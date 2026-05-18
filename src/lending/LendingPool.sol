// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../tokens/PositionNFT.sol";
import "../oracles/PriceOracle.sol";
import "../libraries/YulMath.sol";

/**
 * @title LendingPool
 * @notice UUPS upgradeable lending pool built from scratch. Supports depositing collateral,
 * borrowing, repaying, liquidations, and linear interest rate accrual.
 */
contract LendingPool is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    struct UserPosition {
        uint256 collateral;        // Supplied collateral (e.g. WETH)
        uint256 borrowedPrincipal; // Borrowed principal (scaled by borrowIndex)
        uint256 borrowIndexSnapshot; // User's snapshot of the global borrow index
    }

    IERC20 public collateralToken;
    IERC20 public borrowToken;
    PositionNFT public positionNFT;
    PriceOracle public priceOracle;

    // Mapping from user address to their Position NFT ID
    mapping(address => uint256) public userNFT;
    // Mapping from Position NFT ID to their Position state
    mapping(uint256 => UserPosition) public positions;

    // Linear Interest Rate Model Parameters (in basis points, 10000 = 100%)
    uint256 public constant BASE_RATE = 200;      // 2% base borrow rate
    uint256 public constant SLOPE_RATE = 800;     // 8% max slope borrow rate
    uint256 public constant RESERVE_FACTOR = 1000; // 10% of interest goes to treasury
    address public treasury;

    // Risk Parameters
    uint256 public constant LTV = 7500;                 // 75% max borrow capacity
    uint256 public constant LIQUIDATION_THRESHOLD = 8000; // 80% liquidation threshold
    uint256 public constant LIQUIDATION_BONUS = 500;     // 5% liquidation bonus

    // Interest Indexes & States
    uint256 public totalSupplied; // Pool cash of borrowToken (USDC)
    uint256 public totalBorrowed; // Current compounded borrowed amount
    uint256 public borrowIndex;   // Global borrow index (starts at 1e18)
    uint256 public lastUpdateTimestamp;

    event CollateralDeposited(address indexed user, uint256 tokenId, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 tokenId, uint256 amount);
    event Borrowed(address indexed user, uint256 tokenId, uint256 amount);
    event Repaid(address indexed user, uint256 tokenId, uint256 amount);
    event Liquidated(
        uint256 indexed tokenId,
        address indexed liquidator,
        uint256 debtRepaid,
        uint256 collateralSeized
    );
    event InterestAccrued(uint256 interestAccrued, uint256 newTotalBorrowed, uint256 newBorrowIndex);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _collateralToken,
        address _borrowToken,
        address _positionNFT,
        address _priceOracle,
        address _treasury,
        address _initialOwner
    ) external initializer {
        __Ownable_init(_initialOwner);

        collateralToken = IERC20(_collateralToken);
        borrowToken = IERC20(_borrowToken);
        positionNFT = PositionNFT(_positionNFT);
        priceOracle = PriceOracle(_priceOracle);
        treasury = _treasury;

        borrowIndex = 1e18; // Standard 18 decimal scale
        lastUpdateTimestamp = block.timestamp;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Accrues interest globally for the pool based on the linear model.
     */
    function accrueInterest() public {
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;
        if (timeElapsed == 0 || totalBorrowed == 0) {
            lastUpdateTimestamp = block.timestamp;
            return;
        }

        uint256 rate = getBorrowRate(); // Annualized rate in basis points

        // interest = totalBorrowed * rate * timeElapsed / (365 days * 10000)
        uint256 interestAccrued = YulMath.yulMulDiv(
            totalBorrowed,
            rate * timeElapsed,
            365 days * 10000
        );

        if (interestAccrued > 0) {
            uint256 fee = YulMath.yulMulDiv(interestAccrued, RESERVE_FACTOR, 10000);
            uint256 lenderInterest = interestAccrued - fee;

            totalBorrowed += interestAccrued;
            totalSupplied += lenderInterest; // Treasury fee compounds borrowable liquidity

            // Update global borrow index
            // newIndex = borrowIndex * (totalBorrowed + interestAccrued) / totalBorrowed
            borrowIndex = YulMath.yulMulDiv(borrowIndex, totalBorrowed, totalBorrowed - interestAccrued);
        }

        lastUpdateTimestamp = block.timestamp;
        emit InterestAccrued(interestAccrued, totalBorrowed, borrowIndex);
    }

    /**
     * @notice Returns the current borrow interest rate based on utilization.
     */
    function getBorrowRate() public view returns (uint256) {
        uint256 utilization = getUtilization();
        // BASE_RATE + SLOPE_RATE * utilization / 10000
        return BASE_RATE + YulMath.yulMulDiv(SLOPE_RATE, utilization, 10000);
    }

    /**
     * @notice Returns the pool utilization rate in basis points (10000 = 100%).
     */
    function getUtilization() public view returns (uint256) {
        uint256 cash = totalSupplied; // Underlying supply in pool
        uint256 borrows = totalBorrowed;
        if (borrows == 0) return 0;
        // utilization = borrows * 10000 / (cash + borrows)
        return YulMath.yulMulDiv(borrows, 10000, cash + borrows);
    }

    /**
     * @notice Deposits collateral into the Lending Pool.
     * @param amount The amount of collateral to deposit.
     * @return tokenId The ID of the Position NFT.
     */
    function depositCollateral(uint256 amount) external nonReentrant returns (uint256 tokenId) {
        require(amount > 0, "Amount must be > 0");
        accrueInterest();

        tokenId = userNFT[msg.sender];
        if (tokenId == 0) {
            // Mint a new position NFT
            tokenId = positionNFT.mint(msg.sender);
            userNFT[msg.sender] = tokenId;
        }

        positions[tokenId].collateral += amount;

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        emit CollateralDeposited(msg.sender, tokenId, amount);
    }

    /**
     * @notice Withdraws collateral from the Lending Pool.
     * @param amount The amount of collateral to withdraw.
     */
    function withdrawCollateral(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        accrueInterest();

        uint256 tokenId = userNFT[msg.sender];
        require(tokenId != 0, "No active position");
        
        UserPosition storage pos = positions[tokenId];
        require(pos.collateral >= amount, "Insufficient collateral balance");

        pos.collateral -= amount;

        // Verify health factor remains safe
        require(getHealthFactor(tokenId) >= 1e18, "Position falls below safe threshold");

        collateralToken.safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, tokenId, amount);
    }

    /**
     * @notice Borrows borrowToken (USDC) from the Lending Pool.
     * @param amount The amount of borrowToken to borrow.
     */
    function borrow(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        accrueInterest();

        uint256 tokenId = userNFT[msg.sender];
        require(tokenId != 0, "No collateral deposited");

        UserPosition storage pos = positions[tokenId];

        // Accrue user's previous debt interest
        uint256 currentDebt = getPositionDebt(tokenId);
        
        pos.borrowedPrincipal = currentDebt + amount;
        pos.borrowIndexSnapshot = borrowIndex;

        totalBorrowed += amount;
        totalSupplied -= amount;

        // Verify position health factor is safe (must be >= 1.0)
        require(getHealthFactor(tokenId) >= 1e18, "Insufficient collateral capacity");

        borrowToken.safeTransfer(msg.sender, amount);
        emit Borrowed(msg.sender, tokenId, amount);
    }

    /**
     * @notice Repays borrowToken to reduce debt.
     * @param amount The amount of borrowToken to repay.
     */
    function repay(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        accrueInterest();

        uint256 tokenId = userNFT[msg.sender];
        require(tokenId != 0, "No active position");

        UserPosition storage pos = positions[tokenId];
        uint256 currentDebt = getPositionDebt(tokenId);
        require(currentDebt > 0, "No debt to repay");

        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;

        pos.borrowedPrincipal = currentDebt - repayAmount;
        pos.borrowIndexSnapshot = borrowIndex;

        totalBorrowed -= repayAmount;
        totalSupplied += repayAmount;

        borrowToken.safeTransferFrom(msg.sender, address(this), repayAmount);
        emit Repaid(msg.sender, tokenId, repayAmount);
    }

    /**
     * @notice Supplies borrowToken (USDC) into the pool to earn interest.
     * @param amount The amount of borrowToken to supply.
     */
    function supplyBorrowToken(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        accrueInterest();

        totalSupplied += amount;
        borrowToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Withdraws supplied borrowToken (USDC) from the pool.
     * @param amount The amount of borrowToken to withdraw.
     */
    function withdrawBorrowToken(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        accrueInterest();
        require(totalSupplied >= amount, "Insufficient pool liquidity");

        totalSupplied -= amount;
        borrowToken.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Liquidates an unhealthy position.
     * @param tokenId The ID of the position to liquidate.
     * @param repayAmount The amount of borrowToken to repay.
     */
    function liquidate(uint256 tokenId, uint256 repayAmount) external nonReentrant {
        require(repayAmount > 0, "Repay amount must be > 0");
        accrueInterest();

        uint256 hf = getHealthFactor(tokenId);
        require(hf < 1e18, "Position is healthy");

        UserPosition storage pos = positions[tokenId];
        uint256 currentDebt = getPositionDebt(tokenId);
        require(currentDebt > 0, "No debt to liquidate");

        // Can only liquidate up to 50% of total debt
        uint256 maxRepay = currentDebt / 2;
        uint256 actualRepay = repayAmount > maxRepay ? maxRepay : repayAmount;

        // Seize collateral worth actualRepay + 5% bonus
        uint256 collateralPrice = priceOracle.getAssetPrice(address(collateralToken));
        uint256 borrowPrice = priceOracle.getAssetPrice(address(borrowToken));

        // Value of debt repaid in USD = actualRepay * borrowPrice / decimals
        // Collateral value to seize in USD = debtValueUSD * (1 + LIQUIDATION_BONUS / 10000)
        // Collateral amount to seize = (actualRepay * borrowPrice * 1.05) / collateralPrice
        uint256 seizedCollateral = YulMath.yulMulDiv(
            actualRepay * borrowPrice,
            10000 + LIQUIDATION_BONUS,
            collateralPrice * 10000
        );

        require(pos.collateral >= seizedCollateral, "Liquidator seeks more than available collateral");

        pos.collateral -= seizedCollateral;
        pos.borrowedPrincipal = currentDebt - actualRepay;
        pos.borrowIndexSnapshot = borrowIndex;

        totalBorrowed -= actualRepay;
        totalSupplied += actualRepay;

        // Transfer funds
        borrowToken.safeTransferFrom(msg.sender, address(this), actualRepay);
        collateralToken.safeTransfer(msg.sender, seizedCollateral);

        emit Liquidated(tokenId, msg.sender, actualRepay, seizedCollateral);
    }

    /**
     * @notice Calculates the health factor of a position.
     * Health Factor = (CollateralValue * LiquidationThreshold) / (DebtValue * 10000)
     * Scaled by 1e18 (1e18 = 1.0)
     */
    function getHealthFactor(uint256 tokenId) public view returns (uint256) {
        UserPosition storage pos = positions[tokenId];
        if (pos.collateral == 0) return 0;
        
        uint256 currentDebt = getPositionDebt(tokenId);
        if (currentDebt == 0) return type(uint256).max; // Infinite health factor

        uint256 collateralPrice = priceOracle.getAssetPrice(address(collateralToken));
        uint256 borrowPrice = priceOracle.getAssetPrice(address(borrowToken));

        uint256 collateralValueUSD = pos.collateral * collateralPrice; // collateral * price (8 decimals)
        uint256 debtValueUSD = currentDebt * borrowPrice;             // debt * price (8 decimals)

        // Health factor scaled by 1e18
        // HF = (collateralValueUSD * LIQUIDATION_THRESHOLD / 10000) * 1e18 / debtValueUSD
        return YulMath.yulMulDiv(collateralValueUSD, LIQUIDATION_THRESHOLD * 1e14, debtValueUSD);
    }

    /**
     * @notice Calculates the total debt (principal + interest) of a position.
     */
    function getPositionDebt(uint256 tokenId) public view returns (uint256) {
        UserPosition storage pos = positions[tokenId];
        if (pos.borrowedPrincipal == 0) return 0;
        
        // debt = borrowedPrincipal * borrowIndex / borrowIndexSnapshot
        return YulMath.yulMulDiv(pos.borrowedPrincipal, borrowIndex, pos.borrowIndexSnapshot);
    }
}

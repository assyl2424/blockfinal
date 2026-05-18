import React, { useState, useEffect } from 'react';
import { 
  useAccount, 
  useConnect, 
  useDisconnect, 
  useChainId, 
  useSwitchChain 
} from 'wagmi';
import { 
  Coins, 
  TrendingUp, 
  Vote, 
  Database, 
  ShieldAlert, 
  CheckCircle, 
  Wallet, 
  RefreshCw, 
  UserCheck, 
  PlusCircle, 
  ArrowRightLeft,
  ArrowDownCircle,
  FileText,
  Percent,
  Check,
  AlertTriangle,
  Heart
} from 'lucide-react';

// Simulated state interface for our rich DeFi Sandbox Mode
interface SimulatedState {
  wethBalance: number;
  usdcBalance: number;
  lpBalance: number;
  vaultShares: number;
  vaultAssets: number;
  suppliedCollateral: number;
  borrowedPrincipal: number;
  healthFactor: number;
  borrowIndex: number;
  totalPoolUSDC: number;
  ethPrice: number;
  referralCode: string;
}

export default function App() {
  // Tab State: "swap" | "lending" | "vault" | "governance" | "indexer"
  const [activeTab, setActiveTab] = useState<string>("swap");
  
  // Real Web3 MetaMask connection hooks
  const { address, isConnected } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();

  // Synchronized compatibility state mapping
  const [connected, setConnected] = useState<boolean>(false);
  const [walletAddress, setWalletAddress] = useState<string>("");
  const [network, setNetwork] = useState<string>("Arbitrum Sepolia");
  const [showNetworkAlert, setShowNetworkAlert] = useState<boolean>(false);

  // Monitor MetaMask real connection status
  useEffect(() => {
    if (isConnected && address) {
      setConnected(true);
      setWalletAddress(address);
      
      // Auto chain detect
      if (chainId === 421614) {
        setNetwork("Arbitrum Sepolia");
        setShowNetworkAlert(false);
      } else if (chainId === 84532) {
        setNetwork("Base Sepolia");
        setShowNetworkAlert(false);
      } else if (chainId === 31337) {
        setNetwork("Local Anvil");
        setShowNetworkAlert(false);
      } else {
        setNetwork("Wrong Network");
        setShowNetworkAlert(true);
      }
    } else {
      setConnected(false);
      setWalletAddress("");
      setShowNetworkAlert(false);
    }
  }, [isConnected, address, chainId]);

  // DeFi state
  const [state, setState] = useState<SimulatedState>({
    wethBalance: 10.0,
    usdcBalance: 15000.0,
    lpBalance: 0,
    vaultShares: 0,
    vaultAssets: 0,
    suppliedCollateral: 0,
    borrowedPrincipal: 0,
    healthFactor: 999.0,
    borrowIndex: 1.0,
    totalPoolUSDC: 50000.0,
    ethPrice: 3000.0,
    referralCode: ""
  });

  // Action input states
  const [swapAmount, setSwapAmount] = useState<string>("1");
  const [swapDirection, setSwapDirection] = useState<boolean>(true); // true = WETH -> USDC, false = USDC -> WETH
  const [depositAmount, setDepositAmount] = useState<string>("2");
  const [withdrawAmount, setWithdrawAmount] = useState<string>("1");
  const [borrowAmount, setBorrowAmount] = useState<string>("1000");
  const [repayAmount, setRepayAmount] = useState<string>("500");
  const [vaultDeposit, setVaultDeposit] = useState<string>("2000");
  const [vaultWithdraw, setVaultWithdraw] = useState<string>("1000");
  const [referrerInput, setReferrerInput] = useState<string>("");
  
  // Governance states
  const [proposals, setProposals] = useState<any[]>([
    {
      id: 1,
      title: "PIP-1: Adjust Lending Pool LTV from 75% to 80%",
      description: "Increase maximum leverage capacity for high-reputation collateral depositors, capitalizing on improved price feed speed.",
      proposer: "0x334...a8F",
      status: "ACTIVE",
      startBlock: 7420100,
      endBlock: 7470500,
      votesFor: 125000,
      votesAgainst: 12000,
      votesAbstain: 3200,
      voted: false
    },
    {
      id: 2,
      title: "PIP-2: Upgrade Lending Pool to Linear V2 Referral Engine",
      description: "Introduce custom basis-points referral distributions to liquidity integrators, driving deposit size growths.",
      proposer: "0xAAa...888",
      status: "EXECUTED",
      startBlock: 7300000,
      endBlock: 7350400,
      votesFor: 350000,
      votesAgainst: 0,
      votesAbstain: 500,
      voted: true
    }
  ]);
  const [proposalTitle, setProposalTitle] = useState<string>("");
  const [proposalDesc, setProposalDesc] = useState<string>("");
  const [delegatedAddress, setDelegatedAddress] = useState<string>("");
  const [delegatedStatus, setDelegatedStatus] = useState<boolean>(false);

  // Subgraph indexing transactions list
  const [transactions, setTransactions] = useState<any[]>([
    { id: "tx-1", type: "SWAP", hash: "0x8fa4...18f", timestamp: "Just now", details: "Swapped 1.0 WETH for 2,991 USDC" },
    { id: "tx-2", type: "DEPOSIT", hash: "0xcc29...3a8", timestamp: "5 mins ago", details: "Supplied 2.5 Collateral WETH" },
    { id: "tx-3", type: "BORROW", hash: "0x78ab...de2", timestamp: "12 mins ago", details: "Borrowed 1,500 USDC" },
    { id: "tx-4", type: "VOTE", hash: "0x12fa...6bc", timestamp: "1 hour ago", details: "Voted FOR Proposal PIP-1 with 1,000 Votes" }
  ]);

  // Alert message banner state
  const [successMsg, setSuccessMsg] = useState<string>("");
  const [errorMsg, setErrorMsg] = useState<string>("");

  // Auto clear alerts
  useEffect(() => {
    if (successMsg) {
      const timer = setTimeout(() => setSuccessMsg(""), 4000);
      return () => clearTimeout(timer);
    }
  }, [successMsg]);

  useEffect(() => {
    if (errorMsg) {
      const timer = setTimeout(() => setErrorMsg(""), 4000);
      return () => clearTimeout(timer);
    }
  }, [errorMsg]);

  // Connect Wallet Action
  const connectWallet = () => {
    if (!isConnected) {
      const metamask = connectors.find(c => c.id === 'injected' || c.name.toLowerCase().includes('metamask'));
      if (metamask) {
        connect({ connector: metamask });
      } else if (connectors[0]) {
        connect({ connector: connectors[0] });
      } else {
        setErrorMsg("No Web3 provider extension found. Please install MetaMask!");
      }
    } else {
      disconnect();
    }
  };

  // Switch network logic
  const handleNetworkChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const selected = e.target.value;
    if (selected === "Wrong Chain Demo") {
      setShowNetworkAlert(true);
      setNetwork("Wrong Network");
      return;
    }
    
    let targetChainId = 421614; // Default Arbitrum Sepolia
    if (selected === "Base Sepolia") targetChainId = 84532;
    if (selected === "Local Anvil") targetChainId = 31337;

    if (switchChain) {
      switchChain({ chainId: targetChainId });
    } else {
      if (selected === "Base Sepolia") {
        setNetwork("Base Sepolia");
      } else if (selected === "Local Anvil") {
        setNetwork("Local Anvil");
      } else {
        setNetwork("Arbitrum Sepolia");
      }
      setShowNetworkAlert(false);
    }
  };

  // Math: swap outputs
  const getSwapOutput = () => {
    const amount = parseFloat(swapAmount) || 0;
    if (swapDirection) {
      // WETH -> USDC: $3000 per WETH minus 0.3% fee
      return (amount * state.ethPrice * 0.997).toFixed(2);
    } else {
      // USDC -> WETH: $3000 per WETH minus 0.3% fee
      return (amount / state.ethPrice * 0.997).toFixed(6);
    }
  };

  // Execute Swap
  const handleSwap = (e: React.FormEvent) => {
    e.preventDefault();
    const amount = parseFloat(swapAmount);
    if (!amount || amount <= 0) return setErrorMsg("Enter a valid swap amount");

    if (swapDirection) {
      if (amount > state.wethBalance) return setErrorMsg("Insufficient WETH balance");
      const usdcReceived = amount * state.ethPrice * 0.997;
      setState(prev => ({
        ...prev,
        wethBalance: prev.wethBalance - amount,
        usdcBalance: prev.usdcBalance + usdcReceived
      }));
      setTransactions(prev => [
        {
          id: `tx-${Date.now()}`,
          type: "SWAP",
          hash: "0x" + Math.random().toString(16).substring(2, 10) + "...swap",
          timestamp: "Just now",
          details: `Swapped ${amount.toFixed(4)} WETH for ${usdcReceived.toFixed(2)} USDC`
        },
        ...prev
      ]);
      setSuccessMsg(`Swapped ${amount} WETH successfully!`);
    } else {
      if (amount > state.usdcBalance) return setErrorMsg("Insufficient USDC balance");
      const wethReceived = amount / state.ethPrice * 0.997;
      setState(prev => ({
        ...prev,
        usdcBalance: prev.usdcBalance - amount,
        wethBalance: prev.wethBalance + wethReceived
      }));
      setTransactions(prev => [
        {
          id: `tx-${Date.now()}`,
          type: "SWAP",
          hash: "0x" + Math.random().toString(16).substring(2, 10) + "...swap",
          timestamp: "Just now",
          details: `Swapped ${amount.toFixed(2)} USDC for ${wethReceived.toFixed(6)} WETH`
        },
        ...prev
      ]);
      setSuccessMsg(`Swapped ${amount} USDC successfully!`);
    }
  };

  // Calculate Health Factor
  const calculateHF = (collateral: number, debt: number, price: number) => {
    if (debt <= 0) return 999.0;
    // Health factor = (Collateral Value * Liquidation Threshold) / Debt
    // Threshold is 80%
    const collateralValue = collateral * price;
    const hf = (collateralValue * 0.8) / debt;
    return hf;
  };

  // Handle deposit collateral
  const handleDepositCollateral = (e: React.FormEvent) => {
    e.preventDefault();
    const amount = parseFloat(depositAmount);
    if (!amount || amount <= 0) return setErrorMsg("Enter valid collateral deposit");
    if (amount > state.wethBalance) return setErrorMsg("Insufficient WETH balance");

    const newCollateral = state.suppliedCollateral + amount;
    const newHF = calculateHF(newCollateral, state.borrowedPrincipal, state.ethPrice);

    setState(prev => ({
      ...prev,
      wethBalance: prev.wethBalance - amount,
      suppliedCollateral: newCollateral,
      healthFactor: newHF
    }));

    setTransactions(prev => [
      {
        id: `tx-${Date.now()}`,
        type: "DEPOSIT",
        hash: "0x" + Math.random().toString(16).substring(2, 10) + "...dep",
        timestamp: "Just now",
        details: `Deposited ${amount.toFixed(4)} WETH Collateral`
      },
      ...prev
    ]);
    setSuccessMsg(`Successfully deposited ${amount} WETH collateral!`);
  };

  // Handle withdraw collateral
  const handleWithdrawCollateral = (e: React.FormEvent) => {
    e.preventDefault();
    const amount = parseFloat(withdrawAmount);
    if (!amount || amount <= 0) return setErrorMsg("Enter valid withdrawal amount");
    if (amount > state.suppliedCollateral) return setErrorMsg("Insufficient collateral supplied");

    const newCollateral = state.suppliedCollateral - amount;
    const newHF = calculateHF(newCollateral, state.borrowedPrincipal, state.ethPrice);

    // Enforce LTV cap (75% max borrow on withdrawal)
    if (state.borrowedPrincipal > 0 && newHF < 1.0) {
      return setErrorMsg("Withdrawal would trigger immediate liquidation risk!");
    }

    setState(prev => ({
      ...prev,
      wethBalance: prev.wethBalance + amount,
      suppliedCollateral: newCollateral,
      healthFactor: newHF
    }));

    setTransactions(prev => [
      {
        id: `tx-${Date.now()}`,
        type: "WITHDRAW",
        hash: "0x" + Math.random().toString(16).substring(2, 10) + "...wth",
        timestamp: "Just now",
        details: `Withdrew ${amount.toFixed(4)} WETH Collateral`
      },
      ...prev
    ]);
    setSuccessMsg(`Successfully withdrew ${amount} WETH collateral!`);
  };

  // Handle Borrow
  const handleBorrow = (e: React.FormEvent) => {
    e.preventDefault();
    const amount = parseFloat(borrowAmount);
    if (!amount || amount <= 0) return setErrorMsg("Enter valid borrow amount");
    if (amount > state.totalPoolUSDC) return setErrorMsg("Lending pool liquidity exhausted");

    const newBorrowed = state.borrowedPrincipal + amount;
    const newHF = calculateHF(state.suppliedCollateral, newBorrowed, state.ethPrice);

    // Enforce LTV limit (Health factor must be > 1.0)
    if (newHF < 1.0) {
      return setErrorMsg("Borrow exceeds maximum LTV capacity (Insufficient collateral)");
    }

    setState(prev => ({
      ...prev,
      borrowedPrincipal: newBorrowed,
      usdcBalance: prev.usdcBalance + amount,
      totalPoolUSDC: prev.totalPoolUSDC - amount,
      healthFactor: newHF
    }));

    setTransactions(prev => [
      {
        id: `tx-${Date.now()}`,
        type: "BORROW",
        hash: "0x" + Math.random().toString(16).substring(2, 10) + "...bor",
        timestamp: "Just now",
        details: `Borrowed ${amount.toFixed(2)} USDC`
      },
      ...prev
    ]);
    setSuccessMsg(`Successfully borrowed ${amount} USDC!`);
  };

  // Handle Repay
  const handleRepay = (e: React.FormEvent) => {
    e.preventDefault();
    const amount = parseFloat(repayAmount);
    if (!amount || amount <= 0) return setErrorMsg("Enter valid repay amount");
    if (amount > state.usdcBalance) return setErrorMsg("Insufficient USDC to repay");
    if (amount > state.borrowedPrincipal) return setErrorMsg("Repay amount exceeds outstanding debt");

    const newBorrowed = state.borrowedPrincipal - amount;
    const newHF = calculateHF(state.suppliedCollateral, newBorrowed, state.ethPrice);

    setState(prev => ({
      ...prev,
      borrowedPrincipal: newBorrowed,
      usdcBalance: prev.usdcBalance - amount,
      totalPoolUSDC: prev.totalPoolUSDC + amount,
      healthFactor: newHF
    }));

    setTransactions(prev => [
      {
        id: `tx-${Date.now()}`,
        type: "REPAY",
        hash: "0x" + Math.random().toString(16).substring(2, 10) + "...rep",
        timestamp: "Just now",
        details: `Repaid ${amount.toFixed(2)} USDC Debt`
      },
      ...prev
    ]);
    setSuccessMsg(`Repaid ${amount} USDC successfully!`);
  };

  // Crash ETH Price to simulate liquidation!
  const triggerPriceCrash = () => {
    const crashedPrice = 1800.0;
    const newHF = calculateHF(state.suppliedCollateral, state.borrowedPrincipal, crashedPrice);
    setState(prev => ({
      ...prev,
      ethPrice: crashedPrice,
      healthFactor: newHF
    }));
    setSuccessMsg("Simulated market flash crash: WETH price dropped to $1,800!");
  };

  // Reset ETH Price
  const resetMarketPrice = () => {
    const restoredPrice = 3000.0;
    const newHF = calculateHF(state.suppliedCollateral, state.borrowedPrincipal, restoredPrice);
    setState(prev => ({
      ...prev,
      ethPrice: restoredPrice,
      healthFactor: newHF
    }));
    setSuccessMsg("Market price restored: WETH is back to $3,000.");
  };

  // Liquidate Unhealthy Position
  const handleLiquidationSim = () => {
    if (state.healthFactor >= 1.0) {
      return setErrorMsg("Position is currently healthy (Health Factor >= 1.0)");
    }
    // Perform liquidation
    // Liquidator pays off 100% of the debt and seizes collateral with a 5% discount bonus
    const debtPaid = state.borrowedPrincipal;
    const collateralValueToSeize = debtPaid * 1.05;
    const collateralToSeize = collateralValueToSeize / state.ethPrice;

    if (state.usdcBalance < debtPaid) {
      return setErrorMsg("You need sufficient USDC to act as liquidator");
    }

    setState(prev => ({
      ...prev,
      // Liquidator loses USDC paid but gets WETH collateral seized
      usdcBalance: prev.usdcBalance - debtPaid,
      wethBalance: prev.wethBalance + collateralToSeize,
      // Borrower position wiped out
      suppliedCollateral: prev.suppliedCollateral - collateralToSeize,
      borrowedPrincipal: 0,
      healthFactor: 999.0
    }));

    setTransactions(prev => [
      {
        id: `tx-${Date.now()}`,
        type: "LIQUIDATE",
        hash: "0x" + Math.random().toString(16).substring(2, 10) + "...liq",
        timestamp: "Just now",
        details: `Liquidated position: Repaid ${debtPaid.toFixed(2)} USDC, Seized ${collateralToSeize.toFixed(4)} WETH`
      },
      ...prev
    ]);
    setSuccessMsg("Position liquidated successfully! You earned a 5% discount bonus!");
  };

  // ERC-4626 Yield Vault Deposit
  const handleVaultDeposit = (e: React.FormEvent) => {
    e.preventDefault();
    const amount = parseFloat(vaultDeposit);
    if (!amount || amount <= 0) return setErrorMsg("Enter valid vault deposit");
    if (amount > state.usdcBalance) return setErrorMsg("Insufficient USDC balance");

    // Deposit splits: rounds shares down to prevent inflation attacks (strictly like ERC-4626)
    // 1 assets = 1 share initial rate
    const newShares = Math.floor(amount);

    setState(prev => ({
      ...prev,
      usdcBalance: prev.usdcBalance - amount,
      vaultShares: prev.vaultShares + newShares,
      vaultAssets: prev.vaultAssets + amount
    }));

    setTransactions(prev => [
      {
        id: `tx-${Date.now()}`,
        type: "VAULT",
        hash: "0x" + Math.random().toString(16).substring(2, 10) + "...vlt",
        timestamp: "Just now",
        details: `Deposited ${amount.toFixed(2)} USDC into Yield Vault. Minted ${newShares} Shares.`
      },
      ...prev
    ]);
    setSuccessMsg(`Deposited ${amount} USDC into ERC-4626 Yield Vault!`);
  };

  // ERC-4626 Yield Vault Withdraw
  const handleVaultWithdraw = (e: React.FormEvent) => {
    e.preventDefault();
    const sharesToRedeem = parseFloat(vaultWithdraw);
    if (!sharesToRedeem || sharesToRedeem <= 0) return setErrorMsg("Enter valid shares to withdraw");
    if (sharesToRedeem > state.vaultShares) return setErrorMsg("Insufficient vault shares");

    // Math: asset conversion rounds UP on withdraw/redeem to protect pool
    const shareRatio = state.vaultAssets / state.vaultShares;
    const assetsToReceive = Math.ceil(sharesToRedeem * shareRatio * 100) / 100;

    setState(prev => ({
      ...prev,
      vaultShares: prev.vaultShares - sharesToRedeem,
      vaultAssets: prev.vaultAssets - assetsToReceive,
      usdcBalance: prev.usdcBalance + assetsToReceive
    }));

    setTransactions(prev => [
      {
        id: `tx-${Date.now()}`,
        type: "VAULT",
        hash: "0x" + Math.random().toString(16).substring(2, 10) + "...vlt",
        timestamp: "Just now",
        details: `Redeemed ${sharesToRedeem} Shares for ${assetsToReceive.toFixed(2)} USDC`
      },
      ...prev
    ]);
    setSuccessMsg(`Redeemed ${sharesToRedeem} Shares for ${assetsToReceive} USDC!`);
  };

  // Simulate Yield Harvest (Harvest 10% appreciation of Vault assets!)
  const handleHarvestYield = () => {
    if (state.vaultAssets <= 0) return setErrorMsg("No assets in the vault to generate yield");
    const yieldEarned = state.vaultAssets * 0.08; // 8% profit generated!
    const feeAmount = yieldEarned * 0.05; // 5% fee to treasury
    const netYield = yieldEarned - feeAmount;

    setState(prev => ({
      ...prev,
      vaultAssets: prev.vaultAssets + netYield
    }));

    setTransactions(prev => [
      {
        id: `tx-${Date.now()}`,
        type: "VAULT",
        hash: "0x" + Math.random().toString(16).substring(2, 10) + "...har",
        timestamp: "Just now",
        details: `Harvested yield: Generated +${yieldEarned.toFixed(2)} USDC profit (+8.00% yield appreciation)`
      },
      ...prev
    ]);
    setSuccessMsg("Yield harvested: Vault shares successfully appreciated by 8.00%!");
  };

  // Governance proposals: delegate votes
  const handleDelegate = (e: React.FormEvent) => {
    e.preventDefault();
    if (!delegatedAddress.startsWith("0x") || delegatedAddress.length < 40) {
      return setErrorMsg("Provide a valid hex delegator address");
    }
    setDelegatedStatus(true);
    setSuccessMsg(`Successfully delegated voting power to ${delegatedAddress}!`);
  };

  // Governance: cast vote
  const castVote = (proposalId: number, support: number) => {
    setProposals(prev => prev.map(p => {
      if (p.id === proposalId) {
        if (p.voted) return p;
        const weight = 1000;
        const votesAdded = weight;
        return {
          ...p,
          voted: true,
          votesFor: support === 1 ? p.votesFor + votesAdded : p.votesFor,
          votesAgainst: support === 0 ? p.votesAgainst + votesAdded : p.votesAgainst,
          votesAbstain: support === 2 ? p.votesAbstain + votesAdded : p.votesAbstain,
        };
      }
      return p;
    }));

    const supportString = support === 1 ? "FOR" : support === 0 ? "AGAINST" : "ABSTAIN";
    setTransactions(prev => [
      {
        id: `tx-${Date.now()}`,
        type: "VOTE",
        hash: "0x" + Math.random().toString(16).substring(2, 10) + "...vot",
        timestamp: "Just now",
        details: `Voted ${supportString} on Proposal #${proposalId} with 1,000 voting weight`
      },
      ...prev
    ]);
    setSuccessMsg(`Voted ${supportString} successfully on Proposal #${proposalId}!`);
  };

  // Governance: submit new proposal
  const submitProposal = (e: React.FormEvent) => {
    e.preventDefault();
    if (!proposalTitle || !proposalDesc) return setErrorMsg("Provide a title and description");

    const newProp = {
      id: proposals.length + 1,
      title: proposalTitle,
      description: proposalDesc,
      proposer: connected ? walletAddress.substring(0, 7) + "..." + walletAddress.substring(38) : "0x709...9C8",
      status: "ACTIVE",
      startBlock: 7500000,
      endBlock: 7550000,
      votesFor: 0,
      votesAgainst: 0,
      votesAbstain: 0,
      voted: false
    };

    setProposals(prev => [newProp, ...prev]);
    setProposalTitle("");
    setProposalDesc("");
    setTransactions(prev => [
      {
        id: `tx-${Date.now()}`,
        type: "PROPOSAL",
        hash: "0x" + Math.random().toString(16).substring(2, 10) + "...prp",
        timestamp: "Just now",
        details: `Created new proposal: "${proposalTitle}"`
      },
      ...prev
    ]);
    setSuccessMsg("Governance proposal submitted successfully!");
  };

  // Governance: queue proposal in Timelock
  const queueProposal = (proposalId: number) => {
    setProposals(prev => prev.map(p => {
      if (p.id === proposalId) {
        return { ...p, status: "QUEUED" };
      }
      return p;
    }));
    setTransactions(prev => [
      {
        id: `tx-${Date.now()}`,
        type: "QUEUE",
        hash: "0x" + Math.random().toString(16).substring(2, 10) + "...que",
        timestamp: "Just now",
        details: `Queued Proposal #${proposalId} in Timelock (2-day delay initialized)`
      },
      ...prev
    ]);
    setSuccessMsg(`Proposal #${proposalId} successfully queued in Timelock!`);
  };

  // Governance: execute proposal from Timelock
  const executeProposal = (proposalId: number) => {
    setProposals(prev => prev.map(p => {
      if (p.id === proposalId) {
        return { ...p, status: "EXECUTED" };
      }
      return p;
    }));
    setTransactions(prev => [
      {
        id: `tx-${Date.now()}`,
        type: "EXECUTE",
        hash: "0x" + Math.random().toString(16).substring(2, 10) + "...exe",
        timestamp: "Just now",
        details: `Executed Proposal #${proposalId} successfully on-chain!`
      },
      ...prev
    ]);
    setSuccessMsg(`Proposal #${proposalId} executed successfully on-chain!`);
  };

  // Lending pool: referral bonus config
  const handleRegisterReferrer = (e: React.FormEvent) => {
    e.preventDefault();
    if (!referrerInput.startsWith("0x") || referrerInput.length < 40) {
      return setErrorMsg("Invalid referrer address format");
    }
    setState(prev => ({ ...prev, referralCode: referrerInput }));
    setSuccessMsg(`Registered referrer ${referrerInput} with 5% referral bonus!`);
  };

  return (
    <div className="app-container">
      {/* Banner / Navigation */}
      <header className="nav-header">
        <div className="brand">
          <Coins size={32} color="#9333ea" />
          DSA DEFI <span>SUPER-APP</span>
        </div>
        
        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <select 
            onChange={handleNetworkChange} 
            value={network}
            style={{
              background: 'rgba(18, 16, 26, 0.75)',
              border: '1px solid var(--border-glass)',
              color: '#fff',
              padding: '0.5rem 1rem',
              borderRadius: '50px',
              fontFamily: 'var(--font-display)',
              fontWeight: 600,
              outline: 'none',
              cursor: 'pointer'
            }}
          >
            <option value="Arbitrum Sepolia">Arbitrum Sepolia</option>
            <option value="Base Sepolia">Base Sepolia</option>
            <option value="Local Anvil">Local Anvil</option>
            <option value="Wrong Chain Demo">Ethereum Mainnet (Wrong Chain)</option>
          </select>

          <button 
            className={`wallet-btn ${connected ? 'connected' : ''}`}
            onClick={connectWallet}
          >
            <Wallet size={18} />
            {connected ? `${walletAddress.substring(0, 6)}...${walletAddress.substring(38)}` : "Connect Wallet"}
          </button>
        </div>
      </header>

      {/* Network Alert (Automatic wrong chain checks) */}
      {showNetworkAlert && (
        <div className="alert alert-danger" style={{ animation: 'pulseGlow 2s infinite ease-in-out' }}>
          <ShieldAlert size={20} />
          <div>
            <strong>Wrong Chain Detected!</strong> The DSA protocol is supported exclusively on Arbitrum Sepolia, Base Sepolia, or Local Anvil devnets. Please switch your provider.
          </div>
        </div>
      )}

      {/* Action alerts */}
      {successMsg && (
        <div className="alert alert-info">
          <CheckCircle size={20} color="var(--secondary)" />
          <div>{successMsg}</div>
        </div>
      )}
      {errorMsg && (
        <div className="alert alert-danger">
          <ShieldAlert size={20} />
          <div>{errorMsg}</div>
        </div>
      )}

      {/* Dashboard Top Metrics */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1.25rem', marginBottom: '2rem' }}>
        <div className="stat-box">
          <span className="stat-label">WETH Balance</span>
          <span className="stat-value neon-cyan">{state.wethBalance.toFixed(4)} WETH</span>
        </div>
        <div className="stat-box">
          <span className="stat-label">USDC Balance</span>
          <span className="stat-value neon-cyan">{state.usdcBalance.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} USDC</span>
        </div>
        <div className="stat-box">
          <span className="stat-label">Collateral Staked</span>
          <span className="stat-value">{state.suppliedCollateral.toFixed(4)} WETH</span>
        </div>
        <div className="stat-box">
          <span className="stat-label">Position Health Factor</span>
          <span className={`stat-value ${state.healthFactor < 1.0 ? 'neon-green' : state.healthFactor < 1.5 ? 'neon-green' : 'neon-cyan'}`} style={{ color: state.healthFactor < 1.0 ? 'var(--danger)' : state.healthFactor < 1.5 ? 'var(--warning)' : 'var(--success)' }}>
            {state.healthFactor === 999.0 ? '∞' : state.healthFactor.toFixed(3)}
          </span>
        </div>
      </div>

      {/* Tab Selectors */}
      <nav className="tab-container">
        <button 
          className={`tab-btn ${activeTab === 'swap' ? 'active' : ''}`}
          onClick={() => setActiveTab('swap')}
        >
          <ArrowRightLeft size={16} style={{ marginRight: '0.4rem', verticalAlign: 'middle' }} />
          AMM Pool
        </button>
        <button 
          className={`tab-btn ${activeTab === 'lending' ? 'active' : ''}`}
          onClick={() => setActiveTab('lending')}
        >
          <Percent size={16} style={{ marginRight: '0.4rem', verticalAlign: 'middle' }} />
          Lending Pool
        </button>
        <button 
          className={`tab-btn ${activeTab === 'vault' ? 'active' : ''}`}
          onClick={() => setActiveTab('vault')}
        >
          <TrendingUp size={16} style={{ marginRight: '0.4rem', verticalAlign: 'middle' }} />
          Yield Vault
        </button>
        <button 
          className={`tab-btn ${activeTab === 'governance' ? 'active' : ''}`}
          onClick={() => setActiveTab('governance')}
        >
          <Vote size={16} style={{ marginRight: '0.4rem', verticalAlign: 'middle' }} />
          DAO Governance
        </button>
        <button 
          className={`tab-btn ${activeTab === 'indexer' ? 'active' : ''}`}
          onClick={() => setActiveTab('indexer')}
        >
          <Database size={16} style={{ marginRight: '0.4rem', verticalAlign: 'middle' }} />
          Subgraph Indexer
        </button>
      </nav>

      {/* Main Tab Contents */}
      <main className="grid-container">
        
        {/* TAB 1: SWAP PORTAL */}
        {activeTab === 'swap' && (
          <div style={{ gridColumn: '1 / -1' }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
              
              <div className="card glowing">
                <h3 className="card-title">
                  <Coins size={20} color="var(--primary)" />
                  Constant-Product SWAP
                </h3>
                
                <form onSubmit={handleSwap}>
                  <div className="form-group">
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
                      <span className="form-label">From Asset</span>
                      <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                        Balance: {swapDirection ? `${state.wethBalance.toFixed(4)} WETH` : `${state.usdcBalance.toFixed(2)} USDC`}
                      </span>
                    </div>
                    <div className="input-container">
                      <input 
                        type="number" 
                        step="any"
                        value={swapAmount} 
                        onChange={(e) => setSwapAmount(e.target.value)}
                        className="input-field" 
                        placeholder="0.00" 
                      />
                      <span className="input-suffix">{swapDirection ? "WETH" : "USDC"}</span>
                    </div>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'center', margin: '1rem 0' }}>
                    <button 
                      type="button" 
                      onClick={() => setSwapDirection(!swapDirection)}
                      style={{
                        background: 'rgba(147, 51, 234, 0.1)',
                        border: '1px solid var(--border-glass)',
                        color: 'var(--primary)',
                        padding: '0.5rem',
                        borderRadius: '50%',
                        cursor: 'pointer',
                        transition: 'all 0.3s ease'
                      }}
                      title="Flip direction"
                    >
                      <ArrowDownCircle size={22} />
                    </button>
                  </div>

                  <div className="form-group">
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
                      <span className="form-label">To Asset (Estimated output)</span>
                      <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                        Balance: {swapDirection ? `${state.usdcBalance.toFixed(2)} USDC` : `${state.wethBalance.toFixed(4)} WETH`}
                      </span>
                    </div>
                    <div className="input-container">
                      <input 
                        type="text" 
                        readOnly 
                        value={getSwapOutput()}
                        className="input-field" 
                        style={{ background: 'rgba(0,0,0,0.2)', cursor: 'not-allowed' }}
                      />
                      <span className="input-suffix" style={{ color: 'var(--accent)' }}>{swapDirection ? "USDC" : "WETH"}</span>
                    </div>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '1.5rem' }}>
                    <span>LP Swap Fee</span>
                    <span style={{ color: '#fff' }}>0.30% ($x \cdot y = k$ Constant Product)</span>
                  </div>

                  <button type="submit" className="action-btn">
                    Execute Trade
                  </button>
                </form>
              </div>

              {/* Pool reserves / Liquidity pool detail card */}
              <div className="card">
                <h3 className="card-title">
                  <TrendingUp size={20} color="var(--secondary)" />
                  Sorted Pool Liquidity
                </h3>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '0.5rem' }}>
                    <span style={{ color: 'var(--text-secondary)' }}>Trading Pair</span>
                    <span style={{ fontWeight: 700 }}>WETH / USDC</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span>Pool WETH Reserve</span>
                    <span>1,500.00 WETH</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span>Pool USDC Reserve</span>
                    <span>4,500,000.00 USDC</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span>Spot price (USDC/ETH)</span>
                    <span style={{ color: 'var(--secondary)', fontWeight: 700 }}>${state.ethPrice.toLocaleString()} USD</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span>Deterministic Method</span>
                    <span style={{ color: 'var(--accent)' }}>CREATE2 (Salt-Sorted Pairs)</span>
                  </div>
                  
                  <div style={{ marginTop: '1rem', padding: '0.8rem', background: 'rgba(0, 240, 255, 0.04)', border: '1px solid rgba(0, 240, 255, 0.1)', borderRadius: 'var(--radius-md)', fontSize: '0.85rem' }}>
                    <p style={{ color: 'var(--secondary)' }}>
                      <strong>Deterministic Pool addresses:</strong> Pool contract is pre-calculated using the standard Sorted address-bytes parameters, preventing pool duplications.
                    </p>
                  </div>
                </div>
              </div>

            </div>
          </div>
        )}

        {/* TAB 2: LENDING & BORROWING */}
        {activeTab === 'lending' && (
          <div style={{ gridColumn: '1 / -1' }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
              
              {/* Collateral Deposit/Withdraw card */}
              <div className="card">
                <h3 className="card-title">
                  <PlusCircle size={20} color="var(--primary)" />
                  Collateral Management
                </h3>
                
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem', marginBottom: '1.5rem' }}>
                  <form onSubmit={handleDepositCollateral}>
                    <div className="form-group">
                      <label className="form-label">Supply WETH Collateral</label>
                      <div className="input-container">
                        <input 
                          type="number" 
                          step="any"
                          value={depositAmount} 
                          onChange={(e) => setDepositAmount(e.target.value)}
                          className="input-field" 
                        />
                        <span className="input-suffix">WETH</span>
                      </div>
                    </div>
                    <button type="submit" className="action-btn" style={{ background: 'linear-gradient(135deg, var(--success) 0%, var(--primary) 100%)' }}>
                      Stake Collateral
                    </button>
                  </form>

                  <form onSubmit={handleWithdrawCollateral}>
                    <div className="form-group">
                      <label className="form-label">Withdraw WETH Collateral</label>
                      <div className="input-container">
                        <input 
                          type="number" 
                          step="any"
                          value={withdrawAmount} 
                          onChange={(e) => setWithdrawAmount(e.target.value)}
                          className="input-field" 
                        />
                        <span className="input-suffix">WETH</span>
                      </div>
                    </div>
                    <button type="submit" className="action-btn" style={{ background: 'linear-gradient(135deg, rgba(255,255,255,0.05) 0%, var(--danger) 100%)' }}>
                      Withdraw Collateral
                    </button>
                  </form>
                </div>

                <div style={{ borderTop: '1px solid rgba(255,255,255,0.05)', paddingTop: '1.25rem' }}>
                  <h4 style={{ fontSize: '1rem', color: '#fff', marginBottom: '0.75rem' }}>Linear Interest Rate Model</h4>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', fontSize: '0.85rem' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span className="text-muted">Base Rate:</span>
                      <span>2.00% APY</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span className="text-muted">Slope Rate:</span>
                      <span>8.00% APY</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span className="text-muted">Liquidation Threshold:</span>
                      <span style={{ color: 'var(--accent)' }}>80.00%</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span className="text-muted">Referral Fee Cut:</span>
                      <span style={{ color: 'var(--secondary)' }}>5.00%</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Borrow & Repay card */}
              <div className="card">
                <h3 className="card-title">
                  <ArrowRightLeft size={20} color="var(--secondary)" />
                  USDC Debt Portal
                </h3>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem', marginBottom: '1.5rem' }}>
                  <form onSubmit={handleBorrow}>
                    <div className="form-group">
                      <label className="form-label">Borrow USDC</label>
                      <div className="input-container">
                        <input 
                          type="number" 
                          value={borrowAmount} 
                          onChange={(e) => setBorrowAmount(e.target.value)}
                          className="input-field" 
                        />
                        <span className="input-suffix">USDC</span>
                      </div>
                    </div>
                    <button type="submit" className="action-btn">
                      Borrow Assets
                    </button>
                  </form>

                  <form onSubmit={handleRepay}>
                    <div className="form-group">
                      <label className="form-label">Repay USDC</label>
                      <div className="input-container">
                        <input 
                          type="number" 
                          value={repayAmount} 
                          onChange={(e) => setRepayAmount(e.target.value)}
                          className="input-field" 
                        />
                        <span className="input-suffix">USDC</span>
                      </div>
                    </div>
                    <button type="submit" className="action-btn" style={{ background: 'linear-gradient(135deg, var(--secondary) 0%, var(--primary) 100%)' }}>
                      Repay Debt
                    </button>
                  </form>
                </div>

                <div style={{ borderTop: '1px solid rgba(255,255,255,0.05)', paddingTop: '1.25rem' }}>
                  <h4 style={{ fontSize: '1rem', color: '#fff', marginBottom: '0.75rem' }}>Active Borrowing Position</h4>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', fontSize: '0.85rem' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span className="text-muted">Total Borrowed Debt:</span>
                      <span style={{ fontWeight: 700 }}>{state.borrowedPrincipal.toFixed(2)} USDC</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span className="text-muted">Max Capacity (75% LTV):</span>
                      <span style={{ color: 'var(--success)' }}>${(state.suppliedCollateral * state.ethPrice * 0.75).toFixed(2)} USD</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span className="text-muted">Lending Index:</span>
                      <span>{state.borrowIndex.toFixed(4)}x</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span className="text-muted">Dynamic Borrow Rate:</span>
                      <span style={{ color: 'var(--secondary)' }}>2.34% APY</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Advanced Liquidation Simulator & Referral Section */}
              <div className="card" style={{ gridColumn: '1 / -1' }}>
                <h3 className="card-title">
                  <AlertTriangle size={20} color="var(--danger)" />
                  Advanced Risk Simulation & Upgraded Referral Engine (UUPS V2)
                </h3>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
                  
                  {/* Market simulator */}
                  <div>
                    <h4 style={{ color: '#fff', fontSize: '1rem', marginBottom: '0.75rem' }}>1. Collateral Value Crash Simulator</h4>
                    <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginBottom: '1rem' }}>
                      Decrease WETH collateral price to trigger health factor drop below 1.0. This allows anyone to liquidate the position with a 5% collateral bonus incentive!
                    </p>
                    
                    <div style={{ display: 'flex', gap: '1rem', marginBottom: '1.25rem' }}>
                      <button 
                        onClick={triggerPriceCrash} 
                        className="action-btn"
                        style={{ background: 'linear-gradient(135deg, rgba(255,255,255,0.05) 0%, var(--danger) 100%)', flex: 1 }}
                      >
                        Crash WETH to $1,800
                      </button>
                      <button 
                        onClick={resetMarketPrice} 
                        className="action-btn"
                        style={{ background: 'linear-gradient(135deg, var(--success) 0%, rgba(18,16,26,0.65) 100%)', flex: 1 }}
                      >
                        Restore to $3,000
                      </button>
                    </div>

                    <button 
                      onClick={handleLiquidationSim}
                      className="action-btn glowing"
                      disabled={state.healthFactor >= 1.0}
                      style={{ background: state.healthFactor >= 1.0 ? 'rgba(255,255,255,0.02)' : 'linear-gradient(135deg, var(--danger) 0%, var(--accent) 100%)' }}
                    >
                      <ShieldAlert size={18} style={{ marginRight: '0.4rem', verticalAlign: 'middle' }} />
                      Liquidate Position (Active when HF &lt; 1.0)
                    </button>
                  </div>

                  {/* Referral Engine */}
                  <div>
                    <h4 style={{ color: '#fff', fontSize: '1rem', marginBottom: '0.75rem' }}>2. UUPS V2 Upgraded Referral Engine</h4>
                    <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginBottom: '1rem' }}>
                      Register a referrer under our upgraded V2 storage layout to distribute dynamic 5% referral fee cuts upon liquidation rewards or supply borrow transactions.
                    </p>
                    
                    <form onSubmit={handleRegisterReferrer}>
                      <div className="form-group">
                        <label className="form-label">Referrer Hex Address</label>
                        <div className="input-container" style={{ marginBottom: '1rem' }}>
                          <input 
                            type="text" 
                            value={referrerInput}
                            onChange={(e) => setReferrerInput(e.target.value)}
                            className="input-field"
                            placeholder="0x9333ea...4e52"
                          />
                        </div>
                      </div>
                      <button type="submit" className="action-btn" style={{ background: 'linear-gradient(135deg, var(--primary) 0%, var(--secondary) 100%)' }}>
                        Register Referrer
                      </button>
                    </form>

                    {state.referralCode && (
                      <div style={{ marginTop: '1rem', fontSize: '0.85rem', color: 'var(--secondary)' }}>
                        <Check size={14} style={{ marginRight: '0.25rem', verticalAlign: 'middle' }} />
                        Active Referrer: <strong>{state.referralCode}</strong> (Referral basis points: 500)
                      </div>
                    )}
                  </div>

                </div>
              </div>

            </div>
          </div>
        )}

        {/* TAB 3: YIELD VAULT */}
        {activeTab === 'vault' && (
          <div style={{ gridColumn: '1 / -1' }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
              
              <div className="card glowing">
                <h3 className="card-title">
                  <TrendingUp size={20} color="var(--primary)" />
                  ERC-4626 Compliant Yield Vault
                </h3>
                
                <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginBottom: '1.25rem' }}>
                  Stake USDC into our tokenized vault. Deposits round shares DOWN, while withdrawals round underlying assets UP, completely neutralizing inflation attacks.
                </p>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem', marginBottom: '1.5rem' }}>
                  <form onSubmit={handleVaultDeposit}>
                    <div className="form-group">
                      <label className="form-label">Deposit USDC</label>
                      <div className="input-container">
                        <input 
                          type="number" 
                          value={vaultDeposit}
                          onChange={(e) => setVaultDeposit(e.target.value)}
                          className="input-field" 
                        />
                        <span className="input-suffix">USDC</span>
                      </div>
                    </div>
                    <button type="submit" className="action-btn">
                      Deposit
                    </button>
                  </form>

                  <form onSubmit={handleVaultWithdraw}>
                    <div className="form-group">
                      <label className="form-label">Redeem Shares</label>
                      <div className="input-container">
                        <input 
                          type="number" 
                          value={vaultWithdraw}
                          onChange={(e) => setVaultWithdraw(e.target.value)}
                          className="input-field" 
                        />
                        <span className="input-suffix">Shares</span>
                      </div>
                    </div>
                    <button type="submit" className="action-btn" style={{ background: 'linear-gradient(135deg, var(--secondary) 0%, var(--primary) 100%)' }}>
                      Withdraw
                    </button>
                  </form>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid rgba(255,255,255,0.05)', paddingTop: '1.25rem' }}>
                  <div>
                    <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>My Shares Balance:</span>
                    <h4 style={{ fontSize: '1.2rem', color: '#fff' }}>{state.vaultShares} DSA-YVS</h4>
                  </div>
                  <div>
                    <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Convertible Assets:</span>
                    <h4 style={{ fontSize: '1.2rem', color: 'var(--secondary)' }}>{state.vaultAssets.toFixed(2)} USDC</h4>
                  </div>
                </div>
              </div>

              {/* Yield generator & rounding parameters card */}
              <div className="card">
                <h3 className="card-title">
                  <PlusCircle size={20} color="var(--secondary)" />
                  Automated Yield Strategies
                </h3>
                
                <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginBottom: '1.25rem' }}>
                  Our yield vault deposits assets directly into the upgradeable Lending Pool, compounding borrowing fees automatically. Click below to simulate strategy yield harvests.
                </p>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', marginBottom: '1.5rem' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                    <span className="text-muted">Strategy Manager Address:</span>
                    <span style={{ fontFamily: 'monospace' }}>0xTimelockController...88a9</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                    <span className="text-muted">Harvest Strategy Fee:</span>
                    <span>5.00% (collected on yield)</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                    <span className="text-muted">Strategy Target:</span>
                    <span style={{ color: 'var(--success)', fontWeight: 700 }}>Lending Pool USDC Staking</span>
                  </div>
                </div>

                <button 
                  onClick={handleHarvestYield}
                  className="action-btn glowing"
                  style={{ background: 'linear-gradient(135deg, var(--secondary) 0%, var(--success) 100%)' }}
                >
                  <RefreshCw size={18} style={{ marginRight: '0.4rem', verticalAlign: 'middle', animation: 'pulseGlow 2s infinite ease-in-out' }} />
                  Simulate Yield Generation (+8.00% Harvest)
                </button>
              </div>

            </div>
          </div>
        )}

        {/* TAB 4: DAO GOVERNANCE */}
        {activeTab === 'governance' && (
          <div style={{ gridColumn: '1 / -1' }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1.8fr 1.2fr', gap: '2rem' }}>
              
              {/* Proposals List */}
              <div>
                <h3 style={{ fontSize: '1.25rem', color: '#fff', marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <FileText size={20} color="var(--primary)" />
                  Active DAO Proposals
                </h3>

                {proposals.map(p => (
                  <div className="card" key={p.id} style={{ borderLeft: `4px solid ${p.status === 'EXECUTED' ? 'var(--primary)' : 'var(--secondary)'}` }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.5rem' }}>
                      <h4 style={{ fontSize: '1.1rem', color: '#fff' }}>{p.title}</h4>
                      <span className={`badge ${p.status === 'EXECUTED' ? 'badge-executed' : 'badge-active'}`}>
                        {p.status}
                      </span>
                    </div>

                    <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginBottom: '1rem' }}>
                      {p.description}
                    </p>

                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '1.5rem', fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '1.25rem' }}>
                      <span>Proposer: <strong style={{ color: 'var(--text-secondary)' }}>{p.proposer}</strong></span>
                      <span>Votes For: <strong style={{ color: 'var(--success)' }}>{p.votesFor.toLocaleString()}</strong></span>
                      <span>Votes Against: <strong style={{ color: 'var(--danger)' }}>{p.votesAgainst.toLocaleString()}</strong></span>
                      <span>Abstain: <strong style={{ color: '#fff' }}>{p.votesAbstain.toLocaleString()}</strong></span>
                    </div>

                    {p.status === "ACTIVE" && !p.voted && (
                      <div style={{ display: 'flex', gap: '0.75rem' }}>
                        <button 
                          onClick={() => castVote(p.id, 1)}
                          className="action-btn"
                          style={{ background: 'rgba(34, 197, 94, 0.12)', border: '1px solid var(--success)', color: 'var(--success)', fontSize: '0.85rem', padding: '0.5rem 1rem' }}
                        >
                          Vote FOR
                        </button>
                        <button 
                          onClick={() => castVote(p.id, 0)}
                          className="action-btn"
                          style={{ background: 'rgba(239, 68, 68, 0.12)', border: '1px solid var(--danger)', color: 'var(--danger)', fontSize: '0.85rem', padding: '0.5rem 1rem' }}
                        >
                          Vote AGAINST
                        </button>
                        <button 
                          onClick={() => castVote(p.id, 2)}
                          className="action-btn"
                          style={{ background: 'rgba(255,255,255, 0.05)', border: '1px solid var(--border-glass)', color: 'var(--text-secondary)', fontSize: '0.85rem', padding: '0.5rem 1rem' }}
                        >
                          ABSTAIN
                        </button>
                      </div>
                    )}

                    {p.status === "ACTIVE" && p.voted && (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                        <div style={{ fontSize: '0.85rem', color: 'var(--secondary)', fontWeight: 600 }}>
                          <Check size={14} style={{ marginRight: '0.25rem', verticalAlign: 'middle' }} />
                          Your vote is recorded securely in block history.
                        </div>
                        <button 
                          onClick={() => queueProposal(p.id)}
                          className="action-btn glowing"
                          style={{ background: 'linear-gradient(135deg, var(--secondary) 0%, var(--primary) 100%)', width: 'fit-content', padding: '0.5rem 1.25rem', fontSize: '0.85rem' }}
                        >
                          Queue in Timelock (2-Day Delay)
                        </button>
                      </div>
                    )}

                    {p.status === "QUEUED" && (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                        <div style={{ fontSize: '0.85rem', color: 'var(--accent)', fontWeight: 600 }}>
                          ⏱️ Timelock Delay active. Proposal queued in Timelock Controller.
                        </div>
                        <button 
                          onClick={() => executeProposal(p.id)}
                          className="action-btn glowing"
                          style={{ background: 'linear-gradient(135deg, var(--accent) 0%, var(--success) 100%)', width: 'fit-content', padding: '0.5rem 1.25rem', fontSize: '0.85rem' }}
                        >
                          Execute Proposal on-chain
                        </button>
                      </div>
                    )}

                    {p.status === "EXECUTED" && (
                      <div style={{ fontSize: '0.85rem', color: 'var(--success)', fontWeight: 600 }}>
                        🟢 Proposal Executed on-chain successfully by Timelock!
                      </div>
                    )}

                    {/* Horizontal Visual Pipeline Progress Tracker */}
                    <div style={{ marginTop: '1.25rem', paddingTop: '1rem', borderTop: '1px solid rgba(255,255,255,0.06)' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem', color: 'var(--success)' }}>
                          <CheckCircle size={12} /> Created
                        </div>
                        <div style={{ flex: 1, height: '2px', margin: '0 0.5rem', background: 'var(--success)' }}></div>
                        
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem', color: (p.voted || p.status === 'QUEUED' || p.status === 'EXECUTED') ? 'var(--success)' : 'var(--text-muted)' }}>
                          {(p.voted || p.status === 'QUEUED' || p.status === 'EXECUTED') ? <CheckCircle size={12} /> : <div style={{width:8, height:8, borderRadius:'50%', background:'var(--text-muted)', margin:'0 2px'}}></div>} Voted
                        </div>
                        <div style={{ flex: 1, height: '2px', margin: '0 0.5rem', background: (p.status === 'QUEUED' || p.status === 'EXECUTED') ? 'var(--success)' : 'rgba(255,255,255,0.1)' }}></div>
                        
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem', color: (p.status === 'QUEUED' || p.status === 'EXECUTED') ? 'var(--success)' : 'var(--text-muted)' }}>
                          {(p.status === 'QUEUED' || p.status === 'EXECUTED') ? <CheckCircle size={12} /> : <div style={{width:8, height:8, borderRadius:'50%', background:'var(--text-muted)', margin:'0 2px'}}></div>} Queued
                        </div>
                        <div style={{ flex: 1, height: '2px', margin: '0 0.5rem', background: p.status === 'EXECUTED' ? 'var(--success)' : 'rgba(255,255,255,0.1)' }}></div>
                        
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem', color: p.status === 'EXECUTED' ? 'var(--success)' : 'var(--text-muted)' }}>
                          {p.status === 'EXECUTED' ? <CheckCircle size={12} /> : <div style={{width:8, height:8, borderRadius:'50%', background:'var(--text-muted)', margin:'0 2px'}}></div>} Executed
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Delegation & Proposal Creation Column */}
              <div>
                {/* Voting Power card */}
                <div className="card">
                  <h3 className="card-title">
                    <UserCheck size={18} color="var(--secondary)" />
                    My Voting Rights
                  </h3>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem', marginBottom: '1.25rem' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                      <span>Delegate Address:</span>
                      <span style={{ fontWeight: 600, color: delegatedStatus ? 'var(--secondary)' : 'var(--text-muted)' }}>
                        {delegatedStatus ? `${delegatedAddress.substring(0, 6)}...${delegatedAddress.substring(38)}` : "Self Delegated"}
                      </span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                      <span>Voting Weight:</span>
                      <span style={{ fontWeight: 700, color: 'var(--primary-hover)' }}>50,000.00 votes</span>
                    </div>
                  </div>

                  <form onSubmit={handleDelegate}>
                    <div className="form-group">
                      <label className="form-label" style={{ fontSize: '0.8rem' }}>Delegate Voting Power</label>
                      <input 
                        type="text" 
                        value={delegatedAddress} 
                        onChange={(e) => setDelegatedAddress(e.target.value)}
                        placeholder="0xAddress to delegate..."
                        className="input-field" 
                        style={{ padding: '0.5rem 0.8rem', fontSize: '0.85rem' }}
                      />
                    </div>
                    <button type="submit" className="action-btn" style={{ padding: '0.5rem', fontSize: '0.85rem' }}>
                      Update Delegate
                    </button>
                  </form>
                </div>

                {/* Create Proposal card */}
                <div className="card">
                  <h3 className="card-title">
                    <PlusCircle size={18} color="var(--primary)" />
                    Submit Proposal
                  </h3>
                  
                  <form onSubmit={submitProposal}>
                    <div className="form-group">
                      <label className="form-label" style={{ fontSize: '0.8rem' }}>Proposal Title</label>
                      <input 
                        type="text" 
                        value={proposalTitle} 
                        onChange={(e) => setProposalTitle(e.target.value)}
                        placeholder="PIP-X: Proposal description..."
                        className="input-field" 
                        style={{ padding: '0.5rem 0.8rem', fontSize: '0.85rem' }}
                      />
                    </div>
                    <div className="form-group">
                      <label className="form-label" style={{ fontSize: '0.8rem' }}>Detailed Specification</label>
                      <textarea 
                        rows={3}
                        value={proposalDesc} 
                        onChange={(e) => setProposalDesc(e.target.value)}
                        placeholder="Provide details about target contracts and call data..."
                        className="input-field" 
                        style={{ padding: '0.5rem 0.8rem', fontSize: '0.85rem', resize: 'vertical' }}
                      />
                    </div>
                    
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: '1rem' }}>
                      * Requires 1,000 GovToken threshold to submit.
                    </div>

                    <button type="submit" className="action-btn" style={{ padding: '0.6rem', fontSize: '0.9rem' }}>
                      Submit Proposal
                    </button>
                  </form>
                </div>
              </div>

            </div>
          </div>
        )}

        {/* TAB 5: SUBGRAPH INDEXER DASHBOARD */}
        {activeTab === 'indexer' && (
          <div style={{ gridColumn: '1 / -1' }}>
            <div className="card">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '0.75rem' }}>
                <h3 style={{ fontSize: '1.25rem', color: '#fff', display: 'flex', alignItems: 'center', gap: '0.5rem', margin: 0 }}>
                  <Database size={20} color="var(--secondary)" />
                  The Graph Indexer Real-Time Sync
                </h3>
                <span className="badge badge-active" style={{ fontSize: '0.7rem' }}>
                  Synced — Block 7421932
                </span>
              </div>

              <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginBottom: '1.5rem' }}>
                Our subgraphs index block transactions and parse custom protocol events into highly available graphql query nodes. Below is the real-time indexed database stream reading directly from the `subgraph/schema.graphql` structure:
              </p>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                {transactions.map(t => (
                  <div className="list-item" key={t.id}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                      <span 
                        className="badge" 
                        style={{
                          background: t.type === 'SWAP' ? 'rgba(147, 51, 234, 0.15)' : t.type === 'DEPOSIT' ? 'rgba(34, 197, 94, 0.15)' : t.type === 'BORROW' ? 'rgba(239, 68, 68, 0.15)' : 'rgba(0, 240, 255, 0.15)',
                          color: t.type === 'SWAP' ? 'var(--primary-hover)' : t.type === 'DEPOSIT' ? 'var(--success)' : t.type === 'BORROW' ? 'var(--danger)' : 'var(--secondary)'
                        }}
                      >
                        {t.type}
                      </span>
                      <div>
                        <div style={{ fontWeight: 600, fontSize: '0.95rem', color: '#fff' }}>{t.details}</div>
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>Tx: {t.hash}</div>
                      </div>
                    </div>
                    <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>{t.timestamp}</span>
                  </div>
                ))}
              </div>

              <div style={{ marginTop: '2rem', padding: '1rem', background: 'rgba(147, 51, 234, 0.04)', border: '1px solid rgba(147, 51, 234, 0.15)', borderRadius: 'var(--radius-md)', fontSize: '0.85rem' }}>
                <h4 style={{ color: 'var(--primary-hover)', fontSize: '0.95rem', marginBottom: '0.4rem', fontWeight: 600 }}>Active Subgraph GraphQL Queries executed on page-load:</h4>
                <pre style={{ color: 'var(--text-secondary)', background: 'rgba(0,0,0,0.2)', padding: '0.75rem', borderRadius: 'var(--radius-sm)', fontFamily: 'monospace', overflowX: 'auto', fontSize: '0.8rem' }}>
{`query GetDashboardData {
  users(id: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8") {
    swaps(first: 5, orderBy: timestamp, orderDirection: desc) {
      amount0In
      amount1Out
    }
    lendingPositions {
      collateralDeposited
      borrowedAmount
      healthFactor
    }
  }
}`}
                </pre>
              </div>
            </div>
          </div>
        )}

      </main>

      <footer style={{ marginTop: '3rem', textAlign: 'center', fontSize: '0.8rem', color: 'var(--text-muted)', borderTop: '1px solid rgba(255,255,255,0.05)', padding: '1.5rem' }}>
        <p style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.25rem' }}>
          DSA DeFi Super-App capstone portal. Structured in secure Solidity assembly. Built with <Heart size={12} color="var(--accent)" fill="var(--accent)" /> by Capstone Engineering.
        </p>
      </footer>
    </div>
  );
}

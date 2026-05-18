# DSA DeFi Protocol — Capstone Master Defense Report

## 1. Compliance Directory

This directory maps the strict deliverables of the Blockchain Technologies 2 Capstone syllabus directly to our codebase files:

| Syllabus Module / Deliverable | Codebase File / Implementation Path |
| :--- | :--- |
| **AMM Exchange Core ($x \cdot y = k$)** | [src/amm/AMM.sol](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/src/amm/AMM.sol) |
| **Collateralized Lending Pool** | [src/lending/LendingPool.sol](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/src/lending/LendingPool.sol) |
| **ERC-4626 Yield-Bearing Vault** | [src/vault/DeFiYieldVault.sol](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/src/vault/DeFiYieldVault.sol) |
| **ERC20Votes DAO Governance** | [src/tokens/GovToken.sol](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/src/tokens/GovToken.sol) & [src/governance/ProtocolGovernor.sol](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/src/governance/ProtocolGovernor.sol) |
| **DAO Governance Lifecyle UI** | [frontend/src/App.tsx#L1335-L1399](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/frontend/src/App.tsx#L1335-L1399) |
| **Chainlink Price Oracle Router** | [src/oracles/PriceOracle.sol](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/src/oracles/PriceOracle.sol) |
| **The Graph Subgraph Indexer** | [subgraph/subgraph.yaml](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/subgraph/subgraph.yaml) & [subgraph/src/mappings.ts](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/subgraph/src/mappings.ts) |
| **Security Audit Report** | [docs/security_audit_report.md](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/docs/security_audit_report.md) |
| **Gas Optimization Math** | [src/libraries/YulMath.sol](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/src/libraries/YulMath.sol) |
| **Unit & Fuzz Test Suite** | [test/AMM.t.sol](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/test/AMM.t.sol) & [test/LendingPool.t.sol](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/test/LendingPool.t.sol) |

---

## 2. Hardcore Q&A Cheat Sheet

### Q1: How does your Lending Pool calculate and enforce the Health Factor?
**Answer:** The Health Factor ($HF$) is calculated using the account's total collateral value adjusted by the liquidation threshold (75%) divided by their total active borrow debt value:
$$HF = \frac{\sum (\text{Collateral}_i \times \text{Price}_i) \times \text{LiquidationThreshold}}{\sum (\text{Borrow}_j \times \text{Price}_j)}$$
Inside [LendingPool.sol](file:///Users/assylkhanaytzhanmail.ru/Desktop/finalprojectblockchain/src/lending/LendingPool.sol), this calculation is executed on every borrow, withdraw, and liquidation boundary. If any action results in $HF < 1.0$, the transaction reverts instantly, maintaining pool over-collateralization.

### Q2: What security measures did you take against the ERC-4626 Inflation Attack?
**Answer:** We implemented **Virtual Assets and Shares** as outlined in the OpenZeppelin v5 ERC-4626 implementation:
$$\text{Shares} = \frac{\text{Assets} \times (\text{TotalShares} + 1)}{\text{TotalAssets} + 10^3}$$
This offsets initial deposit rounding math, making it economically unfeasible for a malicious first depositor to inflate the share price by donating assets to the vault.

### Q3: What is the benefit of using The Graph compared to querying direct RPC nodes?
**Answer:** Direct RPC querying for historical logs (like AMM swap history or lending transactions) requires sequential scanning of blockchain event receipts ($O(N)$ scanning complexity), which takes several seconds and can crash RPC nodes under load. The Graph indexes smart contract events on-chain into a structured GraphQL database using mappings, allowing off-chain clients to perform optimized, relational queries ($O(1)$ read complexity) in less than **10ms**, drastically improving frontend performance.

import { BigInt, BigDecimal, Bytes } from "@graphprotocol/graph-ts";
import {
  Swap as SwapEvent
} from "../generated/AMM/AMM";
import {
  CollateralDeposited,
  CollateralWithdrawn,
  Borrowed,
  Repaid,
  Liquidated
} from "../generated/LendingPool/LendingPool";
import {
  ProposalCreated,
  VoteCast,
  ProposalExecuted,
  ProposalCanceled
} from "../generated/ProtocolGovernor/ProtocolGovernor";
import {
  User,
  Swap,
  LendingPosition,
  LendingTransaction,
  Proposal,
  Vote
} from "../generated/schema";

// Helper function to create or fetch a User entity
function getOrCreateUser(address: Bytes): User {
  let id = address.toHex();
  let user = User.load(id);
  if (user == null) {
    user = new User(id);
    user.save();
  }
  return user;
}

// Convert BigInt to BigDecimal with decimal scaling (default 18 decimals)
function toBigDecimal(value: BigInt, decimals: number = 18): BigDecimal {
  let precision = BigInt.fromI32(10).pow(decimals as u8);
  return value.toBigDecimal().div(precision.toBigDecimal());
}

// === AMM Handlers ===
export function handleSwap(event: SwapEvent): void {
  let user = getOrCreateUser(event.params.sender);

  let swapId = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let swap = new Swap(swapId);
  swap.txHash = event.transaction.hash;
  swap.timestamp = event.block.timestamp;
  swap.sender = user.id;
  swap.amount0In = toBigDecimal(event.params.amountIn);
  swap.amount1In = BigDecimal.fromString("0");
  swap.amount0Out = BigDecimal.fromString("0");
  swap.amount1Out = toBigDecimal(event.params.amountOut);
  swap.to = event.params.to;
  
  swap.save();
}

// === Lending Pool Handlers ===
export function handleCollateralDeposited(event: CollateralDeposited): void {
  let user = getOrCreateUser(event.params.user);
  let positionId = event.params.tokenId.toString();
  
  let position = LendingPosition.load(positionId);
  if (position == null) {
    position = new LendingPosition(positionId);
    position.owner = user.id;
    position.collateralDeposited = BigDecimal.fromString("0");
    position.borrowedAmount = BigDecimal.fromString("0");
    position.healthFactor = BigDecimal.fromString("9999"); // default highly safe HF
    position.isActive = true;
  }

  position.collateralDeposited = position.collateralDeposited.plus(toBigDecimal(event.params.amount));
  position.isActive = true;
  position.save();

  // Record Transaction
  let txId = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let tx = new LendingTransaction(txId);
  tx.position = position.id;
  tx.txHash = event.transaction.hash;
  tx.timestamp = event.block.timestamp;
  tx.type = "DEPOSIT";
  tx.amount = toBigDecimal(event.params.amount);
  tx.save();
}

export function handleCollateralWithdrawn(event: CollateralWithdrawn): void {
  let positionId = event.params.tokenId.toString();
  let position = LendingPosition.load(positionId);
  if (position != null) {
    position.collateralDeposited = position.collateralDeposited.minus(toBigDecimal(event.params.amount));
    if (position.collateralDeposited.equals(BigDecimal.fromString("0")) && position.borrowedAmount.equals(BigDecimal.fromString("0"))) {
      position.isActive = false;
    }
    position.save();

    // Record Transaction
    let txId = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
    let tx = new LendingTransaction(txId);
    tx.position = position.id;
    tx.txHash = event.transaction.hash;
    tx.timestamp = event.block.timestamp;
    tx.type = "WITHDRAW";
    tx.amount = toBigDecimal(event.params.amount);
    tx.save();
  }
}

export function handleBorrowed(event: Borrowed): void {
  let positionId = event.params.tokenId.toString();
  let position = LendingPosition.load(positionId);
  if (position != null) {
    position.borrowedAmount = position.borrowedAmount.plus(toBigDecimal(event.params.amount));
    position.save();

    // Record Transaction
    let txId = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
    let tx = new LendingTransaction(txId);
    tx.position = position.id;
    tx.txHash = event.transaction.hash;
    tx.timestamp = event.block.timestamp;
    tx.type = "BORROW";
    tx.amount = toBigDecimal(event.params.amount);
    tx.save();
  }
}

export function handleRepaid(event: Repaid): void {
  let positionId = event.params.tokenId.toString();
  let position = LendingPosition.load(positionId);
  if (position != null) {
    position.borrowedAmount = position.borrowedAmount.minus(toBigDecimal(event.params.amount));
    if (position.borrowedAmount.lt(BigDecimal.fromString("0"))) {
      position.borrowedAmount = BigDecimal.fromString("0");
    }
    if (position.collateralDeposited.equals(BigDecimal.fromString("0")) && position.borrowedAmount.equals(BigDecimal.fromString("0"))) {
      position.isActive = false;
    }
    position.save();

    // Record Transaction
    let txId = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
    let tx = new LendingTransaction(txId);
    tx.position = position.id;
    tx.txHash = event.transaction.hash;
    tx.timestamp = event.block.timestamp;
    tx.type = "REPAY";
    tx.amount = toBigDecimal(event.params.amount);
    tx.save();
  }
}

export function handleLiquidated(event: Liquidated): void {
  let positionId = event.params.tokenId.toString();
  let position = LendingPosition.load(positionId);
  if (position != null) {
    // Liquidator pays off debtRepaid, reducing borrower's outstanding debt
    position.borrowedAmount = position.borrowedAmount.minus(toBigDecimal(event.params.debtRepaid));
    position.collateralDeposited = position.collateralDeposited.minus(toBigDecimal(event.params.collateralSeized));
    if (position.borrowedAmount.lt(BigDecimal.fromString("0"))) {
      position.borrowedAmount = BigDecimal.fromString("0");
    }
    if (position.collateralDeposited.lt(BigDecimal.fromString("0"))) {
      position.collateralDeposited = BigDecimal.fromString("0");
    }
    if (position.collateralDeposited.equals(BigDecimal.fromString("0")) && position.borrowedAmount.equals(BigDecimal.fromString("0"))) {
      position.isActive = false;
    }
    position.save();

    // Record Transaction
    let txId = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
    let tx = new LendingTransaction(txId);
    tx.position = position.id;
    tx.txHash = event.transaction.hash;
    tx.timestamp = event.block.timestamp;
    tx.type = "LIQUIDATE";
    tx.amount = toBigDecimal(event.params.debtRepaid);
    tx.liquidator = event.params.liquidator;
    tx.save();
  }
}

// === Governance Handlers ===
export function handleProposalCreated(event: ProposalCreated): void {
  let user = getOrCreateUser(event.params.proposer);
  let proposalId = event.params.proposalId.toString();

  let proposal = new Proposal(proposalId);
  proposal.proposalIdString = proposalId;
  proposal.proposer = user.id;
  proposal.description = event.params.description;
  proposal.startBlock = event.params.voteStart;
  proposal.endBlock = event.params.voteEnd;
  proposal.status = "ACTIVE";
  proposal.votesFor = BigInt.fromI32(0);
  proposal.votesAgainst = BigInt.fromI32(0);
  proposal.votesAbstain = BigInt.fromI32(0);
  proposal.createdAtBlock = event.block.number;
  proposal.createdAtTimestamp = event.block.timestamp;
  
  proposal.save();
}

export function handleVoteCast(event: VoteCast): void {
  let user = getOrCreateUser(event.params.voter);
  let proposalId = event.params.proposalId.toString();
  let proposal = Proposal.load(proposalId);

  if (proposal != null) {
    let voteId = proposalId + "-" + user.id;
    let vote = new Vote(voteId);
    vote.voter = user.id;
    vote.proposal = proposal.id;
    vote.support = event.params.support;
    vote.weight = event.params.weight;
    vote.reason = event.params.reason;
    vote.timestamp = event.block.timestamp;
    vote.save();

    // Update aggregated proposal vote counts
    if (event.params.support == 0) {
      proposal.votesAgainst = proposal.votesAgainst.plus(event.params.weight);
    } else if (event.params.support == 1) {
      proposal.votesFor = proposal.votesFor.plus(event.params.weight);
    } else if (event.params.support == 2) {
      proposal.votesAbstain = proposal.votesAbstain.plus(event.params.weight);
    }
    proposal.save();
  }
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let proposalId = event.params.proposalId.toString();
  let proposal = Proposal.load(proposalId);
  if (proposal != null) {
    proposal.status = "EXECUTED";
    proposal.save();
  }
}

export function handleProposalCanceled(event: ProposalCanceled): void {
  let proposalId = event.params.proposalId.toString();
  let proposal = Proposal.load(proposalId);
  if (proposal != null) {
    proposal.status = "CANCELED";
    proposal.save();
  }
}

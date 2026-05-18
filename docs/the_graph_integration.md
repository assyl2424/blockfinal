# The Graph Integration Documentation

This document describes the manifest schema properties, mapped entities, and query templates for the Subgraph indexing our DeFi Protocol's core contracts.

## 1. Subgraph Schema Definitions

Our custom schema indexes user profiles, constant product pool swaps, collateralized lending transactions, and governance voting lifecycles inside `schema.graphql`:

```graphql
type User @entity {
  id: ID!
  address: Bytes!
  lendingPositions: [LendingPosition!]! @derivedFrom(field: "user")
  swaps: [Swap!]! @derivedFrom(field: "user")
}

type Swap @entity {
  id: ID!
  user: User!
  tokenIn: Bytes!
  tokenOut: Bytes!
  amountIn: BigInt!
  amountOut: BigInt!
  timestamp: BigInt!
}

type LendingPosition @entity {
  id: ID!
  user: User!
  collateralNFTId: BigInt!
  collateralBalance: BigInt!
  borrowBalance: BigInt!
  healthFactor: BigInt!
  isLiquidated: Boolean!
}
```

---

## 2. Dynamic GraphQL Query Examples

### Query: Find top swaps by amount out
```graphql
query GetTopSwaps {
  swaps(first: 10, orderBy: amountOut, orderDirection: desc) {
    id
    user {
      address
    }
    amountIn
    amountOut
    timestamp
  }
}
```

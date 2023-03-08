# BondAggregator

*Oighty, Zeus, Potted Meat, indigo*

> Bond Aggregator

Bond Aggregator Contract

*Bond Protocol is a permissionless system to create Olympus-style bond markets      for any token pair. The markets do not require maintenance and will manage      bond prices based on activity. Bond issuers create BondMarkets that pay out      a Payout Token in exchange for deposited Quote Tokens. Users can purchase      future-dated Payout Tokens with Quote Tokens at the current market price and      receive Bond Tokens to represent their position while their bond vests.      Once the Bond Tokens vest, they can redeem it for the Quote Tokens.The Aggregator contract keeps a unique set of market IDs across multiple      Tellers and Auctioneers. Additionally, it aggregates market data from      multiple Auctioneers in convenient view functions for front-end interfaces.      The Aggregator contract should be deployed first since Tellers, Auctioneers, and      Callbacks all require it in their constructors.*

## Methods

### auctioneers

```solidity
function auctioneers(uint256) external view returns (contract IBondAuctioneer)
```

Approved auctioneers



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IBondAuctioneer | undefined |

### authority

```solidity
function authority() external view returns (contract Authority)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract Authority | undefined |

### currentCapacity

```solidity
function currentCapacity(uint256 id_) external view returns (uint256)
```

Returns current capacity of a market



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### findMarketFor

```solidity
function findMarketFor(address payout_, address quote_, uint256 amountIn_, uint256 minAmountOut_, uint256 maxExpiry_) external view returns (uint256)
```

Returns the market ID with the highest current payoutToken payout for depositing quoteToken



#### Parameters

| Name | Type | Description |
|---|---|---|
| payout_ | address | Address of payout token |
| quote_ | address | Address of quote token |
| amountIn_ | uint256 | Amount of quote tokens to deposit |
| minAmountOut_ | uint256 | Minimum amount of payout tokens to receive as payout |
| maxExpiry_ | uint256 | Latest acceptable vesting timestamp for bond                         Inputting the zero address will take into account just the protocol fee. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getAuctioneer

```solidity
function getAuctioneer(uint256 id_) external view returns (contract IBondAuctioneer)
```

Get the auctioneer for the provided market ID



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of Market |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IBondAuctioneer | undefined |

### getTeller

```solidity
function getTeller(uint256 id_) external view returns (contract IBondTeller)
```

Returns the Teller that services the market ID



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IBondTeller | undefined |

### isInstantSwap

```solidity
function isInstantSwap(uint256 id_) external view returns (bool)
```

Does market send payout immediately



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | Market ID to search for |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### isLive

```solidity
function isLive(uint256 id_) external view returns (bool)
```

Is a given market accepting deposits



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of market |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### liveMarketsBetween

```solidity
function liveMarketsBetween(uint256 firstIndex_, uint256 lastIndex_) external view returns (uint256[])
```

Returns array of active market IDs within a range

*Should be used if length exceeds max to query entire array*

#### Parameters

| Name | Type | Description |
|---|---|---|
| firstIndex_ | uint256 | undefined |
| lastIndex_ | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256[] | undefined |

### liveMarketsBy

```solidity
function liveMarketsBy(address owner_) external view returns (uint256[])
```

Returns an array of all active market IDs for a given owner



#### Parameters

| Name | Type | Description |
|---|---|---|
| owner_ | address | Address of owner to query by |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256[] | undefined |

### liveMarketsFor

```solidity
function liveMarketsFor(address token_, bool isPayout_) external view returns (uint256[])
```

Returns an array of all active market IDs for a given quote token



#### Parameters

| Name | Type | Description |
|---|---|---|
| token_ | address | Address of token to query by |
| isPayout_ | bool | If true, search by payout token, else search for quote token |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256[] | undefined |

### marketCounter

```solidity
function marketCounter() external view returns (uint256)
```

Counter for bond markets on approved auctioneers




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### marketPrice

```solidity
function marketPrice(uint256 id_) external view returns (uint256)
```

Calculate current market price of payout token in quote tokens

*Accounts for debt and control variable decay since last deposit (vs _marketPrice())*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of market |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Price for market (see the specific auctioneer for units) |

### marketScale

```solidity
function marketScale(uint256 id_) external view returns (uint256)
```

Scale value to use when converting between quote token and payout token amounts with marketPrice()



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of market |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Scaling factor for market in configured decimals |

### marketsFor

```solidity
function marketsFor(address payout_, address quote_) external view returns (uint256[])
```

Returns an array of all active market IDs for a given payout and quote token



#### Parameters

| Name | Type | Description |
|---|---|---|
| payout_ | address | Address of payout token |
| quote_ | address | Address of quote token |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256[] | undefined |

### marketsForPayout

```solidity
function marketsForPayout(address, uint256) external view returns (uint256)
```

Market IDs for payout token



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### marketsForQuote

```solidity
function marketsForQuote(address, uint256) external view returns (uint256)
```

Market IDs for quote token



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### marketsToAuctioneers

```solidity
function marketsToAuctioneers(uint256) external view returns (contract IBondAuctioneer)
```

Auctioneer for Market ID



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IBondAuctioneer | undefined |

### maxAmountAccepted

```solidity
function maxAmountAccepted(uint256 id_, address referrer_) external view returns (uint256)
```

Returns maximum amount of quote token accepted by the market



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of market |
| referrer_ | address | Address of referrer, used to get fees to calculate accurate payout amount.                     Inputting the zero address will take into account just the protocol fee. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### owner

```solidity
function owner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### payoutFor

```solidity
function payoutFor(uint256 amount_, uint256 id_, address referrer_) external view returns (uint256)
```

Payout due for amount of quote tokens

*Accounts for debt and control variable decay so it is up to date*

#### Parameters

| Name | Type | Description |
|---|---|---|
| amount_ | uint256 | Amount of quote tokens to spend |
| id_ | uint256 | ID of market |
| referrer_ | address | Address of referrer, used to get fees to calculate accurate payout amount.                     Inputting the zero address will take into account just the protocol fee. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | amount of payout tokens to be paid |

### registerAuctioneer

```solidity
function registerAuctioneer(contract IBondAuctioneer auctioneer_) external nonpayable
```

Register a auctioneer with the aggregatorOnly Guardian

*A auctioneer must be registered with an aggregator to create markets*

#### Parameters

| Name | Type | Description |
|---|---|---|
| auctioneer_ | contract IBondAuctioneer | Address of the Auctioneer to register |

### registerMarket

```solidity
function registerMarket(contract ERC20 payoutToken_, contract ERC20 quoteToken_) external nonpayable returns (uint256 marketId)
```

Register a new market with the aggregatorOnly registered depositories



#### Parameters

| Name | Type | Description |
|---|---|---|
| payoutToken_ | contract ERC20 | Token to be paid out by the market |
| quoteToken_ | contract ERC20 | Token to be accepted by the market |

#### Returns

| Name | Type | Description |
|---|---|---|
| marketId | uint256 | undefined |

### setAuthority

```solidity
function setAuthority(contract Authority newAuthority) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| newAuthority | contract Authority | undefined |

### setOwner

```solidity
function setOwner(address newOwner) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |



## Events

### AuthorityUpdated

```solidity
event AuthorityUpdated(address indexed user, contract Authority indexed newAuthority)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| user `indexed` | address | undefined |
| newAuthority `indexed` | contract Authority | undefined |

### OwnerUpdated

```solidity
event OwnerUpdated(address indexed user, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| user `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |



## Errors

### Aggregator_OnlyAuctioneer

```solidity
error Aggregator_OnlyAuctioneer()
```








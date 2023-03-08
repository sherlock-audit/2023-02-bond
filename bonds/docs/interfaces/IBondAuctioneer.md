# IBondAuctioneer









## Methods

### closeMarket

```solidity
function closeMarket(uint256 id_) external nonpayable
```

Disable existing bond marketMust be market owner



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of market to close |

### createMarket

```solidity
function createMarket(bytes params_) external nonpayable returns (uint256)
```

Creates a new bond market

*See specific auctioneer implementations for details on encoding the parameters.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| params_ | bytes | Configuration data needed for market creation, encoded in a bytes array |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | id              ID of new bond market |

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

### getAggregator

```solidity
function getAggregator() external view returns (contract IBondAggregator)
```

Returns the Aggregator that services the Auctioneer




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IBondAggregator | undefined |

### getMarketInfoForPurchase

```solidity
function getMarketInfoForPurchase(uint256 id_) external view returns (address owner, address callbackAddr, contract ERC20 payoutToken, contract ERC20 quoteToken, uint48 vesting, uint256 maxPayout)
```

Provides information for the Teller to execute purchases on a Market



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | Market ID |

#### Returns

| Name | Type | Description |
|---|---|---|
| owner | address |           Address of the market owner (tokens transferred from this address if no callback) |
| callbackAddr | address |    Address of the callback contract to get tokens for payouts |
| payoutToken | contract ERC20 |     Payout Token (token paid out) for the Market |
| quoteToken | contract ERC20 |      Quote Token (token received) for the Market |
| vesting | uint48 |         Timestamp or duration for vesting, implementation-dependent |
| maxPayout | uint256 |       Maximum amount of payout tokens you can purchase in one transaction |

### getTeller

```solidity
function getTeller() external view returns (contract IBondTeller)
```

Returns the Teller that services the Auctioneer




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

### marketPrice

```solidity
function marketPrice(uint256 id_) external view returns (uint256)
```

Calculate current market price of payout token in quote tokens



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of market |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Price for market in configured decimals |

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

### ownerOf

```solidity
function ownerOf(uint256 id_) external view returns (address)
```

Returns the address of the market owner



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of market |

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

### pullOwnership

```solidity
function pullOwnership(uint256 id_) external nonpayable
```

Accept ownership of a marketMust be market newOwner

*The existing owner must call pushOwnership prior to the newOwner calling this function*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | Market ID |

### purchaseBond

```solidity
function purchaseBond(uint256 id_, uint256 amount_, uint256 minAmountOut_) external nonpayable returns (uint256 payout)
```

Exchange quote tokens for a bond in a specified marketMust be teller



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of the Market the bond is being purchased from |
| amount_ | uint256 | Amount to deposit in exchange for bond (after fee has been deducted) |
| minAmountOut_ | uint256 | Minimum acceptable amount of bond to receive. Prevents frontrunning |

#### Returns

| Name | Type | Description |
|---|---|---|
| payout | uint256 |          Amount of payout token to be received from the bond |

### pushOwnership

```solidity
function pushOwnership(uint256 id_, address newOwner_) external nonpayable
```

Designate a new owner of a marketMust be market owner

*Doesn&#39;t change permissions until newOwner calls pullOwnership*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | Market ID |
| newOwner_ | address | New address to give ownership to |

### setAllowNewMarkets

```solidity
function setAllowNewMarkets(bool status_) external nonpayable
```

Change the status of the auctioneer to allow creation of new markets

*Setting to false and allowing active markets to end will sunset the auctioneer*

#### Parameters

| Name | Type | Description |
|---|---|---|
| status_ | bool | Allow market creation (true) : Disallow market creation (false) |

### setCallbackAuthStatus

```solidity
function setCallbackAuthStatus(address creator_, bool status_) external nonpayable
```

Change whether a market creator is allowed to use a callback address in their markets or notMust be guardian

*Callback is believed to be safe, but a whitelist is implemented to prevent abuse*

#### Parameters

| Name | Type | Description |
|---|---|---|
| creator_ | address | Address of market creator |
| status_ | bool | Allow callback (true) : Disallow callback (false) |

### setDefaults

```solidity
function setDefaults(uint32[6] defaults_) external nonpayable
```

Set the auctioneer defaultsMust be policy

*The defaults set here are important to avoid edge cases in market behavior, e.g. a very short market reacts doesn&#39;t tune wellOnly applies to new markets that are created after the change*

#### Parameters

| Name | Type | Description |
|---|---|---|
| defaults_ | uint32[6] | Array of default values                     1. Tune interval - amount of time between tuning adjustments                     2. Tune adjustment delay - amount of time to apply downward tuning adjustments                     3. Minimum debt decay interval - minimum amount of time to let debt decay to zero                     4. Minimum deposit interval - minimum amount of time to wait between deposits                     5. Minimum market duration - minimum amount of time a market can be created for                     6. Minimum debt buffer - the minimum amount of debt over the initial debt to trigger a market shutdown |

### setIntervals

```solidity
function setIntervals(uint256 id_, uint32[3] intervals_) external nonpayable
```

Set market intervals to different values than the defaultsMust be market owner

*Changing the intervals could cause markets to behave in unexpected way                                 tuneInterval should be greater than tuneAdjustmentDelay*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | Market ID |
| intervals_ | uint32[3] | Array of intervals (3)                                 1. Tune interval - Frequency of tuning                                 2. Tune adjustment delay - Time to implement downward tuning adjustments                                 3. Debt decay interval - Interval over which debt should decay completely |





# BondBaseSDA

*Oighty, Zeus, Potted Meat, indigo*

> Bond Sequential Dutch Auctioneer (SDA)

Bond Sequential Dutch Auctioneer Base Contract

*Bond Protocol is a system to create Olympus-style bond markets      for any token pair. The markets do not require maintenance and will manage      bond prices based on activity. Bond issuers create BondMarkets that pay out      a Payout Token in exchange for deposited Quote Tokens. Users can purchase      future-dated Payout Tokens with Quote Tokens at the current market price and      receive Bond Tokens to represent their position while their bond vests.      Once the Bond Tokens vest, they can redeem it for the Quote Tokens.The Auctioneer contract allows users to create and manage bond markets.      All bond pricing logic and market data is stored in the Auctioneer.      A Auctioneer is dependent on a Teller to serve external users and      an Aggregator to register new markets. This implementation of the Auctioneer      uses a Sequential Dutch Auction pricing system to buy a target amount of quote      tokens or sell a target amount of payout tokens over the duration of a market.*

## Methods

### adjustments

```solidity
function adjustments(uint256) external view returns (uint256 change, uint48 lastAdjustment, uint48 timeToAdjusted, bool active)
```

Control variable changes



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| change | uint256 | undefined |
| lastAdjustment | uint48 | undefined |
| timeToAdjusted | uint48 | undefined |
| active | bool | undefined |

### allowNewMarkets

```solidity
function allowNewMarkets() external view returns (bool)
```

Whether or not the auctioneer allows new markets to be created

*Changing to false will sunset the auctioneer after all active markets end*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### authority

```solidity
function authority() external view returns (contract Authority)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract Authority | undefined |

### callbackAuthorized

```solidity
function callbackAuthorized(address) external view returns (bool)
```

Whether or not the market creator is authorized to use a callback address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

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

### currentControlVariable

```solidity
function currentControlVariable(uint256 id_) external view returns (uint256)
```

Up to date control variable

*Accounts for control variable adjustment*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of market |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Control variable for market in payout token decimals |

### currentDebt

```solidity
function currentDebt(uint256 id_) external view returns (uint256)
```

Calculate debt factoring in decay

*Accounts for debt decay since last deposit*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of market |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Current debt for market in payout token decimals |

### defaultTuneAdjustment

```solidity
function defaultTuneAdjustment() external view returns (uint32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32 | undefined |

### defaultTuneInterval

```solidity
function defaultTuneInterval() external view returns (uint32)
```

Sane defaults for tuning. Can be adjusted for a specific market via setters.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32 | undefined |

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

*Accounts for debt and control variable decay since last deposit (vs _marketPrice())*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of market |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Price for market in configured decimals (see MarketParams) |

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

### markets

```solidity
function markets(uint256) external view returns (address owner, contract ERC20 payoutToken, contract ERC20 quoteToken, address callbackAddr, bool capacityInQuote, uint256 capacity, uint256 totalDebt, uint256 minPrice, uint256 maxPayout, uint256 sold, uint256 purchased, uint256 scale)
```

Main information pertaining to bond market



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| payoutToken | contract ERC20 | undefined |
| quoteToken | contract ERC20 | undefined |
| callbackAddr | address | undefined |
| capacityInQuote | bool | undefined |
| capacity | uint256 | undefined |
| totalDebt | uint256 | undefined |
| minPrice | uint256 | undefined |
| maxPayout | uint256 | undefined |
| sold | uint256 | undefined |
| purchased | uint256 | undefined |
| scale | uint256 | undefined |

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

### metadata

```solidity
function metadata(uint256) external view returns (uint48 lastTune, uint48 lastDecay, uint32 length, uint32 depositInterval, uint32 tuneInterval, uint32 tuneAdjustmentDelay, uint32 debtDecayInterval, uint256 tuneIntervalCapacity, uint256 tuneBelowCapacity, uint256 lastTuneDebt)
```

Data needed for tuning bond market



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| lastTune | uint48 | undefined |
| lastDecay | uint48 | undefined |
| length | uint32 | undefined |
| depositInterval | uint32 | undefined |
| tuneInterval | uint32 | undefined |
| tuneAdjustmentDelay | uint32 | undefined |
| debtDecayInterval | uint32 | undefined |
| tuneIntervalCapacity | uint256 | undefined |
| tuneBelowCapacity | uint256 | undefined |
| lastTuneDebt | uint256 | undefined |

### minDebtBuffer

```solidity
function minDebtBuffer() external view returns (uint32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32 | undefined |

### minDebtDecayInterval

```solidity
function minDebtDecayInterval() external view returns (uint32)
```

Minimum values for decay, deposit interval, market duration and debt buffer.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32 | undefined |

### minDepositInterval

```solidity
function minDepositInterval() external view returns (uint32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32 | undefined |

### minMarketDuration

```solidity
function minMarketDuration() external view returns (uint32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32 | undefined |

### newOwners

```solidity
function newOwners(uint256) external view returns (address)
```

New address to designate as market owner. They must accept ownership to transfer permissions.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### owner

```solidity
function owner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

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

### setAuthority

```solidity
function setAuthority(contract Authority newAuthority) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| newAuthority | contract Authority | undefined |

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

### setOwner

```solidity
function setOwner(address newOwner) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |

### terms

```solidity
function terms(uint256) external view returns (uint256 controlVariable, uint256 maxDebt, uint48 vesting, uint48 conclusion)
```

Information used to control how a bond market changes



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| controlVariable | uint256 | undefined |
| maxDebt | uint256 | undefined |
| vesting | uint48 | undefined |
| conclusion | uint48 | undefined |



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

### MarketClosed

```solidity
event MarketClosed(uint256 indexed id)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| id `indexed` | uint256 | undefined |

### MarketCreated

```solidity
event MarketCreated(uint256 indexed id, address indexed payoutToken, address indexed quoteToken, uint48 vesting, uint256 initialPrice)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| id `indexed` | uint256 | undefined |
| payoutToken `indexed` | address | undefined |
| quoteToken `indexed` | address | undefined |
| vesting  | uint48 | undefined |
| initialPrice  | uint256 | undefined |

### OwnerUpdated

```solidity
event OwnerUpdated(address indexed user, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| user `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |

### Tuned

```solidity
event Tuned(uint256 indexed id, uint256 oldControlVariable, uint256 newControlVariable)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| id `indexed` | uint256 | undefined |
| oldControlVariable  | uint256 | undefined |
| newControlVariable  | uint256 | undefined |



## Errors

### Auctioneer_AmountLessThanMinimum

```solidity
error Auctioneer_AmountLessThanMinimum()
```






### Auctioneer_BadExpiry

```solidity
error Auctioneer_BadExpiry()
```






### Auctioneer_InitialPriceLessThanMin

```solidity
error Auctioneer_InitialPriceLessThanMin()
```






### Auctioneer_InvalidCallback

```solidity
error Auctioneer_InvalidCallback()
```






### Auctioneer_InvalidParams

```solidity
error Auctioneer_InvalidParams()
```






### Auctioneer_MarketConcluded

```solidity
error Auctioneer_MarketConcluded(uint256 conclusion_)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| conclusion_ | uint256 | undefined |

### Auctioneer_MaxPayoutExceeded

```solidity
error Auctioneer_MaxPayoutExceeded()
```






### Auctioneer_NewMarketsNotAllowed

```solidity
error Auctioneer_NewMarketsNotAllowed()
```






### Auctioneer_NotAuthorized

```solidity
error Auctioneer_NotAuthorized()
```






### Auctioneer_NotEnoughCapacity

```solidity
error Auctioneer_NotEnoughCapacity()
```






### Auctioneer_OnlyMarketOwner

```solidity
error Auctioneer_OnlyMarketOwner()
```








# BondBaseCallback

*Oighty, Zeus, Potted Meat, indigo*

> Bond Callback

Bond Callback Base Contract

*Bond Protocol is a system to create Olympus-style bond markets      for any token pair. The markets do not require maintenance and will manage      bond prices based on activity. Bond issuers create BondMarkets that pay out      a Payout Token in exchange for deposited Quote Tokens. Users can purchase      future-dated Payout Tokens with Quote Tokens at the current market price and      receive Bond Tokens to represent their position while their bond vests.      Once the Bond Tokens vest, they can redeem it for the Quote Tokens.The Callback contract is an optional feature of the Bond system.      Callbacks allow issuers (market creators) to apply custom logic on receipt and      payout of tokens. The Callback must be created prior to market creation and      the address passed in as an argument. The Callback depends on the Aggregator      contract for the Auctioneer that the market is created to get market data.Without a Callback contract, payout tokens are transferred directly from      the market owner on each bond purchase (market owners must approve the      Teller serving that market for the amount of Payout Tokens equivalent to the      capacity of a market when created.*

## Methods

### amountsForMarket

```solidity
function amountsForMarket(uint256 id_) external view returns (uint256 in_, uint256 out_)
```

Returns the number of quote tokens received and payout tokens paid out for a market



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of the market |

#### Returns

| Name | Type | Description |
|---|---|---|
| in_ | uint256 |     Amount of quote tokens bonded to the market |
| out_ | uint256 |    Amount of payout tokens paid out to the market |

### approvedMarkets

```solidity
function approvedMarkets(address, uint256) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### callback

```solidity
function callback(uint256 id_, uint256 inputAmount_, uint256 outputAmount_) external nonpayable
```

Send payout tokens to Teller while allowing market owners to perform custom logic on received or paid out tokensMarket ID on Teller must be whitelisted

*Must transfer the output amount of payout tokens back to the TellerShould check that the quote tokens have been transferred to the contract in the _callback function*

#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of the market |
| inputAmount_ | uint256 | Amount of quote tokens bonded to the market |
| outputAmount_ | uint256 | Amount of payout tokens to be paid out to the market |

### deposit

```solidity
function deposit(contract ERC20 token_, uint256 amount_) external nonpayable
```

Deposit tokens to the callback and update balancesOnly callback owner



#### Parameters

| Name | Type | Description |
|---|---|---|
| token_ | contract ERC20 | Address of the token to deposit |
| amount_ | uint256 | Amount of tokens to deposit |

### owner

```solidity
function owner() external view returns (address)
```



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```



*Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.*


### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```



*Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |

### whitelist

```solidity
function whitelist(address teller_, uint256 id_) external nonpayable
```

Whitelist a teller and market ID combinationMust be callback owner



#### Parameters

| Name | Type | Description |
|---|---|---|
| teller_ | address | Address of the Teller contract which serves the market |
| id_ | uint256 | ID of the market |

### withdraw

```solidity
function withdraw(address to_, contract ERC20 token_, uint256 amount_) external nonpayable
```

Withdraw tokens from the callback and update balancesOnly callback owner



#### Parameters

| Name | Type | Description |
|---|---|---|
| to_ | address | Address of the recipient |
| token_ | contract ERC20 | Address of the token to withdraw |
| amount_ | uint256 | Amount of tokens to withdraw |



## Events

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |



## Errors

### Callback_MarketNotSupported

```solidity
error Callback_MarketNotSupported(uint256 id)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| id | uint256 | undefined |

### Callback_TokensNotReceived

```solidity
error Callback_TokensNotReceived()
```








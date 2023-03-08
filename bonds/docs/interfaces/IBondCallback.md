# IBondCallback









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





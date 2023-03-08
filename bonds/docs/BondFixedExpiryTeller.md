# BondFixedExpiryTeller

*Oighty, Zeus, Potted Meat, indigo*

> Bond Fixed Expiry Teller

Bond Fixed Expiry Teller Contract

*Bond Protocol is a permissionless system to create Olympus-style bond markets      for any token pair. The markets do not require maintenance and will manage      bond prices based on activity. Bond issuers create BondMarkets that pay out      a Payout Token in exchange for deposited Quote Tokens. Users can purchase      future-dated Payout Tokens with Quote Tokens at the current market price and      receive Bond Tokens to represent their position while their bond vests.      Once the Bond Tokens vest, they can redeem it for the Quote Tokens.The Bond Fixed Expiry Teller is an implementation of the      Bond Base Teller contract specific to handling user bond transactions      and tokenizing bond markets where all purchases vest at the same timestamp      as ERC20 tokens.*

## Methods

### FEE_DECIMALS

```solidity
function FEE_DECIMALS() external view returns (uint48)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint48 | undefined |

### authority

```solidity
function authority() external view returns (contract Authority)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract Authority | undefined |

### bondTokenImplementation

```solidity
function bondTokenImplementation() external view returns (contract ERC20BondToken)
```

ERC20BondToken reference implementation (deployed on creation to clone from)




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ERC20BondToken | undefined |

### bondTokens

```solidity
function bondTokens(contract ERC20, uint48) external view returns (contract ERC20BondToken)
```

ERC20 bond tokens (unique to a underlying and expiry)



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | contract ERC20 | undefined |
| _1 | uint48 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ERC20BondToken | undefined |

### claimFees

```solidity
function claimFees(contract ERC20[] tokens_, address to_) external nonpayable
```

Claim fees accrued for input tokens and sends to protocolMust be guardian



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokens_ | contract ERC20[] | Array of tokens to claim fees for |
| to_ | address | Address to send fees to |

### create

```solidity
function create(contract ERC20 underlying_, uint48 expiry_, uint256 amount_) external nonpayable returns (contract ERC20BondToken, uint256)
```

Deposit an ERC20 token and mint a future-dated ERC20 bond token



#### Parameters

| Name | Type | Description |
|---|---|---|
| underlying_ | contract ERC20 | ERC20 token redeemable when the bond token vests |
| expiry_ | uint48 | Timestamp at which the bond token can be redeemed for the underlying token |
| amount_ | uint256 | Amount of underlying tokens to deposit |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ERC20BondToken | Address of the ERC20 bond token received |
| _1 | uint256 | Amount of the ERC20 bond token received |

### createFeeDiscount

```solidity
function createFeeDiscount() external view returns (uint48)
```

&#39;Create&#39; function fee discount. Amount standard fee is reduced by for partners who just want to use the &#39;create&#39; function to issue bond tokens. Configurable by policy.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint48 | undefined |

### deploy

```solidity
function deploy(contract ERC20 underlying_, uint48 expiry_) external nonpayable returns (contract ERC20BondToken)
```

Deploy a new ERC20 bond token for an (underlying, expiry) pair and return its address

*ERC20 used for fixed-expiryIf a bond token exists for the (underlying, expiry) pair, it returns that address*

#### Parameters

| Name | Type | Description |
|---|---|---|
| underlying_ | contract ERC20 | ERC20 token redeemable when the bond token vests |
| expiry_ | uint48 | Timestamp at which the bond token can be redeemed for the underlying token |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ERC20BondToken | Address of the ERC20 bond token being created |

### getBondTokenForMarket

```solidity
function getBondTokenForMarket(uint256 id_) external view returns (contract ERC20BondToken)
```

Get the OlympusERC20BondToken contract corresponding to a market



#### Parameters

| Name | Type | Description |
|---|---|---|
| id_ | uint256 | ID of the market |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ERC20BondToken | ERC20BondToken contract address |

### getFee

```solidity
function getFee(address referrer_) external view returns (uint48)
```

Get current fee charged by the teller based on the combined protocol and referrer fee



#### Parameters

| Name | Type | Description |
|---|---|---|
| referrer_ | address | Address of the referrer |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint48 | Fee in basis points (3 decimal places) |

### owner

```solidity
function owner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### protocolFee

```solidity
function protocolFee() external view returns (uint48)
```

Fee paid to protocol. Configurable by policy, must be greater than 30 bps.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint48 | undefined |

### purchase

```solidity
function purchase(address recipient_, address referrer_, uint256 id_, uint256 amount_, uint256 minAmountOut_) external nonpayable returns (uint256, uint48)
```

Exchange quote tokens for a bond in a specified market



#### Parameters

| Name | Type | Description |
|---|---|---|
| recipient_ | address | Address of recipient of bond. Allows deposits for other addresses |
| referrer_ | address | Address of referrer who will receive referral fee. For frontends to fill.                         Direct calls can use the zero address for no referrer fee. |
| id_ | uint256 | ID of the Market the bond is being purchased from |
| amount_ | uint256 | Amount to deposit in exchange for bond |
| minAmountOut_ | uint256 | Minimum acceptable amount of bond to receive. Prevents frontrunning |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Amount of payout token to be received from the bond |
| _1 | uint48 | Timestamp at which the bond token can be redeemed for the underlying token |

### redeem

```solidity
function redeem(contract ERC20BondToken token_, uint256 amount_) external nonpayable
```

Redeem a fixed-expiry bond token for the underlying token (bond token must have matured)



#### Parameters

| Name | Type | Description |
|---|---|---|
| token_ | contract ERC20BondToken | Token to redeem |
| amount_ | uint256 | Amount to redeem |

### referrerFees

```solidity
function referrerFees(address) external view returns (uint48)
```

Fee paid to a front end operator. Set by the referrer, must be less than or equal to 5e4.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint48 | undefined |

### rewards

```solidity
function rewards(address, contract ERC20) external view returns (uint256)
```

Fees earned by an address, by token



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | contract ERC20 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### setProtocolFee

```solidity
function setProtocolFee(uint48 fee_) external nonpayable
```

Set protocol feeMust be guardian



#### Parameters

| Name | Type | Description |
|---|---|---|
| fee_ | uint48 | Protocol fee in basis points (3 decimal places) |

### setReferrerFee

```solidity
function setReferrerFee(uint48 fee_) external nonpayable
```

Set your fee as a referrer to the protocolFee is set for sending address



#### Parameters

| Name | Type | Description |
|---|---|---|
| fee_ | uint48 | Referrer fee in basis points (3 decimal places) |



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

### Bonded

```solidity
event Bonded(uint256 indexed id, address indexed referrer, uint256 amount, uint256 payout)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| id `indexed` | uint256 | undefined |
| referrer `indexed` | address | undefined |
| amount  | uint256 | undefined |
| payout  | uint256 | undefined |

### ERC20BondTokenCreated

```solidity
event ERC20BondTokenCreated(contract ERC20BondToken bondToken, contract ERC20 indexed underlying, uint48 indexed expiry)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| bondToken  | contract ERC20BondToken | undefined |
| underlying `indexed` | contract ERC20 | undefined |
| expiry `indexed` | uint48 | undefined |

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

### CreateFail

```solidity
error CreateFail()
```






### Teller_InvalidCallback

```solidity
error Teller_InvalidCallback()
```






### Teller_InvalidParams

```solidity
error Teller_InvalidParams()
```






### Teller_NotAuthorized

```solidity
error Teller_NotAuthorized()
```






### Teller_TokenDoesNotExist

```solidity
error Teller_TokenDoesNotExist(contract ERC20 underlying, uint48 expiry)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| underlying | contract ERC20 | undefined |
| expiry | uint48 | undefined |

### Teller_TokenNotMatured

```solidity
error Teller_TokenNotMatured(uint48 maturesOn)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| maturesOn | uint48 | undefined |

### Teller_UnsupportedToken

```solidity
error Teller_UnsupportedToken()
```








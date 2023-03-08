# BondBaseTeller

*Oighty, Zeus, Potted Meat, indigo*

> Bond Teller

Bond Teller Base Contract

*Bond Protocol is a permissionless system to create Olympus-style bond markets      for any token pair. The markets do not require maintenance and will manage      bond prices based on activity. Bond issuers create BondMarkets that pay out      a Payout Token in exchange for deposited Quote Tokens. Users can purchase      future-dated Payout Tokens with Quote Tokens at the current market price and      receive Bond Tokens to represent their position while their bond vests.      Once the Bond Tokens vest, they can redeem it for the Quote Tokens.The Teller contract handles all interactions with end users and manages tokens      issued to represent bond positions. Users purchase bonds by depositing Quote Tokens      and receive a Bond Token (token type is implementation-specific) that represents      their payout and the designated expiry. Once a bond vests, Investors can redeem their      Bond Tokens for the underlying Payout Token. A Teller requires one or more Auctioneer      contracts to be deployed to provide markets for users to purchase bonds from.*

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

### createFeeDiscount

```solidity
function createFeeDiscount() external view returns (uint48)
```

&#39;Create&#39; function fee discount. Amount standard fee is reduced by for partners who just want to use the &#39;create&#39; function to issue bond tokens. Configurable by policy.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint48 | undefined |

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

### referrerFees

```solidity
function referrerFees(address) external view returns (uint48)
```

Fee paid to a front end operator. Set by the referrer, must be less than or equal to 5e4.

*There are some situations where the fees may round down to zero if quantity of baseToken      is &lt; 1e5 wei (can happen with big price differences on small decimal tokens). This is purely      a theoretical edge case, as the bond amount would not be practical.*

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








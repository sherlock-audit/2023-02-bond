# BondFixedTermTeller

*Oighty, Zeus, Potted Meat, indigo*

> Bond Fixed Term Teller

Bond Fixed Term Teller Contract

*Bond Protocol is a permissionless system to create Olympus-style bond markets      for any token pair. The markets do not require maintenance and will manage      bond prices based on activity. Bond issuers create BondMarkets that pay out      a Payout Token in exchange for deposited Quote Tokens. Users can purchase      future-dated Payout Tokens with Quote Tokens at the current market price and      receive Bond Tokens to represent their position while their bond vests.      Once the Bond Tokens vest, they can redeem it for the Quote Tokens.The Bond Fixed Term Teller is an implementation of the      Bond Base Teller contract specific to handling user bond transactions      and tokenizing bond markets where purchases vest in a fixed amount of time      (rounded to the day) as ERC1155 tokens.*

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

### balanceOf

```solidity
function balanceOf(address, uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### balanceOfBatch

```solidity
function balanceOfBatch(address[] owners, uint256[] ids) external view returns (uint256[] balances)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| owners | address[] | undefined |
| ids | uint256[] | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| balances | uint256[] | undefined |

### batchRedeem

```solidity
function batchRedeem(uint256[] tokenIds_, uint256[] amounts_) external nonpayable
```

Redeem multiple fixed-term bond tokens for the underlying tokens (bond tokens must have matured)



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenIds_ | uint256[] | Array of bond token ids |
| amounts_ | uint256[] | Array of amounts of bond tokens to redeem |

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
function create(contract ERC20 underlying_, uint48 expiry_, uint256 amount_) external nonpayable returns (uint256, uint256)
```

Deposit an ERC20 token and mint a future-dated ERC1155 bond token



#### Parameters

| Name | Type | Description |
|---|---|---|
| underlying_ | contract ERC20 | ERC20 token redeemable when the bond token vests |
| expiry_ | uint48 | Timestamp at which the bond token can be redeemed for the underlying token |
| amount_ | uint256 | Amount of underlying tokens to deposit |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | ID of the ERC1155 bond token received |
| _1 | uint256 | Amount of the ERC1155 bond token received |

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
function deploy(contract ERC20 underlying_, uint48 expiry_) external nonpayable returns (uint256)
```

&quot;Deploy&quot; a new ERC1155 bond token for an (underlying, expiry) pair and return its address

*ERC1155 used for fixed-termIf a bond token exists for the (underlying, expiry) pair, it returns that address*

#### Parameters

| Name | Type | Description |
|---|---|---|
| underlying_ | contract ERC20 | ERC20 token redeemable when the bond token vests |
| expiry_ | uint48 | Timestamp at which the bond token can be redeemed for the underlying token |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | ID of the ERC1155 bond token being created |

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

### getTokenId

```solidity
function getTokenId(contract ERC20 underlying_, uint48 expiry_) external pure returns (uint256)
```

Get token ID from token and expiry



#### Parameters

| Name | Type | Description |
|---|---|---|
| underlying_ | contract ERC20 | undefined |
| expiry_ | uint48 | Expiry of the bond |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | ID of the bond token |

### getTokenNameAndSymbol

```solidity
function getTokenNameAndSymbol(uint256 tokenId_) external view returns (string, string)
```

Get the token name and symbol for a bond token



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId_ | uint256 | ID of the bond token |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | name        Bond token name |
| _1 | string | symbol      Bond token symbol |

### isApprovedForAll

```solidity
function isApprovedForAll(address, address) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

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
function redeem(uint256 tokenId_, uint256 amount_) external nonpayable
```

Redeem a fixed-term bond token for the underlying token (bond token must have matured)



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId_ | uint256 | ID of the bond token to redeem |
| amount_ | uint256 | Amount of bond token to redeem |

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

### safeBatchTransferFrom

```solidity
function safeBatchTransferFrom(address from, address to, uint256[] ids, uint256[] amounts, bytes data) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| ids | uint256[] | undefined |
| amounts | uint256[] | undefined |
| data | bytes | undefined |

### safeTransferFrom

```solidity
function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes data) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| id | uint256 | undefined |
| amount | uint256 | undefined |
| data | bytes | undefined |

### setApprovalForAll

```solidity
function setApprovalForAll(address operator, bool approved) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| operator | address | undefined |
| approved | bool | undefined |

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

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| interfaceId | bytes4 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### tokenMetadata

```solidity
function tokenMetadata(uint256) external view returns (bool active, contract ERC20 payoutToken, uint48 expiry, uint256 supply)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| active | bool | undefined |
| payoutToken | contract ERC20 | undefined |
| expiry | uint48 | undefined |
| supply | uint256 | undefined |



## Events

### ApprovalForAll

```solidity
event ApprovalForAll(address indexed owner, address indexed operator, bool approved)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| operator `indexed` | address | undefined |
| approved  | bool | undefined |

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

### ERC1155BondTokenCreated

```solidity
event ERC1155BondTokenCreated(uint256 tokenId, contract ERC20 indexed payoutToken, uint48 indexed expiry)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId  | uint256 | undefined |
| payoutToken `indexed` | contract ERC20 | undefined |
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

### TransferBatch

```solidity
event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| operator `indexed` | address | undefined |
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| ids  | uint256[] | undefined |
| amounts  | uint256[] | undefined |

### TransferSingle

```solidity
event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| operator `indexed` | address | undefined |
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| id  | uint256 | undefined |
| amount  | uint256 | undefined |



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








# IBondFixedTermTeller









## Methods

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

### getTokenId

```solidity
function getTokenId(contract ERC20 payoutToken_, uint48 expiry_) external pure returns (uint256)
```

Get token ID from token and expiry



#### Parameters

| Name | Type | Description |
|---|---|---|
| payoutToken_ | contract ERC20 | Payout token of bond |
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





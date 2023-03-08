# IBondFixedExpiryTeller









## Methods

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





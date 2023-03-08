# IBondTeller









## Methods

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





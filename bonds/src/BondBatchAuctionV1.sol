// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {Clone} from "clones/Clone.sol";

import {IBondBatchAuctionV1} from "./interfaces/IBondBatchAuctionV1.sol";
import {IGnosisEasyAuction} from "./interfaces/IGnosisEasyAuction.sol";
import {BondFixedExpiryTeller} from "./BondFixedExpiryTeller.sol";
import {IBondBatchAuctionFactoryV1} from "./interfaces/IBondBatchAuctionFactoryV1.sol";

import {TransferHelper} from "./lib/TransferHelper.sol";
import {FullMath} from "./lib/FullMath.sol";

/// @title Bond Batch Auction V1
/// @notice Bond Batch Auction V1 Contract (Gnosis EasyAuction Wrapper)
/// @dev The Bond Batch Auction V1 system is a clone-based, permissionless wrapper
///      around the Gnosis EasyAuction batch auction system. The purpose is to simplify
///      the creation and sale of Fixed Expiry ERC20 Bond Tokens via a batch auction mechanism.
///
///      The BondBatchAuctionV1 contract is a single-user contract that is deployed as a clone
///      from the factory to keep each user's auctions and token balances separate.
/// @author Oighty
contract BondBatchAuctionV1 is IBondBatchAuctionV1, ReentrancyGuard, Clone {
    using TransferHelper for ERC20;
    using FullMath for uint256;

    /* ========== ERRORS ========== */
    error BatchAuction_InvalidParams();
    error BatchAuction_OnlyOwner();
    error BatchAuction_AlreadySettled();
    error BatchAuction_TokenNotSupported();
    error BatchAuction_AuctionHasNotEnded();
    error BatchAuction_AlreadySettledExternally();
    error BatchAuction_NotSettledExternally();

    /* ========== EVENTS ========== */
    event BatchAuctionCreated(
        uint256 indexed auctionId_,
        address indexed owner_,
        ERC20 quoteToken_,
        ERC20 payoutToken_,
        uint256 auctionEnd
    );
    event BatchAuctionSettled(
        uint256 indexed auctionId_,
        bytes32 clearingOrder,
        uint256 quoteTokenProceeds,
        uint256 payoutTokensSold
    );

    /* ========== STATE VARIABLES ========== */

    uint256[] public auctions;
    mapping(uint256 => AuctionData) internal _auctionData;

    /* ========== CONSTRUCTOR ========== */

    constructor() {}

    /* ========== IMMUTABLE CLONE ARGS ========== */

    /// @inheritdoc IBondBatchAuctionV1
    function gnosisAuction() public pure override returns (IGnosisEasyAuction) {
        return IGnosisEasyAuction(_getArgAddress(0));
    }

    /// @inheritdoc IBondBatchAuctionV1
    function teller() public pure override returns (BondFixedExpiryTeller) {
        return BondFixedExpiryTeller(_getArgAddress(20));
    }

    /// @inheritdoc IBondBatchAuctionV1
    function factory() public pure override returns (IBondBatchAuctionFactoryV1) {
        return IBondBatchAuctionFactoryV1(_getArgAddress(40));
    }

    /// @inheritdoc IBondBatchAuctionV1
    function owner() public pure override returns (address) {
        return _getArgAddress(60);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOwner() {
        if (msg.sender != owner()) revert BatchAuction_OnlyOwner();
        _;
    }

    /* ========== AUCTION MANAGEMENT ========== */

    /// @inheritdoc IBondBatchAuctionV1
    function initiateBatchAuction(BatchAuctionParams memory batchAuctionParams_)
        external
        onlyOwner
        returns (uint256)
    {
        // Validate bond token params

        // Validate underlying token address is a contract
        // Not sufficient to ensure it's a token
        if (address(batchAuctionParams_.payoutTokenParams.underlying).code.length == 0)
            revert BatchAuction_InvalidParams();

        // Normalize bond token expiry by rounding down to the nearest day.
        // The Bond Teller does this anyways so better to validate with the rounded value.
        // Check that Bond Token Expiry >= Auction End
        if (
            (uint256(batchAuctionParams_.payoutTokenParams.expiry) / 1 days) * 1 days <
            batchAuctionParams_.auctionEnd
        ) revert BatchAuction_InvalidParams();

        // Batch auction params are validated by the EasyAuction contract
        // https://github.com/gnosis/ido-contracts/blob/bc0a4eff40b065e46cc3f21615416528efe6e8e7/contracts/EasyAuction.sol#L173

        // Deploy Bond Token (checks exist on the teller to see if it already exists)
        ERC20 payoutToken = ERC20(
            address(
                teller().deploy(
                    batchAuctionParams_.payoutTokenParams.underlying,
                    batchAuctionParams_.payoutTokenParams.expiry
                )
            )
        );

        {
            // Calculate fee for minting bond tokens
            uint256 amount = amountWithFee(uint256(batchAuctionParams_.auctionAmount)) +
                amountWithTellerFee(uint256(batchAuctionParams_.liquidityAmount));

            // Transfer tokens in from sender
            /// @dev sender needs to have approved this contract to manage the underlying token to create bond tokens with
            /// @dev this amount can be determined before calling by using the `amountWithFee` function using the auctionAmount and `amountWithTellerFee` using the liquidityAmount
            // The contract does not support underlying tokens that are fee-on-transfer tokens
            // Check balance before and after to ensure the correct amount was transferred
            uint256 balanceBefore = batchAuctionParams_.payoutTokenParams.underlying.balanceOf(
                address(this)
            );
            batchAuctionParams_.payoutTokenParams.underlying.safeTransferFrom(
                owner(),
                address(this),
                amount
            );
            if (
                batchAuctionParams_.payoutTokenParams.underlying.balanceOf(address(this)) <
                balanceBefore + amount
            ) revert BatchAuction_TokenNotSupported();

            // Approve the teller for the amount with fee and create Bond Tokens
            batchAuctionParams_.payoutTokenParams.underlying.approve(address(teller()), amount);
            teller().create(
                batchAuctionParams_.payoutTokenParams.underlying,
                batchAuctionParams_.payoutTokenParams.expiry,
                amount
            );

            // Send the bond tokens reserved to provide liquidity to the sender (if there are any)
            if (batchAuctionParams_.liquidityAmount > 0)
                payoutToken.safeTransfer(owner(), uint256(batchAuctionParams_.liquidityAmount));
        }

        {
            // Approve auction contract for bond tokens (transferred immediately after so no approval override issues)
            // We include the gnosis fee amount in the approval since initiateAuction will transfer this amount
            uint256 feeDecimals = gnosisAuction().FEE_DENOMINATOR();
            payoutToken.approve(
                address(gnosisAuction()),
                (uint256(batchAuctionParams_.auctionAmount) *
                    (gnosisAuction().feeNumerator() + feeDecimals)) / feeDecimals
            );
        }

        // Initiate Batch Auction
        uint256 auctionId = gnosisAuction().initiateAuction(
            payoutToken,
            batchAuctionParams_.quoteToken,
            batchAuctionParams_.cancelUntil,
            batchAuctionParams_.auctionEnd,
            batchAuctionParams_.auctionAmount,
            batchAuctionParams_.minimumTotalPurchased,
            batchAuctionParams_.minimumBiddingAmountPerOrder,
            batchAuctionParams_.minFundingThreshold,
            false, // no atomic closures
            batchAuctionParams_.accessManager,
            batchAuctionParams_.accessManagerData
        );

        // Store auction information
        auctions.push(auctionId);
        _auctionData[auctionId] = AuctionData({
            quoteToken: batchAuctionParams_.quoteToken,
            payoutToken: payoutToken,
            created: true,
            settled: false,
            auctionEnd: uint48(batchAuctionParams_.auctionEnd),
            payoutAmount: batchAuctionParams_.auctionAmount
        });

        // Register auction with factory
        factory().registerAuction(auctionId, batchAuctionParams_.quoteToken);

        // Return auction ID
        return auctionId;
    }

    /// @inheritdoc IBondBatchAuctionV1
    function settleBatchAuction(uint256 auctionId_) external onlyOwner returns (bytes32) {
        // Validate auction was created with this contract and hasn't been settled on this contract yet
        if (!_auctionData[auctionId_].created) revert BatchAuction_InvalidParams();
        if (_auctionData[auctionId_].settled) revert BatchAuction_AlreadySettled();

        // Validate timestamp is past auction end
        if (block.timestamp < _auctionData[auctionId_].auctionEnd)
            revert BatchAuction_AuctionHasNotEnded();

        // Validate that the auction hasn't been settled on the auction contract
        bytes32 clearingOrder = gnosisAuction().auctionData(auctionId_).clearingPriceOrder;
        if (clearingOrder != bytes32(0)) revert BatchAuction_AlreadySettledExternally();

        // Get tokens and starting balances
        AuctionData memory auction = _auctionData[auctionId_];
        uint256 qtStartBal = auction.quoteToken.balanceOf(address(this));
        uint256 ptStartBal = auction.payoutToken.balanceOf(address(this));

        // Settle auction
        clearingOrder = gnosisAuction().settleAuction(auctionId_);
        _auctionData[auctionId_].settled = true;

        // Get ending balances
        uint256 qtEndBal = auction.quoteToken.balanceOf(address(this));
        uint256 ptEndBal = auction.payoutToken.balanceOf(address(this));

        // Transfer any auction proceeds to owner
        // If the auction did not sell the minimum amount, then it will have returned the payout tokens instead and the balance change will be 0
        if (qtEndBal > qtStartBal) auction.quoteToken.safeTransfer(owner(), qtEndBal - qtStartBal);

        // Check if any payout tokens were returned, if so, transfer them to the owner
        // Owners will need to redeem these for the underlying on the fixed expiry teller.
        // We could check for this here, but it's unlikely that many vested tokens
        // will want to be redeem immediately after an auction ends.
        if (ptEndBal > ptStartBal) auction.payoutToken.safeTransfer(owner(), ptEndBal - ptStartBal);

        // Return clearing order bytes32 from EasyAuction
        return clearingOrder;
    }

    /// @inheritdoc IBondBatchAuctionV1
    function withdrawExternallySettledFunds(uint256 auctionId_) external override onlyOwner {
        AuctionData storage auction = _auctionData[auctionId_];

        // Validate auction was created with this contract and hasn't been settled yet on this contract
        if (!auction.created) revert BatchAuction_InvalidParams();
        if (auction.settled) revert BatchAuction_AlreadySettled();

        // Validate timestamp is past auction end
        if (block.timestamp < _auctionData[auctionId_].auctionEnd)
            revert BatchAuction_AuctionHasNotEnded();

        // Validate that the auction has been settled on the auction contract
        bytes32 clearingOrder = gnosisAuction().auctionData(auctionId_).clearingPriceOrder;
        if (clearingOrder == bytes32(0)) revert BatchAuction_NotSettledExternally();

        // Assume auction has already been settled externally via the public EasyAuction function
        auction.settled = true;

        // Therefore, we can just transfer the funds to the owner
        /// @dev since we don't know how many tokens were received from the auction,
        /// we just transfer all of the quote token and payout token balances.
        /// This could inadvertently transfer tokens that were sent to the contract
        /// by another auction as well, but they are all owned by the owner
        // so it doesn't matter if they are co-mingled.
        uint256 qtBal = auction.quoteToken.balanceOf(address(this));
        if (qtBal > 0) auction.quoteToken.safeTransfer(owner(), qtBal);
        uint256 ptBal = auction.payoutToken.balanceOf(address(this));
        if (ptBal > 0) auction.payoutToken.safeTransfer(owner(), ptBal);
    }

    /// @inheritdoc IBondBatchAuctionV1
    function emergencyWithdraw(ERC20 token_) external override onlyOwner {
        // Confirm that the token is a contract
        if (address(token_).code.length == 0 && address(token_) != address(0))
            revert BatchAuction_InvalidParams();

        // If token address is zero, withdraw ETH
        if (address(token_) == address(0)) {
            payable(owner()).transfer(address(this).balance);
        } else {
            token_.safeTransfer(owner(), token_.balanceOf(address(this)));
        }
    }

    /* ========== VIEW FUNCTIONS ==========*/

    /// @inheritdoc IBondBatchAuctionV1
    function numAuctions() external view override returns (uint256) {
        return auctions.length;
    }

    /// @inheritdoc IBondBatchAuctionV1
    function auctionData(uint256 auctionId_) external view override returns (AuctionData memory) {
        return _auctionData[auctionId_];
    }

    /// @inheritdoc IBondBatchAuctionV1
    function amountWithFee(uint256 auctionAmount_) public view override returns (uint256) {
        BondFixedExpiryTeller _teller = teller();
        IGnosisEasyAuction _gnosisAuction = gnosisAuction();
        uint256 tellerFeeDecimals = _teller.FEE_DECIMALS();
        uint256 easyAuctionFeeDecimals = _gnosisAuction.FEE_DENOMINATOR();
        return
            auctionAmount_
                .mulDiv(
                    easyAuctionFeeDecimals + _gnosisAuction.feeNumerator(),
                    easyAuctionFeeDecimals
                )
                .mulDivUp(
                    tellerFeeDecimals,
                    tellerFeeDecimals - (_teller.protocolFee() - _teller.createFeeDiscount())
                );
    }

    /// @inheritdoc IBondBatchAuctionV1
    function amountWithTellerFee(uint256 liquidityAmount_) public view override returns (uint256) {
        BondFixedExpiryTeller _teller = teller();
        uint256 tellerFeeDecimals = _teller.FEE_DECIMALS();
        return
            liquidityAmount_.mulDivUp(
                tellerFeeDecimals,
                tellerFeeDecimals - (_teller.protocolFee() - _teller.createFeeDiscount())
            );
    }

    /// @inheritdoc IBondBatchAuctionV1
    function isLive(uint256 auctionId_) public view override returns (bool) {
        return _auctionData[auctionId_].auctionEnd > uint48(block.timestamp);
    }

    /// @inheritdoc IBondBatchAuctionV1
    function liveAuctions(uint256 startIndex_, uint256 endIndex_)
        external
        view
        override
        returns (uint256[] memory)
    {
        // Get length of auction array and ensure endIndex is not greater than the length
        if (auctions.length < endIndex_) revert BatchAuction_InvalidParams();

        // Iterate through auctions and determine number of live auctions
        uint256 len;
        for (uint256 i = startIndex_; i < endIndex_; ++i) {
            if (isLive(auctions[i])) {
                ++len;
            }
        }

        // Initialize a dynamic array in memory with the correct length
        uint256[] memory live = new uint256[](len);
        uint256 index;
        for (uint256 j = startIndex_; j < endIndex_; ++j) {
            uint256 id = auctions[j];
            if (isLive(id)) {
                live[index] = id;
                ++index;
            }
        }

        // Return array of live auction IDs
        return live;
    }
}

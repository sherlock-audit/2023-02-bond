/// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";

import {ERC20, MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockFOTERC20} from "./utils/mocks/MockFOTERC20.sol";

import {BondFixedExpiryTeller} from "src/BondFixedExpiryTeller.sol";
import {IGnosisEasyAuction} from "src/interfaces/IGnosisEasyAuction.sol";

import {BondBatchAuctionFactoryV1} from "src/BondBatchAuctionFactoryV1.sol";
import {BondBatchAuctionV1, IBondBatchAuctionV1} from "src/BondBatchAuctionV1.sol";
import {ERC20BondToken} from "src/ERC20BondToken.sol";

import {FullMath} from "src/lib/FullMath.sol";

contract BondBatchAuctionV1Test is Test {
    using FullMath for uint256;

    BondFixedExpiryTeller public teller;
    IGnosisEasyAuction public gnosisAuction;
    BondBatchAuctionV1 public batchAuction;
    BondBatchAuctionV1 public batchAuction2;
    BondBatchAuctionFactoryV1 public batchAuctionFactory;

    IBondBatchAuctionV1.BatchAuctionParams public auctionParams;
    IBondBatchAuctionV1.BondTokenParams public bondTokenParams;

    MockERC20 public quote;
    MockERC20 public base;

    address public guardian;
    address public owner;
    address payable public alice;
    address payable public bob;
    address payable public carol;
    address payable public dave;

    uint256 forkId;

    function setUp() public {
        vm.warp(51 * 365 * 24 * 60 * 60); // Set timestamp at roughly Jan 1, 2021 (51 years since Unix epoch)

        // Setup users
        alice = payable(address(uint160(uint256(keccak256(abi.encodePacked("alice"))))));
        bob = payable(address(uint160(uint256(keccak256(abi.encodePacked("bob"))))));
        carol = payable(address(uint160(uint256(keccak256(abi.encodePacked("carol"))))));
        dave = payable(address(uint160(uint256(keccak256(abi.encodePacked("dave"))))));

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
        vm.deal(dave, 100 ether);

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(carol, "carol");
        vm.label(dave, "dave");

        // Use mainnet fork to test with actual EasyAuction contract instead of mocking locally
        // Can do the same with the FixedExpiryTeller
        forkId = vm.createFork(vm.envString("RPC_URL"));
        vm.selectFork(forkId);

        teller = BondFixedExpiryTeller(0x007FE70dc9797C4198528aE43d8195ffF82Bdc95);
        gnosisAuction = IGnosisEasyAuction(0x0b7fFc1f4AD541A4Ed16b40D8c37f0929158D101);
        guardian = 0x007BD11FCa0dAaeaDD455b51826F9a015f2f0969; // Use the guardian address from the mainnet fork to change teller configs to test fees
        owner = 0x0DA0C3e52C977Ed3cBc641fF02DD271c3ED55aFe;

        vm.label(address(teller), "teller");
        vm.label(address(gnosisAuction), "gnosisAuction");
        vm.label(guardian, "guardian");
        vm.label(owner, "owner");

        // Deploy BondBatchAuctionFactoryV1
        batchAuctionFactory = new BondBatchAuctionFactoryV1(gnosisAuction, teller);

        // Create a batch auction clone for alice
        vm.prank(alice);
        batchAuction = batchAuctionFactory.deployClone(alice);

        vm.label(address(batchAuction), "aliceBatchAuction");

        vm.prank(dave);
        batchAuction2 = batchAuctionFactory.deployClone(dave);

        vm.label(address(batchAuction2), "daveBatchAuction");

        // Create tokens and mint them to users
        quote = new MockERC20("Quote", "Q", 18);
        vm.label(address(quote), "quote");

        base = new MockERC20("Base", "B", 18);
        vm.label(address(base), "base");

        // Mint tokens to users buying from batch auction and approve gnosis auction contract
        quote.mint(bob, 1e9 ether);
        quote.mint(carol, 1e9 ether);

        vm.prank(bob);
        quote.approve(address(gnosisAuction), type(uint256).max);
        vm.prank(carol);
        quote.approve(address(gnosisAuction), type(uint256).max);

        // Mint tokens to users creating batch auctions and approve batch auction contract
        base.mint(alice, (uint256(type(uint96).max) * 202) / 100); // double for auction + liquidity amount fuzzing, pad by 1% to account for fees
        vm.prank(alice);
        base.approve(address(batchAuction), type(uint256).max);

        base.mint(dave, (uint256(type(uint96).max) * 202) / 100); // double for auction + liquidity amount fuzzing, pad by 1% to account for fees
        vm.prank(dave);
        base.approve(address(batchAuction2), type(uint256).max);

        // Setup base params for creating batch auctions
        bondTokenParams = IBondBatchAuctionV1.BondTokenParams({
            underlying: base,
            expiry: uint48(block.timestamp + 7 days)
        });

        auctionParams = IBondBatchAuctionV1.BatchAuctionParams({
            payoutTokenParams: bondTokenParams,
            quoteToken: quote,
            cancelUntil: block.timestamp + 2 days,
            auctionEnd: block.timestamp + 3 days,
            auctionAmount: uint96(1e4 ether),
            minimumTotalPurchased: uint96(1e4 ether / 2),
            minimumBiddingAmountPerOrder: 1e2 ether,
            minFundingThreshold: 1e4 ether * 100, // Minimum Price is 100 quote : 1 base
            liquidityAmount: 1e3 ether,
            accessManager: address(0), // No access manager (this is a pass-through so should work same as gnosis)
            accessManagerData: bytes("") // No access manager data
        });

        // Set fees on teller and easy auction
        vm.startPrank(guardian);
        teller.setCreateFeeDiscount(0); // 0% discount
        teller.setProtocolFee(300); // 0.3% fee
        vm.stopPrank();
        // net teller fee is 0.3%

        vm.prank(owner);
        gnosisAuction.setFeeParameters(2, owner); // 0.2%
    }

    /* ========== UTLITY FUNCTIONS ========== */
    function _encodeOrder(
        uint64 userId,
        uint96 buyAmount,
        uint96 sellAmount
    ) internal pure returns (bytes32) {
        return bytes32(abi.encodePacked(userId, buyAmount, sellAmount));
    }

    function _setFeesZero() internal {
        vm.startPrank(guardian);
        teller.setCreateFeeDiscount(0);
        teller.setProtocolFee(0);
        vm.stopPrank();

        vm.prank(owner);
        gnosisAuction.setFeeParameters(0, owner);
    }

    function _fillOrdersMoreThanCapacity(uint256 auctionId) internal returns (bytes32, bytes32) {
        // Fill some orders on the auction
        uint96[] memory minBuyAmounts = new uint96[](1);
        uint96[] memory sellAmounts = new uint96[](1);
        bytes32[] memory prevSellOrders = new bytes32[](1);

        // Buy 5e3 payout tokens with 1e6 quote tokens from bob
        minBuyAmounts[0] = 5e3 ether;
        sellAmounts[0] = 1e6 ether;
        prevSellOrders[0] = bytes32(uint256(1));

        vm.prank(bob);
        uint64 bobId = gnosisAuction.placeSellOrders(
            auctionId,
            minBuyAmounts,
            sellAmounts,
            prevSellOrders,
            bytes("")
        );

        bytes32 bobOrder = _encodeOrder(bobId, minBuyAmounts[0], sellAmounts[0]);

        // Buy 6e3 payout tokens with 9e5 quote tokens from carol (not all will fill)
        minBuyAmounts[0] = 6e3 ether;
        sellAmounts[0] = 9e5 ether;
        prevSellOrders[0] = bytes32(uint256(1));

        vm.prank(carol);
        uint64 carolId = gnosisAuction.placeSellOrders(
            auctionId,
            minBuyAmounts,
            sellAmounts,
            prevSellOrders,
            bytes("")
        );

        bytes32 carolOrder = _encodeOrder(carolId, minBuyAmounts[0], sellAmounts[0]);

        return (bobOrder, carolOrder);
    }

    function _fillOrdersLessThanCapacity(uint256 auctionId) internal returns (bytes32, bytes32) {
        // Fill some orders on the auction
        uint96[] memory minBuyAmounts = new uint96[](1);
        uint96[] memory sellAmounts = new uint96[](1);
        bytes32[] memory prevSellOrders = new bytes32[](1);

        // Buy 5e3 payout tokens with 1e6 quote tokens from bob
        minBuyAmounts[0] = 5e3 ether;
        sellAmounts[0] = 1e6 ether;
        prevSellOrders[0] = bytes32(uint256(1));

        vm.prank(bob);
        uint64 bobId = gnosisAuction.placeSellOrders(
            auctionId,
            minBuyAmounts,
            sellAmounts,
            prevSellOrders,
            bytes("")
        );

        bytes32 bobOrder = _encodeOrder(bobId, minBuyAmounts[0], sellAmounts[0]);

        // Buy 4e3 payout tokens with 8e5 quote tokens from carol, the rest won't be filled
        minBuyAmounts[0] = 4e3 ether;
        sellAmounts[0] = 8e5 ether;
        prevSellOrders[0] = bytes32(uint256(1));

        vm.prank(carol);
        uint64 carolId = gnosisAuction.placeSellOrders(
            auctionId,
            minBuyAmounts,
            sellAmounts,
            prevSellOrders,
            bytes("")
        );

        bytes32 carolOrder = _encodeOrder(carolId, minBuyAmounts[0], sellAmounts[0]);

        return (bobOrder, carolOrder);
    }

    function _claimOrders(
        uint256 auctionId,
        bytes32 bobOrder,
        bytes32 carolOrder
    ) internal returns (uint256[4] memory) {
        // Claim orders
        bytes32[] memory orders = new bytes32[](1);
        orders[0] = bobOrder;
        vm.prank(bob);
        (uint256 bobPayoutAmt, uint256 bobQuoteAmt) = gnosisAuction.claimFromParticipantOrder(
            auctionId,
            orders
        );

        orders[0] = carolOrder;
        vm.prank(carol);
        (uint256 carolPayoutAmt, uint256 carolQuoteAmt) = gnosisAuction.claimFromParticipantOrder(
            auctionId,
            orders
        );

        return [bobPayoutAmt, bobQuoteAmt, carolPayoutAmt, carolQuoteAmt];
    }

    ////////////////////////////////////////////////////////////////////////////
    //                        BATCH AUCTION CLONE TESTS                       //
    ////////////////////////////////////////////////////////////////////////////

    /* ========== BATCH AUCTION TESTS ========== */
    // [X] Create batch auction with fixed expiry tokens
    //    [X] Can create with valid params with no fees
    //    [X] Can create with valid params with fees
    //    [X] Fuzz auction and liquidity amounts
    //    [X] Can't create with invalid params
    //    [X] Able to mint extra fixed expiry tokens for liquidity that are not auctioned off
    //    [ ] Don't allow fee-on-transfer tokens for payout token
    // [X] Settle batch auctions
    //    [X] Owner is the only one who can settle their auction
    //    [X] Batch auction wrapper doesn't custody any funds if settled on contract
    //    [X] Transfer balances are correct throughout auction lifecycle
    //    [X] Completed filled auctions are settled correctly and creator receives quote tokens
    //    [X] Partially filled auctions (above the threshold) are settled correctly and creator receives quote tokens
    //    [X] Partially filled auctions (below the threshold) are settled correctly and creator receives payout tokens back
    //    [ ] Cannot settle auction that hasn't ended
    //    [ ] Cannot settle auction that has already been settled externally
    // [X] Withdraw externally settled funds
    //    [X] Only owner can withdraw funds from Batch auctions owned by clone that are settled externally on Gnosis Auction
    //    [X] Completed filled auctions are settled correctly and creator receives quote tokens
    //    [X] Partially filled auctions (above the threshold) are settled correctly and creator receives quote tokens
    //    [X] Partially filled auctions (below the threshold) are settled correctly and creator receives payout tokens back
    //    [ ] Cannot withdraw tokens for auction that hasn't ended
    //    [ ] Cannot withdraw tokens for auction that has not been settled externally
    // [X] Trapped tokens can be withdrawn by owner (emergencyWithdraw)
    //    [X] Only owner can withdraw trapped tokens
    //    [X] If no token is specified, then ETH is withdrawn
    //    [X] If token is specified, then token is withdrawn

    function test_initiateBatchAuction_createWithValidParams() public {
        // Set fees on teller and easy auction to zero as basic test
        _setFeesZero();

        // Create batch auction
        uint256 startBal = base.balanceOf(alice);

        uint256 nextId = gnosisAuction.auctionCounter() + 1;
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);
        assertEq(auctionId, nextId);

        // Verify auction data on batch auction wrapper
        assertEq(batchAuction.auctions(0), auctionId);
        IBondBatchAuctionV1.AuctionData memory auctionData = batchAuction.auctionData(auctionId);
        assertEq(address(auctionData.quoteToken), address(quote));
        ERC20BondToken payoutToken = ERC20BondToken(address(auctionData.payoutToken));
        assertEq(address(payoutToken.underlying()), address(base));
        assertEq(auctionData.created, true);
        assertEq(auctionData.settled, false);
        assertEq(auctionData.auctionEnd, auctionParams.auctionEnd);
        assertEq(auctionData.payoutAmount, auctionParams.auctionAmount);

        // Verify auction data on Gnosis EasyAuction
        IGnosisEasyAuction.AuctionData memory gnosisData = gnosisAuction.auctionData(auctionId);
        assertEq(address(gnosisData.auctioningToken), address(auctionData.payoutToken));
        assertEq(address(gnosisData.biddingToken), address(quote));
        assertEq(gnosisData.orderCancellationEndDate, auctionParams.cancelUntil);
        assertEq(gnosisData.auctionEndDate, auctionParams.auctionEnd);
        assertEq(gnosisData.minFundingThreshold, auctionParams.minFundingThreshold);
        assertEq(
            gnosisData.minimumBiddingAmountPerOrder,
            auctionParams.minimumBiddingAmountPerOrder
        );
        assertEq(gnosisAuction.auctionAccessManager(auctionId), auctionParams.accessManager);
        assertEq(gnosisAuction.auctionAccessData(auctionId), auctionParams.accessManagerData);
        assertEq(gnosisData.isAtomicClosureAllowed, false);

        // Verify balances have updated correctly

        // Alice has paid the base tokens to create the auction
        assertEq(
            base.balanceOf(alice),
            startBal - auctionParams.auctionAmount - auctionParams.liquidityAmount
        );

        // Base (underlying) tokens have been deposited to the teller to create bond tokens
        assertEq(
            base.balanceOf(address(teller)),
            auctionParams.auctionAmount + auctionParams.liquidityAmount
        );

        // Bond tokens have been deposited to the easy auction contract for the batch auction sale
        assertEq(payoutToken.balanceOf(address(gnosisAuction)), auctionParams.auctionAmount);

        // Bond tokens for liquidity have been returned to auction creator
        assertEq(payoutToken.balanceOf(alice), auctionParams.liquidityAmount);
    }

    function test_initiateBatchAuction_createWithValidParamsAndFees() public {
        // Create batch auction
        uint256 startBal = base.balanceOf(alice);

        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Verify auction data on batch auction wrapper
        assertEq(batchAuction.auctions(0), auctionId);
        IBondBatchAuctionV1.AuctionData memory auctionData = batchAuction.auctionData(auctionId);
        assertEq(address(auctionData.quoteToken), address(quote));
        ERC20BondToken payoutToken = ERC20BondToken(address(auctionData.payoutToken));
        assertEq(address(payoutToken.underlying()), address(base));
        assertEq(auctionData.created, true);
        assertEq(auctionData.settled, false);
        assertEq(auctionData.auctionEnd, auctionParams.auctionEnd);
        assertEq(auctionData.payoutAmount, auctionParams.auctionAmount);

        // Verify auction data on Gnosis EasyAuction
        IGnosisEasyAuction.AuctionData memory gnosisData = gnosisAuction.auctionData(auctionId);
        assertEq(address(gnosisData.auctioningToken), address(auctionData.payoutToken));
        assertEq(address(gnosisData.biddingToken), address(quote));
        assertEq(gnosisData.orderCancellationEndDate, auctionParams.cancelUntil);
        assertEq(gnosisData.auctionEndDate, auctionParams.auctionEnd);
        assertEq(gnosisData.minFundingThreshold, auctionParams.minFundingThreshold);
        assertEq(
            gnosisData.minimumBiddingAmountPerOrder,
            auctionParams.minimumBiddingAmountPerOrder
        );
        assertEq(gnosisAuction.auctionAccessManager(auctionId), auctionParams.accessManager);
        assertEq(gnosisAuction.auctionAccessData(auctionId), auctionParams.accessManagerData);
        assertEq(gnosisData.isAtomicClosureAllowed, false);

        // Verify balances have updated correctly

        // Alice has paid the base tokens to create the auction (including both fees)
        uint256 auctionAmount = batchAuction.amountWithFee(auctionParams.auctionAmount);
        uint256 liquidityAmount = batchAuction.amountWithTellerFee(auctionParams.liquidityAmount);
        assertEq(base.balanceOf(alice), startBal - auctionAmount - liquidityAmount);

        // Base (underlying) tokens have been deposited to the teller to create bond tokens
        assertEq(base.balanceOf(address(teller)), auctionAmount + liquidityAmount);

        // Bond tokens have been deposited to the easy auction contract for the batch auction sale
        // Amount of bond tokens is less than the amount with fee since the teller fee is deducted
        uint256 tellerFeeDecimals = teller.FEE_DECIMALS();
        uint256 amountToAuction = auctionAmount.mulDiv(
            tellerFeeDecimals - (teller.protocolFee() - teller.createFeeDiscount()),
            tellerFeeDecimals
        );
        assertEq(payoutToken.balanceOf(address(gnosisAuction)), amountToAuction);

        // Bond tokens for liquidity have been returned to auction creator
        assertEq(payoutToken.balanceOf(alice), auctionParams.liquidityAmount);
    }

    function testFuzz_initiateBatchAuction_amounts(uint96 auctionAmount_, uint96 liquidityAmount_)
        public
    {
        vm.assume(auctionAmount_ > 0); // assume auction amount is greater than 0

        // Set amounts
        auctionParams.auctionAmount = auctionAmount_;
        auctionParams.liquidityAmount = liquidityAmount_;

        // Create market and expect to pass
        vm.prank(alice);
        batchAuction.initiateBatchAuction(auctionParams);
    }

    function testRevert_initiateBatchAuction_createWithInvalidParams() public {
        // Auction amount fuzzed above

        // Payout token expiry must be after auction end (accounting for token rounding)
        auctionParams.payoutTokenParams.expiry = uint48(auctionParams.auctionEnd - 1);

        bytes memory err = abi.encodeWithSignature("BatchAuction_InvalidParams()");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.initiateBatchAuction(auctionParams);

        auctionParams.payoutTokenParams.expiry = uint48(auctionParams.auctionEnd + 1 days);

        // minimumTotalPurchased must be greater than 0
        auctionParams.minimumTotalPurchased = uint96(0);
        err = abi.encodePacked("tokens cannot be auctioned for free");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.initiateBatchAuction(auctionParams);

        auctionParams.minimumTotalPurchased = uint96(1e4 ether / 2);

        // minimumBiddingAmountPerOrder must be greater than zero
        auctionParams.minimumBiddingAmountPerOrder = 0;
        err = abi.encodePacked("minimumBiddingAmountPerOrder is not allowed to be zero");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.initiateBatchAuction(auctionParams);

        auctionParams.minimumBiddingAmountPerOrder = 1e2 ether;

        // Cancel duration must be less than auction duration
        auctionParams.cancelUntil = block.timestamp + 4 days; // auction duration is 3 days
        err = abi.encodePacked("time periods are not configured correctly");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.initiateBatchAuction(auctionParams);

        // Auction duration must be greater than 0
        auctionParams.cancelUntil = block.timestamp - 1 days;
        auctionParams.auctionEnd = block.timestamp;
        err = abi.encodePacked("auction end date must be in the future");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.initiateBatchAuction(auctionParams);
    }

    function testRevert_cannotUseFOTTokenAsUnderlying() public {
        // Create FOT token
        MockFOTERC20 fotBase = new MockFOTERC20("FOT Token", "FOT", 18, address(this), 1e3); // 1% fee

        // Set FOT token as underlying
        auctionParams.payoutTokenParams.underlying = fotBase;

        // Mint fot tokens to users creating batch auctions and approve batch auction contract
        fotBase.mint(alice, (uint256(type(uint96).max) * 202) / 100);
        vm.prank(alice);
        fotBase.approve(address(batchAuction), type(uint256).max);

        // Create auction, expect revert
        bytes memory err = abi.encodeWithSignature("BatchAuction_TokenNotSupported()");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.initiateBatchAuction(auctionParams);
    }

    function test_settleBatchAuction_onlyOwner() public {
        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Fill some orders on auction
        (, bytes32 carolOrder) = _fillOrdersMoreThanCapacity(auctionId);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Try to settle auction as non-owner, expect to revert
        vm.prank(bob);
        bytes memory err = abi.encodeWithSignature("BatchAuction_OnlyOwner()");
        vm.expectRevert(err);
        batchAuction.settleBatchAuction(auctionId);

        // Settle auction as owner, expect to pass
        vm.prank(alice);
        bytes32 clearingOrder = batchAuction.settleBatchAuction(auctionId);

        assertEq(clearingOrder, carolOrder);
    }

    function test_settleBatchAuction_quoteBalances() public {
        // Set fees on teller and easy auction to zero as basic test
        _setFeesZero();

        // Get initial balances
        uint256 aliceStartBal = quote.balanceOf(alice);
        uint256 bobStartBal = quote.balanceOf(bob);
        uint256 carolStartBal = quote.balanceOf(carol);
        uint256 gaStartBal = quote.balanceOf(address(gnosisAuction));

        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Batch auction contract should hold no quote tokens
        assertEq(quote.balanceOf(address(batchAuction)), 0);

        // Fill some orders on auction
        (bytes32 bobOrder, bytes32 carolOrder) = _fillOrdersMoreThanCapacity(auctionId);

        // Confirm balances before settlement
        assertEq(quote.balanceOf(bob), bobStartBal - 1e6 ether);
        assertEq(quote.balanceOf(carol), carolStartBal - 9e5 ether);
        assertEq(quote.balanceOf(address(gnosisAuction)), gaStartBal + 1e6 ether + 9e5 ether);
        // Batch auction contract should hold no quote tokens
        assertEq(quote.balanceOf(address(batchAuction)), 0);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Settle auction
        vm.prank(alice);
        batchAuction.settleBatchAuction(auctionId);

        // Batch auction contract should hold no quote tokens
        assertEq(quote.balanceOf(address(batchAuction)), 0);

        // Claim orders
        uint256[4] memory amounts = _claimOrders(auctionId, bobOrder, carolOrder);

        // Confirm balances after claiming
        assertEq(quote.balanceOf(alice), aliceStartBal + 1e6 ether + 5e5 ether);
        assertEq(quote.balanceOf(bob), bobStartBal - 1e6 ether);
        assertEq(quote.balanceOf(carol), carolStartBal - 5e5 ether);

        // Confirm quote token amounts claimed
        assertEq(amounts[1], 0);
        assertEq(amounts[3], 4e5 ether);

        // Batch auction contract should hold no quote tokens
        assertEq(quote.balanceOf(address(batchAuction)), 0);
    }

    function test_settleBatchAuction_payoutBalances() public {
        // Set fees on teller and easy auction to zero as basic test
        _setFeesZero();

        // Batch auction contract should hold no base tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);

        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Get initial balances (post auction creation)
        IBondBatchAuctionV1.AuctionData memory data = batchAuction.auctionData(auctionId);
        ERC20 payout = data.payoutToken;
        uint256 bobStartBal = payout.balanceOf(bob);
        uint256 carolStartBal = payout.balanceOf(carol);
        uint256 gaStartBal = payout.balanceOf(address(gnosisAuction));

        // Batch auction contract should hold no base or payout tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);
        assertEq(payout.balanceOf(address(batchAuction)), 0);

        // Fill some orders on auction
        (bytes32 bobOrder, bytes32 carolOrder) = _fillOrdersMoreThanCapacity(auctionId);

        // Batch auction contract should hold no base or payout tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);
        assertEq(payout.balanceOf(address(batchAuction)), 0);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Settle auction
        vm.prank(alice);
        batchAuction.settleBatchAuction(auctionId);

        // Batch auction contract should hold no base or payout tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);
        assertEq(payout.balanceOf(address(batchAuction)), 0);

        // Claim orders
        uint256[4] memory amounts = _claimOrders(auctionId, bobOrder, carolOrder);

        // Confirm balances after claiming
        uint256 twoThirds = (uint256(1e4 ether) * 2) / 3;
        uint256 oneThird = twoThirds / 2;

        assertEq(payout.balanceOf(bob), bobStartBal + twoThirds);
        assertEq(payout.balanceOf(carol), carolStartBal + oneThird);
        assertEq(payout.balanceOf(address(gnosisAuction)), gaStartBal - 1e4 ether + 1); // rounding error in payout calculations cause 1 wei to be remaining in the contract

        // Confirm payout token amounts claimed
        assertEq(amounts[0], twoThirds);
        assertEq(amounts[2], oneThird);

        // Batch auction contract should hold no base or payout tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);
        assertEq(payout.balanceOf(address(batchAuction)), 0);
    }

    function test_settleBatchAuction_quoteBalances_partiallyFilledValid() public {
        // Set fees on teller and easy auction to zero as basic test
        _setFeesZero();

        // Get initial balances
        uint256 aliceStartBal = quote.balanceOf(alice);
        uint256 bobStartBal = quote.balanceOf(bob);
        uint256 carolStartBal = quote.balanceOf(carol);
        uint256 gaStartBal = quote.balanceOf(address(gnosisAuction));

        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Batch auction contract should hold no quote tokens
        assertEq(quote.balanceOf(address(batchAuction)), 0);

        // Fill some orders on auction
        (bytes32 bobOrder, bytes32 carolOrder) = _fillOrdersLessThanCapacity(auctionId);

        // Confirm balances before settlement
        assertEq(quote.balanceOf(bob), bobStartBal - 1e6 ether);
        assertEq(quote.balanceOf(carol), carolStartBal - 8e5 ether);
        assertEq(quote.balanceOf(address(gnosisAuction)), gaStartBal + 1e6 ether + 8e5 ether);
        // Batch auction contract should hold no quote tokens
        assertEq(quote.balanceOf(address(batchAuction)), 0);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Settle auction
        vm.prank(alice);
        batchAuction.settleBatchAuction(auctionId);

        // Batch auction contract should hold no quote tokens
        assertEq(quote.balanceOf(address(batchAuction)), 0);

        // Claim orders
        uint256[4] memory amounts = _claimOrders(auctionId, bobOrder, carolOrder);

        // Confirm balances after claiming
        assertEq(quote.balanceOf(alice), aliceStartBal + 1e6 ether + 8e5 ether);
        assertEq(quote.balanceOf(bob), bobStartBal - 1e6 ether);
        assertEq(quote.balanceOf(carol), carolStartBal - 8e5 ether);

        // Confirm quote token amounts claimed
        assertEq(amounts[1], 0);
        assertEq(amounts[3], 0);

        // Batch auction contract should hold no quote tokens
        assertEq(quote.balanceOf(address(batchAuction)), 0);
    }

    function test_settleBatchAuction_quoteBalances_partiallyFilledNotValid() public {
        // Set fees on teller and easy auction to zero as basic test
        _setFeesZero();

        // Get initial balances
        uint256 aliceStartBal = quote.balanceOf(alice);
        uint256 bobStartBal = quote.balanceOf(bob);
        uint256 carolStartBal = quote.balanceOf(carol);
        uint256 gaStartBal = quote.balanceOf(address(gnosisAuction));

        // Increase the minimum total purchased to the full capacity
        // and the minimum funding threshold to the full capacity at 200 quote tokens per base token
        // This will cause a partially filled market to be invalid
        auctionParams.minimumTotalPurchased = uint96(1e4 ether);
        auctionParams.minFundingThreshold = 1e4 ether * 200;

        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Batch auction contract should hold no quote tokens
        assertEq(quote.balanceOf(address(batchAuction)), 0);

        // Fill some orders on auction
        (bytes32 bobOrder, bytes32 carolOrder) = _fillOrdersLessThanCapacity(auctionId);

        // Confirm balances before settlement
        assertEq(quote.balanceOf(bob), bobStartBal - 1e6 ether);
        assertEq(quote.balanceOf(carol), carolStartBal - 8e5 ether);
        assertEq(quote.balanceOf(address(gnosisAuction)), gaStartBal + 1e6 ether + 8e5 ether);
        // Batch auction contract should hold no quote tokens
        assertEq(quote.balanceOf(address(batchAuction)), 0);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Settle auction
        vm.prank(alice);
        batchAuction.settleBatchAuction(auctionId);

        // Batch auction contract should hold no quote tokens
        assertEq(quote.balanceOf(address(batchAuction)), 0);

        // Claim orders
        uint256[4] memory amounts = _claimOrders(auctionId, bobOrder, carolOrder);

        // Confirm balances after claiming
        assertEq(quote.balanceOf(alice), aliceStartBal);
        assertEq(quote.balanceOf(bob), bobStartBal);
        assertEq(quote.balanceOf(carol), carolStartBal);

        // Confirm quote token amounts claimed
        assertEq(amounts[1], 1e6 ether);
        assertEq(amounts[3], 8e5 ether);

        // Batch auction contract should hold no quote tokens
        assertEq(quote.balanceOf(address(batchAuction)), 0);
    }

    function test_settleBatchAuction_payoutBalances_partiallyFilledValid() public {
        // Set fees on teller and easy auction to zero as basic test
        _setFeesZero();

        // Batch auction contract should hold no base tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);

        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Get initial balances (post auction creation)
        IBondBatchAuctionV1.AuctionData memory data = batchAuction.auctionData(auctionId);
        ERC20 payout = data.payoutToken;
        uint256 bobStartBal = payout.balanceOf(bob);
        uint256 carolStartBal = payout.balanceOf(carol);
        uint256 gaStartBal = payout.balanceOf(address(gnosisAuction));

        // Batch auction contract should hold no base or payout tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);
        assertEq(payout.balanceOf(address(batchAuction)), 0);

        // Fill some orders on auction
        (bytes32 bobOrder, bytes32 carolOrder) = _fillOrdersLessThanCapacity(auctionId);

        // Batch auction contract should hold no base or payout tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);
        assertEq(payout.balanceOf(address(batchAuction)), 0);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Settle auction
        vm.prank(alice);
        batchAuction.settleBatchAuction(auctionId);

        // Batch auction contract should hold no base or payout tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);
        assertEq(payout.balanceOf(address(batchAuction)), 0);

        // Claim orders
        uint256[4] memory amounts = _claimOrders(auctionId, bobOrder, carolOrder);

        // Confirm balances after claiming
        uint256 fiveNinths = (uint256(1e4 ether) * 5) / 9;
        uint256 fourNinths = (fiveNinths * 4) / 5;

        assertEq(payout.balanceOf(bob), bobStartBal + fiveNinths);
        assertEq(payout.balanceOf(carol), carolStartBal + fourNinths);
        assertEq(payout.balanceOf(address(gnosisAuction)), gaStartBal - 1e4 ether + 1); // rounding error in payout calculations cause 1 wei to be remaining in the contract

        // Confirm payout token amounts claimed
        assertEq(amounts[0], fiveNinths);
        assertEq(amounts[2], fourNinths);

        // Batch auction contract should hold no base or payout tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);
        assertEq(payout.balanceOf(address(batchAuction)), 0);
    }

    function test_settleBatchAuction_payoutBalances_partiallyFilledNotValid() public {
        // Increase the minimum total purchased to the full capacity and
        // minimum funding threshold to 200 quote tokens per payout at full capacity
        // This will cause a partially filled market to be invalid
        auctionParams.minimumTotalPurchased = uint96(1e4 ether);
        auctionParams.minFundingThreshold = 1e4 ether * 250;

        // Set fees on teller and easy auction to zero as basic test
        _setFeesZero();

        // Batch auction contract should hold no base tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);

        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Get initial balances (post auction creation)
        IBondBatchAuctionV1.AuctionData memory data = batchAuction.auctionData(auctionId);
        ERC20 payout = data.payoutToken;
        uint256 bobStartBal = payout.balanceOf(bob);
        uint256 carolStartBal = payout.balanceOf(carol);

        // Batch auction contract should hold no base or payout tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);
        assertEq(payout.balanceOf(address(batchAuction)), 0);

        // Fill some orders on auction
        (bytes32 bobOrder, bytes32 carolOrder) = _fillOrdersLessThanCapacity(auctionId);

        // Batch auction contract should hold no base or payout tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);
        assertEq(payout.balanceOf(address(batchAuction)), 0);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Settle auction
        vm.prank(alice);
        batchAuction.settleBatchAuction(auctionId);

        // Batch auction contract should hold no base or payout tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);
        assertEq(payout.balanceOf(address(batchAuction)), 0);

        // Claim orders
        uint256[4] memory amounts = _claimOrders(auctionId, bobOrder, carolOrder);

        // Confirm balances after claiming
        assertEq(
            payout.balanceOf(alice),
            auctionParams.auctionAmount + auctionParams.liquidityAmount
        );
        assertEq(payout.balanceOf(bob), bobStartBal);
        assertEq(payout.balanceOf(carol), carolStartBal);
        assertEq(payout.balanceOf(address(gnosisAuction)), 0);

        // Confirm payout token amounts claimed
        assertEq(amounts[0], 0);
        assertEq(amounts[2], 0);

        // Batch auction contract should hold no base or payout tokens
        assertEq(base.balanceOf(address(batchAuction)), 0);
        assertEq(payout.balanceOf(address(batchAuction)), 0);
    }

    function testRevert_settleBatchAuction_notEnded() public {
        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Fill some orders on auction
        _fillOrdersMoreThanCapacity(auctionId);

        // Try to settle auction before auction end time, expect to revert
        bytes memory err = abi.encodeWithSignature("BatchAuction_AuctionHasNotEnded()");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.settleBatchAuction(auctionId);
    }

    function testRevert_settleBatchAuction_alreadySettled() public {
        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Fill some orders on auction
        _fillOrdersMoreThanCapacity(auctionId);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Settle auction
        vm.prank(alice);
        batchAuction.settleBatchAuction(auctionId);

        // Try to settle auction again, expect to revert
        bytes memory err = abi.encodeWithSignature("BatchAuction_AlreadySettled()");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.settleBatchAuction(auctionId);
    }

    function testRevert_settleBatchAuction_alreadySettledExternally() public {
        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Fill some orders on auction
        _fillOrdersMoreThanCapacity(auctionId);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Settle auction externally on gnosis auction as non-owner
        vm.prank(bob);
        gnosisAuction.settleAuction(auctionId);

        // Try to settle auction again, expect to revert
        bytes memory err = abi.encodeWithSignature("BatchAuction_AlreadySettledExternally()");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.settleBatchAuction(auctionId);
    }

    function testRevert_settleBatchAuction_notCreated() public {
        // Try to settle auction that was not created by batch auction contract, expect to revert
        bytes memory err = abi.encodeWithSignature("BatchAuction_InvalidParams()");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.settleBatchAuction(0);
    }

    function test_withdrawExternallySettledFunds_onlyOwner() public {
        // Set fees to zero to avoid rounding errors
        _setFeesZero();

        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Fill some orders on auction
        (, bytes32 carolOrder) = _fillOrdersMoreThanCapacity(auctionId);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Settle auction externally on gnosis auction as non-owner
        vm.prank(bob);
        bytes32 clearingOrder = gnosisAuction.settleAuction(auctionId);

        assertEq(clearingOrder, carolOrder);

        // Try to withdraw tokens settled externally as non-owner, expect to revert
        vm.prank(bob);
        bytes memory err = abi.encodeWithSignature("BatchAuction_OnlyOwner()");
        vm.expectRevert(err);
        batchAuction.withdrawExternallySettledFunds(auctionId);

        // Withdraw tokens settled externally as owner, expect to pass
        vm.prank(alice);
        batchAuction.withdrawExternallySettledFunds(auctionId);
    }

    function test_withdrawExternallySettledFunds_completelyFilledValid() public {
        // Set fees to zero to avoid rounding errors
        _setFeesZero();

        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Fill some orders on auction
        _fillOrdersMoreThanCapacity(auctionId);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Settle auction externally on gnosis auction as non-owner
        vm.prank(bob);
        gnosisAuction.settleAuction(auctionId);

        // Get balances before withdrawing
        ERC20 payout = batchAuction.auctionData(auctionId).payoutToken;
        uint256 startQuoteBal = quote.balanceOf(alice);
        uint256 startPayoutBal = payout.balanceOf(alice);

        // Withdraw tokens settled externally
        vm.prank(alice);
        batchAuction.withdrawExternallySettledFunds(auctionId);

        // Confirm balances after withdrawing
        assertEq(quote.balanceOf(alice), startQuoteBal + 1e6 ether + 5e5 ether);
        assertEq(payout.balanceOf(alice), startPayoutBal);
    }

    function test_withdrawExternallySettledFunds_partiallyFilledValid() public {
        // Set fees to zero to avoid rounding errors
        _setFeesZero();

        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Fill some orders on auction
        _fillOrdersLessThanCapacity(auctionId);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Settle auction externally on gnosis auction as non-owner
        vm.prank(bob);
        gnosisAuction.settleAuction(auctionId);

        // Get balances before withdrawing
        ERC20 payout = batchAuction.auctionData(auctionId).payoutToken;
        uint256 startQuoteBal = quote.balanceOf(alice);
        uint256 startPayoutBal = payout.balanceOf(alice);

        // Withdraw tokens settled externally
        vm.prank(alice);
        batchAuction.withdrawExternallySettledFunds(auctionId);

        // Confirm balances after withdrawing
        assertEq(quote.balanceOf(alice), startQuoteBal + 1e6 ether + 8e5 ether);
        assertEq(payout.balanceOf(alice), startPayoutBal);
    }

    function test_withdrawExternallySettledFunds_partiallyFilledNotValid() public {
        // Set fees to zero to avoid rounding errors
        _setFeesZero();

        // Increase the minimum total purchased to the full capacity
        // and the minimum funding threshold to the full capacity at 200 quote tokens per base token
        // This will cause a partially filled market to be invalid
        auctionParams.minimumTotalPurchased = uint96(1e4 ether);
        auctionParams.minFundingThreshold = 1e4 ether * 200;

        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Fill some orders on auction
        _fillOrdersLessThanCapacity(auctionId);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Settle auction externally on gnosis auction as non-owner
        vm.prank(bob);
        gnosisAuction.settleAuction(auctionId);

        // Get balances before withdrawing
        ERC20 payout = batchAuction.auctionData(auctionId).payoutToken;
        uint256 startQuoteBal = quote.balanceOf(alice);
        uint256 startPayoutBal = payout.balanceOf(alice);

        // Withdraw tokens settled externally
        vm.prank(alice);
        batchAuction.withdrawExternallySettledFunds(auctionId);

        // Confirm balances after withdrawing
        assertEq(quote.balanceOf(alice), startQuoteBal);
        assertEq(payout.balanceOf(alice), startPayoutBal + auctionParams.auctionAmount);
    }

    function testRevert_withdrawExternallySettledFunds_notEnded() public {
        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Fill some orders on auction
        _fillOrdersMoreThanCapacity(auctionId);

        // Try to settle auction before auction end time, expect to revert
        bytes memory err = abi.encodeWithSignature("BatchAuction_AuctionHasNotEnded()");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.withdrawExternallySettledFunds(auctionId);
    }

    function testRevert_withdrawExternallySettledFunds_alreadySettled() public {
        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Fill some orders on auction
        _fillOrdersMoreThanCapacity(auctionId);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Settle auction
        vm.prank(alice);
        batchAuction.settleBatchAuction(auctionId);

        // Try to settle auction again, expect to revert
        bytes memory err = abi.encodeWithSignature("BatchAuction_AlreadySettled()");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.withdrawExternallySettledFunds(auctionId);
    }

    function testRevert_withdrawExternallySettledFunds_notSettledExternally() public {
        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Fill some orders on auction
        _fillOrdersMoreThanCapacity(auctionId);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Try to withdraw funds when the auction hasn't been settled externally (or internally), expect to revert
        bytes memory err = abi.encodeWithSignature("BatchAuction_NotSettledExternally()");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.withdrawExternallySettledFunds(auctionId);
    }

    function testRevert_withdrawExternallySettledFunds_notCreated() public {
        // Try to settle auction that was not created by batch auction contract, expect to revert
        bytes memory err = abi.encodeWithSignature("BatchAuction_InvalidParams()");
        vm.expectRevert(err);
        vm.prank(alice);
        batchAuction.withdrawExternallySettledFunds(0);
    }

    function test_emergencyWithdraw_onlyOwner() public {
        // Send tokens to contract which traps them
        vm.prank(bob);
        quote.transfer(address(batchAuction), 1e6 ether);

        // Try to withdraw tokens as non-owner, expect to revert
        vm.prank(bob);
        bytes memory err = abi.encodeWithSignature("BatchAuction_OnlyOwner()");
        vm.expectRevert(err);
        batchAuction.emergencyWithdraw(quote);

        // Withdraw tokens as owner, expect to pass
        vm.prank(alice);
        batchAuction.emergencyWithdraw(quote);
    }

    function test_emergencyWithdraw_ERC20() public {
        // Send tokens to contract which traps them
        vm.prank(bob);
        quote.transfer(address(batchAuction), 1e6 ether);

        uint256 startBal = quote.balanceOf(address(batchAuction));
        uint256 startAliceBal = quote.balanceOf(alice);
        assertEq(startBal, 1e6 ether);
        assertEq(startAliceBal, 0);

        // Withdraw tokens as owner
        vm.prank(alice);
        batchAuction.emergencyWithdraw(quote);

        assertEq(quote.balanceOf(address(batchAuction)), 0);
        assertEq(quote.balanceOf(alice), startAliceBal + startBal);
    }

    function test_emergencyWithdraw_ETH() public {
        // Send ETH to contract which traps it
        vm.deal(address(batchAuction), 1 ether);

        uint256 startBal = address(batchAuction).balance;
        uint256 startAliceBal = address(alice).balance;
        assertEq(startBal, 1 ether);

        // Withdraw tokens as owner
        vm.prank(alice);
        batchAuction.emergencyWithdraw(ERC20(address(0)));

        assertEq(address(batchAuction).balance, 0);
        assertEq(address(alice).balance, startAliceBal + startBal);
    }

    function testRevert_emergencyWithdraw_nonContract() public {
        // Try to withdraw non-token, expect to revert
        vm.prank(alice);
        bytes memory err = abi.encodeWithSignature("BatchAuction_InvalidParams()");
        vm.expectRevert(err);
        batchAuction.emergencyWithdraw(ERC20(bob));
    }

    /* ========== VIEW FUNCTION TESTS ========= */
    // [X] numAuctions
    // [X] auctionData
    // [X] isLive
    // [X] liveAuctions
    // [X] amountWithFee
    // [X] amountWithTellerFee

    function test_numAuctions() public {
        // Confirm initial number of auctions
        assertEq(batchAuction.numAuctions(), 0);

        // Create auction
        vm.prank(alice);
        batchAuction.initiateBatchAuction(auctionParams);

        // Confirm number of auctions after creating one
        assertEq(batchAuction.numAuctions(), 1);

        // Create a few more
        vm.startPrank(alice);
        batchAuction.initiateBatchAuction(auctionParams);
        batchAuction.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        // Confirm number of auctions after creating a few more
        assertEq(batchAuction.numAuctions(), 3);
    }

    function test_auctionData() public {
        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Confirm auction data
        IBondBatchAuctionV1.AuctionData memory data = batchAuction.auctionData(auctionId);

        assertEq(address(data.quoteToken), address(quote));
        assertEq(
            address(data.payoutToken),
            address(
                teller.bondTokens(
                    auctionParams.payoutTokenParams.underlying,
                    (auctionParams.payoutTokenParams.expiry / 1 days) * 1 days
                )
            )
        );
        assertEq(data.created, true);
        assertEq(data.settled, false);
        assertEq(data.auctionEnd, auctionParams.auctionEnd);
        assertEq(data.payoutAmount, auctionParams.auctionAmount);
    }

    function test_isLive() public {
        // Create auction
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        // Confirm auction is live
        assertEq(batchAuction.isLive(auctionId), true);

        // Move past the auction end time
        vm.warp(auctionParams.auctionEnd + 1);

        // Confirm auction is no longer live
        assertEq(batchAuction.isLive(auctionId), false);
    }

    function test_liveAuctions() public {
        // Create several auctions
        vm.startPrank(alice);
        uint256 auctionId1 = batchAuction.initiateBatchAuction(auctionParams);
        uint256 auctionId2 = batchAuction.initiateBatchAuction(auctionParams);
        auctionParams.auctionEnd += 10;
        uint256 auctionId3 = batchAuction.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        // Check that all auctions are live
        uint256[] memory liveAuctions = batchAuction.liveAuctions(0, 3);
        assertEq(liveAuctions.length, 3);
        assertEq(liveAuctions[0], auctionId1);
        assertEq(liveAuctions[1], auctionId2);
        assertEq(liveAuctions[2], auctionId3);

        // Get a subset of auctions using indexes
        liveAuctions = batchAuction.liveAuctions(1, 3);
        assertEq(liveAuctions.length, 2);
        assertEq(liveAuctions[0], auctionId2);
        assertEq(liveAuctions[1], auctionId3);

        // Try to get just the first auction
        liveAuctions = batchAuction.liveAuctions(0, 1);
        assertEq(liveAuctions.length, 1);
        assertEq(liveAuctions[0], auctionId1);

        // Make purchases on auction 1
        _fillOrdersMoreThanCapacity(auctionId1);

        // Move past the end time of the auctions
        vm.warp(auctionParams.auctionEnd - 9);

        // Expect all but the last auction to not be live anymore
        liveAuctions = batchAuction.liveAuctions(0, 3);
        assertEq(liveAuctions.length, 1);
        assertEq(liveAuctions[0], auctionId3);

        // Confirm that range of 0 returns empty array
        liveAuctions = batchAuction.liveAuctions(0, 0);
        assertEq(liveAuctions.length, 0);
    }

    function testFuzz_amountWithFee(uint256 amount_) public {
        // Fees are set to 0.3% on teller and 0.2% on easy auction
        // The teller fee is taken from the amount + easy auction fee
        // Easy auction fee is additive the amount passed in (i.e. total = amount * (1 + fee)))
        // Teller fee is taken from the amount provided (i.e. amount = total * (1 - fee)) where
        // the fee is rounded down (so the amount is rounded up).

        // Assume that the amount passed in, when the fee is added is less than uint256 max to prevent overflows
        vm.assume(amount_ < type(uint256).max.mulDiv(99700, 100000).mulDivUp(1000, 1002));

        uint256 expectedAmount = amount_.mulDiv(1002, 1000).mulDivUp(100000, 99700);

        assertEq(batchAuction.amountWithFee(amount_), expectedAmount);

        // Check that the math works correctly when fees are zero (i.e. no rounding errors)
        _setFeesZero();
        assertEq(batchAuction.amountWithFee(amount_), amount_);
    }

    function testFuzz_amountWithTellerFee(uint256 amount_) public {
        // Fee is set to 0.3% on teller
        // Teller fee is taken from the amount provided (i.e. amount = total * (1 - fee)) where
        // the fee is rounded down (so the amount is rounded up).

        // Assume that the amount passed in, when the fee is added is less than uint256 max to prevent overflows
        vm.assume(amount_ < type(uint256).max.mulDiv(99700, 100000));

        uint256 expectedAmount = amount_.mulDivUp(100000, 99700);
        assertEq(batchAuction.amountWithTellerFee(amount_), expectedAmount);

        // Check that the math works correctly when fees are zero (i.e. no rounding errors)
        _setFeesZero();
        assertEq(batchAuction.amountWithTellerFee(amount_), amount_);
    }

    ////////////////////////////////////////////////////////////////////////////
    //                    BATCH AUCTION CLONE FACTORY TESTS                   //
    ////////////////////////////////////////////////////////////////////////////

    /* ========== CLONE TESTS ========= */
    // [X] Deployment of clones
    //      [X] Clone can be deployed by any address
    //      [X] Owner must not be zero address and is stored on factory
    //      [X] Clone immutable arguments are set correctly are creation
    // [X] Clones can register auctions with the factory
    //      [X] Auctions can only be registered by clones
    //      [X] Auctions are stored on the factory correctly

    function testFuzz_deployClone(address random) public {
        vm.assume(random != address(0));

        // Deploy clone for self
        vm.prank(random);
        batchAuctionFactory.deployClone(random);

        // Deploy clone for bob
        vm.prank(random);
        batchAuctionFactory.deployClone(bob);
    }

    function testRevert_deployClone_zeroAddress() public {
        // Try to deploy clone with zero address, expect to revert
        vm.prank(alice);
        bytes memory err = abi.encodeWithSignature("BatchAuctionFactory_InvalidParams()");
        vm.expectRevert(err);
        batchAuctionFactory.deployClone(address(0));
    }

    function test_deployClone_ownerStored() public {
        // Deploy clone
        vm.prank(bob);
        BondBatchAuctionV1 clone = batchAuctionFactory.deployClone(bob);

        // Check that owner is stored correctly
        assertEq(batchAuctionFactory.cloneOwners(clone), bob);
    }

    function test_deployClone_immutableArgs() public {
        // Deploy clone
        vm.prank(bob);
        BondBatchAuctionV1 clone = batchAuctionFactory.deployClone(bob);

        // Check that immutable arguments are set correctly on the clone
        assertEq(address(clone.gnosisAuction()), address(gnosisAuction));
        assertEq(address(clone.teller()), address(teller));
        assertEq(address(clone.factory()), address(batchAuctionFactory));
        assertEq(clone.owner(), bob);
    }

    function test_registerAuction_onlyClone() public {
        // batchAuction is a pre-deployed clone

        // Try to register auction from non-clone, expect revert
        vm.prank(alice);
        bytes memory err = abi.encodeWithSignature("BatchAuctionFactory_OnlyClone()");
        vm.expectRevert(err);
        batchAuctionFactory.registerAuction(uint256(1), quote);

        // Register auction from clone, expect to pass
        vm.prank(address(batchAuction));
        batchAuctionFactory.registerAuction(uint256(1), quote);
    }

    function test_registerAuction_auctionStored() public {
        // batchAuction is a pre-deployed clone

        // Register auction from clone
        vm.prank(address(batchAuction));
        batchAuctionFactory.registerAuction(uint256(1), quote);

        // Check that auction is stored correctly
        assertEq(batchAuctionFactory.auctions(0), uint256(1));
        assertEq(address(batchAuctionFactory.auctionsToClones(uint256(1))), address(batchAuction));
        assertEq(batchAuctionFactory.auctionsForQuote(quote, 0), uint256(1));
    }

    /* ========== VIEW TESTS ========= */
    // [X] numAuctions
    // [X] auctionData
    // [X] isLive
    // [X] liveAuctions
    // [X] liveAuctionsBy
    // [X] auctionsBy
    // [X] liveAuctionsFor (quote token)
    // [X] auctionsFor (quote token)

    function test_auctionData_multipleClones() public {
        // batchAuction and batchAuction2 are pre-deployed clones

        // Create auctions
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        vm.prank(dave);
        uint256 auctionId2 = batchAuction2.initiateBatchAuction(auctionParams);

        // Confirm auction data for auction 1
        IBondBatchAuctionV1.AuctionData memory data = batchAuctionFactory.auctionData(auctionId);

        assertEq(address(data.quoteToken), address(quote));
        assertEq(
            address(data.payoutToken),
            address(
                teller.bondTokens(
                    auctionParams.payoutTokenParams.underlying,
                    (auctionParams.payoutTokenParams.expiry / 1 days) * 1 days
                )
            )
        );
        assertEq(data.created, true);
        assertEq(data.settled, false);
        assertEq(data.auctionEnd, auctionParams.auctionEnd);
        assertEq(data.payoutAmount, auctionParams.auctionAmount);

        // Confirm auction data for auction 2
        data = batchAuctionFactory.auctionData(auctionId2);

        assertEq(address(data.quoteToken), address(quote));
        assertEq(
            address(data.payoutToken),
            address(
                teller.bondTokens(
                    auctionParams.payoutTokenParams.underlying,
                    (auctionParams.payoutTokenParams.expiry / 1 days) * 1 days
                )
            )
        );
        assertEq(data.created, true);
        assertEq(data.settled, false);
        assertEq(data.auctionEnd, auctionParams.auctionEnd);
        assertEq(data.payoutAmount, auctionParams.auctionAmount);
    }

    function test_isLive_multipleClones() public {
        // batchAuction and batchAuction2 are pre-deployed clones

        // Create auctions
        vm.prank(alice);
        uint256 auctionId = batchAuction.initiateBatchAuction(auctionParams);

        vm.prank(dave);
        uint256 auctionId2 = batchAuction2.initiateBatchAuction(auctionParams);

        // Confirm that both auctions are live
        assertEq(batchAuctionFactory.isLive(auctionId), true);
        assertEq(batchAuctionFactory.isLive(auctionId2), true);
    }

    function test_numAuctions_multipleClones() public {
        // Create several auctions
        vm.startPrank(alice);
        uint256 auctionId1 = batchAuction.initiateBatchAuction(auctionParams);
        uint256 auctionId2 = batchAuction.initiateBatchAuction(auctionParams);
        uint256 auctionId3 = batchAuction.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        assertEq(batchAuctionFactory.numAuctions(), 3);

        vm.startPrank(dave);
        uint256 auctionId4 = batchAuction2.initiateBatchAuction(auctionParams);
        uint256 auctionId5 = batchAuction2.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        assertEq(batchAuctionFactory.numAuctions(), 5);
    }

    function test_liveAuctions_multipleClones() public {
        // Create several auctions
        vm.startPrank(alice);
        uint256 auctionId1 = batchAuction.initiateBatchAuction(auctionParams);
        uint256 auctionId2 = batchAuction.initiateBatchAuction(auctionParams);
        auctionParams.auctionEnd += 10;
        uint256 auctionId3 = batchAuction.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        vm.startPrank(dave);
        uint256 auctionId4 = batchAuction2.initiateBatchAuction(auctionParams);
        uint256 auctionId5 = batchAuction2.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        // Check that all auctions are live
        uint256[] memory liveAuctions = batchAuctionFactory.liveAuctions(0, 5);
        assertEq(liveAuctions.length, 5);
        assertEq(liveAuctions[0], auctionId1);
        assertEq(liveAuctions[1], auctionId2);
        assertEq(liveAuctions[2], auctionId3);
        assertEq(liveAuctions[3], auctionId4);
        assertEq(liveAuctions[4], auctionId5);

        // Get a subset of auctions using indexes
        liveAuctions = batchAuctionFactory.liveAuctions(1, 3);
        assertEq(liveAuctions.length, 2);
        assertEq(liveAuctions[0], auctionId2);
        assertEq(liveAuctions[1], auctionId3);

        // Try to get just the first auction
        liveAuctions = batchAuctionFactory.liveAuctions(0, 1);
        assertEq(liveAuctions.length, 1);
        assertEq(liveAuctions[0], auctionId1);

        // Move past the end time of the initial auctions
        vm.warp(auctionParams.auctionEnd - 9);

        // Get list of live auctions
        liveAuctions = batchAuctionFactory.liveAuctions(0, 5);
        assertEq(liveAuctions.length, 3);
        assertEq(liveAuctions[0], auctionId3);
        assertEq(liveAuctions[1], auctionId4);
        assertEq(liveAuctions[2], auctionId5);

        // Confirm that range of 0 returns empty array
        liveAuctions = batchAuctionFactory.liveAuctions(0, 0);
        assertEq(liveAuctions.length, 0);
    }

    function test_liveAuctionsBy_multipleClones() public {
        // Create several auctions with alice
        vm.startPrank(alice);
        uint256 auctionId1 = batchAuction.initiateBatchAuction(auctionParams);
        uint256 auctionId2 = batchAuction.initiateBatchAuction(auctionParams);
        auctionParams.auctionEnd += 10;
        uint256 auctionId3 = batchAuction.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        // Create some auctions with dave
        vm.startPrank(dave);
        uint256 auctionId4 = batchAuction2.initiateBatchAuction(auctionParams);
        uint256 auctionId5 = batchAuction2.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        // Check that all auctions are live
        uint256[] memory liveAuctions = batchAuctionFactory.liveAuctionsBy(alice, 0, 5);
        assertEq(liveAuctions.length, 3);
        assertEq(liveAuctions[0], auctionId1);
        assertEq(liveAuctions[1], auctionId2);
        assertEq(liveAuctions[2], auctionId3);

        liveAuctions = batchAuctionFactory.liveAuctionsBy(dave, 0, 5);
        assertEq(liveAuctions.length, 2);
        assertEq(liveAuctions[0], auctionId4);
        assertEq(liveAuctions[1], auctionId5);

        // Get a subset of auctions using indexes
        liveAuctions = batchAuctionFactory.liveAuctionsBy(alice, 1, 4);
        assertEq(liveAuctions.length, 2);
        assertEq(liveAuctions[0], auctionId2);
        assertEq(liveAuctions[1], auctionId3);

        liveAuctions = batchAuctionFactory.liveAuctionsBy(dave, 1, 4);
        assertEq(liveAuctions.length, 1);
        assertEq(liveAuctions[0], auctionId4);

        // Try to get just the first auction
        liveAuctions = batchAuctionFactory.liveAuctionsBy(alice, 0, 1);
        assertEq(liveAuctions.length, 1);
        assertEq(liveAuctions[0], auctionId1);

        // Try to get just last auction
        liveAuctions = batchAuctionFactory.liveAuctionsBy(dave, 4, 5);
        assertEq(liveAuctions.length, 1);
        assertEq(liveAuctions[0], auctionId5);

        // Move past the end time of the initial auctions
        vm.warp(auctionParams.auctionEnd - 9);

        // Get list of live auctions remaining
        liveAuctions = batchAuctionFactory.liveAuctionsBy(alice, 0, 5);
        assertEq(liveAuctions.length, 1);
        assertEq(liveAuctions[0], auctionId3);

        liveAuctions = batchAuctionFactory.liveAuctionsBy(dave, 0, 5);
        assertEq(liveAuctions.length, 2);
        assertEq(liveAuctions[0], auctionId4);
        assertEq(liveAuctions[1], auctionId5);

        // Confirm that it returns the empty list if owner has no auctions in the range
        liveAuctions = batchAuctionFactory.liveAuctionsBy(alice, 4, 5);
        assertEq(liveAuctions.length, 0);

        liveAuctions = batchAuctionFactory.liveAuctionsBy(dave, 2, 3);
        assertEq(liveAuctions.length, 0);

        liveAuctions = batchAuctionFactory.liveAuctionsBy(carol, 0, 5);
        assertEq(liveAuctions.length, 0);

        // Confirm that range of 0 returns empty array
        liveAuctions = batchAuctionFactory.liveAuctionsBy(alice, 0, 0);
        assertEq(liveAuctions.length, 0);
    }

    function test_auctionsBy_multipleClones() public {
        // Create several auctions with alice
        vm.startPrank(alice);
        uint256 auctionId1 = batchAuction.initiateBatchAuction(auctionParams);
        uint256 auctionId2 = batchAuction.initiateBatchAuction(auctionParams);
        auctionParams.auctionEnd += 10;
        uint256 auctionId3 = batchAuction.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        // Create some auctions with dave
        vm.startPrank(dave);
        uint256 auctionId4 = batchAuction2.initiateBatchAuction(auctionParams);
        uint256 auctionId5 = batchAuction2.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        // Check that all auctions return
        uint256[] memory auctions = batchAuctionFactory.auctionsBy(alice, 0, 5);
        assertEq(auctions.length, 3);
        assertEq(auctions[0], auctionId1);
        assertEq(auctions[1], auctionId2);
        assertEq(auctions[2], auctionId3);

        auctions = batchAuctionFactory.auctionsBy(dave, 0, 5);
        assertEq(auctions.length, 2);
        assertEq(auctions[0], auctionId4);
        assertEq(auctions[1], auctionId5);

        // Get a subset of auctions using indexes
        auctions = batchAuctionFactory.auctionsBy(alice, 1, 4);
        assertEq(auctions.length, 2);
        assertEq(auctions[0], auctionId2);
        assertEq(auctions[1], auctionId3);

        auctions = batchAuctionFactory.auctionsBy(dave, 1, 4);
        assertEq(auctions.length, 1);
        assertEq(auctions[0], auctionId4);

        // Try to get just the first auction
        auctions = batchAuctionFactory.liveAuctionsBy(alice, 0, 1);
        assertEq(auctions.length, 1);
        assertEq(auctions[0], auctionId1);

        // Try to get just last auction
        auctions = batchAuctionFactory.auctionsBy(dave, 4, 5);
        assertEq(auctions.length, 1);
        assertEq(auctions[0], auctionId5);

        // Move past the end time of the initial auctions
        vm.warp(auctionParams.auctionEnd - 9);

        // Expect same list of auctions as before
        auctions = batchAuctionFactory.auctionsBy(alice, 0, 5);
        assertEq(auctions.length, 3);
        assertEq(auctions[0], auctionId1);
        assertEq(auctions[1], auctionId2);
        assertEq(auctions[2], auctionId3);

        auctions = batchAuctionFactory.auctionsBy(dave, 0, 5);
        assertEq(auctions.length, 2);
        assertEq(auctions[0], auctionId4);
        assertEq(auctions[1], auctionId5);

        // Confirm that it returns the empty list if owner has no auctions in the range
        auctions = batchAuctionFactory.auctionsBy(alice, 4, 5);
        assertEq(auctions.length, 0);

        auctions = batchAuctionFactory.auctionsBy(dave, 2, 3);
        assertEq(auctions.length, 0);

        auctions = batchAuctionFactory.auctionsBy(carol, 0, 5);
        assertEq(auctions.length, 0);

        // Confirm that range of 0 returns empty array
        auctions = batchAuctionFactory.auctionsBy(alice, 0, 0);
        assertEq(auctions.length, 0);
    }

    function test_auctionsFor_multipleClones() public {
        // Create new quote token to create auctions with
        MockERC20 quote2 = new MockERC20("Quote2", "Q2", 18);

        // Create several auctions with quote token 1
        vm.startPrank(alice);
        uint256 auctionId1 = batchAuction.initiateBatchAuction(auctionParams);
        auctionParams.auctionEnd += 10;
        uint256 auctionId2 = batchAuction.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        auctionParams.auctionEnd -= 10;
        vm.prank(dave);
        uint256 auctionId3 = batchAuction2.initiateBatchAuction(auctionParams);

        // Change params to use quote2
        auctionParams.quoteToken = quote2;

        // Create some auctions with quote token 2
        vm.startPrank(alice);
        uint256 auctionId4 = batchAuction.initiateBatchAuction(auctionParams);
        uint256 auctionId5 = batchAuction.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        auctionParams.auctionEnd += 10;
        vm.prank(dave);
        uint256 auctionId6 = batchAuction2.initiateBatchAuction(auctionParams);

        // Get all auctions
        uint256 numAuctionsForQuote = batchAuctionFactory.numAuctionsFor(quote);
        uint256[] memory auctions = batchAuctionFactory.auctionsFor(quote, 0, numAuctionsForQuote);
        assertEq(auctions.length, 3);
        assertEq(auctions[0], auctionId1);
        assertEq(auctions[1], auctionId2);
        assertEq(auctions[2], auctionId3);

        uint256 numAuctionsForQuote2 = batchAuctionFactory.numAuctionsFor(quote2);
        auctions = batchAuctionFactory.auctionsFor(quote2, 0, numAuctionsForQuote2);
        assertEq(auctions.length, 3);
        assertEq(auctions[0], auctionId4);
        assertEq(auctions[1], auctionId5);
        assertEq(auctions[2], auctionId6);

        // Get a subset of auctions using indexes
        auctions = batchAuctionFactory.auctionsFor(quote, 1, numAuctionsForQuote);
        assertEq(auctions.length, 2);
        assertEq(auctions[0], auctionId2);
        assertEq(auctions[1], auctionId3);

        auctions = batchAuctionFactory.auctionsFor(quote2, 0, 1);
        assertEq(auctions.length, 1);
        assertEq(auctions[0], auctionId4);

        // Try to get just the first auction
        auctions = batchAuctionFactory.auctionsFor(quote, 0, 1);
        assertEq(auctions.length, 1);
        assertEq(auctions[0], auctionId1);

        // Try to get just last auction
        auctions = batchAuctionFactory.auctionsFor(quote2, 2, numAuctionsForQuote2);
        assertEq(auctions.length, 1);
        assertEq(auctions[0], auctionId6);

        // Move past the end time of most auctions (except 2 and 6)
        vm.warp(auctionParams.auctionEnd - 9);

        // The list of auctionsFor shouldn't change when auctions go from live to settled
        auctions = batchAuctionFactory.auctionsFor(quote, 0, numAuctionsForQuote);
        assertEq(auctions.length, 3);
        assertEq(auctions[0], auctionId1);
        assertEq(auctions[1], auctionId2);
        assertEq(auctions[2], auctionId3);

        auctions = batchAuctionFactory.auctionsFor(quote2, 0, numAuctionsForQuote2);
        assertEq(auctions.length, 3);
        assertEq(auctions[0], auctionId4);
        assertEq(auctions[1], auctionId5);
        assertEq(auctions[2], auctionId6);

        // Confirm that range of 0 returns empty array
        auctions = batchAuctionFactory.auctionsFor(quote, 0, 0);
        assertEq(auctions.length, 0);
    }

    function test_liveAuctionsFor_multipleClones() public {
        // Create new quote token to create auctions with
        MockERC20 quote2 = new MockERC20("Quote2", "Q2", 18);

        // Create several auctions with quote token 1
        vm.startPrank(alice);
        uint256 auctionId1 = batchAuction.initiateBatchAuction(auctionParams);
        auctionParams.auctionEnd += 10;
        uint256 auctionId2 = batchAuction.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        auctionParams.auctionEnd -= 10;
        vm.prank(dave);
        uint256 auctionId3 = batchAuction2.initiateBatchAuction(auctionParams);

        // Change params to use quote2
        auctionParams.quoteToken = quote2;

        // Create some auctions with quote token 2
        vm.startPrank(alice);
        uint256 auctionId4 = batchAuction.initiateBatchAuction(auctionParams);
        uint256 auctionId5 = batchAuction.initiateBatchAuction(auctionParams);
        vm.stopPrank();

        auctionParams.auctionEnd += 10;
        vm.prank(dave);
        uint256 auctionId6 = batchAuction2.initiateBatchAuction(auctionParams);

        // Get all auctions
        uint256 numAuctionsForQuote = batchAuctionFactory.numAuctionsFor(quote);
        uint256[] memory auctions = batchAuctionFactory.liveAuctionsFor(
            quote,
            0,
            numAuctionsForQuote
        );
        assertEq(auctions.length, 3);
        assertEq(auctions[0], auctionId1);
        assertEq(auctions[1], auctionId2);
        assertEq(auctions[2], auctionId3);

        uint256 numAuctionsForQuote2 = batchAuctionFactory.numAuctionsFor(quote2);
        auctions = batchAuctionFactory.liveAuctionsFor(quote2, 0, numAuctionsForQuote2);
        assertEq(auctions.length, 3);
        assertEq(auctions[0], auctionId4);
        assertEq(auctions[1], auctionId5);
        assertEq(auctions[2], auctionId6);

        // Get a subset of auctions using indexes
        auctions = batchAuctionFactory.liveAuctionsFor(quote, 1, numAuctionsForQuote);
        assertEq(auctions.length, 2);
        assertEq(auctions[0], auctionId2);
        assertEq(auctions[1], auctionId3);

        auctions = batchAuctionFactory.liveAuctionsFor(quote2, 0, 1);
        assertEq(auctions.length, 1);
        assertEq(auctions[0], auctionId4);

        // Try to get just the first auction
        auctions = batchAuctionFactory.liveAuctionsFor(quote, 0, 1);
        assertEq(auctions.length, 1);
        assertEq(auctions[0], auctionId1);

        // Try to get just last auction
        auctions = batchAuctionFactory.liveAuctionsFor(quote2, 2, numAuctionsForQuote2);
        assertEq(auctions.length, 1);
        assertEq(auctions[0], auctionId6);

        // Move past the end time of most auctions (except 2 and 6)
        vm.warp(auctionParams.auctionEnd - 9);

        // The list of live auctions should be reduced
        auctions = batchAuctionFactory.liveAuctionsFor(quote, 0, numAuctionsForQuote);
        assertEq(auctions.length, 1);
        assertEq(auctions[0], auctionId2);

        auctions = batchAuctionFactory.liveAuctionsFor(quote2, 0, numAuctionsForQuote2);
        assertEq(auctions.length, 1);
        assertEq(auctions[0], auctionId6);

        // Confirm that range of 0 returns empty array
        auctions = batchAuctionFactory.liveAuctionsFor(quote, 0, 0);
        assertEq(auctions.length, 0);
    }
}

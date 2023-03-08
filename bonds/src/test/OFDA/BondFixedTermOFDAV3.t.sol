// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {Utilities} from "../utils/Utilities.sol";
import {console2} from "forge-std/console2.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {RolesAuthority, Authority} from "solmate/auth/authorities/RolesAuthority.sol";
import {MockBondCallback} from "../utils/mocks/MockBondCallback.sol";
import {MockPriceFeed} from "../utils/mocks/MockPriceFeed.sol";
import {MockFOTERC20} from "../utils/mocks/MockFOTERC20.sol";

import {IBondOFDA} from "../../interfaces/IBondOFDA.sol";
import {IBondCallback} from "../../interfaces/IBondCallback.sol";

import {BondFixedTermOFDA} from "../../BondFixedTermOFDA.sol";
import {BondFixedTermTeller} from "../../BondFixedTermTeller.sol";
import {BondAggregator} from "../../BondAggregator.sol";
import {BondSampleCallback} from "../../BondSampleCallback.sol";
import {BondChainlinkOracle} from "../../BondChainlinkOracle.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {FullMath} from "../../lib/FullMath.sol";

// V3 test suite uses a callback for payout tokens and tests instant swap markets
contract BondFixedTermOFDAV3Test is Test {
    using FullMath for uint256;

    Utilities internal utils;
    address payable internal alice;
    address payable internal bob;
    address payable internal carol;
    address payable internal guardian;
    address payable internal policy;
    address payable internal treasury;
    address payable internal referrer;

    RolesAuthority internal auth;
    BondFixedTermOFDA internal auctioneer;
    BondFixedTermTeller internal teller;
    BondAggregator internal aggregator;
    MockERC20 internal payoutToken;
    MockERC20 internal quoteToken;
    IBondOFDA.MarketParams internal params;
    MockPriceFeed internal priceFeed;
    BondChainlinkOracle internal oracle;
    MockBondCallback internal callback;

    function setUp() public {
        vm.warp(51 * 365 * 24 * 60 * 60); // Set timestamp at roughly Jan 1, 2021 (51 years since Unix epoch)
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(7);
        alice = users[0];
        bob = users[1];
        carol = users[2];
        guardian = users[3];
        policy = users[4];
        treasury = users[5];
        referrer = users[6];
        auth = new RolesAuthority(address(this), Authority(address(0)));

        // Deploy fresh contracts
        aggregator = new BondAggregator(guardian, auth);
        teller = new BondFixedTermTeller(policy, aggregator, guardian, auth);
        auctioneer = new BondFixedTermOFDA(teller, aggregator, guardian, auth);
        priceFeed = new MockPriceFeed();

        address[] memory auctioneers = new address[](1);
        auctioneers[0] = address(auctioneer);
        oracle = new BondChainlinkOracle(address(aggregator), auctioneers);

        // Configure access control on Authority
        // Role 0 - Guardian
        // Aggregator
        auth.setRoleCapability(
            uint8(0),
            address(aggregator),
            aggregator.registerAuctioneer.selector,
            true
        );

        // Teller
        auth.setRoleCapability(uint8(0), address(teller), teller.setProtocolFee.selector, true);
        auth.setRoleCapability(
            uint8(0),
            address(teller),
            teller.setCreateFeeDiscount.selector,
            true
        );

        // Auctioneer
        auth.setRoleCapability(
            uint8(0),
            address(auctioneer),
            auctioneer.setAllowNewMarkets.selector,
            true
        );
        auth.setRoleCapability(
            uint8(0),
            address(auctioneer),
            auctioneer.setCallbackAuthStatus.selector,
            true
        );

        // Role 1 - Policy
        // Auctioneer
        auth.setRoleCapability(
            uint8(1),
            address(auctioneer),
            auctioneer.setMinDepositInterval.selector,
            true
        );
        auth.setRoleCapability(
            uint8(1),
            address(auctioneer),
            auctioneer.setMinMarketDuration.selector,
            true
        );

        // Assign roles to addresses
        auth.setUserRole(guardian, uint8(0), true);
        auth.setUserRole(policy, uint8(1), true);

        // Configure protocol
        vm.prank(guardian);
        auctioneer.setCallbackAuthStatus(address(this), true);
        vm.prank(guardian);
        aggregator.registerAuctioneer(auctioneer);

        // Set fees for testing
        vm.prank(guardian);
        teller.setProtocolFee(uint48(100));

        vm.prank(guardian);
        teller.setCreateFeeDiscount(uint48(25));

        vm.prank(referrer);
        teller.setReferrerFee(uint48(200));
    }

    function createMarket(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals
    )
        internal
        returns (
            uint256 id,
            uint256 scale,
            uint256 price
        )
    {
        // Set oracle decimals and initial price using price decimal scaling
        priceFeed.setDecimals(_oracleDecimals);
        price = 50 * 10**uint8(int8(_oracleDecimals) + _payoutPriceDecimals - _quotePriceDecimals);
        priceFeed.setLatestAnswer(int256(price));
        priceFeed.setTimestamp(block.timestamp);
        priceFeed.setAnsweredInRound(1);
        priceFeed.setRoundId(1);

        // Configure oracle to support token pair
        bytes memory oracleData = abi.encode(
            priceFeed,
            1 days,
            MockPriceFeed(address(0)),
            0,
            _oracleDecimals,
            false
        );
        oracle.setPair(quoteToken, payoutToken, true, oracleData);

        // Configure market params

        uint256 capacity = _capacityInQuote
            ? 500_000 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals)
            : 100_000 * 10**uint8(int8(_payoutDecimals) - _payoutPriceDecimals);

        uint48 fixedDiscount = 10e3; // 10%
        uint48 maxDiscountFromCurrent = 30e3; // 30%
        uint48 depositInterval = 7 days / 10;

        uint48 vesting = 0; // instant swap markets
        uint48 conclusion = uint48(block.timestamp + 7 days);

        params = IBondOFDA.MarketParams(
            payoutToken, // ERC20 payoutToken
            quoteToken, // ERC20 quoteToken
            address(callback), // address callbackAddr
            oracle, // IBondOracle oracle
            fixedDiscount, // uint48 fixedDiscount
            maxDiscountFromCurrent, // uint48 maxDiscountFromCurrent
            _capacityInQuote, // bool capacityIn
            capacity, // uint256 capacity
            depositInterval, // uint48 depositInterval
            vesting, // uint48 vesting (timestamp or duration)
            conclusion // uint48 conclusion (timestamp)
        );

        id = auctioneer.createMarket(abi.encode(params));

        scale = auctioneer.marketScale(id);
        price = auctioneer.marketPrice(id);
    }

    function beforeEach(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals
    )
        internal
        returns (
            uint256 id,
            uint256 scale,
            uint256 price
        )
    {
        // Deploy token contracts with provided decimals
        payoutToken = new MockERC20("Payout Token", "BT", _payoutDecimals);
        quoteToken = new MockERC20("Quote Token", "QT", _quoteDecimals);
        callback = new MockBondCallback(payoutToken);

        // Mint tokens to users for testing
        uint256 testAmount = 1_000_000_000 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);

        quoteToken.mint(alice, testAmount);
        quoteToken.mint(bob, testAmount);
        quoteToken.mint(carol, testAmount);

        // Approve the teller for the tokens
        vm.prank(alice);
        quoteToken.approve(address(teller), testAmount);
        vm.prank(bob);
        quoteToken.approve(address(teller), testAmount);
        vm.prank(carol);
        quoteToken.approve(address(teller), testAmount);

        // Create market
        (id, scale, price) = createMarket(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals,
            _oracleDecimals
        );
    }

    function inFuzzRange(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals
    ) internal pure returns (bool) {
        if (
            _payoutDecimals > 18 || _payoutDecimals < 6 || _quoteDecimals > 18 || _quoteDecimals < 6
        ) return false;

        if (
            _payoutPriceDecimals < int8(-11) ||
            _payoutPriceDecimals > int8(12) ||
            _quotePriceDecimals < int8(-11) ||
            _quotePriceDecimals > int8(12)
        ) return false;

        // Don't test situations where the number of price decimals is greater than the number of
        // payout decimals, these are not likely to happen as it would create tokens whose smallest unit
        // would be a very high value (e.g. 1 wei > $ 1)
        if (
            _payoutPriceDecimals > int8(_payoutDecimals) ||
            _quotePriceDecimals > int8(_quoteDecimals)
        ) return false;

        // Oracle decimals must be between 6 and 18
        if (_oracleDecimals > 18 || _oracleDecimals < 6) return false;

        // Oracle decimals must be greater than the price difference between the tokens
        if (int8(_oracleDecimals) <= _quotePriceDecimals - _payoutPriceDecimals) return false;

        // Otherwise, return true
        return true;
    }

    /* ========== OFDA TESTS ========== */
    // [X] Market creation
    //     [X] Market can be created by any address with valid params
    //     [X] Market values are correct after creation
    //     [X] Market cannot be created with invalid params
    //     [X] Market cannot be created with invalid oracle
    //     [X] Markets cannot be created if allowNewMarkets is false
    //     [X] setAllowNewMarkets can only be called by guardian
    // [X] Market behavior
    //     [X] Market can be purchased from at the right price
    //     [X] User must receive minAmountOut of payout tokens from a purchase, otherwise revert
    //     [X] User payout cannot exceed max payout
    //     [X] Price stays a consistent discount from the oracle unless it goes below minimum
    //     [X] Market ends when capacity is reached or duration is over
    //     [X] Changes to the oracle price affect the market price
    //     [X] Market price cannot be less than the minimum price
    //     [X] Markets start at the fixed discount from the oracle price
    //     [X] Purchase reverts if oracle fails to validate and return a price
    // [X] Bond position behavior
    //     [X] Bond tokens (ERC1155) are issued to purchaser to represent their vesting position (when market is not instant swap)
    //     [X] Bond tokens have correct metadata for the purchase
    //     [X] Bond tokens can be redeemed for payout tokens after vesting period
    //     [X] Bond tokens cannot be redeemed for payout tokens prior to vesting period ending
    //     [X] Bond token must have been created by the teller to be redeemed
    // [X] Administration
    //     [X] market owners can close markets early
    //     [X] market owners can push market ownership to a new address and it can be pulled to that address
    //     [X] setMinMarketDuration can only be called by policy
    //     [X] setMinDepositInterval can only be called by policy
    // [X] View functions return correct values
    //     [X] marketScale
    //     [X] payoutFor
    //     [X] maxAmountAccepted
    //     [X] isInstantSwap
    //     [X] isLive
    //     [X] ownerOf
    // [X] Aggregator view functions return correct values
    //     [X] marketsFor
    //     [X] liveMarketsFor
    //     [X] liveMarketsBetween
    //     [X] findMarketFor
    //     [X] liveMarketsBy

    function test_createMarket_anyAuthorizedAddress(address creator_) public {
        beforeEach(18, 18, false, 0, 0, 18);
        vm.assume(creator_ != address(this));

        // Expect to fail before being authorized
        bytes memory err = abi.encodeWithSignature("Auctioneer_NotAuthorized()");
        vm.expectRevert(err);
        vm.prank(creator_);
        auctioneer.createMarket(abi.encode(params));

        // Authorize creator for callback
        vm.prank(guardian);
        auctioneer.setCallbackAuthStatus(creator_, true);

        // Create market
        vm.prank(creator_);
        auctioneer.createMarket(abi.encode(params));
    }

    function testCorrectness_CreateMarket(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals
    ) public {
        if (
            !inFuzzRange(
                _payoutDecimals,
                _quoteDecimals,
                _payoutPriceDecimals,
                _quotePriceDecimals,
                _oracleDecimals
            )
        ) return;
        // uint8 _payoutDecimals = 6;
        // uint8 _quoteDecimals = 6;
        // bool _capacityInQuote = false;
        // int8 _payoutPriceDecimals = 0;
        // int8 _quotePriceDecimals = 0;
        // uint8 _oracleDecimals = 6;

        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals,
            _oracleDecimals
        );
        assertEq(id, 0);

        // Get variables for created Market
        {
            // Check scale set correctly, add a decimal due to price having one extra for precision purposes in other tests
            assertEq(
                scale,
                10 **
                    uint8(
                        36 +
                            int8(_payoutDecimals) -
                            int8(_quoteDecimals) -
                            (_payoutPriceDecimals - _quotePriceDecimals + 1) /
                            2
                    )
            );

            // Check market price set correctly, add a decimal due to price having one extra for precision purposes in other tests
            assertEq(
                price,
                (50 *
                    10**uint8(int8(_oracleDecimals) + _payoutPriceDecimals - _quotePriceDecimals) *
                    10 **
                        uint8(
                            36 -
                                (_payoutPriceDecimals - _quotePriceDecimals + 1) /
                                2 -
                                int8(_oracleDecimals)
                        )).mulDivUp(100e3 - 10e3, 100e3)
            );

            (, , , , uint256 minPrice, , uint256 oracleConversion) = auctioneer.terms(id);

            // Check oracle conversion set correctly, add a decimal due to price having one extra for precision purposes in other tests
            assertEq(
                oracleConversion,
                10 **
                    uint8(
                        36 -
                            (_payoutPriceDecimals - _quotePriceDecimals + 1) /
                            2 -
                            int8(_oracleDecimals)
                    )
            );

            // Check min price set correctly
            assertEq(
                minPrice,
                (uint256(priceFeed.latestAnswer()) * oracleConversion).mulDivUp(100e3 - 30e3, 100e3)
            );
        }

        // Check max payout set correctly
        (, , , , , uint256 capacity, uint256 maxPayout, , ) = auctioneer.markets(id);
        uint256 payoutCapacity = _capacityInQuote ? capacity.mulDiv(scale, price) : capacity;
        assertEq(maxPayout, payoutCapacity.mulDiv(10e3, 100e3));
    }

    function testFail_CreateMarketParamOutOfBounds(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals
    ) public {
        require(
            !inFuzzRange(
                _payoutDecimals,
                _quoteDecimals,
                _payoutPriceDecimals,
                _quotePriceDecimals,
                _oracleDecimals
            ),
            "In fuzz range"
        );
        createMarket(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals,
            _oracleDecimals
        );
    }

    function testCorrectness_CannotCreateMarketWithInvalidParams() public {
        // Create tokens, etc.
        beforeEach(18, 18, true, 0, 0, 18);

        // Vesting: If not 0 (instant swap), must be greater than 1 day and less than 50 years

        // Less than 1 day
        IBondOFDA.MarketParams memory params = IBondOFDA.MarketParams(
            payoutToken, // ERC20 payoutToken
            quoteToken, // ERC20 quoteToken
            address(callback), // address callbackAddr
            oracle, // IBondOracle oracle
            uint48(10e3), // uint48 fixedDiscount
            uint48(30e3), // uint48 maxDiscountFromCurrent
            false, // bool capacityIn
            10000e18, // uint256 capacity
            uint48(7 days / 10), // uint48 depositInterval
            uint48(1 days) - 1, // uint48 vesting (timestamp or duration)
            uint48(block.timestamp + 7 days) // uint48 conclusion (timestamp)
        );

        bytes memory err = abi.encodeWithSignature("Auctioneer_InvalidParams()");
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));

        // Fixed Term vesting cannot be greater than 50 years
        params.vesting = uint48(52 weeks * 50) + 1;
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));

        // Values within the range and 0 (instant swap) are valid
        params.vesting = uint48(3 days);
        auctioneer.createMarket(abi.encode(params));

        params.vesting = uint48(0);
        auctioneer.createMarket(abi.encode(params));

        // Market duration must be greater than 1 day
        params.conclusion = uint48(block.timestamp + 1 days - 1);
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));

        params.conclusion = uint48(block.timestamp + 3 days);
        auctioneer.createMarket(abi.encode(params));

        params.conclusion = uint48(block.timestamp + 7 days);

        // Set maxDiscountFromCurrent high to test base discount
        params.maxDiscountFromCurrent = uint48(100e3);

        // Fixed discount must be between 0 and 100e3 (100%) (but not 100e3)
        params.fixedDiscount = uint48(100e3);
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));

        params.fixedDiscount = uint48(99e3);
        auctioneer.createMarket(abi.encode(params));

        // Set max discount from current lower and try to set base discount greater
        params.maxDiscountFromCurrent = uint48(30e3);
        params.fixedDiscount = uint48(30e3 + 1);
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));

        params.fixedDiscount = uint48(0);

        // Max discount from current price must be between 0 and 100e3 (100%)
        params.maxDiscountFromCurrent = uint48(100e3 + 1);
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));

        params.maxDiscountFromCurrent = uint48(0);
        auctioneer.createMarket(abi.encode(params));

        params.maxDiscountFromCurrent = uint48(100e3);
        auctioneer.createMarket(abi.encode(params));

        params.fixedDiscount = uint48(10e3);
        params.maxDiscountFromCurrent = uint48(30e3);

        // Deposit interval must be greater than the minimum deposit interval and less than or equal to the market duration
        params.depositInterval = uint48(1 hours - 1);
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));

        params.depositInterval = uint48(1 hours);
        auctioneer.createMarket(abi.encode(params));

        params.depositInterval = uint48(7 days + 1);
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));

        params.depositInterval = uint48(7 days);
        auctioneer.createMarket(abi.encode(params));

        params.depositInterval = uint48(1 days);

        // Price must be non-zero (will fail on oracle because it validates the feed)
        err = abi.encodeWithSignature("BondOracle_BadFeed(address)", address(priceFeed));

        int256 price = priceFeed.latestAnswer();
        priceFeed.setLatestAnswer(0);
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));
        priceFeed.setLatestAnswer(price);

        // Timestamp must be later than the update threshold
        priceFeed.setTimestamp(block.timestamp - 1 days - 1);
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));
    }

    function testCorrectness_OnlyGuardianCanSetAllowNewMarkets() public {
        beforeEach(18, 18, true, 0, 0, 18);

        // Don't allow normal users to change allowNewMarkets
        bytes memory err = abi.encodePacked("UNAUTHORIZED");
        vm.prank(alice);
        vm.expectRevert(err);
        auctioneer.setAllowNewMarkets(false);

        // Check that value is still true
        assert(auctioneer.allowNewMarkets());

        // Change allowNewMarkets to false as Guardian
        vm.prank(guardian);
        auctioneer.setAllowNewMarkets(false);

        // Check that the value is false
        assert(!auctioneer.allowNewMarkets());
    }

    function testFail_CannotCreateNewMarketsIfSunset() public {
        beforeEach(18, 18, true, 0, 0, 18);

        // Change allowNewMarkets to false as Guardian
        vm.prank(guardian);
        auctioneer.setAllowNewMarkets(false);

        // Try to create a new market, expect to fail
        createMarket(18, 18, true, 0, 0, 18);
    }

    function testCorrectness_OnlyGuardianCanSetCallbackAuthStatus() public {
        beforeEach(18, 18, true, 0, 0, 18);

        // Don't allow normal users to set callbackAuthorized values
        bytes memory err = abi.encodePacked("UNAUTHORIZED");
        vm.prank(alice);
        vm.expectRevert(err);
        auctioneer.setCallbackAuthStatus(alice, true);

        // Check that alice is not authorized to use callbacks still
        assert(!auctioneer.callbackAuthorized(alice));

        // Change callbackAuthStatus to false as Guardian
        vm.prank(guardian);
        auctioneer.setCallbackAuthStatus(alice, true);

        // Check that alice is authorized to use callbacks now
        assert(auctioneer.callbackAuthorized(alice));
    }

    function testCorrectness_CannotCreateMarketWithCallbackUnlessAuthorized() public {
        beforeEach(18, 18, true, 0, 0, 18);

        // Attempt to create a market with a callback without authorization
        bytes memory err = abi.encodeWithSignature("Auctioneer_NotAuthorized()");
        vm.prank(alice);
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));

        // Change allowNewMarkets to false as Guardian
        vm.prank(guardian);
        auctioneer.setCallbackAuthStatus(alice, true);

        // Create a market with a callback now that alice is authorized
        vm.prank(alice);
        uint256 id = auctioneer.createMarket(abi.encode(params));
        assertEq(id, 1);
    }

    function testCorrectness_RemovingFromWhitelistRevertsCurrentMarkets() public {
        // Create a market from this contract with a callback
        (uint256 id, uint256 price, uint256 scale) = beforeEach(18, 18, true, 0, 0, 18);

        // Purchase a bond to ensure it's working as intended
        uint256 amount = 50e18;
        uint256 fee = amount.mulDiv(teller.getFee(referrer), 1e5);
        uint256 minAmountOut = (amount - fee).mulDiv(price, scale) / 2;

        vm.prank(alice);
        teller.purchase(alice, referrer, id, amount, minAmountOut);

        // Remove this contract from the whitelist
        vm.prank(guardian);
        auctioneer.setCallbackAuthStatus(address(this), false);

        // Try to purchase a bond again, expect to fail
        bytes memory err = abi.encodeWithSignature("Auctioneer_NotAuthorized()");
        vm.expectRevert(err);
        vm.prank(alice);
        teller.purchase(alice, referrer, id, amount, minAmountOut);
    }

    function testCorrectness_ConcludeInCorrectAmountOfTime() public {
        (uint256 id, , ) = beforeEach(18, 6, true, 0, 0, 18);
        (, uint48 conclusion, , , , , ) = auctioneer.terms(id);

        assertEq(conclusion, uint48(block.timestamp + 7 days));
    }

    function testCorrectness_PurchaseBond(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals
    ) public {
        if (
            !inFuzzRange(
                _payoutDecimals,
                _quoteDecimals,
                _payoutPriceDecimals,
                _quotePriceDecimals,
                _oracleDecimals
            )
        ) return;
        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals,
            _oracleDecimals
        );

        // Set variables for purchase
        uint256 amount = 50 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);
        uint256 fee = amount.mulDiv(teller.getFee(referrer), 1e5);
        uint256 minAmountOut = (amount - fee).mulDiv(scale, price) / 2; // set low to avoid slippage error

        // Purchase a bond
        uint256[3] memory balancesBefore = [
            quoteToken.balanceOf(alice),
            quoteToken.balanceOf(address(callback)),
            payoutToken.balanceOf(alice)
        ];

        vm.prank(alice);
        (uint256 payout, ) = teller.purchase(alice, referrer, id, amount, minAmountOut);
        uint256[3] memory balancesAfter = [
            quoteToken.balanceOf(alice),
            quoteToken.balanceOf(address(callback)),
            payoutToken.balanceOf(alice)
        ];

        assertEq(balancesAfter[0], balancesBefore[0] - amount);
        assertEq(balancesAfter[1], balancesBefore[1] + amount - fee);
        assertGe(balancesAfter[2], balancesBefore[2] + payout);
    }

    function testCorrectness_purchase_minAmountOut(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals
    ) public {
        if (
            !inFuzzRange(
                _payoutDecimals,
                _quoteDecimals,
                _payoutPriceDecimals,
                _quotePriceDecimals,
                _oracleDecimals
            )
        ) return;
        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals,
            _oracleDecimals
        );

        // Set variables for purchase
        uint256 amount = 50 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);
        uint256 fee = amount.mulDiv(teller.getFee(referrer), 1e5);

        // Set minAmountOut to be more than the market will return
        uint256 minAmountOut = (amount - fee).mulDiv(scale, price) + 1;

        // Purchase a bond, expect revert
        bytes memory err = abi.encodeWithSignature("Auctioneer_AmountLessThanMinimum()");
        vm.expectRevert(err);
        vm.prank(alice);
        teller.purchase(alice, referrer, id, amount, minAmountOut);

        // Set minAmountOut at exactly the amount the market will return
        minAmountOut -= 1;

        // Purchase a bond, expect to succeed
        vm.prank(alice);
        teller.purchase(alice, referrer, id, amount, minAmountOut);
    }

    function testFuzz_fixedDiscount(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals,
        uint48 _fixedDiscount
    ) public {
        if (
            !inFuzzRange(
                _payoutDecimals,
                _quoteDecimals,
                _payoutPriceDecimals,
                _quotePriceDecimals,
                _oracleDecimals
            )
        ) return;
        if (_fixedDiscount >= 100e3) return;

        beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals,
            _oracleDecimals
        );

        // Change fixed discount
        params.fixedDiscount = _fixedDiscount;

        // Max discount from current must be larger than fixed discount
        params.maxDiscountFromCurrent = _fixedDiscount + 1;

        // Create market
        uint256 id = auctioneer.createMarket(abi.encode(params));
        uint256 price = auctioneer.marketPrice(id);

        // Get raw oracle price and oracle conversion
        (, , , , , , uint256 oracleConversion) = auctioneer.terms(id);
        uint256 oraclePrice = oracle.currentPrice(id) * oracleConversion;

        console2.log("price", price);
        console2.log("oraclePrice", oracle.currentPrice(id));
        console2.log("oracleConversion", oracleConversion);
        console2.log("scaledOraclePrice", oraclePrice);
        console2.log("discountedPrice", oraclePrice.mulDivUp(100e3 - params.fixedDiscount, 100e3));

        // Compare price and calculated price
        // With extreme values, some precision can be lost. Allow 1% deviation.
        assertApproxEqRel(price, oraclePrice.mulDivUp(100e3 - params.fixedDiscount, 100e3), 1e16);
    }

    function testCorrectness_fixedDiscount(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals
    ) public {
        if (
            !inFuzzRange(
                _payoutDecimals,
                _quoteDecimals,
                _payoutPriceDecimals,
                _quotePriceDecimals,
                _oracleDecimals
            )
        ) return;
        (uint256 id, , uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals,
            _oracleDecimals
        );

        (, uint48 conclusion, , , uint256 minPrice, , uint256 oracleConversion) = auctioneer.terms(
            id
        );
        uint48 length = conclusion - uint48(block.timestamp);

        // Confirm that price is correct
        assertEq(price, (uint256(priceFeed.latestAnswer()) * oracleConversion * 9) / 10);

        // Jump forward in time
        vm.warp(block.timestamp + uint256(length) / 10); // Move forward 10% of the market duration

        // Get price after time jump
        uint256 endPrice = auctioneer.marketPrice(id);

        // Check that price hasn't changed since no oracle update
        assertEq(endPrice, price);

        // Reduce oracle price by 10% and check that the discount is applied correctly
        int256 origFeedPrice = priceFeed.latestAnswer();
        priceFeed.setLatestAnswer((priceFeed.latestAnswer() * int256(9)) / int256(10));

        // Check that price is changed
        endPrice = auctioneer.marketPrice(id);

        assertEq(endPrice, (price * 9) / 10);

        // Set feed so that price is less than minPrice (30% lower than original), with a 10% discount this will be less than minPrice
        priceFeed.setLatestAnswer((origFeedPrice * int256(7)) / int256(10));

        endPrice = auctioneer.marketPrice(id);
        assertEq(endPrice, minPrice);
    }

    function testCorrectness_OracleChangeAdjustsPrice(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals
    ) public {
        if (
            !inFuzzRange(
                _payoutDecimals,
                _quoteDecimals,
                _payoutPriceDecimals,
                _quotePriceDecimals,
                _oracleDecimals
            )
        ) return;
        (uint256 id, , uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals,
            _oracleDecimals
        );

        // Change oracle price up
        int256 startAnswer = priceFeed.latestAnswer();
        int256 newAnswer = (startAnswer * 115) / 100;
        priceFeed.setLatestAnswer(newAnswer);

        // Get market price after oracle change
        uint256 newPrice = auctioneer.marketPrice(id);
        assertEq(newPrice, price.mulDiv(115, 100));

        // Change oracle price down
        newAnswer = (startAnswer * 85) / 100;
        priceFeed.setLatestAnswer(newAnswer);

        // Get market price after oracle change
        newPrice = auctioneer.marketPrice(id);
        assertEq(newPrice, price.mulDiv(85, 100));
    }

    function testRevert_purchase_BadOracleFeed(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals
    ) public {
        if (
            !inFuzzRange(
                _payoutDecimals,
                _quoteDecimals,
                _payoutPriceDecimals,
                _quotePriceDecimals,
                _oracleDecimals
            )
        ) return;
        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals,
            _oracleDecimals
        );

        // Make oracle timestamp stale
        priceFeed.setTimestamp(block.timestamp - 48 hours);

        // Set amounts for purchase
        uint256 amount = 50 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);
        uint256 minAmountOut = amount.mulDiv(scale, price).mulDiv(
            1e5 - teller.getFee(referrer),
            1e5
        );

        // Try to purchase, expect to fail
        bytes memory err = abi.encodeWithSignature(
            "BondOracle_BadFeed(address)",
            address(priceFeed)
        );
        vm.expectRevert(err);
        vm.prank(alice);
        teller.purchase(alice, referrer, id, amount, minAmountOut);

        // Set timestamp back to normal and make price invalid
        priceFeed.setTimestamp(block.timestamp);
        priceFeed.setLatestAnswer(int256(0));

        // Try to purchase, expect to fail
        vm.expectRevert(err);
        vm.prank(alice);
        teller.purchase(alice, referrer, id, amount, minAmountOut);
    }

    function testCorrectness_MarketScale(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals
    ) public {
        if (
            !inFuzzRange(
                _payoutDecimals,
                _quoteDecimals,
                _payoutPriceDecimals,
                _quotePriceDecimals,
                _oracleDecimals
            )
        ) return;

        (uint256 id, uint256 expectedScale, ) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals,
            _oracleDecimals
        );

        uint256 scale = aggregator.marketScale(id);

        assertEq(scale, expectedScale);
    }

    function testCorrectness_PayoutFor(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals
    ) public {
        if (
            !inFuzzRange(
                _payoutDecimals,
                _quoteDecimals,
                _payoutPriceDecimals,
                _quotePriceDecimals,
                _oracleDecimals
            )
        ) return;

        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals,
            _oracleDecimals
        );

        uint256 amountIn = 50 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);
        uint256 fee = amountIn.mulDiv(teller.getFee(referrer), 1e5);
        uint256 payout = aggregator.payoutFor(amountIn, id, referrer);
        uint256 expectedPayout = (amountIn - fee).mulDiv(scale, price);

        // Check that the values are equal
        assertEq(payout, expectedPayout);
    }

    function testCorrectness_maxAmountAccepted(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals,
        uint8 _oracleDecimals
    ) public {
        if (
            !inFuzzRange(
                _payoutDecimals,
                _quoteDecimals,
                _payoutPriceDecimals,
                _quotePriceDecimals,
                _oracleDecimals
            )
        ) return;

        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals,
            _oracleDecimals
        );

        // Get max amount accepted from the market
        uint256 amount = auctioneer.maxAmountAccepted(id, referrer);

        // Case: maxPayout <= capacity
        // Calculate expected amount from max payout, price, scale, and fees
        uint256 maxPayout = auctioneer.maxPayout(id);
        uint256 expAmount = maxPayout.mulDiv(price, scale);
        uint256 estimatedFee = expAmount.mulDiv(teller.getFee(referrer), 1e5);

        assertEq(amount, expAmount + estimatedFee);

        // Case: maxPayout > capacity

        // Purchase several bonds to almost expend market capacity
        (, uint48 conclusion, , , , , ) = auctioneer.terms(id);
        uint48 length = conclusion - uint48(block.timestamp);
        uint256 time = block.timestamp;
        for (uint256 i; i < 9; ++i) {
            vm.prank(alice);
            teller.purchase(alice, referrer, id, amount, 0);
            time += uint256(length) / 10;
            vm.warp(time);
            priceFeed.setTimestamp(time);
        }

        vm.prank(alice);
        teller.purchase(alice, referrer, id, amount / 2, 0);

        // 5% of capacity should be remaining whereas a max bond is 10% of capacity
        (, , , , bool capacityInQuote, uint256 capacity, , , ) = auctioneer.markets(id);
        price = auctioneer.marketPrice(id);
        capacity = capacityInQuote ? capacity : capacity.mulDiv(price, scale);
        estimatedFee = capacity.mulDiv(teller.getFee(referrer), 1e5);
        amount = auctioneer.maxAmountAccepted(id, referrer);

        assertEq(amount, capacity + estimatedFee);
    }

    function testCorrectness_isInstantSwap() public {
        (uint256 id1, , ) = beforeEach(18, 18, false, 0, 0, 18);

        // Fixed term markets are instant swap if the vesting period is 0

        // First market has a vesting period of 0, so it should be instant swap
        assertTrue(auctioneer.isInstantSwap(id1));

        // Create a new market with non-zero vesting
        params.vesting = uint48(2 days);
        uint256 id2 = auctioneer.createMarket(abi.encode(params));

        // Second market should not be instant swap
        assertFalse(auctioneer.isInstantSwap(id2));
    }

    function testCorrectness_isLive(uint48 conclusion_) public {
        if (conclusion_ < block.timestamp + 1 days || conclusion_ > block.timestamp + 365 days)
            return;
        beforeEach(18, 18, false, 0, 0, 18);

        params.conclusion = conclusion_;
        params.depositInterval = uint48(conclusion_ - block.timestamp) / 10;
        uint256 id = auctioneer.createMarket(abi.encode(params));
        (, uint48 conclusion, , , , , ) = auctioneer.terms(id);
        uint48 length = uint48(conclusion - block.timestamp);

        // Markets are live if their capacity > 0 and the current time is before the market conclusion

        // Case: capacity > 0, time < conclusion -> True
        assertTrue(auctioneer.isLive(id));

        // Case: capacity > 0, time >= conclusion -> False
        vm.warp(conclusion);
        assertFalse(auctioneer.isLive(id));

        vm.warp(conclusion + 1);
        assertFalse(auctioneer.isLive(id));

        // Case: capacity = 0, time < conclusion -> False
        vm.warp(conclusion - length);
        assertTrue(auctioneer.isLive(id));

        // Set fees to 0 to make it easier to deplete capacity
        vm.prank(guardian);
        teller.setProtocolFee(0);

        // Purchase all capacity, keep time less than conclusion
        uint256 time = uint256(conclusion - length);
        uint256 amount = auctioneer.maxAmountAccepted(id, alice);
        for (uint256 i; i < 11; ++i) {
            console2.log(auctioneer.currentCapacity(id));
            vm.prank(alice);
            teller.purchase(alice, alice, id, amount, 0);
            if (time < conclusion - length / 10) {
                time += length / 10;
                vm.warp(time);
                priceFeed.setTimestamp(time);
            }
            amount = auctioneer.maxAmountAccepted(id, alice);
        }

        assertEq(auctioneer.currentCapacity(id), 0);
        assertLt(time, conclusion);
        assertFalse(auctioneer.isLive(id));

        // Case: capacity = 0, time >= conclusion -> False
        vm.warp(conclusion);
        assertFalse(auctioneer.isLive(id));

        vm.warp(conclusion + 1);
        assertFalse(auctioneer.isLive(id));
    }

    function testCorrectness_ownerOf(address addr) public {
        (uint256 id, , ) = beforeEach(18, 18, false, 0, 0, 18);

        // Confirm first market is owned by the test contract
        assertEq(auctioneer.ownerOf(id), address(this));

        // Authorize the supplied address to use a callback
        vm.prank(guardian);
        auctioneer.setCallbackAuthStatus(addr, true);

        // Create a new market with supplied address
        vm.prank(addr);
        uint256 id2 = auctioneer.createMarket(abi.encode(params));

        // Confirm second market is owned by the supplied address
        assertEq(auctioneer.ownerOf(id2), addr);
    }

    function testCorrectness_MarketOwnershipPushAndPull() public {
        (uint256 id, , ) = beforeEach(18, 18, false, 0, 0, 18);

        // Attempt to set new owner with non-owner account
        bytes memory err1 = abi.encodeWithSignature("Auctioneer_OnlyMarketOwner()");
        vm.expectRevert(err1);
        vm.prank(alice);
        auctioneer.pushOwnership(id, alice);

        // Push new owner with owner account
        auctioneer.pushOwnership(id, bob);

        // Check that newOwner is set, but owner is not
        (address owner, , , , , , , , ) = auctioneer.markets(id);
        address newOwner = auctioneer.newOwners(id);
        assertEq(owner, address(this));
        assertEq(newOwner, bob);

        // Try to pull with a different address
        bytes memory err2 = abi.encodeWithSignature("Auctioneer_NotAuthorized()");
        vm.expectRevert(err2);
        vm.prank(alice);
        auctioneer.pullOwnership(id);

        // Pull ownership with newOwner account
        vm.prank(bob);
        auctioneer.pullOwnership(id);

        (owner, , , , , , , , ) = auctioneer.markets(id);
        newOwner = auctioneer.newOwners(id);
        assertEq(owner, bob);
        assertEq(newOwner, bob);
    }

    function testCorrectness_closeMarket_onlyMarketOwner(address addr) public {
        vm.assume(addr != address(this));
        (uint256 id, , ) = beforeEach(18, 18, false, 0, 0, 18);

        assertTrue(auctioneer.isLive(id));

        // Try to close the market with an address that's not the owner, expect to fail
        bytes memory err = abi.encodeWithSignature("Auctioneer_OnlyMarketOwner()");
        vm.expectRevert(err);
        vm.prank(addr);
        auctioneer.closeMarket(id);

        assertTrue(auctioneer.isLive(id));

        // Close market with owner (this contract)
        auctioneer.closeMarket(id);

        assertTrue(!auctioneer.isLive(id));
    }

    function testCorrectness_OnlyPolicyCanSetDefaults() public {
        beforeEach(18, 18, false, 0, 0, 18);

        // Attempt to set new intervals with non-policy account
        bytes memory err = abi.encodePacked("UNAUTHORIZED");
        vm.expectRevert(err);
        vm.prank(alice);
        auctioneer.setMinMarketDuration(uint48(4 days));

        vm.expectRevert(err);
        vm.prank(alice);
        auctioneer.setMinDepositInterval(uint48(4 hours));

        // Set new intervals as policy
        uint48 expMinDepositInterval = 2 hours;
        uint48 expMinMarketDuration = 2 days;

        vm.prank(policy);
        auctioneer.setMinMarketDuration(expMinMarketDuration);
        assertEq(auctioneer.minMarketDuration(), expMinMarketDuration);

        vm.prank(policy);
        auctioneer.setMinDepositInterval(expMinDepositInterval);
        assertEq(auctioneer.minDepositInterval(), expMinDepositInterval);
    }

    function testRevert_CannotSetDefaultsOutofBounds() public {
        beforeEach(18, 18, false, 0, 0, 18);

        bytes memory err = abi.encodeWithSignature("Auctioneer_InvalidParams()");

        // Set min deposit interval and market duration to a value easier to test against (use time values in solidity)
        vm.prank(policy);
        auctioneer.setMinMarketDuration(uint48(4 days));

        vm.prank(policy);
        auctioneer.setMinDepositInterval(uint48(36 hours));

        // Attempt to set new minMarketDuration less than minDepositInterval, expect revert
        vm.expectRevert(err);
        vm.prank(policy);
        auctioneer.setMinMarketDuration(uint48(32 hours));

        // Attempt to set new minDepositInterval greater than minMarketDuration, expect revert
        vm.expectRevert(err);
        vm.prank(policy);
        auctioneer.setMinDepositInterval(uint48(5 days));

        // Attempt to set minDepositInterval below 1 hour, expect revert
        vm.expectRevert(err);
        vm.prank(policy);
        auctioneer.setMinDepositInterval(uint48(1 hours - 1));

        // Set minDepositInterval below 1 day to test minMarketDuration limit
        vm.prank(policy);
        auctioneer.setMinDepositInterval(uint48(12 hours));

        // Attempt to set min market duration below 1 day, expect revert
        vm.expectRevert(err);
        vm.prank(policy);
        auctioneer.setMinMarketDuration(uint48(18 hours));
    }

    function testCorrectness_FeesPaidInQuoteToken() public {
        (uint256 id, uint256 scale, uint256 price) = beforeEach(18, 18, false, 0, 0, 18);

        // Purchase a bond to accumulate a fee for protocol
        uint256 amount = 5000 * 1e18;
        uint256 minAmountOut = amount.mulDiv(1e5 - teller.getFee(referrer), 1e5).mulDiv(
            scale,
            price
        );

        vm.prank(alice);
        teller.purchase(alice, referrer, id, amount, minAmountOut);

        // Get fees and check balances
        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = quoteToken;

        vm.prank(policy);
        teller.claimFees(tokens, treasury);

        vm.prank(referrer);
        teller.claimFees(tokens, referrer);

        assertEq(quoteToken.balanceOf(treasury), amount.mulDiv(100, 1e5));
        assertEq(quoteToken.balanceOf(referrer), amount.mulDiv(200, 1e5));
    }

    function testCorrectness_OnlyGuardianCanSetProtocolFee() public {
        beforeEach(18, 18, false, 0, 0, 18);

        // Attempt to set new fees with non-guardian account
        bytes memory err = abi.encodePacked("UNAUTHORIZED");
        vm.expectRevert(err);
        vm.prank(alice);
        teller.setProtocolFee(0);

        // Attempt to set a fee greater than the max (5%)
        err = abi.encodeWithSignature("Teller_InvalidParams()");
        vm.expectRevert(err);
        vm.prank(guardian);
        teller.setProtocolFee(6e3);

        // Set new fees as guardian
        uint48 expFee = 500;

        vm.prank(guardian);
        teller.setProtocolFee(expFee);

        assertEq(teller.protocolFee(), expFee);
    }

    function testCorrectness_OnlyGuardianCanSetCreateFeeDiscount() public {
        beforeEach(18, 18, false, 0, 0, 18);

        // Attempt to set new fees with non-guardian account
        bytes memory err = abi.encodePacked("UNAUTHORIZED");
        vm.expectRevert(err);
        vm.prank(alice);
        teller.setCreateFeeDiscount(0);

        // Attempt to set a fee greater than the protocol fee
        err = abi.encodeWithSignature("Teller_InvalidParams()");
        uint48 discount = teller.protocolFee() + 1;
        vm.expectRevert(err);
        vm.prank(guardian);
        teller.setCreateFeeDiscount(discount);

        // Set new create fee discount as guardian
        discount = 50;

        vm.prank(guardian);
        teller.setCreateFeeDiscount(discount);

        assertEq(teller.createFeeDiscount(), discount);
    }

    function testCorrectness_ReferrerCanSetOwnFee() public {
        beforeEach(18, 18, false, 0, 0, 18);

        // Attempt to set fee above the max value (5e4) and expect to fail
        bytes memory err = abi.encodeWithSignature("Teller_InvalidParams()");
        vm.expectRevert(err);
        vm.prank(referrer);
        teller.setReferrerFee(6e4);

        // Confirm that the fee is still set to the initialized value
        assertEq(teller.referrerFees(referrer), uint48(200));

        // Set the fee to an allowed value
        uint48 expFee = 500;
        vm.prank(referrer);
        teller.setReferrerFee(expFee);

        // Confirm that the fee is set to the new value
        assertEq(teller.referrerFees(referrer), expFee);
    }

    function testCorrectness_getFee() public {
        beforeEach(18, 18, false, 0, 0, 18);

        // Check that the fee set the protocol is correct (use zero address for referrer)
        assertEq(teller.getFee(address(0)), uint48(100));

        // Check that the fee set the protocol + referrer is correct
        assertEq(teller.getFee(referrer), uint48(300));
    }

    function testCorrectness_liveMarketsBetween() public {
        // Setup tests and create multiple markets
        (uint256 id1, , ) = beforeEach(18, 18, false, 0, 0, 18);
        (uint256 id2, , ) = createMarket(18, 6, true, 3, 0, 18);
        (uint256 id3, , ) = createMarket(9, 6, true, 1, 0, 18);
        (uint256 id4, , ) = createMarket(18, 9, true, -2, 1, 18);
        (uint256 id5, , ) = createMarket(6, 9, true, 0, 1, 18);

        // Get first 3 markets
        {
            uint256[] memory liveMarkets = aggregator.liveMarketsBetween(0, 3);
            assertEq(liveMarkets.length, 3);
            assertEq(liveMarkets[0], id1);
            assertEq(liveMarkets[1], id2);
            assertEq(liveMarkets[2], id3);
        }

        // Get last 3 markets
        {
            uint256[] memory liveMarkets = aggregator.liveMarketsBetween(2, 5);
            assertEq(liveMarkets.length, 3);
            assertEq(liveMarkets[0], id3);
            assertEq(liveMarkets[1], id4);
            assertEq(liveMarkets[2], id5);
        }

        // Get middle 3 markets
        {
            uint256[] memory liveMarkets = aggregator.liveMarketsBetween(1, 4);
            assertEq(liveMarkets.length, 3);
            assertEq(liveMarkets[0], id2);
            assertEq(liveMarkets[1], id3);
            assertEq(liveMarkets[2], id4);
        }

        // Get 1 market
        {
            uint256[] memory liveMarkets = aggregator.liveMarketsBetween(1, 2);
            assertEq(liveMarkets.length, 1);
            assertEq(liveMarkets[0], id2);
        }
    }

    function testCorrectness_liveMarketsFor() public {
        // Setup tests and create multiple markets
        (uint256 id1, , ) = beforeEach(18, 18, false, 3, 0, 18);

        // Create new tokens
        payoutToken = new MockERC20("Payout Token Two", "BT2", 18);
        quoteToken = new MockERC20("Quote Token Two", "BT2", 6);

        // Set pairs on the oracle
        bytes memory oracleData = abi.encode(
            priceFeed,
            uint48(1 days),
            MockPriceFeed(address(0)),
            0,
            18,
            false
        );
        oracle.setPair(quoteToken, payoutToken, true, oracleData);

        // Create market with new tokens
        (uint256 id2, , ) = createMarket(18, 6, true, 0, 0, 18);

        // Get 4 tokens that have been created
        (, ERC20 payoutToken1, ERC20 quoteToken1, , , , , , ) = auctioneer.markets(id1);
        (, ERC20 payoutToken2, ERC20 quoteToken2, , , , , , ) = auctioneer.markets(id2);

        // Create market with blend of tokens, set on oracle first
        oracle.setPair(payoutToken1, quoteToken2, true, oracleData);

        uint256 id3 = auctioneer.createMarket(
            abi.encode(
                IBondOFDA.MarketParams(
                    quoteToken2, // ERC20 payoutToken
                    payoutToken1, // ERC20 quoteToken
                    address(callback), // address callbackAddr
                    oracle, // IBondOracle oracle
                    uint48(0), // uint48 fixedDiscount
                    uint48(20e3), // uint48 maxDiscountFromCurrent
                    false, // bool capacityIn
                    10000e18, // uint256 capacity
                    uint48(7 days / 10), // uint48 deposit Interval
                    uint48(0), // uint48 vesting (timestamp or duration)
                    uint48(block.timestamp + 7 days) // uint48 conclusion (timestamp)
                )
            )
        );

        // Get markets for tokens
        {
            uint256[] memory markets = aggregator.liveMarketsFor(address(payoutToken1), true);
            assertEq(markets.length, 1);
            assertEq(markets[0], id1);
        }
        {
            uint256[] memory markets = aggregator.liveMarketsFor(address(payoutToken1), false);
            assertEq(markets.length, 1);
            assertEq(markets[0], id3);
        }
        {
            uint256[] memory markets = aggregator.liveMarketsFor(address(payoutToken2), true);
            assertEq(markets.length, 1);
            assertEq(markets[0], id2);
        }
        {
            uint256[] memory markets = aggregator.liveMarketsFor(address(payoutToken2), false);
            assertEq(markets.length, 0);
        }
        {
            uint256[] memory markets = aggregator.liveMarketsFor(address(quoteToken1), true);
            assertEq(markets.length, 0);
        }
        {
            uint256[] memory markets = aggregator.liveMarketsFor(address(quoteToken1), false);
            assertEq(markets.length, 1);
            assertEq(markets[0], id1);
        }
        {
            uint256[] memory markets = aggregator.liveMarketsFor(address(quoteToken2), true);
            assertEq(markets.length, 1);
            assertEq(markets[0], id3);
        }
        {
            uint256[] memory markets = aggregator.liveMarketsFor(address(quoteToken2), false);
            assertEq(markets.length, 1);
            assertEq(markets[0], id2);
        }
    }

    function testCorrectness_marketsFor() public {
        // Setup tests and create multiple markets
        (uint256 id1, , ) = beforeEach(18, 18, false, 3, 0, 18);

        // Create new tokens
        payoutToken = new MockERC20("Payout Token Two", "BT2", 18);
        quoteToken = new MockERC20("Quote Token Two", "BT2", 6);

        // Set pairs on the oracle
        bytes memory oracleData = abi.encode(
            priceFeed,
            uint48(1 days),
            MockPriceFeed(address(0)),
            0,
            18,
            false
        );
        oracle.setPair(quoteToken, payoutToken, true, oracleData);

        // Create market with new tokens
        (uint256 id2, , ) = createMarket(18, 6, true, 0, 0, 18);

        // Get 4 tokens that have been created
        (, ERC20 payoutToken1, ERC20 quoteToken1, , , , , , ) = auctioneer.markets(id1);
        (, ERC20 payoutToken2, ERC20 quoteToken2, , , , , , ) = auctioneer.markets(id2);

        // Create market with blend of tokens, set on oracle first
        oracle.setPair(payoutToken1, quoteToken2, true, oracleData);

        uint256 id3 = auctioneer.createMarket(
            abi.encode(
                IBondOFDA.MarketParams(
                    quoteToken2, // ERC20 payoutToken
                    payoutToken1, // ERC20 quoteToken
                    address(callback), // address callbackAddr
                    oracle, // IBondOracle oracle
                    uint48(0), // uint48 fixedDiscount
                    uint48(20e3), // uint48 maxDiscountFromCurrent
                    false, // bool capacityIn
                    10000e18, // uint256 capacity
                    uint48(7 days / 10), // uint48 deposit Interval
                    uint48(0), // uint48 vesting (timestamp or duration)
                    uint48(block.timestamp + 7 days) // uint48 conclusion (timestamp)
                )
            )
        );

        // Get markets for tokens
        {
            uint256[] memory markets = aggregator.marketsFor(
                address(payoutToken1),
                address(quoteToken1)
            );
            assertEq(markets.length, 1);
            assertEq(markets[0], id1);
        }
        {
            uint256[] memory markets = aggregator.marketsFor(
                address(payoutToken1),
                address(quoteToken2)
            );
            assertEq(markets.length, 0);
        }
        {
            uint256[] memory markets = aggregator.marketsFor(
                address(payoutToken2),
                address(quoteToken1)
            );
            assertEq(markets.length, 0);
        }
        {
            uint256[] memory markets = aggregator.marketsFor(
                address(payoutToken2),
                address(quoteToken2)
            );
            assertEq(markets.length, 1);
            assertEq(markets[0], id2);
        }
        {
            uint256[] memory markets = aggregator.marketsFor(
                address(quoteToken1),
                address(payoutToken1)
            );
            assertEq(markets.length, 0);
        }
        {
            uint256[] memory markets = aggregator.marketsFor(
                address(quoteToken1),
                address(payoutToken2)
            );
            assertEq(markets.length, 0);
        }
        {
            uint256[] memory markets = aggregator.marketsFor(
                address(quoteToken2),
                address(payoutToken1)
            );
            assertEq(markets.length, 1);
            assertEq(markets[0], id3);
        }
        {
            uint256[] memory markets = aggregator.marketsFor(
                address(quoteToken2),
                address(payoutToken2)
            );
            assertEq(markets.length, 0);
        }
    }

    function testCorrectness_findMarketFor() public {
        // Setup tests and create multiple markets
        (uint256 id1, , ) = beforeEach(18, 18, false, 3, 0, 18);

        // Create new tokens
        payoutToken = new MockERC20("Payout Token Two", "BT2", 18);
        quoteToken = new MockERC20("Quote Token Two", "BT2", 6);

        // Set pairs on the oracle
        bytes memory oracleData = abi.encode(
            priceFeed,
            uint48(1 days),
            MockPriceFeed(address(0)),
            0,
            18,
            false
        );
        oracle.setPair(quoteToken, payoutToken, true, oracleData);

        // Create market with new tokens
        (uint256 id2, , ) = createMarket(18, 6, true, 0, 0, 18);

        // Get 4 tokens that have been created
        (, ERC20 payoutToken1, ERC20 quoteToken1, , , , , , ) = auctioneer.markets(id1);
        (, ERC20 payoutToken2, ERC20 quoteToken2, , , , , , ) = auctioneer.markets(id2);

        // Create market with blend of tokens, set on oracle first
        oracle.setPair(payoutToken1, quoteToken2, true, oracleData);

        uint256 id3 = auctioneer.createMarket(
            abi.encode(
                IBondOFDA.MarketParams(
                    quoteToken2, // ERC20 payoutToken
                    payoutToken1, // ERC20 quoteToken
                    address(callback), // address callbackAddr
                    oracle, // IBondOracle oracle
                    uint48(0), // uint48 fixedDiscount
                    uint48(20e3), // uint48 maxDiscountFromCurrent
                    false, // bool capacityIn
                    10000e18, // uint256 capacity
                    uint48(7 days / 10), // uint48 deposit Interval
                    uint48(0), // uint48 vesting (timestamp or duration)
                    uint48(block.timestamp + 7 days) // uint48 conclusion (timestamp)
                )
            )
        );

        // Get markets for tokens
        {
            uint256 marketId = aggregator.findMarketFor(
                address(payoutToken1),
                address(quoteToken1),
                5e21,
                1,
                block.timestamp + 30 days
            );
            assertEq(marketId, id1);
        }
        {
            uint256 marketId = aggregator.findMarketFor(
                address(payoutToken2),
                address(quoteToken2),
                5e6,
                1,
                block.timestamp + 30 days
            );
            assertEq(marketId, id2);
        }
        {
            uint256 marketId = aggregator.findMarketFor(
                address(quoteToken2),
                address(payoutToken1),
                5e18,
                1,
                block.timestamp + 30 days
            );
            assertEq(marketId, id3);
        }
    }

    function testCorrectness_liveMarketsBy() public {
        // Setup tests and create multiple markets
        (uint256 id1, , ) = beforeEach(18, 18, false, 3, 0, 18);
        (uint256 id2, , ) = createMarket(18, 18, false, 3, 0, 18);

        // Approve new owner for callback
        vm.prank(guardian);
        auctioneer.setCallbackAuthStatus(bob, true);

        // Create a market with a different owner
        vm.prank(bob);
        uint256 id3 = auctioneer.createMarket(
            abi.encode(
                IBondOFDA.MarketParams(
                    payoutToken, // ERC20 payoutToken
                    quoteToken, // ERC20 quoteToken
                    address(callback), // address callbackAddr
                    oracle, // IBondOracle oracle
                    uint48(0), // uint48 fixedDiscount
                    uint48(20e3), // uint48 maxDiscountFromCurrent
                    false, // bool capacityIn
                    10000e18, // uint256 capacity
                    uint48(7 days / 10), // uint48 deposit Interval
                    uint48(0), // uint48 vesting (timestamp or duration)
                    uint48(block.timestamp + 7 days) // uint48 conclusion (timestamp)
                )
            )
        );

        // Get markets by owners
        {
            uint256[] memory markets = aggregator.liveMarketsBy(
                address(this),
                0,
                aggregator.marketCounter()
            );
            assertEq(markets.length, 2);
            assertEq(markets[0], id1);
            assertEq(markets[1], id2);
        }
        {
            uint256[] memory markets = aggregator.liveMarketsBy(bob, 0, aggregator.marketCounter());
            assertEq(markets.length, 1);
            assertEq(markets[0], id3);
        }
    }

    function testCorrectness_ProtocolAndReferrerCanRedeemFees() public {
        // Create market and purchase a couple bonds so there are fees to claim
        (uint256 id, uint256 scale, uint256 price) = beforeEach(18, 18, false, 0, 0, 18);
        uint256 amount = 50 * 1e18;
        uint256 minAmountOut = amount.mulDiv(scale / 2, price);

        vm.prank(alice);
        teller.purchase(alice, referrer, id, amount, minAmountOut);

        vm.prank(alice);
        teller.purchase(alice, referrer, id, amount, minAmountOut);

        vm.prank(alice);
        teller.purchase(alice, referrer, id, amount, minAmountOut);

        // Try to redeem fees as non-protocol account
        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = quoteToken;
        uint256 totalAmount = amount * 3;

        // Redeem fees for protocol
        {
            uint256 startBal = quoteToken.balanceOf(treasury);
            vm.prank(policy);
            teller.claimFees(tokens, treasury);
            uint256 endBal = quoteToken.balanceOf(treasury);
            assertEq(endBal, startBal + totalAmount.mulDiv(100, 1e5));
        }

        // Redeem fees for referrer
        {
            uint256 startBal = quoteToken.balanceOf(referrer);
            vm.prank(referrer);
            teller.claimFees(tokens, referrer);
            uint256 endBal = quoteToken.balanceOf(referrer);
            assertEq(endBal, startBal + totalAmount.mulDiv(200, 1e5));
        }
    }

    function testCorrectness_FOTQuoteTokenFailsPurchase() public {
        // Initialize protocol
        beforeEach(18, 18, false, 0, 0, 18);

        // Deploy fee-on-transfer (FOT) token
        MockFOTERC20 fotToken = new MockFOTERC20("FOT Token", "FOT", 18, bob, 1e3); // 1% fee on transfer to bob

        // Send FOT token to user for purchase and approve teller for FOT token
        fotToken.mint(alice, 5000 * 1e18);

        vm.prank(alice);
        fotToken.approve(address(teller), 5000 * 1e18);

        // Set price feed for pair on the oracle
        bytes memory oracleData = abi.encode(
            priceFeed,
            uint48(24 hours),
            MockPriceFeed(address(0)),
            uint48(0),
            18,
            false
        );
        oracle.setPair(fotToken, payoutToken, true, oracleData);

        // Create market with FOT token as quote token
        uint256 id = auctioneer.createMarket(
            abi.encode(
                IBondOFDA.MarketParams(
                    payoutToken, // ERC20 payoutToken
                    fotToken, // ERC20 quoteToken
                    address(callback), // address callbackAddr
                    oracle, // IBondOracle oracle
                    uint48(0), // uint48 fixedDiscount
                    uint48(20e3), // uint48 maxDiscountFromCurrent
                    false, // bool capacityIn
                    10000e18, // uint256 capacity
                    uint48(7 days / 10), // uint48 deposit Interval
                    uint48(0), // uint48 vesting (timestamp or duration)
                    uint48(block.timestamp + 7 days) // uint48 conclusion (timestamp)
                )
            )
        );

        // Try to purchase a bond and expect revert
        uint256 price = auctioneer.marketPrice(id);
        uint256 scale = auctioneer.marketScale(id);
        uint256 amount = 50 * 1e18;
        uint256 minAmountOut = amount.mulDiv(scale / 2, price);

        bytes memory err = abi.encodeWithSignature("Teller_UnsupportedToken()");
        vm.prank(alice);
        vm.expectRevert(err);
        teller.purchase(alice, referrer, id, amount, minAmountOut);
    }

    function testCorrectness_FOTPayoutTokenFailsPurchase() public {
        // Initialize protocol
        beforeEach(18, 18, false, 0, 0, 18);

        // Deploy fee-on-transfer (FOT) token
        MockFOTERC20 fotToken = new MockFOTERC20("FOT Token", "FOT", 18, bob, 1e3); // 1% fee on transfer to bob
        BondSampleCallback fotCallback = new BondSampleCallback(aggregator);

        // Mint FOT token to this address for payouts
        fotToken.mint(address(fotCallback), 1000 * 1e18);

        // Set price feed for pair on the oracle
        bytes memory oracleData = abi.encode(
            priceFeed,
            uint48(24 hours),
            MockPriceFeed(address(0)),
            uint48(0),
            18,
            false
        );
        oracle.setPair(quoteToken, fotToken, true, oracleData);

        // Create market with FOT token as payout token
        uint256 id = auctioneer.createMarket(
            abi.encode(
                IBondOFDA.MarketParams(
                    fotToken, // ERC20 payoutToken
                    quoteToken, // ERC20 quoteToken
                    address(fotCallback), // address callbackAddr
                    oracle, // IBondOracle oracle
                    uint48(0), // uint48 fixedDiscount
                    uint48(20e3), // uint48 maxDiscountFromCurrent
                    false, // bool capacityIn
                    10000e18, // uint256 capacity
                    uint48(7 days / 10), // uint48 depositInterval
                    uint48(0), // uint48 vesting (timestamp or duration)
                    uint48(block.timestamp + 7 days) // uint48 conclusion (timestamp)
                )
            )
        );

        // Register market on callback
        fotCallback.whitelist(address(teller), id);

        // Try to purchase a bond and expect revert
        uint256 price = auctioneer.marketPrice(id);
        uint256 scale = auctioneer.marketScale(id);
        uint256 amount = 50 * 1e18;
        uint256 minAmountOut = amount.mulDiv(scale / 2, price);

        bytes memory err = abi.encodeWithSignature("Teller_InvalidCallback()");
        vm.prank(alice);
        vm.expectRevert(err);
        teller.purchase(alice, referrer, id, amount, minAmountOut);
    }
}
// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {Utilities} from "../utils/Utilities.sol";
import {console2} from "forge-std/console2.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {RolesAuthority, Authority} from "solmate/auth/authorities/RolesAuthority.sol";
import {MockFOTERC20} from "../utils/mocks/MockFOTERC20.sol";

import {IBondFPA} from "../../interfaces/IBondFPA.sol";
import {IBondCallback} from "../../interfaces/IBondCallback.sol";

import {BondFixedExpiryFPA} from "../../BondFixedExpiryFPA.sol";
import {BondFixedExpiryTeller} from "../../BondFixedExpiryTeller.sol";
import {BondAggregator} from "../../BondAggregator.sol";
import {ERC20BondToken} from "../../ERC20BondToken.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {FullMath} from "../../lib/FullMath.sol";

contract MaliciousBondToken is ERC20 {
    ERC20 public underlying;
    uint48 public expiry;

    constructor(ERC20 underlying_, uint48 expiry_)
        ERC20("Malicious Bond Token", "MBT", underlying_.decimals())
    {
        underlying = underlying_;
        expiry = expiry_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract BondFixedExpiryFPAV1Test is Test {
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
    BondFixedExpiryFPA internal auctioneer;
    BondFixedExpiryTeller internal teller;
    BondAggregator internal aggregator;
    MockERC20 internal payoutToken;
    MockERC20 internal quoteToken;
    IBondFPA.MarketParams internal params;

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
        teller = new BondFixedExpiryTeller(policy, aggregator, guardian, auth);
        auctioneer = new BondFixedExpiryFPA(teller, aggregator, guardian, auth);

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
        int8 _quotePriceDecimals
    )
        internal
        returns (
            uint256 id,
            uint256 scale,
            uint256 price
        )
    {
        uint256 capacity = _capacityInQuote
            ? 500_000 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals)
            : 100_000 * 10**uint8(int8(_payoutDecimals) - _payoutPriceDecimals);

        int8 scaleAdjustment = int8(_payoutDecimals) -
            int8(_quoteDecimals) -
            (_payoutPriceDecimals - _quotePriceDecimals) /
            2;

        scale = 10**uint8(36 + scaleAdjustment);

        price =
            5 *
            10 **
                uint8(
                    int8(36 + _quoteDecimals - _payoutDecimals) +
                        scaleAdjustment +
                        _payoutPriceDecimals -
                        _quotePriceDecimals
                );

        uint48 vesting = uint48(block.timestamp + 14 days); // fixed expiry in 14 days
        uint48 conclusion = uint48(block.timestamp + 7 days);
        uint48 depositInterval = uint48(7 days / 20); // 5% of capacity

        params = IBondFPA.MarketParams(
            payoutToken, // ERC20 payoutToken
            quoteToken, // ERC20 quoteToken
            address(0), // address callbackAddr - No callback in V1
            _capacityInQuote, // bool capacityIn
            capacity, // uint256 capacity
            price, // uint256 formattedPrice
            vesting, // uint48 vesting (timestamp or duration)
            conclusion, // uint48 conclusion (timestamp)
            depositInterval, // uint48 depositInterval
            scaleAdjustment // int8 scaleAdjustment
        );

        id = auctioneer.createMarket(abi.encode(params));
    }

    function beforeEach(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
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

        // Mint tokens to users for testing
        uint256 testAmount = 1_000_000 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);

        quoteToken.mint(alice, testAmount);
        quoteToken.mint(bob, testAmount);
        quoteToken.mint(carol, testAmount);
        payoutToken.mint(
            address(this),
            1_000_000_000 * 10**uint8(int8(_payoutDecimals) - _payoutPriceDecimals)
        );

        // Approve the teller for the tokens
        vm.prank(alice);
        quoteToken.approve(address(teller), testAmount);
        vm.prank(bob);
        quoteToken.approve(address(teller), testAmount);
        vm.prank(carol);
        quoteToken.approve(address(teller), testAmount);

        // Approve the teller with this contract for payouts
        payoutToken.approve(
            address(teller),
            1_000_000_000 * 10**uint8(int8(_payoutDecimals) - _payoutPriceDecimals)
        );

        // Create market
        (id, scale, price) = createMarket(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals
        );
    }

    function inFuzzRange(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
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

        // Otherwise, return true
        return true;
    }

    function testCorrectness_CreateMarket(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
    ) public {
        if (
            !inFuzzRange(_payoutDecimals, _quoteDecimals, _payoutPriceDecimals, _quotePriceDecimals)
        ) return;
        (uint256 id, uint256 expectedScale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals
        );
        assertEq(id, 0);

        // Get variables for created Market
        (, , , , , uint256 capacity, uint256 maxPayout, , uint256 scale, , ) = auctioneer.markets(
            id
        );

        // Check scale set correctly
        assertEq(scale, expectedScale);

        // Check max payout set correctly
        uint256 convertedCapacity = _capacityInQuote
            ? capacity.mulDiv(expectedScale, price)
            : capacity;
        uint256 expectedMaxPayout = (convertedCapacity * 5e3) / 1e5;
        assertEq(maxPayout, expectedMaxPayout);
    }

    function testFail_CreateMarketParamOutOfBounds(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
    ) public {
        require(
            !inFuzzRange(
                _payoutDecimals,
                _quoteDecimals,
                _payoutPriceDecimals,
                _quotePriceDecimals
            ),
            "In fuzz range"
        );
        createMarket(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals
        );
    }

    function testCorrectness_CannotCreateMarketWithInvalidParams() public {
        // Create tokens, etc.
        beforeEach(18, 18, true, 0, 0);

        // Vesting: If not 0 (instant swap), must be greater than market conclusion (which must be greater than MAX_FIXED_TERM because Unix epoch is more than 50 years ago)

        // Less than market duration
        IBondFPA.MarketParams memory params = IBondFPA.MarketParams(
            payoutToken, // ERC20 payoutToken
            quoteToken, // ERC20 quoteToken
            address(0), // address callbackAddr - No callback in V1
            false, // bool capacityIn
            1e22, // uint256 capacity
            5e36, // uint256 initialPrice
            uint48(block.timestamp + 7 days - 1), // uint48 vesting (timestamp or duration)
            uint48(block.timestamp + 7 days), // uint48 conclusion (timestamp)
            uint48(7 days / 20), // uint48 depositInterval
            0 // int8 scaleAdjustment
        );

        bytes memory err = abi.encodeWithSignature("Auctioneer_InvalidParams()");
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));

        // Values within the range and 0 (instant swap) are valid
        params.vesting = uint48(0);
        auctioneer.createMarket(abi.encode(params));

        params.vesting = uint48(block.timestamp + 14 days);
        auctioneer.createMarket(abi.encode(params));

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

        // Market duration must be greater than 1 day
        params.conclusion = uint48(block.timestamp) + 1 days - 1;
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));

        params.conclusion = uint48(block.timestamp) + 3 days;
        auctioneer.createMarket(abi.encode(params));

        // Formatted Price must not be zero
        params.formattedPrice = 0;
        vm.expectRevert(err);
        auctioneer.createMarket(abi.encode(params));

        params.formattedPrice = 5e36;
        auctioneer.createMarket(abi.encode(params));
    }

    function testCorrectness_OnlyGuardianCanSetAllowNewMarkets() public {
        beforeEach(18, 18, true, 0, 0);

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

    function testCorrectness_OnlyPolicyCanSetDefaults() public {
        beforeEach(18, 18, false, 0, 0);

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

    function testFail_CannotCreateNewMarketsIfSunset() public {
        beforeEach(18, 18, true, 0, 0);

        // Change allowNewMarkets to false as Guardian
        vm.prank(guardian);
        auctioneer.setAllowNewMarkets(false);

        // Try to create a new market, expect to fail
        createMarket(18, 18, true, 0, 0);
    }

    function testCorrectness_ConcludeInCorrectAmountOfTime() public {
        (uint256 id, , ) = beforeEach(18, 6, true, 0, 0);
        (, uint48 conclusion) = auctioneer.terms(id);

        assertEq(conclusion, uint48(block.timestamp + 7 days));
    }

    function testCorrectness_PurchaseBond(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
    ) public {
        if (
            !inFuzzRange(_payoutDecimals, _quoteDecimals, _payoutPriceDecimals, _quotePriceDecimals)
        ) return;
        // uint8 _payoutDecimals = 18;
        // uint8 _quoteDecimals = 6;
        // bool _capacityInQuote = false;
        // int8 _priceShiftDecimals = -12;
        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals
        );

        // Set variables for purchase
        uint256 amount = 50 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);
        uint256 fee = amount.mulDiv(teller.getFee(referrer), 1e5);
        uint256 minAmountOut = (amount - fee).mulDiv(scale, price) / 2; // set low to avoid slippage error

        // Purchase a bond
        uint256[3] memory balancesBefore = [
            quoteToken.balanceOf(alice),
            quoteToken.balanceOf(address(this)),
            payoutToken.balanceOf(address(teller))
        ];

        vm.prank(alice);
        (uint256 payout, uint48 expiry) = teller.purchase(
            alice,
            referrer,
            id,
            amount,
            minAmountOut
        );
        uint256[3] memory balancesAfter = [
            quoteToken.balanceOf(alice),
            quoteToken.balanceOf(address(this)),
            payoutToken.balanceOf(address(teller))
        ];

        // Confirm purchase
        (uint48 vesting, ) = auctioneer.terms(id);
        ERC20BondToken bondToken = teller.getBondTokenForMarket(id);
        uint256 bondTokenBalance = bondToken.balanceOf(alice);

        assertEq(balancesAfter[0], balancesBefore[0] - amount);
        assertEq(balancesAfter[1], balancesBefore[1] + amount - fee);
        assertGe(balancesAfter[2], balancesBefore[2] + payout);
        assertEq(payout, bondTokenBalance);
        assertEq(expiry, vesting);
    }

    function testCorrectness_SlippageCheck(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
    ) public {
        if (
            !inFuzzRange(_payoutDecimals, _quoteDecimals, _payoutPriceDecimals, _quotePriceDecimals)
        ) return;
        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals
        );

        // Set variables for purchase with minAmountOut greater than expected payout
        uint256 amount = 50 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);
        uint256 fee = amount.mulDiv(teller.getFee(referrer), 1e5);
        uint256 minAmountOut = (amount - fee).mulDiv(scale, price) + 1;

        // Purchase a bond and expect to fail
        bytes memory err = abi.encodeWithSignature("Auctioneer_AmountLessThanMinimum()");
        vm.expectRevert(err);
        vm.prank(alice);
        teller.purchase(alice, referrer, id, amount, minAmountOut);

        // Update slippage check to be correct amount and expect to succeed
        minAmountOut = (amount - fee).mulDiv(scale, price);
        vm.prank(alice);
        teller.purchase(alice, referrer, id, amount, minAmountOut);
    }

    function testCorrectness_BondTokensIssued(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
    ) public {
        if (
            !inFuzzRange(_payoutDecimals, _quoteDecimals, _payoutPriceDecimals, _quotePriceDecimals)
        ) return;
        // uint8 _payoutDecimals = 18;
        // uint8 _quoteDecimals = 18;
        // bool _capacityInQuote = false;
        // int8 _payoutPriceDecimals = 0;
        // int8 _quotePriceDecimals = 0;
        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals
        );

        // Set variables for purchase
        uint256 amount = 50 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);
        uint256 minAmountOut = amount.mulDiv(scale, price).mulDiv(
            1e5 - teller.getFee(referrer),
            1e5
        );

        // Purchase bond on first day,
        vm.prank(alice);
        (uint256 payout1, uint48 expiry1) = teller.purchase(
            alice,
            referrer,
            id,
            amount,
            minAmountOut
        );
        ERC20BondToken bondToken = teller.getBondTokenForMarket(id);
        uint256 bondTokenBalance = bondToken.balanceOf(alice);
        assertEq(bondTokenBalance, payout1);

        // speed up past a day, purchase another bond and show it has same expiry
        vm.warp(block.timestamp + 86401);
        vm.prank(alice);
        (uint256 payout2, uint48 expiry2) = teller.purchase(
            alice,
            referrer,
            id,
            amount,
            minAmountOut
        );
        bondTokenBalance = bondToken.balanceOf(alice);
        assertEq(bondTokenBalance, payout1 + payout2);
        assertEq(expiry2, expiry1);
        assertEq(bondToken.expiry(), expiry1);
    }

    function testCorrectness_BondTokenMetadata(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
    ) public {
        if (
            !inFuzzRange(_payoutDecimals, _quoteDecimals, _payoutPriceDecimals, _quotePriceDecimals)
        ) return;
        // uint8 _payoutDecimals = 18;
        // uint8 _quoteDecimals = 18;
        // bool _capacityInQuote = false;
        // int8 _payoutPriceDecimals = 0;
        // int8 _quotePriceDecimals = 0;
        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals
        );

        // Set variables for purchase
        uint256 amount = 50 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);
        uint256 minAmountOut = amount.mulDiv(scale, price).mulDiv(
            1e5 - teller.getFee(referrer),
            1e5
        );

        // Check that token was created on market creation (fixed expiry)
        (uint48 vesting, ) = auctioneer.terms(id);

        ERC20BondToken bondToken = teller.getBondTokenForMarket(id);
        assertGt(uint256(bytes32(bytes20(address(bondToken)))), 0);

        // Purchase bond to update supply
        {
            vm.prank(alice);
            (, uint48 expiry1) = teller.purchase(alice, referrer, id, amount, minAmountOut);
            assertEq(expiry1, vesting);
        }

        // Get token metadata and confirm
        {
            ERC20 underlying = bondToken.underlying();
            uint256 supply = bondToken.totalSupply();
            uint48 expiry2 = bondToken.expiry();

            assertEq(address(underlying), address(payoutToken));
            assertEq(expiry2, vesting);
            assertEq(supply, bondToken.balanceOf(alice));
        }
    }

    function testCorrectness_BondTokenCannotRedeemBeforeExpiry(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
    ) public {
        if (
            !inFuzzRange(_payoutDecimals, _quoteDecimals, _payoutPriceDecimals, _quotePriceDecimals)
        ) return;
        // uint8 _payoutDecimals = 18;
        // uint8 _quoteDecimals = 18;
        // bool _capacityInQuote = false;
        // int8 _payoutPriceDecimals = 0;
        // int8 _quotePriceDecimals = 0;
        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals
        );

        // Set variables for purchase
        uint256 amount = 50 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);
        uint256 minAmountOut = amount.mulDiv(scale, price).mulDiv(
            1e5 - teller.getFee(referrer),
            1e5
        );

        // Purchase bond on first day
        vm.prank(alice);
        (uint256 payout1, uint48 expiry1) = teller.purchase(
            alice,
            referrer,
            id,
            amount,
            minAmountOut
        );
        ERC20BondToken bondToken = teller.getBondTokenForMarket(id);
        uint256 bondTokenBalance1 = bondToken.balanceOf(alice);
        assertEq(bondTokenBalance1, payout1);

        // Test redeem before expiry, expect to fail
        bytes memory err = abi.encodeWithSignature("Teller_TokenNotMatured(uint48)", expiry1);
        vm.prank(alice);
        vm.expectRevert(err);
        teller.redeem(bondToken, bondTokenBalance1);

        // Check that balances are the same
        assertEq(payoutToken.balanceOf(alice), 0);
        assertEq(bondToken.balanceOf(alice), bondTokenBalance1);
    }

    function testCorrectness_BondTokenRedemption(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
    ) public {
        if (
            !inFuzzRange(_payoutDecimals, _quoteDecimals, _payoutPriceDecimals, _quotePriceDecimals)
        ) return;
        // uint8 _payoutDecimals = 18;
        // uint8 _quoteDecimals = 18;
        // bool _capacityInQuote = false;
        // int8 _payoutPriceDecimals = 0;
        // int8 _quotePriceDecimals = 0;
        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals
        );

        // Set variables for purchase
        uint256 amount = 50 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);
        uint256 minAmountOut = amount.mulDiv(scale, price).mulDiv(
            1e5 - teller.getFee(referrer),
            1e5
        ) / 2;

        // Purchase bond
        vm.prank(alice);
        (uint256 payout, ) = teller.purchase(alice, referrer, id, amount, minAmountOut);
        ERC20BondToken bondToken = teller.getBondTokenForMarket(id);
        uint256 bondTokenBalance = bondToken.balanceOf(alice);
        assertEq(bondTokenBalance, payout);

        // Test redeemToken after expiry
        vm.warp(block.timestamp + 14 days + 1);
        vm.prank(alice);
        teller.redeem(bondToken, bondTokenBalance);
        assertEq(payoutToken.balanceOf(alice), bondTokenBalance);
        assertEq(bondToken.balanceOf(alice), 0);
    }

    function testCorrectness_BondTokenMustBeCreatedByTeller(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
    ) public {
        // Setup
        if (
            !inFuzzRange(_payoutDecimals, _quoteDecimals, _payoutPriceDecimals, _quotePriceDecimals)
        ) return;
        // uint8 _payoutDecimals = 18;
        // uint8 _quoteDecimals = 18;
        // bool _capacityInQuote = false;
        // int8 _payoutPriceDecimals = 0;
        // int8 _quotePriceDecimals = 0;
        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals
        );

        // Make a bond purchase to have underlying tokens stored in the Teller
        // Set variables for purchase
        uint256 amount = 50 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);
        uint256 minAmountOut = amount.mulDiv(scale, price).mulDiv(
            1e5 - teller.getFee(referrer),
            1e5
        ) / 2;

        // Purchase bond
        vm.prank(alice);
        (uint256 payout, ) = teller.purchase(alice, referrer, id, amount, minAmountOut);
        ERC20BondToken bondToken = teller.getBondTokenForMarket(id);
        uint256 bondTokenBalance = bondToken.balanceOf(alice);
        assertEq(bondTokenBalance, payout);

        // Mint malicious bond tokens and try to redeem them for the underlying, expect revert
        MaliciousBondToken mbt = new MaliciousBondToken(payoutToken, uint48(0));
        mbt.mint(bob, bondTokenBalance);

        bytes memory err = abi.encodeWithSignature("Teller_UnsupportedToken()");
        vm.prank(bob);
        vm.expectRevert(err);
        teller.redeem(ERC20BondToken(address(mbt)), bondTokenBalance);
    }

    function testCorrectness_MarketPrice(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
    ) public {
        if (
            !inFuzzRange(_payoutDecimals, _quoteDecimals, _payoutPriceDecimals, _quotePriceDecimals)
        ) return;

        (uint256 id, , uint256 expectedPrice) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals
        );

        uint256 price = aggregator.marketPrice(id);

        assertEq(price, expectedPrice);
    }

    function testCorrectness_MarketScale(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
    ) public {
        if (
            !inFuzzRange(_payoutDecimals, _quoteDecimals, _payoutPriceDecimals, _quotePriceDecimals)
        ) return;

        (uint256 id, uint256 expectedScale, ) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals
        );

        uint256 scale = aggregator.marketScale(id);

        assertEq(scale, expectedScale);
    }

    function testCorrectness_PayoutFor(
        uint8 _payoutDecimals,
        uint8 _quoteDecimals,
        bool _capacityInQuote,
        int8 _payoutPriceDecimals,
        int8 _quotePriceDecimals
    ) public {
        if (
            !inFuzzRange(_payoutDecimals, _quoteDecimals, _payoutPriceDecimals, _quotePriceDecimals)
        ) return;

        (uint256 id, uint256 scale, uint256 price) = beforeEach(
            _payoutDecimals,
            _quoteDecimals,
            _capacityInQuote,
            _payoutPriceDecimals,
            _quotePriceDecimals
        );

        uint256 amountIn = 5 * 10**uint8(int8(_quoteDecimals) - _quotePriceDecimals);
        uint256 fee = amountIn.mulDiv(teller.getFee(referrer), 1e5);
        uint256 payout = aggregator.payoutFor(amountIn, id, referrer);
        uint256 expectedPayout = (amountIn - fee).mulDiv(scale, price);

        // Check that the values are equal
        assertEq(payout, expectedPayout);
    }

    function testCorrectness_MarketOwnershipPushAndPull() public {
        (uint256 id, , ) = beforeEach(18, 18, false, 0, 0);

        // Attempt to set new owner with non-owner account
        bytes memory err1 = abi.encodeWithSignature("Auctioneer_OnlyMarketOwner()");
        vm.expectRevert(err1);
        vm.prank(alice);
        auctioneer.pushOwnership(id, alice);

        // Push new owner with owner account
        auctioneer.pushOwnership(id, bob);

        // Check that newOwner is set, but owner is not
        (address owner, , , , , , , , , , ) = auctioneer.markets(id);
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

        (owner, , , , , , , , , , ) = auctioneer.markets(id);
        newOwner = auctioneer.newOwners(id);
        assertEq(owner, bob);
        assertEq(newOwner, bob);
    }

    function testCorrectness_FeesPaidInQuoteToken() public {
        (uint256 id, uint256 scale, uint256 price) = beforeEach(18, 18, false, 0, 0);

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
        beforeEach(18, 18, false, 0, 0);

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
        beforeEach(18, 18, false, 0, 0);

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
        beforeEach(18, 18, false, 0, 0);

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
        beforeEach(18, 18, false, 0, 0);

        // Check that the fee set the protocol is correct (use zero address for referrer)
        assertEq(teller.getFee(address(0)), uint48(100));

        // Check that the fee set the protocol + referrer is correct
        assertEq(teller.getFee(referrer), uint48(300));
    }

    function testCorrectness_liveMarketsBetween() public {
        // Setup tests and create multiple markets
        (uint256 id1, , ) = beforeEach(18, 18, false, 0, 0);
        (uint256 id2, , ) = createMarket(18, 6, true, 3, 0);
        (uint256 id3, , ) = createMarket(9, 6, true, 1, 0);
        (uint256 id4, , ) = createMarket(18, 9, true, -2, 1);
        (uint256 id5, , ) = createMarket(6, 9, true, 0, 1);

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
        (uint256 id1, , ) = beforeEach(18, 18, false, 3, 0);

        payoutToken = new MockERC20("Payout Token Two", "BT2", 18);
        quoteToken = new MockERC20("Quote Token Two", "BT2", 6);
        (uint256 id2, , ) = createMarket(18, 6, true, 0, 0);

        (, ERC20 payoutToken1, ERC20 quoteToken1, , , , , , , , ) = auctioneer.markets(id1);
        (, ERC20 payoutToken2, ERC20 quoteToken2, , , , , , , , ) = auctioneer.markets(id2);

        uint256 id3 = auctioneer.createMarket(
            abi.encode(
                IBondFPA.MarketParams(
                    quoteToken2,
                    payoutToken1,
                    address(0),
                    true,
                    500_000 * 1e18,
                    5 * 1e36,
                    uint48(block.timestamp + 14 days),
                    uint48(block.timestamp + 7 days),
                    uint48(7 days / 20),
                    0
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
        (uint256 id1, , ) = beforeEach(18, 18, false, 3, 0);

        payoutToken = new MockERC20("Payout Token Two", "BT2", 18);
        quoteToken = new MockERC20("Quote Token Two", "BT2", 6);
        (uint256 id2, , ) = createMarket(18, 6, true, 0, 0);

        (, ERC20 payoutToken1, ERC20 quoteToken1, , , , , , , , ) = auctioneer.markets(id1);
        (, ERC20 payoutToken2, ERC20 quoteToken2, , , , , , , , ) = auctioneer.markets(id2);

        uint256 id3 = auctioneer.createMarket(
            abi.encode(
                IBondFPA.MarketParams(
                    quoteToken2,
                    payoutToken1,
                    address(0),
                    true,
                    500_000 * 1e18,
                    5 * 1e36,
                    uint48(block.timestamp + 14 days),
                    uint48(block.timestamp + 7 days),
                    uint48(7 days / 20),
                    0
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
        (uint256 id1, , ) = beforeEach(18, 18, false, 3, 0);

        payoutToken = new MockERC20("Payout Token Two", "BT2", 18);
        quoteToken = new MockERC20("Quote Token Two", "BT2", 6);
        (uint256 id2, , ) = createMarket(18, 6, true, 0, 0);

        (, ERC20 payoutToken1, ERC20 quoteToken1, , , , , , , , ) = auctioneer.markets(id1);
        (, ERC20 payoutToken2, ERC20 quoteToken2, , , , , , , , ) = auctioneer.markets(id2);

        uint256 id3 = auctioneer.createMarket(
            abi.encode(
                IBondFPA.MarketParams(
                    quoteToken2,
                    payoutToken1,
                    address(0),
                    true,
                    500_000 * 1e18,
                    5 * 1e36,
                    uint48(block.timestamp + 14 days),
                    uint48(block.timestamp + 7 days),
                    uint48(7 days / 20),
                    0
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
        (uint256 id1, , ) = beforeEach(18, 18, false, 3, 0);
        (uint256 id2, , ) = createMarket(18, 18, false, 3, 0);

        // Create a market with a different owner
        vm.prank(bob);
        uint256 id3 = auctioneer.createMarket(
            abi.encode(
                IBondFPA.MarketParams(
                    payoutToken,
                    quoteToken,
                    address(0),
                    true,
                    500_000 * 1e18,
                    5 * 1e36,
                    uint48(block.timestamp + 14 days),
                    uint48(block.timestamp + 7 days),
                    uint48(7 days / 20),
                    0
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
        (uint256 id, uint256 scale, uint256 price) = beforeEach(18, 18, false, 0, 0);
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
        beforeEach(18, 18, false, 0, 0);

        // Deploy fee-on-transfer (FOT) token
        MockFOTERC20 fotToken = new MockFOTERC20("FOT Token", "FOT", 18, bob, 1e3); // 1% fee on transfer to bob

        // Send FOT token to user for purchase and approve teller for FOT token
        fotToken.mint(alice, 5000 * 1e18);

        vm.prank(alice);
        fotToken.approve(address(teller), 5000 * 1e18);

        // Create market with FOT token as quote token
        uint256 price = 5 * 1e36;
        uint256 scale = 1e36;
        uint256 id = auctioneer.createMarket(
            abi.encode(
                IBondFPA.MarketParams(
                    payoutToken,
                    fotToken,
                    address(0),
                    true,
                    500_000 * 1e18,
                    price,
                    uint48(block.timestamp + 14 days),
                    uint48(block.timestamp + 7 days),
                    uint48(7 days / 20),
                    0
                )
            )
        );

        // Try to purchase a bond and expect revert
        uint256 amount = 50 * 1e18;
        uint256 minAmountOut = amount.mulDiv(scale / 2, price);

        bytes memory err = abi.encodeWithSignature("Teller_UnsupportedToken()");
        vm.prank(alice);
        vm.expectRevert(err);
        teller.purchase(alice, referrer, id, amount, minAmountOut);
    }

    function testCorrectness_FOTPayoutTokenFailsPurchase() public {
        // Initialize protocol
        beforeEach(18, 18, false, 0, 0);

        // Deploy fee-on-transfer (FOT) token
        MockFOTERC20 fotToken = new MockFOTERC20("FOT Token", "FOT", 18, bob, 1e3); // 1% fee on transfer to bob

        // Mint FOT token to this address for payouts
        fotToken.mint(address(this), 1000 * 1e18);
        fotToken.approve(address(teller), 1000 * 1e18);

        // Create market with FOT token as payout token
        uint256 price = 5 * 1e36;
        uint256 scale = 1e36;
        uint256 id = auctioneer.createMarket(
            abi.encode(
                IBondFPA.MarketParams(
                    fotToken,
                    quoteToken,
                    address(0),
                    true,
                    500_000 * 1e18,
                    price,
                    uint48(block.timestamp + 14 days),
                    uint48(block.timestamp + 7 days),
                    uint48(7 days / 20),
                    0
                )
            )
        );

        // Try to purchase a bond and expect revert
        uint256 amount = 50 * 1e18;
        uint256 minAmountOut = amount.mulDiv(scale / 2, price);

        bytes memory err = abi.encodeWithSignature("Teller_UnsupportedToken()");
        vm.prank(alice);
        vm.expectRevert(err);
        teller.purchase(alice, referrer, id, amount, minAmountOut);
    }

    function testCorrectness_deployBondToken() public {
        beforeEach(18, 18, false, 0, 0);

        // Deploy ERC20 bond token
        ERC20 underlying = payoutToken;
        uint48 expiry = uint48(block.timestamp + 2 days);

        teller.deploy(underlying, expiry);

        // Get bond token address
        ERC20BondToken bondToken = teller.getBondToken(underlying, expiry);

        // Expect the underlying to be correct and the expiry to be rounded to the nearest day
        assertEq(address(bondToken.underlying()), address(payoutToken));
        assertEq(bondToken.expiry(), (expiry * 1 days) / 1 days);
    }

    function testRevert_cannotDeployBondTokenWithInvalidParams() public {
        beforeEach(18, 18, false, 0, 0);

        // warp time to midday to test expiry rounding
        vm.warp(block.timestamp + 12 hours);

        // Try to deploy bond token with an expiry in the past, expect revert
        ERC20 underlying = payoutToken;
        uint48 expiry = uint48(block.timestamp - 1);

        bytes memory err = abi.encodeWithSignature("Teller_InvalidParams()");
        vm.expectRevert(err);
        teller.deploy(underlying, expiry);

        // Try to deploy bond token with an expiry in the future, but that rounds down to the past (e.g. today), expect revert
        expiry = uint48(block.timestamp + 1);
        vm.expectRevert(err);
        teller.deploy(underlying, expiry);

        // Try to deploy bond token with an expiry in the future (more than a day) and expect success
        expiry = uint48(block.timestamp + 1 days);
        teller.deploy(underlying, expiry);
    }

    function testCorrectness_createBondToken() public {
        beforeEach(18, 18, false, 0, 0);

        // Deploy ERC20 bond token
        ERC20 underlying = quoteToken;
        uint48 expiry = uint48(block.timestamp + 2 days);

        teller.deploy(underlying, expiry);

        // Get bond token address
        ERC20BondToken bondToken = teller.getBondToken(underlying, expiry);

        // Get start balances
        uint256 startUnderlyingBal = underlying.balanceOf(alice);
        uint256 startBondTokenBal = bondToken.balanceOf(alice);

        // Create bond tokens
        vm.startPrank(alice);
        underlying.approve(address(teller), 1000 * 1e18);
        teller.create(underlying, expiry, 1000 * 1e18);
        vm.stopPrank();

        // Get end balances
        uint256 endUnderlyingBal = underlying.balanceOf(alice);
        uint256 endBondTokenBal = bondToken.balanceOf(alice);

        // Expect underlying balance to decrease and bond token balance to increase
        assertEq(endUnderlyingBal, startUnderlyingBal - 1000 * 1e18);
        assertEq(
            endBondTokenBal,
            startBondTokenBal +
                (1000 * 1e18 * (1e5 - uint256(teller.protocolFee() - teller.createFeeDiscount()))) /
                1e5
        );
    }

    function testRevert_cannotCreateBondTokensWithInvalidParams() public {
        beforeEach(18, 18, false, 0, 0);

        ERC20 underlying = quoteToken;
        vm.prank(alice);
        underlying.approve(address(teller), 1000 * 1e18);

        // warp time to midday to test expiry rounding
        vm.warp(block.timestamp + 12 hours);

        // Try to create bond tokens with an expiry in the past, expect revert
        uint48 expiry = uint48(block.timestamp - 1);

        bytes memory err = abi.encodeWithSignature("Teller_InvalidParams()");
        vm.expectRevert(err);
        vm.prank(alice);
        teller.create(underlying, expiry, 1);

        // Try to create bond tokens with an expiry in the future, but that rounds down to the past (e.g. today), expect revert
        expiry = uint48(block.timestamp + 1);
        vm.expectRevert(err);
        vm.prank(alice);
        teller.create(underlying, expiry, 1);

        // Try to create bond tokens for an expiry that doesn't have a bond token deployed, expect revert
        expiry = uint48(block.timestamp + 2 days);
        err = abi.encodeWithSignature(
            "Teller_TokenDoesNotExist(address,uint48)",
            address(underlying),
            (expiry / 1 days) * 1 days
        );
        vm.expectRevert(err);
        vm.prank(alice);
        teller.create(underlying, expiry, 1);
    }
}

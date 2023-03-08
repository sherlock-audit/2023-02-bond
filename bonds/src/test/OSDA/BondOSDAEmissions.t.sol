// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {Utilities} from "../utils/Utilities.sol";
import {console2} from "forge-std/console2.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {RolesAuthority, Authority} from "solmate/auth/authorities/RolesAuthority.sol";
import {MockBondCallback} from "../utils/mocks/MockBondCallback.sol";
import {MockPriceFeed} from "../utils/mocks/MockPriceFeed.sol";

import {IBondOSDA} from "../../interfaces/IBondOSDA.sol";
import {IBondCallback} from "../../interfaces/IBondCallback.sol";

import {BondFixedExpiryOSDA} from "../../BondFixedExpiryOSDA.sol";
import {BondFixedExpiryTeller} from "../../BondFixedExpiryTeller.sol";
import {BondAggregator} from "../../BondAggregator.sol";
import {BondChainlinkOracle} from "../../BondChainlinkOracle.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {FullMath} from "../../lib/FullMath.sol";

contract BondOSDAEmissionsTest is Test {
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
    BondFixedExpiryOSDA internal auctioneer;
    BondFixedExpiryTeller internal teller;
    BondAggregator internal aggregator;
    MockERC20 internal payoutToken;
    MockERC20 internal quoteToken;
    IBondOSDA.MarketParams internal params;
    MockBondCallback internal callback;
    MockPriceFeed internal priceFeed;
    BondChainlinkOracle internal oracle;

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
        auctioneer = new BondFixedExpiryOSDA(teller, aggregator, guardian, auth);
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
        uint48 _duration,
        uint48 _depositInterval,
        uint48 _baseDiscount,
        uint48 _targetIntervalDiscount
    )
        internal
        returns (
            uint256 id,
            uint256 scale,
            uint256 price
        )
    {
        // Set oracle decimals and initial price using price decimal scaling
        priceFeed.setDecimals(18);
        price = 5e18;
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
            18,
            false
        );
        oracle.setPair(quoteToken, payoutToken, true, oracleData);

        // Configure market params

        uint256 capacity = 100_000e18;

        uint48 maxDiscountFromCurrent = 50e3; // 50%

        uint48 vesting = uint48(block.timestamp + 90 days); // fixed expiry in 90 days
        uint48 conclusion = uint48(block.timestamp) + _duration;

        params = IBondOSDA.MarketParams(
            payoutToken, // ERC20 payoutToken
            quoteToken, // ERC20 quoteToken
            address(callback), // address callbackAddr
            oracle, // IBondOracle oracle
            _baseDiscount, // uint48 baseDiscount
            maxDiscountFromCurrent, // uint48 maxDiscountFromCurrent
            _targetIntervalDiscount, // uint48 targetIntervalDiscount
            false, // bool capacityIn
            capacity, // uint256 capacity
            _depositInterval, // uint48 depositInterval
            vesting, // uint48 vesting (timestamp or duration)
            conclusion // uint48 conclusion (timestamp)
        );

        id = auctioneer.createMarket(abi.encode(params));

        scale = auctioneer.marketScale(id);
        price = auctioneer.marketPrice(id);
    }

    function beforeEach(
        uint48 _duration,
        uint48 _depositInterval,
        uint48 _baseDiscount,
        uint48 _targetIntervalDiscount
    )
        internal
        returns (
            uint256 id,
            uint256 scale,
            uint256 price
        )
    {
        // Deploy token and callback contracts
        payoutToken = new MockERC20("Payout Token", "BT", 18);
        quoteToken = new MockERC20("Quote Token", "QT", 18);
        callback = new MockBondCallback(payoutToken);

        // Mint tokens to users for testing
        {
            uint256 testAmount = 1_000_000 * 1e18;

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
        }

        // Create market
        (id, scale, price) = createMarket(
            _duration,
            _depositInterval,
            _baseDiscount,
            _targetIntervalDiscount
        );
    }

    function testCorrectness_EmSpeedLong(
        uint48 depositInterval_,
        uint48 baseDiscount_,
        uint48 targetIntervalDiscount_
    ) public {
        vm.assume(baseDiscount_ < 30e3);
        vm.assume(targetIntervalDiscount_ >= 1e3 && targetIntervalDiscount_ <= 20e3);
        vm.assume(depositInterval_ >= 1 hours && depositInterval_ <= 30 days / 5); // assume issuer doesn't want everything to sell in one txn

        // Create market
        (uint256 id, uint256 scale, uint256 targetPrice) = beforeEach(
            30 days, // duration
            depositInterval_,
            baseDiscount_,
            targetIntervalDiscount_
        );

        // Set bond amount close to max bond
        uint256 bondAmount = auctioneer.maxAmountAccepted(id, referrer) / 2;

        (, uint48 conclusion, , , , , , , ) = auctioneer.terms(id);
        uint256 capacity = auctioneer.currentCapacity(id);
        uint256 minAmountOut = bondAmount.mulDiv(scale / 2, targetPrice);

        uint48 time = uint48(block.timestamp);
        uint256 startCapacity = capacity;
        uint256 threshold = capacity.mulDiv(1, 10000);
        uint256 currentPrice;
        while (time < conclusion && capacity > threshold) {
            // Purchase a bond if price is at or under market
            bondAmount = auctioneer.maxAmountAccepted(id, referrer) / 2;
            currentPrice = auctioneer.marketPrice(id);
            console2.log("Current price: ", currentPrice);
            minAmountOut = bondAmount.mulDiv(scale / 2, currentPrice);
            if (currentPrice <= targetPrice) {
                vm.prank(alice);
                teller.purchase(alice, referrer, id, bondAmount, minAmountOut);
            }

            // Get updated capacity
            capacity = auctioneer.currentCapacity(id);

            // Increment time
            time += 600;
            vm.warp(time);
            priceFeed.setTimestamp(time);
        }

        uint48 marketEnded = time;
        console2.log("Long duration");
        console2.log("Ended at % of duration:");
        console2.log(((marketEnded - (conclusion - 30 days)) * 100) / 30 days);
        console2.log("Capacity % left at end: ");
        console2.log((capacity * 100) / startCapacity);

        assertGt(marketEnded - (conclusion - 30 days), (30 days * 90) / 100);
        assertLt(capacity, (startCapacity * 10) / 100);
    }

    function testCorrectness_EmSpeedMid(
        uint48 depositInterval_,
        uint48 baseDiscount_,
        uint48 targetIntervalDiscount_
    ) public {
        vm.assume(baseDiscount_ < 30e3);
        vm.assume(targetIntervalDiscount_ >= 1e3 && targetIntervalDiscount_ <= 20e3);
        vm.assume(depositInterval_ >= 1 hours && depositInterval_ <= 7 days / 5); // assume issuer doesn't want everything to sell in one txn

        // Create market
        (uint256 id, uint256 scale, uint256 targetPrice) = beforeEach(
            7 days, // duration
            depositInterval_,
            baseDiscount_,
            targetIntervalDiscount_
        );

        // Set bond amount close to max bond
        uint256 bondAmount = auctioneer.maxAmountAccepted(id, referrer) / 2;

        (, uint48 conclusion, , , , , , , ) = auctioneer.terms(id);
        uint256 capacity = auctioneer.currentCapacity(id);
        uint256 minAmountOut = bondAmount.mulDiv(scale / 2, targetPrice);

        uint48 time = uint48(block.timestamp);
        uint256 startCapacity = capacity;
        uint256 threshold = capacity.mulDiv(1, 10000);
        uint256 currentPrice;
        while (time < conclusion && capacity > threshold) {
            // Purchase a bond if price is at or under market
            bondAmount = auctioneer.maxAmountAccepted(id, referrer) / 2;
            currentPrice = auctioneer.marketPrice(id);
            minAmountOut = bondAmount.mulDiv(scale / 2, currentPrice);
            if (currentPrice <= targetPrice) {
                vm.prank(alice);
                teller.purchase(alice, referrer, id, bondAmount, minAmountOut);
            }

            // Get updated capacity
            capacity = auctioneer.currentCapacity(id);

            // Increment time
            time += 600;
            vm.warp(time);
            priceFeed.setTimestamp(time);
        }

        uint48 marketEnded = time;
        console2.log("Mid duration");
        console2.log("Ended at % of duration:");
        console2.log(((marketEnded - (conclusion - 7 days)) * 100) / 7 days);
        console2.log("Capacity % left at end: ");
        console2.log((capacity * 100) / startCapacity);

        assertGt(marketEnded - (conclusion - 7 days), (7 days * 90) / 100);
        assertLt(capacity, (startCapacity * 10) / 100);
    }

    function testCorrectness_EmSpeedShort(
        uint48 depositInterval_,
        uint48 baseDiscount_,
        uint48 targetIntervalDiscount_
    ) public {
        vm.assume(baseDiscount_ < 30e3);
        vm.assume(targetIntervalDiscount_ >= 1e3 && targetIntervalDiscount_ <= 20e3);
        vm.assume(depositInterval_ >= 1 hours && depositInterval_ <= 3 days / 5); // assume issuer doesn't want everything to sell in one txn

        // Create market
        (uint256 id, uint256 scale, uint256 targetPrice) = beforeEach(
            3 days, // duration = 3 days
            depositInterval_,
            baseDiscount_,
            targetIntervalDiscount_
        );

        // Set bond amount close to max bond
        uint256 bondAmount = auctioneer.maxAmountAccepted(id, referrer) / 2;

        (, uint48 conclusion, , , , , , , ) = auctioneer.terms(id);
        uint256 capacity = auctioneer.currentCapacity(id);
        uint256 minAmountOut = bondAmount.mulDiv(scale / 2, targetPrice);

        uint48 time = uint48(block.timestamp);
        uint256 startCapacity = capacity;
        uint256 threshold = capacity.mulDiv(1, 10000);
        uint256 currentPrice;
        while (time < conclusion && capacity > threshold) {
            // Purchase a bond if price is at or under market
            bondAmount = auctioneer.maxAmountAccepted(id, referrer) / 2;
            currentPrice = auctioneer.marketPrice(id);
            minAmountOut = bondAmount.mulDiv(scale / 2, currentPrice);
            if (currentPrice <= targetPrice) {
                vm.prank(alice);
                teller.purchase(alice, referrer, id, bondAmount, minAmountOut);
            }

            // Get updated capacity
            capacity = auctioneer.currentCapacity(id);

            // Increment time
            time += 600;
            vm.warp(time);
            priceFeed.setTimestamp(time);
        }

        uint48 marketEnded = time;
        console2.log("Short duration");
        console2.log("Ended at % of duration:");
        console2.log(((marketEnded - (conclusion - 3 days)) * 100) / 3 days);
        console2.log("Capacity % left at end: ");
        console2.log((capacity * 100) / startCapacity);

        assertGt(marketEnded - (conclusion - 3 days), (3 days * 90) / 100);
        assertLt(capacity, (startCapacity * 10) / 100);
    }
}

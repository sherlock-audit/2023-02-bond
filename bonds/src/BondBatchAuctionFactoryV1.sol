// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.15;

import {ClonesWithImmutableArgs} from "clones/ClonesWithImmutableArgs.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {IBondBatchAuctionFactoryV1} from "./interfaces/IBondBatchAuctionFactoryV1.sol";
import {IGnosisEasyAuction} from "./interfaces/IGnosisEasyAuction.sol";
import {BondFixedExpiryTeller} from "./BondFixedExpiryTeller.sol";
import {BondBatchAuctionV1, IBondBatchAuctionV1} from "./BondBatchAuctionV1.sol";

/// @title Bond Batch Auction V1
/// @notice Bond Batch Auction V1 Contract (Gnosis EasyAuction Wrapper)
/// @dev The Bond Batch Auction V1 system is a clone-based, permissionless wrapper
///      around the Gnosis EasyAuction batch auction system. The purpose is to simplify
///      the creation and sale of Fixed Expiry ERC20 Bond Tokens via a batch auction mechanism.
///
///      The BondBatchAuctionFactoryV1 contract allows users to create a new BondBatchAuctionV1
///      clones which they can use to create their own batch auctions. The factory has view functions
///      which aggregate the batch auctions created by the deployed clones.
/// @author Oighty
contract BondBatchAuctionFactoryV1 is IBondBatchAuctionFactoryV1 {
    using ClonesWithImmutableArgs for address;

    /* ========== ERRORS ========== */
    error BatchAuctionFactory_InvalidParams();
    error BatchAuctionFactory_OnlyClone();

    /* ========== EVENTS ========== */
    event BatchAuctionCloneDeployed(BondBatchAuctionV1 clone, address owner, address creator);
    event BatchAuctionCreated(uint256 auctionId, BondBatchAuctionV1 clone);

    /* ========== STATE VARIABLES ========== */

    // Dependencies
    IGnosisEasyAuction public immutable gnosisAuction;
    BondFixedExpiryTeller public immutable teller;

    // Batch Auction Clones
    BondBatchAuctionV1 public implementation;
    mapping(BondBatchAuctionV1 => address) public cloneOwners;

    // Batch Auctions
    uint256[] public auctions;
    mapping(uint256 => BondBatchAuctionV1) public auctionsToClones;
    mapping(ERC20 => uint256[]) public auctionsForQuote;

    /* ========== CONSTRUCTOR ========== */

    constructor(IGnosisEasyAuction gnosisAuction_, BondFixedExpiryTeller teller_) {
        gnosisAuction = gnosisAuction_;
        teller = teller_;
        implementation = new BondBatchAuctionV1();
    }

    /* ========== MODIFIERS ========== */

    modifier onlyClone() {
        if (cloneOwners[BondBatchAuctionV1(msg.sender)] == address(0))
            revert BatchAuctionFactory_OnlyClone();
        _;
    }

    /* ========== CLONE DEPLOYMENT ========== */

    /// @inheritdoc IBondBatchAuctionFactoryV1
    function deployClone(address owner_) external override returns (BondBatchAuctionV1) {
        // Check that owner is not the zero address
        if (owner_ == address(0)) revert BatchAuctionFactory_InvalidParams();

        // Create clone
        bytes memory data = abi.encodePacked(gnosisAuction, teller, this, owner_);
        BondBatchAuctionV1 clone = BondBatchAuctionV1(address(implementation).clone(data));

        // Store clone owner
        cloneOwners[clone] = owner_;

        // Emit event
        emit BatchAuctionCloneDeployed(clone, owner_, msg.sender);

        // Return clone
        return clone;
    }

    /* ========== AUCTION REGISTRATION ========== */

    /// @inheritdoc IBondBatchAuctionFactoryV1
    function registerAuction(uint256 auctionId_, ERC20 quoteToken_) external onlyClone {
        // Check that auction ID is not already registered
        if (address(auctionsToClones[auctionId_]) != address(0))
            revert BatchAuctionFactory_InvalidParams();

        // Store auction ID and clone mapping
        auctions.push(auctionId_);
        BondBatchAuctionV1 clone = BondBatchAuctionV1(msg.sender);
        auctionsToClones[auctionId_] = clone;
        auctionsForQuote[quoteToken_].push(auctionId_);

        // Emit event
        emit BatchAuctionCreated(auctionId_, clone);
    }

    /* ========== VIEW FUNCTIONS ========== */

    /// @inheritdoc IBondBatchAuctionFactoryV1
    function numAuctions() external view override returns (uint256) {
        return auctions.length;
    }

    /// @inheritdoc IBondBatchAuctionFactoryV1
    function numAuctionsFor(ERC20 quoteToken_) external view override returns (uint256) {
        return auctionsForQuote[quoteToken_].length;
    }

    /// @inheritdoc IBondBatchAuctionFactoryV1
    function auctionData(uint256 auctionId_)
        external
        view
        override
        returns (IBondBatchAuctionV1.AuctionData memory)
    {
        return auctionsToClones[auctionId_].auctionData(auctionId_);
    }

    /// @inheritdoc IBondBatchAuctionFactoryV1
    function isLive(uint256 auctionId_) public view override returns (bool) {
        return auctionsToClones[auctionId_].isLive(auctionId_);
    }

    /// @inheritdoc IBondBatchAuctionFactoryV1
    function liveAuctions(uint256 startIndex_, uint256 endIndex_)
        external
        view
        override
        returns (uint256[] memory)
    {
        // Get length of auction array and ensure endIndex is not greater than the length
        if (auctions.length < endIndex_) revert BatchAuctionFactory_InvalidParams();

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

    /// @inheritdoc IBondBatchAuctionFactoryV1
    function liveAuctionsBy(
        address owner_,
        uint256 startIndex_,
        uint256 endIndex_
    ) external view override returns (uint256[] memory) {
        // Get length of auction array and ensure endIndex is not greater than the length
        if (auctions.length < endIndex_) revert BatchAuctionFactory_InvalidParams();

        // Iterate through auctions and determine number of live auctions for owner
        uint256 len;
        for (uint256 i = startIndex_; i < endIndex_; ++i) {
            uint256 id = auctions[i];
            if (isLive(id) && auctionsToClones[id].owner() == owner_) {
                ++len;
            }
        }

        // Initialize a dynamic array in memory with the correct length
        uint256[] memory live = new uint256[](len);
        uint256 index;
        for (uint256 j = startIndex_; j < endIndex_; ++j) {
            uint256 id = auctions[j];
            if (isLive(id) && auctionsToClones[id].owner() == owner_) {
                live[index] = id;
                ++index;
            }
        }

        // Return array of live auction IDs for owner
        return live;
    }

    /// @inheritdoc IBondBatchAuctionFactoryV1
    function auctionsBy(
        address owner_,
        uint256 startIndex_,
        uint256 endIndex_
    ) external view override returns (uint256[] memory) {
        // Get length of auction array and ensure endIndex is not greater than the length
        if (auctions.length < endIndex_) revert BatchAuctionFactory_InvalidParams();

        // Iterate through auctions and determine number of auctions for owner
        uint256 len;
        for (uint256 i = startIndex_; i < endIndex_; ++i) {
            if (auctionsToClones[auctions[i]].owner() == owner_) {
                ++len;
            }
        }

        // Initialize a dynamic array in memory with the correct length
        uint256[] memory owned = new uint256[](len);
        uint256 index;
        for (uint256 j = startIndex_; j < endIndex_; ++j) {
            uint256 id = auctions[j];
            if (auctionsToClones[id].owner() == owner_) {
                owned[index] = id;
                ++index;
            }
        }

        // Return array of auction IDs for owner
        return owned;
    }

    /// @inheritdoc IBondBatchAuctionFactoryV1
    function liveAuctionsFor(
        ERC20 quoteToken_,
        uint256 startIndex_,
        uint256 endIndex_
    ) external view override returns (uint256[] memory) {
        uint256[] memory qtAuctions = auctionsForQuote[quoteToken_];

        // Get length of auction array and ensure endIndex is not greater than the length
        if (qtAuctions.length < endIndex_) revert BatchAuctionFactory_InvalidParams();

        // Iterate through auctions and determine number of live auctions for quote token
        uint256 len;
        for (uint256 i = startIndex_; i < endIndex_; ++i) {
            uint256 id = qtAuctions[i];
            if (isLive(id)) {
                ++len;
            }
        }

        // Initialize a dynamic array in memory with the correct length
        uint256[] memory live = new uint256[](len);
        uint256 index;
        for (uint256 j = startIndex_; j < endIndex_; ++j) {
            uint256 id = qtAuctions[j];
            if (isLive(id)) {
                live[index] = id;
                ++index;
            }
        }

        // Return array of live auction IDs for quote token
        return live;
    }

    /// @inheritdoc IBondBatchAuctionFactoryV1
    function auctionsFor(
        ERC20 quoteToken_,
        uint256 startIndex_,
        uint256 endIndex_
    ) external view override returns (uint256[] memory) {
        // Get length of auction array and ensure endIndex is not greater than the length
        if (auctionsForQuote[quoteToken_].length < endIndex_)
            revert BatchAuctionFactory_InvalidParams();

        // Use index range to determine length of return array and initialize array in memory
        uint256 len = endIndex_ - startIndex_;
        uint256[] memory qtAuctions = new uint256[](len);

        // Iterate through the
        uint256 index;
        for (uint256 i = startIndex_; i < endIndex_; ++i) {
            qtAuctions[index] = auctionsForQuote[quoteToken_][i];
            ++index;
        }

        // Return array of auction IDs for quote token within the index range
        return qtAuctions;
    }
}

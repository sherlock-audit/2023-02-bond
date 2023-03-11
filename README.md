# Bond Protocol Audit Contest Details 03/2023

-   Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
-   Submit findings using the issue page in your private contest repo (label issues as med or high)
-   [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Overview

[Bond Protocol](https://www.bondprotocol.finance/) is a system to create OTC markets for any ERC20 token pair with optional vesting of the payout. The markets do not require maintenance and will manage bond prices per the methodology defined in the specific auctioneer contract. Bond issuers create markets that pay out a Payout Token in exchange for deposited Quote Tokens. If payouts are instant, users can purchase Payout Tokens with Quote Tokens at the current market price and receive the Payout tokens immediately on purchase. Otherwise, they receive Bond Tokens to represent their position while their bond vests. Once the Bond Tokens vest, they can redeem it for the Quote Tokens. The type of Bond Token received depends on the vesting type of the market: Fixed Expiry (all purchases vest at a set time in the future) -> ERC20, Fixed Term (each purchaser waits a specific amount of time from their purchase) -> ERC1155.

Bond Protocol is comprised of 3 main types of contracts:

-   Auctioneers - Store market data, implement pricing logic, and allow creators to create/close markets
-   Tellers - Handle user purchases and issuing/redeeming of bond tokens
-   Aggregator - Maintains unique count of markets across system and provides convenient view functions for querying data across multiple Auctioneers or Tellers

![Bond Protocol Architecture](./bonds/media/Bond%20System%20Architecture%20-%20General.png)

Bond Protocol was launched on mainnet in late 2022 with a single auction type: Sequential Dutch Auctions. The purpose of this audit is to review new auction types that will be added to the existing Bond Protocol system. Additionally, we have created a wrapper on the Gnosis EasyAuction contract to create a seamless experience for creating batch auctions to sell Fixed-Expiry Bond Tokens (ERC20) created on the Bond Fixed Expiry Teller contract. The existing smart contracts can be found on the [Bond Protocol GitHub](https://github.com/Bond-Protocol/bond-contracts) and documentation for them can be found on the [Bond Protocol documentation site](https://docs.bondprotocol.finance/).

# On-chain context

```
DEPLOYMENT: mainnet, arbitrum, optimism, base
ERC20: any
ERC721: none
ERC777: none
FEE-ON-TRANSFER: none, explicitly restricted in tellers
REBASING TOKENS: none, not restricted by code but not expected to be supported
ADMIN: trusted, includes both guardian and policy roles which are held by Bond Protocol MS
EXTERNAL-ADMINS: trusted
```

Please answer the following questions to provide more context:

### Q: Are there any additional protocol roles? If yes, please explain in detail:

1. The roles
2. The actions those roles can take
3. Outcomes that are expected from those roles
4. Specific actions/outcomes NOT intended to be possible for those roles

A: None

---

### Q: Is the code/contract expected to comply with any EIPs? Are there specific assumptions around adhering to those EIPs that Watsons should be aware of?

A: None

---

### Q: Please list any known issues/acceptable risks that should not result in a valid finding.

A: Some of the new auctioneers rely on an oracle. The oracle is supposed to implement criteria for validating the returned data and reverting otherwise. For the OSDA contract, a reverting oracle will cause a DoS of the contract and cause price to continue decreasing while DoS'd. We're debating the pros/cons of having a revert close a market vs. allowing it to continue.

---

### Q: Please provide links to previous audits (if any).

A: The existing Bond Protocol contracts that the new auctioneers will integrate with have been audited a couple times. Here are the audit details for these:

-   [Zellic Audit 1](https://github.com/Bond-Protocol/bond-contracts/blob/master/audits/Zellic/Bond%20Protocol%20Report.pdf)
-   [Zellic Audit 2](https://github.com/Bond-Protocol/bond-contracts/blob/master/audits/Zellic/Bond%20Protocol%20Threat%20Model.pdf)
-   [Sherlock Audit Contest 11/2022](https://github.com/Bond-Protocol/bond-contracts/blob/master/audits/Sherlock/Bond_Final_Report.pdf)

---

### Q: Are there any off-chain mechanisms or off-chain procedures for the protocol (keeper bots, input validation expectations, etc)?

A: The Fixed Price Auctioneer relies on properly formatted price and scale adjustment values when creating a market. These are the same assumptions as the existing Bond Protocol Sequential Dutch Auctioneer contract. Bond Labs operates a dapp that can properly format this data, but it is possible to do it manually as described in the IBondFPA interface and the [Bond Protocol documentation](https://docs.bondprotocol.finance/smart-contracts/auctioneer/base-sequential-dutch-auctioneer-sda#calculating-scale-adjustment).

---

### Q: In case of external protocol integrations, are the risks of an external protocol pausing or executing an emergency withdrawal acceptable? If not, Watsons will submit issues related to these situations that can harm your protocol's functionality.

A: Not Acceptable. The only external integration is for Chainlink price feeds in the sample BondOracle contract. The issues of a price feed failing to return data or update are known. Issues related to the validation of data returned from the price feeds is acceptable though.

# Audit Scope

The contracts in-scope for this audit are:

```
src
├─ bases
|   ├─ BondBaseOSDA.sol
|   ├─ BondBaseOFDA.sol
|   ├─ BondBaseFPA.sol
|   ├─ BondBaseOracle.sol
├─ interfaces
|   ├─ AggregatorV2V3Interface.sol
|   ├─ IBondOSDA.sol
|   ├─ IBondOFDA.sol
|   ├─ IBondFPA.sol
|   ├─ IBondOracle.sol
|   ├─ IBondBatchAuctionFactoryV1.sol
|   ├─ IBondBatchAuctionV1.sol
|   ├─ IGnosisEasyAuction.sol
├─ BondFixedExpiryOSDA.sol
├─ BondFixedTermOSDA.sol
├─ BondFixedExpiryOFDA.sol
├─ BondFixedTermOSDA.sol
├─ BondFixedExpiryFPA.sol
├─ BondFixedTermFPA.sol
├─ BondChainlinkOracle.sol
├─ BondBatchAuctionFactoryV1.sol
├─ BondBatchAuctionV1.sol
```

The in-scope contracts integrate with these previously audited contracts:

```
src
├─ bases
|   ├─ BondBaseTeller.sol
|   ├─ BondBaseCallback.sol
├─ interfaces
|   ├─ IBondTeller.sol
|   ├─ IBondFixedExpiryTeller.sol
|   ├─ IBondFixedTermTellers.sol
|   ├─ IBondAggregator.sol
|   ├─ IBondCallback.sol
|   ├─ IBondAuctioneer.sol
├─ BondAggregator.sol
├─ BondFixedTermTeller.sol
├─ BondFixedExpiryTeller.sol
├─ BondSampleCallback.sol
├─ ERC20BondToken.sol
```

The following sections provide context and details about the different implementations.

## Oracle-based Auctioneers

The Oracle-based Auctioneer contracts allow market creators to create bond markets that use external price feeds to stay in line with market prices. There are two variants of Oracle-based Auctioneers:

-   Oracle Fixed Discount Auctioneer (OFDA)
-   Oracle Sequential Dutch Auctioneer (OSDA)

The IBondOracle interface is required to be implemented for a contract that will serve as an oracle. Bond protocol has created a Base Oracle abstract and implemented a sample oracle contract for Chainlink price feeds that can be used by market issuers. With the sample contract, each issuer deploys their own oracle contract so they have control over the configuration.

### Oracle Fixed Discount Auctioneer (OFDA)

The Oracle-based Fixed Discount Auctioneer allows market creators to sell tokens at a discount to the current oracle price, likely in exchange for vesting the tokens over a certain amount of time. Typically, longer duration vesting will require a larger discount. Additionally, larger discounts may be required for smaller cap tokens or when market demand is low.

Market creators can also set a minimum total discount from the starting price, which creates a hard floor for the market price.

The below chart shows a notional example of how price might evolve over an OFDA market.

![Oracle-based Fixed Discount Auction](./bonds/media/Oracle-based%20Fixed%20Discount%20Auction.png)

### Oracle Sequential Dutch Auctioneer (OSDA)

The Oracle-based Sequential Dutch Auctioneer implements a simplified sequential dutch auction pricing methodology which seeks to sell out the capacity of the market linearly over the duration. We do so by implementing a linear decay of price based on the percent difference in expected capacity vs. actual capacity (relative to the initial capacity) at any given point in time. The OSDA allows specifying a base discount from the oracle price and calculates a decay speed based on a target deposit interval and target discount over that interval. More specifically, we define the price as:

$$ P(t) = O(t) \times (1 - b) \times (1 + k \times r(t)) $$

where $O(t)$ is the oracle price at time $t$, $b$ is the base discount percent of the market, $k$ is the decay speed, and $r(t)$ is the capacity ratio.

We calculate $k$ on market creation as:

$$ k = \frac{L}{I_d} \times d $$

where $L$ is the duration of the market, $I_d$ is the deposit interval, and $d$ is the target deposit interval discount.

We calculate the capacity ratio as:

$$ r(t) = \frac{\chi(t) - C(t)}{C_0} $$

where $C_0$ is the initial capacity of the market, $C(t)$ is the remaining capacity at time $t$, and $\chi(t) = C_0 \times \frac{L - t}{L}$ is the expected capacity at time $t$.

Market creators can also set a minimum total discount from the starting price, which creates a hard floor for the market price.

The below chart shows a notional example of how price might evolve over an OSDA market.

![Oracle-based Sequential Dutch Auctioneer](./bonds/media/Oracle-based%20Sequential%20Dutch%20Auction.png)

If you're familiar with other dutch auction mechanism designs, this version of the SDA is similar to [Paradigm's Continuous Gradual Dutch Auction (GDA) model](https://www.paradigm.xyz/2022/04/gda#continuous-gda) with linear decay, but there is no price slippage based on the purchase amount. Note the version described in the link above uses exponential decay vs. linear decay, but it's possible to derive a linear decay version as well.

Configuring appropriate base discount and target interval discounts is a function of the market demand for the token and the vesting period of the payouts. Typically, longer vesting periods require a larger base discount. Target interval discounts may need to be higher for smaller cap tokens or where demand is soft. However, various combinations can be used depending on desired market characteristics. For example, a high base discount and low target interval discount will give a consistently good deal with low volatility in the market price. The opposite configuration, low base discount and high target interval discount, will be more volatile, but may result in lower overall discounts depending on demand.

### Base Oracle + Sample Bond Chainlink Oracle

Both of the oracle auctioneers rely on an external price feed to function. In order to make it easier for creators to use oracles, we have created a base oracle contract that implements the interface that the auctioneers expect, namely getting the price and decimals from the oracle based on the market id.

Additionally, since Chainlink is the most popular oracle system used in DeFi, we have implemented a sample oracle that implements validation and computation of token pair prices using one or two chainlink price feeds. Assuming both the quote token and payout token have Chainlink price feeds, there are four potential cases it handles:

1. Single feed: Use when there is a price feed for the exact asset pair in quote tokens per payout token (e.g. OHM/ETH which provides the number of ETH (qt) per OHM (pt))

2. Single feed inverse: Use when there is a price for the opposite of your asset pair in quote tokens per payout token (e.g. OHM/ETH which provides the number of ETH per OHM, but you need the number of OHM (qt) per ETH (pt)).

3. Double feed multiplication: Use when two price feeds are required to get the price of the desired asset pair in quote tokens per payout token. For example, if you need the price of OHM/USD, but there is only a price feed for OHM/ETH and ETH/USD, then multiplying the two feeds will give you the price of OHM/USD.

4. Double feed division: Use when two price feeds are required to get the price of the desired asset pair in quote tokens per payout token. For example, if you need the price of OHM/DAI, but there is only a price feed for OHM/ETH and DAI/ETH, then dividing the two feeds will give you the price of OHM/DAI.

## Fixed Price Auctioneer (FPA)

The fixed price auctioneer is the simplest auction variant and does what is sounds like: allows creators to buy/sell a set capacity of token at the quoted price for a certain amount of time. Because of this, it is similar to a limit order in an order book exchange. The goal of this auction variant is to sell as many tokens as possible at the set price. Unlike the SDA auction variants, it is not seeking to sell the full capacity. For completeness, here is an example price/time chart for Fixed Price Auctions:

![Fixed Price Auction](./bonds/media/Fixed%20Price%20Auction.png)

## Bond Batch Auction V1 (Gnosis EasyAuction Wrapper)

The Bond Batch Auction V1 contracts are more separated from the overall Bond system. These contracts implement a wrapper around the [Gnosis EasyAuction contract](https://github.com/gnosis/ido-contracts/blob/main/contracts/EasyAuction.sol) to allow users to create batch auctions for Fixed-Expiry Bond Tokens in a single transaction by providing the underlying token. The EasyAuction contract has some open functions which allow for any user to settle an auction (and therefore send proceeds to the creator) after it ends. We implemented this wrapper using a Factory pattern and Clones with Immutable Args to allow each user to have their own wrapper contract to avoid loss of funds that would occur by tokens being randomly sent to a single wrapper contract from auctions created by multiple users. As such, each user that wishes to create a batch auction first must call `deployClone` on the `BatchAuctionFactoryV1.sol` contract to create their own instance of `BatchAuctionV1.sol` and can then create batch auctions from the clone via `initiateBatchAuction`. The `BatchAuctionV1.sol` contract implements functions to handle cases where the market is settled externally and where it is not. The parameters for batch auctions are largely derived from the EasyAuction contract with a couple additions and a decision to not allow atomic settlement.

# Getting Started

This repository uses Foundry as its development and testing environment. You must first [install Foundry](https://getfoundry.sh/) to build the contracts and run the test suite.

## Clone the repository into a local directory

```sh
git clone https://github.com/sherlock-audit/2023-02-bond
```

## Install dependencies

```sh
cd 2023-02-bond/bonds
touch .env # Add .env file
# Add RPC_URL env variable for an ETH mainnet node to the .env file
# If not, BatchAuctionV1.t.sol will fail since it uses a mainnet fork
npm install # install npm modules for linting and doc generation, optional
forge build # installs git submodule dependencies when contracts are compiled
```

## Build

Compile the contracts with `forge build`.

## Tests

Run the full test suite with `forge test`.

Fuzz tests have been written to cover a range of market situations. Default number of runs is 256, more were used when troubleshooting edge cases.

The test suite can take awhile to run, specifically the `BondOSDAEmissions.t.sol` file. To run the test suite without this file: `forge test --nmc Emissions`

## Linting

Pre-configured `solhint` and `prettier-plugin-solidity`. Can be run by

```sh
npm run lint
```

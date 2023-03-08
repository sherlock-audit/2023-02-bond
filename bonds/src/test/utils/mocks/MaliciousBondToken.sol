// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

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

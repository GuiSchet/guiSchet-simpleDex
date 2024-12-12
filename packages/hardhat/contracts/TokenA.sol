// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenA is ERC20("TokenA", "TKA") {
    constructor() {
        _mint(0x1E2E4c416e51F8a420062500DD37D0B2CcFdDDFB, 1000);

    }
}
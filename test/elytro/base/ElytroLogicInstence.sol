// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@source/Elytro.sol";

contract ElytroLogicInstence {
    Elytro public elytroLogic;

    constructor(address _entryPoint, address defaultValidator) {
        elytroLogic = new Elytro(_entryPoint, defaultValidator);
    }
}

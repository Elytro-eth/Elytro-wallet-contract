// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IModuleManager} from "@soulwallet-core/contracts/interface/IModuleManager.sol";

interface IElytroModuleManager is IModuleManager {
    function installModule(bytes calldata moduleAndData) external;
}

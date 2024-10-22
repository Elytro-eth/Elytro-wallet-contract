// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ValidatorManager} from "@soulwallet-core/contracts/base/ValidatorManager.sol";
import {IElytroValidatorManager} from "../interfaces/IElytroValidatorManager.sol";

abstract contract ElytroValidatorManager is IElytroValidatorManager, ValidatorManager {
    function installValidator(bytes calldata validatorAndData) external virtual override {
        validatorManagementAccess();
        _installValidator(address(bytes20(validatorAndData[:20])), validatorAndData[20:]);
    }
}

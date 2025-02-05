// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "../abstract/ElytroUpgradeManager.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract NewImplementation is Initializable, ElytroUpgradeManager {
    address public immutable WALLETIMPL;
    bytes32 public constant CURRENT_UPGRADE_SLOT = keccak256("elytro.wallet.upgradeTo_NewImplementation");

    constructor() {
        WALLETIMPL = address(this);
        _disableInitializers();
    }

    function initialize(
        bytes32[] calldata owners,
        address defalutCallbackHandler,
        bytes[] calldata modules,
        bytes[] calldata hooks
    ) external initializer {}

    function hello() external pure returns (string memory) {
        return "hello world";
    }

    function upgradeTo(address newImplementation) external override {
        _upgradeTo(newImplementation);
    }

    function upgradeFrom(address oldImplementation) external override {
        (oldImplementation);
        require(oldImplementation != WALLETIMPL);
        bool hasUpgraded = false;

        bytes32 _CURRENT_UPGRADE_SLOT = CURRENT_UPGRADE_SLOT;
        assembly {
            hasUpgraded := sload(_CURRENT_UPGRADE_SLOT)
        }
        require(!hasUpgraded, "already upgraded");
        assembly {
            sstore(_CURRENT_UPGRADE_SLOT, 1)
        }

        // data migration during upgrade
    }
}

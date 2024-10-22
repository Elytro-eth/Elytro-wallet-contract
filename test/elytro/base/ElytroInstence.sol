// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./ElytroLogicInstence.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import "@source/factory/ElytroFactory.sol";
import "@source/libraries/TypeConversion.sol";
import "@source/interfaces/IElytro.sol";

contract ElytroInstence {
    using TypeConversion for address;

    ElytroLogicInstence public elytroLogicInstence;
    ElytroFactory public elytroFactory;
    EntryPoint public entryPoint;
    IElytro public elytro;

    constructor(
        address defaultCallbackHandler,
        address defaultValidator,
        bytes32[] memory owners,
        bytes[] memory modules,
        bytes[] memory hooks,
        bytes32 salt
    ) {
        entryPoint = new EntryPoint();
        elytroLogicInstence = new ElytroLogicInstence(address(entryPoint), address(defaultValidator));

        elytroFactory =
            new ElytroFactory(address(elytroLogicInstence.elytroLogic()), address(entryPoint), address(this));

        // elytroLogicInstence.initialize(owners, defaultCallbackHandler, modules, hooks);
        bytes memory initializer = abi.encodeWithSignature(
            "initialize(bytes32[],address,bytes[],bytes[])", owners, defaultCallbackHandler, modules, hooks
        );
        address walletAddress1 = elytroFactory.getWalletAddress(initializer, salt);
        address walletAddress2 = elytroFactory.createWallet(initializer, salt);
        require(walletAddress1 == walletAddress2, "walletAddress1 != walletAddress2");
        require(walletAddress2.code.length > 0, "wallet code is empty");
        // walletAddress1 as Elytro
        elytro = IElytro(walletAddress1);
    }
}

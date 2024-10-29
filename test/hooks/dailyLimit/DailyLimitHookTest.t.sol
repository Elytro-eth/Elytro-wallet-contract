// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../elytro/base/ElytroInstence.sol";
import {ElytroDefaultValidator} from "@source/validator/ElytroDefaultValidator.sol";
import {DailyERC20SpendingLimitHook} from "@source/hooks/spendLimit/DailyERC20SpendingLimitHook.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {UserOpHelper} from "../../helper/UserOpHelper.t.sol";
import {UserOperationHelper} from "@soulwallet-core/test/dev/userOperationHelper.sol";
import "@source/dev/tokens/TokenERC20.sol";

contract DailyLimitHookTest is Test, UserOpHelper {
    using TypeConversion for address;

    ElytroInstence public elytroInstence;
    ElytroDefaultValidator public elytroDefaultValidator;
    IElytro public elytro;
    address public walletOwner;
    uint256 public walletOwnerPrivateKey;

    DailyERC20SpendingLimitHook public dailyLimitHook;
    uint256 public constant DAILY_LIMIT = 1 ether;
    TokenERC20 testLimitToken;
    TokenERC20 testNoLimitToken;
    EntryPoint public testEntryPoint;

    function setUp() public {
        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner");
        dailyLimitHook = new DailyERC20SpendingLimitHook();
        testLimitToken = new TokenERC20(18);
        testNoLimitToken = new TokenERC20(18);

        bytes[] memory modules = new bytes[](0);
        bytes[] memory hooks = new bytes[](1);
        uint8 capabilityFlags = 2; // preUserOpValidationHook only
        address[] memory tokens = new address[](2);
        uint256[] memory limits = new uint256[](2);
        tokens[0] = address(testLimitToken);
        limits[0] = DAILY_LIMIT;
        tokens[1] = address(2);
        limits[1] = DAILY_LIMIT;
        bytes memory tokenAndLimit = abi.encode(tokens, limits);
        hooks[0] = abi.encodePacked(address(dailyLimitHook), tokenAndLimit, capabilityFlags);

        bytes32[] memory owners = new bytes32[](1);
        owners[0] = walletOwner.toBytes32();
        elytroDefaultValidator = new ElytroDefaultValidator();
        bytes32 salt = bytes32(0);
        elytroInstence = new ElytroInstence(address(0), address(elytroDefaultValidator), owners, modules, hooks, salt);
        elytro = elytroInstence.elytro();
        testEntryPoint = elytroInstence.entryPoint();
    }

    function test_ethUnderLimit() public {
        vm.deal(address(elytro), 1000 ether);

        bytes memory callData = abi.encodeWithSelector(IStandardExecutor.execute.selector, address(10), 0.5 ether, "");

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp({
            sender: address(elytro),
            nonce: 0,
            initCode: "",
            callData: callData,
            callGasLimit: 900000,
            verificationGasLimit: 1000000,
            preVerificationGas: 300000,
            maxFeePerGas: 100 gwei,
            maxPriorityFeePerGas: 100 gwei,
            paymasterAndData: ""
        });
        bytes memory hookAndData = returnDummyHookAndData();

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        userOperation.signature = signUserOp(
            testEntryPoint, userOperation, walletOwnerPrivateKey, address(elytroDefaultValidator), hookAndData
        );
        ops[0] = userOperation;
        testEntryPoint.handleOps(ops, payable(walletOwner));
    }

    function test_ethOverLimit() public {
        vm.deal(address(elytro), 1000 ether);

        bytes memory callData = abi.encodeWithSelector(IStandardExecutor.execute.selector, address(10), 2 ether, "");

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp({
            sender: address(elytro),
            nonce: 0,
            initCode: "",
            callData: callData,
            callGasLimit: 900000,
            verificationGasLimit: 1000000,
            preVerificationGas: 300000,
            maxFeePerGas: 100 gwei,
            maxPriorityFeePerGas: 100 gwei,
            paymasterAndData: ""
        });
        bytes memory hookAndData = returnDummyHookAndData();

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        userOperation.signature = signUserOp(
            testEntryPoint, userOperation, walletOwnerPrivateKey, address(elytroDefaultValidator), hookAndData
        );
        ops[0] = userOperation;
        vm.expectRevert();
        testEntryPoint.handleOps(ops, payable(walletOwner));
    }

    function test_multipleTxsInOneDay() public {
        vm.deal(address(elytro), 1000 ether);

        // First transaction: 0.4 ether
        _executeTransaction(0.4 ether, false);

        // Second transaction: 0.4 ether
        _executeTransaction(0.4 ether, false);

        _executeTransaction(0.3 ether, true);
    }

    function test_resetLimitNextDay() public {
        vm.deal(address(elytro), 1000 ether);

        // First day transactions
        _executeTransaction(0.5 ether, false);
        _executeTransaction(0.4 ether, false);

        // Move to next day
        vm.warp(block.timestamp + 24 hours);

        // Should work as limit is reset
        _executeTransaction(0.5 ether, false);
    }

    function _executeTransaction(uint256 amount, bool expectRevert) internal {
        bytes memory callData = abi.encodeWithSelector(IStandardExecutor.execute.selector, address(10), amount, "");

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp({
            sender: address(elytro),
            nonce: testEntryPoint.getNonce(address(elytro), 0),
            initCode: "",
            callData: callData,
            callGasLimit: 900000,
            verificationGasLimit: 1000000,
            preVerificationGas: 300000,
            maxFeePerGas: 100 gwei,
            maxPriorityFeePerGas: 100 gwei,
            paymasterAndData: ""
        });

        bytes memory hookAndData = returnDummyHookAndData();
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        userOperation.signature = signUserOp(
            testEntryPoint, userOperation, walletOwnerPrivateKey, address(elytroDefaultValidator), hookAndData
        );
        ops[0] = userOperation;
        if (expectRevert) {
            vm.expectRevert();
        }
        testEntryPoint.handleOps(ops, payable(walletOwner));
    }

    function test_erc20UnderLimit() public {
        vm.deal(address(elytro), 1000 ether);
        // Mint tokens to the wallet
        testLimitToken.sudoMint(address(elytro), 1000 ether);

        bytes memory callData = abi.encodeWithSelector(
            IStandardExecutor.execute.selector,
            address(testLimitToken),
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, address(10), 0.5 ether)
        );

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp({
            sender: address(elytro),
            nonce: 0,
            initCode: "",
            callData: callData,
            callGasLimit: 900000,
            verificationGasLimit: 1000000,
            preVerificationGas: 300000,
            maxFeePerGas: 100 gwei,
            maxPriorityFeePerGas: 100 gwei,
            paymasterAndData: ""
        });
        bytes memory hookAndData = returnDummyHookAndData();

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        userOperation.signature = signUserOp(
            testEntryPoint, userOperation, walletOwnerPrivateKey, address(elytroDefaultValidator), hookAndData
        );
        ops[0] = userOperation;
        testEntryPoint.handleOps(ops, payable(walletOwner));
    }

    function test_erc20OverLimit() public {
        vm.deal(address(elytro), 1000 ether);
        // Mint tokens to the wallet
        testLimitToken.sudoMint(address(elytro), 1000 ether);

        bytes memory callData = abi.encodeWithSelector(
            IStandardExecutor.execute.selector,
            address(testLimitToken),
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, address(10), 2 ether)
        );

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp({
            sender: address(elytro),
            nonce: 0,
            initCode: "",
            callData: callData,
            callGasLimit: 900000,
            verificationGasLimit: 1000000,
            preVerificationGas: 300000,
            maxFeePerGas: 100 gwei,
            maxPriorityFeePerGas: 100 gwei,
            paymasterAndData: ""
        });
        bytes memory hookAndData = returnDummyHookAndData();

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        userOperation.signature = signUserOp(
            testEntryPoint, userOperation, walletOwnerPrivateKey, address(elytroDefaultValidator), hookAndData
        );
        ops[0] = userOperation;
        vm.expectRevert();
        testEntryPoint.handleOps(ops, payable(walletOwner));
    }

    function test_erc20MultipleTxsInOneDay() public {
        vm.deal(address(elytro), 1000 ether);
        // Mint tokens to the wallet
        testLimitToken.sudoMint(address(elytro), 1000 ether);

        // First transaction: 0.4 ether
        _executeERC20Transaction(0.4 ether, false);

        // Second transaction: 0.4 ether
        _executeERC20Transaction(0.4 ether, false);

        // Third transaction should revert as it exceeds daily limit
        _executeERC20Transaction(0.3 ether, true);
    }

    function test_erc20ResetLimitNextDay() public {
        vm.deal(address(elytro), 1000 ether);
        // Mint tokens to the wallet
        testLimitToken.sudoMint(address(elytro), 1000 ether);

        // First day transactions
        _executeERC20Transaction(0.5 ether, false);
        _executeERC20Transaction(0.4 ether, false);

        // Move to next day
        vm.warp(block.timestamp + 24 hours);

        // Should work as limit is reset
        _executeERC20Transaction(0.5 ether, false);
    }

    function _executeERC20Transaction(uint256 amount, bool expectRevert) internal {
        bytes memory callData = abi.encodeWithSelector(
            IStandardExecutor.execute.selector,
            address(testLimitToken),
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, address(10), amount)
        );

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp({
            sender: address(elytro),
            nonce: testEntryPoint.getNonce(address(elytro), 0),
            initCode: "",
            callData: callData,
            callGasLimit: 900000,
            verificationGasLimit: 1000000,
            preVerificationGas: 300000,
            maxFeePerGas: 100 gwei,
            maxPriorityFeePerGas: 100 gwei,
            paymasterAndData: ""
        });

        bytes memory hookAndData = returnDummyHookAndData();
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        userOperation.signature = signUserOp(
            testEntryPoint, userOperation, walletOwnerPrivateKey, address(elytroDefaultValidator), hookAndData
        );
        ops[0] = userOperation;
        if (expectRevert) {
            vm.expectRevert();
        }
        testEntryPoint.handleOps(ops, payable(walletOwner));
    }

    function test_noLimitTokenMultipleTransfers() public {
        vm.deal(address(elytro), 1000 ether);
        // Mint tokens to the wallet
        testNoLimitToken.sudoMint(address(elytro), 1000 ether);

        // Should be able to make multiple large transfers since this token isn't limited
        _executeNoLimitTokenTransaction(2 ether);
        _executeNoLimitTokenTransaction(3 ether);
        _executeNoLimitTokenTransaction(4 ether);
    }

    function test_noLimitTokenTransfer() public {
        vm.deal(address(elytro), 1000 ether);
        // Mint tokens to the wallet
        testNoLimitToken.sudoMint(address(elytro), 1000 ether);

        // Should be able to transfer more than the daily limit since this token isn't limited
        bytes memory callData = abi.encodeWithSelector(
            IStandardExecutor.execute.selector,
            address(testNoLimitToken),
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, address(10), 2 ether)
        );

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp({
            sender: address(elytro),
            nonce: 0,
            initCode: "",
            callData: callData,
            callGasLimit: 900000,
            verificationGasLimit: 1000000,
            preVerificationGas: 300000,
            maxFeePerGas: 100 gwei,
            maxPriorityFeePerGas: 100 gwei,
            paymasterAndData: ""
        });
        bytes memory hookAndData = returnDummyHookAndData();

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        userOperation.signature = signUserOp(
            testEntryPoint, userOperation, walletOwnerPrivateKey, address(elytroDefaultValidator), hookAndData
        );
        ops[0] = userOperation;
        testEntryPoint.handleOps(ops, payable(walletOwner));
    }

    function _executeNoLimitTokenTransaction(uint256 amount) internal {
        bytes memory callData = abi.encodeWithSelector(
            IStandardExecutor.execute.selector,
            address(testNoLimitToken),
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, address(10), amount)
        );

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp({
            sender: address(elytro),
            nonce: testEntryPoint.getNonce(address(elytro), 0),
            initCode: "",
            callData: callData,
            callGasLimit: 900000,
            verificationGasLimit: 1000000,
            preVerificationGas: 300000,
            maxFeePerGas: 100 gwei,
            maxPriorityFeePerGas: 100 gwei,
            paymasterAndData: ""
        });

        bytes memory hookAndData = returnDummyHookAndData();
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        userOperation.signature = signUserOp(
            testEntryPoint, userOperation, walletOwnerPrivateKey, address(elytroDefaultValidator), hookAndData
        );
        ops[0] = userOperation;
        testEntryPoint.handleOps(ops, payable(walletOwner));
    }

    function returnDummyHookAndData() private view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x1, bytes32(0));
        bytes memory hookSignatureData = abi.encodePacked(r, s, v);
        bytes4 hookSignatureLength = bytes4(uint32(hookSignatureData.length));
        return abi.encodePacked(address(dailyLimitHook), hookSignatureLength, hookSignatureData);
    }
}

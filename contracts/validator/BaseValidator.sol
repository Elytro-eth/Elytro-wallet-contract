// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../interfaces/IValidator.sol";
import "./libraries/ValidatorSigDecoder.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../libraries/TypeConversion.sol";
import "../libraries/Errors.sol";
import "../libraries/WebAuthn.sol";

abstract contract BaseValidator is IValidator {
    using ECDSA for bytes32;
    using TypeConversion for address;

    function _packSignatureHash(bytes32 hash, uint8 signatureType, uint256 validationData)
        internal
        pure
        virtual
        returns (bytes32);

    function recover(uint8 signatureType, bytes32 rawHash, bytes calldata rawSignature)
        internal
        view
        returns (bytes32 recovered, bool success)
    {
        if (signatureType == 0x0 || signatureType == 0x1) {
            //ecdas recover
            (address recoveredAddr, ECDSA.RecoverError error,) = ECDSA.tryRecover(rawHash, rawSignature);
            if (error != ECDSA.RecoverError.NoError) {
                success = false;
            } else {
                success = true;
            }
            recovered = recoveredAddr.toBytes32();
        } else if (signatureType == 0x2 || signatureType == 0x3) {
            bytes32 publicKey = WebAuthn.recover(rawHash, rawSignature);
            if (publicKey == 0) {
                recovered = publicKey;
                success = false;
            } else {
                recovered = publicKey;
                success = true;
            }
        } else {
            revert Errors.INVALID_SIGNTYPE();
        }
    }

    function recoverSignature(bytes32 rawHash, bytes calldata rawSignature)
        external
        view
        override
        returns (uint256 validationData, bytes32 recovered, bool success)
    {
        uint8 signatureType;
        bytes calldata signature;
        (signatureType, validationData, signature) = ValidatorSigDecoder.decodeValidatorSignature(rawSignature);

        bytes32 hash = _packSignatureHash(rawHash, signatureType, validationData);

        (recovered, success) = recover(signatureType, hash, signature);
    }
}

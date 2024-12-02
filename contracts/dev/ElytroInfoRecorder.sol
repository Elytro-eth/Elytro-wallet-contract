// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ElytroInfoRecorder
 * @notice A general purpose event recorder for wallet-related information
 */
contract ElytroInfoRecorder {
    /**
     * @notice record wallet info via event
     * @param wallet The wallet address
     * @param category The category of the info (e.g., "keccak256("GUARDIAN_INFO");", etc)
     * @param data ABI encoded info
     */
    event DataRecorded(address indexed wallet, bytes32 indexed category, bytes data);

    /**
     * @notice Record info for a wallet
     * @param category The category of info being recorded
     * @param data ABI encoded data
     */
    function recordData(bytes32 category, bytes calldata data) external {
        emit DataRecorded(msg.sender, category, data);
    }
}

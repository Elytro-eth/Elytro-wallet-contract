// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ElytroInfoRecorder
 * @notice A general purpose event recorder for wallet-related information
 * Key Features:
 * - Event-based information recording
 * - Gas-efficient design
 * - Support for multiple data categories
 * - Indexed parameters for efficient querying
 * - Flexible data encoding support
 * Common Categories:
 * ```solidity
 * bytes32 constant GUARDIAN_INFO = keccak256("GUARDIAN_INFO");
 * ```
 *
 * Usage Example:
 * ```solidity
 * // Recording Guardian information
 * bytes32 category = keccak256("GUARDIAN_INFO");
 * address[] memory guardians = // guardian addresses
 * uint256 threshold = // threshold value
 * bytes memory guardianData = abi.encode(guardians, threshold);
 * elytroInfoRecorder.recordData(category, guardianData);
 * ```
 * Security Considerations:
 * 1. All recorded data is publicly visible on-chain
 * 2. Only the wallet itself can record its data (msg.sender)
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

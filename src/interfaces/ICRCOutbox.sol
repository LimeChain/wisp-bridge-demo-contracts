// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Types} from "./Types.sol";

interface ICRCOutbox {
    event MessageSent(
        address indexed sender,
        uint256 indexed destinationChainId,
        bytes32 indexed hash,
        uint256 messageIndex
    );

    /// @notice sends CRCMessage
    /// @param message the message to be sent
    /// @return messageHash the hash of the message that was sent
    function sendMessage(Types.CRCMessage calldata message)
        external
        returns (bytes32 messageHash);
}

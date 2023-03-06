// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Bridge} from "./Bridge.sol";

/// @notice Minimalistic contract used for bridging ETH between rollups via the wisp protocol
/// @dev maximum transfer value of 0.01 ETH
/// @dev used for showcase of the Wisp protocol
/// @author Perseverance
contract BridgeETH is Bridge {
    uint256 public constant messageValueLimit = 1 ether / 100;

    constructor(
        uint8 _version,
        address _outbox,
        address _inbox,
        uint256 _counterpartyChainId
    ) Bridge(_version, _outbox, _inbox, _counterpartyChainId) {}

    /// @notice Locks and sends ETH towards the destination
    /// @param nonce a random number used only once per message. Used anti replay attacks.
    function lock(uint64 nonce) public payable {
        uint256 value = (msg.value <= messageValueLimit)
            ? msg.value
            : messageValueLimit;
        sendMessage(nonce, value);
    }

    /// @notice Unlocks funds when receiving a message
    /// @param receiver the recepient of ETH
    /// @param value value being locked in the source
    function onMessageReceived(address receiver, uint256 value)
        internal
        virtual
        override
        returns (bool success)
    {
        unlock(payable(receiver), value);
        return true;
    }

    /// @notice sends value ETH to the receiver
    /// @param receiver the recepient of ETH
    /// @param value value being sent
    function unlock(address payable receiver, uint256 value) private {
        safeTransferETH(receiver, value);
    }

    /// @notice safe function for sending ETH
    /// @param to the recepient of ETH
    /// @param amount the amount being sent
    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    receive() external payable {}
}

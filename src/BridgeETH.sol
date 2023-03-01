// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Bridge} from "./Bridge.sol";

contract BridgeETH is Bridge {
    uint256 public constant messageValueLimit = 1 ether / 100;

    constructor(
        uint8 _version,
        address _outbox,
        address _inbox,
        uint256 _counterpartyChainId
    ) Bridge(_version, _outbox, _inbox, _counterpartyChainId) {}

    function lock(uint64 nonce) public payable {
        uint256 value = (msg.value <= messageValueLimit)
            ? msg.value
            : messageValueLimit;
        sendMessage(nonce, value);
    }

    function onMessageReceived(address receiver, uint256 value)
        internal
        virtual
        override
        returns (bool success)
    {
        unlock(payable(receiver), value);
        return true;
    }

    function unlock(address payable receiver, uint256 value) private {
        safeTransferETH(receiver, value);
    }

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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ICRCOutbox} from "./interfaces/ICRCOutbox.sol";
import {IMessageReceiver} from "./interfaces/IMessageReceiver.sol";
import {Types} from "./interfaces/Types.sol";

abstract contract Bridge is IMessageReceiver {
    /// @notice version of Wisp that this protocol uses
    uint8 public immutable WISP_VERSION;

    /// @notice the outbox contract used for sending tokens
    ICRCOutbox public immutable outbox;

    /// @notice the inbox contract of this rollup that we should only oblige to when receiving messages
    address public immutable inbox;

    /// @notice the chainId of the other rollup that we would send to
    uint256 public immutable counterpartyChainId;

    /// @notice the address of this bridge contract on the other rollup that we should target.
    address public counterparty;

    event Lock(
        address indexed sender,
        uint256 indexed amount,
        bytes32 messageHash
    );

    modifier onlyInbox() {
        require(msg.sender == inbox, "not sent by the inbox contract");
        _;
    }

    constructor(
        uint8 _version,
        address _outbox,
        address _inbox,
        uint256 _counterpartyChainId
    ) {
        WISP_VERSION = _version;
        outbox = ICRCOutbox(_outbox);
        inbox = _inbox;
        counterpartyChainId = _counterpartyChainId;
    }

    function setCounteparty(address _counterparty) public {
        require(counterparty == address(0), "Counterparty already set");
        counterparty = _counterparty;
    }

    function sendMessage(uint64 nonce, uint256 value) internal {
        require(value > 0, "No ETH Sent");
        bytes memory payload = abi.encode(msg.sender, value);

        Types.CRCMessage memory message = Types.CRCMessage(
            WISP_VERSION,
            counterpartyChainId,
            nonce,
            msg.sender,
            counterparty,
            payload,
            0,
            0,
            hex""
        );

        bytes32 messageHash = outbox.sendMessage(message);

        emit Lock(msg.sender, msg.value, messageHash);
    }

    /// @notice receives CRCMessageEnvelope
    /// @param envelope the message envelope you are receiving
    function receiveMessage(
        Types.CRCMessageEnvelope calldata envelope,
        uint256 sourceChainId
    ) external virtual onlyInbox returns (bool success) {
        assert(envelope.message.target == address(this));
        address receiver;
        uint256 value;
        (receiver, value) = abi.decode(
            envelope.message.payload,
            (address, uint256)
        );
        assert(receiver == envelope.message.user);
        return onMessageReceived(receiver, value);
    }

    function onMessageReceived(address receiver, uint256 value)
        internal
        virtual
        returns (bool success);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ICRCOutbox} from "./interfaces/ICRCOutbox.sol";
import {IMessageReceiver} from "./interfaces/IMessageReceiver.sol";
import {Types} from "./interfaces/Types.sol";

/// @notice Base contract for a bridge. Sends and receives wisp messages
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

    event MessageReceived(address indexed receiver, uint256 indexed amount);

    modifier onlyInbox() {
        require(msg.sender == inbox, "not sent by the inbox contract");
        _;
    }

    /// @param _version version of the wisp protocol
    /// @param _outbox the address of the wisp protocol outbox that the bridge will send to
    /// @param _inbox the address of the wisp protocol inbox that the bridge will read from
    /// @param _counterpartyChainId the chain id of the network whose messages this bridge will only respond to
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

    /// @notice used for setting the address of the bridge countract in the counterparty rollup
    /// @dev will be used for checking when receiving messages
    /// @param _counterparty the address of the bridge contract in the counterparty network
    function setCounteparty(address _counterparty) public {
        require(counterparty == address(0), "Counterparty already set");
        counterparty = _counterparty;
    }

    /// @notice used for sending messages
    /// @dev creates a message sends it to the wisp outbox
    /// @param nonce a random number used once to guard against replay and differentiate messages
    /// @param value the amount of currency being sent.
    function sendMessage(uint64 nonce, uint256 value) internal {
        require(value > 0, "No value Sent");
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

        emit Lock(msg.sender, value, messageHash);
    }

    /// @notice Implements the receiver interface. Sanity checks the message and passes it to implementers to process.
    /// @param envelope the message envelope you are receiving
    /// @param sourceChainId the chainid of the message source
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
        emit MessageReceived(receiver, value);
        return onMessageReceived(receiver, value);
    }

    /// @notice Used by extending contracts to respond to checked messages
    /// @param receiver the message receiver
    /// @param value value being locked in the source
    function onMessageReceived(address receiver, uint256 value)
        internal
        virtual
        returns (bool success);
}

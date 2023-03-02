// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {BridgeETH} from "./../src/BridgeETH.sol";
import {Types} from "./../src/interfaces/Types.sol";
import {ICRCOutbox} from "./../src/interfaces/ICRCOutbox.sol";
import {IMessageReceiver} from "./../src/interfaces/IMessageReceiver.sol";

contract MockCRCInbox is IMessageReceiver {
    function receiveMessage(
        Types.CRCMessageEnvelope calldata envelope,
        uint256 sourceChainId
    ) external override returns (bool success) {}
}

contract MockCRCOutbox is ICRCOutbox {
    function sendMessage(Types.CRCMessage calldata message)
        external
        override
        returns (bytes32 messageHash)
    {}
}

contract CRCOutboxTest is Test {
    event Lock(
        address indexed sender,
        uint256 indexed amount,
        bytes32 messageHash
    );

    event MessageReceived(address indexed receiver, uint256 indexed amount);

    /// @notice version of Wisp that this protocol uses
    uint8 public constant WISP_VERSION = 1;

    BridgeETH public source;
    ICRCOutbox public sourceOutbox;
    IMessageReceiver public sourceInbox;
    uint64 public sourceChainId = 420;

    BridgeETH public destination;
    ICRCOutbox public destinationOutbox;
    IMessageReceiver public destinationInbox;
    uint64 public destinationChainId = 81723;

    function setUp() public {
        sourceOutbox = new MockCRCOutbox();
        sourceInbox = new MockCRCInbox();
        destinationOutbox = new MockCRCOutbox();
        destinationInbox = new MockCRCInbox();

        source = new BridgeETH(
            WISP_VERSION,
            address(sourceOutbox),
            address(sourceInbox),
            destinationChainId
        );

        destination = new BridgeETH(
            WISP_VERSION,
            address(destinationOutbox),
            address(destinationInbox),
            sourceChainId
        );

        source.setCounteparty(address(destination));
        destination.setCounteparty(address(source));

        vm.deal(address(destination), 100 ether);
    }

    function testLockSendsMessage(uint64 nonce, uint256 value) public {
        value = bound(value, 1, 10000);
        bytes memory payload = abi.encode(address(this), value);

        Types.CRCMessage memory message = Types.CRCMessage({
            version: WISP_VERSION,
            destinationChainId: destinationChainId,
            nonce: nonce,
            user: address(this),
            target: address(destination),
            payload: payload,
            stateRelayFee: 0,
            deliveryFee: 0,
            extra: hex""
        });

        vm.expectCall(
            address(sourceOutbox),
            abi.encodeCall(sourceOutbox.sendMessage, (message))
        );
        source.lock{value: value}(nonce);
    }

    function testLockSendsLowerValue(uint64 nonce, uint256 value) public {
        uint256 messageValueLimit = source.messageValueLimit();
        value = bound(value, messageValueLimit, messageValueLimit * 100);
        bytes memory payload = abi.encode(address(this), messageValueLimit);

        Types.CRCMessage memory message = Types.CRCMessage({
            version: WISP_VERSION,
            destinationChainId: destinationChainId,
            nonce: nonce,
            user: address(this),
            target: address(destination),
            payload: payload,
            stateRelayFee: 0,
            deliveryFee: 0,
            extra: hex""
        });

        vm.expectCall(
            address(sourceOutbox),
            abi.encodeCall(sourceOutbox.sendMessage, (message))
        );
        source.lock{value: value}(nonce);
    }

    function testLockEventEmitted(uint64 nonce, uint256 value) public {
        value = bound(value, 1, 10000);
        vm.expectEmit(true, true, false, false);
        emit Lock(address(this), value, hex"");
        source.lock{value: value}(nonce);
    }

    function testRevertingOnZero(uint64 nonce) public {
        vm.expectRevert("No value Sent");
        source.lock(nonce);
    }

    function testReceiveReleasesETH(uint64 nonce, uint256 value) public {
        value = bound(value, 1, 10000);
        bytes memory payload = abi.encode(address(this), value);

        Types.CRCMessage memory message = Types.CRCMessage({
            version: WISP_VERSION,
            destinationChainId: destinationChainId,
            nonce: nonce,
            user: address(this),
            target: address(destination),
            payload: payload,
            stateRelayFee: 0,
            deliveryFee: 0,
            extra: hex""
        });

        Types.CRCMessageEnvelope memory envelope = Types.CRCMessageEnvelope({
            message: message,
            sender: address(source)
        });

        uint256 balanceBefore = address(this).balance;

        vm.prank(address(destinationInbox));
        destination.receiveMessage(envelope, sourceChainId);

        assertEq(balanceBefore + value, address(this).balance);
    }

    function testMessageReceivedEventEmitted(uint64 nonce, uint256 value)
        public
    {
        value = bound(value, 1, 10000);
        bytes memory payload = abi.encode(address(this), value);

        Types.CRCMessage memory message = Types.CRCMessage({
            version: WISP_VERSION,
            destinationChainId: destinationChainId,
            nonce: nonce,
            user: address(this),
            target: address(destination),
            payload: payload,
            stateRelayFee: 0,
            deliveryFee: 0,
            extra: hex""
        });

        Types.CRCMessageEnvelope memory envelope = Types.CRCMessageEnvelope({
            message: message,
            sender: address(source)
        });

        vm.startPrank(address(destinationInbox));

        vm.expectEmit(true, true, false, false);
        emit MessageReceived(address(this), value);

        destination.receiveMessage(envelope, sourceChainId);

        vm.stopPrank();
    }

    function testRevertOnWrongTarget(uint64 nonce, uint256 value) public {
        value = bound(value, 1, 10000);
        bytes memory payload = abi.encode(address(this), value);

        Types.CRCMessage memory message = Types.CRCMessage({
            version: WISP_VERSION,
            destinationChainId: destinationChainId,
            nonce: nonce,
            user: address(this),
            target: address(0),
            payload: payload,
            stateRelayFee: 0,
            deliveryFee: 0,
            extra: hex""
        });

        Types.CRCMessageEnvelope memory envelope = Types.CRCMessageEnvelope({
            message: message,
            sender: address(source)
        });

        uint256 balanceBefore = address(this).balance;

        vm.startPrank(address(destinationInbox));

        vm.expectRevert();
        destination.receiveMessage(envelope, sourceChainId);

        assertEq(balanceBefore, address(this).balance);
    }

    function testRevertOnWrongUser(uint64 nonce, uint256 value) public {
        value = bound(value, 1, 10000);
        bytes memory payload = abi.encode(address(this), value);

        Types.CRCMessage memory message = Types.CRCMessage({
            version: WISP_VERSION,
            destinationChainId: destinationChainId,
            nonce: nonce,
            user: address(0),
            target: address(destination),
            payload: payload,
            stateRelayFee: 0,
            deliveryFee: 0,
            extra: hex""
        });

        Types.CRCMessageEnvelope memory envelope = Types.CRCMessageEnvelope({
            message: message,
            sender: address(source)
        });

        uint256 balanceBefore = address(this).balance;

        vm.startPrank(address(destinationInbox));

        vm.expectRevert();
        destination.receiveMessage(envelope, sourceChainId);

        assertEq(balanceBefore, address(this).balance);
    }

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/BridgeETH.sol";

contract DeployScript is Script {
    function run() external {
        uint8 version = uint8(vm.envUint("WISP_VERSION"));
        address outbox = vm.envAddress("OUTBOX_ADDRESS");
        address inbox = vm.envAddress("INBOX_ADDRESS");
        uint256 counterpartyChainId = vm.envUint("COUNTERPARTY_CHAINID");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        new BridgeETH(version, outbox, inbox, counterpartyChainId);

        vm.stopBroadcast();
    }
}

contract SetCounterParty is Script {
    function run() external {
        address bridgeAddress = vm.envAddress("BRIDGE_ADDRESS");
        address counterparty = vm.envAddress("COUNTERPARTY_ADDRESS");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        BridgeETH bridge = BridgeETH(payable(bridgeAddress));
        bridge.setCounteparty(counterparty);

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {Bridge} from "../src/Bridge.sol";
import {MessageRelay} from "../src/MessageRelay.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title Deploy
 * @notice Deploy local: underlying mock, Bridge (con BridgeToken) y MessageRelay.
 * @dev `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 */
contract Deploy is Script {
    uint256 internal constant THRESHOLD = 1;
    uint256 internal constant MINT_AMOUNT = 1_000_000 ether;

    /**
     * @notice Despliega el stack demo listo para deposit → sign → release en Anvil.
     */
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);
        // Anvil #1 como relayer demo (pk conocido solo en local).
        address relayer = vm.addr(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d);

        vm.startBroadcast(pk);

        MockERC20 underlying = new MockERC20("Underlying", "UND");
        underlying.mint(deployer, MINT_AMOUNT);

        Bridge bridge = new Bridge(relayer, THRESHOLD);
        MessageRelay relay = new MessageRelay(relayer, THRESHOLD);

        vm.stopBroadcast();

        console2.log("Deployer", deployer);
        console2.log("Relayer", relayer);
        console2.log("Underlying", address(underlying));
        console2.log("Bridge", address(bridge));
        console2.log("BridgeToken", bridge.bridgeToken());
        console2.log("MessageRelay", address(relay));
        console2.log("Threshold", THRESHOLD);
        console2.log("ChainId", block.chainid);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {Bridge} from "../src/Bridge.sol";
import {MessageRelay} from "../src/MessageRelay.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title Deploy
 * @notice Deploy local (Anvil) o testnet: MockERC20 + Bridge + MessageRelay.
 * @dev Local:
 *      `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 *      Testnet (ej. Sepolia):
 *      `forge script script/Deploy.s.sol:Deploy --rpc-url $SEPOLIA_RPC_URL --broadcast --verify`
 */
contract Deploy is Script {
    uint256 internal constant THRESHOLD = 1;
    uint256 internal constant MINT_AMOUNT = 1_000_000 ether;

    /// @dev Anvil account #0 (solo fallback local).
    uint256 internal constant ANVIL_PK_0 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    /// @dev Anvil account #1 (relayer demo local).
    uint256 internal constant ANVIL_PK_1 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    /**
     * @notice Despliega el stack. En testnet: `PRIVATE_KEY` + `RELAYER_ADDRESS` en `.env`.
     */
    function run() external {
        uint256 pk = vm.envOr("PRIVATE_KEY", ANVIL_PK_0);
        address deployer = vm.addr(pk);

        // Testnet: forzás el relayer. Local: Anvil #1 si no hay env.
        address relayer = vm.envOr("RELAYER_ADDRESS", vm.addr(ANVIL_PK_1));
        if (relayer == address(0)) {
            revert("RELAYER_ADDRESS zero");
        }

        uint256 threshold = vm.envOr("RELAYER_THRESHOLD", THRESHOLD);
        if (threshold == 0) {
            revert("threshold zero");
        }

        vm.startBroadcast(pk);

        MockERC20 underlying = new MockERC20("Underlying", "UND");
        underlying.mint(deployer, MINT_AMOUNT);

        Bridge bridge = new Bridge(relayer, threshold);
        MessageRelay relay = new MessageRelay(relayer, threshold);

        vm.stopBroadcast();

        console2.log("Deployer", deployer);
        console2.log("Relayer", relayer);
        console2.log("Underlying", address(underlying));
        console2.log("Bridge", address(bridge));
        console2.log("BridgeToken", bridge.bridgeToken());
        console2.log("MessageRelay", address(relay));
        console2.log("Threshold", threshold);
        console2.log("ChainId", block.chainid);
    }
}

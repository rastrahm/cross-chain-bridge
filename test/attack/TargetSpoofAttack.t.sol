// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Bridge} from "../../src/Bridge.sol";
import {BridgeToken} from "../../src/BridgeToken.sol";
import {IBridge, BridgeMessage} from "../../src/interfaces/IBridge.sol";
import {IBridgeToken} from "../../src/interfaces/IBridgeToken.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {EIP712BridgeHelper} from "../helpers/EIP712BridgeHelper.sol";

/**
 * @title TargetSpoofAttackTest
 * @notice SWC-121/122: spoof de `target`, mint directo y firma de payload alterado.
 */
contract TargetSpoofAttackTest is EIP712BridgeHelper {
    uint256 internal constant RELAYER_PK = 0xA11CE;
    uint256 internal constant ATTACKER_PK = 0xBAD;
    uint256 internal constant SOURCE_CHAIN_ID = 1;
    uint256 internal constant DEST_CHAIN_ID = 31_337;
    uint256 internal constant AMOUNT = 100 ether;

    address internal relayer;
    address internal attacker;
    address internal user;
    address internal recipient;

    MockERC20 internal underlying;
    Bridge internal bridge;
    Bridge internal otherBridge;
    BridgeToken internal bridgeToken;

    function setUp() public {
        relayer = vm.addr(RELAYER_PK);
        attacker = vm.addr(ATTACKER_PK);
        user = makeAddr("user");
        recipient = makeAddr("recipient");

        underlying = new MockERC20("Underlying", "UND");
        bridge = new Bridge(relayer, 1);
        otherBridge = new Bridge(relayer, 1);
        bridgeToken = BridgeToken(bridge.bridgeToken());

        underlying.mint(user, 1_000_000 ether);
        vm.chainId(SOURCE_CHAIN_ID);
    }

    /**
     * @notice SWC-121: `target` de otro bridge → `InvalidTarget`.
     */
    function test_Attack_spoofTarget_revertsInvalidTarget() public {
        vm.startPrank(user);
        underlying.approve(address(bridge), AMOUNT);
        bridge.deposit(address(underlying), AMOUNT, DEST_CHAIN_ID, recipient);
        vm.stopPrank();

        vm.chainId(DEST_CHAIN_ID);

        BridgeMessage memory message = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: 0,
            target: address(otherBridge),
            recipient: recipient,
            token: address(bridgeToken),
            amount: AMOUNT
        });

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signBridgeMessage(RELAYER_PK, address(bridge), message);

        vm.expectRevert(IBridge.InvalidTarget.selector);
        bridge.release(message, signatures);
    }

    /**
     * @notice SWC-122: atacante no relayer no puede autorizar el release.
     */
    function test_Attack_attackerSignature_revertsInvalidSignature() public {
        vm.startPrank(user);
        underlying.approve(address(bridge), AMOUNT);
        bridge.deposit(address(underlying), AMOUNT, DEST_CHAIN_ID, recipient);
        vm.stopPrank();

        vm.chainId(DEST_CHAIN_ID);

        BridgeMessage memory message = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: 0,
            target: address(bridge),
            recipient: attacker,
            token: address(bridgeToken),
            amount: AMOUNT
        });

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signBridgeMessage(ATTACKER_PK, address(bridge), message);

        vm.expectRevert(IBridge.InvalidSignature.selector);
        bridge.release(message, signatures);

        assertEq(bridgeToken.balanceOf(attacker), 0);
    }

    /**
     * @notice Solo el bridge puede `mint` el wrapped (superficie BridgeToken).
     */
    function test_Attack_directMint_revertsOnlyBridge() public {
        vm.prank(attacker);
        vm.expectRevert(IBridgeToken.OnlyBridge.selector);
        bridgeToken.mint(attacker, AMOUNT);
    }

    /**
     * @notice Solo el bridge puede `burn` el wrapped.
     */
    function test_Attack_directBurn_revertsOnlyBridge() public {
        // Acuñar vía release legítimo primero.
        vm.startPrank(user);
        underlying.approve(address(bridge), AMOUNT);
        bridge.deposit(address(underlying), AMOUNT, DEST_CHAIN_ID, recipient);
        vm.stopPrank();

        vm.chainId(DEST_CHAIN_ID);
        BridgeMessage memory message = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: 0,
            target: address(bridge),
            recipient: recipient,
            token: address(bridgeToken),
            amount: AMOUNT
        });
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signBridgeMessage(RELAYER_PK, address(bridge), message);
        bridge.release(message, signatures);

        vm.prank(attacker);
        vm.expectRevert(IBridgeToken.OnlyBridge.selector);
        bridgeToken.burn(recipient, AMOUNT);
    }
}

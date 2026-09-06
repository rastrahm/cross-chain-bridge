// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Bridge} from "../../src/Bridge.sol";
import {BridgeToken} from "../../src/BridgeToken.sol";
import {MessageRelay} from "../../src/MessageRelay.sol";
import {BridgeMessage} from "../../src/interfaces/IBridge.sol";
import {RelayMessage} from "../../src/interfaces/IMessageRelay.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockRelayTarget} from "../../src/mocks/MockRelayTarget.sol";
import {EIP712BridgeHelper} from "../helpers/EIP712BridgeHelper.sol";

/**
 * @title BridgeGasTest
 * @notice Baseline de gas para `forge snapshot` y `doc/GAS.md` (Fase 8).
 */
contract BridgeGasTest is EIP712BridgeHelper {
    uint256 internal constant RELAYER_PK = 0xA11CE;
    uint256 internal constant SOURCE_CHAIN_ID = 1;
    uint256 internal constant DEST_CHAIN_ID = 31_337;
    uint256 internal constant AMOUNT = 100 ether;

    address internal relayer;
    address internal user;
    address internal recipient;

    MockERC20 internal underlying;
    Bridge internal bridge;
    BridgeToken internal bridgeToken;
    MessageRelay internal relay;
    MockRelayTarget internal relayTarget;

    function setUp() public {
        relayer = vm.addr(RELAYER_PK);
        user = makeAddr("user");
        recipient = makeAddr("recipient");

        underlying = new MockERC20("Underlying", "UND");
        bridge = new Bridge(relayer, 1);
        bridgeToken = BridgeToken(bridge.bridgeToken());
        relay = new MessageRelay(relayer, 1);
        relayTarget = new MockRelayTarget();

        underlying.mint(user, 1_000_000 ether);

        vm.startPrank(user);
        underlying.approve(address(bridge), type(uint256).max);
        vm.stopPrank();

        vm.chainId(SOURCE_CHAIN_ID);
    }

    function testGas_deposit() public {
        vm.prank(user);
        bridge.deposit(address(underlying), AMOUNT, DEST_CHAIN_ID, recipient);
    }

    function testGas_release_mint() public {
        vm.prank(user);
        bridge.deposit(address(underlying), AMOUNT, DEST_CHAIN_ID, recipient);

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
    }

    function testGas_release_secondNonce_warmBitmap() public {
        vm.startPrank(user);
        bridge.deposit(address(underlying), AMOUNT, DEST_CHAIN_ID, recipient);
        bridge.deposit(address(underlying), AMOUNT, DEST_CHAIN_ID, recipient);
        vm.stopPrank();

        vm.chainId(DEST_CHAIN_ID);

        BridgeMessage memory msg0 = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: 0,
            target: address(bridge),
            recipient: recipient,
            token: address(bridgeToken),
            amount: AMOUNT
        });
        BridgeMessage memory msg1 = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: 1,
            target: address(bridge),
            recipient: recipient,
            token: address(bridgeToken),
            amount: AMOUNT
        });

        bytes[] memory sig0 = new bytes[](1);
        sig0[0] = _signBridgeMessage(RELAYER_PK, address(bridge), msg0);
        bytes[] memory sig1 = new bytes[](1);
        sig1[0] = _signBridgeMessage(RELAYER_PK, address(bridge), msg1);

        bridge.release(msg0, sig0);
        bridge.release(msg1, sig1);
    }

    function testGas_execute_relay() public {
        vm.chainId(DEST_CHAIN_ID);
        RelayMessage memory message = RelayMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: 0,
            target: address(relayTarget),
            payload: abi.encodeCall(MockRelayTarget.setValue, (42))
        });
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signRelayMessage(RELAYER_PK, address(relay), message);
        relay.execute(message, signatures);
    }

    function testGas_burn() public {
        // Prepara wrapped en recipient vía lock+mint.
        vm.prank(user);
        bridge.deposit(address(underlying), AMOUNT, DEST_CHAIN_ID, recipient);

        vm.chainId(DEST_CHAIN_ID);
        BridgeMessage memory mintMsg = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: 0,
            target: address(bridge),
            recipient: recipient,
            token: address(bridgeToken),
            amount: AMOUNT
        });
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = _signBridgeMessage(RELAYER_PK, address(bridge), mintMsg);
        bridge.release(mintMsg, sigs);

        vm.prank(recipient);
        bridge.burn(AMOUNT, SOURCE_CHAIN_ID, user);
    }

    function testGas_processedNonces_view() public view {
        bridge.processedNonces(SOURCE_CHAIN_ID, 0);
    }
}

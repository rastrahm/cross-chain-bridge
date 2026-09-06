// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Bridge} from "../src/Bridge.sol";
import {BridgeToken} from "../src/BridgeToken.sol";
import {IBridge, BridgeMessage} from "../src/interfaces/IBridge.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {EIP712BridgeHelper} from "./helpers/EIP712BridgeHelper.sol";

/**
 * @title InvalidSignatureTest
 * @notice Fase 5: firmante incorrecto, payload alterado y firmas v/r/s malformadas.
 */
contract InvalidSignatureTest is EIP712BridgeHelper {
    uint256 internal constant RELAYER_PK = 0xA11CE;
    uint256 internal constant ATTACKER_PK = 0xB0B;
    uint256 internal constant SOURCE_CHAIN_ID = 1;
    uint256 internal constant DEST_CHAIN_ID = 31_337;
    uint256 internal constant AMOUNT = 100 ether;

    address internal relayer;
    address internal attacker;
    address internal user;
    address internal recipient;

    MockERC20 internal underlying;
    Bridge internal bridge;
    BridgeToken internal bridgeToken;

    function setUp() public {
        relayer = vm.addr(RELAYER_PK);
        attacker = vm.addr(ATTACKER_PK);
        user = makeAddr("user");
        recipient = makeAddr("recipient");

        underlying = new MockERC20("Underlying", "UND");
        bridge = new Bridge(relayer, 1);
        bridgeToken = BridgeToken(bridge.bridgeToken());

        underlying.mint(user, 1_000_000 ether);
        vm.chainId(SOURCE_CHAIN_ID);
    }

    /**
     * @notice Firma de una EOA que no es relayer → `InvalidSignature`.
     */
    function test_release_revertsWrongSigner() public {
        BridgeMessage memory message = _depositAndBuildMessage();

        vm.chainId(DEST_CHAIN_ID);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signBridgeMessage(ATTACKER_PK, address(bridge), message);

        vm.expectRevert(IBridge.InvalidSignature.selector);
        bridge.release(message, signatures);

        assertEq(bridgeToken.balanceOf(recipient), 0);
        assertFalse(bridge.processedNonces(SOURCE_CHAIN_ID, 0));
    }

    /**
     * @notice Array de firmas vacío → `InvalidSignature`.
     */
    function test_release_revertsEmptySignatures() public {
        BridgeMessage memory message = _depositAndBuildMessage();

        vm.chainId(DEST_CHAIN_ID);
        bytes[] memory signatures = new bytes[](0);

        vm.expectRevert(IBridge.InvalidSignature.selector);
        bridge.release(message, signatures);
    }

    /**
     * @notice `amount` alterado tras firmar → digest distinto → `InvalidSignature`.
     */
    function test_release_revertsTamperedAmount() public {
        BridgeMessage memory message = _depositAndBuildMessage();

        vm.chainId(DEST_CHAIN_ID);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signBridgeMessage(RELAYER_PK, address(bridge), message);

        message.amount = AMOUNT + 1 ether;

        vm.expectRevert(IBridge.InvalidSignature.selector);
        bridge.release(message, signatures);
    }

    /**
     * @notice `recipient` alterado tras firmar → `InvalidSignature`.
     */
    function test_release_revertsTamperedRecipient() public {
        BridgeMessage memory message = _depositAndBuildMessage();

        vm.chainId(DEST_CHAIN_ID);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signBridgeMessage(RELAYER_PK, address(bridge), message);

        message.recipient = makeAddr("attackerRecipient");

        vm.expectRevert(IBridge.InvalidSignature.selector);
        bridge.release(message, signatures);
    }

    /**
     * @notice `nonce` alterado tras firmar → `InvalidSignature`.
     */
    function test_release_revertsTamperedNonce() public {
        BridgeMessage memory message = _depositAndBuildMessage();

        vm.chainId(DEST_CHAIN_ID);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signBridgeMessage(RELAYER_PK, address(bridge), message);

        message.nonce = 99;

        vm.expectRevert(IBridge.InvalidSignature.selector);
        bridge.release(message, signatures);
    }

    /**
     * @notice Firma con longitud distinta de 65 bytes → `InvalidSignature`.
     */
    function test_release_revertsMalformedSignatureLength() public {
        BridgeMessage memory message = _depositAndBuildMessage();

        vm.chainId(DEST_CHAIN_ID);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"deadbeef"; // != 65 bytes

        vm.expectRevert(IBridge.InvalidSignature.selector);
        bridge.release(message, signatures);
    }

    /**
     * @notice `v` inválido (p.ej. 0) en firma de 65 bytes → `InvalidSignature`.
     */
    function test_release_revertsMalformedV() public {
        BridgeMessage memory message = _depositAndBuildMessage();

        vm.chainId(DEST_CHAIN_ID);
        bytes memory sig = _signBridgeMessage(RELAYER_PK, address(bridge), message);
        // Forzar v = 0 (último byte).
        sig[64] = 0;

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = sig;

        vm.expectRevert(IBridge.InvalidSignature.selector);
        bridge.release(message, signatures);
    }

    /**
     * @notice Umbral 2 con una sola firma válida → `ThresholdNotMet`.
     */
    function test_release_revertsThresholdNotMet() public {
        bridge.setRelayerThreshold(2);

        BridgeMessage memory message = _depositAndBuildMessage();

        vm.chainId(DEST_CHAIN_ID);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signBridgeMessage(RELAYER_PK, address(bridge), message);

        vm.expectRevert(IBridge.ThresholdNotMet.selector);
        bridge.release(message, signatures);
    }

    /**
     * @notice Dos copias de la misma firma de relayer no cuentan como umbral 2.
     */
    function test_release_revertsDuplicateRelayerSignatures() public {
        bridge.setRelayerThreshold(2);

        BridgeMessage memory message = _depositAndBuildMessage();

        vm.chainId(DEST_CHAIN_ID);
        bytes memory sig = _signBridgeMessage(RELAYER_PK, address(bridge), message);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = sig;
        signatures[1] = sig;

        // Una firma válida única + duplicado ignorado → validCount=1 < 2.
        // Como hay al menos una válida, revierte ThresholdNotMet (no InvalidSignature).
        vm.expectRevert(IBridge.ThresholdNotMet.selector);
        bridge.release(message, signatures);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /**
     * @notice Deposit en origen y arma el `BridgeMessage` (sin firmar).
     */
    function _depositAndBuildMessage() internal returns (BridgeMessage memory message) {
        vm.startPrank(user);
        underlying.approve(address(bridge), AMOUNT);
        bridge.deposit(address(underlying), AMOUNT, DEST_CHAIN_ID, recipient);
        vm.stopPrank();

        message = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: 0,
            target: address(bridge),
            recipient: recipient,
            token: address(bridgeToken),
            amount: AMOUNT
        });
    }
}

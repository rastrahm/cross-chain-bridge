// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Bridge} from "../src/Bridge.sol";
import {BridgeToken} from "../src/BridgeToken.sol";
import {IBridge, BridgeMessage} from "../src/interfaces/IBridge.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {EIP712BridgeHelper} from "./helpers/EIP712BridgeHelper.sol";

/**
 * @title ReplayTest
 * @notice Fase 4: anti-replay — reuso de nonce y `destinationChainId` incorrecto.
 */
contract ReplayTest is EIP712BridgeHelper {
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

    function setUp() public {
        relayer = vm.addr(RELAYER_PK);
        user = makeAddr("user");
        recipient = makeAddr("recipient");

        underlying = new MockERC20("Underlying", "UND");
        bridge = new Bridge(relayer, 1);
        bridgeToken = BridgeToken(bridge.bridgeToken());

        underlying.mint(user, 1_000_000 ether);
        vm.chainId(SOURCE_CHAIN_ID);
    }

    /**
     * @notice Segunda `release` con el mismo `(sourceChainId, nonce)` revierte `NonceAlreadyUsed`.
     */
    function test_release_revertsNonceAlreadyUsed() public {
        (BridgeMessage memory message, bytes[] memory signatures) = _depositAndSignRelease();

        vm.chainId(DEST_CHAIN_ID);
        bridge.release(message, signatures);

        assertTrue(bridge.processedNonces(SOURCE_CHAIN_ID, message.nonce));
        assertEq(bridgeToken.balanceOf(recipient), AMOUNT);

        vm.expectRevert(IBridge.NonceAlreadyUsed.selector);
        bridge.release(message, signatures);

        // No doble mint.
        assertEq(bridgeToken.balanceOf(recipient), AMOUNT);
    }

    /**
     * @notice `destinationChainId` distinto de `block.chainid` revierte `InvalidChainId`.
     */
    function test_release_revertsInvalidChainId() public {
        (BridgeMessage memory message, bytes[] memory signatures) = _depositAndSignRelease();

        // Mensaje apunta a DEST_CHAIN_ID pero ejecutamos en otra cadena.
        vm.chainId(999);

        vm.expectRevert(IBridge.InvalidChainId.selector);
        bridge.release(message, signatures);

        assertFalse(bridge.processedNonces(SOURCE_CHAIN_ID, message.nonce));
        assertEq(bridgeToken.balanceOf(recipient), 0);
    }

    /**
     * @notice Reusar la firma cambiando solo `destinationChainId` al chain actual falla la firma.
     * @dev Guarda EIP-712: el digest incluye `destinationChainId`; la firma original no sirve.
     */
    function test_release_revertsWhenDestinationChainIdTampered() public {
        (BridgeMessage memory message, bytes[] memory signatures) = _depositAndSignRelease();

        uint256 attackerChain = 999;
        vm.chainId(attackerChain);

        message.destinationChainId = attackerChain;

        // Firma sigue siendo la del mensaje original (dest 31337) → umbral no se cumple / firma inválida.
        vm.expectRevert(IBridge.InvalidSignature.selector);
        bridge.release(message, signatures);

        assertFalse(bridge.processedNonces(SOURCE_CHAIN_ID, message.nonce));
        assertEq(bridgeToken.balanceOf(recipient), 0);
    }

    /**
     * @notice `message.target` distinto del bridge destino revierte `InvalidTarget`.
     */
    function test_release_revertsInvalidTarget() public {
        (BridgeMessage memory message, bytes[] memory signatures) = _depositAndSignRelease();

        vm.chainId(DEST_CHAIN_ID);
        message.target = makeAddr("fakeBridge");

        // target check ocurre antes de verificar firmas.
        vm.expectRevert(IBridge.InvalidTarget.selector);
        bridge.release(message, signatures);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /**
     * @notice Deposit en origen y firma un `BridgeMessage` válido para `DEST_CHAIN_ID`.
     * @return message Payload tipado.
     * @return signatures Firma del relayer (1-of-1).
     */
    function _depositAndSignRelease()
        internal
        returns (BridgeMessage memory message, bytes[] memory signatures)
    {
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

        // Firmar con domain de destino (chainId del mensaje).
        vm.chainId(DEST_CHAIN_ID);
        signatures = new bytes[](1);
        signatures[0] = _signBridgeMessage(RELAYER_PK, address(bridge), message);
        // Volver a origen no es necesario; cada test fija el chainId de ejecución.
    }
}

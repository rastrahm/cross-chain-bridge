// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {BridgeMessage} from "../src/interfaces/IBridge.sol";
import {RelayMessage} from "../src/interfaces/IMessageRelay.sol";
import {BridgeHash} from "../src/libraries/BridgeHash.sol";

/**
 * @title BridgeHashTest
 * @notice Unit tests del `structHash` EIP-712 (fase 1 — librería ya disponible).
 */
contract BridgeHashTest is Test {
    bytes32 internal constant BRIDGE_MESSAGE_TYPEHASH = keccak256(
        "BridgeMessage(uint256 sourceChainId,uint256 destinationChainId,uint256 nonce,address target,address recipient,address token,uint256 amount)"
    );

    bytes32 internal constant RELAY_MESSAGE_TYPEHASH = keccak256(
        "RelayMessage(uint256 sourceChainId,uint256 destinationChainId,uint256 nonce,address target,bytes payload)"
    );

    /**
     * @notice `hash(BridgeMessage)` coincide con el encoding canónico EIP-712 de todos los campos anti-replay.
     */
    function test_hashBridgeMessage_encodesAllAntiReplayFields() public pure {
        BridgeMessage memory message = BridgeMessage({
            sourceChainId: 1,
            destinationChainId: 31_337,
            nonce: 7,
            target: address(0xBEEF),
            recipient: address(0xCAFE),
            token: address(0x1001),
            amount: 100 ether
        });

        bytes32 expected = keccak256(
            abi.encode(
                BRIDGE_MESSAGE_TYPEHASH,
                message.sourceChainId,
                message.destinationChainId,
                message.nonce,
                message.target,
                message.recipient,
                message.token,
                message.amount
            )
        );

        assertEq(BridgeHash.hashMemory(message), expected);
    }

    /**
     * @notice Cambiar `nonce` (u otro campo) altera el structHash.
     */
    function test_hashBridgeMessage_changesWhenNonceChanges() public pure {
        BridgeMessage memory a = BridgeMessage({
            sourceChainId: 1,
            destinationChainId: 31_337,
            nonce: 1,
            target: address(0xBEEF),
            recipient: address(0xCAFE),
            token: address(0x1001),
            amount: 1 ether
        });
        BridgeMessage memory b = BridgeMessage({
            sourceChainId: 1,
            destinationChainId: 31_337,
            nonce: 2,
            target: address(0xBEEF),
            recipient: address(0xCAFE),
            token: address(0x1001),
            amount: 1 ether
        });

        assertTrue(BridgeHash.hashMemory(a) != BridgeHash.hashMemory(b));
    }

    /**
     * @notice Cambiar `destinationChainId` altera el structHash (guarda cross-chain).
     */
    function test_hashBridgeMessage_changesWhenDestinationChainIdChanges() public pure {
        BridgeMessage memory a = BridgeMessage({
            sourceChainId: 1,
            destinationChainId: 31_337,
            nonce: 1,
            target: address(0xBEEF),
            recipient: address(0xCAFE),
            token: address(0x1001),
            amount: 1 ether
        });
        BridgeMessage memory b = BridgeMessage({
            sourceChainId: 1,
            destinationChainId: 31_338,
            nonce: 1,
            target: address(0xBEEF),
            recipient: address(0xCAFE),
            token: address(0x1001),
            amount: 1 ether
        });

        assertTrue(BridgeHash.hashMemory(a) != BridgeHash.hashMemory(b));
    }

    /**
     * @notice `hash(RelayMessage)` hashea `payload` como `bytes` (keccak256 del contenido).
     */
    function test_hashRelayMessage_hashesPayloadBytes() public pure {
        RelayMessage memory message = RelayMessage({
            sourceChainId: 1,
            destinationChainId: 31_337,
            nonce: 3,
            target: address(0xBEEF),
            payload: hex"deadbeef"
        });

        bytes32 expected = keccak256(
            abi.encode(
                RELAY_MESSAGE_TYPEHASH,
                message.sourceChainId,
                message.destinationChainId,
                message.nonce,
                message.target,
                keccak256(message.payload)
            )
        );

        assertEq(BridgeHash.hashMemory(message), expected);
    }
}

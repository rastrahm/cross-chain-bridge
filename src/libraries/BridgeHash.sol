// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BridgeMessage} from "../interfaces/IBridge.sol";
import {RelayMessage} from "../interfaces/IMessageRelay.sol";

/**
 * @title BridgeHash
 * @notice TYPEHASH y `structHash` EIP-712 para mensajes del puente y del relé.
 * @dev Overloads `calldata` evitan copia a memory en `release` / `execute`.
 */
library BridgeHash {
    /// @dev keccak256("BridgeMessage(uint256 sourceChainId,uint256 destinationChainId,uint256 nonce,address target,address recipient,address token,uint256 amount)")
    bytes32 internal constant BRIDGE_MESSAGE_TYPEHASH = keccak256(
        "BridgeMessage(uint256 sourceChainId,uint256 destinationChainId,uint256 nonce,address target,address recipient,address token,uint256 amount)"
    );

    /// @dev keccak256("RelayMessage(uint256 sourceChainId,uint256 destinationChainId,uint256 nonce,address target,bytes payload)")
    bytes32 internal constant RELAY_MESSAGE_TYPEHASH = keccak256(
        "RelayMessage(uint256 sourceChainId,uint256 destinationChainId,uint256 nonce,address target,bytes payload)"
    );

    /**
     * @notice Hash del struct `BridgeMessage` desde calldata (hot path `release`).
     */
    function hash(BridgeMessage calldata message) internal pure returns (bytes32 digest) {
        return keccak256(
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
    }

    /**
     * @notice Hash del struct `BridgeMessage` desde memory (tests / helpers).
     */
    function hashMemory(BridgeMessage memory message) internal pure returns (bytes32) {
        return keccak256(
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
    }

    /**
     * @notice Hash del struct `RelayMessage` desde calldata (hot path `execute`).
     */
    function hash(RelayMessage calldata message) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                RELAY_MESSAGE_TYPEHASH,
                message.sourceChainId,
                message.destinationChainId,
                message.nonce,
                message.target,
                keccak256(message.payload)
            )
        );
    }

    /**
     * @notice Hash del struct `RelayMessage` desde memory (tests / helpers).
     */
    function hashMemory(RelayMessage memory message) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                RELAY_MESSAGE_TYPEHASH,
                message.sourceChainId,
                message.destinationChainId,
                message.nonce,
                message.target,
                keccak256(message.payload)
            )
        );
    }
}

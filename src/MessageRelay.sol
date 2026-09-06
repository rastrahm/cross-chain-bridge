// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IMessageRelay, RelayMessage} from "./interfaces/IMessageRelay.sol";
import {BridgeHash} from "./libraries/BridgeHash.sol";
import {NonceBitmap} from "./libraries/NonceBitmap.sol";
import {RelayerSig} from "./libraries/RelayerSig.sol";

/**
 * @title MessageRelay
 * @notice Relé cross-chain de mensajes genéricos con umbral de firmas EIP-712.
 * @dev Bitmap de nonces + `RelayerSig` fast-path. Dominio: `("MessageRelay", "1")`.
 */
contract MessageRelay is IMessageRelay, EIP712, ReentrancyGuard, Ownable2Step {
    using NonceBitmap for mapping(uint256 => mapping(uint256 => uint256));

    /// @dev sourceChainId => wordIndex => bitmap.
    mapping(uint256 sourceChainId => mapping(uint256 word => uint256 bits)) private _processedBitmap;

    /// @inheritdoc IMessageRelay
    mapping(address account => bool approved) public override isRelayer;

    /// @inheritdoc IMessageRelay
    uint256 public override relayerThreshold;

    /**
     * @notice Registra el relayer inicial y el umbral.
     * @param initialRelayer Primera dirección autorizada a firmar.
     * @param threshold_ Mínimo de firmas válidas (≥ 1).
     */
    constructor(address initialRelayer, uint256 threshold_) EIP712("MessageRelay", "1") Ownable(msg.sender) {
        if (initialRelayer == address(0)) {
            revert ZeroAddress();
        }
        if (threshold_ == 0) {
            revert ThresholdNotMet();
        }

        isRelayer[initialRelayer] = true;
        relayerThreshold = threshold_;

        emit RelayerUpdated(initialRelayer, true);
        emit RelayerThresholdUpdated(threshold_);
    }

    /**
     * @inheritdoc IMessageRelay
     */
    function processedNonces(uint256 sourceChainId, uint256 nonce) external view override returns (bool) {
        return _processedBitmap.isUsed(sourceChainId, nonce);
    }

    /**
     * @inheritdoc IMessageRelay
     * @dev CEI: checks → marcar nonce → `target.call(payload)` → evento.
     */
    function execute(RelayMessage calldata message, bytes[] calldata signatures) external override nonReentrant {
        if (message.destinationChainId != block.chainid) {
            revert InvalidChainId();
        }
        if (message.target == address(0)) {
            revert ZeroAddress();
        }
        if (_processedBitmap.isUsed(message.sourceChainId, message.nonce)) {
            revert NonceAlreadyUsed();
        }

        RelayerSig.verify(isRelayer, relayerThreshold, _hashTypedDataV4(BridgeHash.hash(message)), signatures);

        _processedBitmap.markUsed(message.sourceChainId, message.nonce);

        (bool success,) = message.target.call(message.payload);
        if (!success) {
            revert ExecutionFailed();
        }

        emit MessageExecuted(message.sourceChainId, message.nonce, message.target);
    }

    /**
     * @inheritdoc IMessageRelay
     */
    function setRelayer(address relayer, bool approved) external override onlyOwner {
        if (relayer == address(0)) {
            revert ZeroAddress();
        }
        isRelayer[relayer] = approved;
        emit RelayerUpdated(relayer, approved);
    }

    /**
     * @inheritdoc IMessageRelay
     */
    function setRelayerThreshold(uint256 newThreshold) external override onlyOwner {
        if (newThreshold == 0) {
            revert ThresholdNotMet();
        }
        relayerThreshold = newThreshold;
        emit RelayerThresholdUpdated(newThreshold);
    }
}

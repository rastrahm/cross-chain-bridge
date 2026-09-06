// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IMessageRelay, RelayMessage} from "./interfaces/IMessageRelay.sol";
import {BridgeHash} from "./libraries/BridgeHash.sol";

/**
 * @title MessageRelay
 * @notice Relé cross-chain de mensajes genéricos con umbral de firmas EIP-712.
 * @dev Marca nonce antes del `call` (CEI). Dominio: `("MessageRelay", "1")`.
 */
contract MessageRelay is IMessageRelay, EIP712, ReentrancyGuard, Ownable2Step {
    /// @inheritdoc IMessageRelay
    mapping(uint256 sourceChainId => mapping(uint256 nonce => bool used)) public override processedNonces;

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
     * @dev CEI: checks → marcar nonce → `target.call(payload)` → evento.
     */
    function execute(RelayMessage calldata message, bytes[] calldata signatures) external override nonReentrant {
        if (message.destinationChainId != block.chainid) {
            revert InvalidChainId();
        }
        if (message.target == address(0)) {
            revert ZeroAddress();
        }
        if (processedNonces[message.sourceChainId][message.nonce]) {
            revert NonceAlreadyUsed();
        }

        bytes32 digest = _hashTypedDataV4(BridgeHash.hash(message));
        _verifyRelayerSignatures(digest, signatures);

        processedNonces[message.sourceChainId][message.nonce] = true;

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

    /**
     * @notice Exige al menos `relayerThreshold` firmas válidas de relayers distintos.
     */
    function _verifyRelayerSignatures(bytes32 digest, bytes[] calldata signatures) internal view {
        uint256 threshold = relayerThreshold;
        address[] memory seen = new address[](signatures.length);
        uint256 validCount;

        for (uint256 i = 0; i < signatures.length; ++i) {
            (address signer, ECDSA.RecoverError err,) = ECDSA.tryRecover(digest, signatures[i]);
            if (err != ECDSA.RecoverError.NoError || signer == address(0) || !isRelayer[signer]) {
                continue;
            }
            if (_alreadySeen(seen, validCount, signer)) {
                continue;
            }
            seen[validCount] = signer;
            unchecked {
                ++validCount;
            }
            if (validCount >= threshold) {
                return;
            }
        }

        if (validCount == 0) {
            revert InvalidSignature();
        }
        revert ThresholdNotMet();
    }

    function _alreadySeen(address[] memory seen, uint256 length, address signer) private pure returns (bool) {
        for (uint256 j = 0; j < length; ++j) {
            if (seen[j] == signer) {
                return true;
            }
        }
        return false;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {BridgeToken} from "./BridgeToken.sol";
import {IBridge, BridgeMessage} from "./interfaces/IBridge.sol";
import {IBridgeToken} from "./interfaces/IBridgeToken.sol";
import {BridgeHash} from "./libraries/BridgeHash.sol";

/**
 * @title Bridge
 * @notice Puente lock/burn (origen) y mint/unlock (destino) con pruebas EIP-712.
 * @dev `deposit` (lock) + `release` (mint/unlock) con umbral de relayers.
 *      `burn` stub hasta el flujo burn→unlock. Dominio EIP-712: `("CrossChainBridge", "1")`.
 */
contract Bridge is IBridge, EIP712, ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;

    /// @inheritdoc IBridge
    address public immutable override bridgeToken;

    /// @inheritdoc IBridge
    mapping(uint256 sourceChainId => mapping(uint256 nonce => bool used)) public override processedNonces;

    /// @inheritdoc IBridge
    mapping(address account => bool approved) public override isRelayer;

    /// @inheritdoc IBridge
    uint256 public override relayerThreshold;

    /// @inheritdoc IBridge
    uint256 public override nextDepositNonce;

    /**
     * @notice Despliega `BridgeToken`, registra el relayer inicial y el umbral.
     * @param initialRelayer Primera dirección autorizada a firmar releases.
     * @param threshold_ Mínimo de firmas válidas (≥ 1).
     */
    constructor(address initialRelayer, uint256 threshold_)
        EIP712("CrossChainBridge", "1")
        Ownable(msg.sender)
    {
        if (initialRelayer == address(0)) {
            revert ZeroAddress();
        }
        if (threshold_ == 0) {
            revert ThresholdNotMet();
        }

        bridgeToken = address(new BridgeToken("Bridge Token", "bTKN", address(this)));
        isRelayer[initialRelayer] = true;
        relayerThreshold = threshold_;

        emit RelayerUpdated(initialRelayer, true);
        emit RelayerThresholdUpdated(threshold_);
    }

    // -------------------------------------------------------------------------
    // Origen — lock
    // -------------------------------------------------------------------------

    /**
     * @inheritdoc IBridge
     * @dev CEI: asigna nonce + emite evento, luego `safeTransferFrom`.
     */
    function deposit(address token, uint256 amount, uint256 destinationChainId, address recipient)
        external
        override
        nonReentrant
    {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (token == address(0) || recipient == address(0)) {
            revert ZeroAddress();
        }
        if (destinationChainId == block.chainid) {
            revert InvalidChainId();
        }

        uint256 nonce = nextDepositNonce;
        unchecked {
            nextDepositNonce = nonce + 1;
        }

        emit Deposit(msg.sender, token, amount, destinationChainId, recipient, nonce);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @inheritdoc IBridge
     * @dev Stub: burn→unlock se completa en fases posteriores.
     */
    function burn(uint256, uint256, address) external pure override {
        revert ExecutionFailed();
    }

    // -------------------------------------------------------------------------
    // Destino — release
    // -------------------------------------------------------------------------

    /**
     * @inheritdoc IBridge
     * @dev CEI: checks (chain, target, nonce, firmas) → marcar nonce → mint/unlock → evento.
     */
    function release(BridgeMessage calldata message, bytes[] calldata signatures) external override nonReentrant {
        if (message.destinationChainId != block.chainid) {
            revert InvalidChainId();
        }
        if (message.target != address(this)) {
            revert InvalidTarget();
        }
        if (message.amount == 0) {
            revert ZeroAmount();
        }
        if (message.recipient == address(0) || message.token == address(0)) {
            revert ZeroAddress();
        }
        if (processedNonces[message.sourceChainId][message.nonce]) {
            revert NonceAlreadyUsed();
        }

        bytes32 digest = _hashTypedDataV4(BridgeHash.hash(message));
        _verifyRelayerSignatures(digest, signatures);

        processedNonces[message.sourceChainId][message.nonce] = true;

        _mintOrUnlock(message.token, message.recipient, message.amount);

        emit Released(message.sourceChainId, message.nonce, message.recipient, message.amount);
    }

    // -------------------------------------------------------------------------
    // Admin
    // -------------------------------------------------------------------------

    /**
     * @inheritdoc IBridge
     */
    function setRelayer(address relayer, bool approved) external override onlyOwner {
        if (relayer == address(0)) {
            revert ZeroAddress();
        }
        isRelayer[relayer] = approved;
        emit RelayerUpdated(relayer, approved);
    }

    /**
     * @inheritdoc IBridge
     */
    function setRelayerThreshold(uint256 newThreshold) external override onlyOwner {
        if (newThreshold == 0) {
            revert ThresholdNotMet();
        }
        relayerThreshold = newThreshold;
        emit RelayerThresholdUpdated(newThreshold);
    }

    // -------------------------------------------------------------------------
    // Internals
    // -------------------------------------------------------------------------

    /**
     * @notice Exige al menos `relayerThreshold` firmas válidas de relayers distintos.
     * @dev Firmas inválidas o de no-relayers se ignoran; duplicados no cuentan dos veces.
     * @param digest Hash EIP-712 (`_hashTypedDataV4`).
     * @param signatures Lista de firmas `r || s || v` (65 bytes).
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

    /**
     * @notice Mint de wrapped si `token == bridgeToken`; si no, unlock ERC-20 custodiado.
     * @param token Token a liberar en destino.
     * @param recipient Destinatario.
     * @param amount Cantidad.
     */
    function _mintOrUnlock(address token, address recipient, uint256 amount) internal {
        if (token == bridgeToken) {
            IBridgeToken(bridgeToken).mint(recipient, amount);
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }
    }

    /**
     * @notice Comprueba si `signer` ya fue contado en `seen[0..length)`.
     */
    function _alreadySeen(address[] memory seen, uint256 length, address signer) private pure returns (bool) {
        for (uint256 j = 0; j < length; ++j) {
            if (seen[j] == signer) {
                return true;
            }
        }
        return false;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {BridgeToken} from "./BridgeToken.sol";
import {IBridge, BridgeMessage} from "./interfaces/IBridge.sol";
import {BridgeHash} from "./libraries/BridgeHash.sol";
import {NonceBitmap} from "./libraries/NonceBitmap.sol";
import {RelayerSig} from "./libraries/RelayerSig.sol";

/**
 * @title Bridge
 * @notice Puente lock/burn (origen) y mint/unlock (destino) con pruebas EIP-712.
 * @dev Hot path gas: bitmap de nonces, `RelayerSig` fast-path (threshold=1), hash calldata.
 *      Dominio EIP-712: `("CrossChainBridge", "1")`.
 */
contract Bridge is IBridge, EIP712, ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;
    using NonceBitmap for mapping(uint256 => mapping(uint256 => uint256));

    /// @inheritdoc IBridge
    address public immutable override bridgeToken;

    /// @dev sourceChainId => wordIndex => bitmap (256 nonces/slot).
    mapping(uint256 sourceChainId => mapping(uint256 word => uint256 bits)) private _processedBitmap;

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

    /**
     * @inheritdoc IBridge
     * @dev Lee el bitmap interno (compatible con el getter del mapping público previo).
     */
    function processedNonces(uint256 sourceChainId, uint256 nonce) external view override returns (bool) {
        return _processedBitmap.isUsed(sourceChainId, nonce);
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
     * @dev CEI: asigna nonce + emite `Burn`, luego quema `bridgeToken` del caller.
     */
    function burn(uint256 amount, uint256 destinationChainId, address recipient) external override nonReentrant {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (recipient == address(0)) {
            revert ZeroAddress();
        }
        if (destinationChainId == block.chainid) {
            revert InvalidChainId();
        }

        uint256 nonce = nextDepositNonce;
        unchecked {
            nextDepositNonce = nonce + 1;
        }

        emit Burn(msg.sender, amount, destinationChainId, recipient, nonce);

        BridgeToken(bridgeToken).burn(msg.sender, amount);
    }

    // -------------------------------------------------------------------------
    // Destino — release
    // -------------------------------------------------------------------------

    /**
     * @inheritdoc IBridge
     * @dev CEI: checks → marcar nonce (bitmap) → mint/unlock → evento.
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
        if (_processedBitmap.isUsed(message.sourceChainId, message.nonce)) {
            revert NonceAlreadyUsed();
        }

        RelayerSig.verify(isRelayer, relayerThreshold, _hashTypedDataV4(BridgeHash.hash(message)), signatures);

        _processedBitmap.markUsed(message.sourceChainId, message.nonce);

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
     * @notice Mint de wrapped si `token == bridgeToken`; si no, unlock ERC-20 custodiado.
     * @dev Llama `BridgeToken.mint` tipado (sin dispatch de interfaz genérica).
     */
    function _mintOrUnlock(address token, address recipient, uint256 amount) internal {
        address wrapped = bridgeToken;
        if (token == wrapped) {
            BridgeToken(wrapped).mint(recipient, amount);
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }
    }
}

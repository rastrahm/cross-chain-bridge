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

/**
 * @title Bridge
 * @notice Puente lock/burn (origen) y mint/unlock (destino) con pruebas EIP-712.
 * @dev Fase 2: `deposit` (lock) completo. `burn` / `release` se completan en fases 3+.
 *      Dominio EIP-712: `("CrossChainBridge", "1")`.
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
     * @dev Fase 3+: quema wrapped. Stub hasta completar el flujo burn/unlock.
     */
    function burn(uint256, uint256, address) external pure override {
        revert ExecutionFailed();
    }

    // -------------------------------------------------------------------------
    // Destino — release (fase 3)
    // -------------------------------------------------------------------------

    /**
     * @inheritdoc IBridge
     * @dev Fase 3: verificación EIP-712 + mint. Stub en fase 2.
     */
    function release(BridgeMessage calldata, bytes[] calldata) external pure override {
        revert ExecutionFailed();
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
}

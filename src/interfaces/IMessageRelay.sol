// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title RelayMessage
 * @notice Payload tipado EIP-712 para mensajes genéricos cross-chain.
 * @dev Misma guarda anti-replay: chain IDs, nonce y `target`.
 */
struct RelayMessage {
    uint256 sourceChainId;
    uint256 destinationChainId;
    uint256 nonce;
    address target;
    bytes payload;
}

/**
 * @title IMessageRelay
 * @notice Relé de mensajes firmados con verificación de umbral de relayers.
 */
interface IMessageRelay {
    // -------------------------------------------------------------------------
    // Errors (alineados con IBridge para consistencia de tests)
    // -------------------------------------------------------------------------

    /// @notice Firma ECDSA inválida o firmante fuera del set de relayers.
    error InvalidSignature();

    /// @notice El par `(sourceChainId, nonce)` ya fue procesado.
    error NonceAlreadyUsed();

    /// @notice `destinationChainId` no coincide con `block.chainid`.
    error InvalidChainId();

    /// @notice `target.call(payload)` falló.
    error ExecutionFailed();

    /// @notice Firmas válidas por debajo del umbral.
    error ThresholdNotMet();

    /// @notice Dirección cero no permitida.
    error ZeroAddress();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /**
     * @notice Mensaje ejecutado con éxito en destino.
     * @param sourceChainId Cadena origen.
     * @param nonce Nonce consumido.
     * @param target Contrato llamado.
     */
    event MessageExecuted(uint256 indexed sourceChainId, uint256 indexed nonce, address target);

    /**
     * @notice Alta o baja de un relayer autorizado.
     * @param relayer Dirección del relayer.
     * @param approved `true` si queda autorizado.
     */
    event RelayerUpdated(address indexed relayer, bool approved);

    /**
     * @notice Umbral de firmas actualizado.
     * @param newThreshold Nuevo mínimo de firmas válidas.
     */
    event RelayerThresholdUpdated(uint256 newThreshold);

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /**
     * @notice Indica si el nonce de una cadena origen ya se usó.
     * @param sourceChainId Cadena origen.
     * @param nonce Nonce del mensaje.
     * @return `true` si ya fue procesado.
     */
    function processedNonces(uint256 sourceChainId, uint256 nonce) external view returns (bool);

    /**
     * @notice Si `account` está en el set de relayers.
     * @param account Dirección a consultar.
     * @return `true` si puede firmar ejecuciones.
     */
    function isRelayer(address account) external view returns (bool);

    /**
     * @notice Mínimo de firmas válidas de relayers distintos.
     * @return Umbral actual.
     */
    function relayerThreshold() external view returns (uint256);

    // -------------------------------------------------------------------------
    // Mutating
    // -------------------------------------------------------------------------

    /**
     * @notice Verifica EIP-712 + umbral, marca nonce y ejecuta `target.call(payload)`.
     * @param message Payload tipado.
     * @param signatures Firmas ECDSA de relayers.
     */
    function execute(RelayMessage calldata message, bytes[] calldata signatures) external;

    /**
     * @notice Autoriza o revoca un relayer.
     * @param relayer Dirección.
     * @param approved Nuevo estado.
     */
    function setRelayer(address relayer, bool approved) external;

    /**
     * @notice Actualiza el umbral de firmas.
     * @param newThreshold Nuevo mínimo (≥ 1).
     */
    function setRelayerThreshold(uint256 newThreshold) external;
}

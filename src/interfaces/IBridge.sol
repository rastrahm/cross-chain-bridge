// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title BridgeMessage
 * @notice Payload tipado EIP-712 para mint/unlock en destino.
 * @dev Anti-replay: `sourceChainId`, `destinationChainId`, `nonce` y `target` van en el hash.
 */
struct BridgeMessage {
    uint256 sourceChainId;
    uint256 destinationChainId;
    uint256 nonce;
    address target;
    address recipient;
    address token;
    uint256 amount;
}

/**
 * @title IBridge
 * @notice Superficie del puente lock/burn (origen) y mint/unlock (destino).
 * @dev Errores/eventos centralizados para `vm.expectRevert` / `vm.expectEmit` en Foundry.
 */
interface IBridge {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Firma ECDSA inválida o firmante fuera del set de relayers.
    error InvalidSignature();

    /// @notice El par `(sourceChainId, nonce)` ya fue procesado.
    error NonceAlreadyUsed();

    /// @notice `destinationChainId` no coincide con `block.chainid` (u origen inválido).
    error InvalidChainId();

    /// @notice Mint, unlock o llamada asociada falló.
    error ExecutionFailed();

    /// @notice `amount` es cero.
    error ZeroAmount();

    /// @notice Firmas válidas y únicas por debajo de `relayerThreshold`.
    error ThresholdNotMet();

    /// @notice `message.target` no es este contrato.
    error InvalidTarget();

    /// @notice Dirección cero no permitida.
    error ZeroAddress();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /**
     * @notice Tokens bloqueados en origen listos para acuñar/desbloquear en destino.
     * @param sender Quien depositó.
     * @param token ERC-20 bloqueado.
     * @param amount Cantidad bloqueada.
     * @param destinationChainId Cadena destino.
     * @param recipient Destinatario en destino.
     * @param nonce Nonce asignado al depósito.
     */
    event Deposit(
        address indexed sender,
        address token,
        uint256 amount,
        uint256 destinationChainId,
        address recipient,
        uint256 nonce
    );

    /**
     * @notice Wrapped quemado en origen para desbloquear liquidez en otra cadena.
     * @param sender Quien quemó.
     * @param amount Cantidad quemada.
     * @param destinationChainId Cadena destino.
     * @param recipient Destinatario en destino.
     * @param nonce Nonce asignado.
     */
    event Burn(address indexed sender, uint256 amount, uint256 destinationChainId, address recipient, uint256 nonce);

    /**
     * @notice Release exitoso en destino (mint o unlock).
     * @param sourceChainId Cadena de origen del mensaje.
     * @param nonce Nonce consumido.
     * @param recipient Destinatario.
     * @param amount Cantidad liberada.
     */
    event Released(uint256 indexed sourceChainId, uint256 indexed nonce, address recipient, uint256 amount);

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
     * @return `true` si puede firmar releases.
     */
    function isRelayer(address account) external view returns (bool);

    /**
     * @notice Mínimo de firmas válidas de relayers distintos.
     * @return Umbral actual.
     */
    function relayerThreshold() external view returns (uint256);

    /**
     * @notice Próximo nonce a asignar en depósitos/burns de este deploy (origen).
     * @return Nonce que se usará en el próximo `deposit`/`burn`.
     */
    function nextDepositNonce() external view returns (uint256);

    /**
     * @notice Token wrapped controlado por este bridge (destino mint/burn).
     * @return Dirección del `BridgeToken`.
     */
    function bridgeToken() external view returns (address);

    // -------------------------------------------------------------------------
    // Mutating — origen
    // -------------------------------------------------------------------------

    /**
     * @notice Bloquea `amount` de `token` y emite `Deposit` para el relayer.
     * @param token ERC-20 a bloquear.
     * @param amount Cantidad.
     * @param destinationChainId Cadena donde se hará el release.
     * @param recipient Destinatario en destino.
     */
    function deposit(address token, uint256 amount, uint256 destinationChainId, address recipient) external;

    /**
     * @notice Quema wrapped local y emite `Burn` para unlock/mint en destino.
     * @param amount Cantidad a quemar.
     * @param destinationChainId Cadena destino.
     * @param recipient Destinatario en destino.
     */
    function burn(uint256 amount, uint256 destinationChainId, address recipient) external;

    // -------------------------------------------------------------------------
    // Mutating — destino
    // -------------------------------------------------------------------------

    /**
     * @notice Verifica EIP-712 + umbral, marca nonce y mint/unlock.
     * @param message Payload tipado.
     * @param signatures Firmas ECDSA de relayers (orden libre; duplicados no cuentan dos veces).
     */
    function release(BridgeMessage calldata message, bytes[] calldata signatures) external;

    // -------------------------------------------------------------------------
    // Admin
    // -------------------------------------------------------------------------

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

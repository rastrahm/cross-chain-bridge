// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IBridgeToken
 * @notice ERC-20 wrapped acuñable/quemable solo por el contrato bridge.
 */
interface IBridgeToken {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Caller distinto del bridge autorizado.
    error OnlyBridge();

    /// @notice Dirección cero no permitida.
    error ZeroAddress();

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /**
     * @notice Contrato bridge autorizado a mint/burn.
     * @return Dirección del bridge.
     */
    function bridge() external view returns (address);

    // -------------------------------------------------------------------------
    // Mutating
    // -------------------------------------------------------------------------

    /**
     * @notice Acuña `amount` a `to` (solo bridge).
     * @param to Destinatario.
     * @param amount Cantidad.
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Quema `amount` de `from` (solo bridge; requiere allowance o caller=from según impl).
     * @param from Cuenta a debitar.
     * @param amount Cantidad.
     */
    function burn(address from, uint256 amount) external;
}

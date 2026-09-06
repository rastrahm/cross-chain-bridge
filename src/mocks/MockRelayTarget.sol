// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title MockRelayTarget
 * @notice Receptor de prueba para `MessageRelay.execute` (éxito / fallo controlado).
 */
contract MockRelayTarget {
    uint256 public value;
    bool public shouldFail;

    /**
     * @notice Configura si la próxima llamada a `setValue` debe revertir.
     * @param fail_ `true` para forzar fallo.
     */
    function setShouldFail(bool fail_) external {
        shouldFail = fail_;
    }

    /**
     * @notice Actualiza `value` o revierte si `shouldFail`.
     * @param newValue Nuevo valor.
     */
    function setValue(uint256 newValue) external {
        if (shouldFail) {
            revert("MockRelayTarget: forced fail");
        }
        value = newValue;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title NonceBitmap
 * @notice Bitmap de nonces procesados (256 nonces por slot) para abaratar SSTORE secuenciales.
 * @dev Índice de palabra = `nonce >> 8`; bit = `nonce & 255`.
 */
library NonceBitmap {
    /**
     * @notice Comprueba si `(sourceChainId, nonce)` ya fue marcado.
     */
    function isUsed(mapping(uint256 => mapping(uint256 => uint256)) storage bitmap, uint256 sourceChainId, uint256 nonce)
        internal
        view
        returns (bool)
    {
        return bitmap[sourceChainId][nonce >> 8] & (uint256(1) << (nonce & 255)) != 0;
    }

    /**
     * @notice Marca `(sourceChainId, nonce)` como usado (idempotente a nivel de bit).
     */
    function markUsed(
        mapping(uint256 => mapping(uint256 => uint256)) storage bitmap,
        uint256 sourceChainId,
        uint256 nonce
    ) internal {
        bitmap[sourceChainId][nonce >> 8] |= uint256(1) << (nonce & 255);
    }
}

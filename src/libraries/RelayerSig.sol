// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IBridge} from "../interfaces/IBridge.sol";

/**
 * @title RelayerSig
 * @notice Verificación de umbral de firmas ECDSA sobre un digest EIP-712.
 * @dev Fast-path `threshold == 1` evita alloc del array `seen`. Errores alineados a `IBridge`.
 */
library RelayerSig {
    /**
     * @notice Exige ≥ `threshold` firmas válidas de relayers distintos.
     * @param isRelayer Mapping storage del set autorizado.
     * @param threshold Mínimo de firmantes únicos.
     * @param digest Hash EIP-712 (`_hashTypedDataV4`).
     * @param signatures Firmas `r||s||v` (65 bytes).
     */
    function verify(
        mapping(address => bool) storage isRelayer,
        uint256 threshold,
        bytes32 digest,
        bytes[] calldata signatures
    ) internal view {
        if (threshold == 1) {
            _verifyThresholdOne(isRelayer, digest, signatures);
            return;
        }
        _verifyThresholdMany(isRelayer, threshold, digest, signatures);
    }

    /**
     * @dev Caso caliente 1-of-N: primera firma de relayer válida basta; sin heap alloc.
     */
    function _verifyThresholdOne(mapping(address => bool) storage isRelayer, bytes32 digest, bytes[] calldata signatures)
        private
        view
    {
        uint256 len = signatures.length;
        for (uint256 i; i < len;) {
            (address signer, ECDSA.RecoverError err,) = ECDSA.tryRecover(digest, signatures[i]);
            if (err == ECDSA.RecoverError.NoError && signer != address(0) && isRelayer[signer]) {
                return;
            }
            unchecked {
                ++i;
            }
        }
        revert IBridge.InvalidSignature();
    }

    /**
     * @dev N-of-M: cuenta firmantes únicos hasta alcanzar el umbral.
     */
    function _verifyThresholdMany(
        mapping(address => bool) storage isRelayer,
        uint256 threshold,
        bytes32 digest,
        bytes[] calldata signatures
    ) private view {
        uint256 len = signatures.length;
        address[] memory seen = new address[](len);
        uint256 validCount;

        for (uint256 i; i < len;) {
            (address signer, ECDSA.RecoverError err,) = ECDSA.tryRecover(digest, signatures[i]);
            if (err == ECDSA.RecoverError.NoError && signer != address(0) && isRelayer[signer]) {
                if (!_alreadySeen(seen, validCount, signer)) {
                    seen[validCount] = signer;
                    unchecked {
                        ++validCount;
                    }
                    if (validCount >= threshold) {
                        return;
                    }
                }
            }
            unchecked {
                ++i;
            }
        }

        if (validCount == 0) {
            revert IBridge.InvalidSignature();
        }
        revert IBridge.ThresholdNotMet();
    }

    function _alreadySeen(address[] memory seen, uint256 length, address signer) private pure returns (bool) {
        for (uint256 j; j < length;) {
            if (seen[j] == signer) {
                return true;
            }
            unchecked {
                ++j;
            }
        }
        return false;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {BridgeMessage} from "../../src/interfaces/IBridge.sol";
import {BridgeHash} from "../../src/libraries/BridgeHash.sol";

/**
 * @title EIP712BridgeHelper
 * @notice Helpers de dominio EIP-712 y firmas `vm.sign` para la suite del bridge.
 * @dev Debe coincidir con `EIP712("CrossChainBridge", "1")` en `Bridge` (fases 2–3).
 */
abstract contract EIP712BridgeHelper is Test {
    string internal constant EIP712_NAME = "CrossChainBridge";
    string internal constant EIP712_VERSION = "1";

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /**
     * @notice Domain separator EIP-712 para `verifyingContract` en el `chainId` actual.
     * @param verifyingContract Dirección del Bridge que verifica (destino).
     * @return Separador de dominio v4.
     */
    function _domainSeparator(address verifyingContract) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(EIP712_NAME)),
                keccak256(bytes(EIP712_VERSION)),
                block.chainid,
                verifyingContract
            )
        );
    }

    /**
     * @notice Digest EIP-712 (`\x19\x01` ‖ domain ‖ structHash) listo para `vm.sign` / `ecrecover`.
     * @param verifyingContract Bridge destino.
     * @param message Payload tipado.
     * @return digest Hash a firmar.
     */
    function _digest(address verifyingContract, BridgeMessage memory message) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(verifyingContract), BridgeHash.hash(message)));
    }

    /**
     * @notice Firma un `BridgeMessage` con la clave privada del relayer.
     * @param privateKey Clave del relayer (`vm.addr(privateKey)` debe estar en `isRelayer`).
     * @param verifyingContract Bridge destino.
     * @param message Payload.
     * @return signature Codificación `abi.encodePacked(r, s, v)`.
     */
    function _signBridgeMessage(uint256 privateKey, address verifyingContract, BridgeMessage memory message)
        internal
        view
        returns (bytes memory signature)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, _digest(verifyingContract, message));
        return abi.encodePacked(r, s, v);
    }
}

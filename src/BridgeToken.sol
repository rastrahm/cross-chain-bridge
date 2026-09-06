// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IBridgeToken} from "./interfaces/IBridgeToken.sol";

/**
 * @title BridgeToken
 * @notice ERC-20 wrapped del puente: `mint` / `burn` solo por el contrato `bridge`.
 * @dev Desplegado por `Bridge` en el constructor (`immutable bridge = address(this)` del bridge).
 */
contract BridgeToken is ERC20, IBridgeToken {
    /// @inheritdoc IBridgeToken
    address public immutable override bridge;

    /**
     * @notice Restringe mint/burn al bridge.
     */
    modifier onlyBridge() {
        if (msg.sender != bridge) {
            revert OnlyBridge();
        }
        _;
    }

    /**
     * @notice Crea el token wrapped ligado a un bridge.
     * @param name_ Nombre ERC-20.
     * @param symbol_ Símbolo ERC-20.
     * @param bridge_ Contrato autorizado a acuñar/quemar (no cero).
     */
    constructor(string memory name_, string memory symbol_, address bridge_) ERC20(name_, symbol_) {
        if (bridge_ == address(0)) {
            revert ZeroAddress();
        }
        bridge = bridge_;
    }

    /**
     * @inheritdoc IBridgeToken
     */
    function mint(address to, uint256 amount) external override onlyBridge {
        if (to == address(0)) {
            revert ZeroAddress();
        }
        _mint(to, amount);
    }

    /**
     * @inheritdoc IBridgeToken
     * @dev El bridge debita `from` sin allowance (flujo `burn` del puente).
     */
    function burn(address from, uint256 amount) external override onlyBridge {
        _burn(from, amount);
    }
}

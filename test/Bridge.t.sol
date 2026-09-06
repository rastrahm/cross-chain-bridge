// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Bridge} from "../src/Bridge.sol";
import {BridgeToken} from "../src/BridgeToken.sol";
import {IBridge, BridgeMessage} from "../src/interfaces/IBridge.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {EIP712BridgeHelper} from "./helpers/EIP712BridgeHelper.sol";

/**
 * @title BridgeTest
 * @notice Deposit (fase 2 ✅) + digest EIP-712 + release e2e (fase 3).
 * @dev `release` aún stub → `test_release_e2e_depositSignMint` falla con `ExecutionFailed` hasta fase 3.
 */
contract BridgeTest is EIP712BridgeHelper {
    uint256 internal constant RELAYER_PK = 0xA11CE;
    uint256 internal constant SOURCE_CHAIN_ID = 1;
    uint256 internal constant AMOUNT = 100 ether;

    address internal relayer;
    address internal user;
    address internal recipient;

    MockERC20 internal underlying;
    Bridge internal bridge;
    BridgeToken internal bridgeToken;

    function setUp() public {
        relayer = vm.addr(RELAYER_PK);
        user = makeAddr("user");
        recipient = makeAddr("recipient");

        underlying = new MockERC20("Underlying", "UND");
        bridge = new Bridge(relayer, 1);
        bridgeToken = BridgeToken(bridge.bridgeToken());

        underlying.mint(user, 1_000_000 ether);

        // Simula origen distinto al destino del release (destino = block.chainid).
        vm.chainId(SOURCE_CHAIN_ID);
    }

    // -------------------------------------------------------------------------
    // Deposit (evento + lock)
    // -------------------------------------------------------------------------

    /**
     * @notice `deposit` bloquea tokens y emite `Deposit` con nonce 0.
     */
    function test_deposit_emitsDepositAndLocksTokens() public {
        uint256 destChainId = 31_337;

        vm.startPrank(user);
        underlying.approve(address(bridge), AMOUNT);

        vm.expectEmit(true, false, false, true, address(bridge));
        emit IBridge.Deposit(user, address(underlying), AMOUNT, destChainId, recipient, 0);

        bridge.deposit(address(underlying), AMOUNT, destChainId, recipient);
        vm.stopPrank();

        assertEq(underlying.balanceOf(address(bridge)), AMOUNT);
        assertEq(underlying.balanceOf(user), 1_000_000 ether - AMOUNT);
        assertEq(bridge.nextDepositNonce(), 1);
    }

    /**
     * @notice `deposit` con amount 0 revierte `ZeroAmount`.
     */
    function test_deposit_revertsZeroAmount() public {
        vm.startPrank(user);
        underlying.approve(address(bridge), 1);
        vm.expectRevert(IBridge.ZeroAmount.selector);
        bridge.deposit(address(underlying), 0, 31_337, recipient);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // EIP-712 digest
    // -------------------------------------------------------------------------

    /**
     * @notice El digest EIP-712 firmado por el relayer se recupera con `ecrecover`.
     */
    function test_eip712_digestRecoversRelayer() public view {
        BridgeMessage memory message = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: block.chainid,
            nonce: 0,
            target: address(bridge),
            recipient: recipient,
            token: address(bridgeToken),
            amount: AMOUNT
        });

        bytes32 digest = _digest(address(bridge), message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(RELAYER_PK, digest);
        address recovered = ecrecover(digest, v, r, s);

        assertEq(recovered, relayer);
        assertTrue(bridge.isRelayer(relayer));
    }

    // -------------------------------------------------------------------------
    // Release e2e (deposit → sign → mint)
    // -------------------------------------------------------------------------

    /**
     * @notice Flujo feliz: deposit en origen → firma relayer → release en destino acuña wrapped.
     * @dev Usa dos `chainId`: deposit en `SOURCE_CHAIN_ID`, release en `31_337`.
     */
    function test_release_e2e_depositSignMint() public {
        uint256 destChainId = 31_337;

        // --- Origen (chainId ya es SOURCE_CHAIN_ID desde setUp) ---
        vm.startPrank(user);
        underlying.approve(address(bridge), AMOUNT);
        bridge.deposit(address(underlying), AMOUNT, destChainId, recipient);
        vm.stopPrank();

        uint256 nonce = 0;
        assertEq(bridge.nextDepositNonce(), 1);

        // --- Destino ---
        vm.chainId(destChainId);

        BridgeMessage memory message = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: destChainId,
            nonce: nonce,
            target: address(bridge),
            recipient: recipient,
            token: address(bridgeToken),
            amount: AMOUNT
        });

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signBridgeMessage(RELAYER_PK, address(bridge), message);

        vm.expectEmit(true, true, false, true, address(bridge));
        emit IBridge.Released(SOURCE_CHAIN_ID, nonce, recipient, AMOUNT);

        bridge.release(message, signatures);

        assertEq(bridgeToken.balanceOf(recipient), AMOUNT);
        assertTrue(bridge.processedNonces(SOURCE_CHAIN_ID, nonce));
    }
}

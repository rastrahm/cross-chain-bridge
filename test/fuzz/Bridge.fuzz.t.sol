// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Bridge} from "../../src/Bridge.sol";
import {BridgeToken} from "../../src/BridgeToken.sol";
import {IBridge, BridgeMessage} from "../../src/interfaces/IBridge.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {EIP712BridgeHelper} from "../helpers/EIP712BridgeHelper.sol";

/**
 * @title BridgeFuzzTest
 * @notice Fase 7: fuzz de `amount`, `chainId` y `nonce` con `bound()`.
 */
contract BridgeFuzzTest is EIP712BridgeHelper {
    uint256 internal constant RELAYER_PK = 0xA11CE;
    uint256 internal constant SOURCE_CHAIN_ID = 1;
    uint256 internal constant DEST_CHAIN_ID = 31_337;

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

        underlying.mint(user, type(uint128).max);
        vm.chainId(SOURCE_CHAIN_ID);
    }

    /**
     * @notice `deposit` bloquea exactamente `amount` y avanza el nonce.
     */
    function testFuzz_deposit_locksExactAmount(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000 ether);

        uint256 nonceBefore = bridge.nextDepositNonce();
        uint256 userBefore = underlying.balanceOf(user);

        vm.startPrank(user);
        underlying.approve(address(bridge), amount);
        bridge.deposit(address(underlying), amount, DEST_CHAIN_ID, recipient);
        vm.stopPrank();

        assertEq(underlying.balanceOf(address(bridge)), amount);
        assertEq(underlying.balanceOf(user), userBefore - amount);
        assertEq(bridge.nextDepositNonce(), nonceBefore + 1);
    }

    /**
     * @notice `deposit` con amount 0 siempre revierte (fuzz de ruido).
     */
    function testFuzz_deposit_revertsZeroAmount(uint256 destChainId, address to) public {
        destChainId = bound(destChainId, 2, type(uint32).max);
        if (destChainId == SOURCE_CHAIN_ID) {
            destChainId = DEST_CHAIN_ID;
        }
        if (to == address(0)) {
            to = recipient;
        }

        vm.startPrank(user);
        underlying.approve(address(bridge), 1);
        vm.expectRevert(IBridge.ZeroAmount.selector);
        bridge.deposit(address(underlying), 0, destChainId, to);
        vm.stopPrank();
    }

    /**
     * @notice `destinationChainId == block.chainid` en deposit revierte `InvalidChainId`.
     */
    function testFuzz_deposit_revertsSameChainId(uint256 amount) public {
        amount = bound(amount, 1, 1_000 ether);

        vm.startPrank(user);
        underlying.approve(address(bridge), amount);
        vm.expectRevert(IBridge.InvalidChainId.selector);
        bridge.deposit(address(underlying), amount, SOURCE_CHAIN_ID, recipient);
        vm.stopPrank();
    }

    /**
     * @notice Release e2e: mint exacto para amounts fuzzed; replay del mismo nonce falla.
     */
    function testFuzz_release_mintsExactAmountAndNonceUnique(uint256 amount) public {
        amount = bound(amount, 1, 500_000 ether);

        vm.startPrank(user);
        underlying.approve(address(bridge), amount);
        bridge.deposit(address(underlying), amount, DEST_CHAIN_ID, recipient);
        vm.stopPrank();

        uint256 nonce = bridge.nextDepositNonce() - 1;

        vm.chainId(DEST_CHAIN_ID);

        BridgeMessage memory message = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: nonce,
            target: address(bridge),
            recipient: recipient,
            token: address(bridgeToken),
            amount: amount
        });

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signBridgeMessage(RELAYER_PK, address(bridge), message);

        bridge.release(message, signatures);

        assertEq(bridgeToken.balanceOf(recipient), amount);
        assertTrue(bridge.processedNonces(SOURCE_CHAIN_ID, nonce));

        vm.expectRevert(IBridge.NonceAlreadyUsed.selector);
        bridge.release(message, signatures);

        assertEq(bridgeToken.balanceOf(recipient), amount);
    }

    /**
     * @notice Cualquier `block.chainid` ≠ `destinationChainId` revierte `InvalidChainId`.
     */
    function testFuzz_release_revertsWrongChainId(uint256 wrongChainId, uint256 amount) public {
        amount = bound(amount, 1, 10_000 ether);
        wrongChainId = bound(wrongChainId, 1, type(uint32).max);
        if (wrongChainId == DEST_CHAIN_ID) {
            wrongChainId = DEST_CHAIN_ID + 1;
        }

        vm.startPrank(user);
        underlying.approve(address(bridge), amount);
        bridge.deposit(address(underlying), amount, DEST_CHAIN_ID, recipient);
        vm.stopPrank();

        BridgeMessage memory message = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: 0,
            target: address(bridge),
            recipient: recipient,
            token: address(bridgeToken),
            amount: amount
        });

        vm.chainId(DEST_CHAIN_ID);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signBridgeMessage(RELAYER_PK, address(bridge), message);

        vm.chainId(wrongChainId);

        vm.expectRevert(IBridge.InvalidChainId.selector);
        bridge.release(message, signatures);
    }

    /**
     * @notice Nonces de depósito distintos producen releases independientes.
     */
    function testFuzz_release_distinctNoncesIndependent(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 1, 100_000 ether);
        amountB = bound(amountB, 1, 100_000 ether);

        vm.startPrank(user);
        underlying.approve(address(bridge), amountA + amountB);
        bridge.deposit(address(underlying), amountA, DEST_CHAIN_ID, recipient);
        bridge.deposit(address(underlying), amountB, DEST_CHAIN_ID, recipient);
        vm.stopPrank();

        vm.chainId(DEST_CHAIN_ID);

        BridgeMessage memory msg0 = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: 0,
            target: address(bridge),
            recipient: recipient,
            token: address(bridgeToken),
            amount: amountA
        });
        BridgeMessage memory msg1 = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: 1,
            target: address(bridge),
            recipient: recipient,
            token: address(bridgeToken),
            amount: amountB
        });

        bytes[] memory sig0 = new bytes[](1);
        sig0[0] = _signBridgeMessage(RELAYER_PK, address(bridge), msg0);
        bytes[] memory sig1 = new bytes[](1);
        sig1[0] = _signBridgeMessage(RELAYER_PK, address(bridge), msg1);

        bridge.release(msg0, sig0);
        bridge.release(msg1, sig1);

        assertEq(bridgeToken.balanceOf(recipient), amountA + amountB);
        assertTrue(bridge.processedNonces(SOURCE_CHAIN_ID, 0));
        assertTrue(bridge.processedNonces(SOURCE_CHAIN_ID, 1));
    }
}

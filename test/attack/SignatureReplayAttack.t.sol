// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Bridge} from "../../src/Bridge.sol";
import {BridgeToken} from "../../src/BridgeToken.sol";
import {IBridge, BridgeMessage} from "../../src/interfaces/IBridge.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {EIP712BridgeHelper} from "../helpers/EIP712BridgeHelper.sol";

/**
 * @title SignatureReplayAttackTest
 * @notice SWC-121: replay de firma (mismo nonce / cross-chain domain).
 */
contract SignatureReplayAttackTest is EIP712BridgeHelper {
    uint256 internal constant RELAYER_PK = 0xA11CE;
    uint256 internal constant SOURCE_CHAIN_ID = 1;
    uint256 internal constant DEST_CHAIN_ID = 31_337;
    uint256 internal constant AMOUNT = 50 ether;

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
        vm.chainId(SOURCE_CHAIN_ID);
    }

    /**
     * @notice SWC-121: replay on-chain del mismo mensaje tras éxito → `NonceAlreadyUsed`.
     */
    function test_Attack_replaySameMessage_revertsNonceAlreadyUsed() public {
        (BridgeMessage memory message, bytes[] memory signatures) = _depositSign();

        vm.chainId(DEST_CHAIN_ID);
        bridge.release(message, signatures);

        vm.expectRevert(IBridge.NonceAlreadyUsed.selector);
        bridge.release(message, signatures);

        assertEq(bridgeToken.balanceOf(recipient), AMOUNT);
    }

    /**
     * @notice SWC-121: misma firma en otra cadena con dest alterado → `InvalidSignature`.
     */
    function test_Attack_crossChainDomainReplay_revertsInvalidSignature() public {
        (BridgeMessage memory message, bytes[] memory signatures) = _depositSign();

        uint256 forkChain = 99_999;
        vm.chainId(forkChain);
        message.destinationChainId = forkChain;

        vm.expectRevert(IBridge.InvalidSignature.selector);
        bridge.release(message, signatures);

        assertEq(bridgeToken.balanceOf(recipient), 0);
    }

    function _depositSign() internal returns (BridgeMessage memory message, bytes[] memory signatures) {
        vm.startPrank(user);
        underlying.approve(address(bridge), AMOUNT);
        bridge.deposit(address(underlying), AMOUNT, DEST_CHAIN_ID, recipient);
        vm.stopPrank();

        message = BridgeMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: 0,
            target: address(bridge),
            recipient: recipient,
            token: address(bridgeToken),
            amount: AMOUNT
        });

        vm.chainId(DEST_CHAIN_ID);
        signatures = new bytes[](1);
        signatures[0] = _signBridgeMessage(RELAYER_PK, address(bridge), message);
    }
}

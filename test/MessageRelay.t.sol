// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MessageRelay} from "../src/MessageRelay.sol";
import {IMessageRelay, RelayMessage} from "../src/interfaces/IMessageRelay.sol";
import {MockRelayTarget} from "../src/mocks/MockRelayTarget.sol";
import {EIP712BridgeHelper} from "./helpers/EIP712BridgeHelper.sol";

/**
 * @title MessageRelayTest
 * @notice Fase 6: `execute` feliz, umbral N-of-M, `ExecutionFailed` y anti-replay básico.
 */
contract MessageRelayTest is EIP712BridgeHelper {
    uint256 internal constant RELAYER1_PK = 0xA11CE;
    uint256 internal constant RELAYER2_PK = 0xB0B;
    uint256 internal constant RELAYER3_PK = 0xC0FFEE;
    uint256 internal constant SOURCE_CHAIN_ID = 1;
    uint256 internal constant DEST_CHAIN_ID = 31_337;

    address internal relayer1;
    address internal relayer2;
    address internal relayer3;

    MessageRelay internal relay;
    MockRelayTarget internal target;

    function setUp() public {
        relayer1 = vm.addr(RELAYER1_PK);
        relayer2 = vm.addr(RELAYER2_PK);
        relayer3 = vm.addr(RELAYER3_PK);

        relay = new MessageRelay(relayer1, 1);
        target = new MockRelayTarget();

        vm.chainId(DEST_CHAIN_ID);
    }

    /**
     * @notice `execute` con 1 firma válida llama al target y marca el nonce.
     */
    function test_execute_successWithOneRelayer() public {
        RelayMessage memory message = _buildMessage(0, abi.encodeCall(MockRelayTarget.setValue, (42)));

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signRelayMessage(RELAYER1_PK, address(relay), message);

        vm.expectEmit(true, true, false, true, address(relay));
        emit IMessageRelay.MessageExecuted(SOURCE_CHAIN_ID, 0, address(target));

        relay.execute(message, signatures);

        assertEq(target.value(), 42);
        assertTrue(relay.processedNonces(SOURCE_CHAIN_ID, 0));
    }

    /**
     * @notice Umbral 2-of-3: dos firmas de relayers distintos bastan.
     */
    function test_execute_successWithThreshold2of3() public {
        relay.setRelayer(relayer2, true);
        relay.setRelayer(relayer3, true);
        relay.setRelayerThreshold(2);

        RelayMessage memory message = _buildMessage(0, abi.encodeCall(MockRelayTarget.setValue, (7)));

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = _signRelayMessage(RELAYER1_PK, address(relay), message);
        signatures[1] = _signRelayMessage(RELAYER2_PK, address(relay), message);

        relay.execute(message, signatures);

        assertEq(target.value(), 7);
        assertTrue(relay.processedNonces(SOURCE_CHAIN_ID, 0));
    }

    /**
     * @notice Target que revierte → `ExecutionFailed`; el estado (nonce) se revierte con la tx.
     */
    function test_execute_revertsExecutionFailed() public {
        target.setShouldFail(true);

        RelayMessage memory message = _buildMessage(0, abi.encodeCall(MockRelayTarget.setValue, (1)));

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signRelayMessage(RELAYER1_PK, address(relay), message);

        vm.expectRevert(IMessageRelay.ExecutionFailed.selector);
        relay.execute(message, signatures);

        assertFalse(relay.processedNonces(SOURCE_CHAIN_ID, 0));
        assertEq(target.value(), 0);
    }

    /**
     * @notice Reuso de nonce → `NonceAlreadyUsed`.
     */
    function test_execute_revertsNonceAlreadyUsed() public {
        RelayMessage memory message = _buildMessage(0, abi.encodeCall(MockRelayTarget.setValue, (1)));

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signRelayMessage(RELAYER1_PK, address(relay), message);

        relay.execute(message, signatures);

        vm.expectRevert(IMessageRelay.NonceAlreadyUsed.selector);
        relay.execute(message, signatures);
    }

    /**
     * @notice `destinationChainId` incorrecto → `InvalidChainId`.
     */
    function test_execute_revertsInvalidChainId() public {
        RelayMessage memory message = _buildMessage(0, abi.encodeCall(MockRelayTarget.setValue, (1)));

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signRelayMessage(RELAYER1_PK, address(relay), message);

        vm.chainId(999);

        vm.expectRevert(IMessageRelay.InvalidChainId.selector);
        relay.execute(message, signatures);
    }

    /**
     * @notice Umbral 2 con una sola firma → `ThresholdNotMet`.
     */
    function test_execute_revertsThresholdNotMet() public {
        relay.setRelayer(relayer2, true);
        relay.setRelayerThreshold(2);

        RelayMessage memory message = _buildMessage(0, abi.encodeCall(MockRelayTarget.setValue, (1)));

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signRelayMessage(RELAYER1_PK, address(relay), message);

        vm.expectRevert(IMessageRelay.ThresholdNotMet.selector);
        relay.execute(message, signatures);
    }

    function _buildMessage(uint256 nonce, bytes memory payload) internal view returns (RelayMessage memory) {
        return RelayMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: nonce,
            target: address(target),
            payload: payload
        });
    }
}

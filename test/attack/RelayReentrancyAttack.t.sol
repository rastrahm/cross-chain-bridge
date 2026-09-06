// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MessageRelay} from "../../src/MessageRelay.sol";
import {IMessageRelay, RelayMessage} from "../../src/interfaces/IMessageRelay.sol";
import {EIP712BridgeHelper} from "../helpers/EIP712BridgeHelper.sol";

/**
 * @title ReenteringRelayTarget
 * @notice Target que reentra `MessageRelay.execute` durante el `call` (SWC-107).
 */
contract ReenteringRelayTarget {
    MessageRelay public relay;
    RelayMessage public replayMessage;
    bytes public replaySignature;
    bool public attackEnabled;

    function configure(MessageRelay relay_, RelayMessage calldata message_, bytes calldata signature_) external {
        relay = relay_;
        replayMessage = message_;
        replaySignature = signature_;
    }

    function setAttackEnabled(bool enabled) external {
        attackEnabled = enabled;
    }

    function ping() external {
        if (attackEnabled) {
            attackEnabled = false;
            bytes[] memory sigs = new bytes[](1);
            sigs[0] = replaySignature;
            relay.execute(replayMessage, sigs);
        }
    }
}

/**
 * @title RelayReentrancyAttackTest
 * @notice SWC-107: reentrada en `MessageRelay.execute` vía target malicioso.
 */
contract RelayReentrancyAttackTest is EIP712BridgeHelper {
    uint256 internal constant RELAYER_PK = 0xA11CE;
    uint256 internal constant SOURCE_CHAIN_ID = 1;
    uint256 internal constant DEST_CHAIN_ID = 31_337;

    address internal relayer;
    MessageRelay internal relay;
    ReenteringRelayTarget internal target;

    function setUp() public {
        relayer = vm.addr(RELAYER_PK);
        relay = new MessageRelay(relayer, 1);
        target = new ReenteringRelayTarget();
        vm.chainId(DEST_CHAIN_ID);
    }

    /**
     * @notice SWC-107: el target no puede reentrar `execute` (guard).
     */
    function test_Attack_reenterExecute_revertsGuard() public {
        RelayMessage memory message = RelayMessage({
            sourceChainId: SOURCE_CHAIN_ID,
            destinationChainId: DEST_CHAIN_ID,
            nonce: 0,
            target: address(target),
            payload: abi.encodeCall(ReenteringRelayTarget.ping, ())
        });

        bytes memory sig = _signRelayMessage(RELAYER_PK, address(relay), message);
        target.configure(relay, message, sig);
        target.setAttackEnabled(true);

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = sig;

        // El call interno revierte por reentrancy → execute reporta ExecutionFailed.
        vm.expectRevert(IMessageRelay.ExecutionFailed.selector);
        relay.execute(message, signatures);

        assertFalse(relay.processedNonces(SOURCE_CHAIN_ID, 0));
    }
}

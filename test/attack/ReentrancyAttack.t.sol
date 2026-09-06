// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Bridge} from "../../src/Bridge.sol";
import {EIP712BridgeHelper} from "../helpers/EIP712BridgeHelper.sol";

/**
 * @title ReenteringERC20
 * @notice Token malicioso que reentra `deposit` durante `transferFrom` (SWC-107).
 */
contract ReenteringERC20 is ERC20 {
    Bridge public bridge;
    address public attackRecipient;
    uint256 public attackDestChainId;
    bool public attackEnabled;

    constructor() ERC20("Reentering", "REENT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function configureAttack(Bridge bridge_, address recipient_, uint256 destChainId_) external {
        bridge = bridge_;
        attackRecipient = recipient_;
        attackDestChainId = destChainId_;
    }

    function setAttackEnabled(bool enabled) external {
        attackEnabled = enabled;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (attackEnabled && address(bridge) != address(0)) {
            attackEnabled = false;
            bridge.deposit(address(this), 1, attackDestChainId, attackRecipient);
        }
        return super.transferFrom(from, to, amount);
    }
}

/**
 * @title ReentrancyAttackTest
 * @notice SWC-107: reentrada en `deposit` / `release` bloqueada por `ReentrancyGuard`.
 */
contract ReentrancyAttackTest is EIP712BridgeHelper {
    uint256 internal constant RELAYER_PK = 0xA11CE;
    uint256 internal constant SOURCE_CHAIN_ID = 1;
    uint256 internal constant DEST_CHAIN_ID = 31_337;

    address internal relayer;
    address internal user;
    address internal recipient;

    Bridge internal bridge;
    ReenteringERC20 internal token;

    function setUp() public {
        relayer = vm.addr(RELAYER_PK);
        user = makeAddr("user");
        recipient = makeAddr("recipient");

        bridge = new Bridge(relayer, 1);
        token = new ReenteringERC20();
        token.configureAttack(bridge, recipient, DEST_CHAIN_ID);
        token.mint(user, 1_000 ether);

        vm.chainId(SOURCE_CHAIN_ID);
    }

    /**
     * @notice SWC-107: reentrar `deposit` desde `transferFrom` revierte el guard.
     */
    function test_Attack_reenterDeposit_revertsGuard() public {
        token.setAttackEnabled(true);

        vm.startPrank(user);
        token.approve(address(bridge), type(uint256).max);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        bridge.deposit(address(token), 10 ether, DEST_CHAIN_ID, recipient);
        vm.stopPrank();

        assertEq(token.balanceOf(address(bridge)), 0);
        assertEq(bridge.nextDepositNonce(), 0);
    }

    /**
     * @notice Sin ataque, el deposit del token custom funciona (control negativo).
     */
    function test_Attack_depositWithoutReentrancy_succeeds() public {
        token.setAttackEnabled(false);

        vm.startPrank(user);
        token.approve(address(bridge), 10 ether);
        bridge.deposit(address(token), 10 ether, DEST_CHAIN_ID, recipient);
        vm.stopPrank();

        assertEq(token.balanceOf(address(bridge)), 10 ether);
        assertEq(bridge.nextDepositNonce(), 1);
    }
}

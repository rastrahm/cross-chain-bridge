# SWC Audit — Cross-Chain Bridge & Message Relay

🌐 [Español](./SWC-AUDIT-ES.md) · **English**

Verification of `Bridge`, `MessageRelay` and `BridgeToken` against the [SWC Registry](https://swcregistry.io/) (EIP-1470) and monorepo principles (custom errors, `ReentrancyGuard`, SafeERC20, EIP-712 / ECDSA, anti-replay).

> **Note:** The SWC Registry has not been actively maintained since ~2020. Complement it with [SCSVS](https://github.com/ComposableSecurity/SCSVS) and [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Audited contracts:** `src/Bridge.sol`, `src/MessageRelay.sol`, `src/BridgeToken.sol`, `src/libraries/BridgeHash.sol` (+ interfaces)  
**Mocks (outside prod):** `src/mocks/MockERC20.sol`, `src/mocks/MockRelayTarget.sol`  
**Date:** 2026-09-06  
**Test reference:** `test/Bridge.t.sol`, `test/Replay.t.sol`, `test/InvalidSignature.t.sol`, `test/MessageRelay.t.sol`, `test/attack/`, `test/fuzz/`  
**Style:** aligned with [`08-flash-loans/doc/SWC-AUDIT-EN.md`](../../08-flash-loans/doc/SWC-AUDIT-EN.md)

---

## Executive summary

| Status | Count |
|--------|----------|
| ✅ Mitigated / Not applicable | 33 |
| ⚠️ Informational (design / trust) | 3 |
| ❌ Vulnerable | 0 |

**Conclusion:** No exploitable SWC vulnerabilities within the v1 scope (lock→mint, burn→unlock, EIP-712 + relayer threshold, `MessageRelay.execute`). Informational risks: trust in the relayer set / owner (`Ownable2Step`) and fee-on-transfer / ERC-777 tokens out of scope.

**Verified suite principles:**

| Principle | Status |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ |
| Fixed pragma `0.8.24` | ✅ |
| CEI + `nonReentrant` on deposit / release / execute | ✅ + `test/attack/` |
| EIP-712 anti-replay + `processedNonces` | ✅ + Replay / SignatureReplay |
| ECDSA / N-of-M threshold | ✅ + InvalidSignature / MessageRelay |
| SafeERC20 (SWC-104) on lock/unlock | ✅ |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/Bridge.fuzz.t.sol` |

---

## Full SWC-100 — SWC-136 matrix

| ID | Title | Applies | Status | Evidence in Cross-Chain Bridge |
|----|--------|--------|--------|----------------------------------|
| SWC-100 | Function Default Visibility | Yes | ✅ | Explicit visibility in contracts, interfaces and `BridgeHash` |
| SWC-101 | Integer Overflow and Underflow | Yes | ✅ | Solidity `0.8.24`; fuzzed amounts; `unchecked` only on nonce `++` after checks |
| SWC-102 | Outdated Compiler Version | Yes | ✅ | `pragma solidity 0.8.24` + `foundry.toml` `solc = "0.8.24"` |
| SWC-103 | Floating Pragma | Yes | ✅ | Exact pragma (no `^`) across all of `src/` |
| SWC-104 | Unchecked Call Return Value | Yes | ✅ | OZ `SafeERC20` on deposit/unlock; `MessageRelay` checks the `call` `success` → `ExecutionFailed` |
| SWC-105 | Unprotected Ether Withdrawal | No | N/A | No ETH / `payable` / `.call{value}` |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | No `selfdestruct` |
| SWC-107 | Reentrancy | Yes | ✅ | `nonReentrant` on deposit/release/execute; `test/attack/ReentrancyAttack.t.sol` + `RelayReentrancyAttack.t.sol` |
| SWC-108 | State Variable Default Visibility | Yes | ✅ | Explicit `immutable` / `public` mappings |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | No legacy storage pointers |
| SWC-110 | Assert Violation | No | N/A | No production `assert` |
| SWC-111 | Deprecated Solidity Functions | Yes | ✅ | No `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | No `delegatecall` |
| SWC-113 | DoS with Failed Call | Partial | ✅ | `execute` with a failing target → `ExecutionFailed`; tx reverts (nonce is not left marked) |
| SWC-114 | Transaction Order Dependence | Yes | ⚠️ | Public relayers / `release`: race between relayers (idempotent via nonce); see risks |
| SWC-115 | Authorization through tx.origin | No | N/A | No `tx.origin`; auth via ECDSA + `isRelayer` |
| SWC-116 | Block values as a proxy for time | No | N/A | No on-chain time locks |
| SWC-117 | Signature Malleability | Yes | ✅ | OZ `ECDSA.tryRecover` (normalized s-value / v); malformed signatures → `InvalidSignature` |
| SWC-118 | Incorrect Constructor Name | No | N/A | 0.8+ `constructor` |
| SWC-119 | Shadowing State Variables | Yes | ✅ | No state shadowing |
| SWC-120 | Weak Sources of Randomness | No | N/A | No RNG |
| SWC-121 | Missing Protection against Signature Replay | Yes | ✅ | EIP-712 domain + `destinationChainId` + `target` + `processedNonces`; Replay / SignatureReplayAttack |
| SWC-122 | Lack of Proper Signature Verification | Yes | ✅ | Relayer threshold; `InvalidSignature` / `ThresholdNotMet`; InvalidSignature + TargetSpoofAttack |
| SWC-123 | Requirement Violation | Yes | ✅ | Custom errors + unit / fuzz / attack |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | No storage assembly |
| SWC-125 | Incorrect Inheritance Order | Yes | ✅ | `IBridge, EIP712, ReentrancyGuard, Ownable2Step` |
| SWC-126 | Insufficient Gas Griefing | Partial | ✅ | `execute` depends on the caller's gas; failure → `ExecutionFailed` |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | No dynamic function types |
| SWC-128 | DoS With Block Gas Limit | Partial | ✅ | Signature loop bounded by `signatures.length` (caller pays gas) |
| SWC-129 | Typographical Error | Yes | ✅ | Review + `forge build` / 43 tests PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII |
| SWC-131 | Presence of unused variables | Yes | ✅ | No material dead code in production `src/` |
| SWC-132 | Unexpected Ether balance | No | N/A | Contracts do not handle ETH |
| SWC-133 | Hash Collisions (var-length args) | Yes | ✅ | Typed EIP-712 (`BridgeHash`); `bytes payload` hashed with `keccak256` |
| SWC-134 | Message call with hardcoded gas | No | N/A | No `{gas: …}` |
| SWC-135 | Code With No Effects | No | N/A | No relevant no-ops |
| SWC-136 | Unencrypted Private Data On-Chain | Partial | ✅ | Nonces, relayers and amounts are public by design |

---

## Informational risks

### SWC-114 — Transaction ordering / relayers

`release` and `execute` are public: anyone can submit an already-signed message. The first success consumes the nonce; a second attempt reverts with `NonceAlreadyUsed` (no double mint). There is no loss of funds from races between relayers.

### Centralization / trust

| Topic | Risk | v1 treatment |
|------|--------|----------------|
| Relayer set + threshold | Colluding relayers can sign fake releases | `Ownable2Step` admin; N-of-M threshold; document trust |
| `burn` | Source burns wrapped; destination unlocks via `release` | Implemented + `test_burn_e2e_unlockUnderlying` |
| Fee-on-transfer / ERC-777 tokens | Unexpected accounting / callbacks | Out of v1 scope; honest ERC-20 mocks + attack token only for reentrancy |

### MessageRelay surface

`target.call(payload)` executes arbitrary calldata signed by relayers. The risk is **trust in relayers**, not insufficient on-chain auth: without a valid threshold there is no `execute`. Covered in `MessageRelay.t.sol` + `RelayReentrancyAttack.t.sol`.

---

## Monorepo principles checklist (+ module 09)

| Principle | Compliant? | Notes |
|-----------|----------|--------|
| Custom errors | ✅ | `InvalidSignature`, `NonceAlreadyUsed`, `InvalidChainId`, `ExecutionFailed`, … |
| ReentrancyGuard (OZ) | ✅ | deposit / release / execute |
| SafeERC20 | ✅ | lock + unlock |
| EIP-712 domain | ✅ | Bridge `CrossChainBridge`/`1`; Relay `MessageRelay`/`1` |
| Anti-replay | ✅ | chainIds + nonce + target in hash |
| Public/external NatSpec | ✅ | Phase 8 |
| Fuzz ≥ 1000 runs | ✅ | `test/fuzz/Bridge.fuzz.t.sol` |
| `test/attack/` suite | ✅ | Reentrancy · RelayReentrancy · TargetSpoof · SignatureReplay |
| Gas baseline | ✅ | `doc/GAS-EN.md` + `.gas-snapshot` |

---

## Verification findings (code)

### Confirmed mitigations

1. **`Bridge.deposit`:** checks → nonce++ + event → `safeTransferFrom` under `nonReentrant`.
2. **`Bridge.release`:** chainId / target / nonce / signatures → mark nonce → mint/unlock → event.
3. **`MessageRelay.execute`:** same guards + `call` with `success` check.
4. **`BridgeToken`:** `onlyBridge` on mint/burn.
5. **No `require` strings / `tx.origin` / ETH `transfer`/`send` / `delegatecall` / `selfdestruct`** in `src/`.

### Non-blocking observations (phase 8 / v2)

| # | Observation | Severity | Suggested action |
|---|-------------|-----------|-----------------|
| 1 | ~~`burn` stub~~ | Resolved | `burn` + e2e unlock |
| 2 | ~~NatSpec / gas snapshot~~ | Resolved P8 | `GAS-EN.md` + `.gas-snapshot` + Deploy |
| 3 | Relayer trust | Info (design) | Multisig / documented rotation |
| 4 | Signature loop without hard cap | Info | Caller pays gas; optional `maxSignatures` |

---

## SWC → tests mapping

| SWC | Test(s) |
|-----|---------|
| SWC-101 | `testFuzz_deposit_locksExactAmount`, `testFuzz_release_mintsExactAmountAndNonceUnique` |
| SWC-103 | Fixed compiler (`forge build`) |
| SWC-104 | Unit deposit; `test_execute_revertsExecutionFailed` |
| SWC-107 | `test/attack/ReentrancyAttack.t.sol`, `RelayReentrancyAttack.t.sol` |
| SWC-113 | `test_execute_revertsExecutionFailed` |
| SWC-117 | `test_release_revertsMalformedV`, `MalformedSignatureLength` |
| SWC-121 | `Replay.t.sol`, `SignatureReplayAttack.t.sol`, fuzz nonce unique |
| SWC-122 | `InvalidSignature.t.sol`, `TargetSpoofAttack.t.sol` |
| SWC-123 | unit + fuzz + attack |
| SWC-133 | `BridgeHash.t.sol` |

---

## Execution result

```text
forge test --summary
BridgeTest                    5 PASS
BridgeHashTest                4 PASS
ReplayTest                    4 PASS
InvalidSignatureTest          9 PASS
MessageRelayTest              6 PASS
BridgeFuzzTest                6 PASS (1000 runs each)
ReentrancyAttackTest          2 PASS
RelayReentrancyAttackTest     1 PASS
TargetSpoofAttackTest         4 PASS
SignatureReplayAttackTest     2 PASS
Total: 51 PASS / 0 FAIL / 0 SKIP
```

---

## References

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [EIP-712](https://eips.ethereum.org/EIPS/eip-712)
- Module 08: [`08-flash-loans/doc/SWC-AUDIT-EN.md`](../../08-flash-loans/doc/SWC-AUDIT-EN.md)
- Plan: [`PLANIFICACION-EN.md`](./PLANIFICACION-EN.md)

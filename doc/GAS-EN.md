# Gas optimization — Cross-Chain Bridge & Message Relay

🌐 [Español](./GAS-ES.md) · **English**

Regenerate:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract BridgeGasTest --gas-report
forge snapshot --match-contract BridgeGasTest
```

**Baseline date:** 2026-09-06 (Phase 8, post-optimization)  
**Snapshot:** `.gas-snapshot` (`test/gas/Bridge.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000` (prioritizes runtime over deploy)

---

## Snapshot comparison (before → after)

| Test | Before | After | Δ |
|------|-------|---------|---|
| `testGas_deposit` | 77 709 | **77 343** | −366 |
| `testGas_release_mint` | 171 298 | **169 945** | −1 353 |
| `testGas_release_secondNonce_warmBitmap` | 221 138 | **196 620** | **−24 518 (−11.1%)** |
| `testGas_execute_relay` | 79 629 | **78 700** | −929 |
| `testGas_processedNonces_view` | 7 888 | 7 957 | +69 (getter via bitmap) |

> The biggest savings are in sequential releases: the **nonce bitmap** reuses the same SSTORE slot (256 nonces/word).

---

## Deploy (gas-report)

| Contract | Deploy cost | Size (B) | Notes |
|----------|--------------|----------|-------|
| `Bridge` | ~2 369 077 | ~12 321 | Includes deploy of `BridgeToken` + inlined libs |
| `MessageRelay` | ~1 345 792 | ~6 969 | EIP-712 + RelayerSig + NonceBitmap |

Deploy cost goes up vs pre-opt (`optimizer_runs` 200 → 10 000 + lib code). Deliberate tradeoff: cheaper `release`/`execute` hot path.

---

## Main functions (gas-report medians)

| Function | Contract | Median | Min | Notes |
|---------|----------|--------|-----|-------|
| `deposit` | Bridge | **85 078** | 50 878 | ERC-20 lock + event |
| `release` | Bridge | **112 786** | **61 498** | Min = nonce in warm word |
| `execute` | MessageRelay | **89 361** | 89 361 | 1 signature + target `call` |
| `processedNonces` | Bridge | **2 706** | — | View over bitmap |
| `bridgeToken` | Bridge | **291** | — | `immutable` |

---

## Applied optimizations (Phase 8)

| Technique | Where | Effect |
|---------|-------|--------|
| **Nonce bitmap** (256/slot) | `NonceBitmap` · Bridge · MessageRelay | −11% on 2nd release; warm SSTORE |
| **Fast path `threshold == 1`** | `RelayerSig` | No `address[] seen` allocation in the 1-of-N case |
| **EIP-712 hash from `calldata`** | `BridgeHash.hash(calldata)` | Avoids copying the struct to memory |
| **Typed `BridgeToken.mint`** | `_mintOrUnlock` | No cast to a generic interface |
| **Custom errors** | All of `src/` | Less calldata than `require` strings |
| **`immutable` `bridgeToken` / `bridge`** | Bridge · BridgeToken | No SLOAD in the mint path |
| **`unchecked ++`** | RelayerSig loops | Fewer overflow checks |
| **`optimizer_runs = 10_000`** | `foundry.toml` | Aggressive inlining in hot paths |

---

## Accepted tradeoffs

| Decision | Why |
|---------|---------|
| More expensive deploy | `release`/`execute` runtime dominates the bridge's operating cost |
| Bitmap vs `mapping => bool` | Deposit nonces are sequential → excellent locality |
| OZ `SafeERC20` / `ECDSA` / `EIP712` | Security and suite consistency > micro-savings |
| `burn` + unlock | Complete (CEI + e2e) | See `test_burn_e2e_unlockUnderlying` |
| Fast path only for `threshold == 1` | Simple test/prod case; N-of-M keeps the full logic |

---

## Relationship with security

The optimizations do **not** weaken CEI / `nonReentrant` / anti-replay:

- The bitmap marks the nonce **before** mint/`call` (same CEI order).
- `RelayerSig` still requires `isRelayer` signers and the threshold.
- See [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md).

# Technical guide — Cross-Chain Bridge & Message Relay

🌐 [Español](./GUIA-TECNICA-ES.md) · **English**

A document to understand **what was decided**, **how the logic flows** and **where gas can still be saved**.  
Complements: [`PLANIFICACION-EN.md`](./PLANIFICACION-EN.md) · [`GAS-EN.md`](./GAS-EN.md) · [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) · diagrams.

---

## 1. In one sentence

It is a **lock/mint** and **burn/unlock** bridge plus a generic **MessageRelay**: on the source chain tokens are locked or burned; a relayer signs an **EIP-712** message; on the destination chain the signature is verified (N-of-M threshold), the nonce is marked, and tokens are minted, unlocked, or a `call` is executed.

There is no light client or block inclusion proof: on-chain cryptographic security is **trust in the relayer set + anti-replay**.

---

## 2. Technical decisions (why it is built this way)

### 2.1 Architecture: one “mirror” contract per chain

| Decision | Discarded alternative | Reason |
|----------|------------------------|--------|
| Same `Bridge` bytecode on source and destination | Separate Source/Dest contracts | A single codebase; the role comes from usage (`deposit`/`burn` vs `release`) |
| `BridgeToken` deployed in the Bridge constructor | External token with `setBridge` | `immutable bridge` with no chicken-and-egg problem or setter |
| Separate `MessageRelay` | Putting generic messages into Bridge | Different surfaces: tokens vs arbitrary `call` |

In Foundry tests, two chains are simulated with `vm.chainId` over the same deployment.

### 2.2 Crypto: EIP-712 + ECDSA (OpenZeppelin)

| Decision | Reason |
|----------|--------|
| Typed EIP-712 (`BridgeMessage` / `RelayMessage`) | Domain separator per chain + contract; anti-replay across domains |
| Fields in the hash: `sourceChainId`, `destinationChainId`, `nonce`, `target`, + payload | A signature is not valid on another network, another contract or for another amount |
| Bridge domain: `("CrossChainBridge", "1")` | Different from the Relay `("MessageRelay", "1")` → signatures cannot be mixed |
| OZ `ECDSA.tryRecover` | Rejects malleability (s/v); broken signatures do not revert with an opaque panic |
| N-of-M threshold (`isRelayer` + `relayerThreshold`) | 1 signature in the demo; N distinct signatures in prod |

We do **not** use Merkle/light client: out of v1 scope (see planning).

### 2.3 Nonces: bitmap instead of `mapping => bool`

| Decision | Reason |
|----------|--------|
| `processedNonces` via **bitmap** (256 nonces per slot) | Deposit nonces are sequential → the 2nd `release` reuses the same slot (warm SSTORE) |
| Nonce assigned on source (`nextDepositNonce++`) and consumed on destination | The `Deposit`/`Burn` event carries the nonce the relayer signs |
| Mark nonce **before** mint/`call` (CEI) | Prevents double minting on reentrancy; if the `call` fails, the whole tx reverts, including the bit |

### 2.4 Token flows

| Flow | Source | Destination (`release`) |
|-------|--------|---------------------|
| **Lock → mint** | `deposit`: lock ERC-20 | `token == bridgeToken` → `mint` |
| **Burn → unlock** | `burn`: burn wrapped | `token == underlying` → `safeTransfer` |

Rule in `_mintOrUnlock`: if the message token is the wrapped one → mint; otherwise → unlock from custody.

### 2.5 Security / suite style

| Decision | Reason |
|----------|--------|
| Exact `pragma solidity 0.8.24` | No floating pragma (SWC-103) |
| Custom errors | Less gas than `require("…")` |
| `ReentrancyGuard` on deposit/burn/release/execute | SWC-107; covered in `test/attack/` |
| `SafeERC20` | SWC-104 |
| `Ownable2Step` for relayer admin | Two-step ownership transfer |
| Phased TDD + fuzz ≥ 1000 + SWC-AUDIT | Monorepo criteria |

### 2.6 Gas / tooling

| Decision | Reason |
|----------|--------|
| `optimizer_runs = 10_000` | Prioritizes `release`/`execute` **runtime** (deploy cost goes up) |
| Internal libs `BridgeHash`, `NonceBitmap`, `RelayerSig` | Reuse Bridge ↔ Relay; threshold-1 fast path |
| EIP-712 hash from **calldata** | Avoids copying the struct to memory |

---

## 3. System logic

### 3.1 Actors

```
User ──deposit/burn──► Bridge (source) ──event──► Relayer(s)
                                                      │
                                                 EIP-712 signature
                                                      │
User ◄──mint/unlock── Bridge (destination) ◄──release─┘
```

- **User:** provides or recovers tokens.  
- **Relayer(s):** off-chain; sign the digest; anyone can submit `release`/`execute` on-chain.  
- **Owner:** manages `isRelayer` and the threshold.

### 3.2 Lock → mint (happy path)

1. User on chain A calls `deposit(token, amount, destChainId, recipient)`.  
2. Checks: amount > 0, addresses ≠ 0, `destChainId ≠ block.chainid`.  
3. Effects: `nonce = nextDepositNonce++`, emits `Deposit`.  
4. Interaction: `safeTransferFrom` → tokens remain in the Bridge.  
5. Relayer builds `BridgeMessage` (includes `sourceChainId=A`, `destinationChainId=B`, `nonce`, `target=BridgeB`, `token=bridgeToken`, `amount`, `recipient`).  
6. Signs the EIP-712 digest of the **Bridge domain on B**.  
7. On chain B: `release(message, signatures)`.  
8. Checks: `destinationChainId == block.chainid`, `target == this`, nonce unused, signature threshold.  
9. Effects: marks the nonce in the bitmap.  
10. Interaction: `BridgeToken.mint(recipient, amount)`.  
11. Emits `Released`.

### 3.3 Burn → unlock

1. User holding wrapped tokens on B calls `burn(amount, destChainId=A, recipient)`.  
2. Same CEI: nonce + `Burn` → `BridgeToken.burn(msg.sender, amount)`.  
3. Relayer signs a message with `token = underlying` (the ERC-20 held in custody on A).  
4. On A: `release` → `_mintOrUnlock` does a `safeTransfer` of the underlying to the recipient.

### 3.4 MessageRelay

Same anti-replay/signature idea, but the effect is:

```text
target.call(payload)
```

If the `call` fails → `ExecutionFailed` and **the whole tx reverts** (including the nonce bit).

### 3.5 What the contract rejects (summary)

| Situation | Typical error |
|-----------|--------------|
| Same signature / same nonce again | `NonceAlreadyUsed` |
| `destinationChainId ≠ block.chainid` | `InvalidChainId` |
| `target ≠ address(this)` (Bridge only) | `InvalidTarget` |
| Non-relayer signer / tampered payload / broken signature | `InvalidSignature` |
| Fewer unique signatures than the threshold | `ThresholdNotMet` |
| Reentrancy in deposit/release/execute | `ReentrancyGuard` |
| Amount 0 | `ZeroAmount` |

---

## 4. Can the gas of the existing code be improved?

Yes. The current code is already optimized on the “reasonable” hot path; below are **possible** improvements, at a cost in complexity or security.

### 4.1 Already applied (baseline)

See [`GAS-EN.md`](./GAS-EN.md): bitmap (−11% on 2nd release), threshold-1 fast path, calldata hash, immutables, custom errors, `optimizer_runs = 10_000`.

### 4.2 Feasible additional improvements

| Idea | Expected savings | Risk / cost |
|------|-----------------|----------------|
| **Assembly** in `BridgeHash` (encode + keccak without intermediate `abi.encode`) | Low–medium on `release` | Harder to audit; forge-lint already suggests it |
| **Pack admin storage**: `relayerThreshold` as `uint64`/`uint128` next to another field | Low (few writes) | Little impact on the hot path |
| **Transient storage** (Cancun) for a custom reentrancy lock | Low–medium vs classic OZ guard | The custom guard must be maintained/audited |
| **Compact signatures** (only `r,s` + `v` in short bytes / EIP-2098) | Less calldata | Wallet/tooling compatibility |
| **Lower `optimizer_runs`** if deploy is the bottleneck | Cheaper deploy | `release` runtime may go up |
| **External library** for RelayerSig (not inlined) | Smaller deploy bytecode | +DELEGATECALL cost on every verify |
| **Emit less “fat” events** or index fewer fields | Low | Worse DX/off-chain indexers |
| **Permit + deposit** in a single tx (EIP-2612 on underlying) | UX; not always less total gas | Only if the token supports it |

### 4.3 What you should **not** “optimize” blindly

| Temptation | Why not |
|-----------|------------|
| Remove CEI / mark the nonce after the mint | Double mint under reentrancy |
| Remove fields from the EIP-712 hash | Cross-chain replay |
| ETH `transfer`/`send` or unchecked returns | Breaks SWC / suite rules |
| Go back to a “simpler” `bool` mapping | Worse gas for sequential nonces |
| Trust a single relayer without documenting trust | Design risk, not a gas issue |

### 4.4 Suggested order if iterating on gas

1. Measure again: `forge test --match-contract BridgeGasTest --gas-report`.  
2. Profile only `release` (it is the expensive hot path: ecrecover + mint).  
3. Try assembly in `BridgeHash` with digest equality tests.  
4. Revisit the `optimizer_runs` tradeoff depending on whether you redeploy often or execute often.

---

## 5. File mind map

```text
src/
  Bridge.sol          → deposit / burn / release
  MessageRelay.sol    → execute
  BridgeToken.sol     → mint/burn onlyBridge
  libraries/
    BridgeHash.sol    → EIP-712 structHash
    NonceBitmap.sol   → processed nonces
    RelayerSig.sol    → signature threshold
```

Key tests: e2e (`Bridge.t.sol`), replay, invalid signatures, MessageRelay, fuzz, `test/attack/`, gas.

---

## 6. Executive summary

1. **Decisions:** mirror bridge + EIP-712/ECDSA + relayer threshold + nonce bitmap + CEI/`nonReentrant` + OZ SafeERC20; no light client in v1.  
2. **Logic:** source assigns the nonce and moves supply (lock/burn) → relayer signs → destination verifies and mints/unlocks/calls.  
3. **Gas:** there is already a big win on sequential releases; the next realistic jump is micro-optimizing hashing (assembly) or signature calldata, without touching the security model.

If you want to dig deeper into a single topic in a future doc: **EIP-712 anti-replay**, **bitmap**, or the **burn→unlock flow** step by step with test values.

# Planning — Module 09: Cross-Chain Bridge & Message Relay

🌐 [Español](./PLANIFICACION-ES.md) · **English**

**Status:** Phases **0–8** ✅ — module complete (gas + NatSpec + Deploy + optimization).

## 1. Project goal

Build a secure **cross-chain token bridge** and **message relayer**: lock or burn assets on the source chain, generate an ECDSA (EIP-712) cryptographic proof and, on the destination chain, mint or unlock the equivalent after signature verification, anti-replay checks and nonces. Stack: Foundry and Solidity `0.8.24`.

### Core capabilities

- **Lock/burn** mechanics on the source chain and **mint/unlock** on the destination chain.
- ECDSA verification with OpenZeppelin `ECDSA` / `SignatureChecker` and **EIP-712** typed hashing.
- EIP-712 domain separation against **cross-chain replay**.
- Processed nonces per `sourceChainId` and `nonce` (`mapping(uint256 => mapping(uint256 => bool)) processedNonces`).
- Threshold / relayer set validation before `mint` or `unlock`.
- Foundry tests: e2e deposit → `vm.sign` → relay, replay, invalid signatures, fuzz.

---

## 2. Scope

### Included

| Area | Description |
|------|-------------|
| Bridge (source) | `deposit` / `lock` ERC-20 or `burn` of wrapped token; emits event with bridgeable payload |
| Bridge (destination) | `release` / `mint` / `unlock` after verifying EIP-712 signature(s) |
| MessageRelay | Generic message relay using the same proof scheme |
| EIP-712 | Typed struct with `sourceChainId`, `destinationChainId`, `nonce`, target, recipient, amount, token |
| Relayer set | Signature threshold (multisig / designated set) before execution |
| Nonces | `processedNonces[sourceChainId][nonce]` — single use |
| Security | `ReentrancyGuard` / CEI on deposit, burn and release; custom errors |
| Tokens | `BridgeToken` (mintable/burnable controlled by the bridge) + MockERC20 |
| Tests | Unit e2e, replay, signature failure, fuzz amounts/chainIds/nonces |

### Not included (v1)

- Light clients / SPV / zk block-inclusion proofs.
- Production off-chain relayer (only simulated in tests with `vm.sign`).
- Complex multi-token registry (v1: token paired by address or simple mapping).
- On-chain governance of the relayer set beyond `Ownable2Step` admin.
- Next.js frontend (optional later phase).
- Native ETH bridging (WETH as ERC-20 if needed).

---

## 3. Tech stack

| Component | Choice |
|-----------|--------|
| Compiler | `pragma solidity 0.8.24;` (exact, no floating pragma) |
| Framework | Foundry (`forge test`, fuzz ≥ 1000, `vm.sign`, `vm.chainId`) |
| Crypto | OZ `ECDSA`, `SignatureChecker`, `EIP712` |
| Libraries | OpenZeppelin Contracts v5.x (`ReentrancyGuard`, `Ownable2Step`, `SafeERC20`, `ERC20Burnable`) |
| ETH | If applicable: `.call{value: ...}("")` — never `transfer`/`send` |
| Documentation | NatSpec on every public/external API |

---

## 4. Architecture

```
09-cross-chain-bridge/
├── doc/
│   ├── README.md                         # language index
│   ├── README-ES.md / README-EN.md
│   ├── PLANIFICACION-ES.md / -EN.md
│   ├── diagrama-clases-ES.md / -EN.md
│   ├── diagrama-flujo-ES.md / -EN.md
│   ├── flujograma-ES.md / -EN.md
│   └── …                                 # GAS, SWC-AUDIT, GUIA-TECNICA, DEPLOY-TESTNET, SOCIAL (-ES / -EN)
├── src/
│   ├── Bridge.sol                        # lock/burn + mint/unlock + nonces
│   ├── MessageRelay.sol                  # execution of signed generic messages
│   ├── BridgeToken.sol                   # ERC-20 mint/burn bridge-only
│   ├── interfaces/
│   │   ├── IBridge.sol
│   │   ├── IMessageRelay.sol
│   │   └── IBridgeToken.sol
│   ├── libraries/
│   │   └── BridgeHash.sol                # EIP-712 hash of BridgeMessage
│   └── mocks/
│       └── MockERC20.sol
├── test/
│   ├── Bridge.t.sol                      # e2e deposit → sign → release
│   ├── Replay.t.sol                      # chainId / nonce reuse
│   ├── InvalidSignature.t.sol
│   ├── MessageRelay.t.sol
│   └── fuzz/Bridge.fuzz.t.sol
├── script/
│   └── Deploy.s.sol
├── foundry.toml
└── remappings.txt
```

### Roles

| Actor | Responsibility |
|-------|----------------|
| **User** | Deposits/burns on source; receives mint/unlock on destination |
| **Relayer(s)** | Watch events, sign EIP-712 payload, submit `release`/`execute` |
| **Admin / owner** | Manages relayer set, threshold, paired tokens |
| **Bridge (source)** | Holds custody or burns; emits `Deposit` / `Burn` |
| **Bridge (destination)** | Verifies signature + nonce + chainIds; mint or unlock |
| **Attacker (test)** | Replay, forged signature, wrong chainId, reentrancy → must revert |

---

## 5. Data model

```solidity
// EIP-712 typed message (summary)
struct BridgeMessage {
    uint256 sourceChainId;
    uint256 destinationChainId;
    uint256 nonce;
    address target;        // destination bridge contract
    address recipient;
    address token;         // token on destination (or mapping)
    uint256 amount;
}

// Bridge (state summary)
mapping(uint256 => mapping(uint256 => bool)) public processedNonces; // sourceChainId => nonce => used
mapping(address => bool) public isRelayer;
uint256 public relayerThreshold;   // e.g. 1 in tests; N-of-M in prod
uint256 public nextDepositNonce;   // per source chain (or per user depending on design)
address public immutable bridgeToken; // mintable wrapped token on destination
```

### EIP-712 hash (anti-replay fields)

| Field | Why |
|-------|-----|
| `sourceChainId` | Prevents reusing a proof from another source |
| `destinationChainId` | Must match the destination's `block.chainid` |
| `nonce` | Single use per `sourceChainId` |
| `target` | Executable only on the expected bridge contract |
| `recipient` / `token` / `amount` | Transfer payload |

### EIP-712 domain

| Field | Typical value |
|-------|---------------|
| `name` | `"CrossChainBridge"` |
| `version` | `"1"` |
| `chainId` | `block.chainid` of the **verifying** contract (destination) |
| `verifyingContract` | `address(this)` of the destination Bridge |

---

## 6. On-chain API

### Bridge — source

| Function | Visibility | Description |
|----------|------------|-------------|
| `deposit(address token, uint256 amount, uint256 destChainId, address recipient)` | external nonReentrant | Locks ERC-20; assigns nonce; emits `Deposit` |
| `burn(uint256 amount, uint256 destChainId, address recipient)` | external nonReentrant | Burns local wrapped token; emits `Burn` |

### Bridge — destination

| Function | Visibility | Description |
|----------|------------|-------------|
| `release(BridgeMessage msg, bytes[] signatures)` | external nonReentrant | Verifies EIP-712 + threshold; marks nonce; mint/unlock |
| `processedNonces(uint256 sourceChainId, uint256 nonce)` | view | Whether the nonce was already used |
| `isRelayer(address)` / `relayerThreshold()` | view | Set and threshold |

### MessageRelay

| Function | Visibility | Description |
|----------|------------|-------------|
| `execute(RelayMessage msg, bytes[] signatures)` | external nonReentrant | Verifies and executes `call` to the target (generic payload) |

### Custom errors (mandatory)

| Error | Condition |
|-------|-----------|
| `InvalidSignature()` | ECDSA recovery fails or signer is not a relayer |
| `NonceAlreadyUsed()` | `processedNonces[source][nonce] == true` |
| `InvalidChainId()` | `destinationChainId != block.chainid` (or invalid source) |
| `ExecutionFailed()` | Message call / mint-unlock fails |

Additional recommended errors (suite):

| Error | Condition |
|-------|-----------|
| `ZeroAmount()` | amount 0 |
| `ThresholdNotMet()` | valid signatures < threshold |
| `UnauthorizedRelayer()` | admin-only: relayer set |
| `InvalidTarget()` | `msg.target != address(this)` |

### Events

`Deposit` (sender, token, amount, destChainId, recipient, nonce) · `Burn` · `Released` (sourceChainId, nonce, recipient, amount) · `MessageExecuted` · `RelayerUpdated`

---

## 7. Deposit → release logic (CEI)

### Source `deposit` / `burn`

1. **Checks:** `amount > 0`, `destChainId != block.chainid` (optional), `recipient != 0`.
2. **Effects:** `nonce = nextDepositNonce++` (or per-user nonce); emit event with all struct fields.
3. **Interactions:** `SafeERC20.safeTransferFrom` (lock) or `burnFrom` / `burn`.

### Destination `release`

1. **Checks:** `destinationChainId == block.chainid` → otherwise `InvalidChainId`.
2. **Checks:** `target == address(this)` → otherwise `InvalidTarget`.
3. **Checks:** `!processedNonces[sourceChainId][nonce]` → otherwise `NonceAlreadyUsed`.
4. **Checks:** EIP-712 hash + ≥ `relayerThreshold` valid signatures from `isRelayer` → otherwise `InvalidSignature` / `ThresholdNotMet`.
5. **Effects:** `processedNonces[sourceChainId][nonce] = true`.
6. **Interactions:** mint to `recipient` or `safeTransfer` (unlock) → otherwise `ExecutionFailed`.
7. Emit `Released`.

CEI order: mark the nonce **before** the external interaction (mint/transfer).

---

## 8. Implementation phases (TDD)

| Phase | Deliverable | Status |
|-------|-------------|--------|
| **0** | Docs (`doc/`) + Foundry scaffold + interfaces | ✅ |
| **1** | Failing tests: deposit event, EIP-712 hash, happy-path release | ✅ |
| **2** | `BridgeToken` + `Bridge.deposit` / minimal lock | ✅ |
| **3** | `release` with 1 relayer + `vm.sign` e2e | ✅ |
| **4** | Replay: same nonce / different `chainId` → revert | ✅ |
| **5** | Invalid signatures / tamper / malformed v,r,s | ✅ |
| **6** | N-of-M threshold + `MessageRelay.execute` | ✅ |
| **7** | Fuzz amounts, chainIds, nonces (`bound`) + SWC/attack | ✅ |
| **8** | Gas snapshot + NatSpec + `Deploy.s.sol` + optimization | ✅ |

---

## 9. Test plan

| Suite | Location | Coverage |
|-------|----------|----------|
| E2E bridge | `test/Bridge.t.sol` | deposit → sign → release → destination balance |
| Replay | `test/Replay.t.sol` | nonce reuse; different `vm.chainId` |
| Signatures | `test/InvalidSignature.t.sol` | wrong signer, payload tampered, bad v/r/s |
| Relay | `test/MessageRelay.t.sol` | execute message; `ExecutionFailed` |
| Fuzz | `test/fuzz/Bridge.fuzz.t.sol` | `bound` amount/chainId/nonce |
| Attack | `test/attack/` | reentrancy on release, target spoof |

Invariant: a successful `release` marks the nonce; a second attempt with the same proof **always** reverts with `NonceAlreadyUsed`.

---

## 10. Acceptance criteria

- [x] Foundry scaffold (`0.8.24`, fuzz ≥ 1000)
- [x] Message struct includes `sourceChainId`, `destinationChainId`, `nonce`, `target`
- [x] EIP-712 + ECDSA with OZ; domain bound to the destination contract
- [x] `processedNonces[sourceChainId][nonce]` prevents double spending
- [x] Custom errors: `InvalidSignature`, `NonceAlreadyUsed`, `InvalidChainId`, `ExecutionFailed`
- [x] Relayer threshold before mint/unlock
- [x] `ReentrancyGuard` / CEI on deposit, burn, release
- [x] E2E test with `vm.sign`
- [x] Replay and invalid-signature tests with `vm.expectRevert`
- [x] Fuzzing of amounts, chain IDs and nonces
- [x] NatSpec on public/external functions
- [x] CEI + SafeERC20; no ETH `transfer`/`send`
- [x] Gas baseline (`doc/GAS-EN.md` + `.gas-snapshot`)
- [x] `script/Deploy.s.sol` for Anvil
- [x] SWC suite / `test/attack/` + fuzz ≥ 1000

---

## 11. Related documents

| Document | Content |
|----------|---------|
| [diagrama-clases-EN.md](./diagrama-clases-EN.md) | Contract, interface and test UML |
| [diagrama-flujo-EN.md](./diagrama-flujo-EN.md) | Lock/burn → signature → mint/unlock sequence |
| [flujograma-EN.md](./flujograma-EN.md) | Operations, anti-replay, TDD |
| [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md) | SWC-100–136 matrix + mapping to tests |
| [GAS-EN.md](./GAS-EN.md) | Gas baseline, optimizations, snapshot |

---

## 12. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Cross-chain replay | EIP-712 domain + `destinationChainId` + `target` |
| Double mint (same deposit) | `processedNonces` marked before mint |
| Single compromised relayer | N-of-M threshold (`relayerThreshold`) |
| Signature over tampered payload | Full typed hash; tamper test |
| Reentrancy on release | `nonReentrant` + CEI (nonce before transfer) |
| Wrong chain ID on destination | `InvalidChainId` if ≠ `block.chainid` |
| Fee-on-transfer token | v1: standard tokens only; simple mock |

---

## 13. Conventions (suite + Solidity rules)

- Fixed pragma `0.8.24`; layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions (External → Public → Internal → Private).
- NatSpec `@notice` / `@dev` / `@param` / `@return` on the public API.
- Tests first (TDD); `vm.expectRevert` on failure paths.
- Gas: `immutable`/`constant`, custom errors, storage packing where applicable.
- Explain patterns (Bridge lock-mint, burn-unlock, EIP-712) before coding each phase.

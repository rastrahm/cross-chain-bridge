# Project flowchart — Cross-Chain Bridge & Message Relay

🌐 [Español](./flujograma-ES.md) · **English**

**To-be** operational flowchart (v1): setup → deposit/burn → signature → release → anti-replay → security → TDD.

## 1. System master flowchart

```mermaid
flowchart TB
    subgraph SETUP["PHASE 0 — Setup"]
        S1[Foundry 0.8.24 + interfaces] --> S2[Deploy BridgeToken]
        S2 --> S3[Deploy Bridge A/B + EIP-712 domain]
        S3 --> S4[Register relayer + threshold]
        S4 --> S5[User approves ERC-20 to the Bridge]
    end

    subgraph ORIGEN["PHASE 1 — Source"]
        O1[deposit or burn] --> O2{Validations}
        O2 -->|amount 0| Ox1[ZeroAmount]
        O2 -->|OK| O3[Assign nonce + lock/burn]
        O3 --> O4[Emit Deposit/Burn]
    end

    subgraph RELAY["PHASE 2 — Relayer"]
        R1[Read event] --> R2[Build BridgeMessage]
        R2 --> R3[EIP-712 hash]
        R3 --> R4[ECDSA sign N relayers]
    end

    subgraph DESTINO["PHASE 3 — Destination"]
        D1[release message, sigs] --> D2{chainId + target?}
        D2 -->|No| Dx1[InvalidChainId / InvalidTarget]
        D2 -->|Yes| D3{nonce free?}
        D3 -->|No| Dx2[NonceAlreadyUsed]
        D3 -->|Yes| D4{signature threshold OK?}
        D4 -->|No| Dx3[InvalidSignature / ThresholdNotMet]
        D4 -->|Yes| D5[Mark nonce]
        D5 --> D6[Mint or unlock]
        D6 -->|Failure| Dx4[ExecutionFailed]
        D6 -->|OK| D7[Emit Released]
    end

    SETUP --> ORIGEN
    ORIGEN --> RELAY
    RELAY --> DESTINO
    DESTINO --> END1([Recipient holds tokens · nonce consumed])
```

## 2. Detailed anti-replay flowchart

```mermaid
flowchart TD
    Start([Release attempt]) --> A{destinationChainId == block.chainid?}
    A -->|No| F1[InvalidChainId]
    A -->|Yes| B{target == destination Bridge?}
    B -->|No| F2[InvalidTarget]
    B -->|Yes| C{processedNonces source nonce?}
    C -->|true| F3[NonceAlreadyUsed]
    C -->|false| D[Verify signatures over EIP-712 digest]
    D --> E{Does digest include source, dest, nonce, target, amount...?}
    E -->|Incomplete fields = design bug| F4[Replay risk — must not be allowed in implementation]
    E -->|Yes| G[Mark nonce → mint/unlock]
    G --> H([PASS Replay.t.sol on retry])
    F1 --> Z([Revert])
    F2 --> Z
    F3 --> Z
```

The digest **must** include the module's four guard fields: `sourceChainId`, `destinationChainId`, `nonce`, `target`.

## 3. Security flowchart (reentrancy + CEI)

```mermaid
flowchart TD
    A[release with valid signature] --> B[nonReentrant: ENTERED]
    B --> C[Checks: chain, target, nonce, sigs]
    C --> D[Effects: processedNonces = true]
    D --> E[Interactions: mint/transfer]
    E --> F{Malicious callback reenters release?}
    F -->|Yes| G[Revert ReentrancyGuard]
    F -->|No| H[Emit Released + unlock]
    G --> I([Nonce already marked: no double mint even if CEI were misapplied])
    H --> J([Consistent state])
```

Marking the nonce **before** the mint prevents double minting even if reentrancy protection were to fail in a hypothetical scenario.

## 4. Invalid signatures flowchart

```mermaid
flowchart TD
    A([InvalidSignature.t.sol scenario]) --> B{Vector}
    B -->|Signer is not a relayer| C[InvalidSignature / ThresholdNotMet]
    B -->|amount/recipient tampered| D[Different digest → recover fails threshold]
    B -->|malformed v,r,s| E[ECDSA revert or address 0 → InvalidSignature]
    B -->|Threshold 2, only 1 valid signature| F[ThresholdNotMet]
    C --> Z([PASS expectRevert])
    D --> Z
    E --> Z
    F --> Z
```

## 5. Development pipeline flowchart (TDD)

```mermaid
flowchart LR
    A[.cursorrules] --> B[Planning docs + diagrams]
    B --> C[Foundry scaffold + interfaces]
    C --> D[Red e2e tests]
    D --> E[BridgeToken + deposit]
    E --> F[release + vm.sign]
    F --> G[Replay.t.sol]
    G --> H[InvalidSignature.t.sol]
    H --> I[MessageRelay + N-of-M threshold]
    I --> J[Fuzz amount/chainId/nonce]
    J --> K[Gas + NatSpec + Deploy]
    K --> L([Module closed])
```

## 6. Flow ↔ function ↔ invariant matrix

| Flowchart step | Function | Invariant / postcondition |
|---------------------|---------|----------------------------|
| Source lock | `Bridge.deposit` | Bridge balance ↑; event with unique nonce |
| Source burn | `Bridge.burn` | wrapped supply ↓; event |
| Signature | off-chain / `vm.sign` | digest = same on-chain `_hashTypedDataV4` |
| Release OK | `Bridge.release` | `processedNonces` true; recipient ↑ amount |
| Replay | `Bridge.release` | second call → `NonceAlreadyUsed` |
| Wrong chain | `Bridge.release` | `InvalidChainId` |
| Bad signature | `Bridge.release` | `InvalidSignature` / `ThresholdNotMet` |
| Generic message | `MessageRelay.execute` | call OK or `ExecutionFailed`; nonce marked |
| Reentrancy | `release` / `deposit` | second entry reverts |

## 7. Lock-mint vs burn-unlock flowchart

```mermaid
flowchart TD
    subgraph LM["Lock → Mint"]
        L1[Native ERC-20 on source] --> L2[Bridge.deposit lock]
        L2 --> L3[Relayer signs]
        L3 --> L4[Bridge.release mint BridgeToken]
    end

    subgraph BU["Burn → Unlock"]
        B1[BridgeToken on chain B] --> B2[Bridge.burn]
        B2 --> B3[Relayer signs]
        B3 --> B4[Bridge.release unlock ERC-20 on A]
    end

    LM --> T[Same EIP-712 + nonce verification]
    BU --> T
```

## 8. How to read these diagrams

1. **Setup**: wrapped token, Bridge(s), relayers and threshold.
2. **Source**: the user provides liquidity (lock) or burns wrapped tokens; the nonce is recorded in the event.
3. **Relayer**: signs the full EIP-712 struct (not just the hash of the raw event without a domain).
4. **Destination**: validate chain, target, nonce and threshold → mark nonce → mint/unlock.
5. **TDD**: docs → red e2e tests → implementation → replay/signatures → fuzz → closure.

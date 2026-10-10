# Flow diagram — Cross-Chain Bridge & Message Relay

🌐 [Español](./diagrama-flujo-ES.md) · **English**

**To-be** business flows (v1). See also [flujograma-EN.md](./flujograma-EN.md) and [PLANIFICACION-EN.md](./PLANIFICACION-EN.md).

## 1. System lifecycle

```mermaid
flowchart TD
    Start([Start]) --> DeployT[Deploy BridgeToken]
    DeployT --> DeployB[Deploy Bridge on chain A and B]
    DeployB --> Admin[Owner registers relayers + threshold]
    Admin --> Ready[System ready]

    Ready --> Action{Action}
    Action -->|deposit + valid release| Ok[Mint/unlock on destination]
    Action -->|replay nonce| R1[Revert NonceAlreadyUsed]
    Action -->|wrong chainId| R2[Revert InvalidChainId]
    Action -->|invalid signature| R3[Revert InvalidSignature]

    Ok --> Ready
    R1 --> Ready
    R2 --> Ready
    R3 --> Ready
```

## 2. Source flow: `deposit` (lock)

```mermaid
flowchart TD
    A([User calls deposit token, amount, destChainId, recipient]) --> B[nonReentrant ON]
    B --> C{amount > 0?}
    C -->|No| E1[Revert ZeroAmount]
    C -->|Yes| D{recipient != 0?}
    D -->|No| E2[Revert ExecutionFailed or InvalidRecipient]
    D -->|Yes| E[Effects: nonce = nextDepositNonce++]
    E --> F[Interaction: safeTransferFrom user → Bridge]
    F --> G[Emit Deposit sender, token, amount, destChainId, recipient, nonce]
    G --> H[nonReentrant OFF]
    H --> I([Tokens locked; event ready for relayer])
```

## 3. Source flow: `burn` (wrapped → another chain)

```mermaid
flowchart TD
    A([User calls burn amount, destChainId, recipient]) --> B[nonReentrant ON]
    B --> C{amount > 0?}
    C -->|No| E1[Revert ZeroAmount]
    C -->|Yes| D[Effects: nonce = nextDepositNonce++]
    D --> E[Interaction: BridgeToken.burn user, amount]
    E --> F[Emit Burn]
    F --> G[nonReentrant OFF]
    G --> H([Local supply ↓; event for unlock/mint on destination])
```

## 4. Off-chain flow: EIP-712 signature (relayer / test)

```mermaid
flowchart TD
    A([Relayer observes Deposit/Burn]) --> B[Builds BridgeMessage]
    B --> C[sourceChainId, destinationChainId, nonce, target, recipient, token, amount]
    C --> D[digest = EIP712 hashTypedDataV4 structHash]
    D --> E[ECDSA signature: vm.sign or relayer wallet]
    E --> F([message + signatures ready for release])
```

In Foundry: `digest` is computed exactly as on-chain; `(v, r, s) = vm.sign(relayerPk, digest)`.

## 5. Destination flow: `release` (mint / unlock)

```mermaid
flowchart TD
    A([Anyone calls release message, signatures]) --> B[nonReentrant ON]
    B --> C{destinationChainId == block.chainid?}
    C -->|No| E1[Revert InvalidChainId]
    C -->|Yes| D{target == address this?}
    D -->|No| E2[Revert InvalidTarget]
    D -->|Yes| F{processedNonces source nonce?}
    F -->|Already used| E3[Revert NonceAlreadyUsed]
    F -->|Free| G[digest = _hashTypedDataV4]
    G --> H[_verifySignatures: recover ∈ isRelayer]
    H --> I{valid signatures >= threshold?}
    I -->|No| E4[Revert InvalidSignature / ThresholdNotMet]
    I -->|Yes| J[Effects: processedNonces source nonce = true]
    J --> K{mode?}
    K -->|mint wrapped| L[BridgeToken.mint recipient, amount]
    K -->|unlock locked| M[safeTransfer token → recipient]
    L --> N{OK?}
    M --> N
    N -->|No| E5[Revert ExecutionFailed]
    N -->|Yes| O[Emit Released]
    O --> P[nonReentrant OFF]
    P --> Q([User receives tokens on destination])
```

## 6. E2E flow (Foundry test)

```mermaid
flowchart LR
    subgraph ORIGEN["Source chain / setUp"]
        U[User deposit]
        Ev[Deposit event]
    end

    subgraph FIRMA["Test harness"]
        H[Compute EIP-712 digest]
        S[vm.sign relayerPk]
    end

    subgraph DESTINO["Destination chain / same or 2nd deploy"]
        R[release message, sig]
        Bal[assert balance recipient]
    end

    U --> Ev --> H --> S --> R --> Bal
```

## 7. Anti-replay flow

```mermaid
flowchart TD
    A([First valid release]) --> B[processedNonces = true]
    B --> C[Mint/unlock OK]

    D([Same message + same signatures again]) --> E{nonce used?}
    E -->|Yes| F[Revert NonceAlreadyUsed]

    G([Same signature but different destinationChainId]) --> H{chainid matches?}
    H -->|No| I[Revert InvalidChainId]

    J([Payload amount tampered, same signature]) --> K[recover ≠ relayer or different digest]
    K --> L[Revert InvalidSignature]
```

## 8. MessageRelay.execute flow

```mermaid
flowchart TD
    A([execute RelayMessage, signatures]) --> B[Validate chainId + nonce + signatures]
    B --> C{OK?}
    C -->|No| E1[InvalidChainId / NonceAlreadyUsed / InvalidSignature]
    C -->|Yes| D[Effects: mark nonce]
    D --> E[Interaction: target.call payload]
    E --> F{success?}
    F -->|No| E2[Revert ExecutionFailed]
    F -->|Yes| G[Emit MessageExecuted]
```

## 9. Relayer authentication flow

```mermaid
flowchart TD
    A([Verify each signature]) --> B[signer = ECDSA.recover digest, sig]
    B --> C{isRelayer signer?}
    C -->|No| D[Ignore / does not count toward threshold]
    C -->|Yes| E[Count unique signer]
    E --> F{count >= relayerThreshold?}
    F -->|No| G[Revert ThresholdNotMet]
    F -->|Yes| H([Continue effects])
```

Duplicate signatures from the same relayer must not count twice toward the threshold.

## Legend

| Symbol | Meaning |
|---------|-------------|
| Rectangle | On-chain process / action |
| Diamond | Decision / validation |
| Oval | Start / end |

## CEI order

| Step | `deposit` / `burn` | `release` |
|------|--------------------|-----------|
| **Checks** | amount, recipient | chainId, target, free nonce, signatures |
| **Effects** | increment deposit nonce | `processedNonces[...] = true` |
| **Interactions** | transferFrom / burn | mint / transfer / call |
| **Final checks** | — | mint/transfer success or `ExecutionFailed` |

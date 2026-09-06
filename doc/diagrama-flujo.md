# Diagrama de flujo — Cross-Chain Bridge & Message Relay

Flujos de negocio **to-be** (v1). Ver también [flujograma.md](./flujograma.md) y [PLANIFICACION.md](./PLANIFICACION.md).

## 1. Ciclo de vida del sistema

```mermaid
flowchart TD
    Start([Inicio]) --> DeployT[Deploy BridgeToken]
    DeployT --> DeployB[Deploy Bridge en cadena A y B]
    DeployB --> Admin[Owner registra relayers + umbral]
    Admin --> Ready[Sistema listo]

    Ready --> Action{Acción}
    Action -->|deposit + release válido| Ok[Mint/unlock en destino]
    Action -->|replay nonce| R1[Revert NonceAlreadyUsed]
    Action -->|chainId incorrecto| R2[Revert InvalidChainId]
    Action -->|firma inválida| R3[Revert InvalidSignature]

    Ok --> Ready
    R1 --> Ready
    R2 --> Ready
    R3 --> Ready
```

## 2. Flujo origen: `deposit` (lock)

```mermaid
flowchart TD
    A([Usuario llama deposit token, amount, destChainId, recipient]) --> B[nonReentrant ON]
    B --> C{amount > 0?}
    C -->|No| E1[Revert ZeroAmount]
    C -->|Sí| D{recipient != 0?}
    D -->|No| E2[Revert ExecutionFailed o InvalidRecipient]
    D -->|Sí| E[Effects: nonce = nextDepositNonce++]
    E --> F[Interaction: safeTransferFrom user → Bridge]
    F --> G[Emit Deposit sender, token, amount, destChainId, recipient, nonce]
    G --> H[nonReentrant OFF]
    H --> I([Tokens bloqueados; evento listo para relayer])
```

## 3. Flujo origen: `burn` (wrapped → otra cadena)

```mermaid
flowchart TD
    A([Usuario llama burn amount, destChainId, recipient]) --> B[nonReentrant ON]
    B --> C{amount > 0?}
    C -->|No| E1[Revert ZeroAmount]
    C -->|Sí| D[Effects: nonce = nextDepositNonce++]
    D --> E[Interaction: BridgeToken.burn user, amount]
    E --> F[Emit Burn]
    F --> G[nonReentrant OFF]
    G --> H([Supply local ↓; evento para unlock/mint en destino])
```

## 4. Flujo off-chain: firma EIP-712 (relayer / test)

```mermaid
flowchart TD
    A([Relayer observa Deposit/Burn]) --> B[Construye BridgeMessage]
    B --> C[sourceChainId, destinationChainId, nonce, target, recipient, token, amount]
    C --> D[digest = EIP712 hashTypedDataV4 structHash]
    D --> E[Firma ECDSA: vm.sign o wallet relayer]
    E --> F([message + signatures listos para release])
```

En Foundry: `digest` se calcula igual que on-chain; `(v, r, s) = vm.sign(relayerPk, digest)`.

## 5. Flujo destino: `release` (mint / unlock)

```mermaid
flowchart TD
    A([Cualquiera llama release message, signatures]) --> B[nonReentrant ON]
    B --> C{destinationChainId == block.chainid?}
    C -->|No| E1[Revert InvalidChainId]
    C -->|Sí| D{target == address this?}
    D -->|No| E2[Revert InvalidTarget]
    D -->|Sí| F{processedNonces source nonce?}
    F -->|Ya usado| E3[Revert NonceAlreadyUsed]
    F -->|Libre| G[digest = _hashTypedDataV4]
    G --> H[_verifySignatures: recover ∈ isRelayer]
    H --> I{firmas válidas >= threshold?}
    I -->|No| E4[Revert InvalidSignature / ThresholdNotMet]
    I -->|Sí| J[Effects: processedNonces source nonce = true]
    J --> K{modo?}
    K -->|mint wrapped| L[BridgeToken.mint recipient, amount]
    K -->|unlock locked| M[safeTransfer token → recipient]
    L --> N{OK?}
    M --> N
    N -->|No| E5[Revert ExecutionFailed]
    N -->|Sí| O[Emit Released]
    O --> P[nonReentrant OFF]
    P --> Q([Usuario recibe tokens en destino])
```

## 6. Flujo e2e (test Foundry)

```mermaid
flowchart LR
    subgraph ORIGEN["Cadena origen / setUp"]
        U[Usuario deposit]
        Ev[Evento Deposit]
    end

    subgraph FIRMA["Test harness"]
        H[Calcular digest EIP-712]
        S[vm.sign relayerPk]
    end

    subgraph DESTINO["Cadena destino / mismo o 2do deploy"]
        R[release message, sig]
        Bal[assert balance recipient]
    end

    U --> Ev --> H --> S --> R --> Bal
```

## 7. Flujo anti-replay

```mermaid
flowchart TD
    A([Primera release válida]) --> B[processedNonces = true]
    B --> C[Mint/unlock OK]

    D([Misma message + mismas firmas otra vez]) --> E{nonce usado?}
    E -->|Sí| F[Revert NonceAlreadyUsed]

    G([Misma firma pero destinationChainId distinto]) --> H{chainid coincide?}
    H -->|No| I[Revert InvalidChainId]

    J([Payload amount alterado, misma firma]) --> K[recover ≠ relayer o digest distinto]
    K --> L[Revert InvalidSignature]
```

## 8. Flujo MessageRelay.execute

```mermaid
flowchart TD
    A([execute RelayMessage, signatures]) --> B[Validar chainId + nonce + firmas]
    B --> C{OK?}
    C -->|No| E1[InvalidChainId / NonceAlreadyUsed / InvalidSignature]
    C -->|Sí| D[Effects: marcar nonce]
    D --> E[Interaction: target.call payload]
    E --> F{success?}
    F -->|No| E2[Revert ExecutionFailed]
    F -->|Sí| G[Emit MessageExecuted]
```

## 9. Flujo de autenticación de relayers

```mermaid
flowchart TD
    A([Verificar cada signature]) --> B[signer = ECDSA.recover digest, sig]
    B --> C{isRelayer signer?}
    C -->|No| D[Ignorar / no cuenta al umbral]
    C -->|Sí| E[Contar firmante único]
    E --> F{count >= relayerThreshold?}
    F -->|No| G[Revert ThresholdNotMet]
    F -->|Sí| H([Continuar effects])
```

Firmas duplicadas del mismo relayer no deben contar dos veces hacia el umbral.

## Leyenda

| Símbolo | Significado |
|---------|-------------|
| Rectángulo | Proceso / acción on-chain |
| Diamante | Decisión / validación |
| Óvalo | Inicio / fin |

## Orden CEI

| Paso | `deposit` / `burn` | `release` |
|------|--------------------|-----------|
| **Checks** | amount, recipient | chainId, target, nonce libre, firmas |
| **Effects** | incrementar nonce depósito | `processedNonces[...] = true` |
| **Interactions** | transferFrom / burn | mint / transfer / call |
| **Checks finales** | — | éxito de mint/transfer o `ExecutionFailed` |

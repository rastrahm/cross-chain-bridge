# Flujograma del proyecto — Cross-Chain Bridge & Message Relay

Flujograma operativo **to-be** (v1): setup → deposit/burn → firma → release → anti-replay → seguridad → TDD.

## 1. Flujograma maestro del sistema

```mermaid
flowchart TB
    subgraph SETUP["FASE 0 — Setup"]
        S1[Foundry 0.8.24 + interfaces] --> S2[Deploy BridgeToken]
        S2 --> S3[Deploy Bridge A/B + EIP-712 domain]
        S3 --> S4[Registrar relayer + threshold]
        S4 --> S5[Usuario aprueba ERC-20 al Bridge]
    end

    subgraph ORIGEN["FASE 1 — Origen"]
        O1[deposit o burn] --> O2{Validaciones}
        O2 -->|amount 0| Ox1[ZeroAmount]
        O2 -->|OK| O3[Asignar nonce + lock/burn]
        O3 --> O4[Emit Deposit/Burn]
    end

    subgraph RELAY["FASE 2 — Relayer"]
        R1[Leer evento] --> R2[Armar BridgeMessage]
        R2 --> R3[Hash EIP-712]
        R3 --> R4[Firmar ECDSA N relayers]
    end

    subgraph DESTINO["FASE 3 — Destino"]
        D1[release message, sigs] --> D2{chainId + target?}
        D2 -->|No| Dx1[InvalidChainId / InvalidTarget]
        D2 -->|Sí| D3{nonce libre?}
        D3 -->|No| Dx2[NonceAlreadyUsed]
        D3 -->|Sí| D4{umbral firmas OK?}
        D4 -->|No| Dx3[InvalidSignature / ThresholdNotMet]
        D4 -->|Sí| D5[Marcar nonce]
        D5 --> D6[Mint o unlock]
        D6 -->|Fallo| Dx4[ExecutionFailed]
        D6 -->|OK| D7[Emit Released]
    end

    SETUP --> ORIGEN
    ORIGEN --> RELAY
    RELAY --> DESTINO
    DESTINO --> END1([Recipient con tokens · nonce consumido])
```

## 2. Flujograma detallado anti-replay

```mermaid
flowchart TD
    Start([Intento de release]) --> A{destinationChainId == block.chainid?}
    A -->|No| F1[InvalidChainId]
    A -->|Sí| B{target == Bridge destino?}
    B -->|No| F2[InvalidTarget]
    B -->|Sí| C{processedNonces source nonce?}
    C -->|true| F3[NonceAlreadyUsed]
    C -->|false| D[Verificar firmas sobre digest EIP-712]
    D --> E{¿Digest incluye source, dest, nonce, target, amount...?}
    E -->|Campos incompletos = bug de diseño| F4[Riesgo de replay — no permitir en implementación]
    E -->|Sí| G[Marcar nonce → mint/unlock]
    G --> H([PASS Replay.t.sol en reintento])
    F1 --> Z([Revert])
    F2 --> Z
    F3 --> Z
```

El digest **debe** incluir los cuatro campos de guarda del módulo: `sourceChainId`, `destinationChainId`, `nonce`, `target`.

## 3. Flujograma de seguridad (reentrancy + CEI)

```mermaid
flowchart TD
    A[release con firma válida] --> B[nonReentrant: ENTERED]
    B --> C[Checks: chain, target, nonce, sigs]
    C --> D[Effects: processedNonces = true]
    D --> E[Interactions: mint/transfer]
    E --> F{Callback malicioso reentra release?}
    F -->|Sí| G[Revert ReentrancyGuard]
    F -->|No| H[Emit Released + unlock]
    G --> I([Nonce ya marcado: no doble mint si se usara CEI incorrecto])
    H --> J([Estado consistente])
```

Marcar el nonce **antes** del mint evita doble acuñación aunque falle la protección de reentrada en un escenario hipotético.

## 4. Flujograma firmas inválidas

```mermaid
flowchart TD
    A([Escenario InvalidSignature.t.sol]) --> B{Vector}
    B -->|Firmante no es relayer| C[InvalidSignature / ThresholdNotMet]
    B -->|amount/recipient alterados| D[Digest distinto → recover falla umbral]
    B -->|v,r,s malformados| E[ECDSA revert o address 0 → InvalidSignature]
    B -->|Umbral 2, solo 1 firma válida| F[ThresholdNotMet]
    C --> Z([PASS expectRevert])
    D --> Z
    E --> Z
    F --> Z
```

## 5. Flujograma del pipeline de desarrollo (TDD)

```mermaid
flowchart LR
    A[.cursorrules] --> B[Docs planificación + diagramas]
    B --> C[Scaffold Foundry + interfaces]
    C --> D[Tests e2e rojos]
    D --> E[BridgeToken + deposit]
    E --> F[release + vm.sign]
    F --> G[Replay.t.sol]
    G --> H[InvalidSignature.t.sol]
    H --> I[MessageRelay + umbral N-of-M]
    I --> J[Fuzz amount/chainId/nonce]
    J --> K[Gas + NatSpec + Deploy]
    K --> L([Módulo cerrado])
```

## 6. Matriz flujo ↔ función ↔ invariante

| Paso del flujograma | Función | Invariante / postcondición |
|---------------------|---------|----------------------------|
| Lock origen | `Bridge.deposit` | balance Bridge ↑; evento con nonce único |
| Burn origen | `Bridge.burn` | supply wrapped ↓; evento |
| Firma | off-chain / `vm.sign` | digest = mismo `_hashTypedDataV4` on-chain |
| Release OK | `Bridge.release` | `processedNonces` true; recipient ↑ amount |
| Replay | `Bridge.release` | segundo call → `NonceAlreadyUsed` |
| Chain wrong | `Bridge.release` | `InvalidChainId` |
| Firma bad | `Bridge.release` | `InvalidSignature` / `ThresholdNotMet` |
| Mensaje genérico | `MessageRelay.execute` | call OK o `ExecutionFailed`; nonce marcado |
| Reentrada | `release` / `deposit` | segunda entrada revierte |

## 7. Flujograma lock-mint vs burn-unlock

```mermaid
flowchart TD
    subgraph LM["Lock → Mint"]
        L1[ERC-20 nativo en origen] --> L2[Bridge.deposit lock]
        L2 --> L3[Relayer firma]
        L3 --> L4[Bridge.release mint BridgeToken]
    end

    subgraph BU["Burn → Unlock"]
        B1[BridgeToken en cadena B] --> B2[Bridge.burn]
        B2 --> B3[Relayer firma]
        B3 --> B4[Bridge.release unlock ERC-20 en A]
    end

    LM --> T[Misma verificación EIP-712 + nonces]
    BU --> T
```

## 8. Cómo leer estos diagramas

1. **Setup**: token wrapped, Bridge(s), relayers y umbral.
2. **Origen**: el usuario deja liquidez (lock) o quema wrapped; el nonce queda en el evento.
3. **Relayer**: firma el struct EIP-712 completo (no solo el hash del evento crudo sin domain).
4. **Destino**: validar cadena, target, nonce y umbral → marcar nonce → mint/unlock.
5. **TDD**: docs → tests rojos e2e → implementación → replay/firmas → fuzz → cierre.

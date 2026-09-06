# Auditoría SWC — Cross-Chain Bridge & Message Relay

Verificación de `Bridge`, `MessageRelay` y `BridgeToken` contra el [SWC Registry](https://swcregistry.io/) (EIP-1470) y principios del monorepo (custom errors, `ReentrancyGuard`, SafeERC20, EIP-712 / ECDSA, anti-replay).

> **Nota:** El SWC Registry no se mantiene activamente desde ~2020. Complementar con [SCSVS](https://github.com/ComposableSecurity/SCSVS) y [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Contratos auditados:** `src/Bridge.sol`, `src/MessageRelay.sol`, `src/BridgeToken.sol`, `src/libraries/BridgeHash.sol` (+ interfaces)  
**Mocks (fuera de prod):** `src/mocks/MockERC20.sol`, `src/mocks/MockRelayTarget.sol`  
**Fecha:** 2026-09-06  
**Referencia tests:** `test/Bridge.t.sol`, `test/Replay.t.sol`, `test/InvalidSignature.t.sol`, `test/MessageRelay.t.sol`, `test/attack/`, `test/fuzz/`  
**Estilo:** alineado a [`08-flash-loans/doc/SWC-AUDIT.md`](../../08-flash-loans/doc/SWC-AUDIT.md)

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| ✅ Mitigado / No aplicable | 33 |
| ⚠️ Informativo (diseño / trust) | 3 |
| ❌ Vulnerable | 0 |

**Conclusión:** Sin vulnerabilidades SWC explotables en el alcance v1 (lock→mint, EIP-712 + umbral de relayers, `MessageRelay.execute`). Riesgos informativos: trust del set de relayers / owner (`Ownable2Step`), tokens fee-on-transfer / ERC-777 fuera de alcance, y `burn` aún stub (unlock inverso incompleto hasta fases posteriores).

**Principios del suite verificados:**

| Principio | Estado |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ |
| Pragma fijo `0.8.24` | ✅ |
| CEI + `nonReentrant` en deposit / release / execute | ✅ + `test/attack/` |
| Anti-replay EIP-712 + `processedNonces` | ✅ + Replay / SignatureReplay |
| ECDSA / umbral N-of-M | ✅ + InvalidSignature / MessageRelay |
| SafeERC20 (SWC-104) en lock/unlock | ✅ |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/Bridge.fuzz.t.sol` |

---

## Matriz completa SWC-100 — SWC-136

| ID | Título | Aplica | Estado | Evidencia en Cross-Chain Bridge |
|----|--------|--------|--------|----------------------------------|
| SWC-100 | Function Default Visibility | Sí | ✅ | Visibilidad explícita en contratos, interfaces y `BridgeHash` |
| SWC-101 | Integer Overflow and Underflow | Sí | ✅ | Solidity `0.8.24`; fuzz amounts; `unchecked` solo en `++` de nonce post-check |
| SWC-102 | Outdated Compiler Version | Sí | ✅ | `pragma solidity 0.8.24` + `foundry.toml` `solc = "0.8.24"` |
| SWC-103 | Floating Pragma | Sí | ✅ | Pragma exacto (sin `^`) en todo `src/` |
| SWC-104 | Unchecked Call Return Value | Sí | ✅ | OZ `SafeERC20` en deposit/unlock; `MessageRelay` chequea `success` del `call` → `ExecutionFailed` |
| SWC-105 | Unprotected Ether Withdrawal | No | N/A | Sin ETH / `payable` / `.call{value}` |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | Sin `selfdestruct` |
| SWC-107 | Reentrancy | Sí | ✅ | `nonReentrant` en deposit/release/execute; `test/attack/ReentrancyAttack.t.sol` + `RelayReentrancyAttack.t.sol` |
| SWC-108 | State Variable Default Visibility | Sí | ✅ | `immutable` / mappings `public` explícitos |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | Sin punteros storage legacy |
| SWC-110 | Assert Violation | No | N/A | Sin `assert` de producción |
| SWC-111 | Deprecated Solidity Functions | Sí | ✅ | Sin `suicide` / `throw` / `tx.origin` / `transfer`/`send` ETH |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | Sin `delegatecall` |
| SWC-113 | DoS with Failed Call | Parcial | ✅ | `execute` con target que falla → `ExecutionFailed`; tx revierte (nonce no queda marcado) |
| SWC-114 | Transaction Order Dependence | Sí | ⚠️ | Relayers / `release` públicos: carrera entre relayers (idempotente vía nonce); ver riesgos |
| SWC-115 | Authorization through tx.origin | No | N/A | Sin `tx.origin`; auth por ECDSA + `isRelayer` |
| SWC-116 | Block values as a proxy for time | No | N/A | Sin locks temporales on-chain |
| SWC-117 | Signature Malleability | Sí | ✅ | OZ `ECDSA.tryRecover` (s-value / v normalizados); firmas malformadas → `InvalidSignature` |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Sí | ✅ | Sin shadowing de estado |
| SWC-120 | Weak Sources of Randomness | No | N/A | Sin RNG |
| SWC-121 | Missing Protection against Signature Replay | Sí | ✅ | Domain EIP-712 + `destinationChainId` + `target` + `processedNonces`; Replay / SignatureReplayAttack |
| SWC-122 | Lack of Proper Signature Verification | Sí | ✅ | Umbral de relayers; `InvalidSignature` / `ThresholdNotMet`; InvalidSignature + TargetSpoofAttack |
| SWC-123 | Requirement Violation | Sí | ✅ | Custom errors + unit / fuzz / attack |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | Sin assembly de storage |
| SWC-125 | Incorrect Inheritance Order | Sí | ✅ | `IBridge, EIP712, ReentrancyGuard, Ownable2Step` |
| SWC-126 | Insufficient Gas Griefing | Parcial | ✅ | `execute` depende del gas del caller; fallo → `ExecutionFailed` |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | Sin function types dinámicos |
| SWC-128 | DoS With Block Gas Limit | Parcial | ✅ | Loop de firmas acotado por `signatures.length` (caller paga gas) |
| SWC-129 | Typographical Error | Sí | ✅ | Revisión + `forge build` / 43 tests PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII |
| SWC-131 | Presence of unused variables | Sí | ✅ | Sin dead code material en `src/` de producción |
| SWC-132 | Unexpected Ether balance | No | N/A | Contratos no manejan ETH |
| SWC-133 | Hash Collisions (var-length args) | Sí | ✅ | EIP-712 tipado (`BridgeHash`); `bytes payload` hasheado con `keccak256` |
| SWC-134 | Message call with hardcoded gas | No | N/A | Sin `{gas: …}` |
| SWC-135 | Code With No Effects | No | N/A | Sin no-ops relevantes |
| SWC-136 | Unencrypted Private Data On-Chain | Parcial | ✅ | Nonces, relayers y montos son públicos por diseño |

---

## Riesgos informativos

### SWC-114 — Orden de transacciones / relayers

`release` y `execute` son públicos: cualquiera puede publicar un mensaje ya firmado. El primer éxito consume el nonce; un segundo intento revierte `NonceAlreadyUsed` (sin doble mint). No hay pérdida de fondos por carrera entre relayers.

### Centralización / trust

| Tema | Riesgo | Tratamiento v1 |
|------|--------|----------------|
| Set de relayers + umbral | Relayers coludidos pueden firmar releases falsos | `Ownable2Step` admin; umbral N-of-M; documentar trust |
| `burn` stub | Flujo burn→unlock incompleto | Stub `ExecutionFailed`; fuera de fase 7 |
| Tokens fee-on-transfer / ERC-777 | Accounting / callbacks inesperados | Fuera de alcance v1; mocks ERC-20 honestos + attack token solo para reentrancy |

### Superficie MessageRelay

`target.call(payload)` ejecuta calldata arbitraria firmada por relayers. El riesgo es de **confianza en relayers**, no de auth on-chain insuficiente: sin umbral válido no hay `execute`. Cubierto en `MessageRelay.t.sol` + `RelayReentrancyAttack.t.sol`.

---

## Checklist principios monorepo (+ módulo 09)

| Principio | ¿Cumple? | Notas |
|-----------|----------|--------|
| Custom errors | ✅ | `InvalidSignature`, `NonceAlreadyUsed`, `InvalidChainId`, `ExecutionFailed`, … |
| ReentrancyGuard (OZ) | ✅ | deposit / release / execute |
| SafeERC20 | ✅ | lock + unlock |
| EIP-712 domain | ✅ | Bridge `CrossChainBridge`/`1`; Relay `MessageRelay`/`1` |
| Anti-replay | ✅ | chainIds + nonce + target en hash |
| NatSpec públicas/externas | Parcial | Completar en fase 8 |
| Fuzz ≥ 1000 runs | ✅ | `test/fuzz/Bridge.fuzz.t.sol` |
| Suite `test/attack/` | ✅ | Reentrancy · RelayReentrancy · TargetSpoof · SignatureReplay |
| Gas baseline | ⬜ | Fase 8 (`GAS.md` + snapshot) |

---

## Hallazgos de verificación (código)

### Mitigaciones confirmadas

1. **`Bridge.deposit`:** checks → nonce++ + evento → `safeTransferFrom` bajo `nonReentrant`.
2. **`Bridge.release`:** chainId / target / nonce / firmas → marcar nonce → mint/unlock → evento.
3. **`MessageRelay.execute`:** mismas guardas + `call` con chequeo de `success`.
4. **`BridgeToken`:** `onlyBridge` en mint/burn.
5. **Sin `require` strings / `tx.origin` / ETH `transfer`/`send` / `delegatecall` / `selfdestruct`** en `src/`.

### Observaciones no bloqueantes (fase 8 / v2)

| # | Observación | Severidad | Acción sugerida |
|---|-------------|-----------|-----------------|
| 1 | `burn` stub | Info | Completar burn→unlock |
| 2 | NatSpec / gas snapshot | Info | Fase 8 |
| 3 | Trust de relayers | Info (diseño) | Multisig / rotación documentada |
| 4 | Loop de firmas sin cap duro | Info | Caller paga gas; opcional `maxSignatures` |

---

## Mapeo SWC → tests

| SWC | Test(s) |
|-----|---------|
| SWC-101 | `testFuzz_deposit_locksExactAmount`, `testFuzz_release_mintsExactAmountAndNonceUnique` |
| SWC-103 | Compilador fijo (`forge build`) |
| SWC-104 | Unit deposit; `test_execute_revertsExecutionFailed` |
| SWC-107 | `test/attack/ReentrancyAttack.t.sol`, `RelayReentrancyAttack.t.sol` |
| SWC-113 | `test_execute_revertsExecutionFailed` |
| SWC-117 | `test_release_revertsMalformedV`, `MalformedSignatureLength` |
| SWC-121 | `Replay.t.sol`, `SignatureReplayAttack.t.sol`, fuzz nonce unique |
| SWC-122 | `InvalidSignature.t.sol`, `TargetSpoofAttack.t.sol` |
| SWC-123 | unit + fuzz + attack |
| SWC-133 | `BridgeHash.t.sol` |

---

## Resultado de ejecución

```text
forge test --summary
BridgeTest                    5 PASS
BridgeHashTest                4 PASS
ReplayTest                    4 PASS
InvalidSignatureTest          9 PASS
MessageRelayTest              6 PASS
BridgeFuzzTest                6 PASS (1000 runs c/u)
ReentrancyAttackTest          2 PASS
RelayReentrancyAttackTest     1 PASS
TargetSpoofAttackTest         4 PASS
SignatureReplayAttackTest     2 PASS
Total: 43 PASS / 0 FAIL / 0 SKIP
```

---

## Referencias

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [EIP-712](https://eips.ethereum.org/EIPS/eip-712)
- Módulo 08: [`08-flash-loans/doc/SWC-AUDIT.md`](../../08-flash-loans/doc/SWC-AUDIT.md)
- Plan: [`PLANIFICACION.md`](./PLANIFICACION.md)

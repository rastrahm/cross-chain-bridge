# Optimización de gas — Cross-Chain Bridge & Message Relay

Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract BridgeGasTest --gas-report
forge snapshot --match-contract BridgeGasTest
```

**Fecha baseline:** 2026-09-06 (Fase 8, post-optimización)  
**Snapshot:** `.gas-snapshot` (`test/gas/Bridge.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000` (prioriza runtime sobre deploy)

---

## Comparativa snapshot (antes → después)

| Test | Antes | Después | Δ |
|------|-------|---------|---|
| `testGas_deposit` | 77 709 | **77 343** | −366 |
| `testGas_release_mint` | 171 298 | **169 945** | −1 353 |
| `testGas_release_secondNonce_warmBitmap` | 221 138 | **196 620** | **−24 518 (−11.1%)** |
| `testGas_execute_relay` | 79 629 | **78 700** | −929 |
| `testGas_processedNonces_view` | 7 888 | 7 957 | +69 (getter vía bitmap) |

> El mayor ahorro está en releases secuenciales: el **bitmap de nonces** reutiliza el mismo slot SSTORE (256 nonces/palabra).

---

## Deploy (gas-report)

| Contrato | Coste deploy | Size (B) | Notas |
|----------|--------------|----------|-------|
| `Bridge` | ~2 369 077 | ~12 321 | Incluye deploy de `BridgeToken` + libs inlined |
| `MessageRelay` | ~1 345 792 | ~6 969 | EIP-712 + RelayerSig + NonceBitmap |

Deploy sube vs pre-opt (`optimizer_runs` 200 → 10 000 + código de libs). Tradeoff consciente: hot path `release`/`execute` más barato.

---

## Funciones principales (medianas gas-report)

| Función | Contrato | Median | Min | Notas |
|---------|----------|--------|-----|-------|
| `deposit` | Bridge | **85 078** | 50 878 | Lock ERC-20 + evento |
| `release` | Bridge | **112 786** | **61 498** | Min = nonce en palabra caliente |
| `execute` | MessageRelay | **89 361** | 89 361 | 1 firma + `call` target |
| `processedNonces` | Bridge | **2 706** | — | View sobre bitmap |
| `bridgeToken` | Bridge | **291** | — | `immutable` |

---

## Optimizaciones aplicadas (Fase 8)

| Técnica | Dónde | Efecto |
|---------|-------|--------|
| **Nonce bitmap** (256/slot) | `NonceBitmap` · Bridge · MessageRelay | −11% en 2º release; SSTORE caliente |
| **Fast-path `threshold == 1`** | `RelayerSig` | Sin alloc `address[] seen` en el caso 1-of-N |
| **Hash EIP-712 desde `calldata`** | `BridgeHash.hash(calldata)` | Evita copia memory del struct |
| **`BridgeToken.mint` tipado** | `_mintOrUnlock` | Sin cast a interfaz genérica |
| **Custom errors** | Todo `src/` | Menor calldata que `require` strings |
| **`immutable` `bridgeToken` / `bridge`** | Bridge · BridgeToken | Sin SLOAD en mint path |
| **`unchecked ++`** | Loops RelayerSig | Menos overflow checks |
| **`optimizer_runs = 10_000`** | `foundry.toml` | Inlining agresivo en hot paths |

---

## Tradeoffs aceptados

| Decisión | Por qué |
|----------|---------|
| Deploy más caro | Runtime de `release`/`execute` domina el coste operativo del puente |
| Bitmap vs `mapping => bool` | Nonces de depósito son secuenciales → excelente localidad |
| OZ `SafeERC20` / `ECDSA` / `EIP712` | Seguridad y consistencia suite > micro-ahorros |
| `burn` + unlock | Completo (CEI + e2e) | Ver `test_burn_e2e_unlockUnderlying` |
| Fast-path solo `threshold == 1` | Caso de tests/prod simple; N-of-M mantiene lógica completa |

---

## Relación con seguridad

Las optimizaciones **no** debilitan CEI / `nonReentrant` / anti-replay:

- El bitmap marca el nonce **antes** de mint/`call` (mismo orden CEI).
- `RelayerSig` sigue exigiendo firmantes `isRelayer` y umbral.
- Ver [`SWC-AUDIT.md`](./SWC-AUDIT.md).

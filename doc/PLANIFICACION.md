# Planificación — Module 09: Cross-Chain Bridge & Message Relay

**Estado:** Fases **0–7** ✅ (fuzz + attack + SWC-AUDIT). Fase 8 pendiente de autorización.

## 1. Objetivo del proyecto

Construir un **puente de tokens cross-chain** y un **relayer de mensajes** seguros: bloquear o quemar activos en la cadena origen, generar una prueba criptográfica ECDSA (EIP-712) y, en la cadena destino, acuñar o desbloquear el equivalente tras verificación de firmas, anti-replay y nonces. Stack: Foundry y Solidity `0.8.24`.

### Capacidades principales

- Mecánica **lock/burn** en origen y **mint/unlock** en destino.
- Verificación ECDSA con OpenZeppelin `ECDSA` / `SignatureChecker` y hashing tipado **EIP-712**.
- Separación de dominio EIP-712 contra **replay entre cadenas**.
- Nonces procesados por `sourceChainId` y `nonce` (`mapping(uint256 => mapping(uint256 => bool)) processedNonces`).
- Validación de umbral / conjunto de relayers antes de `mint` o `unlock`.
- Tests Foundry: e2e deposit → `vm.sign` → relay, replay, firmas inválidas, fuzz.

---

## 2. Alcance

### Incluye

| Área | Descripción |
|------|-------------|
| Bridge (origen) | `deposit` / `lock` ERC-20 o `burn` de wrapped; emite evento con payload bridgeable |
| Bridge (destino) | `release` / `mint` / `unlock` tras verificar firma(s) EIP-712 |
| MessageRelay | Relé genérico de mensajes con mismo esquema de prueba |
| EIP-712 | Struct tipado con `sourceChainId`, `destinationChainId`, `nonce`, target, recipient, amount, token |
| Relayer set | Umbral de firmas (multisig / set designado) antes de ejecutar |
| Nonces | `processedNonces[sourceChainId][nonce]` — un solo uso |
| Seguridad | `ReentrancyGuard` / CEI en deposit, burn y release; custom errors |
| Tokens | `BridgeToken` (mintable/burnable controlado por el bridge) + MockERC20 |
| Tests | Unit e2e, replay, signature fail, fuzz amounts/chainIds/nonces |

### No incluye (v1)

- Light clients / SPV / zk-proofs de inclusión de bloque.
- Relayer off-chain en producción (solo simulación en tests con `vm.sign`).
- Multi-token registry complejo (v1: token emparejado por dirección o mapping simple).
- Gobernanza on-chain del set de relayers más allá de admin `Ownable2Step`.
- Frontend Next.js (fase posterior opcional).
- Bridging de ETH nativo (WETH como ERC-20 si se necesita).

---

## 3. Stack técnico

| Componente | Elección |
|------------|----------|
| Compilador | `pragma solidity 0.8.24;` (exacto, sin pragma flotante) |
| Framework | Foundry (`forge test`, fuzz ≥ 1000, `vm.sign`, `vm.chainId`) |
| Crypto | OZ `ECDSA`, `SignatureChecker`, `EIP712` |
| Librerías | OpenZeppelin Contracts v5.x (`ReentrancyGuard`, `Ownable2Step`, `SafeERC20`, `ERC20Burnable`) |
| ETH | Si aplica: `.call{value: ...}("")` — nunca `transfer`/`send` |
| Documentación | NatSpec en toda API public/external |

---

## 4. Arquitectura

```
09-cross-chain-bridge/
├── doc/
│   ├── README.md
│   ├── PLANIFICACION.md
│   ├── diagrama-clases.md
│   ├── diagrama-flujo.md
│   └── flujograma.md
├── src/
│   ├── Bridge.sol                        # lock/burn + mint/unlock + nonces
│   ├── MessageRelay.sol                  # ejecución de mensajes genéricos firmados
│   ├── BridgeToken.sol                   # ERC-20 mint/burn solo bridge
│   ├── interfaces/
│   │   ├── IBridge.sol
│   │   ├── IMessageRelay.sol
│   │   └── IBridgeToken.sol
│   ├── libraries/
│   │   └── BridgeHash.sol                # hash EIP-712 del BridgeMessage
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

| Actor | Responsabilidad |
|-------|-----------------|
| **Usuario** | Deposita/quema en origen; recibe mint/unlock en destino |
| **Relayer(s)** | Observan eventos, firman payload EIP-712, envían `release`/`execute` |
| **Admin / owner** | Gestiona set de relayers, umbral, tokens emparejados |
| **Bridge (origen)** | Custodia o quema; emite `Deposit` / `Burn` |
| **Bridge (destino)** | Verifica firma + nonce + chainIds; mint o unlock |
| **Atacante (test)** | Replay, firma falsa, chainId wrong, reentrancy → debe revertir |

---

## 5. Modelo de datos

```solidity
// Mensaje tipado EIP-712 (resumen)
struct BridgeMessage {
    uint256 sourceChainId;
    uint256 destinationChainId;
    uint256 nonce;
    address target;        // contrato bridge destino
    address recipient;
    address token;         // token en destino (o mapping)
    uint256 amount;
}

// Bridge (resumen de estado)
mapping(uint256 => mapping(uint256 => bool)) public processedNonces; // sourceChainId => nonce => used
mapping(address => bool) public isRelayer;
uint256 public relayerThreshold;   // p.ej. 1 en tests; N-of-M en prod
uint256 public nextDepositNonce;   // por cadena origen (o por usuario según diseño)
address public immutable bridgeToken; // wrapped mintable en destino
```

### Hash EIP-712 (campos anti-replay)

| Campo | Por qué |
|-------|---------|
| `sourceChainId` | Impide reutilizar prueba de otra origen |
| `destinationChainId` | Debe coincidir con `block.chainid` del destino |
| `nonce` | Un solo uso por `sourceChainId` |
| `target` | Solo ejecutable en el contrato bridge esperado |
| `recipient` / `token` / `amount` | Payload de la transferencia |

### Dominio EIP-712

| Campo | Valor típico |
|-------|----------------|
| `name` | `"CrossChainBridge"` |
| `version` | `"1"` |
| `chainId` | `block.chainid` del contrato que **verifica** (destino) |
| `verifyingContract` | `address(this)` del Bridge destino |

---

## 6. API on-chain

### Bridge — origen

| Función | Visibilidad | Descripción |
|---------|-------------|-------------|
| `deposit(address token, uint256 amount, uint256 destChainId, address recipient)` | external nonReentrant | Lock ERC-20; asigna nonce; emite `Deposit` |
| `burn(uint256 amount, uint256 destChainId, address recipient)` | external nonReentrant | Quema wrapped local; emite `Burn` |

### Bridge — destino

| Función | Visibilidad | Descripción |
|---------|-------------|-------------|
| `release(BridgeMessage msg, bytes[] signatures)` | external nonReentrant | Verifica EIP-712 + umbral; marca nonce; mint/unlock |
| `processedNonces(uint256 sourceChainId, uint256 nonce)` | view | Si el nonce ya se usó |
| `isRelayer(address)` / `relayerThreshold()` | view | Set y umbral |

### MessageRelay

| Función | Visibilidad | Descripción |
|---------|-------------|-------------|
| `execute(RelayMessage msg, bytes[] signatures)` | external nonReentrant | Verifica y ejecuta `call` al target (payload genérico) |

### Errores custom (obligatorios)

| Error | Condición |
|-------|-----------|
| `InvalidSignature()` | Recuperación ECDSA falla o firmante no es relayer |
| `NonceAlreadyUsed()` | `processedNonces[source][nonce] == true` |
| `InvalidChainId()` | `destinationChainId != block.chainid` (u origen inválido) |
| `ExecutionFailed()` | Call de mensaje / mint-unlock falla |

Errores adicionales recomendados (suite):

| Error | Condición |
|-------|-----------|
| `ZeroAmount()` | amount 0 |
| `ThresholdNotMet()` | firmas válidas < umbral |
| `UnauthorizedRelayer()` | admin-only: set de relayers |
| `InvalidTarget()` | `msg.target != address(this)` |

### Eventos

`Deposit` (sender, token, amount, destChainId, recipient, nonce) · `Burn` · `Released` (sourceChainId, nonce, recipient, amount) · `MessageExecuted` · `RelayerUpdated`

---

## 7. Lógica deposit → release (CEI)

### Origen `deposit` / `burn`

1. **Checks:** `amount > 0`, `destChainId != block.chainid` (opcional), `recipient != 0`.
2. **Effects:** `nonce = nextDepositNonce++` (o nonce por usuario); emitir evento con todos los campos del struct.
3. **Interactions:** `SafeERC20.safeTransferFrom` (lock) o `burnFrom` / `burn`.

### Destino `release`

1. **Checks:** `destinationChainId == block.chainid` → sino `InvalidChainId`.
2. **Checks:** `target == address(this)` → sino `InvalidTarget`.
3. **Checks:** `!processedNonces[sourceChainId][nonce]` → sino `NonceAlreadyUsed`.
4. **Checks:** hash EIP-712 + ≥ `relayerThreshold` firmas válidas de `isRelayer` → sino `InvalidSignature` / `ThresholdNotMet`.
5. **Effects:** `processedNonces[sourceChainId][nonce] = true`.
6. **Interactions:** mint a `recipient` o `safeTransfer` (unlock) → sino `ExecutionFailed`.
7. Emit `Released`.

Orden CEI: marcar nonce **antes** de la interacción externa (mint/transfer).

---

## 8. Fases de implementación (TDD)

| Fase | Entregable | Estado |
|------|------------|--------|
| **0** | Docs (`doc/`) + scaffold Foundry + interfaces | ✅ |
| **1** | Tests failing: deposit evento, hash EIP-712, release feliz | ✅ |
| **2** | `BridgeToken` + `Bridge.deposit` / lock mínimo | ✅ |
| **3** | `release` con 1 relayer + `vm.sign` e2e | ✅ |
| **4** | Replay: mismo nonce / otro `chainId` → revert | ✅ |
| **5** | Firmas inválidas / tamper / v,r,s malformados | ✅ |
| **6** | Umbral N-of-M + `MessageRelay.execute` | ✅ |
| **7** | Fuzz amounts, chainIds, nonces (`bound`) + SWC/attack | ✅ |
| **8** | Gas snapshot + NatSpec + `Deploy.s.sol` | ⬜ |

---

## 9. Plan de pruebas

| Suite | Ubicación | Cobertura |
|-------|-----------|-----------|
| E2E bridge | `test/Bridge.t.sol` | deposit → sign → release → balance destino |
| Replay | `test/Replay.t.sol` | nonce reuse; `vm.chainId` distinto |
| Signatures | `test/InvalidSignature.t.sol` | wrong signer, payload tampered, bad v/r/s |
| Relay | `test/MessageRelay.t.sol` | execute mensaje; `ExecutionFailed` |
| Fuzz | `test/fuzz/Bridge.fuzz.t.sol` | `bound` amount/chainId/nonce |
| Attack | `test/attack/` | reentrancy en release, target spoof |

Invariante: un `release` exitoso marca el nonce; un segundo intento con la misma prueba **siempre** revierte `NonceAlreadyUsed`.

---

## 10. Criterios de aceptación

- [x] Scaffold Foundry (`0.8.24`, fuzz ≥ 1000)
- [x] Struct de mensaje incluye `sourceChainId`, `destinationChainId`, `nonce`, `target`
- [x] EIP-712 + ECDSA con OZ; dominio ligado a contrato destino
- [x] `processedNonces[sourceChainId][nonce]` impide doble gasto
- [x] Custom errors: `InvalidSignature`, `NonceAlreadyUsed`, `InvalidChainId`, `ExecutionFailed`
- [x] Umbral de relayers antes de mint/unlock
- [x] `ReentrancyGuard` / CEI en deposit, burn, release
- [x] Test e2e con `vm.sign`
- [x] Tests de replay y firma inválida con `vm.expectRevert`
- [x] Fuzz de amounts, chain IDs y nonces
- [ ] NatSpec en funciones public/external
- [x] CEI + SafeERC20; sin `transfer`/`send` de ETH

---

## 11. Documentos relacionados

| Documento | Contenido |
|-----------|-----------|
| [diagrama-clases.md](./diagrama-clases.md) | UML contratos, interfaces, tests |
| [diagrama-flujo.md](./diagrama-flujo.md) | Secuencia lock/burn → firma → mint/unlock |
| [flujograma.md](./flujograma.md) | Operativo, anti-replay, TDD |
| [SWC-AUDIT.md](./SWC-AUDIT.md) | Matriz SWC-100–136 + mapeo a tests |

---

## 12. Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Replay cross-chain | EIP-712 domain + `destinationChainId` + `target` |
| Doble mint (mismo depósito) | `processedNonces` marcado antes de mint |
| Relayer único comprometido | Umbral N-of-M (`relayerThreshold`) |
| Firma de payload alterado | Hash tipado completo; test de tamper |
| Reentrancy en release | `nonReentrant` + CEI (nonce antes de transfer) |
| Chain ID incorrecto en destino | `InvalidChainId` si ≠ `block.chainid` |
| Token fee-on-transfer | v1: solo tokens estándar; mock simple |

---

## 13. Convenciones (suite + Solidity rules)

- Pragma fijo `0.8.24`; layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions (External → Public → Internal → Private).
- NatSpec `@notice` / `@dev` / `@param` / `@return` en API pública.
- Tests primero (TDD); `vm.expectRevert` en caminos de fallo.
- Gas: `immutable`/`constant`, custom errors, packing de storage donde aplique.
- Explicar patrones (Bridge lock-mint, burn-unlock, EIP-712) antes de codear cada fase.

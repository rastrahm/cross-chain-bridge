# Guía técnica — Cross-Chain Bridge & Message Relay

🌐 **Español** · [English](./GUIA-TECNICA-EN.md)

Documento para entender **qué se decidió**, **cómo fluye la lógica** y **dónde aún se puede ahorrar gas**.  
Complementa: [`PLANIFICACION-ES.md`](./PLANIFICACION-ES.md) · [`GAS-ES.md`](./GAS-ES.md) · [`SWC-AUDIT-ES.md`](./SWC-AUDIT-ES.md) · diagramas.

---

## 1. En una frase

Es un puente **lock/mint** y **burn/unlock** más un **MessageRelay** genérico: en origen se bloquea o quema; un relayer firma un mensaje **EIP-712**; en destino se verifica la firma (umbral N-of-M), se marca el nonce y se acuña, desbloquea o ejecuta un `call`.

No hay light client ni prueba de inclusión de bloque: la seguridad criptográfica on-chain es **confianza en el set de relayers + anti-replay**.

---

## 2. Decisiones técnicas (por qué así)

### 2.1 Arquitectura: un contrato “espejo” por cadena

| Decisión | Alternativa descartada | Motivo |
|----------|------------------------|--------|
| Mismo bytecode `Bridge` en origen y destino | Contratos distintos Source/Dest | Un solo código; el rol lo da el uso (`deposit`/`burn` vs `release`) |
| `BridgeToken` desplegado en el constructor del Bridge | Token externo con `setBridge` | `immutable bridge` sin chicken-egg ni setter |
| `MessageRelay` separado | Meter mensajes genéricos en Bridge | Superficies distintas: tokens vs `call` arbitrario |

En tests Foundry se simulan dos cadenas con `vm.chainId` sobre el mismo deploy.

### 2.2 Crypto: EIP-712 + ECDSA (OpenZeppelin)

| Decisión | Motivo |
|----------|--------|
| EIP-712 tipado (`BridgeMessage` / `RelayMessage`) | Domain separator por cadena + contrato; anti-replay entre dominios |
| Campos en el hash: `sourceChainId`, `destinationChainId`, `nonce`, `target`, + payload | Una firma no sirve en otra red, otro contrato o otro monto |
| Dominio Bridge: `("CrossChainBridge", "1")` | Distinto del Relay `("MessageRelay", "1")` → no mezclar firmas |
| OZ `ECDSA.tryRecover` | Rechaza malleabilidad (s/v); firmas rotas no revierten con panic opaco |
| Umbral N-of-M (`isRelayer` + `relayerThreshold`) | 1 firma en demo; N firmas distintas en prod |

**No** usamos Merkle/light client: fuera de alcance v1 (ver planificación).

### 2.3 Nonces: bitmap en vez de `mapping => bool`

| Decisión | Motivo |
|----------|--------|
| `processedNonces` vía **bitmap** (256 nonces por slot) | Los nonces de depósito son secuenciales → el 2º `release` reutiliza el mismo slot (SSTORE caliente) |
| Nonce asignado en origen (`nextDepositNonce++`) y consumido en destino | El evento `Deposit`/`Burn` lleva el nonce que el relayer firma |
| Marcar nonce **antes** de mint/`call` (CEI) | Evita doble acuñación si hubiera reentrada; si el `call` falla, toda la tx revierte y el bit también |

### 2.4 Flujos de token

| Flujo | Origen | Destino (`release`) |
|-------|--------|---------------------|
| **Lock → mint** | `deposit`: lock ERC-20 | `token == bridgeToken` → `mint` |
| **Burn → unlock** | `burn`: quema wrapped | `token == underlying` → `safeTransfer` |

Regla en `_mintOrUnlock`: si el token del mensaje es el wrapped → mint; si no → unlock de lo custodiado.

### 2.5 Seguridad / estilo suite

| Decisión | Motivo |
|----------|--------|
| `pragma solidity 0.8.24` exacto | Sin floating pragma (SWC-103) |
| Custom errors | Menos gas que `require("…")` |
| `ReentrancyGuard` en deposit/burn/release/execute | SWC-107; cubierto en `test/attack/` |
| `SafeERC20` | SWC-104 |
| `Ownable2Step` para admin de relayers | Transferencia de ownership en dos pasos |
| TDD por fases + fuzz ≥ 1000 + SWC-AUDIT | Criterio del monorepo |

### 2.6 Gas / tooling

| Decisión | Motivo |
|----------|--------|
| `optimizer_runs = 10_000` | Prioriza **runtime** de `release`/`execute` (deploy sube) |
| Libs internas `BridgeHash`, `NonceBitmap`, `RelayerSig` | Reuso Bridge ↔ Relay; fast-path threshold 1 |
| Hash EIP-712 desde **calldata** | Evita copiar el struct a memory |

---

## 3. Lógica que sigue el sistema

### 3.1 Actores

```
Usuario ──deposit/burn──► Bridge (origen) ──evento──► Relayer(s)
                                                         │
                                                    firma EIP-712
                                                         │
Usuario ◄──mint/unlock── Bridge (destino) ◄──release─────┘
```

- **Usuario:** aporta o recupera tokens.  
- **Relayer(s):** off-chain; firman el digest; cualquiera puede enviar `release`/`execute` on-chain.  
- **Owner:** gestiona `isRelayer` y el umbral.

### 3.2 Lock → mint (camino feliz)

1. Usuario en cadena A llama `deposit(token, amount, destChainId, recipient)`.  
2. Checks: amount > 0, addresses ≠ 0, `destChainId ≠ block.chainid`.  
3. Effects: `nonce = nextDepositNonce++`, emite `Deposit`.  
4. Interaction: `safeTransferFrom` → tokens quedan en el Bridge.  
5. Relayer arma `BridgeMessage` (incluye `sourceChainId=A`, `destinationChainId=B`, `nonce`, `target=BridgeB`, `token=bridgeToken`, `amount`, `recipient`).  
6. Firma el digest EIP-712 del **dominio del Bridge en B**.  
7. En cadena B: `release(message, signatures)`.  
8. Checks: `destinationChainId == block.chainid`, `target == this`, nonce libre, umbral de firmas.  
9. Effects: marca nonce en el bitmap.  
10. Interaction: `BridgeToken.mint(recipient, amount)`.  
11. Emite `Released`.

### 3.3 Burn → unlock

1. Usuario con wrapped en B llama `burn(amount, destChainId=A, recipient)`.  
2. Same CEI: nonce + `Burn` → `BridgeToken.burn(msg.sender, amount)`.  
3. Relayer firma mensaje con `token = underlying` (el ERC-20 custodiado en A).  
4. En A: `release` → `_mintOrUnlock` hace `safeTransfer` del underlying al recipient.

### 3.4 MessageRelay

Misma idea anti-replay/firmas, pero el efecto es:

```text
target.call(payload)
```

Si el `call` falla → `ExecutionFailed` y **toda la tx revierte** (incluido el bit del nonce).

### 3.5 Qué rechaza el contrato (resumen)

| Situación | Error típico |
|-----------|--------------|
| Misma firma / mismo nonce otra vez | `NonceAlreadyUsed` |
| `destinationChainId ≠ block.chainid` | `InvalidChainId` |
| `target ≠ address(this)` (solo Bridge) | `InvalidTarget` |
| Firmante no relayer / payload alterado / firma rota | `InvalidSignature` |
| Menos firmas únicas que el umbral | `ThresholdNotMet` |
| Reentrada deposit/release/execute | `ReentrancyGuard` |
| Amount 0 | `ZeroAmount` |

---

## 4. ¿Se puede mejorar el gas de lo que existe?

Sí. Lo actual ya está optimizado en el hot path “razonable”; abajo van mejoras **posibles**, con costo en complejidad o seguridad.

### 4.1 Ya aplicado (baseline)

Ver [`GAS-ES.md`](./GAS-ES.md): bitmap (−11% en 2º release), fast-path umbral 1, hash calldata, immutables, custom errors, `optimizer_runs = 10_000`.

### 4.2 Mejoras adicionales factibles

| Idea | Ahorro esperado | Riesgo / costo |
|------|-----------------|----------------|
| **Assembly** en `BridgeHash` (encode + keccak sin `abi.encode` intermedio) | Bajo–medio en `release` | Más difícil de auditar; forge-lint ya lo sugiere |
| **Empaquetar storage admin**: `relayerThreshold` en `uint64`/`uint128` junto a otro campo | Bajo (pocas writes) | Poco impacto en hot path |
| **Transient storage** (Cancun) para el lock de reentrancy casero | Bajo–medio vs OZ guard clásico | Hay que mantener/auditar el guard propio |
| **Compactar firmas** (solo `r,s` + `v` en bytes cortos / EIP-2098) | Menos calldata | Compatibilidad wallets/tooling |
| **Bajar `optimizer_runs`** si el cuello de botella es deploy | Deploy más barato | Runtime de `release` puede subir |
| **External library** para RelayerSig (no inline) | Bytecode deploy menor | +coste DELEGATECALL en cada verify |
| **No emitir eventos tan “gordos”** o indexar menos | Bajo | Peor DX/indexers off-chain |
| **Permit + deposit** en un solo tx (EIP-2612 en underlying) | UX; no siempre menos gas total | Solo si el token lo soporta |

### 4.3 Lo que **no** conviene “optimizar” a ciegas

| Tentación | Por qué no |
|-----------|------------|
| Quitar CEI / marcar nonce después del mint | Doble mint bajo reentrancy |
| Quitar campos del hash EIP-712 | Replay cross-chain |
| `transfer`/`send` ETH o returns unchecked | Rompe reglas SWC / suite |
| Mapping `bool` otra vez “más simple” | Peor gas en nonces secuenciales |
| Confiar en un solo relayer sin documentar trust | Riesgo de diseño, no de gas |

### 4.4 Orden sugerido si se itera gas

1. Medir otra vez: `forge test --match-contract BridgeGasTest --gas-report`.  
2. Perfilar solo `release` (es el hot path caro: ecrecover + mint).  
3. Probar assembly en `BridgeHash` con tests de igualdad de digest.  
4. Revisar tradeoff `optimizer_runs` según si se redeploya mucho o se ejecuta mucho.

---

## 5. Mapa mental de archivos

```text
src/
  Bridge.sol          → deposit / burn / release
  MessageRelay.sol    → execute
  BridgeToken.sol     → mint/burn onlyBridge
  libraries/
    BridgeHash.sol    → structHash EIP-712
    NonceBitmap.sol   → nonces procesados
    RelayerSig.sol    → umbral de firmas
```

Tests clave: e2e (`Bridge.t.sol`), replay, firmas inválidas, MessageRelay, fuzz, `test/attack/`, gas.

---

## 6. Resumen ejecutivo

1. **Decisiones:** puente espejo + EIP-712/ECDSA + umbral de relayers + bitmap de nonces + CEI/`nonReentrant` + OZ SafeERC20; sin light client en v1.  
2. **Lógica:** origen asigna nonce y mueve supply (lock/burn) → relayer firma → destino verifica y mint/unlock/call.  
3. **Gas:** ya hay win grande en releases secuenciales; el siguiente salto realista es micro-optimizar hashing (assembly) o calldata de firmas, sin tocar el modelo de seguridad.

Si querés profundizar un solo tema en un próximo doc: **EIP-712 anti-replay**, **bitmap**, o **flujo burn→unlock** paso a paso con valores de test.

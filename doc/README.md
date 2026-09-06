# Documentación — Module 09: Cross-Chain Bridge & Message Relay

Índice de la carpeta `doc/`. Planificación y diagramas **to-be** (fase 0).

| Documento | Contenido |
|-----------|-----------|
| [PLANIFICACION.md](./PLANIFICACION.md) | Objetivo, alcance, fases TDD, criterios |
| [diagrama-clases.md](./diagrama-clases.md) | UML: Bridge, Token, Relayer, EIP-712, tests |
| [diagrama-flujo.md](./diagrama-flujo.md) | Flujos lock/burn → firma → mint/unlock |
| [flujograma.md](./flujograma.md) | Operativo, anti-replay, pipeline TDD |

**Estado:** Fases **0–4** ✅. Pendiente autorización fase 5 (firmas inválidas).

**Contratos:** `Bridge` (deposit + release) · `BridgeToken` · `BridgeHash`  
**Tests:** `forge test` → **12 PASS** (incl. `Replay.t.sol`)  
**Estándar crypto:** ECDSA + EIP-712

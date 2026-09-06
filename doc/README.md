# Documentación — Module 09: Cross-Chain Bridge & Message Relay

Índice de la carpeta `doc/`. Planificación y diagramas **to-be** (fase 0).

| Documento | Contenido |
|-----------|-----------|
| [PLANIFICACION.md](./PLANIFICACION.md) | Objetivo, alcance, fases TDD, criterios |
| [diagrama-clases.md](./diagrama-clases.md) | UML: Bridge, Token, Relayer, EIP-712, tests |
| [diagrama-flujo.md](./diagrama-flujo.md) | Flujos lock/burn → firma → mint/unlock |
| [flujograma.md](./flujograma.md) | Operativo, anti-replay, pipeline TDD |

**Estado:** Fases **0–1** ✅. Pendiente autorización fase 2 (`BridgeToken` + `deposit`).

**Entregado:** interfaces · `BridgeHash` · `MockERC20` · tests TDD  
**Rojo esperado:** `forge test` no compila hasta existir `src/Bridge.sol` y `src/BridgeToken.sol`  
**Verde parcial:** `BridgeHash.t.sol` — 4 PASS (aislado)  
**Estándar crypto:** ECDSA + EIP-712

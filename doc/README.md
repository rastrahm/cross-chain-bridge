# Documentación — Module 09: Cross-Chain Bridge & Message Relay

Índice de la carpeta `doc/`. Planificación y diagramas **to-be** (fase 0).

| Documento | Contenido |
|-----------|-----------|
| [PLANIFICACION.md](./PLANIFICACION.md) | Objetivo, alcance, fases TDD, criterios |
| [diagrama-clases.md](./diagrama-clases.md) | UML: Bridge, Token, Relayer, EIP-712, tests |
| [diagrama-flujo.md](./diagrama-flujo.md) | Flujos lock/burn → firma → mint/unlock |
| [flujograma.md](./flujograma.md) | Operativo, anti-replay, pipeline TDD |
| [SWC-AUDIT.md](./SWC-AUDIT.md) | Matriz SWC-100–136, mapeo a tests |

**Estado:** Fases **0–7** ✅. Pendiente autorización fase 8 (gas + NatSpec + Deploy).

**Contratos:** `Bridge` · `MessageRelay` · `BridgeToken` · `BridgeHash`  
**Tests:** `forge test` → **43 PASS** (incl. fuzz 1000 runs + `test/attack/`)  
**Estándar crypto:** ECDSA + EIP-712

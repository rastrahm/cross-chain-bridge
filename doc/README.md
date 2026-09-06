# Documentación — Module 09: Cross-Chain Bridge & Message Relay

Índice de la carpeta `doc/`. Planificación y diagramas **to-be** (fase 0).

| Documento | Contenido |
|-----------|-----------|
| [PLANIFICACION.md](./PLANIFICACION.md) | Objetivo, alcance, fases TDD, criterios |
| [diagrama-clases.md](./diagrama-clases.md) | UML: Bridge, Token, Relayer, EIP-712, tests |
| [diagrama-flujo.md](./diagrama-flujo.md) | Flujos lock/burn → firma → mint/unlock |
| [flujograma.md](./flujograma.md) | Operativo, anti-replay, pipeline TDD |

**Estado:** Fase **0** ✅ (scaffold + interfaces). Pendiente autorización fase 1.

**Entregado en fase 0:** `IBridge` · `IMessageRelay` · `IBridgeToken` · `BridgeHash` · `MockERC20`  
**Pendiente:** `Bridge` · `BridgeToken` · `MessageRelay` · tests  
**Estándar crypto:** ECDSA + EIP-712 · **Tests:** unit, replay, firmas inválidas, fuzz

# Documentación — Module 09: Cross-Chain Bridge & Message Relay

Índice de la carpeta `doc/`. **Proyecto completo** (contratos + seguridad + gas).

| Documento | Contenido |
|-----------|-----------|
| [PLANIFICACION.md](./PLANIFICACION.md) | Objetivo, alcance, fases TDD, criterios |
| [SWC-AUDIT.md](./SWC-AUDIT.md) | Matriz SWC-100–136, mapeo a tests |
| [GAS.md](./GAS.md) | Baseline gas, optimizaciones, snapshot |
| [diagrama-clases.md](./diagrama-clases.md) | UML: Bridge, Token, Relayer, EIP-712, tests |
| [diagrama-flujo.md](./diagrama-flujo.md) | Flujos lock/burn → firma → mint/unlock |
| [flujograma.md](./flujograma.md) | Operativo, anti-replay, pipeline TDD |

**Estado:** Fases **0–8** ✅ (módulo cerrado).

**Contratos:** `Bridge` · `MessageRelay` · `BridgeToken` · `BridgeHash` · `NonceBitmap` · `RelayerSig`  
**Estándar crypto:** ECDSA + EIP-712 · **Tests:** `forge test` → **51 PASS**

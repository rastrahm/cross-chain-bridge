# Documentación — Module 09: Cross-Chain Bridge & Message Relay

🌐 **Español** · [English](./README-EN.md)

Índice de la carpeta `doc/`. **Proyecto completo** (contratos + seguridad + gas).

| Documento | Contenido |
|-----------|-----------|
| [PLANIFICACION-ES.md](./PLANIFICACION-ES.md) | Objetivo, alcance, fases TDD, criterios |
| [SWC-AUDIT-ES.md](./SWC-AUDIT-ES.md) | Matriz SWC-100–136, mapeo a tests |
| [GAS-ES.md](./GAS-ES.md) | Baseline gas, optimizaciones, snapshot |
| [GUIA-TECNICA-ES.md](./GUIA-TECNICA-ES.md) | Decisiones técnicas, lógica, mejoras de gas |
| [DEPLOY-TESTNET-ES.md](./DEPLOY-TESTNET-ES.md) | Deploy Sepolia + Base Sepolia y primer cruce |
| [SOCIAL-ES.md](./SOCIAL-ES.md) | Borradores LinkedIn / X |
| [diagrama-clases-ES.md](./diagrama-clases-ES.md) | UML: Bridge, Token, Relayer, EIP-712, tests |
| [diagrama-flujo-ES.md](./diagrama-flujo-ES.md) | Flujos lock/burn → firma → mint/unlock |
| [flujograma-ES.md](./flujograma-ES.md) | Operativo, anti-replay, pipeline TDD |

**Portfolio local:** [`../portfolio/index.html`](../portfolio/index.html) (ES/EN · Gas · SWC)

**Estado:** Fases **0–8** ✅ (módulo cerrado).

**Contratos:** `Bridge` · `MessageRelay` · `BridgeToken` · `BridgeHash` · `NonceBitmap` · `RelayerSig`  
**Estándar crypto:** ECDSA + EIP-712 · **Tests:** `forge test` → **51 PASS**

# Documentation — Module 09: Cross-Chain Bridge & Message Relay

🌐 [Español](./README-ES.md) · **English**

Index of the `doc/` folder. **Complete project** (contracts + security + gas).

| Document | Content |
|----------|---------|
| [PLANIFICACION-EN.md](./PLANIFICACION-EN.md) | Goal, scope, TDD phases, criteria |
| [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md) | SWC-100–136 matrix, mapping to tests |
| [GAS-EN.md](./GAS-EN.md) | Gas baseline, optimizations, snapshot |
| [GUIA-TECNICA-EN.md](./GUIA-TECNICA-EN.md) | Technical decisions, logic, gas improvements |
| [DEPLOY-TESTNET-EN.md](./DEPLOY-TESTNET-EN.md) | Sepolia + Base Sepolia deploy and first crossing |
| [SOCIAL-EN.md](./SOCIAL-EN.md) | LinkedIn / X drafts |
| [diagrama-clases-EN.md](./diagrama-clases-EN.md) | UML: Bridge, Token, Relayer, EIP-712, tests |
| [diagrama-flujo-EN.md](./diagrama-flujo-EN.md) | Lock/burn → signature → mint/unlock flows |
| [flujograma-EN.md](./flujograma-EN.md) | Operations, anti-replay, TDD pipeline |

**Local portfolio:** [`../portfolio/index.html`](../portfolio/index.html) (ES/EN · Gas · SWC)

**Status:** Phases **0–8** ✅ (module complete).

**Contracts:** `Bridge` · `MessageRelay` · `BridgeToken` · `BridgeHash` · `NonceBitmap` · `RelayerSig`  
**Crypto standard:** ECDSA + EIP-712 · **Tests:** `forge test` → **51 PASS**

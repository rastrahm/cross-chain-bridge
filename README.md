# 09 — Cross-Chain Bridge & Message Relay

Puente de tokens cross-chain y relé de mensajes con pruebas **ECDSA + EIP-712**, anti-replay y nonces. Solidity `0.8.24` + Foundry.

**Estado:** Fases **0–1** ✅ (scaffold + tests TDD rojos). Fases 2–8 pendientes de autorización.

---

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24` |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Crypto | EIP-712 + ECDSA (OpenZeppelin) |
| Librerías | OpenZeppelin Contracts v5.2, forge-std |
| Seguridad | CEI, ReentrancyGuard, custom errors, SafeERC20 |

---

## Documentación

| Doc | Descripción |
|-----|-------------|
| [doc/README.md](./doc/README.md) | Índice de documentación |
| [doc/PLANIFICACION.md](./doc/PLANIFICACION.md) | Plan, fases TDD y criterios |
| [doc/diagrama-clases.md](./doc/diagrama-clases.md) | UML de contratos |
| [doc/diagrama-flujo.md](./doc/diagrama-flujo.md) | Flujos lock/burn → release |
| [doc/flujograma.md](./flujograma.md) | Flujograma operativo y pipeline TDD |

---

## Setup

```shell
export PATH="$HOME/.foundry/bin:$PATH"

forge install foundry-rs/forge-std@v1.16.2 --no-git
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git

forge build
```

---

## Estructura (fase 0)

```
src/
├── interfaces/     IBridge, IMessageRelay, IBridgeToken (+ structs)
├── libraries/      BridgeHash (TYPEHASH + structHash)
└── mocks/          MockERC20
```

Contratos `Bridge`, `BridgeToken` y `MessageRelay` entran desde la fase 2–3 (TDD).

### Fase 1 — tests (rojo)

| Archivo | Estado |
|---------|--------|
| `test/BridgeHash.t.sol` | 4 PASS (structHash EIP-712) |
| `test/Bridge.t.sol` | Rojo: falta `Bridge` / `BridgeToken` |
| `test/helpers/EIP712BridgeHelper.sol` | Domain + `vm.sign` |

```shell
forge test   # Error: Source "src/Bridge.sol" not found  ← esperado hasta fase 2–3
```

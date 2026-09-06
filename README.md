# 09 — Cross-Chain Bridge & Message Relay

Puente de tokens cross-chain y relé de mensajes con pruebas **ECDSA + EIP-712**, anti-replay y nonces. Solidity `0.8.24` + Foundry.

**Estado:** Fases **0–3** ✅ (`release` e2e). Fases 4–8 pendientes de autorización.

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

### Tests

```shell
forge test
# 8 PASS (deposit + EIP-712 hash + e2e release/mint)
```

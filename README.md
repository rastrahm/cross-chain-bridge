# 09 — Cross-Chain Bridge & Message Relay

Puente de tokens cross-chain y relé de mensajes con pruebas **ECDSA + EIP-712**, anti-replay y nonces. Solidity `0.8.24` + Foundry.

**Estado:** Fases **0–8** ✅ (módulo cerrado).

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
| [doc/SWC-AUDIT.md](./doc/SWC-AUDIT.md) | Auditoría SWC-100–136 |
| [doc/GAS.md](./doc/GAS.md) | Gas report baseline y optimizaciones |
| [doc/diagrama-clases.md](./doc/diagrama-clases.md) | UML de contratos |
| [doc/diagrama-flujo.md](./doc/diagrama-flujo.md) | Flujos lock/burn → release |
| [doc/flujograma.md](./doc/flujograma.md) | Flujograma operativo y pipeline TDD |

---

## Setup

```shell
export PATH="$HOME/.foundry/bin:$PATH"

forge install foundry-rs/forge-std@v1.16.2 --no-git
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git

forge build
forge test
forge snapshot --match-contract BridgeGasTest
```

---

## Tests

```shell
forge test
# 51 PASS (unit + burn/unlock + Replay + InvalidSignature + MessageRelay + fuzz + attack + gas)
```

### Seguridad

Ver [`doc/SWC-AUDIT.md`](./doc/SWC-AUDIT.md) (matriz SWC-100–136 + `test/attack/`).

### Gas

Ver [`doc/GAS.md`](./doc/GAS.md). Regenerar snapshot:

```shell
forge snapshot --match-contract BridgeGasTest
```

---

## Deploy local (Anvil)

```shell
# Terminal 1
anvil

# Terminal 2
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

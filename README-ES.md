# 09 — Cross-Chain Bridge & Message Relay

🌐 **Español** · [English](./README-EN.md)

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
| [doc/README-ES.md](./doc/README-ES.md) | Índice de documentación |
| [doc/PLANIFICACION-ES.md](./doc/PLANIFICACION-ES.md) | Plan, fases TDD y criterios |
| [doc/SWC-AUDIT-ES.md](./doc/SWC-AUDIT-ES.md) | Auditoría SWC-100–136 |
| [doc/GAS-ES.md](./doc/GAS-ES.md) | Gas report baseline y optimizaciones |
| [doc/diagrama-clases-ES.md](./doc/diagrama-clases-ES.md) | UML de contratos |
| [doc/diagrama-flujo-ES.md](./doc/diagrama-flujo-ES.md) | Flujos lock/burn → release |
| [doc/flujograma-ES.md](./doc/flujograma-ES.md) | Flujograma operativo y pipeline TDD |
| [doc/DEPLOY-TESTNET-ES.md](./doc/DEPLOY-TESTNET-ES.md) | Deploy en Sepolia + Base Sepolia |
| [doc/GUIA-TECNICA-ES.md](./doc/GUIA-TECNICA-ES.md) | Decisiones, lógica, gas |

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

Ver [`doc/SWC-AUDIT-ES.md`](./doc/SWC-AUDIT-ES.md) (matriz SWC-100–136 + `test/attack/`).

### Gas

Ver [`doc/GAS-ES.md`](./doc/GAS-ES.md). Regenerar snapshot:

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

## Deploy testnet

Guía completa: [`doc/DEPLOY-TESTNET-ES.md`](./doc/DEPLOY-TESTNET-ES.md).

```shell
cp .env.example .env   # PRIVATE_KEY, RELAYER_ADDRESS, SEPOLIA_RPC_URL, ...

forge script script/Deploy.s.sol:Deploy --rpc-url $SEPOLIA_RPC_URL --broadcast -vvvv
forge script script/Deploy.s.sol:Deploy --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvvv
```

Hace falta **un deploy por red**. El relayer (off-chain) une deposit en una con release en la otra.

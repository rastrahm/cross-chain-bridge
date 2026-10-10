# 09 — Cross-Chain Bridge & Message Relay

🌐 [Español](./README-ES.md) · **English**

Cross-chain token bridge and message relay with **ECDSA + EIP-712** proofs, anti-replay protection and nonces. Solidity `0.8.24` + Foundry.

**Status:** Phases **0–8** ✅ (module complete).

---

## Stack

| Layer | Technology |
|-------|------------|
| Contracts | Solidity `0.8.24` |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Crypto | EIP-712 + ECDSA (OpenZeppelin) |
| Libraries | OpenZeppelin Contracts v5.2, forge-std |
| Security | CEI, ReentrancyGuard, custom errors, SafeERC20 |

---

## Documentation

| Doc | Description |
|-----|-------------|
| [doc/README-EN.md](./doc/README-EN.md) | Documentation index |
| [doc/PLANIFICACION-EN.md](./doc/PLANIFICACION-EN.md) | Plan, TDD phases and criteria |
| [doc/SWC-AUDIT-EN.md](./doc/SWC-AUDIT-EN.md) | SWC-100–136 audit |
| [doc/GAS-EN.md](./doc/GAS-EN.md) | Baseline gas report and optimizations |
| [doc/diagrama-clases-EN.md](./doc/diagrama-clases-EN.md) | Contract UML |
| [doc/diagrama-flujo-EN.md](./doc/diagrama-flujo-EN.md) | Lock/burn → release flows |
| [doc/flujograma-EN.md](./doc/flujograma-EN.md) | Operational flowchart and TDD pipeline |
| [doc/DEPLOY-TESTNET-EN.md](./doc/DEPLOY-TESTNET-EN.md) | Deploy on Sepolia + Base Sepolia |
| [doc/GUIA-TECNICA-EN.md](./doc/GUIA-TECNICA-EN.md) | Decisions, logic, gas |

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

### Security

See [`doc/SWC-AUDIT-EN.md`](./doc/SWC-AUDIT-EN.md) (SWC-100–136 matrix + `test/attack/`).

### Gas

See [`doc/GAS-EN.md`](./doc/GAS-EN.md). Regenerate the snapshot:

```shell
forge snapshot --match-contract BridgeGasTest
```

---

## Local deploy (Anvil)

```shell
# Terminal 1
anvil

# Terminal 2
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

## Testnet deploy

Full guide: [`doc/DEPLOY-TESTNET-EN.md`](./doc/DEPLOY-TESTNET-EN.md).

```shell
cp .env.example .env   # PRIVATE_KEY, RELAYER_ADDRESS, SEPOLIA_RPC_URL, ...

forge script script/Deploy.s.sol:Deploy --rpc-url $SEPOLIA_RPC_URL --broadcast -vvvv
forge script script/Deploy.s.sol:Deploy --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvvv
```

You need **one deploy per network**. The (off-chain) relayer links a deposit on one network with a release on the other.

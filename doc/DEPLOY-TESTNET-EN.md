# Testnet deploy — practical guide

🌐 [Español](./DEPLOY-TESTNET-ES.md) · **English**

The bridge **does not live on a single network**. To actually use it you need **the same stack twice**: once on chain A and once on chain B. A bot (relayer) reads from one and sends transactions to the other.

This guide uses **Sepolia** + **Base Sepolia** (both free via faucet). You can swap them for any other EVM pair.

---

## 0. What you will deploy (per network)

On **each** testnet the script creates:

| Contract | Purpose |
|----------|---------|
| `MockERC20` (UND) | Toy token to lock (demo only) |
| `Bridge` | Locks / burns / mints / releases |
| `BridgeToken` | The "copy" token (created by the Bridge itself) |
| `MessageRelay` | Generic messages (optional for the token demo) |

Save the addresses printed by the console. You will need them.

---

## 1. Requirements

1. Foundry installed (`forge`, `cast`).
2. A test wallet (MetaMask or another).
3. Testnet ETH on **both** networks (gas).
4. An RPC (Alchemy, Infura, publicnode, etc.).

Typical faucets:

- Sepolia: [sepoliafaucet.com](https://www.sepoliafaucet.com/) / [cloud.google.com/application/web3/faucet](https://cloud.google.com/application/web3/faucet/ethereum/sepolia)
- Base Sepolia: [faucet.circle.com](https://faucet.circle.com/) or the one in the Base docs

**Important:** the `PRIVATE_KEY` in `.env` is the one that pays for the deploy. Never push it to Git.

---

## 2. `.env` file

Copy the example and fill it in:

```bash
cp .env.example .env
```

Minimum content:

```env
# Account that pays gas and deploys (with or without 0x, Foundry accepts both)
PRIVATE_KEY=tu_clave_hex_de_prueba

# Who can sign releases (can be the same wallet or a different one)
RELAYER_ADDRESS=0xTuDireccionRelayer

# How many signatures the Bridge requires (1 = simple, for the demo)
RELAYER_THRESHOLD=1

# RPCs
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/TU_KEY
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# Optional: verify on the block explorer
ETHERSCAN_API_KEY=tu_key_etherscan
# Base often uses the same explorer family; depending on the Foundry version:
# BASESCAN_API_KEY=...
```

In the demo, the relayer can be **the same** account as the deployer. For anything serious, keep them separate: one pays deploy gas, the other signs.

---

## 3. Deploy on Sepolia (chain A)

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd /ruta/a/09-cross-chain-bridge

# Load variables
set -a && source .env && set +a

forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  -vvvv
```

With Etherscan verification (if you have an API key):

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  --verify \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  -vvvv
```

Write down:

```text
Bridge_A=0x...
BridgeToken_A=0x...
Underlying_A=0x...
MessageRelay_A=0x...
```

Sepolia chain id: **11155111**.

---

## 4. Deploy on Base Sepolia (chain B)

Same command, different RPC:

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" \
  --broadcast \
  -vvvv
```

Write down:

```text
Bridge_B=0x...
BridgeToken_B=0x...
Underlying_B=0x...
MessageRelay_B=0x...
```

Base Sepolia chain id: **84532**.

Note: **Underlying_A and Underlying_B are different tokens** (each network has its own mock). That's fine for a demo. In a real product, you define which "real" token you custody on each side.

---

## 5. Test a minimal crossing (Sepolia → Base Sepolia)

Idea: lock UND on A and mint the copy token on B.

### 5.1 On Sepolia — approve + deposit

```bash
# Approve: the Bridge can take your UND
cast send "$Underlying_A" \
  "approve(address,uint256)" "$Bridge_A" 1000000000000000000 \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --private-key "$PRIVATE_KEY"

# Deposit: 1 UND to Base Sepolia, recipient = your address
cast send "$Bridge_A" \
  "deposit(address,uint256,uint256,address)" \
  "$Underlying_A" \
  1000000000000000000 \
  84532 \
  "$(cast wallet address --private-key $PRIVATE_KEY)" \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --private-key "$PRIVATE_KEY"
```

Look for the `Deposit` event (nonce, amount, etc.) in the explorer or with:

```bash
cast logs --address "$Bridge_A" --rpc-url "$SEPOLIA_RPC_URL" --from-block latest
```

### 5.2 Off-chain — sign the message (relayer)

There's no on-chain magic here: **you (or a script) sign** an EIP-712 message for the domain of **Bridge B** and send `release` to B.

Fields that must match (summary):

- `sourceChainId` = 11155111  
- `destinationChainId` = 84532  
- `nonce` = the one from the Deposit event  
- `target` = `Bridge_B`  
- `token` = `BridgeToken_B` (on the destination you mint the copy)  
- `amount` / `recipient` = the ones from the deposit  

In Foundry, the tests do this with `vm.sign`. On a real testnet you need a Node/Foundry script that:

1. Reads the event.  
2. Hashes EIP-712 with the domain separator of `Bridge_B`.  
3. Signs with the relayer key.  
4. Calls `release` on Base Sepolia.

If you want, the next step for the repo could be a `script/RelayDemo.s.sol` that signs and sends the `release` using environment variables (nonce, addresses, chain ids).

### 5.3 On Base Sepolia — release

```bash
# Pseudo-command: release(BridgeMessage, signatures)
# The exact encoding of the struct + bytes[] is best taken from the test helper
# or from the RelayDemo script (once we add it).
```

If the signature is valid and the nonce hasn't been used → `BridgeToken_B` gets minted to you.

---

## 6. "Why did it fail?" checklist

| Problem | What to check |
|---------|---------------|
| `Insufficient funds` | Faucet: no ETH, no deploy |
| `InvalidSignature` | You signed with the domain of the **wrong** chain (you must sign B's) |
| `InvalidChainId` | `destinationChainId` ≠ chain id where you call `release` |
| `InvalidTarget` | In the message, `target` must be exactly `Bridge_B` |
| `NonceAlreadyUsed` | That nonce was already released |
| Unauthorized relayer | `RELAYER_ADDRESS` from the deploy ≠ whoever signed |

---

## 7. Mental map (two deploys)

```text
Sepolia                         Your machine / bot                  Base Sepolia
────────                        ────────────────                    ────────────
Bridge_A  ──Deposit event───►   reads + signs EIP-712 ──release──►  Bridge_B
UND locked                      (relayer key)                      BridgeToken minted
```

The contracts **do not call each other across networks**. Only the relayer connects the two ends.

---

## 8. Cost and security (testnet)

- Deploying the `Bridge` is heavy (it includes `BridgeToken`). Make sure you have enough ETH headroom.
- Testnet keys: even so, don't reuse them on mainnet.
- Threshold `1` is for playing around. For real use you'd raise it to N distinct signatures.

---

## Quick commands

```bash
# Sepolia only
forge script script/Deploy.s.sol:Deploy --rpc-url $SEPOLIA_RPC_URL --broadcast -vvvv

# Base Sepolia only
forge script script/Deploy.s.sol:Deploy --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvvv
```

Once you have both sets of addresses printed, the "business" is deployed. The full end-to-end crossing is deposit → signature → release (section 5).

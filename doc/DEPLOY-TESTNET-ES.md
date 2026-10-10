# Deploy en testnet — guía práctica

🌐 **Español** · [English](./DEPLOY-TESTNET-EN.md)

El puente **no vive en una sola red**. Para usarlo de verdad necesitás **el mismo stack dos veces**: una vez en la cadena A y otra en la B. Un bot (relayer) lee una y manda transacciones a la otra.

Esta guía usa **Sepolia** + **Base Sepolia** (ambas gratis con faucet). Podés cambiar por cualquier otro par EVM.

---

## 0. Qué vas a desplegar (por cada red)

En **cada** testnet el script crea:

| Contrato | Para qué |
|----------|----------|
| `MockERC20` (UND) | Token de juguete para lockear (solo demo) |
| `Bridge` | Guarda / quema / mintea / suelta |
| `BridgeToken` | Ficha “copia” (la crea el Bridge solo) |
| `MessageRelay` | Mensajes genéricos (opcional para el demo de tokens) |

Guardá las direcciones que imprime la consola. Las vas a necesitar.

---

## 1. Requisitos

1. Foundry instalado (`forge`, `cast`).
2. Una wallet de prueba (MetaMask u otra).
3. ETH de testnet en **las dos** redes (gas).
4. Un RPC (Alchemy, Infura, publicnode, etc.).

Faucets típicos:

- Sepolia: [sepoliafaucet.com](https://www.sepoliafaucet.com/) / [cloud.google.com/application/web3/faucet](https://cloud.google.com/application/web3/faucet/ethereum/sepolia)
- Base Sepolia: [faucet.circle.com](https://faucet.circle.com/) o el de Base docs

**Importante:** la `PRIVATE_KEY` del `.env` es la que paga el deploy. Nunca la subas a Git.

---

## 2. Archivo `.env`

Copiá el ejemplo y completá:

```bash
cp .env.example .env
```

Contenido mínimo:

```env
# Cuenta que paga gas y despliega (sin 0x o con 0x, Foundry acepta ambos)
PRIVATE_KEY=tu_clave_hex_de_prueba

# Quién puede firmar releases (puede ser la misma wallet u otra)
RELAYER_ADDRESS=0xTuDireccionRelayer

# Cuántas firmas pide el Bridge (1 = simple para demo)
RELAYER_THRESHOLD=1

# RPCs
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/TU_KEY
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# Opcional: verificar en explorador
ETHERSCAN_API_KEY=tu_key_etherscan
# Base usa a menudo la misma familia de exploradores; según versión de Foundry:
# BASESCAN_API_KEY=...
```

El relayer en demo puede ser **la misma** cuenta que el deployer. En serio, mejor separar: una paga gas de deploy, otra firma.

---

## 3. Deploy en Sepolia (cadena A)

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd /ruta/a/09-cross-chain-bridge

# Carga variables
set -a && source .env && set +a

forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  -vvvv
```

Con verificación en Etherscan (si tenés API key):

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  --verify \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  -vvvv
```

Anotá:

```text
Bridge_A=0x...
BridgeToken_A=0x...
Underlying_A=0x...
MessageRelay_A=0x...
```

Chain id Sepolia: **11155111**.

---

## 4. Deploy en Base Sepolia (cadena B)

Mismo comando, otro RPC:

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" \
  --broadcast \
  -vvvv
```

Anotá:

```text
Bridge_B=0x...
BridgeToken_B=0x...
Underlying_B=0x...
MessageRelay_B=0x...
```

Chain id Base Sepolia: **84532**.

Ojo: **Underlying_A y Underlying_B son tokens distintos** (cada red tiene su mock). Eso está bien para demo. En un producto real, definís qué token “de verdad” custodiás en cada lado.

---

## 5. Probar un cruce mínimo (Sepolia → Base Sepolia)

Idea: lockear UND en A y mintear la ficha copia en B.

### 5.1 En Sepolia — approve + deposit

```bash
# Approve: el Bridge puede tomar tus UND
cast send "$Underlying_A" \
  "approve(address,uint256)" "$Bridge_A" 1000000000000000000 \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --private-key "$PRIVATE_KEY"

# Deposit: 1 UND hacia Base Sepolia, recipient = tu address
cast send "$Bridge_A" \
  "deposit(address,uint256,uint256,address)" \
  "$Underlying_A" \
  1000000000000000000 \
  84532 \
  "$(cast wallet address --private-key $PRIVATE_KEY)" \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --private-key "$PRIVATE_KEY"
```

Buscá el evento `Deposit` (nonce, amount, etc.) en el explorador o con:

```bash
cast logs --address "$Bridge_A" --rpc-url "$SEPOLIA_RPC_URL" --from-block latest
```

### 5.2 Off-chain — firmar el mensaje (relayer)

Acá no hay magia on-chain: **vos (o un script) firmás** un mensaje EIP-712 del dominio del **Bridge de B** y mandás `release` a B.

Campos que deben cuadrar (resumen):

- `sourceChainId` = 11155111  
- `destinationChainId` = 84532  
- `nonce` = el del evento Deposit  
- `target` = `Bridge_B`  
- `token` = `BridgeToken_B` (en destino minteás la copia)  
- `amount` / `recipient` = los del depósito  

En Foundry los tests hacen esto con `vm.sign`. En testnet real necesitás un script Node/Foundry que:

1. Lea el evento.  
2. Hashee EIP-712 con el domain separator de `Bridge_B`.  
3. Firme con la clave del relayer.  
4. Llame `release` en Base Sepolia.

Si querés, el siguiente paso del repo puede ser un `script/RelayDemo.s.sol` que firme y mande el `release` con variables de entorno (nonce, addresses, chain ids).

### 5.3 En Base Sepolia — release

```bash
# Pseudocomando: release(BridgeMessage, signatures)
# El encoding exacto del struct + bytes[] lo conviene sacar del helper de tests
# o del script RelayDemo (cuando lo agreguemos).
```

Si la firma es válida y el nonce no se usó → te mintean `BridgeToken_B`.

---

## 6. Checklist de “¿por qué falló?”

| Problema | Qué mirar |
|----------|-----------|
| `Insufficient funds` | Faucet: sin ETH no hay deploy |
| `InvalidSignature` | Firmaste con el domain de la cadena **equivocada** (hay que firmar el de B) |
| `InvalidChainId` | `destinationChainId` ≠ chain id de donde hacés `release` |
| `InvalidTarget` | En el mensaje, `target` debe ser exactamente `Bridge_B` |
| `NonceAlreadyUsed` | Ese nonce ya se liberó |
| Relayer no autorizado | `RELAYER_ADDRESS` del deploy ≠ quien firmó |

---

## 7. Mapa mental (dos deploys)

```text
Sepolia                         Tu máquina / bot                    Base Sepolia
────────                        ────────────────                    ────────────
Bridge_A  ──evento Deposit──►   lee + firma EIP-712  ──release──►  Bridge_B
UND locked                      (clave del relayer)                BridgeToken minteado
```

Los contratos **no se llaman entre redes**. Solo el relayer une las puntas.

---

## 8. Coste y seguridad (testnet)

- Deploy del `Bridge` es pesado (incluye `BridgeToken`). Asegurate de tener margen de ETH.
- Claves de testnet: igual no las reutilices en mainnet.
- Umbral `1` es para jugar. En serio subirías a N firmas distintas.

---

## Comandos rápidos

```bash
# Solo Sepolia
forge script script/Deploy.s.sol:Deploy --rpc-url $SEPOLIA_RPC_URL --broadcast -vvvv

# Solo Base Sepolia
forge script script/Deploy.s.sol:Deploy --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvvv
```

Cuando tengas las dos direcciones impresas, ya tenés el “negocio” desplegado. El cruce completo de punta a punta es deposit → firma → release (sección 5).

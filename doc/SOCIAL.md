# Borradores redes — Cross-Chain Bridge & Message Relay (módulo 09)

Links:

- **GitHub:** https://github.com/rastrahm/cross-chain-bridge  
- **GitLab:** https://gitlab.com/rastrahm/cross-chain-bridge  

> Si publicás un artículo largo (Medium/Hashnode/Mirror), poné esa URL como link principal y dejá los repos como “código”.

---

## LinkedIn (tono humano)

Cerré el módulo 09 de mi suite de smart contracts: un **puente cross-chain + relé de mensajes** en Solidity 0.8.24 y Foundry.

La parte que más me interesaba no era “quemar acá y acuñar allá”. Era que una firma válida **no se pueda reusar** en otra cadena, con otro nonce, o contra el contrato equivocado.

Qué quedó adentro:

- Lock → mint y burn → unlock, con `BridgeToken` controlado solo por el bridge  
- Pruebas EIP-712 + ECDSA (OpenZeppelin) y umbral N-of-M de relayers  
- Anti-replay: `sourceChainId`, `destinationChainId`, `nonce` y `target` dentro del hash tipado  
- Bitmap de nonces (256 por slot) + fast-path cuando el umbral es 1 (ahorro claro en releases seguidos)  
- `MessageRelay` para ejecutar calldata firmado en destino  
- Unit, replay, firmas inválidas, fuzz (1000), gas snapshot… y `test/attack/` (reentrancy, spoof de target, replay de firma)

También dejé planificación, diagramas, auditoría SWC y `doc/GAS.md`, porque si no documentás el puente, después nadie confía en el diseño.

Código (mismo proyecto en ambos lados):

GitHub → https://github.com/rastrahm/cross-chain-bridge  
GitLab → https://gitlab.com/rastrahm/cross-chain-bridge  

Si te interesa, ¿qué preferís que desarrolle en un próximo post: el dominio EIP-712 anti-replay, el umbral de relayers, o cómo armé los ataques de firma?

\#Solidity \#Foundry \#Web3 \#Bridge \#EIP712 \#CrossChain \#SmartContracts \#Ethereum \#OpenZeppelin \#DeFi

---

## X / Twitter — versión corta (1 post)

Cerré un puente cross-chain + message relay (Solidity 0.8.24 / Foundry).

EIP-712 + ECDSA, nonces anti-replay, umbral de relayers, lock/mint y burn/unlock. Fuzz + suite de ataques.

GitHub: https://github.com/rastrahm/cross-chain-bridge  
GitLab: https://gitlab.com/rastrahm/cross-chain-bridge  

\#Solidity \#Foundry \#EIP712 \#CrossChain \#Bridge

---

## X — hilo (opcional, más humano)

**1/**  
Terminé el módulo 09 de mi suite: puente cross-chain y relé de mensajes.

No quería solo el happy path. Quería que una firma “buena” no sirva para mint doble ni para ejecutarse en la cadena equivocada.

**2/**  
Stack: Solidity 0.8.24, Foundry, OZ v5 (EIP-712, ECDSA, SafeERC20, ReentrancyGuard).

Flujos: lock → mint y burn → unlock. Más un `MessageRelay` genérico con el mismo esquema de firmas.

**3/**  
Seguridad que me importaba:

- domain separator + campos anti-replay en el struct  
- nonce de un solo uso (bitmap)  
- target tiene que ser este bridge  
- firmante fuera del set / payload alterado / v,r,s rotos → revert  
- reentrar deposit o execute → bloqueado  

**4/**  
Tests: e2e, replay, firmas inválidas, N-of-M, fuzz 1000, gas, y `test/attack/`.

Docs: plan, diagramas, SWC-AUDIT y GAS (con el ahorro del bitmap en el 2º release).

**5/**  
Repo (espejo):

https://github.com/rastrahm/cross-chain-bridge  
https://gitlab.com/rastrahm/cross-chain-bridge  

Local: `forge test` y, con Anvil, el `Deploy.s.sol`.

---

## Notas para publicar

1. Pegá los dos links (GitHub + GitLab); mucha gente mira uno u otro.  
2. En LinkedIn, 1 imagen ayuda: captura de `forge test --summary` o el diagrama de flujo lock/burn → release.  
3. En X, la versión corta entra mejor; el hilo si querés contar el “por qué” del anti-replay.  
4. El gancho no es UI: es criptografía de mensajes + replay protection.

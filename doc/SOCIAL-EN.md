# Social media drafts — Cross-Chain Bridge & Message Relay (module 09)

🌐 [Español](./SOCIAL-ES.md) · **English**

Links:

- **GitHub:** https://github.com/rastrahm/cross-chain-bridge  
- **GitLab:** https://gitlab.com/rastrahm/cross-chain-bridge  

> If you publish a long-form article (Medium/Hashnode/Mirror), use that URL as the main link and leave the repos as "code".

---

## LinkedIn (human tone)

Finally, 5 free minutes, so I'm picking the translation back up.

I wrapped up module 09 of my smart contracts suite: a **cross-chain bridge + message relay** built with Solidity 0.8.24 and Foundry.

The part I cared about most wasn't "burn here, mint there". It was making sure a valid signature **can't be reused** on another chain, with another nonce, or against the wrong contract.

What's inside:

- Lock → mint and burn → unlock, with a `BridgeToken` that only the bridge can control  
- EIP-712 + ECDSA proofs (OpenZeppelin) and an N-of-M relayer threshold  
- Anti-replay: `sourceChainId`, `destinationChainId`, `nonce` and `target` inside the typed hash  
- Nonce bitmap (256 per slot) + a fast path when the threshold is 1 (clear savings on back-to-back releases)  
- `MessageRelay` to execute signed calldata on the destination chain  
- Unit, replay, invalid-signature, fuzz (1000 runs) and gas snapshot tests… plus `test/attack/` (reentrancy, target spoofing, signature replay)

I also included the planning, diagrams, an SWC audit and `doc/GAS-EN.md`, because if you don't document a bridge, nobody ends up trusting the design.

Code (same project on both platforms):

GitHub → https://github.com/rastrahm/cross-chain-bridge  
GitLab → https://gitlab.com/rastrahm/cross-chain-bridge  

If you're interested, what should I cover in a future post: the anti-replay EIP-712 domain, the relayer threshold, or how I built the signature attacks?

\#Solidity \#Foundry \#Web3 \#Bridge \#EIP712 \#CrossChain \#SmartContracts \#Ethereum \#OpenZeppelin \#DeFi

---

## X / Twitter — short version (1 post)

Wrapped up a cross-chain bridge + message relay (Solidity 0.8.24 / Foundry).

EIP-712 + ECDSA, anti-replay nonces, relayer threshold, lock/mint and burn/unlock. Fuzzing + an attack suite.

GitHub: https://github.com/rastrahm/cross-chain-bridge  
GitLab: https://gitlab.com/rastrahm/cross-chain-bridge  

\#Solidity \#Foundry \#EIP712 \#CrossChain \#Bridge

---

## X — thread (optional, more personal)

**1/**  
Finished module 09 of my suite: a cross-chain bridge and message relay.

I didn't want just the happy path. I wanted a "good" signature to be useless for a double mint or for executing on the wrong chain.

**2/**  
Stack: Solidity 0.8.24, Foundry, OZ v5 (EIP-712, ECDSA, SafeERC20, ReentrancyGuard).

Flows: lock → mint and burn → unlock. Plus a generic `MessageRelay` using the same signature scheme.

**3/**  
Security I cared about:

- domain separator + anti-replay fields in the struct  
- single-use nonce (bitmap)  
- target must be this bridge  
- signer outside the set / tampered payload / broken v,r,s → revert  
- reentering deposit or execute → blocked  

**4/**  
Tests: e2e, replay, invalid signatures, N-of-M, fuzz 1000, gas, and `test/attack/`.

Docs: plan, diagrams, SWC-AUDIT and GAS (including the bitmap savings on the 2nd release).

**5/**  
Repo (mirrored):

https://github.com/rastrahm/cross-chain-bridge  
https://gitlab.com/rastrahm/cross-chain-bridge  

Locally: `forge test` and, with Anvil, `Deploy.s.sol`.

---

## Publishing notes

1. Paste both links (GitHub + GitLab); many people look at one or the other.  
2. On LinkedIn, 1 image helps: a screenshot of `forge test --summary` or the lock/burn → release flow diagram.  
3. On X, the short version performs better; use the thread if you want to explain the "why" behind anti-replay.  
4. The hook isn't the UI: it's message cryptography + replay protection.

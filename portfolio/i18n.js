const I18N = {
  es: {
    'html.lang': 'es',
    'meta.title': 'Cross-Chain Bridge & Message Relay — Rolando Strahm',
    'meta.description':
      'Puente cross-chain con EIP-712/ECDSA, anti-replay, optimización de gas y auditoría SWC. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Proyecto',
    'nav.pillars': 'Pilares',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Proceso',
    'nav.attacks': 'Ataques',
    'nav.repos': 'Repos',
    'nav.close': '← Cerrar',

    'hero.tag': '// MÓDULO 09 · PORTFOLIO WEB3',
    'hero.title': 'CROSS-CHAIN BRIDGE<br>MESSAGE RELAY',
    'hero.role': 'Solidity 0.8.24 · Foundry · EIP-712 · Gas · SWC',
    'hero.sub':
      'Lock/mint y burn/unlock con pruebas tipadas, umbral de relayers y anti-replay. Gas documentado (bitmap −11% en 2º release) y campañas defensivas SWC.',
    'hero.cta1': 'Ver en GitHub',
    'hero.cta2': 'Ver en GitLab',

    'ov.eyebrow': '// 01 — CONTEXTO',
    'ov.title': 'Por qué este proyecto',
    'ov.lead':
      'Después de flash loans, construí un <strong>puente cross-chain</strong> y un <strong>MessageRelay</strong>. El foco no es solo quemar y acuñar: es que una firma válida <strong>no se pueda reusar</strong> en otra cadena, con otro nonce o contra el contrato equivocado — más <strong>gas</strong> y <strong>SWC</strong> con tests que demuestran que el ataque falla.',

    'pi.eyebrow': '// 02 — TRES PILARES',
    'pi.title': 'Qué entrega el módulo',
    'p1.num': '// PILAR_01',
    'p1.title': 'Bridge + Relay',
    'p1.desc':
      'Bridge (lock/burn → mint/unlock) + MessageRelay: EIP-712, ECDSA, umbral N-of-M y BridgeToken solo controlado por el bridge.',
    'p1.l1': 'Anti-replay: chainIds + nonce + target',
    'p1.l2': 'Umbral de relayers (1-of-N / N-of-M)',
    'p1.l3': 'CEI + ReentrancyGuard en deposit/burn/release/execute',
    'p2.num': '// PILAR_02',
    'p2.title': 'Optimización de gas',
    'p2.desc':
      'Bitmap de nonces, fast-path threshold=1, hash calldata, immutables y snapshot Foundry en doc/GAS-ES.md.',
    'p2.l1': 'Nonce bitmap: −11.1% en 2º release',
    'p2.l2': 'RelayerSig sin alloc en umbral 1',
    'p2.l3': '.gas-snapshot + optimizer_runs 10k',
    'p3.num': '// PILAR_03',
    'p3.title': 'Verificación SWC',
    'p3.desc':
      'Matriz SWC-100–136, ReentrancyAttack, TargetSpoof, SignatureReplay, InvalidSignature, fuzz ≥ 1000.',
    'p3.l1': '0 vulnerabilidades explotables',
    'p3.l2': '33 mitigados / N/A · 3 info',
    'p3.l3': '51 tests Foundry PASS',

    'gas.eyebrow': '// 03 — OPTIMIZACIÓN DE GAS',
    'gas.title': 'Hot path barato, tradeoffs claros',
    'gas.lead':
      'Fase 8: baseline en <code>doc/GAS-ES.md</code> y <code>.gas-snapshot</code>. Snapshot: <strong>2º release −11.1%</strong> (221 138 → 196 620) gracias al bitmap. Medianas: <strong>deposit ~85k</strong>, <strong>release ~113k</strong> (min caliente ~61k), <strong>execute ~89k</strong>.',
    'gas.th1': 'Optimización',
    'gas.th2': 'Tradeoff / efecto',
    'gas.r1a': 'Nonce bitmap (256 nonces / slot)',
    'gas.r1b': 'SSTORE caliente en releases secuenciales (−11% en 2º release)',
    'gas.r2a': 'RelayerSig fast-path threshold == 1',
    'gas.r2b': 'Sin alloc del array seen en el caso 1-of-N',
    'gas.r3a': 'BridgeHash.hash(calldata)',
    'gas.r3b': 'Evita copia memory del BridgeMessage / RelayMessage',
    'gas.r4a': 'immutable bridgeToken / bridge',
    'gas.r4b': 'Sin SLOAD en mint path del wrapped',
    'gas.r5a': 'BridgeToken.mint tipado',
    'gas.r5b': 'Menos indirección vs cast a interfaz genérica',
    'gas.r6a': 'Custom errors + unchecked ++',
    'gas.r6b': 'Reverts compactos; loops sin overflow checks redundantes',
    'gas.r7a': 'optimizer_runs = 10_000',
    'gas.r7b': 'Deploy más caro; runtime de release/execute priorizado',

    'swc.eyebrow': '// 04 — VERIFICACIÓN SWC',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Matriz <strong>SWC-100 → SWC-136</strong> sobre Bridge / MessageRelay / BridgeToken / BridgeHash. Informe: <code>doc/SWC-AUDIT-ES.md</code>. Conclusión: <strong>0 vulnerabilidades explotables</strong> en el alcance v1 (EIP-712 + lock/mint · burn/unlock).',
    'swc.s1': 'Mitigados / N/A',
    'swc.s2': 'Informativos (diseño)',
    'swc.s3': 'Vulnerables',
    'swc.th1': 'SWC clave',
    'swc.th2': 'Mitigación en el contrato',
    'swc.r107': 'Reentrancy: nonReentrant en deposit/burn/release/execute + test/attack',
    'swc.r117': 'Malleabilidad: OZ ECDSA.tryRecover (s/v normalizados)',
    'swc.r121': 'Replay: domain EIP-712 + chainIds + nonce bitmap + target',
    'swc.r122': 'Firmas: umbral isRelayer; InvalidSignature / ThresholdNotMet',
    'swc.r104': 'Unchecked return: SafeERC20; execute chequea success → ExecutionFailed',
    'swc.r103': 'Floating pragma: pragma solidity 0.8.24 fijo',
    'swc.info': 'INFORMATIVO',
    'swc.i1t': 'Orden de txs / relayers',
    'swc.i1d':
      'release/execute son públicos: el primero que publica consume el nonce. Sin doble mint (NonceAlreadyUsed).',
    'swc.i2t': 'Trust del set de relayers',
    'swc.i2d':
      'Relayers coludidos pueden firmar mensajes falsos. Mitigación v1: Ownable2Step + umbral N-of-M documentado.',

    'pr.eyebrow': '// 05 — PROCESO',
    'pr.title': 'Fases 0–8 cerradas',
    'pr.lead':
      'TDD por gates: docs + scaffold, tests rojos, BridgeToken/deposit, release+vm.sign, replay, firmas inválidas, MessageRelay N-of-M, fuzz/SWC/attack, gas + Deploy + burn/unlock.',
    'ph.02': 'Docs · scaffold · tests rojos · BridgeToken/deposit',
    'ph.34': 'release EIP-712 · replay anti-reuse',
    'ph.56': 'Firmas inválidas · MessageRelay N-of-M',
    'ph.7': 'Fuzz · SWC · test/attack',
    'ph.8': 'Gas · Deploy · burn→unlock',
    'st.1': 'Fases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC críticos',
    'st.4': 'Attack suites',
    'term.label': 'rolando@strahm:~/09-cross-chain-bridge',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 51 passed · 0 failed',
    'term.3': 'cat doc/SWC-AUDIT-ES.md | head',
    'term.4': 'Vulnerable: 0 · Informativos: 3 · Mitigados/N/A: 33',
    'term.5': 'echo status',
    'term.6': 'MODULE_09_CLOSED · GAS_SWC_ATTACK_CLOSED',

    'at.eyebrow': '// 06 — CAMPAÑAS DE ATAQUE',
    'at.title': 'Defensivo, no ofensivo',
    'at.lead':
      'Suites en test/attack, Replay, InvalidSignature y fuzz: el “éxito” del ataque es que revierte sin doble mint. Sin PoCs de exploit.',
    'cA.t': 'Reentrancy',
    'cA.d': 'Reentrar deposit / execute desde token o target → guard.',
    'cB.t': 'Target spoof',
    'cB.d': 'target de otro bridge / mint directo → InvalidTarget / OnlyBridge.',
    'cC.t': 'Signature replay',
    'cC.d': 'Mismo mensaje o domain cruzado → NonceAlreadyUsed / InvalidSignature.',
    'cD.t': 'Firma inválida',
    'cD.d': 'Wrong signer, tamper, v/r/s malos, umbral → revert.',
    'cE.t': 'Fuzz',
    'cE.d': 'amount / chainId / nonce con bound(); 1000 runs.',

    're.eyebrow': '// 07 — CÓDIGO ABIERTO',
    're.title': 'Repositorios',
    're.lead':
      'Mismo código en GitHub y GitLab: contratos, tests, GAS-ES.md, SWC-AUDIT-ES.md, diagramas y Deploy.s.sol.',
    're.cta': 'Contactar',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Cross-Chain Bridge · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · EIP-712 · ALL_SYSTEMS_OPERATIONAL',
  },

  en: {
    'html.lang': 'en',
    'meta.title': 'Cross-Chain Bridge & Message Relay — Rolando Strahm',
    'meta.description':
      'Cross-chain bridge with EIP-712/ECDSA, anti-replay, gas optimization, and SWC audit. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Project',
    'nav.pillars': 'Pillars',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Process',
    'nav.attacks': 'Attacks',
    'nav.repos': 'Repos',
    'nav.close': '← Close',

    'hero.tag': '// MODULE 09 · WEB3 PORTFOLIO',
    'hero.title': 'CROSS-CHAIN BRIDGE<br>MESSAGE RELAY',
    'hero.role': 'Solidity 0.8.24 · Foundry · EIP-712 · Gas · SWC',
    'hero.sub':
      'Lock/mint and burn/unlock with typed proofs, relayer threshold, and anti-replay. Documented gas (bitmap −11% on 2nd release) and defensive SWC campaigns.',
    'hero.cta1': 'View on GitHub',
    'hero.cta2': 'View on GitLab',

    'ov.eyebrow': '// 01 — CONTEXT',
    'ov.title': 'Why this project',
    'ov.lead':
      'After flash loans, I built a <strong>cross-chain bridge</strong> and a <strong>MessageRelay</strong>. The point is not only burn-and-mint — it is making sure a valid signature <strong>cannot be reused</strong> on another chain, with another nonce, or against the wrong contract — plus <strong>gas</strong> and <strong>SWC</strong> with tests that prove the attack fails.',

    'pi.eyebrow': '// 02 — THREE PILLARS',
    'pi.title': 'What the module ships',
    'p1.num': '// PILLAR_01',
    'p1.title': 'Bridge + Relay',
    'p1.desc':
      'Bridge (lock/burn → mint/unlock) + MessageRelay: EIP-712, ECDSA, N-of-M threshold, and a BridgeToken only the bridge can mint/burn.',
    'p1.l1': 'Anti-replay: chainIds + nonce + target',
    'p1.l2': 'Relayer threshold (1-of-N / N-of-M)',
    'p1.l3': 'CEI + ReentrancyGuard on deposit/burn/release/execute',
    'p2.num': '// PILLAR_02',
    'p2.title': 'Gas optimization',
    'p2.desc':
      'Nonce bitmaps, threshold=1 fast-path, calldata hashing, immutables, and a Foundry snapshot in doc/GAS-EN.md.',
    'p2.l1': 'Nonce bitmap: −11.1% on 2nd release',
    'p2.l2': 'RelayerSig with no alloc at threshold 1',
    'p2.l3': '.gas-snapshot + optimizer_runs 10k',
    'p3.num': '// PILLAR_03',
    'p3.title': 'SWC verification',
    'p3.desc':
      'SWC-100–136 matrix, ReentrancyAttack, TargetSpoof, SignatureReplay, InvalidSignature, fuzz ≥ 1000.',
    'p3.l1': '0 exploitable vulnerabilities',
    'p3.l2': '33 mitigated / N/A · 3 info',
    'p3.l3': '51 Foundry tests PASS',

    'gas.eyebrow': '// 03 — GAS OPTIMIZATION',
    'gas.title': 'Cheap hot path, clear tradeoffs',
    'gas.lead':
      'Phase 8: baseline in <code>doc/GAS-EN.md</code> and <code>.gas-snapshot</code>. Snapshot: <strong>2nd release −11.1%</strong> (221,138 → 196,620) via the bitmap. Medians: <strong>deposit ~85k</strong>, <strong>release ~113k</strong> (warm min ~61k), <strong>execute ~89k</strong>.',
    'gas.th1': 'Optimization',
    'gas.th2': 'Tradeoff / effect',
    'gas.r1a': 'Nonce bitmap (256 nonces / slot)',
    'gas.r1b': 'Warm SSTORE on sequential releases (−11% on 2nd release)',
    'gas.r2a': 'RelayerSig fast-path threshold == 1',
    'gas.r2b': 'No seen[] allocation in the 1-of-N case',
    'gas.r3a': 'BridgeHash.hash(calldata)',
    'gas.r3b': 'Avoids memory copy of BridgeMessage / RelayMessage',
    'gas.r4a': 'immutable bridgeToken / bridge',
    'gas.r4b': 'No SLOAD on the wrapped mint path',
    'gas.r5a': 'Typed BridgeToken.mint',
    'gas.r5b': 'Less indirection vs a generic interface cast',
    'gas.r6a': 'Custom errors + unchecked ++',
    'gas.r6b': 'Compact reverts; loops without redundant overflow checks',
    'gas.r7a': 'optimizer_runs = 10_000',
    'gas.r7b': 'Higher deploy cost; release/execute runtime prioritized',

    'swc.eyebrow': '// 04 — SWC VERIFICATION',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Full matrix <strong>SWC-100 → SWC-136</strong> on Bridge / MessageRelay / BridgeToken / BridgeHash. Report: <code>doc/SWC-AUDIT-EN.md</code>. Conclusion: <strong>0 exploitable vulnerabilities</strong> in v1 scope (EIP-712 + lock/mint · burn/unlock).',
    'swc.s1': 'Mitigated / N/A',
    'swc.s2': 'Informational (design)',
    'swc.s3': 'Vulnerable',
    'swc.th1': 'Key SWC',
    'swc.th2': 'Mitigation in the contract',
    'swc.r107': 'Reentrancy: nonReentrant on deposit/burn/release/execute + test/attack',
    'swc.r117': 'Malleability: OZ ECDSA.tryRecover (normalized s/v)',
    'swc.r121': 'Replay: EIP-712 domain + chainIds + nonce bitmap + target',
    'swc.r122': 'Signatures: isRelayer threshold; InvalidSignature / ThresholdNotMet',
    'swc.r104': 'Unchecked return: SafeERC20; execute checks success → ExecutionFailed',
    'swc.r103': 'Floating pragma: fixed pragma solidity 0.8.24',
    'swc.info': 'INFORMATIONAL',
    'swc.i1t': 'Tx ordering / relayers',
    'swc.i1d':
      'release/execute are public: the first publisher consumes the nonce. No double mint (NonceAlreadyUsed).',
    'swc.i2t': 'Relayer-set trust',
    'swc.i2d':
      'Colluding relayers can sign false messages. v1 mitigation: Ownable2Step + documented N-of-M threshold.',

    'pr.eyebrow': '// 05 — PROCESS',
    'pr.title': 'Phases 0–8 closed',
    'pr.lead':
      'Gate-based TDD: docs + scaffold, red tests, BridgeToken/deposit, release+vm.sign, replay, invalid signatures, MessageRelay N-of-M, fuzz/SWC/attack, gas + Deploy + burn/unlock.',
    'ph.02': 'Docs · scaffold · red tests · BridgeToken/deposit',
    'ph.34': 'EIP-712 release · anti-reuse replay',
    'ph.56': 'Invalid signatures · MessageRelay N-of-M',
    'ph.7': 'Fuzz · SWC · test/attack',
    'ph.8': 'Gas · Deploy · burn→unlock',
    'st.1': 'Phases',
    'st.2': 'Tests PASS',
    'st.3': 'Critical SWC',
    'st.4': 'Attack suites',
    'term.label': 'rolando@strahm:~/09-cross-chain-bridge',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 51 passed · 0 failed',
    'term.3': 'cat doc/SWC-AUDIT-EN.md | head',
    'term.4': 'Vulnerable: 0 · Informational: 3 · Mitigated/N/A: 33',
    'term.5': 'echo status',
    'term.6': 'MODULE_09_CLOSED · GAS_SWC_ATTACK_CLOSED',

    'at.eyebrow': '// 06 — ATTACK CAMPAIGNS',
    'at.title': 'Defensive, not offensive',
    'at.lead':
      'Suites under test/attack, Replay, InvalidSignature, and fuzz: a successful “attack” means it reverts with no double mint. No exploit PoCs.',
    'cA.t': 'Reentrancy',
    'cA.d': 'Reenter deposit / execute from token or target → guard.',
    'cB.t': 'Target spoof',
    'cB.d': 'Other-bridge target / direct mint → InvalidTarget / OnlyBridge.',
    'cC.t': 'Signature replay',
    'cC.d': 'Same message or cross-domain → NonceAlreadyUsed / InvalidSignature.',
    'cD.t': 'Invalid signature',
    'cD.d': 'Wrong signer, tamper, bad v/r/s, threshold → revert.',
    'cE.t': 'Fuzz',
    'cE.d': 'amount / chainId / nonce with bound(); 1000 runs.',

    're.eyebrow': '// 07 — OPEN SOURCE',
    're.title': 'Repositories',
    're.lead':
      'Same codebase on GitHub and GitLab: contracts, tests, GAS-EN.md, SWC-AUDIT-EN.md, diagrams, and Deploy.s.sol.',
    're.cta': 'Contact',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Cross-Chain Bridge · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · EIP-712 · ALL_SYSTEMS_OPERATIONAL',
  },
};

function setLanguage(lang) {
  const dict = I18N[lang] || I18N.es;
  document.documentElement.lang = dict['html.lang'];
  document.title = dict['meta.title'];

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc && dict['meta.description']) {
    metaDesc.setAttribute('content', dict['meta.description']);
  }

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    const val = dict[key];
    if (val == null) return;
    if (el.hasAttribute('data-i18n-html')) el.innerHTML = val;
    else el.textContent = val;
  });

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.lang === lang);
  });

  localStorage.setItem('bridge-portfolio-lang', lang);

  const url = new URL(window.location.href);
  url.searchParams.set('lang', lang);
  history.replaceState(null, '', url);
}

function initI18n() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get('lang');
  const saved = localStorage.getItem('bridge-portfolio-lang');
  const preferred =
    (fromQuery === 'en' || fromQuery === 'es' ? fromQuery : null) ||
    saved ||
    (navigator.language?.startsWith('en') ? 'en' : 'es');

  setLanguage(preferred);

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => setLanguage(btn.dataset.lang));
  });
}

document.addEventListener('DOMContentLoaded', initI18n);

#!/usr/bin/env node
/**
 * PerpVault keeper.
 *
 * Without this nothing rebalances, so the de-risk band never runs, bridged
 * capital never reaches margin, and queued redemptions are never funded. It is
 * an availability dependency, not a trust one: every action below is either
 * permissionless or bounded by on-chain checks, so a compromised keeper cannot
 * take funds — it can only fail to act, or act at a bad moment.
 *
 * Ordering matters and is deliberate:
 *   1. flagDistress   latch a liquidated vault shut before anything else
 *   2. settleBridge   recognise credited capital so NAV and margin are current
 *   3. fundClaims     exiting holders come before redeploying into the position
 *   4. rebalance      only then move the position toward target
 *
 * Run:  RPC=... PRIVATE_KEY=0x... VAULT=0x... node keeper.mjs [--once] [--dry]
 */
import { createPublicClient, createWalletClient, http, parseAbi, formatUnits } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

const RPC = process.env.RPC ?? 'https://rpcs.chain.link/hyperevm/testnet';
const VAULT = process.env.VAULT;
const PK = process.env.PRIVATE_KEY;
const ONCE = process.argv.includes('--once');
const DRY = process.argv.includes('--dry');
const INTERVAL_MS = Number(process.env.INTERVAL_MS ?? 60_000);
// Do not trade for drift smaller than this: every rebalance costs ~9bp round
// trip, measured on chain 998, so chasing small deviations loses money.
const DRIFT_BAND_BPS = BigInt(process.env.DRIFT_BAND_BPS ?? 500);

if (!VAULT) throw new Error('VAULT is required');

const abi = parseAbi([
  'function totalAssets() view returns (uint256)',
  'function notional() view returns (uint256)',
  'function coreEquity() view returns (uint256)',
  'function idleAssets() view returns (uint256)',
  'function pendingBridge() view returns (uint256)',
  'function bridgeInFlight() view returns (uint256)',
  'function claimSharesEscrowed() view returns (uint256)',
  'function coreSpot() view returns (uint256)',
  'function leveragedEquity() view returns (uint256)',
  'function pendingWithdraw() view returns (uint256)',
  'function withdrawInFlight() view returns (uint256)',
  'function convertToAssets(uint256) view returns (uint256)',
  'function settleWithdraw() returns (uint256)',
  'event Deposited(address indexed caller, uint256 assets, uint256 shares, uint256 navUsed)',
  'event RedemptionQueued(address indexed receiver, uint256 shares)',
  'function withdrawFromCore(uint256)',
  'function moveUsdClass(uint64,bool)',
  'function claimSharesSettled() view returns (uint256)',
  'function claimPot() view returns (uint256)',
  'function targetLeverageBps() view returns (uint256)',
  'function maxOracleDeviationBps() view returns (uint256)',
  'function markOracleDeviationBps() view returns (uint256)',
  'function rebalanceCooldown() view returns (uint256)',
  'function lastRebalanceAt() view returns (uint256)',
  'function depositsFrozen() view returns (bool)',
  'function isDistressed() view returns (bool)',
  'function maintenanceMargin() view returns (uint256)',
  'function flagDistress() returns (bool)',
  'function settleBridge() returns (uint256)',
  'function fundClaims() returns (uint256)',
  'function rebalance() returns (int256)',
]);

const pub = createPublicClient({ transport: http(RPC) });
const account = PK ? privateKeyToAccount(PK) : null;
const wallet = account ? createWalletClient({ account, transport: http(RPC) }) : null;

const usd = (v) => Number(formatUnits(v, 6)).toLocaleString(undefined, { minimumFractionDigits: 2 });

async function read() {
  const keys = [
    'totalAssets', 'notional', 'coreEquity', 'idleAssets', 'pendingBridge',
    'bridgeInFlight', 'claimSharesEscrowed', 'claimSharesSettled', 'claimPot', 'targetLeverageBps',
    'coreSpot', 'leveragedEquity', 'pendingWithdraw', 'withdrawInFlight',
    'maxOracleDeviationBps', 'markOracleDeviationBps', 'rebalanceCooldown',
    'lastRebalanceAt', 'depositsFrozen', 'isDistressed', 'maintenanceMargin',
  ];
  const out = await Promise.all(
    keys.map((k) => pub.readContract({ address: VAULT, abi, functionName: k }).catch(() => null)),
  );
  return Object.fromEntries(keys.map((k, i) => [k, out[i]]));
}

async function send(fn, why, args = []) {
  if (DRY || !wallet) {
    console.log(`    would call ${fn}(${args.join(', ')}) — ${why}`);
    return null;
  }
  const hash = await wallet.writeContract({ address: VAULT, abi, functionName: fn, args, chain: null });
  // Wait for inclusion before the next action: two writes in one tick otherwise
  // race the account nonce (found in the P3 drill — the second send used a stale
  // nonce and the tick crashed mid-sequence).
  await pub.waitForTransactionReceipt({ hash, timeout: 60_000 });
  console.log(`    ${fn}() -> ${hash}   (${why})`);
  return hash;
}

async function tick() {
  const s = await read();
  if (s.totalAssets === null) {
    console.log('  vault unreadable — precompiles may be unavailable on this chain');
    return;
  }

  const equity = s.totalAssets;
  // Drift is measured against the equity the vault actually LEVERS —
  // leveragedEquity excludes escrowed exits. Measuring against totalAssets
  // shows a queued exit as zero drift and the trim that funds it never fires
  // (found in the P3 lifecycle drill: 30% queued, keeper reported 2.00x and
  // skipped, position never shrank).
  const levBase = (s.leveragedEquity ?? equity) > 0n ? (s.leveragedEquity ?? equity) : equity;
  const lev = levBase > 0n ? (s.notional * 10_000n) / levBase : 0n;
  console.log(
    `  equity ${usd(equity)}  notional ${usd(s.notional)}  lev ${(Number(lev) / 10_000).toFixed(2)}x` +
      `  target ${(Number(s.targetLeverageBps) / 10_000).toFixed(2)}x  dev ${s.markOracleDeviationBps ?? 'n/a'}bps` +
      `${s.depositsFrozen ? '  [DEPOSITS FROZEN]' : ''}`,
  );

  // 1. A distressed vault must stop taking money before anything else happens.
  if (s.isDistressed && !s.depositsFrozen) {
    await send('flagDistress', 'equity at or below maintenance');
  }

  // 2. Recognise bridged capital, so NAV and available margin are current.
  if (s.bridgeInFlight > 0n && s.pendingBridge < s.bridgeInFlight) {
    await send('settleBridge', `${usd(s.bridgeInFlight - s.pendingBridge)} credited`);
  }

  // 3. Recognise capital coming BACK from Core, so it can fund exits.
  if (s.withdrawInFlight > 0n && s.pendingWithdraw < s.withdrawInFlight) {
    await send('settleWithdraw', `${usd(s.withdrawInFlight - s.pendingWithdraw)} landed on HyperEVM`);
  }

  // 4. Queued exits: walk the freed margin home, perp -> spot -> HyperEVM.
  //    rebalance() sizes off leveragedEquity(), so step 5 does the trimming; this
  //    only moves what that trim released. The two legs are deliberately on
  //    separate ticks: the class transfer is a CoreWriter action, so the spot
  //    balance it credits is not readable until after this transaction.
  const freeForClaims = s.idleAssets > s.claimPot ? s.idleAssets - s.claimPot : 0n;
  if (s.claimSharesEscrowed > 0n) {
    const owed = await pub
      .readContract({ address: VAULT, abi, functionName: 'convertToAssets', args: [s.claimSharesEscrowed] })
      .catch(() => 0n);
    const short = owed > freeForClaims ? owed - freeForClaims : 0n;

    // The contract serialises the bridge: withdrawFromCore and moveUsdClass
    // revert with BridgeBusy while an inbound leg is still measuring its spot
    // delta. Step 2 settles the inbound leg, so this only defers a tick when a
    // credit is genuinely still in flight.
    if (s.bridgeInFlight > 0n) {
      console.log(`    inbound bridge still in flight (${usd(s.bridgeInFlight)}), deferring exit legs`);
    } else if (s.coreSpot > 0n && short > 0n) {
      const pull = s.coreSpot < short ? s.coreSpot : short;
      await send('withdrawFromCore', `${usd(pull)} spot -> HyperEVM for exits`, [pull]);
    } else if (short > 0n) {
      // Margin the position no longer needs, now that sizing excludes the exit.
      const needed = s.targetLeverageBps > 0n ? (s.notional * 10_000n) / s.targetLeverageBps : 0n;
      const spare = s.coreEquity > needed ? s.coreEquity - needed : 0n;
      const pull = spare < short ? spare : short;
      if (pull > 0n) await send('moveUsdClass', `${usd(pull)} perp -> spot for exits`, [pull, false]);
      else console.log(`    ${usd(short)} owed on exits, waiting on the unwind`);
    }
  }

  // 5. Settle whatever the buffer can already cover.
  if (s.claimSharesEscrowed > 0n && freeForClaims > 0n) {
    await send('fundClaims', `${usd(freeForClaims)} free against queued exits`);
  }

  // 6. Rebalance last, and only when it is both allowed and worth it.
  const now = BigInt(Math.floor(Date.now() / 1000));
  const nextAllowed = s.lastRebalanceAt + s.rebalanceCooldown;
  const drift = lev > s.targetLeverageBps ? lev - s.targetLeverageBps : s.targetLeverageBps - lev;

  if (s.markOracleDeviationBps === null || s.maxOracleDeviationBps === null) {
    // An older deployment without the oracle guard. Refuse to trade rather than
    // assume the price is sane.
    console.log('    skipping rebalance: vault does not expose the oracle guard');
  } else if (s.markOracleDeviationBps > s.maxOracleDeviationBps) {
    console.log('    skipping rebalance: mark is dislocated from the index');
  } else if (now < nextAllowed) {
    console.log(`    skipping rebalance: cooldown for ${nextAllowed - now}s`);
  } else if (s.notional > 0n && drift < DRIFT_BAND_BPS && s.claimSharesEscrowed === 0n) {
    console.log(`    skipping rebalance: drift ${drift}bps inside the ${DRIFT_BAND_BPS}bps band`);
  } else {
    // The band suppresses fee churn, but never while exits are queued: a small
    // residue's drift sits inside any reasonable band forever, and the vault's
    // sub-minimum trim widening only helps if rebalance is actually called
    // (found in the P3 drill: 0.38 shares of tail, 163bps of drift, stalled).
    await send('rebalance', s.claimSharesEscrowed > 0n ? 'exits queued' : `drift ${drift}bps`);
  }
}

console.log(`keeper on ${VAULT}${DRY ? '  [dry run]' : ''}${account ? `  as ${account.address}` : '  [read only]'}`);

// Ticks are serialized: an event landing mid-tick queues exactly one follow-up
// rather than racing the nonce (the P3 drill's lesson, kept for events too).
let tickRunning = false;
let tickQueued = false;
async function safeTick(reason) {
  if (tickRunning) {
    tickQueued = true;
    return;
  }
  tickRunning = true;
  try {
    if (reason) console.log(`tick (${reason})`);
    await tick();
  } catch (e) {
    console.error('  tick failed:', e.shortMessage ?? e.message);
  }
  tickRunning = false;
  if (tickQueued) {
    tickQueued = false;
    await safeTick('queued during previous tick');
  }
}

await safeTick();
if (!ONCE) {
  // Event-driven: a deposit or a queued exit acts within seconds instead of
  // waiting out the poll. This shrinks the window in which the vault sits off
  // target after a deposit from INTERVAL_MS to bridge physics, which is the
  // whole point — the whale-window transfer scales with that gap. The second,
  // delayed tick covers the rebalance cooldown: if the immediate tick lands
  // inside it, the retry fires just after it expires.
  const react = (what) => (logs) => {
    console.log(`event: ${logs.length} ${what}`);
    safeTick(what);
    setTimeout(() => safeTick(`${what}, post-cooldown retry`), 35_000);
  };
  pub.watchContractEvent({
    address: VAULT, abi, eventName: 'Deposited',
    pollingInterval: 5_000, onLogs: react('deposit'), onError: () => {},
  });
  pub.watchContractEvent({
    address: VAULT, abi, eventName: 'RedemptionQueued',
    pollingInterval: 5_000, onLogs: react('queued exit'), onError: () => {},
  });
  // The poll stays as the heartbeat for everything events cannot see:
  // bridge credits landing, price drift, funding.
  setInterval(() => safeTick(), INTERVAL_MS);
}

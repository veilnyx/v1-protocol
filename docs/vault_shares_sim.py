#!/usr/bin/env python3
"""
Share accounting simulation for a shielded perp vault (e.g. "BTC 10x long").

Purpose: derive the exact numbers quoted in SHIELDED_PERP_VAULT_PLAN.md, and let
them be re-derived when parameters change. No dependencies. Run: python3 this.py

Model
-----
Vault state is (equity E, position size q in BTC, shares outstanding S).

  equity        E   = margin posted + unrealised PnL, marked at current price
  NAV per share     = E / S            (bootstrap NAV = 1.0 when S == 0)
  target size   q   = L * E / P        (L = target leverage)

  price move P -> P'      : E += q * (P' - P)
  deposit D at price P    : s = D / NAV ; E += D ; S += s ; then rebalance
  redeem s shares         : payout = s * NAV ; E -= payout ; S -= s ; rebalance
  rebalance               : trade (q_target - q), paying taker fee on the delta

Liquidation uses Hyperliquid's rule of maintenance margin at half the initial
requirement of the asset's max leverage: mm = notional / (2 * MAX_LEVERAGE).

Deliberately NOT modelled: funding payments, the few-second CoreWriter order
delay, partial fills, redemption slippage beyond the taker fee, and oracle/mark
divergence. Those are real and are listed as risks in the plan. This exists to
make the share accounting unambiguous, not to be a backtest.
"""

# Measured on a real chain-998 round trip: 0.013396 + 0.013390 paid on 29.77 of
# notional, i.e. ~9bp for the pair. The 4.5bp book rate is one side only.
TAKER_FEE = 0.00045  # 4.5 bps, Hyperliquid base taker, per side

# Funding accrues on NOTIONAL, not equity, so leverage multiplies it directly.
# Observed on chain 998: +0.0000125/hr on BTC, ETH and SOL = +10.95% APR, paid by
# longs. A 2x long therefore bleeds ~21.9% APR on equity before any price move.
FUNDING_RATE_HOURLY = 0.0000125
MAX_LEVERAGE = 10    # exchange cap on the asset; sets the maintenance requirement

# Cost of a liquidation as a fraction of notional, over and above the taker fee.
# ASSUMPTION, not a measured value: stands in for liquidator/backstop cost and
# fill slippage. An orderly book liquidation is cheaper; a gapping market that
# goes to backstop liquidation can take the entire remaining balance.
LIQUIDATION_COST = 0.01


class Vault:
    def __init__(self, target_leverage, price, rebalance_on_move=False):
        self.L = target_leverage
        self.P = price
        self.rebalance_on_move = rebalance_on_move
        self.E = 0.0   # equity, USDC
        self.q = 0.0   # position size, BTC (>0 long, <0 short)
        self.S = 0.0   # shares outstanding
        self.fees = 0.0
        self.funding_paid = 0.0
        self.log = []

    # -- views -------------------------------------------------------------
    @property
    def nav(self):
        return 1.0 if self.S == 0 else self.E / self.S

    @property
    def notional(self):
        return abs(self.q) * self.P

    @property
    def effective_leverage(self):
        return 0.0 if self.E <= 0 else self.notional / self.E

    @property
    def maintenance_margin(self):
        return self.notional / (2 * MAX_LEVERAGE)

    @property
    def liquidation_price(self):
        """Price at which equity falls to the maintenance requirement.

        Solve  E + q*(P' - P) = |q|*P' / (2*MAX_LEVERAGE)  for P'.
        """
        if self.q == 0:
            return float("nan")
        a = self.q - (abs(self.q) / (2 * MAX_LEVERAGE))
        if a == 0:
            return float("nan")
        return (self.q * self.P - self.E) / a

    def is_liquidated(self):
        return self.q != 0 and self.E <= self.maintenance_margin

    # -- mutations ---------------------------------------------------------
    def _rebalance(self):
        if self.E <= 0:
            return
        delta = (self.L * self.E / self.P) - self.q
        fee = abs(delta) * self.P * TAKER_FEE
        self.E -= fee
        self.fees += fee
        self.q = self.L * self.E / self.P  # re-solve after paying the fee

    def accrue_funding(self, hours):
        """Charge funding on notional. Longs pay a positive rate; shorts receive."""
        if self.q == 0:
            return 0.0
        cost = self.notional * FUNDING_RATE_HOURLY * hours * (1 if self.q > 0 else -1)
        self.E -= cost
        self.funding_paid += cost
        return cost

    def move(self, new_price, label):
        self.E += self.q * (new_price - self.P)
        self.P = new_price
        if self.rebalance_on_move and not self.is_liquidated():
            self._rebalance()
        self._record(label)

    def deposit(self, usd, who):
        nav = self.nav
        shares = usd / nav
        self.E += usd
        self.S += shares
        self._rebalance()
        self._record(f"{who} deposits {usd:,.0f}")
        return shares

    def redeem(self, shares, who):
        nav = self.nav
        payout = shares * nav
        self.E -= payout
        self.S -= shares
        if self.S > 0:
            self._rebalance()
        else:
            self.q = 0.0
        self._record(f"{who} redeems {shares:,.0f} sh")
        return payout

    def liquidate(self):
        """Close the position at the current mark, paying taker fee plus the
        liquidation cost. Equity is NOT wiped: what remains is the maintenance
        buffer less those costs, and it stays in the vault's Core account.
        Shares are untouched, so NAV simply reprices."""
        cost = self.notional * (TAKER_FEE + LIQUIDATION_COST)
        self.E = max(0.0, self.E - cost)
        self.fees += cost
        self.q = 0.0
        self._record("LIQUIDATED, position closed")

    def _record(self, label):
        self.log.append(dict(label=label, P=self.P, E=self.E, q=self.q, S=self.S,
                             nav=self.nav, lev=self.effective_leverage,
                             liq=self.liquidation_price))


def table(v, upto=None):
    hdr = (f"{'event':<30}{'BTC':>10}{'equity':>12}{'size':>9}"
           f"{'shares':>11}{'NAV':>9}{'lev':>7}{'liq px':>11}")
    print(hdr)
    print("-" * len(hdr))
    for r in v.log[:upto]:
        liq = f"{r['liq']:,.0f}" if r["liq"] == r["liq"] else "-"
        print(f"{r['label']:<30}{r['P']:>10,.0f}{r['E']:>12,.2f}{r['q']:>9.4f}"
              f"{r['S']:>11,.0f}{r['nav']:>9.4f}{r['lev']:>7.2f}{liq:>11}")


def holdings(v, book):
    print(f"\n{'holder':<10}{'shares':>11}{'paid in':>12}{'value now':>12}"
          f"{'P&L':>12}{'return':>9}")
    print("-" * 66)
    for who, (sh, paid) in book.items():
        val = sh * v.nav
        pnl = val - paid
        print(f"{who:<10}{sh:>11,.0f}{paid:>12,.2f}{val:>12,.2f}"
              f"{pnl:>+12,.2f}{pnl / paid:>8.2%}")


def rule(title):
    print("\n" + "=" * 97)
    print(title)
    print("=" * 97)


def main():
    rule("SCENARIO A — BTC 10x long, two depositors entering at different NAVs")
    v = Vault(target_leverage=10, price=100_000)
    book = {}
    a_sh = v.deposit(10_000, "Alice")
    book["Alice"] = (a_sh, 10_000)
    v.move(102_000, "BTC 100k -> 102k")
    b_sh = v.deposit(12_000, "Bob")
    book["Bob"] = (b_sh, 12_000)
    v.move(99_960, "BTC 102k -> 99.96k")
    table(v)
    holdings(v, book)
    print(f"\nBob paid NAV {v.log[1]['nav']:.4f}, which already contained Alice's gain,")
    print("so he bought no part of it. Each holder tracks NAV only from their own")
    print("deposit onward — that is the property the encrypted share note carries.")
    print("Both are down here because the vault is 10x and bought MORE at 102k.")

    rule("SCENARIO A' — counterfactual: what Bob's deposit cost Alice")
    w = Vault(target_leverage=10, price=100_000)
    w.deposit(10_000, "Alice")
    w.move(102_000, "BTC 100k -> 102k")
    w.move(99_960, "BTC 102k -> 99.96k")
    table(w)
    solo = a_sh * w.nav
    joint = a_sh * v.nav
    print(f"\nAlice alone      : {solo:>10,.2f}")
    print(f"Alice with Bob   : {joint:>10,.2f}")
    print(f"cost to Alice    : {joint - solo:>+10,.2f}  ({(joint - solo) / solo:+.2%})")
    print("\nBob's deposit forced a rebalance that bought 1.35 BTC at the local high,")
    print("and Alice owns ~50% of that purchase. Existing holders bear the entry cost")
    print("and entry price of new deposits. Morpho has no such effect because it is")
    print("unlevered and never rebalances. THIS NEEDS A MITIGATION — see the plan.")

    rule("SCENARIO B — redemption out of the Scenario A vault")
    payout = v.redeem(a_sh / 2, "Alice")
    table(v, upto=None)
    print(f"\nAlice redeemed half her shares for {payout:,.2f} USDC. The remaining")
    print("5,000 shares stay in her note and settle at whatever NAV applies later.")

    rule("SCENARIO C — liquidation of a 10x long")
    c = Vault(target_leverage=10, price=100_000)
    c.deposit(10_000, "Alice")
    opened_at, liq_at = c.P, c.liquidation_price
    for px in (98_000, 96_000, 95_000, 94_700, 94_000):
        c.move(px, f"BTC -> {px:,}")
        if c.is_liquidated():
            c.log[-1]["label"] += "  << LIQUIDATED"
            break
    table(c)
    print(f"\nOpened at {opened_at:,.0f}; liquidation price {liq_at:,.0f}, only "
          f"{1 - liq_at / opened_at:.2%} away.")
    print(f"Equity {c.E:,.2f} vs maintenance {c.maintenance_margin:,.2f}.")
    print("A 10x vault is ~5% from liquidation, not 10%, once maintenance margin")
    print("is counted. Note this is NOT a wipeout — see the next scenario.")

    rule("SCENARIO C' — after liquidation: residual value, and restarting the vault")
    pre_nav = c.nav
    c.liquidate()
    table(c)
    print(f"\nNAV was {pre_nav:.4f} at the trigger and {c.nav:.4f} after closing out.")
    print(f"Alice's 10,000 shares are worth {10_000 * c.nav:,.2f} of her original")
    print(f"10,000 — a {10_000 * c.nav / 10_000 - 1:.2%} loss, NOT a total loss.")
    print("The maintenance requirement is what survives. Notes stay valid and")
    print("redeemable; the vault contract and its Core account are both still alive.")

    print("\n-- Carol deposits into the SAME vault after the liquidation --\n")
    carol_sh = c.deposit(5_000, "Carol")
    table(c, upto=None)
    print(f"\nCarol paid NAV {c.log[-2]['nav']:.4f} and received {carol_sh:,.0f} shares")
    print(f"for 5,000 USDC, against Alice's {10_000:,.0f} shares now worth "
          f"{10_000 * c.nav:,.2f}.")
    print("Carol is not buying Alice's loss and Alice is not rescued by Carol's")
    print("arrival: both simply hold shares priced at the same post-liquidation NAV.")
    print("Restarting the same vault is therefore ARITHMETICALLY FAIR. Whether it")
    print("should restart automatically is a separate question — see the plan.")

    rule("SCENARIO D2 — funding alone, price perfectly flat, no rebalancing")
    print("Longs pay +10.95% APR on NOTIONAL, so leverage multiplies it.\n")
    print(f"  {'target':>8}{'30 days':>12}{'90 days':>12}{'365 days':>12}")
    print("  " + "-" * 44)
    for L in (2, 5, 10):
        row = [f"  {L:>7}x"]
        for days in (30, 90, 365):
            v = Vault(target_leverage=L, price=100_000)
            v.deposit(10_000, "Alice")
            v.accrue_funding(days * 24)
            row.append(f"{v.E / 10_000 - 1:>11.2%}")
        print("".join(row))
    print("\nNothing moved. This is the cost of simply holding the position, and it")
    print("is far larger than the rebalancing decay measured below.")

    rule("SCENARIO D — volatility decay with periodic rebalancing, price ends FLAT")
    print("20 moves, +2% then -1.96% repeated, returning to exactly 100,000.\n")
    print(f"  {'target':>8}{'final equity':>15}{'return':>10}{'fees':>10}{'funding':>11}")
    print("  " + "-" * 54)
    for L in (2, 5, 10):
        d = Vault(target_leverage=L, price=100_000, rebalance_on_move=True)
        d.deposit(10_000, "Alice")
        for _ in range(10):
            d.move(d.P * 1.02, "up")
            d.accrue_funding(12)  # a 20-move path spanning ~10 days
            d.move(d.P / 1.02, "down")
            d.accrue_funding(12)
        print(
            f"  {L:>7}x{d.E:>15,.2f}{d.E / 10_000 - 1:>9.2%}"
            f"{d.fees:>10,.2f}{d.funding_paid:>11,.2f}"
        )
    print("\nPrice is unchanged and every vault has lost money. This is intrinsic to")
    print("a rebalanced leveraged product — not a bug, not fixable by execution.")
    print("It must be disclosed to depositors in plain language.")


if __name__ == "__main__":
    main()

# TradePro EA v3.2 — Independent Market-Expert / Quant Audit

**Auditor stance:** first-time reviewer, no stake in the product. Every number below is either
taken from the project's own files or recomputed by me (Section 0). Where the project's own
reports are honest, I say so. Where the evidence does not carry the claims, I say that too.

**Overall grade as a sellable product: 42 / 100.**
The engineering shell (risk guards, per-account compiled licensing, reproducible test scripts,
unusually honest internal reports) is well above the retail-EA norm. The statistical evidence
that any of the three profiles has a real, durable edge is **not** above the bar — after
correcting for basket selection bias, no profile's out-of-sample expectancy is statistically
distinguishable from zero, and the cost model does not represent the product buyers will
actually trade (Exness MT5 CFDs). Selling it today at $99 is defensible only as
"a disciplined, transparent, backtested-in-one-window robot" — not with the performance
framing currently used in the buyer guide and EA comments.

---

## 0. My own verification computations (reproduced, not quoted)

I ran two independent computations (script: `/tmp/audit_calc.py`, run 2026-11-05):

**Computation A — selection-bias counterfactual** (from `backtest_all_results.json` trade lists,
split by trade date ≈ bar 1000):

| Selection method | Later-segment result |
|---|---|
| Published basket-7 (BTC, ADA, SOL, XRP, EUR/USD, AAPL, TSLA) — selected using the **full** window | 88 trades, **+7.9R**, mean +0.090R/trade, **t = 0.59** |
| Honest counterfactual: top-7 selected on the **early segment only** (EUR/USD, AAPL, BTC, SOL, TSLA, ETH, BNB — ADA and XRP drop out) | 95 trades, **−8.5R**, mean −0.089R/trade, t = −0.63 |
| All 20 markets, later segment | 206 trades, +0.8R, mean +0.004R, t = 0.04 |

**Selection-bias gap ≈ +0.18R/trade — larger than the basket's entire later-segment mean
(+0.09R/trade).** In plain terms: the procedure that produced the basket accounts for at least
as much "edge" as the basket itself shows out-of-sample.

**Computation B — fresh-data reproduction** (fresh 1500 H1 candles fetched from OKX/Binance
today, same code path, durations recorded, split at bar 1000). The pipeline reproduces the
published figures closely (Classic OOS +12.8R vs published +10.0R; Sniper pooled WR 89.1% vs
published ~89%) — the backtests are not fabricated and are internally consistent. But with
proper significance testing:

| Profile | IS | OOS | Pooled t-stat | Verdict |
|---|---|---|---|---|
| Classic V2 (SL 1.5 / TP 2.0) | n=140, +25.9R, t=1.48 | n=87, +12.8R, **t=0.94** | t=1.75 | Closest to real; still not significant OOS |
| Fair V2 (SL 2.0 / TP 0.5) | n=190, +7.5R, t=0.78 | n=139, +2.0R, **t=0.25** | t=0.76 | Indistinguishable from zero |
| Sniper DIP (SL 2.0 / TP 0.2) | n=45, +2.3R, t=0.93 | n=19, +1.1R, **t=0.68** | t=1.15 | Indistinguishable from zero |

No profile, in any segment, reaches t ≥ 2. That is the single most important fact in this audit.

---

## 1. Strategy soundness — mechanism or curve-fitting?

### 1.1 V2 trend signal (Classic / Fair engine)
**Mechanism: real.** EMA50/200 trend regime + EMA9/21 trigger + MACD confirmation + RSI band +
trend-strength gate is textbook trend-following/momentum. Momentum is one of the few effects
with cross-market academic support. The payoff check supports a small real tilt in this window:
a driftless random walk with SL 1.5×ATR / TP 3.0×ATR wins 33.3% of the time; the Classic
profile won 39.6% — about +6 points above geometry.

**Parameterization: fitted.** Five stacked conditions with hand-set, asymmetric bands
(buy RSI 40–68 vs sell 32–60; continuation 50–65 vs 35–50; strength thresholds 0.08 and 0.35)
is a large hand-tuned surface for one 62-day window. Evidence of fragility: the identical logic
on all 20 markets loses −35.3R (597 trades, the project's own number); on 4H it loses −29R;
the "expert" add-ons (H4 confirmation, ATR regime, break-even) each failed or were neutral.
A mechanism this parameter-sensitive, validated in exactly one market regime (a trending
crypto autumn, Sep–Nov 2026), is best described as *a plausible mechanism wearing a
curve-fitted suit*.

### 1.2 Fair profile (SL 2.0×ATR / TP 0.5R)
**No new mechanism — it is payoff geometry, not edge.** TP distance = 1.0×ATR, SL = 2.0×ATR.
A random walk hits the near barrier first with probability 2/(2+1) = **66.7%**; the profile
"achieves" 69–70%. The ~70% win rate is arithmetic, marketed as performance. Expectancy is
+0.03–0.04R/trade (t = 0.76 pooled, 0.25 OOS) — zero for practical purposes. The project's own
Fair report concedes the margin is thin; what it does not say is that the win rate itself
contains no information about skill: *any* signal, including a coin flip, wins ~67% with this
exit geometry. As a default profile for paying buyers this is the weakest choice of the three:
it maximises the *feeling* of winning while its expectancy is the most fragile (Section 3).

### 1.3 Sniper (RSI-dip inside EMA200 trend, SL 2.0 / TP 0.2R)
**Mechanism: plausible, small.** Buying an RSI washout that stabilises inside an uptrend
(pullback mean-reversion) is a legitimate, known short-horizon effect. But quantify the
geometry first: TP = 0.4×ATR vs SL = 2.0×ATR ⇒ random-walk win probability = 2.0/2.4 =
**83.3%**. Observed pooled win rate = 89.1% (57/64 in the all-markets replay; 89% in my fresh
run). Wilson 95% CI for 57/64 ≈ **[79%, 95%] — the interval contains the zero-edge geometry
baseline of 83.3%.** So even pooling every sniper trade ever simulated, we cannot reject
"the sniper is payoff geometry plus noise." The residual tilt (~+6 points of WR, +0.05R/trade)
may be real — the sample is simply far too small to know (Section 4).

**Selection caveat specific to the sniper:** it was found by a 45-configuration search
(`backtest_80.py`) whose explicit objective was "WR ≥ 80% and positive both halves." Four
configurations "qualified" — but all four are the same DIP family at SL 2.0–3.0 / TP 0.2–0.3
running on essentially the same ~63 trades. That is one hypothesis passing once, not four
independent confirmations.

---

## 2. Basket selection bias — how much of the edge is the selection?

This is the audit's central quantitative finding (Computation A):

- The 7-market basket was chosen from **full-window** results (`backtest_all.py`, 1500 bars),
  and then "validated" with an IS/OOS split of **the same window** (`backtest_expert.py`).
  The OOS half is therefore not out-of-sample with respect to the selection — the selectors
  had already seen it. The expert report's headline (+27.8R IS / +10.0R OOS) is contaminated
  by construction.
- Counterfactual: had the basket been chosen honestly — top-7 on the early segment only —
  the chosen set differs (ETH and BNB in; ADA and XRP out) and its later-segment result is
  **−8.5R**, not +7.9R.
- Even taking the published basket at face value, its later-segment mean (+0.090R/trade,
  n=88) has t = 0.59 — noise. And within the same later segment, **all 20 markets pooled
  average +0.004R/trade (t = 0.04)**: outside the selection, the V2 engine earned exactly
  nothing in the "OOS" period.
- Decay is visible even in the flattering split: basket early segment +28.8R → later +7.9R.
- Per-market OOS (expert results) shows the basket is not uniformly real either: of the 7,
  only ADA (+7.7R, n=10) and TSLA (+3.9R, n=11) were meaningfully positive OOS; BTC −0.0,
  SOL −1.1, AAPL −1.1, EUR/USD −1.5. Two small-n markets carry the whole OOS claim.
- The all-markets sniper replay makes the same point independently: basket +3.4R (57/64,
  89.1%) vs non-basket **−10.9R** (120/152, 78.9%). The sniper "works" exactly where it was
  selected to work.

**Quantified answer: at least ~100% of the basket's measured out-of-sample edge is
attributable to selection** (bias gap +0.18R/trade vs measured edge +0.09R/trade). There may be
a real residual edge underneath — the Classic profile's pooled t = 1.75 hints at one — but on
current evidence it is unproven and its honest point estimate after selection correction is
≈ 0 to +0.05R/trade, not the +0.16R/trade implied by the +37.8R headline.

A compounding factor: total hypothesis search over this single 62-day window is large —
sweep_v3 (24 configs), metals rescue (30 configs), expert modes (3), fair grid (20, of which
**10 passed** the project's own "positive in both halves" gate — passing was a coin flip,
not a filter), 80-test (45). Well over 100 configurations were mined from the same ~52 signal
days. Under that search intensity, both-halves-positive winners are expected by chance.

---

## 3. Cost realism — what the backtests do not charge

The backtests charge **one spread snapshot per instrument** (measured live from OKX at test
time) minus nothing else. Four gaps, in order of danger:

1. **The tested instruments are not the sold product.** Tests run on OKX perpetual swaps
   (24/7, tight spreads) and Binance spot EURUSDT. Buyers will run Exness MT5 CFDs: wider and
   strongly time-varying spreads (rollover hour, overnight stock-CFD spread blowouts, news),
   session gaps for stocks/indices, dividend adjustments, and broker commissions on many
   account types (raw-spread accounts: ~$3.5/lot/side on FX, plus stock-CFD commissions).
   The backtest's spread for AAPL/TSLA is an OKX perp spread — a fraction of what an Exness
   stock CFD charges outside US hours, which is precisely when a 24/7 H1 EA will take many
   of its signals.
2. **Slippage.** Entries are modelled at next-bar open with zero slippage; exits assume the
   bar's high/low touched SL/TP at the exact level. H1 entries at bar open on MT5 CFDs
   typically slip a few percent of ATR in fast opens; SL exits in gaps slip more.
3. **Swap / funding.** From my reproduction, holding times: Classic median 7h, mean 13.5h,
   26/227 trades > 24h, max 132h (5.5 days); Fair median 4h, 21/329 > 24h; Sniper median 2h,
   only 1/64 trades > 24h. So overnight financing is **minor for the Sniper, modest for
   Classic/Fair** — a 0.02R/night proxy costs Classic ≈ 1.0R total. (On the tested perps the
   analog is funding, also unmodelled, but the live product is CFDs, where long stock/index
   positions pay swap daily.) This is *not* the main cost problem; items 1–2 are.
4. **Stress test** (my Computation B, extra cost per trade on top of the modelled spread):

| Profile | Base (pooled, fresh) | +0.05R/trade | +0.10R/trade | +0.05R + swap proxy |
|---|---|---|---|---|
| Classic | +38.7R (n=227) | +27.3R | +16.0R | +26.3R |
| Fair | +9.5R (n=329) | **−6.9R** | **−23.4R** | **−7.6R** |
| Sniper | +3.5R (n=64) | +0.3R | **−2.9R** | +0.2R |

An extra 0.05R/trade is not pessimistic for the CFD reality gap (it is roughly one extra
modest spread-crossing on a 1.5–2.0×ATR stop). **Under it, the default Fair profile and the
flagship Sniper claim both go to ≈ zero or negative.** Only the Classic profile retains a
cushion — and its statistical significance was already sub-threshold (t = 0.94 OOS).

Also note: the backtest applies one *constant* spread to all 62 days, so it cannot see the
hours when spreads were 5–10× normal — exactly the hours a fixed-rule EA still trades.

---

## 4. Statistical confidence — what would actually settle each claim

Sample sizes behind the marketed numbers:

| Claim | Evidence base | Problem |
|---|---|---|
| Classic "+37.8R" | 230 trades, one 62-day window, basket selected on same window | OOS t = 0.94; selection-contaminated |
| Fair "~70% WR, +12.1R" | 335 trades, same window | Pooled t = 0.76; WR is geometry, not evidence |
| Sniper "88–90% WR" | **63 trades total; OOS n = 19–20** | Wilson CI for OOS 18/20 = [70%, 97%]; P(≥18/20 wins \| true WR = breakeven 85.8%) = **0.44** — the headline result is a coin-flip-level event under the null |

What forward evidence would settle each claim (at the observed effect sizes and variances):

- **Classic:** ~310+ live/demo trades to confirm mean ≈ +0.15R (sd ≈ 1.35) at 95% confidence —
  roughly 10 weeks on 7 charts. Feasible. This is the only claim worth spending demo time on
  first.
- **Fair:** confirming +0.03–0.04R (sd ≈ 0.85) needs **~2,300 trades** — practically
  unprovable. The honest product statement for Fair is "≈70% win rate by construction,
  expectancy ≈ 0, costs decide the sign." It should not be the default profile sold on
  performance.
- **Sniper:** distinguishing WR 89% from the 83.3% geometry baseline needs **~150–200
  trades**; confirming +0.05R/trade expectancy needs ~270. At ~1.2 trades/day that is
  4–7 months of forward testing. The currently running forward test (Section 5.4) had
  **0 closed trades** at audit time — today there is no forward evidence at all.
- For all profiles: forward evidence only counts if it is generated **by the actual EA on an
  actual MT5 demo (Exness)**, because the dominant uncertainty is the OKX/Binance→CFD
  transfer (spreads, sessions, gaps), not the signal arithmetic.

Until then, every performance number attached to this product should be read as
"one 62-day, in-sample-selected simulation," because that is what it is.

---

## 5. Code-level risks in the EA (live ≠ backtest)

Read of `ea/TradeProEA.mq5` v3.2 against the Python simulators:

1. **No timeframe guard — the most dangerous product defect.** Every backtest is H1-only and
   4H is a proven loser (−29R), yet the EA trades on whatever chart it is attached to
   (any `PERIOD_CURRENT`). The owner's own history includes attaching robots to an M30 chart.
   A buyer who attaches to M15/H4 gets an untested, likely losing system with no warning.
   One line (`if(Period() != PERIOD_H1) return INIT_FAILED`) is the fix; its absence in a
   $99 product is hard to defend.
2. **Mid-bar entries via the 30-second timer.** `OnTimer()` calls `Evaluate()` continuously.
   Signals are computed from closed bars (fixed), but entries fire whenever a *transient*
   block clears mid-bar — spread normalising after the open, or an open position closing
   mid-bar (`HasOpenTrade` releasing). The backtest only ever enters at next-bar open.
   Live entries will systematically be later and at worse prices than tested entries, an
   unmeasured drag that hits the thin-margin profiles (Fair, Sniper) hardest.
3. **Guard semantics differ from the backtests.** The simulators apply 3 trades/day and
   −3R/day **per instrument**. The EA: `TradesToday()` is per-symbol (matches), but
   `DailyPL()` sums closed deals across **all symbols** with the magic while floating P&L
   counts only the current symbol. Consequences: (a) live guard behaviour ≠ tested guard
   behaviour; (b) there is **no portfolio-level floating stop** — seven charts risking 1%
   each, four of them highly correlated crypto (BTC/ADA/SOL/XRP), can stack ≈ −4–7% of
   floating loss before any chart's closed-deal stop engages. The backtests' calm
   "worst day ≈ −3R" does not describe the live portfolio.
4. **Silent over-risking in `CalcLot()`.** If the computed lot is below the broker minimum,
   the function returns the minimum lot — risking a multiple of `InpRiskPercent` without any
   warning. Worst exactly where buyers are weakest: small accounts and wide-stop symbols
   (BTC with a 2×ATR stop). There is also no free-margin check before ordering.
5. **Sniper default trap.** The advertised sniper numbers require TP = 0.2R, but the EA ships
   with `InpTP_R = 0.5` (Fair default). A buyer who flips `InpSignalMode = 1` and changes
   nothing else silently gets DIP SL2.0/TP0.5 — the configuration whose OOS win rate in the
   fair grid was 70%, not 88–90%. Marketing and defaults disagree.
6. **Basket check by substring** (`StringFind(_Symbol, "BTC")` etc.) — works for common
   Exness suffixes, but substring matching can false-positive on unrelated symbols
   containing e.g. "SOL"/"ADA", and silently excludes legitimate variants. For a protection
   feature, exact base-symbol parsing would be expected.
7. **Test-mode trade ignores the guards.** `MaybeTestTrade()` opens a position without
   checking `HasOpenTrade`, the daily counters, or the basket, and its deal carries the
   magic — it consumes one of the 3 daily slots and pollutes `DailyPL`. Minor, but it is a
   guard bypass in a product whose selling point is its guards.
8. **`Buf()` returns 0 on `CopyBuffer` failure.** Zeroed MACD/RSI values mostly block
   entries (safe direction), but zeroed EMA50/EMA200 comparisons can produce false trend
   states transiently after attachment, before 200+ bars of indicator history are ready on
   the terminal (which also differs from the Python full-sample seeding — early live signals
   will not match the backtest's).
9. **Fixed 20-point deviation** for all symbols — trivially small for gold/crypto (requotes,
   failed fills in fast markets, no retry), arbitrary for others.
10. **No news/rollover protection.** The only spread defence is an instantaneous check at
    the entry tick; nothing stops entries seconds before scheduled news or the daily
    rollover spread blowout — the exact moments where the cost model (Section 3) breaks.

### 5.4 The forward test that exists (`forward_test.py`)
Good instinct, three caveats: (a) at audit time it has run ~1.5 hours with **0 closed
trades** — it is a plan, not evidence; (b) it tests the sniper on **all 20 markets**, while
the product is sold as basket-only — its results will conflate the two questions; (c) its
exit checker skips the entry candle entirely, so intra-entry-candle TP/SL touches are
missed — a small systematic distortion given the sniper's median trade life is 2 hours.
It also runs on OKX/Binance prices, so even when complete it will not answer the CFD
transfer question (Section 4).

---

## 6. Claims the evidence does NOT support

1. **EA source header: "ذهب +6R" (gold +6R).** From an early 30-trade PAXG probe. The full
   test shows gold at **−8.3R over 38 trades** (all-markets report) and −1.3R in the sniper
   replay; gold is not even in the basket. This line sits in the master source of the
   product being sold. **Unsupported and contradicted — remove it.**
2. **Sniper "expect ~88 winners per 100 trades and +5R"** (buyer guide / BACKTEST-80
   framing). Based on 63 fitted-window trades; t = 1.15; the win-rate CI contains the
   zero-edge geometry baseline (83.3%); the same sniper across all markets *loses* money
   (−7.5R / 216 trades). Supportable version: "in one 62-day basket backtest the sniper won
   89% of 64 trades with a thin positive net that is not statistically significant."
   The current version is **not supported**.
3. **Classic "+37.8R" / Fair "+12.1R" as the robot's measured performance** (site and guide),
   presented without the selection caveat. My counterfactual (Computation A) shows an
   honestly-selected basket loses money in the same later segment (−8.5R). The numbers are
   real arithmetic on a selected set; as performance claims they are **materially
   overstated**.
4. **"~4.9 winning trades per day" (Fair)** — arithmetic from the fitted window at 7 parallel
   charts; it is a backtest rate from a selected basket in one regime, presented in the
   guide as an expectation. Borderline: arithmetically consistent, evidentially unsupported
   as a forward expectation.
5. **Implied claim that the IS/OOS splits validate the profiles.** Given basket selection on
   the full window and >100 configurations mined from the same 62 days, the splits do not
   have their usual meaning. The internal reports disclose more of this than most retail
   products do — credit for that — but the site/guide summaries strip the caveats out.

**Claims that ARE supported:** the all-markets total is negative (−35.3R, disclosed);
4H loses (disclosed); no-guaranteed-profit disclaimers exist on the site; the robot's guards
exist in code as described; the backtest scripts genuinely reproduce the published numbers
(I verified this independently).

---

## 7. Improvement experiments toward 90%

**Program target as defined by the owner:** win rate ≥ 90% **with** positive net expectancy,
proven out-of-sample **and** confirmed by live forward testing. Read this first: at TP 0.2R
geometry, WR 90% with positive expectancy requires a *genuine* barrier-tilt — the random-walk
baseline is 83.3%, and costs push the breakeven WR to ≈ 85.8%. Every experiment below must
therefore be judged on **OOS mean R first, win rate second** — a filter that raises WR by
shrinking the effective target or widening the stop is arithmetic, not progress, and will be
treated as failure. Also read the standing warning: **the Sep–Nov 2026 window is statistically
exhausted.** It has already absorbed 100+ configuration searches. Any experiment "validated"
only on this window is re-mining spent ore. Each experiment below therefore specifies its
evidence source: (W1) the existing window for *screening only*, (W2) a **different** historical
window (e.g. a 62-day block from a different regime — a ranging/bear period), and (F) the live
forward run. Promotion requires W2 + F, never W1 alone.

**Universal test protocol (applies to every experiment):** pre-register the single change and
its parameter(s) *before* running; one change at a time against the frozen sniper baseline
(DIP, SL 2.0, TP 0.2, basket-7); acceptance = OOS mean R improves **and** OOS WR ≥ baseline
**and** trade count ≥ 60% of baseline **and** the improvement survives the +0.05R/trade cost
stress; then walk-forward (3 sequential folds) on W2; then ≥ 100 forward trades on an Exness
demo running the actual EA before any claim changes. Any experiment needing per-market fitted
parameters is rejected by design (see #8).

### Ranked by expected value

**#1 — Spread-relative entry floor (cost-geometry filter)**
- *Change:* skip any entry where TP distance < 6× the *current live* spread (equivalently,
  spread > ~3% of the 2×ATR stop… express as: spread/risk > 0.06 ⇒ skip; tune the constant
  once, on W1, from {0.04, 0.06, 0.08}).
- *Hypothesis:* the sniper's losses are disproportionately trades whose tiny 0.4×ATR target
  was comparable to transaction costs — the trade was lost before the signal mattered.
  Removing cost-dominated trades raises both WR and expectancy without touching the signal.
- *Why it can raise WR without killing expectancy:* it deletes negative-expectancy trades
  (cost > edge) rather than reshaping payoffs; the trades that remain are the ones where the
  dip-bounce tilt exceeds friction.
- *Test:* W1 screen (expect: fewer trades, higher mean R, WR +1–3 pts), then W2 + F.
  On the live EA this uses the real Exness spread at entry — the variable the backtests
  modelled worst, so the forward leg is the decisive one.
- *Overfit risk:* low (one threshold, mechanism is accounting, not pattern-mining).

**#2 — Session / liquidity-hours filter**
- *Change:* entries only 07:00–21:00 UTC; hard exclusion of the 21:00–22:00 UTC rollover
  hour and Sunday-open hours.
- *Hypothesis:* RSI crosses in thin hours are noise (wider spreads, stop-hunting wicks on
  CFDs), and dips in liquid hours resolve by genuine order flow. The backtest — run on 24/7
  perp prices — is blind to this; on the CFD product this filter should remove a
  disproportionate share of the left tail.
- *Why WR can rise honestly:* removes execution-environment losses, not signal losses.
- *Test:* W1 screen by hour-bucket attribution of existing losses (diagnostic only — do
  **not** fit the window edges to W1's worst hours; use the pre-registered institutional
  hours above), confirm on W2, decisive test on F (Exness demo spreads make the effect
  visible only there).
- *Overfit risk:* low if hours are pre-registered as above; **high** if anyone "optimises"
  the window per market — forbidden.

**#3 — Volatility-regime gate**
- *Change:* take DIP entries only when ATR(14) is between the 20th and 80th percentile of
  its trailing 200 bars, **and** EMA200 has a minimum slope (|EMA200[i] − EMA200[i−24]| >
  0.25×ATR) — i.e. a real trend in normal volatility.
- *Hypothesis:* dip-buying fails in two regimes the current rule cannot see: dead ranges
  rolling over (EMA200 flat — the "trend" is imaginary, dips keep dipping) and vol shocks
  (ATR extreme — a 2×ATR stop is inside the noise of a regime break). Both produce the
  full −1R losses that cap the win rate.
- *Why WR can rise honestly:* it targets the loss side (regime-break dips) rather than
  touching TP/SL geometry; fewer, cleaner pullbacks in intact trends.
- *Test:* W1 screen + loss attribution (were gated-out trades actually losers?), W2
  walk-forward, F confirmation. Acceptance per universal protocol.
- *Overfit risk:* moderate — two thresholds, both mechanism-motivated and standard in the
  literature; keep them at round values (20/80, 0.25) and do not grid-search them finely.

**#4 — Confirmation-bar entry for the DIP**
- *Change:* after the RSI cross-back, enter only if the *next* closed bar confirms
  (long: bar closes above the cross bar's close and makes no new low; short mirrored).
  Entry one bar later than baseline.
- *Hypothesis:* a material share of sniper losses are "dead-cat" crosses — RSI ticks back
  over 35 inside a continuing leg down. One bar of price confirmation separates stabilising
  dips from falling knives.
- *Why WR can rise honestly:* improves entry quality (signal-side), at the cost of a
  slightly worse entry price on winners — net effect is an empirical question, which is
  exactly why it ranks below the cost/regime filters.
- *Test:* W1 + W2 with entry-price slippage honestly modelled (enter at confirmation bar's
  next open, as in the existing sims).
- *Overfit risk:* low-moderate (binary rule, no fitted constants).

**#5 — Walk-forward basket re-selection protocol (fix the foundation)**
- *Change:* replace the frozen, full-window-selected basket with a mechanical rule:
  every month, select the basket from the **trailing 60 days only** (same V2/DIP test),
  freeze it for the next month, never peek forward.
- *Hypothesis:* part of the basket's apparent edge is regime persistence (markets that
  trended keep trending for a while). A trailing-selection rule harvests whatever of that
  is real and discards the selection-on-the-future component — measured honestly this time.
- *Why it matters for the 90% target:* every other experiment is evaluated on the basket;
  if the basket itself is an artefact, all downstream "improvements" are fiction. This
  experiment raises *true* expectancy rather than headline WR.
- *Test:* simulate the protocol historically over W1 + W2 (selection windows strictly
  trailing), then run it live in F. Acceptance: protocol-basket OOS mean R > 0 across folds.
- *Overfit risk:* low (the rule has no fitted parameters beyond the window length; fix at
  60 days and do not tune it).

**#6 — Dip-depth requirement**
- *Change:* require the dip to have been *deep* before the cross-back: RSI minimum over the
  dip < 30 (not just < 35), or price ≥ 0.5×ATR beyond EMA50 against the position at the
  extreme — pick ONE formulation, pre-registered.
- *Hypothesis:* shallow RSI dips are trend noise; deep washouts inside an intact trend are
  where mean-reversion energy concentrates. Deeper entries also sit further from the stop
  geometry's noise band.
- *Test:* W1 screen, W2 + F per protocol. Expect materially fewer trades (~40–60% of
  baseline) — check the ≥60% count clause honestly; if the count collapses, the experiment
  fails the protocol even if WR rises, because forward confirmation would take a year.
- *Overfit risk:* moderate — the 30 threshold is a round, literature-standard value; do not
  scan 28/29/31/32.

**#7 — H4 trend agreement for the DIP (low prior — included for completeness)**
- *Change:* require the H4 EMA50/200 regime to agree with the H1 dip direction.
- *Hypothesis:* dips against the higher-timeframe regime are regime changes, not pullbacks.
- *Why it ranks low:* the direct analog was already tested on V2 (`backtest_expert.py`):
  H4 confirmation destroyed in-sample profit (+27.8R → +0.2R) while helping OOS slightly —
  i.e., it mostly deletes trades. Priors say it will do the same here.
- *Test:* only if #3 (which captures much of the same regime information more cheaply)
  shows promise; same protocol.
- *Overfit risk:* moderate; main risk is trade-count collapse masquerading as quality.

**#8 — Per-market parameter splits — ⚠️ DO NOT RUN as designed by intuition**
- *Temptation:* fit SL/TP/RSI thresholds per market (e.g. TP 0.25 for BTC, 0.18 for AAPL…)
  until each market shows 90%.
- *Why this is overfitting, explicitly:* each basket market contributes **6–16 sniper trades**
  in the entire evidence base. Fitting 2–3 parameters per market to ~10 trades guarantees
  in-sample 90%+ and out-of-sample disappointment; it is the single most reliable way to
  manufacture the target number while destroying the product. The same applies to
  per-market hour filters and per-market RSI thresholds.
- *Permitted variant:* **class-level** splits only (crypto / FX / US stocks as three
  classes), parameters shared within a class, accepted only if the improvement is
  significant on pooled class data in W2 and confirmed in F. Anything finer is curve-fitting
  by definition at these sample sizes.

### What reaching the target honestly looks like
A realistic path: #1 + #2 + #3 stack (all are loss-side/cost-side filters with independent
mechanisms) plausibly buys +2–4 points of WR and +0.02–0.05R/trade of expectancy **if** the
underlying dip tilt is real — landing near 90–92% WR in forward trading with a thin but
positive mean. If the tilt is not real (a live possibility: pooled t = 1.15), no filter stack
will get there, and the correct deliverable to the owner is that finding, with the Classic
profile (the only one with cost cushion) repositioned as the product and the sniper retired
to a research track. The three gates — OOS on a *fresh* window, then ≥ 100–270 forward
trades on a real Exness demo through the actual EA — are not bureaucracy; they are the only
thing separating a 90% product from a 90% story.

---

## Bottom line for the owner

- **Strongest assets:** (1) reproducible, honest test infrastructure — I re-ran it and the
  numbers check out; most retail EA vendors have nothing like it. (2) Real risk guards and
  anti-copy licensing in the code. (3) The Classic trend profile shows the only signal in
  the building that survives a cost stress test (+16.0R at +0.10R/trade) and has a plausible
  mechanism.
- **Most dangerous weaknesses:** (1) the basket — and therefore every headline number — is
  selection-contaminated; corrected, the OOS edge is ≈ 0 (Section 2). (2) The default Fair
  profile and the Sniper both have expectancy statistically indistinguishable from zero and
  die under realistic CFD costs (Section 3). (3) The product has **zero** forward/live
  evidence and a code defect (no timeframe guard) that can silently put buyers on an
  untested, proven-losing configuration.
- **Do not ship the current guide/site numbers as performance claims.** Ship the robot as a
  transparent, disciplined tool with backtests *labelled as single-window and
  selection-affected*, run the Classic profile on an Exness demo for ~10 weeks, and let the
  forward record — not the 62 fitted days — write the next version of the sales page.

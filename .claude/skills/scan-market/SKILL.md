---
name: scan-market
description: Scans the market for high-probability swing trade candidates, runs forensic sentiment and bear checks, and outputs the top 3 actionable trade plans.
context: fork
allowed-tools:
  - Bash
  - Read
  - Write
  - Agent
  - mcp__stock-scanner__*
---

When invoked with "scan the market" or `/scan-market`:

1. **Step 1: Check Memory Playbook**
   - Read `memory/playbook.md`. Note all patterns under "Confirmed Negative Edge" to disqualify invalid setups automatically.

2. **Step 2: Top-Down Macro Check (run BEFORE scanning any individual name)**
   - **Regime filter**: pull SPY and QQQ close, 20-day EMA, and 20-day EMA slope (today vs 5 days ago) via `stock-scanner` (`tradingview_technicals` / `tradingview_quote`).
     - Both SPY and QQQ close > 20-day EMA -> **REGIME: AGGRESSIVE LONG**. Scan long setups.
     - Either one at or below its 20-day EMA -> **REGIME: DEFENSIVE**. Only allow SHORT setups (mirror the Step 3 filters: price < 50 EMA, 20 EMA < 50 EMA, RSI 32-55) or high-dividend defensive names (yield >= 3%, e.g. staples, utilities, healthcare). No long breakouts.
     - Flag a warning if the 20-day EMA is declining (below its value 5 days ago) even when price is above it.
   - **Sector relative strength**: for XLK, XLE, XLV, XLI, SMH compute the 10-trading-day return minus SPY's 10-trading-day return. Rank descending.
     - **Leading sectors = top 2 by relative strength.** In DEFENSIVE regime, the rank is for context only; defensive names are chosen by yield and low beta.
     - Map each candidate to a sector ETF via its scanner sector/industry (semiconductors -> SMH, other tech -> XLK, energy -> XLE, health care -> XLV, industrials -> XLI). Candidates outside the five ETFs' coverage cannot be one of the final 3 in AGGRESSIVE regime.
   - Print a one-line header before continuing:
     `REGIME: <AGGRESSIVE LONG|DEFENSIVE> | SPY <close> vs EMA20 <x> | QQQ <close> vs EMA20 <x> | Leaders: <ETF1> (+x.x%), <ETF2> (+x.x%)`
   - If SPY/QQQ or sector data cannot be retrieved, state that it is unavailable and stop. Do not guess the regime.

3. **Step 3: Universe & Quantitative Screen**
   - Query the market via `stock-scanner` (or run `python scripts/filters.py`) across liquid US equities (Average Daily Volume > $20M), restricted to the leading sectors from Step 2 (or the defensive/short universe in a DEFENSIVE regime).
   - Filter for momentum, trend, or pullback setups:
     - Price > 50-day EMA and 20-day EMA > 50-day EMA.
     - RSI between 45 and 68 (avoiding exhaustion above 70).
     - Volume expansion on up-days (>1.3x 20-day volume average).
   - Take the top 6 candidates from this filter into Step 4. Do the screen yourself in this thread; only per-ticker analysis is delegated.

4. **Step 4: Parallel Per-Ticker Analysis (Subagents)**
   - Spawn one `ticker-analyst` subagent per candidate (6 total). **Issue all Agent calls in a single message so they run concurrently.** Never analyze candidates sequentially in this thread.
   - Prompt each with only: `TICKER`, `BIAS`, `REGIME`, `SECTOR ETF`. The worker runs technicals, the sentiment check, the bear check, and the R:R math inside its own context and returns one compact trade card.
   - Do not fetch headlines or run the sentiment/bear checks in this thread. Work only from the returned cards.
   - Discard any card with VERDICT: PASS (earnings in the hold window, R:R below 2.0, playbook negative edge, or missing data). If a worker fails or returns no card, treat that ticker as PASS and say so.

5. **Step 5: Output the Top 3 Trades**
   - As Lead PM, rank the surviving cards by conviction and pick the final 3 (expand each card into the strict format; do not add facts the card does not contain). In AGGRESSIVE regime all 3 must come from the top 2 leading sectors. Fewer than 3 qualifying names is acceptable; do not backfill from lagging sectors.
   - Include the regime header line from Step 2 above the trade plans.
   - Render each setup using the strict Trade Plan format defined in `CLAUDE.md`.

6. **Step 6: Hand Over to the Final Human Gate**
   - Print a compact checklist for the user to confirm before placing the order in their broker:
     1. Live price confirmation at or above the Entry Trigger.
     2. Volume expansion during the first 60 minutes of trading.
     3. Setting the hard Stop-Loss order immediately upon fill.

7. **Step 7: Auto-Journal Watchlist**
   - Append the top 3 picks to `trades/watchlist.csv` with:
     Date, Ticker, Setup Type, Entry Trigger, Stop Loss, Target 1, Target 2, Catalyst, Regime, Sector ETF, Status (PENDING)
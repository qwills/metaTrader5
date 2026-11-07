# CMarketStructure

Pure calculation class: confirmed pivot labels, direction and causal close-confirmed
BOS/CHoCH. No chart, symbol, GUI or trade API. Include:
`#include <Structure\MarketStructure.mqh>`.

## Labels and rules

H/L seed the first high/low. HH/LH compare highs; HL/LL compare lows; EH/EL mean
exact equality. Same-candle high+low pivots are skipped as ambiguous. Raw pivots
are not forced to alternate. Negative prices are valid; EMPTY_VALUE/nonfinite
prices are rejected. Open is not used; analysis validates time/high/low/close.

Initial bullish direction requires rising highs and lows; bearish requires both
falling. Mixed/equal comparisons alone do not initialize direction. Once active,
direction persists until protected swing is crossed against it. BOS crosses the
latest known same-direction pivot and promotes the latest known opposing pivot
as protection. CHoCH crosses protection and clears direction until fresh high/low
comparisons agree. Strict close crossing only; wick/equal close is insufficient.
Each pivot is consumed once. CHoCH has priority over BOS if conditions conflict.

A pivot at candle k with right=r becomes active at candle k+r+1, after the last
right candle has closed. Break time is the open time of the breaking candle;
the event becomes known only after that candle closes.

## API

- `Update(detector)` / `Update(swings[])`: snapshot labels only; clear break state.
- `Analyze(closed_bars, left, right)`: fixed-origin full replay using its own detector.
- `AnalyzeDetected(closed_bars, detector, continuation)`: consumes the matching
  validated detector once, shared with the EA selector. For continuation the caller
  must verify sufficient unchanged overlap and matching configuration.
- `Count`, `GetPoint`, `Trend`, `ProtectedSwing`, `BreakCount`, `GetBreak`, `Reset`.
- `GetCheckpoint` / `RestoreCheckpoint`: bounded confirmed runtime and event data;
  restored points/events/known times are validated. No storage APIs are used here.

Normal and AS_SERIES arrays produce chronological results. Invalid input preserves
valid prior results; empty full analysis clears results. Allocation failure during
commit clears state and returns false. Failed lookups leave output unchanged.

StructureBreak stores time/close, kind/direction, broken reference and its known
confirmation time, confirmed opposing origin and its known time, and the break
candle high/low. Thus Fibo selection can use a historical BOS even after its candle
leaves the display window. CHoCH origin is the protected reference, not a Fibo impulse.

Continuation retains the confirmed regime instead of bootstrapping every window.
Retention is at most 100 previous events plus new batch events; pure full replay
returns its snapshot's events. The EA persists the latest 20 events for timeframe
handoff. Raw H/L seed labels remain window-relative. Revisions, missing overlap and
configuration changes are the caller's responsibility; the EA detects revisions
within cached overlap and requires explicit reseed for gaps without overlap.

## Verification

`Scripts/Structure/MarketStructureExample.mq5`: 153 deterministic conditions, no
orders or objects. Build/run it in Windows. `python3 tests/check_market_structure.py`
runs the same source via C++ adapter with sanitizers. Additional rolling-window and
checkpoint-storage regressions are in `tests/check_myfibo_regressions.py`.
These checks do not replace native MetaEditor compilation/rendering verification.

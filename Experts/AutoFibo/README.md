# AutoFibo 3.00

Automatic Fibonacci EA, renamed from myFibo. Swing selection is always automatic;
there is no Manual/Auto selector and no candle-click selection. Choose **Pivot**
or **Market Structure**, with the usual left/right candle sensitivity (default
2/2). Analysis follows the chart timeframe and uses closed candles only.

## GUI and usage

The plain native Standard Library dialog uses transparent group-box titles and
thin grey frames: **Swing Otomatis**, **Swing**, **Risk**, and **Fibonacci**.
Swing and Risk sit side by side, with the six-level table below them. There is
no Arah row, timeframe selector or per-level Order column.

- On attach, the first automatic search is queued for the timer. **Cari Swing**
  requests a new search; GUI callbacks never fetch price history.
- Pivot uses the latest unambiguous confirmed opposite pair. Market Structure
  uses the causal BOS impulse; CHoCH/unclear conditions preserve the previous
  drawing while waiting. HH/HL/LH/LL and BOS/CHoCH labels stay behind the panel.
- Defaults show **50%, 61.8%, 78.6%**; checkbox choices are **23.6%, 38.2%, 50%,
  61.8%, 78.6%, 88.6%**. There are no 0% or 100% levels/checkboxes. Clearing every
  checkbox hides the object while keeping its anchors.
- Fibonacci lines/text are black. Double-click the object to edit its anchors.
  An edit remains until a different automatic pair arrives, unless **Kunci
  anchor** is checked. Lock defaults off and pauses automatic anchor updates;
  risk/SL/ratio edits and lot previews remain available.
- **Reset** removes the drawing and SL overrides, retaining risk, ratio choices,
  analysis settings and lock. Search resumes on the next closed candle or via
  Cari Swing. A locked drawing requires unlocking before searching.

## Same risk calculator as manualFibo

Enter a percentage of current **account equity**, default **5%**. Each checked
level uses its Fibonacci price as entry and shows an editable **SL price**, lot
size and estimated loss in account currency. Untouched SLs follow the swing start;
custom SLs stay fixed when anchors change. Clear a field to restore its default.
Risk/SL edits apply on finishing the edit. Invalid input restores only that field.

Direction is determined from the latest Bid/Ask snapshot, independently of swing
structure: below the spread is BUY LIMIT; above it is SELL LIMIT. The spread and
its boundaries are unavailable. BUY STOP and SELL STOP are never selected. Limit
type appears in the lot tooltip. Entry and SL must satisfy the selected direction
and broker minimum stop distance. No order submission is implemented.

The shared calculator uses OrderCalcProfit with tick-normalized prices and rounds
lots down to the volume step, respecting minimum/maximum volume. Invalid rows
clear their estimate and display a reason (Spread, Near market, SL invalid,
SL too close, Min lot, Quotes?, Data? or Risk?). Quotes/equity are refreshed once
per second from a shared snapshot; preview calculations pause while minimized
and refresh on restore. Automatic swing analysis still runs on new closed bars.
Risk is independent per level, not a total basket budget. Estimates exclude
commission, swap, slippage/gaps, margin and existing exposure checks.

## Timeframe changes and persistence

Completed anchors, native panel position/minimize state, analysis settings, ratio
choices, lock, risk and custom SLs survive chart timeframe changes. Old-timeframe
structure checkpoints/labels are discarded; unlocked analysis is rebuilt on the
new chart timeframe. Locked anchors stay unchanged until unlocked. On the same
timeframe, checkpoint continuation avoids replaying an unrelated market regime.
Label retries are independent from Fibonacci calculation/history retrieval.
Changing symbol or removing the EA clears its chart-local state and objects.

## Files and installation

AutoFibo.mq5 coordinates events/retries. AutoFiboAnalysis.mqh owns the existing
Pivot/BOS selection logic; AutoFiboChart.mqh adds bounded structure labels to the
shared drawing class; AutoFiboState.mqh persists automatic settings/checkpoints;
AutoFiboDialog.mqh adds the automatic-analysis controls.

The shared model, risk engine, GUI, drawing and common state codec live under
**Include/Fibo/** and are used by both AutoFibo and manualFibo. Automatic analysis
also needs Include/Swing and Include/Structure. Native Controls headers come
from the Windows MT5 installation.

Copy **Experts/AutoFibo**, **Include/Fibo**, **Include/Swing**, and
**Include/Structure** to the corresponding folders under MQL5. Remove the old
myFibo EA from the chart; open Experts/AutoFibo/AutoFibo.mq5 in MetaEditor, press
F7 and attach AutoFibo 3.00. Old myFibo chart state is not imported into the renamed
EA. The copy-only CMD does not delete older myFibo source/EX5 files automatically;
you may remove those manually once AutoFibo works.

```bash
python3 tests/check_autofibo.py
python3 tests/check_autofibo_analysis.py
python3 tests/check_manualfibo.py
python3 tests/check_market_structure.py
python3 tests/check_swing_detector.py
```

C++ adapters/fake APIs are not native MQL5 compilation or rendering. Verify F7,
GUI drag/minimize, field editing, structure annotations, broker estimates and
both locked/unlocked timeframe changes in Windows. ZIP generation is on request;
source builders are tools/package_autofibo.py and tools/package_manualfibo.py.

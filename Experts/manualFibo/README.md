# manualFibo 1.13

Manual Fibonacci drawing EA. No automatic swing detection, market structure,
indicators or order submission. This is a separate EA in the same Git repository;
myFibo is unchanged. MT5 allows one EA per chart, so use a separate chart if you
want both EAs running.

## Usage

1. Click **Pilih Swing**, then click near a candle high or low for the start.
2. Click near another high/low for the end. The closest extreme of the nearest
   candle is used; a midpoint tie picks its high. Equal-price endpoints are rejected.
3. Tick the ratios you want on the drawing: **23.6%, 38.2%, 50%, 61.8%, 78.6%,
   88.6%**. Default: 50%, 61.8%, 78.6%. Prices appear beside each checkbox.
   0% and 100% have no checkboxes or drawn levels; their anchor prices appear above.
4. Double-click the native Fibonacci object to select it, then drag its anchors.
   Tick **Kunci anchor** to prevent anchor editing or selection of a new swing.
   Ratio checkboxes, risk and SL fields remain usable while locked. Lock is off by default.
5. Enter **Risk % Equity** (default **5%**). The budget is a percentage of the
   current account equity and applies independently to each checked level.
6. Edit the **SL price** beside each level if needed. An untouched SL follows the
   swing-start price. Clear the field and finish editing to restore that default.
   Each checked row displays its lot size and estimated loss in account currency.

The Swing and Risk groups sit side by side above the Fibonacci level table.
The plain Standard Library panel has groups outlined by
thin grey frame edges with gaps for transparent titles. There are no filled
group panels or title background rectangles. Start/end display prices only; the
direction row is removed. The drawing and text are black, in the chart background
so the dialog remains in front. On a dark chart,
choose a light background for visibility.

**Batal** or Esc cancels a pending selection and keeps the previous completed
Fibonacci. Reset deletes the drawing and clears custom SL prices, retaining ratio, risk and lock choices. When all
ratios are unchecked the drawing is hidden; rechecking a ratio shows the same
anchors. The selection order defines the swing direction, including reverse-time
clicks. A live candle's extreme is captured at click time and does not follow ticks.

Timeframe changes retain the completed anchors, checkboxes, risk percentage, custom SL prices, lock and native panel
position. A pending selection is cancelled. Symbol changes start fresh; removing
or reattaching the EA clears its state and owned drawings. The Properties dialog
can edit anchors; the checkbox panel is authoritative for level selection, text
and styling. Other chart objects are left intact.

## Lot calculator

Each row uses its Fibonacci price as entry. Direction comes from the latest
Bid/Ask snapshot, independently of swing direction: below the spread is
**BUY LIMIT**, above the spread is **SELL LIMIT**. Entries inside the spread or
exactly at Bid/Ask are unavailable. No BUY STOP or SELL STOP type is selected.
The lot tooltip includes the selected limit type; no order column or per-level
send controls are added. A future single button can use the same limit-only rule.

Broker minimum stop distances are checked using Ask for BUY LIMIT and Bid for
SELL LIMIT. The SL must be below a BUY entry or above a SELL entry and at least
the minimum stop distance from entry. Direction and availability update on each
refresh, so an unchanged default SL can become invalid when market price crosses
a level. SLs are never moved automatically to accommodate a new direction.
Manual SL overrides stay fixed when anchors move, including when choosing a new
swing. If an override becomes invalid for the new direction, that row shows
**SL invalid** until edited or cleared. Risk/SL edits apply when editing finishes. Risk supports up to eight decimal
places; values too small to display are rejected.

The calculator uses OrderCalcProfit to estimate losses in account currency,
normalizes entry/SL to the symbol tick size, and rounds volume down to its volume
step. Lots respect minimum/maximum symbol volume. **Min lot** means the requested
budget cannot support a permitted volume; **Data?** means broker data/calculation
is unavailable; **Risk?** means risk is zero or account equity is unavailable.
**Quotes?** means no usable Bid/Ask quote is available, **Spread** marks an entry
within the spread, **Near market** marks an entry below the required pending-order
distance, and **SL too close** marks an SL below the required entry-to-stop distance.
The Lot tooltip shows the normalized entry/SL prices used in the estimate.

Results refresh once per second for changes in equity/conversion rates without
rewriting an edit in progress. Each refresh shares one equity/symbol snapshot
across the checked levels. Calculations pause while minimized and refresh
immediately on restore. Unchecked levels show no lot estimate. A 5% setting
is **per level**, so three independent filled orders can use up to 15% before
costs. Estimates exclude commission, swap, slippage and gaps. Margin, trading permissions, existing
position exposure and aggregate volume limits are not checked. This is a lot
calculator for manual orders; there are no order-submission controls.

## Files and dependencies

- manualFibo.mq5: lifecycle, manual selection and GUI event coordination.
- ManualFiboModel.mqh: anchors, ratio choices and CFibonacci calculation wrapper.
- ManualFiboDialog.mqh: native CAppDialog, buttons and checkboxes.
- ManualFiboRisk.mqh: strict input parsing and broker-aware lot/risk estimates.
- ManualFiboChart.mqh: editable OBJ_FIBO, preview marker and candle geometry.
- ManualFiboState.mqh: chart-local timeframe handoff.
- Include/Fibo/Fibonacci.mqh: shared calculation class; its defaults are unchanged.

All chart objects use the manualFibo. prefix. GUI settings use manualFibo_<chart>_GUI_v5,
separate from myFibo. No SwingDetector or MarketStructure header is needed.

## Install and validate

Use distribution/manualFibo/manualFibo.zip with install-manualFibo.cmd on Windows.
The installer extracts and copies/overwrites MQL5 files without backups. Open
Experts/manualFibo/manualFibo.mq5 in MetaEditor, press F7, then attach manualFibo 1.13.

```bash
python3 tests/check_manualfibo.py
python3 tools/package_manualfibo.py
python3 tools/package_manualfibo.py --check
```

The runner uses actual project source with C++ adapters and fake chart/GUI APIs.
It is not a compiler MQL5 test. In Windows verify F7, panel drag/minimize, checkbox
clicks, both swing directions, 88.6% prices, anchor edits, lock, cancel, reset,
all-unchecked visibility and timeframe persistence. Windows CMD and native chart
rendering have not been tested on this Mac.

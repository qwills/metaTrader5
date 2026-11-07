# manualFibo 1.03

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
   Ratio checkboxes remain usable while locked. Lock is off by default.

The plain Standard Library panel has Swing and Fibonacci groups outlined by
thin grey CPanel frames, with each title set into the top border. The background
matches the dialog. Start/end display prices only; the direction row is removed.
The drawing and text are
black, in the chart background so the dialog remains in front. On a dark chart,
choose a light background for visibility.

**Batal** or Esc cancels a pending selection and keeps the previous completed
Fibonacci. Reset deletes the drawing but retains ratio and lock choices. When all
ratios are unchecked the drawing is hidden; rechecking a ratio shows the same
anchors. The selection order defines the swing direction, including reverse-time
clicks. A live candle's extreme is captured at click time and does not follow ticks.

Timeframe changes retain the completed anchors, checkboxes, lock and native panel
position. A pending selection is cancelled. Symbol changes start fresh; removing
or reattaching the EA clears its state and owned drawings. The Properties dialog
can edit anchors; the checkbox panel is authoritative for level selection, text
and styling. Other chart objects are left intact.

## Files and dependencies

- manualFibo.mq5: lifecycle, manual selection and GUI event coordination.
- ManualFiboModel.mqh: anchors, ratio choices and CFibonacci calculation wrapper.
- ManualFiboDialog.mqh: native CAppDialog, buttons and checkboxes.
- ManualFiboChart.mqh: editable OBJ_FIBO, preview marker and candle geometry.
- ManualFiboState.mqh: chart-local timeframe handoff.
- Include/Fibo/Fibonacci.mqh: shared calculation class; its defaults are unchanged.

All chart objects use the manualFibo. prefix. GUI settings use manualFibo_<chart>_GUI_v3,
separate from myFibo. No SwingDetector or MarketStructure header is needed.

## Install and validate

Use distribution/manualFibo/manualFibo.zip with install-manualFibo.cmd on Windows.
The installer extracts and copies/overwrites MQL5 files without backups. Open
Experts/manualFibo/manualFibo.mq5 in MetaEditor, press F7, then attach manualFibo 1.03.

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

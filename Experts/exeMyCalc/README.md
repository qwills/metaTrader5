# ExeMyCalc 1.02

ExeMyCalc is a MetaTrader 5 expert advisor based on `myCalc`. It keeps the same chart-based risk calculator workflow, but submits explicit BUY or SELL market orders immediately instead of placing pending limit orders.

## Behavior

- Enter risk percent, plus separate SL and TP values for BUY and SELL.
- Drag the `BuySL`, `BuyTP`, `SellSL`, and `SellTP` horizontal chart lines to update the panel.
- Risk label, percentage input and amount are centered together in a shared top row.
- BUY and SELL have separate group boxes with thin grey borders and transparent titles.
- Each group aligns SL, TP, RR and LOT vertically, with its execution button at the bottom.
- RESET remains centered below both groups. The panel is more compact (620 x 380).
- The panel shows separate buy and sell lot sizes from account balance, risk percent, current market price, and the matching SL line.
- Each side has an editable RR value above LOT. It defaults to `0.0`.
- Editing RR recalculates that side's TP and moves the matching TP line.
- Editing or dragging SL/TP recalculates that side's RR.
- The centered `RESET` button restores risk, SL, TP, RR, and chart lines to current-market defaults.
- Default SL values use the broker minimum stop distance from current Bid/Ask.
- Clicking `BUY` submits a market buy using `BuySL` and `BuyTP`.
- Clicking `SELL` submits a market sell using `SellSL` and `SellTP`.
- Before sending, the EA refreshes entry to the live market price:
  - BUY uses current Ask.
  - SELL uses current Bid.

There is no confirmation step. Button clicks send orders immediately.

The EA normalizes price and volume to the symbol settings and validates broker stop/freeze distance constraints before order submission.

## Inputs

- `risk_pct` - percent of account balance to risk.

## Files

- `ExeMyCalc.mq5` - EA entry point and input wiring.
- `MMDialog.mqh` - two-column chart panel, horizontal lines, BUY/SELL validation flow, and market order submission.
- `MMCalculator.mqh` - price, volume, reward/risk, stop distance, and lot calculations.
- `MMConfig.mqh` - UI constants and object prefix.
- `MMNames.mqh` - chart object naming helpers.
- `MMTypes.mqh` - shared input struct.
- `ExeMyCalc.ex5` - compiled EA output.

## Build

From this directory:

```bash
../../tools/compile_mql5.sh ExeMyCalc.mq5 compile.log
```

A successful build prints:

```text
Result: 0 errors, 0 warnings
```

The compile log is UTF-16. To inspect it:

```bash
iconv -f UTF-16 -t UTF-8 compile.log
```

## Install In MetaTrader

Copy the project files to the MT5 Experts folder:

```bash
cp ExeMyCalc.mq5 ExeMyCalc.ex5 MMCalculator.mqh MMConfig.mqh MMDialog.mqh MMNames.mqh MMTypes.mqh README.md AGENTS.md "$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/ExeMyCalc/"
```

Then refresh Navigator or restart MetaTrader 5 and attach `ExeMyCalc` from Navigator > Experts to a chart.

GUI changes in 1.01–1.02 retain existing control/line names, calculation methods and
immediate market execution. The five frame edges per group are ordinary native
dialog children, so dragging/minimizing uses Standard Library behavior without
extra mouse handlers. No title background panels or custom colors were added.
F7 and visual drag/minimize checks still need MetaEditor/MT5 on Windows; existing
EX5 binaries are historical builds and do not include this source change.

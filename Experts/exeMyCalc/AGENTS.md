# AGENTS.md

This project is a MetaTrader 5 expert advisor named `ExeMyCalc`.

## Working Directory

Project path:

```text
<workspace>/Experts/exeMyCalc
```

The compile helper lives under tools/ at the workspace root:

```bash
../../tools/compile_mql5.sh ExeMyCalc.mq5 compile.log
```

The helper launches MetaTrader's bundled Wine/MetaEditor and writes a UTF-16 compile log. Running it may require access outside the workspace because it uses the installed MetaTrader/Wine environment.

## Verification

After code changes, compile with:

```bash
../../tools/compile_mql5.sh ExeMyCalc.mq5 compile.log
```

Expected clean result:

```text
Result: 0 errors, 0 warnings
```

To inspect the log:

```bash
iconv -f UTF-16 -t UTF-8 compile.log
```

Do not commit compile logs.

## MT5 Install Path

Installed MT5 Experts folder:

```text
$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/ExeMyCalc
```

Install with:

```bash
cp ExeMyCalc.mq5 ExeMyCalc.ex5 MMCalculator.mqh MMConfig.mqh MMDialog.mqh MMNames.mqh MMTypes.mqh README.md AGENTS.md "$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/ExeMyCalc/"
```

## Code Map

- `ExeMyCalc.mq5` owns EA lifecycle, inputs, and dialog creation.
- `MMDialog.mqh` owns UI controls, chart lines, validation flow, and market order sending.
- `MMCalculator.mqh` owns symbol-aware price, volume, reward/risk, stop distance, and lot calculations.
- `MMNames.mqh` owns chart object naming.
- `MMConfig.mqh` owns UI constants and `MM_OBJECT_PREFIX`.
- `MMTypes.mqh` owns shared structs.

## Current UI Behavior

- The compact panel has a shared top risk row and BUY/SELL group boxes with transparent titles.
- SL/TP/RR/LOT rows are aligned inside each group, with its market button below them.
- The shared `ENTRY` and `RR` controls are removed.
- The BUY side has `SL`, `TP`, `RR`, and `LOT` rows backed by `BuySL` and `BuyTP`.
- The SELL side has `SL`, `TP`, `RR`, and `LOT` rows backed by `SellSL` and `SellTP`.
- RR defaults to `0.0`; editing RR recalculates that side's TP and moves the matching TP line.
- Editing or dragging SL/TP recalculates that side's RR.
- The centered bottom `RESET` button restores risk, SL, TP, RR, and chart lines to current-market defaults.
- The chart has four horizontal lines: `BuySL`, `BuyTP`, `SellSL`, and `SellTP`.
- The `BUY` button submits a market buy using `BuySL` and `BuyTP`.
- The `SELL` button submits a market sell using `SellSL` and `SellTP`.
- Default SL values should stay at the broker minimum stop distance from current Bid/Ask.
- There is no execute or confirmation workflow.

## Safety Rules

- Keep market execution behavior; do not reintroduce pending limit order submission.
- BUY orders use current Ask for entry and require `BuySL` below market.
- SELL orders use current Bid for entry and require `SellSL` above market.
- Keep broker stop/freeze distance validation against current Bid/Ask.
- Keep volume normalized down to the symbol volume step.
- Preserve the existing `MM` prefix unless there is a deliberate project-wide rename.

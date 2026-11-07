# AGENTS.md

This project is a MetaTrader 5 expert advisor named `ExeAutoSL`.

## Working Directory

Project path:

```text
<workspace>/Experts/exeAutoSL
```

The compile helper lives two levels up, at the workspace root:

```bash
../../compile_mql5.sh ExeAutoSL.mq5 compile.log
```

The helper launches MetaTrader's bundled Wine/MetaEditor and writes a UTF-16 compile log. Running it may require access outside the workspace because it uses the installed MetaTrader/Wine environment.

## Verification

After code changes, compile with:

```bash
../../compile_mql5.sh ExeAutoSL.mq5 compile.log
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
$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/ExeAutoSL
```

Install with:

```bash
cp ExeAutoSL.mq5 ESDialog.mqh ESCalculator.mqh ESConfig.mqh ESNames.mqh ESTypes.mqh ExeAutoSL.ex5 README.md "$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/ExeAutoSL/"
```

## Code Map

- `ExeAutoSL.mq5` owns EA lifecycle, inputs, and dialog size.
- `ESDialog.mqh` owns UI controls, chart lines, validation flow, and market order sending.
- `ESCalculator.mqh` owns symbol-aware risk, SL, TP, price, and volume calculations.
- `ESNames.mqh` owns chart object naming. Object names include `ChartID()` to avoid collisions.
- `ESConfig.mqh` owns UI constants and `ES_OBJECT_PREFIX`.
- `ESTypes.mqh` owns shared structs.

## Current UI Behavior

- The panel has BUY and SELL columns side by side.
- Each column shows only `SL` and `TP` row labels under a BUY or SELL header.
- The chart has four live horizontal lines: `BuySL`, `BuyTP`, `SellSL`, and `SellTP`.
- The bottom `BUY` and `SELL` buttons submit orders immediately. There is no confirmation workflow.

## Safety Rules

- Keep risk distance based on `OrderCalcProfit()`, not raw tick-value shortcuts.
- Keep market SL/TP distance checks against broker stop/freeze levels and current Bid/Ask.
- Keep explicit numeric validation for user inputs. Do not rely on direct `StringToDouble(ObjectGetString(...))` conversion.
- Preserve magic number support through the `magic_number` input and `CTrade::SetExpertMagicNumber()`.
- Do not reintroduce pending order behavior; this EA is for market execution.

## Naming

Current project name is `ExeAutoSL`. Keep source identifiers under the `ES` prefix unless there is a deliberate rename.

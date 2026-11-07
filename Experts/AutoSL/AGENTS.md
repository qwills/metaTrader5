# AGENTS.md

This project is a MetaTrader 5 expert advisor named `AutoSL`.

## Working Directory

Project path:

```text
<workspace>/Experts/AutoSL
```

The compile helper lives under tools/ at the workspace root:

```bash
../../tools/compile_mql5.sh AutoSL.mq5 compile.log
```

The helper launches MetaTrader's bundled Wine/MetaEditor and writes a UTF-16 compile log. Running it requires access outside this workspace.

## Verification

After code changes, compile with:

```bash
../../tools/compile_mql5.sh AutoSL.mq5 compile.log
```

Expected clean result:

```text
Result: 0 errors, 0 warnings
```

To inspect the log:

```bash
iconv -f UTF-16 -t UTF-8 compile.log
```

Remove generated compile logs before finishing unless the user asks to keep them.

## MT5 Install Path

Compiled expert path:

```text
AutoSL.ex5
```

Installed MT5 Experts path:

```text
$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/AutoSL.ex5
```

Install with:

```bash
cp AutoSL.ex5 "$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/AutoSL.ex5"
```

## Code Map

- `AutoSL.mq5` owns EA lifecycle and inputs.
- `ASDialog.mqh` owns UI, validation, confirmation state, and order sending.
- `ASCalculator.mqh` owns symbol-aware risk, SL, TP, price, and volume calculations.
- `ASNames.mqh` owns chart object naming. Object names include `ChartID()` to avoid collisions.
- `ASConfig.mqh` owns UI constants and `AS_OBJECT_PREFIX`.
- `ASTypes.mqh` owns shared structs.

## Safety Rules

- Keep order submission two-step: `Send` previews, `Confirm` sends only if the plan signature is unchanged.
- Keep risk distance based on `OrderCalcProfit()`, not raw tick-value shortcuts.
- Keep pending entry, SL, and TP distance checks against broker stop/freeze levels.
- Keep explicit numeric validation for user inputs. Do not rely on direct `StringToDouble(ObjectGetString(...))` conversion.
- Preserve magic number support through the `magic_number` input and `CTrade::SetExpertMagicNumber()`.

## Naming

Current project name is `AutoSL`. Keep source identifiers under the `AS` prefix unless there is a deliberate rename.

Do not reintroduce old `getSL`, `GetSL`, or `GS` names.

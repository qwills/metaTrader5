# AutoSL

AutoSL is a MetaTrader 5 expert advisor that calculates stop loss and take profit levels from account risk, lot size, entry price, and risk/reward ratio, then places a pending limit order after confirmation.

## Files

- `AutoSL.mq5` - EA entry point and inputs.
- `ASDialog.mqh` - chart panel, input parsing, confirmation flow, and order submission.
- `ASCalculator.mqh` - price, volume, stop distance, and risk calculations.
- `ASConfig.mqh` - UI constants and object prefix.
- `ASNames.mqh` - chart object naming helpers.
- `ASTypes.mqh` - shared input/order structs.
- `AutoSL.ex5` - compiled EA output.

## Inputs

- `risk_pct` - percent of account balance to risk.
- `risk_reward` - take-profit distance multiplier relative to stop-loss distance.
- `magic_number` - expert magic number used for submitted orders.

## Behavior

AutoSL supports pending limit orders:

- Entry at or below Bid becomes a `BUY LIMIT`.
- Entry at or above Ask becomes a `SELL LIMIT`.
- Entry between Bid and Ask is rejected.

The EA calculates risk using `OrderCalcProfit()` so symbol contract details and currency conversion are handled by MetaTrader. It also checks broker stop/freeze distance constraints and normalizes prices and lot sizes to the symbol settings.

Order submission is two-step:

1. Click `Send` to calculate and preview the order. The button changes to `Confirm`.
2. Click `Confirm` to submit the order, if the plan has not changed.

Changing inputs or dragging the entry line clears the confirmation state.

## Build

From this directory:

```bash
../../tools/compile_mql5.sh AutoSL.mq5 compile.log
```

A successful build prints:

```text
Result: 0 errors, 0 warnings
```

The compile script uses the MetaTrader 5 app bundle and Wine prefix configured on this machine.

## Install In MetaTrader

Copy the compiled output to the MT5 Experts folder:

```bash
cp AutoSL.ex5 "$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/AutoSL.ex5"
```

Then open MetaTrader 5 and attach `AutoSL` from Navigator > Experts to a chart.

## Notes

Compile logs are generated artifacts and are intentionally not kept in the project.

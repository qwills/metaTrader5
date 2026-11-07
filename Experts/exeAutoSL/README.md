# ExeAutoSL

ExeAutoSL is a MetaTrader 5 expert advisor based on AutoSL. It calculates risk-based stop loss and take profit levels for both market BUY and market SELL conditions, then submits a market order immediately when the matching button is clicked.

## Behavior

- Enter risk percent, risk/reward, and lot size.
- BUY calculations use the current Ask as the estimated entry.
- SELL calculations use the current Bid as the estimated entry.
- The panel shows BUY and SELL columns side by side.
- Each column shows SL and TP values.
- The chart shows four live horizontal lines:
  - `BuySL`
  - `BuyTP`
  - `SellSL`
  - `SellTP`
- Clicking `BUY` submits a market buy with the calculated BUY SL/TP.
- Clicking `SELL` submits a market sell with the calculated SELL SL/TP.

There is no confirmation step. Button clicks send orders immediately.

The EA normalizes prices and lot size to the symbol settings, calculates risk with `OrderCalcProfit()`, and validates broker stop/freeze distance constraints.

## Inputs

- `risk_pct` - percent of account balance to risk.
- `risk_reward` - take-profit distance multiplier relative to stop-loss distance.
- `magic_number` - expert magic number used for submitted orders.

## Files

- `ExeAutoSL.mq5` - EA entry point and inputs.
- `ESDialog.mqh` - chart panel, BUY/SELL level display, and market order submission.
- `ESCalculator.mqh` - price, volume, stop distance, and risk calculations.
- `ESConfig.mqh` - UI constants and object prefix.
- `ESNames.mqh` - chart object naming helpers.
- `ESTypes.mqh` - shared input/order structs.
- `ExeAutoSL.ex5` - compiled EA output.

## Build

From this directory:

```bash
../../compile_mql5.sh ExeAutoSL.mq5 compile.log
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
cp ExeAutoSL.mq5 ESDialog.mqh ESCalculator.mqh ESConfig.mqh ESNames.mqh ESTypes.mqh ExeAutoSL.ex5 README.md "$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/ExeAutoSL/"
```

Then refresh Navigator or restart MetaTrader 5 and attach `ExeAutoSL` from Navigator > Experts to a chart.

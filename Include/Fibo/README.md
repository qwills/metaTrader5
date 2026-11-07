# Fibo

Reusable MQL5 Fibonacci retracement calculations for EAs, indicators, and scripts.
The caller supplies swing anchors; the class does not detect swings, draw chart
objects, round prices, or place trades.

## Integration

Copy `Fibonacci.mqh` beside your source and include it:

```cpp
#include "Fibonacci.mqh"

// Inside your event handler or calculation function:
CFibonacci fib;
if(fib.SetAnchors(100.0, 200.0))
{
   double price = fib.PriceAt(0.618); // 138.2
   if(price != EMPTY_VALUE)
      Print(price);
}
```

Alternatively, install the folder under `MQL5/Include/Fibo` and use
`#include <Fibo/Fibonacci.mqh>`.

## Conventions and API

- `SetAnchors(start, end)` accepts distinct, finite prices in chronological swing
  order. A downward swing uses a higher start and lower end. Zero and negative
  prices are supported. `IsReady()` indicates whether anchors have been set.
- `PriceAt(ratio)` uses `end + (start - end) * ratio`: 0 is the end, 1 is the start.
  Ratios are decimals, so 61.8% is `0.618`.
- Default ratios: 0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.
- `SetLevels(ratios)` replaces defaults, preserving order and duplicates.
  Negative ratios project beyond the end; ratios above 1 project beyond the start.
  These are two-anchor projections, not three-anchor Fibonacci extensions.
- `LevelCount()`, `LevelRatio(index)`, and `LevelPrice(index)` provide zero-based
  access to configured levels.
- Invalid setters return `false` and preserve previous state. Price and ratio
  getters return `EMPTY_VALUE` for invalid indices, missing anchors, invalid
  numeric inputs, or overflow. Check this sentinel before using results.
- Normalize executable prices to the consuming symbol's tick size when needed.

## Example and checks

The example now lives at `../../Scripts/Fibo/FibonacciExample.mq5` and uses a
relative include to this library. Preserve `Include/Fibo` and `Scripts/Fibo`
under the same root, compile the example in MetaEditor, then run it on a chart. It checks upward/downward retracements,
endpoints, invalid updates, indices, and custom projections, then prints levels
for the input anchors. The Experts log should show `Fibonacci checks: 0 failure(s)`.

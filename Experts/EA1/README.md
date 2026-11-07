# EA1

Chart drawing EA; it does not place trades.

Keep this workspace layout when building (see `../../docs/BUILD.md`):

```text
Experts/EA1/EA1.mq5
Include/Fibo/Fibonacci.mqh
```

The relative include uses `../../Include/Fibo/Fibonacci.mqh`.
For installation, copy the compiled `EA1.ex5` to the terminal's `MQL5/Experts/EA1/`.
The previous packaged release is retained in `archive/packages/EA1.zip`; it uses
its original folder layout. Do not mix that archive's layout with this workspace.

Compile `EA1.mq5` with MetaEditor, then attach EA1 to a chart.

1. Click **Draw Fibonacci**.
2. Click a candle near its high or low to choose the swing start.
3. Click a second candle near its high or low to choose the swing end.

The panel provides Draw Fibonacci / Cancel drawing and Reset buttons. Reset
removes the EA1 Fibonacci drawing and cancels any pending selection.
Drag the panel header with the left mouse button to move the whole panel.
Panel controls and the area excluded from candle selection move together.

Both clicks select the nearest candle center on screen, then snap to the closer
extreme by price; midpoint ties choose the high. The panel displays the selected
start candle time and price. Chart mouse dragging is temporarily disabled during
selection and its previous setting is restored when selection finishes or is
cancelled.
Clicks must fall in the main chart and map to an existing candle. Clicking in
empty space beyond the nearest candle column is ignored. Selection order defines start and end,
so either time direction and same-candle swings with different prices work.
The current candle's extreme is captured at click time.

An orange dot marks the pending start. Press Esc or click **Cancel drawing**
to cancel. Equal-price endpoints are rejected; choose another end.

The shared `CFibonacci` class calculates all seven default retracement levels:
0%, 23.6%, 38.2%, 50%, 61.8%, 78.6%, and 100%. Zero is the swing end; 100% is
the swing start. Levels are horizontal chart lines extending right, with price
labels and an orange line joining the anchors. These are grouped drawing
objects, not a draggable native Fibonacci object. Only one Fibonacci is kept. Clicking Draw Fibonacci again immediately removes
the previous drawing before selecting its replacement. Cancelling the replacement
leaves the chart without a Fibonacci. Removing or reinitializing the EA (including symbol,
timeframe, or input changes) clears its drawings and controls.

Manual check in MT5: select upward and downward swings, confirm high/low
snapping at both ends, verify 0% and 100% match the selected endpoints, cancel
after either selection step, and retry an equal-price endpoint. Verify clicking
the button never selects a candle and clicks in indicator panes are rejected.

Regression checks: click on the left and right halves of the same candle at
several zoom levels, including the latest candle; confirm the pending dot and
reported timestamp match that candle. Reset after the first click and after
repeated replacement drawings; verify the panel remains and other chart objects
remain intact. Check chart dragging is restored after completion, cancellation,
Reset, and EA removal.

Version 1.20 checks: draw a swing, then click Draw Fibonacci and confirm the
old swing disappears immediately. Drag the header while idle and while selecting
an endpoint; confirm the panel stays together and dragging never selects a
candle. Test Reset after moving the panel. Remove the EA both while selecting
and after drawing: all EA1 lines, labels, markers, and panel objects must vanish,
while unrelated chart objects remain.

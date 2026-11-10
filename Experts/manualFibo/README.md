# manualFibo 1.21

Manual Fibonacci drawing EA. No automatic swing detection, market structure,
or indicators. It submits pending LIMIT orders on demand. This is a separate EA in the same Git repository;
AutoFibo uses automatic swing selection. MT5 allows one EA per chart, so use a separate chart if you
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
   current account balance. Select **Per level** (default) to apply it independently
   to each checked level, or **All** to share one budget across all checked levels.
   The smaller input and numeric money amount sit on the same row. Balance is
   the fixed basis; floating profit/loss does not alter this amount. There is no
   Equity/Balance selector.
6. Edit the **SL price** beside each level if needed. An untouched SL follows the
   swing-start price. Clear the field and finish editing to restore that default.
   Each checked row displays its lot size and estimated loss in account currency.
7. Select **Tanpa TP / Swing end / RR**. Swing end remains the default. RR shows
   an editable ratio (default **2**), while the other modes hide that field.
   Click **Send Orders** to submit all new checked levels.
8. **Delete Orders** cancels manualFibo pending limits for this chart symbol and
   configured OrderMagic, including earlier setups. Filled positions remain open.

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

Timeframe changes retain the completed anchors, checkboxes, risk percentage/mode, custom SL prices, lock and native panel
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
send controls are added. The single Send Orders button uses the same limit-only rule.

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
is unavailable; **Risk?** means risk is zero or account balance is unavailable.
**Quotes?** means no usable Bid/Ask quote is available, **Spread** marks an entry
within the spread, **Near market** marks an entry below the required pending-order
distance, and **SL too close** marks an SL below the required entry-to-stop distance.
The Lot tooltip shows the normalized entry/SL prices used in the estimate.

Results refresh once per second for changes in balance/conversion rates without
rewriting an edit in progress. Each refresh shares one balance/symbol snapshot
across the checked levels. Calculations pause while minimized and refresh
immediately on restore. Unchecked levels show no lot estimate. A 5% setting
in **Per level** mode can total approximately 15% across three levels before
costs. **All** divides that same 5% budget equally among selected levels, so
their combined estimated SL loss stays at or below 5% after lot rounding.
Actual SL loss can exceed estimates due to costs or execution. A minimum lot
that exceeds a share blocks that level; the EA never rounds lots up or silently
drops invalid selected levels. Estimates exclude commission, swap, slippage and gaps. Total est. loss
sums all checked rows, not outstanding orders or existing positions. Invalid
rows make the combined estimate unavailable. Trading preflight is described below.

## Sending and deleting orders

Button clicks execute immediately; there is no confirmation step or automatic
sending from the timer. Enable Algo Trading and EA trading permission. Input
`OrderMagic` defaults to **11600101** and must be nonzero. Reserve it for manualFibo;
use a different magic for independent instances on the same symbol. Instances
sharing symbol/magic intentionally share duplicate protection and delete scope.

Send Orders captures the current risk/selected SL text, refreshes balance/quotes,
and prepares each new checked level. Every new level must pass price/SL/TP and
broker OrderCheck validation before any request is sent. The batch also sums
OrderCalcMargin estimates against free margin. Requests use GTC and
ORDER_FILLING_RETURN; brokers that do not support these settings reject preflight.
Margin estimates exclude existing positions/pending orders; OrderCheck and the
server remain authoritative, and prices/account state can change mid-batch.
All mode also retains the estimated loss reserved for every previously sent or
uncertain level of the same anchor setup, including deselected, filled and
partially filled levels. These reservations are subtracted before retrying/new levels.
Only exact-ticket proof of a wholly unfilled cancellation frees its reservation.
New levels receive no more than their displayed equal share and the remaining
budget divided among new levels. A retry can therefore use smaller lots than the
fresh preview. Reducing risk, changing modes or unchecking successful levels never
reclaims their reservations. Already submitted orders are not modified. Older
1.16 setup records without a saved loss block continuation in All mode rather
than guessing; use a new anchor setup. Reservations are initial SL estimates,
not portfolio exposure or a guarantee of realized loss.
Each request is checked again just before submission. Orders are independent;
there is no atomic basket operation or automatic rollback of successful orders.

TP mode belongs to manualFibo settings:

- **Tanpa TP** sends zero TP.
- **Swing end** uses the normalized swing-end price (default).
- **RR** calculates each level's TP from its own normalized entry and SL:
  BUY target = entry + abs(entry - SL) * RR; SELL target = entry - abs(entry - SL) * RR.

RR defaults to 2, must be positive and supports up to eight decimal places. Its
field is shown only in RR mode. Targets are rounded to the symbol tick size, so
actual price-distance RR may differ slightly. Each TP must be positive, on the
profit side and meet broker distance rules; one invalid new level blocks the
batch before any send. The ratio is based on price distances and excludes costs.
Mode and the last valid RR survive timeframe changes, including a valid RR draft
when the chart is switched before end-edit. Invalid committed RR restores the
previous value; invalid live input on Send blocks sending. Timer refreshes never
overwrite an RR draft. Changing these settings affects future submissions only.
It never modifies submitted orders or bypasses duplicate protection.
Dragging/resetting/removing the drawing or EA does not modify or cancel submitted
orders. Use Delete Orders explicitly. Deletion does not close filled positions,
modify BUY STOP/SELL STOP, or touch other symbols/magic numbers/EA comments.

A compact MF: setup/ratio/attempt comment and account/server/symbol/magic-scoped
terminal records prevent duplicate sends. Identity includes both anchors and the
ratio; changing risk, SL or TP does not rearm an accepted level. Active orders and
full account order history remain checked. Filled/partially filled levels stay
blocked. A proven wholly unfilled cancellation advances the attempt counter and
makes that level eligible for the next explicit Send click, even with the same
anchors. The new suffix keeps old cancelled history and late events from being
mistaken for the result of the new attempt. Definite submission failures remain
eligible for user retry without automatically sending anything.
A timeout/connection/unknown result keeps a blocking submission record.
OnTradeTransaction only captures relevant request/order notifications; it never
scans history or submits orders. A timer reconciles unknown records using exact
request IDs, owned tickets or matching active/history orders. A matched definite
rejection releases the record for the next user click; acceptance/fill keeps
duplicate protection. Deletion uses an exact-ticket check of cancelled state,
initial/remaining volume equality and no assigned position ID before rearming.
An acknowledgement, missing history or any partial fill never releases risk. Missing orders, unavailable history, mismatched IDs
and unknown return codes do not unlock a submission. Requests and broker events
can arrive in different orders, so the result is checked rather than assumed.

Pending records recover on initialization and are checked after reconnect, even
when the GUI is minimized. Polls back off from 5 to 30 seconds, probe at most 32
known tickets and scan at most 128 active and 128 history entries per pass, using
round-robin cursors and a history window from the earliest unresolved intent.
Once no unknown remains, reconciliation stops. The existing status line reports
only a summary; no per-level status column or automatic retry is added. Inspect
Trade/History and the Experts log when an outcome remains uncertain. Terminal
records expire after four weeks without access; history provides the second
check. Protection is local to this terminal, not coordinated across separate
terminal installations. Keep broker order comments/history and terminal records
intact. A terminal mutex serializes commands sharing this account/symbol/magic.

The panel shows sent/failed/uncertain/skipped counts. The Experts log identifies
each submitted ratio, broker ticket and return code, and individual delete failures.
Delete Orders covers earlier setups with the same symbol/magic and MF: comment,
including after reattachment. Send -> Delete -> Send is supported when history
confirms cancellation without fills. Failed or uncertain deletions stay blocked
and reconcile via the existing timer. A cancellation that predates this update
can also be recovered on Send when its exact ticket is saved. Old records without
a saved ticket stay blocked rather than inferring failure from absence. Drawing
reset is not an order reset and does not rearm filled positions.

## Files and dependencies

- Experts/manualFibo/manualFibo.mq5: lifecycle, manual selection and event coordination.
- Experts/manualFibo/ManualFiboDialog.mqh: TP mode/RR controls, total loss and send/delete buttons.
- Experts/manualFibo/ManualFiboSettings.mqh: TP mode and RR configuration, validation and chart handoff.
- Experts/manualFibo/ManualFiboOrders.mqh: batch preflight, limit execution, risk reservations and deletion.
- Experts/manualFibo/ManualFiboReconcile.mqh: durable intent metadata, transaction matching and bounded recovery.
- Include/_common/Fibo/FiboModel.mqh: shared anchors, ratio choices and calculation wrapper.
- Include/_common/Fibo/FiboRisk.mqh: shared input parser and limit-only risk calculator (fixed balance basis for manualFibo).
- Include/_common/Fibo/FiboDialog.mqh: shared native grouped GUI and risk/SL fields.
- Include/_common/Fibo/FiboChart.mqh: shared OBJ_FIBO, preview marker and candle geometry.
- Include/_common/Fibo/FiboState.mqh: shared chart-local model/risk handoff, isolated by EA prefix.
- Include/_common/Fibo/Fibonacci.mqh: calculation class; its defaults are unchanged.

All chart objects use the manualFibo. prefix. GUI settings use manualFibo_<chart>_GUI_v6,
separate from AutoFibo. No SwingDetector or MarketStructure header is needed.

## Install and validate

Copy Experts/manualFibo and the entire Include/_common/Fibo folder to their corresponding
MQL5 locations. Older sibling headers in Experts/manualFibo are no longer used.
When generating a ZIP, use distribution/manualFibo/manualFibo.zip with
install-manualFibo.cmd on Windows.
The installer extracts and copies/overwrites MQL5 files without backups. Open
Experts/manualFibo/manualFibo.mq5 in MetaEditor, press F7, then attach manualFibo 1.21.

```bash
python3 tests/check_manualfibo.py
# Validate source package inputs without generating a ZIP:
python3 -c "import sys; sys.path.insert(0, 'tools'); import package_manualfibo as p; print(p.check_inputs())"
# Only when a ZIP is requested:
# python3 tools/package_manualfibo.py
# python3 tools/package_manualfibo.py --check
```

The runner uses actual project source with C++ adapters and fake chart/GUI APIs.
It is not a compiler MQL5 test. In Windows verify F7, panel drag/minimize, checkbox
clicks, both swing directions, 88.6% prices, anchor edits, lock, cancel, reset,
all-unchecked visibility and timeframe persistence. Also test All/Per level totals,
partial-batch retries, reconnects, transaction ordering and unknown results on demo. Windows CMD and native chart
rendering have not been tested on this Mac.

Startup fix in 1.18 uses positive unique combo-box IDs for All / Per level.
The model/state still stores the existing boolean, so saved risk mode is unchanged.
If attachment fails, the Experts log now identifies OrderMagic, GUI creation/run,
drawing restoration or timer initialization instead of only showing code 1.

Mutex handling in 1.19 reuses an existing lock instead of unconditionally calling
GlobalVariableTemp. Creation races are rechecked, and API failures now have
separate messages from a genuinely nonzero/busy lock. Experts logs the exact key,
value and terminal error. The lock is never reset merely because time has passed.
If a busy message persists with no operation running, close/restart the terminal
to clear session-temporary locks. If it persists after restart, retain the
Experts log for diagnosis; do not clear all terminal globals, because submission
records and risk reservations provide duplicate protection.

Deletion records use marker 3 while awaiting history; markers 1/2 retain their
existing submission meanings. Attempt counters are stored separately as .Gen
and old attempt metadata is removed only after the counter is saved. A restart
between those writes stays protected. The existing GUI status/log reports the
result; no per-level order status column or automatic resend is introduced.

TP settings use the hidden chart-local manualFibo.TradeOptions object with schema
2 (mode plus RR). Legacy checkbox text 0/1 migrates to Tanpa TP/Swing end and RR 2.
This is separate from terminal-global submission/risk records; the shared Fibo
model/state schema and AutoFibo controls are unaffected. Removal/symbol changes
clear these chart settings; fresh attachment defaults to Swing end and RR 2.

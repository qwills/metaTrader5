# myFibo 2.10 — review resolution

This release implements the fixes and cleanup identified in the 2.00 review.
Calculation, chart presentation, persistence and coordination are separate.

| Review item | Resolution |
| --- | --- |
| Label failures blocked Fibo | Rendering has its own pending flag/backoff. Valid Fibo updates proceed; label retry does not call CopyRates or reapply anchors. |
| Successful retry left stale error | Analysis error state is explicit. Recovery clears transient status; a label warning is composed independently and removed after rendering succeeds. Manual edit status is preserved. |
| Invalid analysis treated as no pair | Model returns AnalysisError / Waiting / Ready. Invalid snapshots are not marked processed and are retried. Old structure is not promoted as a successful new result. |
| Installer preferred stale extracted files | Adjacent ZIP takes priority. Version, exact incoming file list and SHA-256 manifest are verified before first overwrite. |
| Duplicate pivot detection | One validated detector snapshot is shared with structure analysis through AnalyzeDetected. |
| Repeated chart writes | Renderer caches each displayed label and only updates changed/missing objects; unchanged snapshots do not move/write/delete objects. |
| Sliding-window regime reset | Structure continuation retains confirmed runtime/protected swings and recent breaks across normal windows. Events retain candle extremes even after their bars expire from the window. |
| State lifetime through timeframe change | Chart-local checkpoint roundtrip saves runtime and last 20 break events alongside the GUI/model snapshot. No large unbounded candle journal is kept. |
| Ambiguous displayed anchor source | GUI shows actual source plus edited flag independently of selected method. Older schema has Unknown provenance. |
| Manual cancellation deleted result | Completed model/object is retained; separate preview fields commit only after valid second click. Cancel/Esc restores completed GUI. Preview and completed result both survive TF handoff. |
| Long README / obsolete compatibility | Current instructions separated from CHANGELOG. Snapshot reads schemas 5 and 6; 1..4 removed. Baseline defect audit replaced with regression acceptance tests. |

## Source layout

- `myFibo.mq5`: chart/UI event dispatch, selection/configuration, timers/retries,
  capture/apply model state. No direct chart-object creation, drawing or updates.
- `MyFiboChart.mqh`: native OBJ_FIBO, text/marker drawing, cache and candle picking.
- `MyFiboState.mqh`: independent snapshot/checkpoint codec and chart-local storage.
- `MyFiboAuto.mqh`: typed analysis outcome, history validation/continuation and
  Pivot/Market Structure anchor selection.
- `CFibonacci`, `CSwingDetector`, `CMarketStructure`: reusable calculation classes;
  no GUI or chart-object API calls.

## Validation

- 153 native-script structure test bodies run through the C++ adapter, including
  causal replay, direction, BOS origin, streaming and checkpoint validation.
- 46 detector conditions and existing controller/GUI suites.
- Dedicated review regressions cover independent label retry, zero unchanged
  label writes, stale-status recovery, invalid full-history retry, anchor source,
  actual manual coordinate/candle selection with deterministic screen mocks,
  Esc/cancel, completed + preview handoff, stable continuation across 200 rolling
  windows, a quiet regime outliving 500 candles, checkpoint roundtrip and malformed
  checkpoint rejection, and explicit gap handling.
- Native chart-property state is modeled by the fake platform for scroll restore.
- Builder verifies all 19 ZIP entries, include dependencies, installer file list,
  source versions, incoming manifest hashes and CRLF CMD formatting.

The adapter is not MetaEditor. F7 compilation, native GUI popup layering/drag and
rendering, live CopyRates/network behavior, and CMD/PowerShell execution still need
Windows verification. No native compiler or PowerShell runtime is installed here;
installer branch/hash verification has been inspected and statically validated,
not executed as a Windows installation.

## Deliberate boundaries

Normal rolling windows preserve the confirmed regime and events, not permanent
unlimited price history. Raw H/L seed labels at the left edge remain relative to
the displayed detector window. Runtime retains last known highs/lows/protection;
break retention is bounded to up to 100 previous events plus the current batch,
and timeframe checkpoint saves the last 20 used for drawing/selection.

History corrections within cached overlap and older history arriving on the left
reseed the model, with an Experts notice. After a timeframe handoff, the last
checkpoint close is verified before continuation and the overlap cache is rebuilt.
Changes outside available cache cannot be audited retrospectively. A non-overlapping
gap is an explicit error; Cari Swing permits reseeding that gap. This can legitimately
change the inferred structure. Checkpoints are not advertised as terminal-session
recovery or permanent BOS history.

Short valid history with no pair receives at most three five-second retries,
then waits for the next analysis candle or explicit search. Label and data retries
respect dragging and explicit anchor lock. Windows installs overwrite without
backups as requested; copy/permission failure can still leave a partial update,
so the CMD reports failure and can be rerun after resolving the cause.

# Review myFibo 2.00

Scope: EA controller, Auto methods, structure replay, GUI, snapshots, installer,
and verification coverage. Review only: production sources and release ZIP were
not changed. Findings reproduced through the existing C++/fake-MT5 adapter.
F7 compilation, real Standard Library internals, chart rendering and Windows CMD
execution remain unverified in this environment.

## Findings to fix before adding features

1. **P2 — rendering a structure label can block the primary Fibo update.**
   `Experts/myFibo/myFibo.mq5:699` returns immediately when
   `DrawStructureLabels()` fails, even though `FindPair()` produced valid anchors.
   Reproduction: initialize Auto with valid candles and inject a failure for a
   structure-label property. Structure data exists, but no Fibo is created until
   the label retry succeeds. Separate presentation errors from analysis/anchor
   application. Retry label rendering independently while preserving the anchor
   update, user edits and lock semantics. Failure injection establishes the
   control-flow defect, not how frequently native chart writes fail.

2. **P2 — successful retries can leave the GUI showing a stale error.**
   `Experts/myFibo/myFibo.mq5:717` returns on an unchanged candidate without
   updating status. Reproduction: first draw a valid Fibo, fail a label update on
   the next analysis candle, then allow the retry to succeed with the same pair.
   `g_last_auto_bar` advances and no retry remains, but the GUI still reports
   failure. Use an explicit analysis/render status state; clear a transient error
   after recovery without overwriting meaningful messages about manual edits.

3. **P2 — analysis failure and valid absence of a pair are indistinguishable.**
   `Experts/myFibo/MyFiboAuto.mqh:78` returns false for invalid data as well as a
   legitimate no-pair outcome. `Experts/myFibo/myFibo.mq5:705` then caches a full
   500-candle snapshot as processed and reports no pivots/BOS. Reproduction:
   inject one close outside its high/low range in a full 500-candle window, then
   correct it without changing the latest candle time. No retry is scheduled;
   OnTimer skips the corrected snapshot until the next analysis candle or an
   explicit search. Return distinct AnalysisError / WaitingForPair / PairReady
   outcomes; do not render old analysis as if it were the new successful result.
   This is a robustness issue demonstrated with malformed input, not evidence
   that normal broker history routinely contains such data.

4. **P2 — installer can silently prefer an older extracted payload to a new ZIP.**
   `distribution/myFibo/install-myFibo.cmd:29` uses an adjacent `MQL5` directory
   whenever it exists. If a user puts a new ZIP/CMD alongside an old extraction,
   old files are installed; incoming version/content is not checked. Verified by
   reading the branch, not by running PowerShell. Make package-source selection
   explicit or prefer and verify the adjacent ZIP. Keep overwriting without
   backups as requested.

## Important existing limitation

Structure is replayed from scratch over a moving 500-candle window. Bootstrap
trend/protected swings can change as left-hand history expires, so past events
and selected impulses are not guaranteed stable across sliding windows. Existing
prefix tests prove causality with a fixed start, which is different. This is
already documented, not a newly discovered look-ahead defect. Before treating
Auto Structure as stable long-term state, add checkpoint/state retention and
sliding-window tests; retain a full replay path for configuration/history changes.

## Improvements and candidates for removal

- **Remove duplicate pivot detection.** `CMyFiboAuto.FindPair()` runs its detector;
  `CMarketStructure.Analyze()` constructs and runs another detector on the same
  bars (`Include/Structure/MarketStructure.mqh:192`). Share one validated snapshot.
  This is unnecessary work, not a measured explanation for native GUI drag lag.
- **Reduce unconditional chart writes.** Label slots are reused, but every analysis
  still moves and rewrites up to 50 objects and deletes all unused slots. Cache
  displayed state and update only changed labels. Do not reinstate mouse-event
  throttling that previously caused native GUI problems.
- **Remove repeated changelog text from the EA usage guide.** Keep current behavior
  and installation rules in README; move historical patch narratives to a
  changelog. This reduces contradictory-looking historical descriptions.
- **Consider retiring old handoff schemas after an explicit migration period.**
  Five read formats are maintained for a chart-local, short-lived state transfer.
  Preserve current schema and the previous release needed during upgrade; keep
  compatibility decisions separate from persistence during normal TF changes.
- **Clarify anchor provenance while waiting.** Switching to Structure after CHoCH
  intentionally retains the previous Fibo, which might have come from Pivot or
  been edited manually. Keep that behavior if desired, but distinguish the source
  of the displayed anchors from the selected method. Unclear is not Sideways.
- **Improve manual-selection cancellation.** `myFibo.mq5:873` deletes a completed
  Fibo as soon as a new manual selection starts; Esc does not restore it. Keep the
  old result until a valid replacement is completed if cancellation should be
  reversible. This is a UX choice rather than a violation of the current docs.
- **Keep model/GUI separation.** CFibonacci, CSwingDetector, CMarketStructure and
  native OBJ_FIBO serve different roles; merging these would reduce clarity.
  Consider extracting persistence and chart rendering from the 948-line EA after
  behavior fixes, without adding a large abstraction framework.

## Verification and remaining gaps

Existing checks all pass: 120 structure checks, 46 detector checks, EA/controller
and fake GUI suites, and exact source/installer ZIP verification.

The three reproduced controller findings are not covered by those passing checks.
Run `python3 tools/review_myfibo_2_00.py` to reproduce the baseline observations.
The audit asserts current defects; convert its cases into expected-correct
regression tests when fixing them. It does not change production files.

Manual click-to-candle geometry is not tested by the current runner:
`tests/check_myfibo_modes.py:84` always returns false for chart coordinate
conversion. Fake ChartGetInteger/ChartSetInteger also do not model real chart
property state. Native minimize/restore, popup layering, rendering failures,
mouse/scroll behavior, actual partial CopyRates responses and CMD execution still
need targeted Windows verification. Passing adapter checks do not establish
native compilation or measured GUI performance.

Recommended order: separate analysis outcomes, decouple label rendering, repair
status recovery, make installer payload selection reliable, then remove duplicate
analysis and repeated chart writes. Evaluate sliding-window state before expanding
the Market Structure rules. No additional trading features are needed for this pass.

## Resolution in 2.10

Implemented in 2.10. The baseline reproduction tool has been replaced by
`tests/check_myfibo_regressions.py`, which asserts corrected behavior. See
`docs/myFibo-review-2.10.md` and the EA changelog for resolution and limitations.

# manualFibo changelog

## 1.14

- Share model/risk/GUI/chart/state classes with AutoFibo under Include/Fibo.
- Keep manual swing selection, defaults, chart-object prefix and GUI position format.
- Update includes, development adapters and source-package payload for the shared headers.

## 1.13

- Infer BUY LIMIT / SELL LIMIT from a shared latest Bid/Ask quote, replacing
  swing-based direction. Never select a stop-order type or submit an order.
- Reject spread entries, missing/crossed quotes, insufficient pending-entry
  distance, and invalid or too-close SLs. Clear invalid lot/loss estimates.
- Include limit type in lot tooltips; retain the existing columns and controls.
- Keep quote/stops/point reads shared across all levels per refresh.
- Rename the dialog control-prefix member to avoid shadowing inherited m_name.
- Cover quote changes, both limit directions independent of swing, normalized
  entry prices and distance boundaries in adapter regressions.

## 1.12

- Share one equity/symbol snapshot across all lot estimates in a refresh.
- Skip broker calculations while minimized; refresh immediately on restore.
- Remove duplicate result refresh after selecting a swing and redundant work
  when risk input is unchanged; invalid input restores only the edited field.
- Replace per-call ratio array creation with direct constant lookup.
- Match risk precision to its eight-decimal display; reject values that would
  display as zero, and validate symbol volume-step precision without exact
  floating-point equality. Correct eight-decimal lot-step formatting.
- Reject empty saved drawings containing stale anchors; migrate legacy risk
  precision without losing valid drawings and retain older state readers.
- Add regressions for metadata read counts, minimized/hidden work, independent
  input recovery, precision and state validation. No GUI features removed.

## 1.11

- Move Risk beside Swing; keep the Fibonacci entry/SL/lot table below both groups.
- Shorten the panel by 90 pixels and use a new native layout settings filename.

## 1.10

- Add editable risk percentage of account equity, default 5%, and per-level SL prices.
- Untouched SLs follow the swing start; manual overrides persist until cleared/reset.
- Show independent lot and estimated-loss previews for checked levels using
  OrderCalcProfit, tick-size normalization and downward volume-step rounding.
- Refresh equity-based estimates on a timer without overwriting edits in progress.
- Preserve risk/SL settings across timeframe changes and read older state schemas.
- Keep order submission outside this calculator; no trading controls were added.

## 1.04

- Replace filled group/title panels with thin border segments and transparent titles.
- Review control registration and event dispatch; verify unique names/IDs and
  native minimize/restore behavior in the adapter.
- Remove redundant Reset display refresh and drawing/status redraws.

## 1.03

- Place Swing and Fibonacci titles into their group frame top borders.
- Remove the Arah direction label/value and compact the panel.

## 1.02

- Add thin grey CPanel group frames around Swing and Fibonacci controls.
- Create frames before controls and let the native dialog move/minimize them.

## 1.01

- Remove 0% and 100% checkboxes and drawn levels; retain six ratio choices.
- Compact the panel and migrate saved ratio masks from the original layout.

## 1.00

- Add a manual-only EA using CFibonacci calculations and an editable black OBJ_FIBO.
- Add eight ratio checkboxes including 88.6%; default to 50%, 61.8% and 78.6%.
- Preserve completed anchors, ratio choices, lock and panel geometry across
  timeframe changes; keep selection/cancellation and object names independent.
- Add adapter regression checks and a source-only Windows ZIP/CMD installer.

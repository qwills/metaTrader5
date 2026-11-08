# manualFibo changelog

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

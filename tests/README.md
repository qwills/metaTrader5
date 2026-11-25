# Development checks

Run from the workspace root:

```bash
python3 tests/check_fibonacci.py
python3 tests/check_bollinger_table.py
python3 tests/check_swing_detector.py
python3 tests/check_market_structure.py
python3 tests/check_autofibo.py
python3 tests/check_autofibo_analysis.py
python3 tests/check_manualfibo.py
```

The first three runners exercise library assertions from fixtures/. The AutoFibo
and manualFibo runners check controller behavior and GUI contracts with fake MT5 APIs. Shared
fake APIs live in mt5_adapter.py and C++ array adaptation in check_swing_detector.py; the fixtures
have no standalone script entry point and are excluded from release packages.

A C++17 compiler is required. Tests use AddressSanitizer/UndefinedBehaviorSanitizer
and temporary build directories. These adapters are not MQL5 compilers;
MetaEditor F7, chart rendering and Windows CMD execution need Windows validation.

BollingerTable checks exercise its production signal classifier and table refresh
with fake APIs: shift 0/1 reads, cross priority, equality, moving middle values,
default/custom/empty timeframe selection and skipped reads for disabled rows,
intrabar changes, unchanged-display command suppression, rollover rejection and
data/command-failure recovery. They do not validate native iBands calculations,
plot buffers, history downloads or chart rendering.
Reload checks also cover retaining table objects/values on chart changes,
claiming multiple pending instances separately, scoped cleanup, and rejecting
tables from other symbols/settings or with missing rows. Native handles are
reacquired on initialization; simulated reload does not prove MT5 cache behavior.
Warm-up regressions preserve last valid values/colors when native data is not
ready after restore, distinguish initial loading from temporary read failures,
and retain the latest valid data across failed chart commands. Tooltips distinguish
live values from cached values awaiting an update.

manualFibo execution tests use manualfibo_trade_adapter.py, a fake broker that
records requests without network access. They cover batch preflight/margin,
limit-only types, optional TP, duplicate/history/timeout protection, partial retry,
scoped deletion, current GUI inputs and the shared single-snapshot risk path.
Trading headers are not imported by AutoFibo. Live server permissions, filling,
expiration, freeze rules and asynchronous server outcomes need Windows/demo tests.

manualFibo 1.17 checks also cover All/Per level aggregate caps, partial-retry risk
reservations, compact risk controls, risk-mode persistence, matched/mismatched
transaction IDs, no scans inside the event handler, idle backoff, startup/history
recovery and exact 64-bit ticket reconstruction. All broker APIs are simulated.

manualFibo 1.20 adds fixed-balance versus floating-equity checks, repeated
send/delete/send cycles, partial/filled protection, delayed cancellation history,
restart recovery, distinct attempt identities and All reservation release tests.
The broker fixture models cancelled state and remaining volume explicitly.

manualFibo 1.21 checks cover TP mode/RR defaults, settings-schema migration,
normalized BUY/SELL targets and per-level SLs, invalid TP distance, live RR input
capture, no modification/duplication of existing orders, native restore visibility
and timeframe handoff of valid drafts. These remain fake broker/GUI checks.

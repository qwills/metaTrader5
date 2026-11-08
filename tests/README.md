# Development checks

Run from the workspace root:

```bash
python3 tests/check_fibonacci.py
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

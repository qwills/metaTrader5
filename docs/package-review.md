# Project and package review — 2026-11-07

The workspace inventory was checked across Experts, Indicators, Include,
PineScript, development runners, installers, release ZIPs and local archives.

## Findings addressed

- FibonacciExample, SwingDetectorExample and MarketStructureExample were
  installable examples. They are removed from Scripts and every local package.
- Their assertions remain development-only fixtures in tests/fixtures. The
  Fibonacci input demonstration was discarded. No fixture has a script entry
  point, and fixtures are excluded from distribution payloads.
- The standalone SwingDetector distribution and its builder were removed.
  myFibo.zip already includes the required SwingDetector headers under
  MQL5/Include/Swing; the source library and its development tests are retained.
- The current release is myFibo 2.18, distributed only as myFibo.zip. Version-named
  duplicate ZIPs were removed from distribution; historical releases stay in
  archive/packages/myFibo after removal of example entries. Production source/binary
  bytes in the affected archives were verified unchanged. Obsolete manifests in
  affected archives were removed and their installers now copy MQL5 only.
- The pre-cleanup TAR backup was repacked without FibonacciExample. Historical
  cleanup hashes remain historical evidence; Git object history was preserved.
- Package builders use explicit payloads and reject example/development entries.
  tools/check_release_packages.py also checks historical ZIP/TAR archives and
  nested ZIPs so stale examples cannot hide in compressed packages.

## Retained

EA1 is a working older Fibonacci EA; it is retained alongside the four order/risk
EAs, myFibo, RiskReward indicators and PineScript source. Production calculations,
GUI and trading behavior were not changed by this cleanup. API usage snippets in
library documentation remain documentation, not installable example programs.

## Verification

- Fibonacci: 21 checks; SwingDetector: 46; MarketStructure: 153. All pass using
  C++ adapters with sanitizers.
- myFibo mode/GUI adapter and regression runners pass.
- myFibo ZIP: 17 entries. The builder and --check pass.
- All remaining local ZIP/TAR archives pass the no-example scan.
- Windows CMD files retain CRLF and copy/overwrite without backups.

Adapters do not compile MQL5. MetaEditor F7, chart/GUI rendering and CMD execution
still require Windows. The copy-only installer does not delete examples already
installed in an existing terminal; INSTALL lists the old filenames for manual
removal.

## Folder organization

Historical reports and original inventory moved to docs/history. Current build
and API guides stay in docs and docs/reference. The macOS compiler helper is now
tools/compile_mql5.sh; the obsolete one-time Git import helper is under
tools/history. Release archives are grouped by project in archive/packages.
Current installers remain together with their ZIPs under distribution. Native
Experts/Indicators/Include paths and existing EX5 files are preserved.

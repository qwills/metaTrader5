# Current Windows packages

- AutoFibo/: install-AutoFibo.cmd and INSTALL.txt for the automatic-only EA.
  AutoFibo.zip can be generated on request with the shared Fibo/Swing/Structure libraries.
- manualFibo/: manualFibo.zip, install-manualFibo.cmd and INSTALL.txt. Manual-only
  EA with ratio checkboxes including 88.6%, per-level SL and equity-risk lot
  estimates, batch limit send/delete and optional TP. Uses Include/_common/Fibo;
  no swing/market-structure library is required.

Place the chosen CMD beside its ZIP, then run it on Windows. An optional first
argument selects another terminal Data Folder. Installers extract and copy/overwrite
MQL5 files without backups. They do not remove old files already in the terminal.
Open the installed EA .mq5 in MetaEditor and press F7. MT5 allows one EA per chart;
use separate charts if running both EAs.

Only current releases belong here. Historical ZIPs live under
archive/packages/<project>/. ZIPs are generated locally and ignored by Git.
Build and validate them using the commands in [tools](../tools/README.md).

The former myFibo ZIP was retained under archive/packages/myFibo/. Existing ZIPs
may predate source changes; use source copying until a fresh ZIP is requested.

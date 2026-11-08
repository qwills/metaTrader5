# Current Windows packages

- myFibo/: myFibo.zip, install-myFibo.cmd and INSTALL.txt. Manual/Auto EA with
  Fibonacci, SwingDetector and MarketStructure libraries.
- manualFibo/: manualFibo.zip, install-manualFibo.cmd and INSTALL.txt. Manual-only
  EA with ratio checkboxes including 88.6%, per-level SL and equity-risk lot
  estimates; only the Fibonacci library is required.

Place the chosen CMD beside its ZIP, then run it on Windows. An optional first
argument selects another terminal Data Folder. Installers extract and copy/overwrite
MQL5 files without backups. They do not remove old files already in the terminal.
Open the installed EA .mq5 in MetaEditor and press F7. MT5 allows one EA per chart;
use separate charts if running both EAs.

Only current releases belong here. Historical ZIPs live under
archive/packages/<project>/. ZIPs are generated locally and ignored by Git.
Build and validate them using the commands in [tools](../tools/README.md).

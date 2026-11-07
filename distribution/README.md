# Current Windows package

myFibo/ contains myFibo.zip, install-myFibo.cmd and INSTALL.txt. The ZIP includes
the EA and its Fibonacci, SwingDetector and MarketStructure library headers.

Place the CMD beside its ZIP, then run it on Windows. An optional first argument
selects another terminal Data Folder. The installer extracts and copies/overwrites
MQL5 files without backups. It does not remove old files already in the terminal.
Compile myFibo with F7 in MetaEditor after installing.

Only the current release belongs here. Historical ZIPs live under
archive/packages/<project>/. ZIPs are generated locally and ignored by Git.
Build and validate them using the commands in [tools](../tools/README.md).

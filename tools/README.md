# Development tools

Run these commands from the workspace root:

```bash
./tools/compile_mql5.sh --doctor
./tools/compile_mql5.sh Experts/myFibo/myFibo.mq5
python3 tools/package_myfibo.py
python3 tools/package_myfibo.py --check
python3 tools/check_release_packages.py
```

The compile helper requires an existing Wine/MetaEditor installation; it does
not install software or copy output to a terminal. See [BUILD](../docs/BUILD.md).
Package builders create current ZIPs under distribution/<project>/; --check only
validates them. The myFibo builder keeps a previous version under
archive/packages/myFibo/ when its version changes. The archive scanner checks all
local release ZIPs and backups for unwanted example or development entries.

Windows copy-only installers stay beside their ZIPs in distribution/. The old
one-time repository import helper is retained in history/first_commit.sh; it
refuses to run in a repository that already has a commit.

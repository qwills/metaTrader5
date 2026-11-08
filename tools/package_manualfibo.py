#!/usr/bin/env python3
"""Build or validate the manualFibo Windows source ZIP."""
import argparse
from pathlib import Path, PurePosixPath
import re
import tempfile
import zipfile
from check_release_packages import forbidden

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT/'distribution/manualFibo'
PACKAGE = DIST/'manualFibo.zip'
PAYLOAD = {f'MQL5/Experts/manualFibo/{name}': ROOT/'Experts/manualFibo'/name
           for name in ('manualFibo.mq5', 'ManualFiboDialog.mqh', 'ManualFiboOrders.mqh', 'ManualFiboReconcile.mqh', 'README.md', 'CHANGELOG.md')}
PAYLOAD.update({f'MQL5/Include/_common/Fibo/{name}': ROOT/'Include/_common/Fibo'/name
                for name in ('Fibonacci.mqh', 'FiboModel.mqh', 'FiboRisk.mqh',
                             'FiboDialog.mqh', 'FiboChart.mqh', 'FiboState.mqh')})
PAYLOAD.update({name: DIST/name for name in ('install-manualFibo.cmd', 'INSTALL.txt')})


def check_inputs():
    release = re.search(r'^#property\s+version\s+"([0-9.]+)"',
                        (ROOT/'Experts/manualFibo/manualFibo.mq5').read_text(), re.M).group(1)
    if (ROOT/'Experts/manualFibo/README.md').read_text().splitlines()[0] != f'# manualFibo {release}':
        raise ValueError('EA/README version mismatch.')
    if not (DIST/'INSTALL.txt').read_text().startswith(f'manualFibo {release} -'):
        raise ValueError('EA/INSTALL version mismatch.')
    cmd = (DIST/'install-manualFibo.cmd').read_bytes()
    if b'\n' in cmd.replace(b'\r\n', b''):
        raise ValueError('CMD must use CRLF.')
    text = cmd.decode('ascii')
    if text.index('if (Test-Path -LiteralPath $zip -PathType Leaf)') > text.index("$payload = Join-Path"):
        raise ValueError('Installer must prefer the adjacent ZIP.')
    if any(token in text for token in ('Get-FileHash', 'ConvertFrom-Json', '$expectedVersion')):
        raise ValueError('Installer must only extract and copy.')
    if "& xcopy.exe (Join-Path $payload '*') $mql5 /E /I /Y" not in text:
        raise ValueError('Installer must copy/overwrite MQL5 contents.')
    for name, source in PAYLOAD.items():
        if forbidden(name) or not source.is_file():
            raise ValueError(f'Invalid package input: {name}')
        if source.suffix not in ('.mq5', '.mqh'):
            continue
        for opening, include in re.findall(r'^\s*#include\s*([<"])([^">]+)[">]', source.read_text(), re.M):
            include = include.replace('\\', '/')
            if opening == '<' and include.startswith('Controls/'):
                continue
            target = str(PurePosixPath('MQL5/Include')/include if opening == '<'
                         else PurePosixPath(name).parent/include)
            if target not in PAYLOAD:
                raise ValueError(f'Missing dependency: {target}')
    return release


def check(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or set(names) != set(PAYLOAD) or archive.testzip():
            raise ValueError('Invalid manualFibo ZIP contents.')
        for name, source in PAYLOAD.items():
            if archive.read(name) != source.read_bytes():
                raise ValueError(f'Stale ZIP entry: {name}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    release = check_inputs()
    if not args.check:
        with tempfile.NamedTemporaryFile(dir=DIST, suffix='.zip', delete=False) as handle:
            temp = Path(handle.name)
        try:
            with zipfile.ZipFile(temp, 'w', zipfile.ZIP_DEFLATED) as archive:
                for name, source in PAYLOAD.items():
                    archive.write(source, name)
            check(temp)
            temp.replace(PACKAGE)
        finally:
            temp.unlink(missing_ok=True)
    check(PACKAGE)
    print(f'manualFibo {release}: {len(PAYLOAD)} ZIP entries verified against source and installer.')


if __name__ == '__main__':
    main()

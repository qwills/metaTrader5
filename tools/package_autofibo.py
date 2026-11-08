#!/usr/bin/env python3
"""Build or validate the Windows AutoFibo source package; no terminal installation."""
import argparse
from pathlib import Path, PurePosixPath
import re
import shutil
import tempfile
import zipfile
from check_release_packages import forbidden

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT/'distribution/AutoFibo'
PACKAGE = DIST/'AutoFibo.zip'
PAYLOAD = {
    'MQL5/Experts/AutoFibo/AutoFibo.mq5': ROOT/'Experts/AutoFibo/AutoFibo.mq5',
    'MQL5/Experts/AutoFibo/AutoFiboDialog.mqh': ROOT/'Experts/AutoFibo/AutoFiboDialog.mqh',
    'MQL5/Experts/AutoFibo/AutoFiboAnalysis.mqh': ROOT/'Experts/AutoFibo/AutoFiboAnalysis.mqh',
    'MQL5/Experts/AutoFibo/AutoFiboTypes.mqh': ROOT/'Experts/AutoFibo/AutoFiboTypes.mqh',
    'MQL5/Experts/AutoFibo/AutoFiboChart.mqh': ROOT/'Experts/AutoFibo/AutoFiboChart.mqh',
    'MQL5/Experts/AutoFibo/AutoFiboState.mqh': ROOT/'Experts/AutoFibo/AutoFiboState.mqh',
    'MQL5/Experts/AutoFibo/CHANGELOG.md': ROOT/'Experts/AutoFibo/CHANGELOG.md',
    'MQL5/Experts/AutoFibo/README.md': ROOT/'Experts/AutoFibo/README.md',
    'MQL5/Include/Fibo/Fibonacci.mqh': ROOT/'Include/Fibo/Fibonacci.mqh',
    'MQL5/Include/Fibo/FiboModel.mqh': ROOT/'Include/Fibo/FiboModel.mqh',
    'MQL5/Include/Fibo/FiboRisk.mqh': ROOT/'Include/Fibo/FiboRisk.mqh',
    'MQL5/Include/Fibo/FiboDialog.mqh': ROOT/'Include/Fibo/FiboDialog.mqh',
    'MQL5/Include/Fibo/FiboChart.mqh': ROOT/'Include/Fibo/FiboChart.mqh',
    'MQL5/Include/Fibo/FiboState.mqh': ROOT/'Include/Fibo/FiboState.mqh',
    'MQL5/Include/Swing/SwingDetector.mqh': ROOT/'Include/Swing/SwingDetector.mqh',
    'MQL5/Include/Swing/SwingTypes.mqh': ROOT/'Include/Swing/SwingTypes.mqh',
    'MQL5/Include/Structure/MarketStructure.mqh': ROOT/'Include/Structure/MarketStructure.mqh',
    'MQL5/Include/Structure/README.md': ROOT/'Include/Structure/README.md',
    'reference/standard-library-guide.md': ROOT/'docs/reference/standard-library-guide.md',
    'reference/download-reference.cmd': ROOT/'docs/reference/download-reference.cmd',
    'install-AutoFibo.cmd': DIST/'install-AutoFibo.cmd',
    'INSTALL.txt': DIST/'INSTALL.txt',
}


def version(source):
    match = re.search(r'^#property\s+version\s+"([0-9.]+)"', source, re.M)
    if not match:
        raise ValueError('EA version was not found.')
    return match[1]


def check_inputs():
    if any(forbidden(name) for name in PAYLOAD):
        raise ValueError("Examples and development files cannot be packaged.")
    for path in PAYLOAD.values():
        if not path.is_file():
            raise ValueError(f'Missing package input: {path}')
    release = version((ROOT/'Experts/AutoFibo/AutoFibo.mq5').read_text())
    if (ROOT/'Experts/AutoFibo/README.md').read_text().splitlines()[0] != f'# AutoFibo {release}':
        raise ValueError('EA/README version mismatch.')
    if not (DIST/'INSTALL.txt').read_text().startswith(f'AutoFibo {release} -'):
        raise ValueError('EA/INSTALL version mismatch.')
    cmd = (DIST/'install-AutoFibo.cmd').read_bytes()
    if b'\n' in cmd.replace(b'\r\n', b''):
        raise ValueError('Windows CMD must use CRLF newlines.')
    text = cmd.decode('ascii')
    if text.index("if (Test-Path -LiteralPath $zip -PathType Leaf)") > text.index("$payload = Join-Path"):
        raise ValueError('Installer must prefer the adjacent ZIP.')
    if any(token in text for token in ('Get-FileHash', 'ConvertFrom-Json', '$expectedVersion')):
        raise ValueError('Installer must only extract and copy the payload.')
    if "& xcopy.exe (Join-Path $payload '*') $mql5 /E /I /Y" not in text:
        raise ValueError('Installer must copy the extracted MQL5 contents.')
    if len(re.split(r'(?m)^# POWERSHELL\r?$', text, maxsplit=1)) != 2:
        raise ValueError('Invalid CMD/PowerShell boundary.')
    for name, path in PAYLOAD.items():
        if path.suffix not in ('.mq5', '.mqh'):
            continue
        for opening, include in re.findall(r'^\s*#include\s*([<"])([^">]+)[">]', path.read_text(), re.M):
            include = include.replace('\\', '/')
            if opening == '<' and include.startswith('Controls/'):
                continue  # Standard Library belongs to the target MT5 installation.
            target = str(PurePosixPath('MQL5/Include')/include if opening == '<'
                         else PurePosixPath(name).parent/include)
            if target not in PAYLOAD:
                raise ValueError(f'Missing packaged dependency: {name} -> {target}')
    return release


def check_zip(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or set(names) != set(PAYLOAD):
            raise ValueError('Unexpected ZIP members.')
        if archive.testzip() is not None:
            raise ValueError('ZIP CRC check failed.')
        for name, source in PAYLOAD.items():
            if archive.read(name) != source.read_bytes():
                raise ValueError(f'Stale ZIP entry: {name}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Validate current ZIP without changing it.')
    args = parser.parse_args()
    release = check_inputs()
    if not args.check:
        with tempfile.NamedTemporaryFile(dir=DIST, suffix='.zip', delete=False) as handle:
            temporary = Path(handle.name)
        try:
            with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
                for name, source in PAYLOAD.items():
                    archive.write(source, name)
            check_zip(temporary)
            if PACKAGE.exists():
                with zipfile.ZipFile(PACKAGE) as previous:
                    old = version(previous.read('MQL5/Experts/AutoFibo/AutoFibo.mq5').decode())
                if old != release:
                    backup = ROOT/f'archive/packages/AutoFibo/AutoFibo-{old}.zip'
                    backup.parent.mkdir(parents=True, exist_ok=True)
                    if not backup.exists():
                        shutil.copy2(PACKAGE, backup)
            temporary.replace(PACKAGE)
        finally:
            temporary.unlink(missing_ok=True)
    check_zip(PACKAGE)
    print(f'AutoFibo {release}: {len(PAYLOAD)} ZIP entries verified against source and installer.')


if __name__ == '__main__':
    main()

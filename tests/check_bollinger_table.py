#!/usr/bin/env python3
"""Run the entire production indicator against a simulated MT5 terminal, not MetaEditor."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from bollinger_table_adapter import SHIM

ROOT = Path(__file__).resolve().parents[1]


def adapt(source):
    source = re.sub(r'^\s*#(?:include|property).*$', '', source, flags=re.M)
    source = re.sub(r'^input\s+', '', source, flags=re.M)
    source = re.sub(r"C'24,28,34'", '0x181c22', source)
    source = re.sub(r'const (\w+) &(\w+)\[\]', r'const MqlArray<\1> &\2', source)
    source = re.sub(r'(\w+) &(\w+)\[\]', r'MqlArray<\1> &\2', source)
    # Translate array storage only; do not extract or replace production functions.
    source = re.sub(r'\b(double|MqlRates|string)\s+((?:\w+\[\](?:,\s*)?)+);',
                    lambda m: 'MqlArray<' + m[1] + '> ' + m[2].replace('[]', '') + ';', source)
    return source


def main():
    compiler = shutil.which('clang++') or shutil.which('g++')
    if not compiler:
        raise SystemExit('C++17 compiler required.')
    indicator = ROOT / 'Indicators/BollingerTable/BollingerTable.mq5'
    header = indicator.with_name('BollingerSignal.mqh')
    checks = ROOT / 'tests/fixtures/bollinger_table_checks.cpp'
    code = SHIM + '\n' + header.read_text() + '\n' + adapt(indicator.read_text()) + '\n' + checks.read_text()
    with tempfile.TemporaryDirectory(prefix='bollinger-checks-') as folder:
        cpp = Path(folder) / 'checks.cpp'
        binary = Path(folder) / 'checks'
        cpp.write_text(code)
        subprocess.run([compiler, '-std=c++17', '-Wall', '-Wextra', '-Werror', '-Wno-unused-parameter',
                        '-fsanitize=address,undefined', '-fno-sanitize-recover=all',
                        str(cpp), '-o', str(binary)], check=True)
        subprocess.run([str(binary)], check=True)
    print('C++ compatibility checks only; Windows F7 and GUI validation remain required.')


if __name__ == '__main__':
    main()

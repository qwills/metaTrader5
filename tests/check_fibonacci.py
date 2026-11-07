#!/usr/bin/env python3
"""Run development-only Fibonacci checks through the shared C++ adapter."""
from pathlib import Path
import shutil
import subprocess
import tempfile
from check_swing_detector import SHIM, adapt

ROOT = Path(__file__).resolve().parents[1]

def main():
    compiler = shutil.which('clang++') or shutil.which('g++')
    if not compiler:
        raise SystemExit('C++17 compiler required.')
    sources = ['Include/Fibo/Fibonacci.mqh', 'tests/fixtures/fibonacci_checks.mqh']
    code = SHIM + '\ndouble MathAbs(double value){return std::abs(value); }\n' + '\n'.join(adapt((ROOT/name).read_text()) for name in sources)
    code += '\nint main(){RunFibonacciChecks();return g_failures == 0 ? 0 : 1;}\n'
    with tempfile.TemporaryDirectory(prefix='fibonacci-checks-') as folder:
        cpp = Path(folder)/'checks.cpp'
        binary = Path(folder)/'checks'
        cpp.write_text(code)
        subprocess.run([compiler, '-std=c++17', '-Wall', '-Wextra', '-Werror',
                        '-fsanitize=address,undefined', '-fno-sanitize-recover=all',
                        str(cpp), '-o', str(binary)], check=True)
        subprocess.run([str(binary)], check=True)
    print('C++ compatibility checks passed; native MQL5 compilation remains separate.')

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Exercise production BB closed-bar signal logic; this is not an MQL compiler."""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    compiler = shutil.which("clang++") or shutil.which("g++")
    if not compiler:
        raise SystemExit("C++17 compiler required.")
    header = ROOT / "Indicators/BollingerTable/BollingerSignal.mqh"
    code = '#include <cassert>\n#include "' + str(header) + '"\n' + r"""
int main()
{
    assert(BollingerSignal(102, 100, 103, 101) == BB_ABOVE);
    assert(BollingerSignal(98, 100, 99, 101) == BB_BELOW);
    assert(BollingerSignal(99, 100, 102, 101) == BB_GOLDEN_CROSS);
    assert(BollingerSignal(101, 100, 100, 101) == BB_DEAD_CROSS);
    // Touching the middle precedes a cross; landing on it remains neutral.
    assert(BollingerSignal(100, 100, 102, 101) == BB_GOLDEN_CROSS);
    assert(BollingerSignal(100, 100, 100, 101) == BB_DEAD_CROSS);
    assert(BollingerSignal(99, 100, 101, 101) == BB_EQUAL);
    assert(BollingerSignal(102, 100, 101, 101) == BB_EQUAL);
    assert(BollingerSignal(100, 100, 101, 101) == BB_EQUAL);
    // Compare each close with its own middle, even when only the middle moves.
    assert(BollingerSignal(100, 101, 100, 99) == BB_GOLDEN_CROSS);
    assert(BollingerSignal(100, 99, 100, 101) == BB_DEAD_CROSS);
    // A cross expires on the next closed bar if price stays on that side.
    assert(BollingerSignal(102, 101, 103, 102) == BB_ABOVE);
    assert(BollingerSignal(100, 101, 99, 100) == BB_BELOW);
    // Small prices must not be rounded before signal classification.
    assert(BollingerSignal(0.99999, 1, 1.00001, 1) == BB_GOLDEN_CROSS);
}
"""
    with tempfile.TemporaryDirectory(prefix="bollinger-checks-") as folder:
        cpp = Path(folder) / "checks.cpp"
        binary = Path(folder) / "checks"
        cpp.write_text(code)
        subprocess.run([compiler, "-std=c++17", "-Wall", "-Wextra", "-Werror",
                        "-fsanitize=address,undefined", "-fno-sanitize-recover=all",
                        str(cpp), "-o", str(binary)], check=True)
        subprocess.run([str(binary)], check=True)
    print("14 BB signal checks passed; Windows F7 and GUI validation remain required.")


if __name__ == "__main__":
    main()

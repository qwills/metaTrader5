#!/usr/bin/env python3
"""Run the MQL test script through a C++ array adapter, not a MetaEditor compiler.

Only MQL dynamic-array declarations/reference types and enum backing types are translated. The detector
algorithm and test bodies are shared verbatim with the native MQL5 example.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SHIM = r'''
#include <climits>
#include <cmath>
#include <cstdio>
#include <iostream>
#include <limits>
#include <string>
#include <vector>
using string = std::string;
using datetime = long long;
const double EMPTY_VALUE = std::numeric_limits<double>::max();
struct MqlRates {
 datetime time; double open, high, low, close;
 long long tick_volume; int spread; long long real_volume;
};
template<class T> struct MqlArray {
 std::vector<T> data;
 bool series = false;
 MqlArray() = default;
 MqlArray(std::initializer_list<T> values): data(values) {}
 T &operator[](int index) { return data.at(series ? data.size()-1-index : index); }
 const T &operator[](int index) const { return data.at(series ? data.size()-1-index : index); }
};
template<class T> int ArraySize(const MqlArray<T> &a) { return static_cast<int>(a.data.size()); }
template<class T> int ArrayResize(MqlArray<T> &a, int size) {
 if(size < 0) return -1;
 try { a.data.resize(size); } catch(...) { return -1; }
 return size;
}
template<class T> bool ArrayGetAsSeries(const MqlArray<T> &a) { return a.series; }
template<class T> bool ArraySetAsSeries(MqlArray<T> &a, bool series) { a.series=series; return true; }
bool MathIsValidNumber(double value) { return std::isfinite(value); }
template<class... T> void Print(const T &... values) { (std::cout << ... << values) << '\n'; }
template<class... T> void PrintFormat(const char *format, T... values) { std::printf(format, values...); std::puts(""); }
'''

def adapt(source):
    source = re.sub(r'^\s*#(?:include|property).*$', '', source, flags=re.M)
    source = re.sub(r'enum (\w+)\s*\{', r'enum \1 : int {', source)
    source = re.sub(r'const (\w+) &(\w+)\[\]', r'const MqlArray<\1> &\2', source)
    source = re.sub(r'(\w+) &(\w+)\[\]', r'MqlArray<\1> &\2', source)
    return re.sub(r'\b(StructureBreak|StructurePoint|SwingPoint|MqlRates|double|int|string)\s+(\w+)\[\]', r'MqlArray<\1> \2', source)


def main():
    compiler = shutil.which('clang++') or shutil.which('g++')
    if not compiler:
        raise SystemExit('A C++17 compiler is required for this compatibility check.')
    sources = [ROOT/'Include/Swing/SwingTypes.mqh', ROOT/'Include/Swing/SwingDetector.mqh',
               ROOT/'Scripts/Swing/SwingDetectorExample.mq5']
    code = SHIM + '\n'.join(adapt(p.read_text()) for p in sources)
    code += '\nint main() { OnStart(); return g_failures == 0 ? 0 : 1; }\n'
    with tempfile.TemporaryDirectory(prefix='swing-detector-') as folder:
        cpp = Path(folder)/'checks.cpp'
        binary = Path(folder)/'checks'
        cpp.write_text(code)
        subprocess.run([compiler, '-std=c++17', '-Wall', '-Wextra', '-Werror',
                        '-fsanitize=address,undefined', '-fno-sanitize-recover=all', str(cpp), '-o', str(binary)], check=True)
        subprocess.run([str(binary)], check=True)
    print('C++ compatibility checks passed. Native MQL5 compilation remains a separate check.')


if __name__ == '__main__':
    main()

# Shared custom libraries

- Fibo/: Fibonacci model, equity risk, native GUI, drawing and state for AutoFibo/manualFibo.
- Swing/: confirmed pivot detector and swing types.
- Structure/: market structure and BOS/CHoCH analysis used by AutoFibo.

Copy this folder to MQL5/Include/_common. EA includes use angle brackets, e.g.
`#include <_common\Fibo\FiboDialog.mqh>`; sibling headers use quotes.
Native Standard Library headers such as `<Controls\Dialog.mqh>` remain provided
by the terminal. Each package includes only its required custom headers.

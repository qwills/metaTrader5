#!/usr/bin/env bash
# Compile with MetaEditor under Wine. No installation or trading is performed.
set -euo pipefail

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'EOF'
Usage: ./tools/compile_mql5.sh [source.mq5] [compile.log]
       ./tools/compile_mql5.sh --doctor

With no source, the current folder must contain exactly one .mq5 file.
Optional environment variables:
  WINE64           Wine executable (absolute path or command name)
  WINEPREFIX       Existing Wine prefix
  METAEDITOR       Unix path to metaeditor64.exe inside that prefix
  MQL5_ROOT        Terminal MQL5 folder containing Include/Controls and Include/Trade
EOF
}
case "${1:-}" in -h|--help) usage; exit 0;; esac
[[ $# -le 2 ]] || { usage >&2; exit 2; }

PREFIX="${WINEPREFIX:-$HOME/Library/Application Support/net.metaquotes.wine.metatrader5}"
WINE_BIN="${WINE64:-}"
if [[ -z "$WINE_BIN" ]]; then
  for candidate in "/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64" \
                   "/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine"; do
    if [[ -x "$candidate" ]]; then WINE_BIN="$candidate"; break; fi
  done
  if [[ -z "$WINE_BIN" ]]; then
    WINE_BIN="$(command -v wine64 || command -v wine || true)"
  fi
elif [[ "$WINE_BIN" != */* ]]; then
  WINE_BIN="$(command -v "$WINE_BIN" || true)"
fi
EDITOR="${METAEDITOR:-$PREFIX/drive_c/Program Files/MetaTrader 5/metaeditor64.exe}"
INCLUDE_ROOT="${MQL5_ROOT:-$(dirname "$EDITOR")/MQL5}"

if [[ "${1:-}" == --doctor ]]; then
  issues=0
  printf 'Wine: %s\nWine prefix: %s\nMetaEditor: %s\nMQL5 root: %s\n' \
    "${WINE_BIN:-(missing)}" "$PREFIX" "$EDITOR" "$INCLUDE_ROOT"
  if [[ -z "$WINE_BIN" || ! -x "$WINE_BIN" ]]; then printf 'MISSING: Wine executable\n'; issues=1; fi
  if [[ ! -d "$PREFIX/drive_c" ]]; then printf 'MISSING: existing Wine prefix with drive_c\n'; issues=1; fi
  if [[ ! -f "$EDITOR" ]]; then printf 'MISSING: MetaEditor compiler\n'; issues=1; fi
  for header in Controls/Dialog.mqh Trade/Trade.mqh; do
    if [[ ! -f "$INCLUDE_ROOT/Include/$header" ]]; then printf 'MISSING: Include/%s\n' "$header"; issues=1; fi
  done
  exit "$issues"
fi

SOURCE="${1:-}"
if [[ -z "$SOURCE" ]]; then
  shopt -s nullglob
  sources=("$PWD"/*.mq5)
  shopt -u nullglob
  if [[ ${#sources[@]} -ne 1 ]]; then usage >&2; exit 2; fi
  SOURCE="${sources[0]}"
fi
[[ -f "$SOURCE" && "$SOURCE" == *.mq5 ]] || fail "Source .mq5 tidak ditemukan: $SOURCE"
# Resolve '..' before converting to a Windows path.
SOURCE="$(cd "$(dirname "$SOURCE")" && pwd -P)/$(basename "$SOURCE")"
LOG="${2:-$(dirname "$SOURCE")/compile.log}"
[[ -d "$(dirname "$LOG")" ]] || fail "Folder log tidak ditemukan: $(dirname "$LOG")"
LOG="$(cd "$(dirname "$LOG")" && pwd -P)/$(basename "$LOG")"
[[ "$LOG" != "$SOURCE" && "$LOG" != "${SOURCE%.mq5}.ex5" ]] || fail 'Log tidak boleh menimpa source atau binary.'
[[ -n "$WINE_BIN" && -x "$WINE_BIN" ]] || fail 'Wine tidak tersedia. Jalankan --doctor; lihat docs/BUILD.md.'
[[ -d "$PREFIX/drive_c" ]] || fail "Wine prefix tidak ditemukan: $PREFIX"
[[ -f "$EDITOR" ]] || fail "MetaEditor tidak ditemukan: $EDITOR"
for header in Controls/Dialog.mqh Trade/Trade.mqh; do
  [[ -f "$INCLUDE_ROOT/Include/$header" ]] || fail "Standard library tidak ditemukan: $INCLUDE_ROOT/Include/$header. Atur MQL5_ROOT."
done
PREFIX="$(cd "$PREFIX" && pwd -P)"
EDITOR="$(cd "$(dirname "$EDITOR")" && pwd -P)/$(basename "$EDITOR")"
INCLUDE_ROOT="$(cd "$INCLUDE_ROOT" && pwd -P)"

# Use Wine's drive mappings when available; default Wine maps Z: to /.
to_wine_path() {
  local winepath_bin
  winepath_bin="$(dirname "$WINE_BIN")/winepath"
  if [[ -x "$winepath_bin" ]]; then
    WINEPREFIX="$PREFIX" "$winepath_bin" -w "$1"
  else
    [[ -L "$PREFIX/dosdevices/z:" && "$(readlink "$PREFIX/dosdevices/z:")" == / ]] || \
      fail 'Butuh winepath atau Wine mapping dosdevices/z: -> /.'
    printf 'Z:%s' "${1//\//\\}"
  fi
}
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mql5-compile.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
# macOS /tmp and /var may be symlinks; Wine needs their canonical paths.
TMP_DIR="$(cd "$TMP_DIR" && pwd -P)"
SOURCE_WIN="$(to_wine_path "$SOURCE")"
LOG_WIN="$(to_wine_path "$TMP_DIR/compile.log")"
INCLUDE_WIN="$(to_wine_path "$INCLUDE_ROOT")"
set +e
WINEPREFIX="$PREFIX" "$WINE_BIN" "$EDITOR" "/compile:$SOURCE_WIN" "/include:$INCLUDE_WIN" "/log:$LOG_WIN"
compiler_status=$?
set -e
[[ -s "$TMP_DIR/compile.log" ]] || fail "Compiler tidak menghasilkan log (exit $compiler_status)."
cp "$TMP_DIR/compile.log" "$LOG"
# MetaEditor writes UTF-16 logs; accept UTF-8 logs from other releases too.
if [[ "$(od -An -tx1 -N2 "$LOG" | tr -d ' \n')" == fffe ]]; then
  iconv -f UTF-16 -t UTF-8 "$LOG" > "$TMP_DIR/readable.log"
else
  cat "$LOG" > "$TMP_DIR/readable.log"
fi
tail -n 20 "$TMP_DIR/readable.log"
# Process exit status alone can report success despite compilation errors.
if ! grep -Eq '(^|[^0-9])0 errors?,[[:space:]]*[0-9]+ warnings?' "$TMP_DIR/readable.log"; then
  fail "Kompilasi gagal atau hasil tidak dikenali. Log: $LOG"
fi
[[ -s "${SOURCE%.mq5}.ex5" ]] || fail 'Log sukses tetapi output .ex5 tidak ditemukan.'
printf 'Output: %s\nLog: %s\n' "${SOURCE%.mq5}.ex5" "$LOG"

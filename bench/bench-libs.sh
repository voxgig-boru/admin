#!/usr/bin/env bash
# bench-libs.sh — whole-process wall time per suite, best of $RUNS, on boru's
# single (compiled) execution path.
#
# There is no interpreter to compare against any more (the fallback and the
# --no-compile / --force-compile flags were retired upstream 2026-09-19), so
# this reports the compiled wall time and, when BASELINE names an older
# bench file, compares it with that file's COMPILE column (the 2026-07-29
# file's COMPILE column was measured with --force-compile, i.e. the same
# fully-compiled path). RATIO = baseline ÷ now (>1 = faster now).
#
# Usage:
#   BORU=/path/to/boru LIBS_DIR=/path/to/checkouts \
#   BASELINE=baselines/bench-2026-07-29.txt bash bench/bench-libs.sh [lib ...]
set -uo pipefail
BORU="${BORU:-boru}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBS_DIR="${LIBS_DIR:-$(cd "$HERE/../.." && pwd)}"
RUNS="${RUNS:-3}"
BASELINE="${BASELINE:-}"
[ -n "$BASELINE" ] && BASELINE="$(cd "$(dirname "$BASELINE")" && pwd)/$(basename "$BASELINE")"
if [ $# -gt 0 ]; then LIBS=("$@"); else
  LIBS=(aless bloom-filter cache decision graph sort stats template trie)
fi

now_ms() { python3 -c 'import time;print(int(time.time()*1000))'; }
best() { # best-of-RUNS wall ms; prints "-" if any run fails
  local min=""
  for _ in $(seq 1 "$RUNS"); do
    local t0 t1 dt
    t0=$(now_ms); "$BORU" "$1" >/dev/null 2>&1 || { echo "-"; return; }; t1=$(now_ms)
    dt=$((t1-t0))
    if [ -z "$min" ] || [ "$dt" -lt "$min" ]; then min=$dt; fi
  done
  echo "$min"
}
# The 2026-07-29 baseline named aless "alice"; map it when looking a row up.
base_ms() {
  [ -n "$BASELINE" ] && [ -f "$BASELINE" ] || return 0
  local lib="$1"; [ "$lib" = aless ] && lib=alice
  awk -v l="$lib" -v s="$2.aql" '$1==l && $2==s {print $4}' "$BASELINE"
}

echo "boru: $("$BORU" -version 2>&1)"
printf '%-14s %-30s %8s %8s %7s\n' LIB SUITE "NOW" "BASE" "RATIO"
printf '%-14s %-30s %8s %8s %7s\n' "---" "-----" "ms" "ms" "x"
for lib in "${LIBS[@]}"; do
  cd "$LIBS_DIR/$lib" 2>/dev/null || continue
  for s in test/*_test.aql test/*_spec.aql; do
    [ -f "$s" ] || continue
    n="$(basename "$s" .aql)"
    ms=$(best "$s")
    b=$(base_ms "$lib" "$n"); b="${b:--}"
    if [ "$ms" != "-" ] && [ "$b" != "-" ] && [ "$ms" -gt 0 ]; then
      r=$(python3 -c "print(f'{$b/$ms:.2f}')")
    else r="-"; fi
    printf '%-14s %-30s %8s %8s %7s\n' "$lib" "$n.aql" "$ms" "$b" "$r"
  done
done

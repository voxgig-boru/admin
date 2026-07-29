#!/usr/bin/env bash
set -uo pipefail
AQL="${AQL:-/tmp/aql-latest}"
LIBS_DIR="$HOME/Projects/voxgig-aql"
declare -a LIBS=(alice bloom-filter decision sort stats template trie)
RUNS=3

now_ms() { python3 -c 'import time;print(int(time.time()*1000))'; }
best() { # runs a command RUNS times, echoes min ms
  local mode="$1"; shift
  local min=""
  for _ in $(seq 1 $RUNS); do
    local t0 t1
    t0=$(now_ms); "$AQL" $mode "$@" >/dev/null 2>&1; t1=$(now_ms)
    local dt=$((t1-t0))
    if [ -z "$min" ] || [ $dt -lt $min ]; then min=$dt; fi
  done
  echo "$min"
}

printf '%-14s %-30s %8s %8s %7s\n' LIB SUITE "INTERP" "COMPILE" "SPEEDUP"
printf '%-14s %-30s %8s %8s %7s\n' "---" "-----" "ms" "ms" "x"
for lib in "${LIBS[@]}"; do
  cd "$LIBS_DIR/$lib" || continue
  for s in test/*_test.aql test/*_spec.aql; do
    [ -f "$s" ] || continue
    ims=$(best "--no-compile" "$s")
    cms=$(best "--force-compile" "$s")
    if [ "$cms" -gt 0 ]; then
      spd=$(python3 -c "print(f'{$ims/$cms:.2f}')")
    else spd="-"; fi
    printf '%-14s %-30s %8s %8s %7s\n' "$lib" "$(basename "$s")" "$ims" "$cms" "$spd"
  done
done

#!/usr/bin/env bash
# verify-libs.sh — cross-library correctness sweep on boru's single execution path.
#
# Since boru 2026-09-19 there is ONE execution path: a program compiles to
# bytecode and runs on the VM, or it fails with `[boru/compile_failed]`
# (a compiler defect). The interpreter fallback and the --compile /
# --force-compile / --no-compile flags are retired, so the old four surfaces
# (interpret / bytecheck / compile-parity / force-compile) collapse to two:
#
#   run    `boru <suite>` from the lib root: compiles, pre-flight-checks and
#          runs. PASS = exit 0 (assertion-bearing suites also print
#          "all green"). A failure is classified as
#            COMPILE  the emitter refused the program (a compiler defect —
#                     this is the "full compilation" metric)
#            CHECK    the static pre-flight check refused it
#            FAIL     it compiled and ran, but errored or an assertion failed
#   check  `boru check <suite>` reports 0 errors.
#
# Each library's root module(s) are also checked standalone (advisory: a
# module checked without callers can surface diagnostics a suite does not).
#
# Usage:
#   BORU=/path/to/boru LIBS_DIR=/path/to/checkouts bash bench/verify-libs.sh [lib ...]
#   MD=1 …   additionally prints the per-suite table as Markdown
set -uo pipefail
BORU="${BORU:-boru}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBS_DIR="${LIBS_DIR:-$(cd "$HERE/../.." && pwd)}"
TIMEOUT="${TIMEOUT:-600}"
if [ $# -gt 0 ]; then LIBS=("$@"); else
  LIBS=(aless bloom-filter cache decision graph sort stats template trie)
fi

now_ms() { python3 -c 'import time;print(int(time.time()*1000))'; }

TOTAL=0; PASS=0; COMPILE=0; CHECKREF=0; FAILS=0; CHECKERR=0
MODERR=0; MODS=0
ROWS=()

echo "boru: $("$BORU" -version 2>&1)"
echo "libs: $LIBS_DIR"
echo
printf '%-13s %-26s %-8s %-6s %-7s %s\n' LIB SUITE RUN CHECK MS DETAIL
printf '%-13s %-26s %-8s %-6s %-7s %s\n' --- ----- --- ----- -- ------

for lib in "${LIBS[@]}"; do
  root="$LIBS_DIR/$lib"
  cd "$root" 2>/dev/null || { echo "$lib: MISSING ($root)"; continue; }
  for s in test/*_test.aql test/*_spec.aql test/*_test.boru test/*_spec.boru; do
    [ -f "$s" ] || continue
    name="$(basename "$s")"; name="${name%.*}"
    TOTAL=$((TOTAL+1))

    t0=$(now_ms); out="$(timeout "$TIMEOUT" "$BORU" "$s" 2>&1)"; rc=$?; t1=$(now_ms)
    detail=""
    if [ $rc -eq 0 ]; then
      run="ok"; PASS=$((PASS+1))
      case "$name" in *smoke*) ;; *) printf '%s\n' "$out" | grep -q 'all green' || detail="(no 'all green')";; esac
    elif printf '%s\n' "$out" | grep -q 'compile_failed'; then
      run="COMPILE"; COMPILE=$((COMPILE+1))
      detail="$(printf '%s\n' "$out" | grep -o 'compilation FAILED: .*' | head -1 | sed 's/ — this is a compiler defect.*//' | cut -c21-140)"
    elif printf '%s\n' "$out" | grep -qE '^check failed|^check: [0-9]+:[0-9]+: \[error\]'; then
      run="CHECK"; CHECKREF=$((CHECKREF+1))
      detail="$(printf '%s\n' "$out" | grep -m1 -oE '\[error\] .*' | cut -c1-120)"
    else
      run="FAIL"; FAILS=$((FAILS+1))
      detail="$(printf '%s\n' "$out" | grep -m1 -E 'FAIL|error' | cut -c1-120)"
    fi

    cerr="$(timeout "$TIMEOUT" "$BORU" check "$s" 2>&1 | grep -oE '[0-9]+ error' | grep -oE '[0-9]+' | tail -1)"
    cerr="${cerr:-?}"
    if [ "$cerr" = 0 ]; then chk="ok"; else chk="E($cerr)"; CHECKERR=$((CHECKERR+1)); fi

    printf '%-13s %-26s %-8s %-6s %-7s %s\n' "$lib" "$name" "$run" "$chk" "$((t1-t0))" "$detail"
    ROWS+=("| $lib | $name | $run | $chk | $((t1-t0)) | ${detail//|/\\|} |")
  done
  for m in *.aql *.boru; do
    [ -f "$m" ] || continue
    MODS=$((MODS+1))
    merr="$(timeout "$TIMEOUT" "$BORU" check "$m" 2>&1 | grep -oE '[0-9]+ error' | grep -oE '[0-9]+' | tail -1)"
    merr="${merr:-?}"
    [ "$merr" = 0 ] || MODERR=$((MODERR+1))
    printf '%-13s %-26s %-8s %-6s\n' "$lib" "[module] $m" "-" "$([ "$merr" = 0 ] && echo ok || echo "E($merr)")"
  done
done

if [ "${MD:-0}" = 1 ]; then
  echo
  echo "| lib | suite | run | check | ms | detail |"
  echo "|---|---|---|---|---:|---|"
  printf '%s\n' "${ROWS[@]}"
fi

echo
echo "================ SUMMARY ================"
echo "suites           : $TOTAL"
echo "run pass         : $PASS"
echo "compile refusals : $COMPILE   (compiler defects — the full-compilation gap)"
echo "check refusals   : $CHECKREF   (pre-flight check blocked the run)"
echo "runtime fails    : $FAILS"
echo "suite check errs : $CHECKERR"
echo "modules w/ errs  : $MODERR / $MODS   (advisory)"
if [ $((TOTAL-PASS+CHECKERR)) -eq 0 ]; then
  echo "RESULT: PASS — every suite compiles, runs green, and checks clean."
else
  echo "RESULT: ISSUES FOUND (see above)."
fi

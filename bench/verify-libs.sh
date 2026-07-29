#!/usr/bin/env bash
set -uo pipefail
AQL="${AQL:-/tmp/aql-latest}"
LIBS_DIR="$HOME/Projects/voxgig-aql"
declare -a LIBS=(alice bloom-filter decision sort stats template trie)

REFUSALS=0
DIVERGES=0
CHECKERR=0
INTERPFAIL=0
FORCEFAIL=0
TOTAL_SUITES=0

printf '%-14s %-30s %-7s %-7s %-7s %-7s\n' LIB SUITE INTERP CHECK COMPILE FORCE
printf '%-14s %-30s %-7s %-7s %-7s %-7s\n' "---" "-----" "------" "-----" "-------" "-----"

for lib in "${LIBS[@]}"; do
  root="$LIBS_DIR/$lib"
  cd "$root" || { echo "$lib: MISSING"; continue; }
  for s in test/*_test.aql test/*_spec.aql; do
    [ -f "$s" ] || continue
    name="$(basename "$s")"
    TOTAL_SUITES=$((TOTAL_SUITES+1))

    interp="$("$AQL" --no-compile "$s" 2>&1)"; irc=$?
    if [ $irc -eq 0 ]; then i="ok"; else i="FAIL"; INTERPFAIL=$((INTERPFAIL+1)); fi

    cerr="$("$AQL" check "$s" 2>&1 | grep -oE '[0-9]+ error' | grep -oE '[0-9]+' | head -1)"
    cerr="${cerr:-0}"
    if [ "$cerr" = 0 ]; then c="ok"; else c="ERR($cerr)"; CHECKERR=$((CHECKERR+1)); fi

    comp="$("$AQL" --compile "$s" 2>&1)"
    if [ "$interp" = "$comp" ]; then b="ok"; else b="DIVERGE"; DIVERGES=$((DIVERGES+1)); fi

    fout="$("$AQL" --force-compile "$s" 2>&1)"; frc=$?
    if printf '%s\n' "$fout" | grep -q 'force-compile:'; then
      f="REFUSE"; REFUSALS=$((REFUSALS+1))
    elif [ $frc -ne 0 ]; then
      f="FAIL"; FORCEFAIL=$((FORCEFAIL+1))
    else
      f="ok"
    fi

    printf '%-14s %-30s %-7s %-7s %-7s %-7s\n' "$lib" "$name" "$i" "$c" "$b" "$f"
    if [ "$f" = REFUSE ]; then
      printf '    ↳ %s\n' "$(printf '%s\n' "$fout" | grep -o 'force-compile:.*' | head -1)"
    fi
    if [ "$b" = DIVERGE ]; then
      diff <(printf '%s\n' "$interp") <(printf '%s\n' "$comp") | head -6 | sed 's/^/    ↳ /'
    fi
  done
done

echo
echo "================ SUMMARY ================"
echo "suites checked : $TOTAL_SUITES"
echo "interp fails   : $INTERPFAIL"
echo "check errors   : $CHECKERR"
echo "divergences    : $DIVERGES"
echo "force refusals : $REFUSALS"
echo "force fails    : $FORCEFAIL"
if [ $((INTERPFAIL+CHECKERR+DIVERGES+REFUSALS+FORCEFAIL)) -eq 0 ]; then
  echo "RESULT: PASS — all suites interpret, bytecheck, compile-parity, and fully force-compile."
else
  echo "RESULT: ISSUES FOUND (see above)."
fi

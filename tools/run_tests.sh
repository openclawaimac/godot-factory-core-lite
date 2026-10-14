#!/usr/bin/env bash
# Strict runner: fails on non-zero exit, any "SCRIPT ERROR" in the output, or a
# missing "RESULT: PASS" line (crash / early exit). Usage: tools/run_tests.sh [godot]
set -u
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
LOG="$(mktemp)"
"$GODOT" --headless --path . -s res://tests/run_tests.gd >"$LOG" 2>&1
CODE=$?
cat "$LOG" > tests/last_run.txt
STATUS=0
if [ $CODE -ne 0 ]; then echo "runner: godot exit code $CODE"; STATUS=1; fi
if grep -q "SCRIPT ERROR" "$LOG"; then echo "runner: SCRIPT ERROR in output:"; grep -A2 "SCRIPT ERROR" "$LOG" | head -20; STATUS=1; fi
if ! grep -q "^RESULT: PASS" "$LOG"; then echo "runner: no 'RESULT: PASS' line (failure, crash or early exit)"; STATUS=1; fi
grep -E "^RESULT:|PROBLEM|FAIL " "$LOG" | head -30
rm -f "$LOG"
exit $STATUS

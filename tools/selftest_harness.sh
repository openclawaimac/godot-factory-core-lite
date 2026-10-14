#!/usr/bin/env bash
# Proves the strict runner catches failures it used to miss. Runs the suite with
# HARNESS_SELFTEST=crash (deliberate script error) and =exit (early quit(0)) and
# expects BOTH runs to FAIL. Normal runs never set the variable. Exit 0 = harness OK.
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
OK=0
for MODE in crash exit; do
  OUT="$(HARNESS_SELFTEST=$MODE tools/run_tests.sh "$GODOT")"
  CODE=$?
  echo "$OUT" | grep -E "^RESULT:|runner:" | head -4
  if [ $CODE -ne 0 ]; then echo "self-test '$MODE': run failed as it should (exit $CODE)"
  else echo "self-test '$MODE': BROKEN, run passed"; OK=1; fi
done
exit $OK

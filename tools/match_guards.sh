#!/usr/bin/env bash
# The match guards (tests/guards, MG1 and FG2): whole bot matches over 16 seeds on each field, headless, in Elimination
# and in Attack / Defend, and the callouts' guards (CO1: one match a map, the bots' calls checked). Many minutes, so they
# run as CI jobs of their own (one a file) and not in tools/check.sh's unit tests. Prints failures and totals.
# Usage: tools/match_guards.sh [file [test]]   (a file in tests/guards, e.g. test_flag_guards, and optionally the tests
#                                              in it whose names hold `test`, e.g. elimination_at_easy; all of them
#                                              without one; GODOT=/path/to/godot to override)
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
LOG="${GUARDS_LOG:-guards.log}"

"$GODOT" --headless --path . --import > import.log 2>&1

# One file (or part of one) stops inside its CI job's 30 minutes, so the summary below still prints; all of them run
# about two hours (Woodland's alone over one).
select=()
limit=9000
if [ -n "${1:-}" ]; then select=("-gselect=$1"); limit=1700; fi
if [ -n "${2:-}" ]; then select+=("-gunit_test_name=$2"); fi
timeout "$limit" "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/guards -gprefix=test_ \
  -gsuffix=.gd ${select[@]+"${select[@]}"} -gexit > "$LOG" 2>&1
status=$?
grep -E "\[Failed\]|rounds over|Passing Tests|Failing Tests" "$LOG" | head -40
if grep -qE "SCRIPT ERROR|Parse Error" "$LOG"; then
  echo "FAIL: script errors during the match guards (see $LOG)"; exit 1
fi
if [ "$status" -ne 0 ]; then
  echo "FAIL: match guards failed (exit $status, see $LOG)"; exit 1
fi
echo "PASS: match guards"

#!/usr/bin/env bash
# Unit tests (Gut, addons/gut): the test_*.gd under tests/unit, headless, in four parts of about the same time (CI1,
# WL9, WR1): part 1 the files before test_df (test_a* to test_dev*, test_bots.gd's whole bot matches among them), part 2
# from test_df to before test_g, part 3 from test_g to before test_rg (test_night*, test_play* and test_range* among
# them), part 4 the rest.
# Each part is a Godot run of its own with its own limit; CI runs them as three jobs side by side. Settings live in
# .gutconfig.json. Prints each failure as "FAIL: <file> <test>: <message>" and the totals, the whole output in
# unit-<part>.log; fails if any test fails or any script error is printed.
# Usage: tools/unit_tests.sh [1|2|3|4]  (all four parts in turn without one; GODOT=/path/to/godot to override)
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

if [ -z "${1:-}" ]; then
  failed=0
  "$0" 1 || failed=1
  "$0" 2 || failed=1
  "$0" 3 || failed=1
  "$0" 4 || failed=1
  exit $failed
fi
part="$1"
if [ "$part" != 1 ] && [ "$part" != 2 ] && [ "$part" != 3 ] && [ "$part" != 4 ]; then
  echo "FAIL: no unit test part '$part' (1, 2, 3 or 4)"; exit 1
fi
LOG="unit-$part.log"

# This part's files by name, byte by byte whatever the locale: part 1 sorts before test_df, part 2 from test_df to
# before test_g, part 3 from test_g to before test_rg, part 4 from test_rg on.
files=()
while IFS= read -r f; do
  files+=("res://$f")
done < <(find tests/unit -name 'test_*.gd' | LC_ALL=C sort | LC_ALL=C awk -v part="$part" '{
  name = $0; sub(/.*\//, "", name)
  at = name < "test_df" ? 1 : (name < "test_g" ? 2 : (name < "test_rg" ? 3 : 4))
  if (at == part) print
}')
if [ "${#files[@]}" -eq 0 ]; then
  echo "FAIL: no test files in unit test part $part"; exit 1
fi
list="$(IFS=,; echo "${files[*]}")"

# Always import first, so a new class_name or asset is known to the tests whatever ran before.
"$GODOT" --headless --path . --import > import.log 2>&1

# A part takes about six minutes on a cloud session (CI1, WL9); the limit only catches a hang, inside the CI job's 20
# minutes.
timeout 1080 "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir= -gtest="$list" > "$LOG" 2>&1
status=$?

# Each failed test with its file (GUT's run summary; a failed before_all or after_all has no test name), each script
# error with the file that was running or, before the first file starts (a test file that doesn't parse), the file its
# "at:" line names, each script that failed to load, and the file a run stopped in if it never reached its totals.
awk '
  /^res:\/\/tests\// { file = $0; test = "" }
  /^= Run Summary/ { summary = 1 }
  summary && /^- / { test = substr($0, 3) }
  summary && /\[Failed\]/ {
    sub(/^ *\[Failed\]: */, ""); print "FAIL: " file (test == "" ? "" : " " test) ": " $0
  }
  !summary && /SCRIPT ERROR|Parse Error/ { if (file != "") print "FAIL: " file ": " $0; else error = $0 }
  error != "" && /^ *at: / && match($0, /res:\/\/[^:)]*/) {
    print "FAIL: " substr($0, RSTART, RLENGTH) ": " error; error = ""
  }
  /Failed to load script "/ { split($0, q, "\""); print "FAIL: " q[2] ": failed to load (" q[4] ")" }
  /^Totals/ { totals = 1 }
  END { if (!totals) print "FAIL: the run stopped in " (file ? file : "its start") }
' "$LOG" | head -40
totals="$(grep -E "^(Tests|Passing Tests|Failing Tests)" "$LOG" | tr -s ' ' | paste -sd ' ' -)"
echo "part $part: ${totals:-no totals, the run never finished}"
if grep -qE "SCRIPT ERROR|Parse Error" "$LOG"; then
  echo "FAIL: script errors during the unit tests (see $LOG)"; exit 1
fi
if [ "$status" -ne 0 ]; then
  echo "FAIL: unit tests failed (exit $status, see $LOG)"; exit 1
fi
echo "PASS: unit tests, part $part"

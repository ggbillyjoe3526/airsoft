#!/usr/bin/env bash
# Unit tests (Gut, addons/gut): the test_*.gd under tests/unit, headless, in parts of about the same time (CI1, WL9,
# WR1, CI2). The parts split the files by name at BOUNDS below: part 1 is every file sorted before the first bound,
# part n every file from bound n-1 to before bound n, the last part the rest.
# Each part is a Godot run of its own with its own limit; CI runs them as jobs side by side. Settings live in
# .gutconfig.json. Prints each failure as "FAIL: <file> <test>: <message>" and the totals, the whole output in
# unit-<part>.log; fails if any test fails or any script error is printed.
# Usage: tools/unit_tests.sh [<part>|--parts]  (every part in turn without one; --parts prints how many there are;
# GODOT=/path/to/godot to override)
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

# Where each part after the first starts, by file name, byte by byte whatever the locale. Move a bound to even out the
# parts (CI2 timed them, docs/records/CI2.md); a new bound adds a part, which CI's unit matrix must list too.
BOUNDS=(test_bots_ test_df test_g test_mc test_rg test_torch_)
parts=$(( ${#BOUNDS[@]} + 1 ))

if [ "${1:-}" = "--parts" ]; then
  echo "$parts"; exit 0
fi
if [ -z "${1:-}" ]; then
  failed=0
  for p in $(seq 1 "$parts"); do
    "$0" "$p" || failed=1
  done
  exit $failed
fi
part="$1"
if ! [[ "$part" =~ ^[1-9][0-9]*$ ]] || [ "$part" -gt "$parts" ]; then
  echo "FAIL: no unit test part '$part' (1 to $parts)"; exit 1
fi
LOG="unit-$part.log"

# This part's files: from the bound before it (none for part 1) to before its own (none for the last part).
from=""
[ "$part" -gt 1 ] && from="${BOUNDS[part - 2]}"
to="${BOUNDS[part - 1]:-}"
files=()
while IFS= read -r f; do
  files+=("res://$f")
done < <(find tests/unit -name 'test_*.gd' | LC_ALL=C sort | LC_ALL=C awk -v from="$from" -v to="$to" '{
  name = $0; sub(/.*\//, "", name)
  if (name >= from && (to == "" || name < to)) print
}')
if [ "${#files[@]}" -eq 0 ]; then
  echo "FAIL: no test files in unit test part $part"; exit 1
fi
list="$(IFS=,; echo "${files[*]}")"

# Always import first, so a new class_name or asset is known to the tests whatever ran before.
"$GODOT" --headless --path . --import > import.log 2>&1

# A part took about 8 to 10 minutes on a cloud session (CI2); a slow CI runner takes half as long again (part 3 has run
# 15 minutes there). The limit catches a hang or a part grown too big, inside the CI job's 20 minutes.
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

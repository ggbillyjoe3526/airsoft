#!/usr/bin/env bash
# Every local gate CI runs, quietly: lint, the changelog notes, the wiki, the unit tests (in four parts, CI1), the smoke
# test and the licence notices; with --guards, the match guards too (about two hours, Woodland most of it; CI runs them
# as jobs of their own).
# Prints one line per gate and the failures; logs are in *.log. Exits non-zero if any gate failed.
# Usage: tools/check.sh [--guards]      (GODOT=/path/to/godot to override)
set -uo pipefail
GODOT="${GODOT:-godot}"
export GODOT
cd "$(dirname "$0")/.."
failed=0

gate() {
  local name="$1"; shift
  if out=$("$@" 2>&1); then
    echo "✓ $name"
  else
    echo "✗ $name"
    printf '%s\n' "$out" | grep -E "FAIL|ERROR|error|Failing|failed|::" | head -20
    failed=1
  fi
}

if command -v gdlint > /dev/null; then
  gate "gdlint" gdlint game tests tools
else
  echo "– gdlint not installed (pip install \"gdtoolkit==4.5.0\"); CI runs it"
fi
gate "changelog notes" tools/changelog.sh check
gate "wiki" python3 tools/wiki.py check
gate "unit tests, part 1" tools/unit_tests.sh 1
gate "unit tests, part 2" tools/unit_tests.sh 2
gate "unit tests, part 3" tools/unit_tests.sh 3
gate "unit tests, part 4" tools/unit_tests.sh 4
gate "smoke test" tools/smoke_test.sh
notices() {
  "$GODOT" --headless --path . -s res://tools/make_notices.gd > notices.log 2>&1 &&
    git diff --quiet -- THIRD_PARTY_NOTICES.txt ||
    { echo "FAIL: THIRD_PARTY_NOTICES.txt is out of date: commit the regenerated file"; return 1; }
}
gate "licence notices" notices
if [ "${1:-}" = "--guards" ]; then
  gate "match guards" tools/match_guards.sh
fi
# The unit tests' totals over the four parts.
awk '/^Tests /{t+=$2} /^Passing Tests/{p+=$3} /^Failing Tests/{f+=$3}
  END{if (t) printf "Tests %d Passing Tests %d%s\n", t, p, f ? " Failing Tests " f : ""}' unit-1.log unit-2.log unit-3.log unit-4.log 2>/dev/null
exit $failed

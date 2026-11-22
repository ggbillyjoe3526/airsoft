#!/usr/bin/env bash
# The review gate (pipeline/README.md › Pull request description). Passes for a draft, for a docs-only change (every
# changed file is Markdown and none is under data/), or when the description has the line
#   Review: critic Accept 8/8 · qa Pass · performance Pass     (only 8/8 is an Accept since 2026-11-22, owner)
# Reads PR_BODY, PR_DRAFT, BASE_SHA and HEAD_SHA (set by .github/workflows/review.yml).
# Usage: PR_BODY="$(cat body.md)" BASE_SHA=origin/main HEAD_SHA=HEAD tools/review_line.sh
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${PR_DRAFT:-false}" = "true" ]; then
  echo "Draft: the review gate waits until the pull request is marked ready."; exit 0
fi
files=$(git diff --no-renames --name-only "${BASE_SHA:?}...${HEAD_SHA:?}")
code=$(printf '%s\n' "$files" | grep -vE '\.md$' || true)
data=$(printf '%s\n' "$files" | grep -E '^data/' || true)
if [ -n "$files" ] && [ -z "$code" ] && [ -z "$data" ]; then
  echo "Docs only: no review agents needed."; exit 0
fi
line=$(printf '%s\n' "${PR_BODY:-}" | tr -d '\r' | grep -E '^Review:' | tail -1 || true)
if printf '%s\n' "$line" \
  | grep -qE '^Review: critic Accept 8/8 · qa Pass · performance Pass[[:space:]]*$'; then
  echo "PASS: $line"; exit 0
fi
echo "::error::This pull request changes code, scenes, config, assets or data, so its description needs the line 'Review: critic Accept 8/8 · qa Pass · performance Pass' (pipeline/README.md › Pull request description). Found: '${line:-nothing}'"
exit 1

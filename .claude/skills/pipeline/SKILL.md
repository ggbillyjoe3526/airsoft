---
name: pipeline
description: Run one task of the Airsoft FPS through the build pipeline (checks, QA, performance, critic, changelog, retries, merge), and the three review agents on any other code pull request. Use at the start of any build thread that has a task block in docs/TASKS.md, for a retry after a failed check or critic, and before marking any pull request that touches code ready.
---

# Running a task through the pipeline

The protocol is `pipeline/README.md`; this is the step list. You are the worker, on the model the task's `tier` names
(`docs/PROCESS.md` › Models); the rest are agents you spawn. Where the repo's agent names aren't offered as agent
types, spawn `general-purpose` with the definition's model (aliases only: `haiku`, `sonnet`, `opus`) and its body at
the top of the prompt. Tell every agent not to call `mcp__hearthbot__` tools. Hand grunt work (summaries, doc lookups,
reading logs, condensing output) to Haiku agents, several at once where it splits, each kept under 100k context
(`docs/PROCESS.md` › Models).

1. **Read** the task block and the contracts it names (grep, then ranges). Branch from the latest `origin/main`. The
   block's `status` and `attempts` change once, in the records commit (a status-only push re-runs CI).
2. **Build** (CLAUDE.md §7, §8) in typed GDScript: the touched GUT tests as you go (`tools/unit_tests.sh`, or one file
   through `gut_cmdln.gd`), then `tools/check.sh` (gdlint, every unit test, the headless smoke test, the licence
   notices) before QA. It prints failures and totals only.
3. **QA**: spawn `qa` with the task id and base commit. It commits its tests (`Agent: qa`) and its Pass or Fail report
   (`pipeline/out/qa-report.md`). On Fail, fix and run it again.
4. **Checks**: `tools/check.sh` again on the head QA left. A failed check: fix from the lines it printed (spawn
   `triage` only for a failure with no file and line in a long log), count an attempt, go to 2. No critic on a failed
   check.
5. **Review agents**, in this order, each told the task id, the head the checks passed on and `tools/check.sh`'s
   summary (a docs-only `tier: trivial` task gets `triage`'s diff summary instead, checked by you against the task):
   - `performance`; on Unexplained, again on Opus.
   - `critic` (Opus, high effort). On Retry (any failed check: only 8/8 is an Accept): `pipeline/README.md` › Verdict
     and attempts; fix only the failed checks and findings, go to 2.
   - A check only a changed acceptance criterion can pass: ask the owner at once on a decision card and stop there.
6. **Changelog**: spawn `changelog` with the task id and title, the pull request title, a player-words summary, the
   kind (new, changed, fixed, internal), the FEATURES heading or none, and the task's decisions. It writes one
   `changelog.d/<short-name>.md` note and edits `docs/FEATURES.md`; nobody edits `CHANGELOG.md` in a pull request.
   Then update the `docs/wiki/` page that describes what players will notice (`docs/wiki/README.md`) and run
   `python3 tools/wiki.py check`.
7. **Record**: a deliberate balance change first runs the headless balance figures for what it touches and quotes
   them. Write `docs/records/<id>.md` (format in `docs/records/README.md`: the review line, a row per attempt, the
   decisions, the known issues left), mark the task done where `docs/ROADMAP.md` lists it, delete its block from
   `docs/TASKS.md`, and copy the run's reports (never raw logs) to the shared files under
   `pipeline/runs/<id>/attempt-<n>/`.
8. **Ship**: merge `origin/main` in, run `tools/check.sh` once more if anything came in, push once with the work, the
   note and the record, and open the pull request (`<id>: …` title, the description and `Review:` line from
   `pipeline/README.md` › Pull request description), ready, not draft. Subscribe to it and merge it yourself once CI is
   green. Never mark ready, or merge, with a review agent unrun or failing.

## A `tier: fix` task

The same steps, lighter where nothing changes for the player (`docs/PROCESS.md` › The pipeline): the critic runs on
Opus as always, the changelog brief names no FEATURES heading unless the fix changes how
an existing feature behaves, `docs/PLAYTEST.md` gets a line only when the player sees a difference, and the record is
the review line, the attempt rows and one Decisions line (no Known issues section when it leaves none).

## Code pull requests outside the pipeline

A bug pass, an audit's fix, a content item or a tooling change with no task block still runs the review agents before
it leaves draft: `tools/check.sh`, then step 5's agents with "Task: none" in their brief, the changelog note (step 6),
and the `Review:` line in the description. A docs-only pull request skips the agents and writes `Review: docs only`.

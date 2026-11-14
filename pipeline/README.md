# The build pipeline

How a task gets built, checked, recorded and merged (owner's design, approved 2026-10-04; carried to Godot
2026-10-18). The agents are in `.claude/agents/`, the step list in `.claude/skills/pipeline/SKILL.md`, the open tasks
in `docs/TASKS.md` and each finished task's record in `docs/records/`. The checks are CI's
(`.github/workflows/ci.yml`) and, locally, `tools/check.sh`.

## Roles

| Role | Where | Edits |
|---|---|---|
| Coordinator | the project's persistent session, plus a planning thread per batch | `docs/TASKS.md`, `docs/ARCHITECTURE.md` › Contracts |
| Worker | the build thread itself (one task per thread); `.claude/agents/worker.md` only when a thread splits its task | the task's `touches`, tests, docs |
| QA | `.claude/agents/qa.md`; every code change; writes GUT tests and hunts bugs, Pass or Fail | `tests/` only (commit trailer `Agent: qa`); its report to `pipeline/out/qa-report.md` |
| Performance | `.claude/agents/performance.md`; every code change; Pass or Fail, ranks the causes when a run regresses | nothing (its report to `pipeline/out/performance.md`) |
| Triage | `.claude/agents/triage.md`; only for a failure `tools/check.sh` can't place | nothing (summaries under `pipeline/out/`) |
| Critic | `.claude/agents/critic.md`; every code change, last | nothing (`pipeline/out/critic.md`; its verdict goes in the task's record) |
| Changelog | `.claude/agents/changelog.md`; works from a player-words brief | one `changelog.d/<short-name>.md` note, `docs/FEATURES.md` |

Which model and effort each role runs on is policy: `docs/PROCESS.md` › Models. `pipeline/out/` holds a run's reports
and logs and is never committed.

Tiers: `core` is the simulation, physics, rendering, bots, navigation, audio engine; `ui` is menus, HUD, settings,
config, asset loading, docs; `trivial` is a one-constant change, a wording fix, a docs-only change; `fix` is a Beta
fix to what already exists (a bug, a balance or tuning value, a HUD or menu fault) that adds nothing new. A fix runs
every check and all three review agents like any code change, with a lighter record and change notes
(`.claude/skills/pipeline/SKILL.md` › A `tier: fix` task; why: `docs/PROCESS.md` › The pipeline).

**The review agents.** QA, performance and the critic review every change that touches code, scenes, config, assets
or gameplay data, inside the pipeline or not (the owner's rule, 2026-10-16: `docs/PROCESS.md` › Pull requests and
branches). A docs-only change skips them: every changed file is Markdown and none is under `data/`, whose tables the
game reads. CI's `review` check reads the pull request's `Review:` line (below).

Audits and major reviews are not pipeline tasks: they run in their own thread and hand their fixes on as tasks.

## The eight steps

1. **Plan**, once per batch: a planning thread turns the owner's list into task blocks (below), updates the Contracts
   section of `docs/ARCHITECTURE.md` when a contract changes, and asks the owner what needs asking before any build.
2. **Build**: one thread per task, on the tier's model, in typed GDScript. Two tasks run at once only when their
   `touches` don't overlap.
3. **QA**: GUT tests for every acceptance criterion, a bug hunt (edge cases, restart and teardown, focus, mouse
   capture, window modes, saves), then the whole suite.
4. **Performance**: a change to runtime code, scenes, assets, `data/` or `project.godot` gets a measured run (the
   headless bot match with `--perf`, this head against `origin/main`); a change with no runtime code is reviewed by
   reading. The agent reviews every code change (frame time, per-frame allocations, freed nodes and resources, the
   budgets) with a Pass or Fail verdict, and ranks the causes when a run regresses (owner, 2026-10-16).
5. **Triage**: `tools/check.sh` prints each failure with its file and line itself, so no model reads a raw log it can
   place; Haiku condenses only what it can't (a long log with no file and line, a `--perf` dump).
6. **Checks**: `tools/check.sh` (below). A failed check goes straight back to the worker with the evidence; the critic
   never sees it.
7. **Critic**: eight binary checks (below), only on green checks, reading the task block, the check summary, the
   contracts the diff touches, QA's and the performance agent's reports and the diff, rather than exploring the
   repository. Every code change gets it; a docs-only `tier: trivial` task gets a Haiku diff check instead. The
   verdict and what follows it are below.
8. **Retry**: only the failed checks and their evidence go back to the worker, and the attempt rule below applies.

Then the thread runs the changelog agent once the change is final (one `changelog.d/` note per pull request; never an
edit to `CHANGELOG.md`), updates the `docs/wiki/` page a player-visible change touches (`docs/PROCESS.md` › Pull
requests and branches), writes the task's record, `docs/records/<id>.md` (below), ships the work, the note and the
record in one push, and merges the pull request itself once CI is green (owner, 2026-10-16).

### The critic's eight checks

The table with its evidence rules is `.claude/agents/critic.md`; in short:

| # | Check | Blocking |
|---|---|---|
| 1 | Every acceptance criterion met, each with its diff line | yes |
| 2 | No contract in ARCHITECTURE › Contracts changed unless the block allows it | yes |
| 3 | No allocation per frame or per tick (`_process`, `_physics_process`, the sim step, per-hit code, handlers) | yes |
| 4 | The new GUT tests would fail without the feature | yes |
| 5 | Simulation apart from presentation, static types everywhere, no magic numbers, no hidden global state | yes |
| 6 | Feels like airsoft: the pillars, the tone, the fixed technical decisions, the assets policy | yes |
| 7 | Maintainability: small scripts and scenes, everything freed, UIDs kept in `.tscn`/`.tres` edits | no |
| 8 | Scope (the task and its stage) and the docs it affects, the wiki page included | no |

### Verdict and attempts

- **Accept** when every blocking check passes, at most one non-blocking check fails, and QA and performance both say
  Pass; the score is the checks passed, out of 8. Otherwise **Retry** with only the failed checks and their evidence.
- **Near miss.** A verdict one check short of Accept is re-run once before the task goes back when its failed check
  is a judgment (checks 5 to 8, or one of 1 to 4 decided by reading). A check failed on a measured number (a budget, a
  count) goes straight back, or to the owner when only a changed criterion can pass it: a re-run can't change a number.
- **Four attempts** per task: one build plus three targeted retries. After the fourth, checks green and at least 6 of
  8 with checks 1 and 2 passing is an **auto-accept** (owner, 2026-10-04; the `Review:` line reads `critic auto-accept
  <score>/8`), and every failed check goes to `docs/KNOWN_ISSUES.md`. Otherwise stop, keep the best attempt on its
  branch and report to the owner what failed and what each attempt tried.
- **Ask the owner at once** when a check can only pass by changing an acceptance criterion (a budget the build can't
  meet, a target his ruling set); don't spend attempts on it.

## The checks

The gates are CI's checks (`.github/workflows/ci.yml`, on every pull request and every push to `main`) and, locally,
`tools/check.sh`, which runs the same ones (in its own order: each unit run imports first, so order doesn't change the
result) and prints failures and totals only. Run it before QA, after QA's commit and before the push.

| Check | Runs | Passes when | Where |
|---|---|---|---|
| `lint` | `gdlint game tests tools` (gdtoolkit 4.5.0, settings in `gdlintrc`) | no findings | both |
| `unit` | `tools/unit_tests.sh`: every `tests/unit/test_*.gd` through GUT 9.7.1, headless | no failed test, no `SCRIPT ERROR` or `Parse Error` | both |
| `smoke` | `tools/smoke_test.sh`: imports the project, then runs it headless with `--smoke` (a bot plays a match once bots exist) | no script error, and the run prints `[smoke] ok` | both |
| `guards` | `tools/match_guards.sh`: every `tests/guards/test_*.gd`, whole bot matches over 16 seeds a field (MG1; CI jobs of their own, six for the night guards, WL10; locally `tools/check.sh --guards`, about two hours) | no failed test, no script error | CI; locally on request |
| `notices` | `godot --headless --path . -s res://tools/make_notices.gd` | `THIRD_PARTY_NOTICES.txt` is current | both |
| `changelog` | `tools/changelog.sh check` | every note in `changelog.d/` is a `### Title` and `- ` bullets | both |
| `review` | `tools/review_line.sh` on the pull request's description (`.github/workflows/review.yml`) | a docs-only change or a draft skips it; otherwise the `Review:` line gives `critic Accept` (or `auto-accept`), `qa Pass` and `performance Pass` | CI |

The `review` check re-runs on `edited` and `ready_for_review`, so it sees the final description; it has its own
workflow, so editing a description doesn't re-run Godot. The exit-time leak warnings at the end of a headless run
(`RID allocations ... leaked at exit`, `ObjectDB instances were leaked`) are known and are not script errors.

**Scope.** A task touches only its block's `touches`, plus tests, docs, its `changelog.d/` note and a folder's README;
the critic's check 8 judges it, and QA's commits touch only `tests/`.

**Performance runs.** The cloud container has no GPU: node counts, orphan nodes, static memory and script time per
tick are evidence there (script time only against a run on the same machine, so the agent runs `origin/main` too);
draw calls need a rendered run; frame times count only on the owner's hardware. `pipeline/perf-budget.json` holds the
budget lines, set from a measured Godot baseline; it has none yet, so performance judges against the owner's targets
(`docs/DECISIONS.md` › Performance budgets: Low holds 60 FPS on modern low-powered hardware, Ultra a 4K, 240 Hz class
PC, frame-time consistency and input latency over peak FPS) and against `origin/main`, and says "no baseline yet".
Budget lines are never raised to pass a check. **Frame-time gating is a manual owner step** on his own machines, before
a release tag.

**Balance figures.** Who wins (each side's share of rounds at every level and map) is a figure measured over many
seeded headless matches and judged against its band, never a pass or fail test: noise across seeds pushed figures
past their bands and cost re-measure loops in the browser game (M73, M74). What must never happen on any seed
(rounds settle, bots leave spawn, nobody falls through the floor, no friendly fire) stays a GUT test. A task that
changes balance on purpose quotes its figures in its record. `tools/balance.sh [filter]` writes the report to
`pipeline/out/balance-report.md` (many hours for every map: Normal on 32 seeds a map, Easy and Hard on 16, in
Elimination, Attack / Defend and Plant The Bomb; `SEEDS=n`, `LEVEL_SEEDS=n`, `LEVELS=normal,hard` and `MODES=plant`
for less).

**Content.** A new replica, part, map, mode or skin goes through the content toolkit (`docs/content/README.md`,
`.claude/skills/new-content/`), then this pipeline.

## Task block (`docs/TASKS.md`)

A worked example (indented here so `grep '^#'` lists no example as a task; in `docs/TASKS.md` each line starts at the
margin):

```
  ## M27 · Character mover without a per-tick allocation
  tier: core
  perf: required
  touches: game/sim/character_mover.gd, tests/unit/test_character_mover.gd
  contract: CharacterMover
  acceptance:
    1. ...
    2. ...
  status: open
  attempts: 0
```

`touches` lists files, or folders with a trailing slash. `perf` is `required` or `skip` (what the diff touches still
decides; `skip` only documents the intent). `tier` is `core`, `ui`, `trivial` or `fix` (Roles, above). `status`:
open · building · checks · critic · retry n · escalated. A task that lands leaves the file: the records step deletes
its block (no `done` blocks stay behind).

The pull request's title starts with the task id(s), `<id>: …` or `<id> + <id>: …`.

## Pull request description

Attribution block first (the project's rule), then:

```
Before: <what a player saw>

After: <what a player sees>

<one sentence on what the change does, if not obvious>

How: <a short paragraph>

Pipeline: attempts <n> · checks <lint ✓ unit ✓ smoke ✓ notices ✓ changelog ✓> · critic <score> · <link to the run folder>

Review: critic Accept <score>/8 · qa Pass · performance Pass
```

The `Pipeline:` line is for pipeline tasks only. The `Review:` line is on every pull request: a code one writes the
three verdicts exactly as above (after four attempts, `Review: critic auto-accept <score>/8 · qa Pass · performance
Pass`), and a docs-only one writes `Review: docs only`. CI's `review` check fails without it once the pull request is
out of draft. Each agent's blocking findings and how they were fixed go in the description's Verified section or the
task's record. Open the pull request ready once the agents passed; the thread merges it when CI is green.

## The task's record (`docs/records/<id>.md`)

One file per task, written by the thread in the records step (`docs/records/README.md` has the format):

- **Review line:** attempts, score out of 8, verdict and the critic's model, in one fixed short line.
- **Attempts:** one row per attempt: the date, the worker model, the checks' result, the critic's score, the retry
  reason, and the token totals the harness reports for each spawned worker (the Agent tool's completion notice
  carries one per worker). The build thread's own tokens show only when its session reports them, and the
  coordinator's never; the owner's usage page is the only complete view. Pass rate per tier is what decides whether a
  tier's model is right.
- **Decisions** the task made for itself, and the **known issues** it left (each also a row in
  `docs/KNOWN_ISSUES.md`). A `tier: fix` record may leave out the Known issues section when there are none.

The run's reports (never raw logs) are copied to the shared files under `pipeline/runs/<id>/attempt-<n>/`. The browser
game's records are in `legacy/browser/docs/records/`, read from git at the tag `0.1-dev.1`.

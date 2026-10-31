# Process

How work is planned, versioned, reviewed and shipped. `CLAUDE.md` holds the rules every session keeps; this file has
the detail. Read it by heading: grep for the one you need.

## Versioning

The number describes the product; Dev or Beta describes its development state. Never move to 0.2 just because a phase
ends, time passes or small improvements pile up.

### The restart

- **The project starts again at 0.1 Dev 1 (owner, 2026-10-18).** It is a new codebase, so its first build is
  0.1 Dev 1, tagged `0.1-dev.1`, even though the browser game already used that number.
- **The format stays exactly as it was.** Only the count resets: the stages, names and tags below are the ones the
  browser game used.
- **The browser versions are history, not a starting point.** The browser game's tags (`0.1-dev.1` to `0.1-dev.6`,
  then `0.1-beta.1`) lived only in the frozen browser repository, no longer on GitHub. This repository never imports
  them, and nothing here continues from Beta 1.
- **To tell them apart in writing,** say "the browser game's 0.1 Beta 1" for its builds. A bare version here always
  means a Godot build.

### The stages

| Version (git tag) | Meaning |
|---|---|
| 0.1 Dev 1, 0.1 Dev 2 … (`0.1-dev.1`, `0.1-dev.2` …) | **Dev**: building the game. Systems and content can be added, gameplay can change a lot, breaking changes are fine. Each build number is a full Dev release. |
| 0.1 Beta 1, 0.1 Beta 2 … (`0.1-beta.1` …) | **Beta**: starts when the owner calls 0.1 feature complete. Fixes, balance, performance, stability, UX and polish; no new features unless he asks for one. |
| 0.1 (`0.1.0`) | The first public release and the start of Early Access (owner, 2026-10-12): feature complete, light on content, released when the owner calls it a stable public product. |
| 0.1.1, 0.1.2 … | Fixes, performance, balance, small UX and accessibility changes, small content, maintenance. |
| 0.2, 0.3 … (`0.2.0` …) | A themed update (Replica, Modes, Maps, Progression, and any more the owner adds), each with its own Dev and Beta builds, in the order he picks. The next one shipped takes the next number. |
| 1.0 (`1.0.0`) | The full launch: the owner calls the game complete and Early Access ends (owner, 2026-10-12). |

### The rules that come with it

- **Names** are written "0.1 Dev 1" or "0.1 Beta 1", with no "v" (owner, 2026-10-05). Tags use the dotted forms
  (`0.1-dev.1`, never `0.1-dev-1`). A GitHub release is titled "Airsoft 0.1 Dev 1".
- **The order** (owner, 2026-10-18): "The first playable build will be tagged as "0.1 Dev 1". This will be followed
  by "0.1 Dev 2", "0.1 Dev 3", etc. Once out of Dev it will then move to "0.1 Beta 1", "0.1 Beta 2", etc and then
  finally on to 0.1." The first public release is named 0.1; its tag is `0.1.0`.
- **Only full releases are tagged** (owner, 2026-10-01). Playtests in between are plain commits; there are no letter
  checkpoints.
- **Only the owner creates tags.** Sessions never create, rename or move one. After he tags, the next pull request
  runs the release checklist (› Releases).
- **Dev until the owner calls it feature complete, then Beta** (owner, 2026-10-06). Beta adds no features unless he
  asks for one.
- **A full bug pass comes before every Beta tag,** and the owner is reminded to clear his checklist before he tags.
  Neither starts automatically.
- **The number is the product, the stage is its state.** Milestones and critic cycles give development granularity;
  they don't each get a version.
- **The build shows its version** (owner, 2026-10-18). The release workflow writes the tag's version into the build
  before Godot exports, so the title screen names the tag it was built from. Between releases `config/version` names
  the build being made: the release checklist's pull request sets it to the next name (owner, 2026-10-30).

## Placing work

- **Dev or Beta.** New systems, modes and content (maps, replicas, menus, art) are Dev. Fixing, balance, performance,
  stability, UX/QoL, polish and final tuning are Beta. During Dev, note Beta-type work in `docs/KNOWN_ISSUES.md`,
  unless it blocks Dev work.
- **What 0.1 is.** The browser game's 0.1 as the owner's rulings define it (owner, 2026-10-18): `docs/ROADMAP.md` ›
  What 0.1 is. 0.1 Dev 1 is the core slice (Depot, the AEG and GBB Pistol, bots, Elimination); the rest of 0.1 follows
  in later Dev builds. 0.1 is feature complete; its content can be light (owner, 2026-10-12).
- **Later versions.** Every later feature has a themed update (`docs/ROADMAP.md` › Early Access: the themed updates;
  owner, 2026-10-05 and 2026-10-12). Don't build them during 0.1 unless the owner pulled them in. While 0.1 is in
  Dev, a system it needs goes there; new content (replicas, attachments, items, modes, maps, things to earn) goes to
  its update.
- **Fun first.** Move on only when the previous part is actually fun. Validate before expanding.
- **No multiplayer.** None is planned (owner, 2026-09-30; confirmed 2026-10-03: absolutely none). No networking code,
  servers or matchmaking.
- **Ideas.** Future ideas (modes, clans, community scenarios and so on) go in `docs/IDEAS.md`. Don't implement them
  unless asked.

## Releases

**A release is the owner's tag.** He pushes it (such as `0.1-dev.1`); `.github/workflows/release.yml` writes that
version into the build, exports Windows and Linux, plays the headless smoke match on the Linux build, builds the
Windows installer, installs it on a Windows runner, plays the same smoke match on the installed game, uninstalls it,
and publishes a GitHub pre-release titled "Airsoft <name>" with notes from the changelog. Sessions never create tags.
A pull request that touches the release pipeline, or Actions › Release › Run workflow, runs it all as a dry run that
publishes nothing (the downloads are in the run's Artifacts).

**After the owner tags a release** (owner, 2026-10-03), the docs move to the new tag without being asked. The first
pull request after a new tag (or a small docs-only one, if no other work is open) updates, to match the owner's
release description:

1. **The changelog:** run `tools/changelog.sh release "<name>"` (for example `"0.1 Dev 1"`). It folds the notes in
   `changelog.d/` into `CHANGELOG.md` under `## <name> (date)` and deletes them. Read the section over before
   committing it.
2. **`README.md`:** the title, the intro paragraph and its "New since …" paragraph, the download link (the release
   page, `.../releases/tag/<tag>`, with the Windows installer, the Windows zip and the Linux zip) and the
   "What's in …" section.
3. **`docs/ROADMAP.md`:** the last tag under Where we are, and the Builds table.
4. **Any other "latest release" mention:** run
   `grep -rn "dev\.[0-9]\|beta\.[0-9]\|Dev [0-9]\|Beta [0-9]" README.md docs/ CLAUDE.md --exclude-dir=records`
   and update each line that names the previous release as current (history and policy examples stay as they are).
   The title screen's version needs nothing at release: the release workflow writes it. Then set `config/version` in
   `project.godot` to the next name (after "0.1 Dev 1", "0.1 Dev 2"), so a source run names the build being made.
5. **The release itself:** check the GitHub release has the three downloads and that the installed game's title
   screen names the new tag. If the Release run in Actions failed, its log says why.
6. **The archive check:** run `wc -c docs/*.md`. A live doc over about 50 KB gets its finished parts moved word for
   word to `docs/archive/<release>/` (the folder is named for the stage just closed, such as `0.1-dev/`; make it if it
   is missing), the full wording of anything shortened goes there too, and `docs/archive/README.md` names the folder.
   Fix every `›` heading reference that pointed at moved text (`grep -rn "<heading>" . --exclude-dir=archive`).

## Pull requests and branches

- **Every change is a pull request** (owner, 2026-10-02) from a new branch made from the latest `main`, one per
  milestone or batch. **Never push to `main`.** One pull request may hold several commits.
- **Review agents on every code change** (owner, 2026-10-16). A pull request that touches code, config, assets or
  gameplay data is marked ready only once the critic, QA and performance agents (`.claude/agents/`) have run and
  passed, and its description's `Review:` line gives their verdicts (`pipeline/README.md` › Pull request description);
  CI checks the line. This holds outside the pipeline too. Docs-only pull requests skip them.
- **Changelog notes.** A pull request with a change players or the owner will notice adds one new file,
  `changelog.d/<short-name>.md`, written by the changelog agent: a `### Title` line, then `- ` bullets in player words
  (`changelog.d/README.md`). Never edit `CHANGELOG.md` in a pull request (parallel pull requests would conflict); CI
  runs `tools/changelog.sh check`.
- **The wiki is part of done** (owner, 2026-10-25). A pull request with a change players will notice (a mechanic,
  rule, screen, setting, control, map, mode, bot behaviour or roadmap step) updates the `docs/wiki/` page that
  describes it in the same pull request, in player words (`docs/wiki/README.md`). Table numbers come from the data through
  `tools/wiki.py`'s markers, never typed in, and Patch Notes is generated from `changelog.d/`. CI runs
  `python3 tools/wiki.py check` (links, sidebar, dev content kept to Roadmap and In development, every public item
  named) and warns when a changelog note comes without a wiki change; `.github/workflows/wiki.yml` publishes the pages
  to the GitHub wiki on every merge to `main`. Docs-only and internal changes need no wiki edit.
- **Who merges.** Every pull request is merged by its own thread, never by the owner (owner, 2026-10-16: "You should
  be merging. Not me"). A code pull request merges once CI is green and the review agents passed (its `Review:` line);
  a docs-only one once CI is green.
- **Branches** (owner, 2026-10-01). `main` holds the latest stable release.
  - **Now (the 0.1 cycle):** work reaches `main` only through merged pull requests, and the tagged commits on `main`
    are the releases.
  - **Later (about when 0.1 is done; the owner decides when):** day-to-day work moves to a development branch, a
    build ready for testing merges into `beta`, and once tested it merges into `main` and is tagged. From then on,
    never push unreleased work to `main`.

## Sessions

- **Start.** Read the task block or brief and project memory, then only the files the task names. Grep `docs/` for
  anything else; never read a whole big doc. Fetch first: a stale clone shows old work as next. Run
  `git ls-remote --tags origin`: a tag newer than the one `README.md` names means the release checklist is due.
- **Godot in the cloud.** Cloud sessions get Godot from the session hook, `.claude/hooks/session-start.mjs`, which
  installs the version named by `GODOT_VERSION` in `.github/workflows/ci.yml` as `godot` on the path. Export templates
  are not installed: CI builds the releases.
- **One task per thread** (owner, 2026-10-02 and 2026-10-06). After a merge, follow-on work starts a fresh thread
  with a short brief.
- **The project chat carries results, blockers and decisions only** (owner, 2026-10-06). A thread replies when it has
  a result, hits something only the owner can unblock, or needs his decision; progress goes in its status checklist.
  The coordinator posts the same three in the project chat (plus the one-line receipt for a new ask), never a
  per-milestone progress line.
- **Quiet output** (owner, 2026-10-02 and 2026-10-06; usage runs out fast). Every command's output is filtered to
  failures and totals: `tools/check.sh` prints only those, and any other command is piped through a filter that does.
- **Pausing.** When the owner says stop or usage is running out, commit and push the work in progress on its branch
  (never patch folders) and say where it stopped.
- **Shared files stay lean** (owner, 2026-10-12 tidy-up: 1.1 GB down to 192 MB, most of it raw test dumps and PNG
  concept pictures). Copy a run's reports there, never raw test output or logs. Save review pictures as JPEG, not PNG.
  Once the work merges, keep the approved pictures and delete the rest of their folder.
- **`docs/HANDOFF.md`** is a short "now": what is being built, what is next, what waits on the owner. The planning
  thread rewrites it once per batch (replace it, don't append). Engine facts live in `docs/ARCHITECTURE.md` and the
  folder READMEs, not there.

## Models

Which model runs which job (owner, 2026-10-08 and 2026-10-23); the roles themselves are in `pipeline/README.md` › Roles. A thread
never changes a model or an effort level unless the owner asks.

- **Opus 5.5 for the coordinator, the planning thread and `tier: core` tasks,** each bug pass (`BP<n>`) and the fixes an
  audit hands on among them. Opus threads run at Extra effort (`xhigh`), the owner's project setting; a `worker` agent a
  thread splits its task to inherits the thread's model at high effort. The critic always runs on Opus (owner,
  2026-10-23), and the performance agent does when a regression stays unexplained.
- **Sonnet 5.5, medium, for `tier: ui`, `tier: trivial` and `tier: fix` tasks** (a fix in a core system, such as the
  simulation, physics or bots, on Opus), QA, and the other performance runs.
- **Haiku 5.5, low, is the cheap, fast "minion army" for grunt work** (owner, 2026-10-23): summaries, web and doc
  lookups, reading logs, triage, the changelog, simple debugging and trivial questions, and the diff check on a
  docs-only `tier: trivial` task. Run several at once where the work splits, and keep each one under 100k context (a
  narrow brief, named files and line ranges, short reports), so the Opus and Sonnet contexts stay clean for reasoning.
- **Fable 5.1 only with the owner's explicit approval, asked for each time.** It costs far more than Opus, so it is
  proposed only where it would do significantly better: an audit, or a review of a major architectural change, a
  major redesign, or how a new system fits into the project. The ask names the job, why Opus is not enough and the
  effort level; nothing starts on Fable until he says yes. A Fable thread writes a report and changes no code; what it
  asks for is built as tasks on the models above.

## Decisions and records

- **Ask when unsure** (owner, 2026-10-02). If you're unsure about a design decision, ask the owner before acting. For
  small details that are easy to change later, choose a sensible default, note it with a one-line reason, say which
  you chose, and keep going.
- **Where a decision goes.** A task's own default or tuning value goes in its record, `docs/records/<id>.md`
  (`docs/records/README.md`). An owner ruling, or a rule every later task must follow, goes in `docs/DECISIONS.md`.
- **Before changing a number** carried from the browser game, read why it is what it is: the old records and
  decisions are in `legacy/browser/docs/` until 0.1.
- **Known issues.** What a task leaves open is a row in `docs/KNOWN_ISSUES.md`, named in its record too. A pull
  request that fixes a row deletes it.
- **Ask the owner at once** when a check can only pass by changing an acceptance criterion (a budget the build can't
  meet, a target his ruling set). Don't spend attempts on it.

## Bug pass

A full bug pass plus a `docs/KNOWN_ISSUES.md` sweep is a standing practice (owner, 2026-10-04), not a one-off.

- **When.** After each batch of feature pull requests merges and before the owner's playtest: fresh features have had
  no real play yet, and the playtest then starts on a clean build. The coordinator reminds the owner with one line in
  the project chat; the pass starts only when he says go (it costs usage).
- **What.** Play every mode in a built game, review the code added since the last pass, fix what can be fixed (a test
  for each), and keep the rest logged in `docs/KNOWN_ISSUES.md` with why.
- **How.** It runs as a pipeline task: `BP<n>` in `docs/TASKS.md`, `tier: core`, the gates and the Opus critic. Two
  parallel review agents (for example UI and input; pool, Loadout and maps) read the new code: in the browser game
  they found bugs that play didn't show. The autoplay bot (`--autoplay`) plays headless matches of every mode and map
  with fixed seeds.
- **Balance.** Run the balance report (bots against bots, headless, over many seeds; `pipeline/README.md`) and copy it
  to the run folder. Each figure **outside** its band by two standard errors or more is a balance issue: fix it in the
  pass or log it in `docs/KNOWN_ISSUES.md`. One **outside, within noise** is re-measured on more seeds before anyone
  acts; one **near an edge** is noted. A task that changes balance on purpose runs its own filter and quotes the
  figures in its record: figures are reported, never asserted, since noise across seeds made pass/fail bands cost
  re-measure loops.
- **Seeds.** The headless bot guards keep only what must never happen, but a fix that touches movement or materials
  can still fail one seed. Re-measure over 16 seeds before changing a threshold.

## Dev tools

None of these reach the shipped game except the perf overlay. Run them from the repository root.

- **The gate:** `tools/check.sh` runs every local gate (gdlint, the unit tests, the headless smoke test, the licence
  notices check) and prints failures and totals only. Run it before every push.
- **Its parts:** `tools/unit_tests.sh` (GUT 9.7.1, tests in `tests/unit/test_*.gd`, in four parts of about the
  same time: `1` the files before `test_df`, `2` those before `test_g`, `3` those before `test_rg`, `4` the rest, all
  four in turn without one; CI runs them as four jobs side by side; a failure prints as `FAIL: <file> <test>: <message>`), `tools/smoke_test.sh`
  (imports the project, a bot plays a headless match, any script error fails) and `gdlint game tests tools`
  (gdtoolkit 4.5.0).
- **Licence notices:** `godot --headless --path . -s res://tools/make_notices.gd` regenerates
  `THIRD_PARTY_NOTICES.txt`; CI fails if it is stale.
- **The perf overlay:** **F3** in any build shows the frame rate, frame time, draw calls and nodes, and in a match its
  seed, your position and the entity count. **F4** draws every BB's recent flight and **F5** the characters' hit
  volumes in the world; all three keys are reserved (they can't be rebound).
- **Debug flags** (planned; they come with the systems they drive). Godot passes them after `--`, as in
  `godot --path . -- --autoplay --seed=1234`:
  - `--autoplay`: a bot plays in your place and logs what it does. The smoke test uses it.
  - `--seed <n>` (or `--seed=<n>`; built, DV1): plays the match with that seed, so a reported seed replays it. A bad
    value is ignored with a warning.
  - `--perf`: the perf overlay from the start, a log line every 2 s and a summary at exit.

## The pipeline

Every task runs through the build pipeline (owner's design, 2026-10-04). `pipeline/README.md` is the protocol: the
roles, the eight steps, the gates, the critic's verdict, the four-attempt rule and the record.
`.claude/skills/pipeline/SKILL.md` is the step list a build thread follows, `docs/TASKS.md` the open tasks with their
acceptance criteria, and `.claude/agents/` the agents (worker, qa, performance, triage, critic, changelog).

- **The gate is `tools/check.sh`,** the same checks CI runs.
- **Three review agents on every code change** (owner, 2026-10-16): the critic (the quality bar), QA (bugs) and
  performance (frame time, allocations, freeing nodes and resources, budgets). A docs-only `tier: trivial` task is
  accepted by green gates plus a Haiku diff check.
- **Four attempts, then auto-accept or the owner** (owner, 2026-10-04): a task stops after four, so a hard one reaches
  the owner instead of looping.
- **The owner's playtest wins.** The critic cannot play the game: it lists checks for the owner
  (`docs/PLAYTEST.md`), whose playtest overrides it.
- **Records.** Each task writes `docs/records/<id>.md` (format in `docs/records/README.md`).

## Writing docs

The owner's rule (2026-10-05): tidy and consistent, easy to read, as simple as the subject allows, as long as it needs
to be and no longer, technical detail only where it's needed, nothing critical lost.

1. **Start with the point.** Under the `#` title, one or two sentences: what the file is for and who reads it. No
   "written on" or "updated for" lines: git keeps that.
2. **Current state only.** Live docs say how things are now. Replace superseded text instead of appending to it (no
   "since M43 …, since M55 …" chains). History goes to `docs/archive/`; when a live doc grows past about 50 KB, move
   its finished parts there.
3. **Headings.** One `#` title, `##` sections, `###` only when a section really has parts. Sentence case, plain words,
   no milestone ids or dates. An id (M44, FA6, audit SIM-17) may end a line in brackets when someone may need to trace
   it.
4. **Lists and tables.** Bullets for facts, numbered lists for steps, tables for items compared on the same columns.
   Scannable list items get a bold lead-in: `- **Name.** Text.` One idea per bullet.
5. **Sentences.** Short, active, present tense, British spelling, plain words. No filler ("note that", "basically",
   "in order to"). No em-dashes: use a colon, a comma or a full stop. "·" is fine as a separator in short labels.
6. **Names.** Menu paths with ›, e.g. `Settings › Graphics › Quality`. Code, files, commands and config keys in
   backticks. Dates as 2026-10-08. An owner ruling is tagged `(owner, 2026-10-07)`.
7. **Timings carry their date** (audit CORE-13): "about 2 minutes (2026-10-08)". The pull request that changes the
   suite or the gate refreshes them.
8. **Wrap** prose and list items at 120 columns. Table rows don't wrap; keep cells short.
9. **Cross-references** by relative path, with › for a heading: `docs/PROCESS.md › Releases`.

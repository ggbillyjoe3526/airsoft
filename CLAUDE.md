# Airsoft FPS: project guide for Claude

You are the lead engineer and development partner on an original first-person airsoft shooter, an installable desktop
game built with Godot and Blender. You build it yourself, using code plus free, properly licensed tools and assets.
Treat this as a real game project, not a coding exercise.

Keep this file short and current. Detailed design lives in `docs/`. Update those docs when decisions change.

## 1. The Game in One Paragraph

A first-person, round-based team shooter inspired by Counter-Strike and Valorant, built entirely around the feel and
culture of **recreational airsoft**. Players use replicas that fire visible BBs, get eliminated by a single hit, call
their hit, and walk off. It should feel playful, physical, tactical, and slightly chaotic: never grimdark, never a
military simulator. Fun beats realism whenever they conflict.

## 2. Design Pillars (test every feature against these)

1. **It feels like airsoft.** BBs with visible travel and arc, magazines, hop-up, hit calling, fields and CQB arenas,
   gear.
2. **Replicas feel like toys, not firearms.** Light recoil, plasticky mechanical sounds, BB puffs instead of blood, no
   gore.
3. **Spaces matter.** Maps are built for angles, cover, routes, and positioning.
4. **Fun beats simulation.** When realism hurts responsiveness, readability, balance, or performance, choose good game
   design.
5. **Its own identity.** Before copying a CS/Valorant mechanic, ask: does airsoft suggest something better?

## 3. Fixed Technical Decisions

These are decided. Do not revisit them without asking the owner.

| Area | Decision |
|---|---|
| Platform | Installable desktop game: Windows first, Linux from CI, macOS later. Not a web game (owner, 2026-10-18). |
| Engine | Godot **4.7.2** stable (standard, not .NET), Forward+ renderer. The version is pinned in `project.godot` (`config/features`) and `GODOT_VERSION` in `.github/workflows/ci.yml` and `release.yml`; they change together, and only with the owner |
| Language | GDScript with static typing everywhere (owner, 2026-10-18) |
| Models | Blender, exported as glTF (`.glb`); build scripts in `tools/blender/` |
| Physics / collision | Jolt (built into Godot), behind the simulation's `WorldQuery` and `CharacterMover` |
| Bot navigation | The layered nav grid ported from the browser game (owner, 2026-10-18) |
| Audio | Godot's audio buses and `AudioStreamPlayer3D`; sounds rendered from the browser game's recipes first, CC0 later |
| Input | Godot's input map, mouse captured in play, keyboard and mouse |
| Tests | GUT 9.7.1 (`addons/gut/`, tests in `tests/unit/`), run headless by `tools/unit_tests.sh`; gdlint for style |
| Multiplayer | **Out of scope.** Single-player vs bots only (owner, 2026-09-30, confirmed 2026-10-03: absolutely none). |

### Simulation structure

- Run gameplay on a **fixed 60 Hz simulation** (`_physics_process`), separate from rendering.
- Players and bots both act through the same **command interface**; bots are just another controller.
- Keep game state in plain classes separate from scene nodes; nodes read state and events, never own the rules.
- Keep randomness seedable.

Do **not** build networking code, servers, or matchmaking.

## 4. Assets Policy

- Start with **greybox geometry**. Gameplay first, art second.
- Make what you can: Blender models, procedural materials, rendered or synthesised sounds.
- Downloaded assets are **CC0 or clearly permissive** only (Kenney, Quaternius, Poly Haven, ambientCG, CC0 sounds).
- Record every external asset in `docs/ASSETS.md`: name, source URL, license, author.
- Keep assets lean: glTF, compressed textures, and an install size budget the owner sets.
- Do not use real brand names or trademarked replica designs.
- Add-ons, tools and assets follow `docs/ASSETS.md` › Adding a library or tool (named source, pinned version, licence
  file, no GPL or LGPL code in the game, dev code never ships) and never anything on its Do not use list (owner,
  2026-10-18). Every export ships Godot's licence and every add-on's, shown from a credits screen.

## 5. Core Mechanics

The browser game's tuned rules are the starting point. Its code, tests and docs (`legacy/browser/`, removed
2026-11-05 at the owner's word) are read from git at the tag `0.1-dev.1` (`legacy/README.md`), and
`legacy/browser/docs/handover/SALVAGE.md` there maps each system to its Godot home. Tune them through play.

- **BBs** are real projectiles, not hitscan: visible travel, gravity, hop-up lift that flattens the arc over mid-range,
  then drops off; slight spread per replica. Ballistics logic is pure and unit-tested.
- **Hits and hit calling** (the signature mechanic): one BB hit eliminates, no health bars. On hit: a distinct "tick",
  a hit indicator, a raised hand and "HIT!". Eliminated players walk off to the dead zone, can't shoot and can't be
  targeted, and can spectate. Bots always call their hits honestly; the game enforces it.
- **Replicas:** stats are data (`data/stats.md`, `data/pool.md`), never hard-coded. They differ in loading, cycling,
  sound and handling, never damage.
- **Movement:** walk, sprint, crouch, lean, vault and a limited jump. Sprinting disables shooting briefly. Responsive,
  grounded, no wall-running or superhero movement.

## 6. Roadmap, Versions and Pull Requests

The plan and build status: `docs/ROADMAP.md`. Versioning, branches, pull requests, the release checklist and the bug
pass: `docs/PROCESS.md` (grep the heading you need). The rules every session keeps:

- **Versions restart at 0.1 Dev 1 (owner, 2026-10-18)** in the browser game's format: "0.1 Dev 1", "0.1 Beta 1" (no
  "v"); tags `0.1-dev.1`, `0.1-beta.1`, `0.1.0`. The sequence is Dev 1, Dev 2 … then Beta 1, Beta 2 … then 0.1
  (tagged `0.1.0`), which opens Early Access (owner, 2026-10-18); themed updates (Replica, Modes, Maps, Progression)
  follow up to 1.0. The browser game's own 0.1 Dev 1 to 0.1 Beta 1 are history in the old repository.
- **The owner creates tags.** Don't create, rename or move them. After he tags, the release checklist is due in the
  next pull request.
- **Never push to `main`.** Every change is a pull request from a new branch made from the latest `main`. Every pull
  request is merged by its own thread once CI is green and, for code, the review agents passed. The owner doesn't
  merge.
- **Three review agents on every code change:** critic (the quality bar), QA (bugs) and performance (frame time,
  allocations, freed nodes and resources, budgets), in `.claude/agents/`. A pull request touching code, scenes,
  config, assets or gameplay data is marked ready, and merged, only once all three passed and its `Review:` line says
  so. Docs-only pull requests skip them.
- **Placing work:** new systems, modes and content are Dev; fixing, balance, performance, stability, UX/QoL, polish are
  Beta. Don't build later-version features unless the owner pulled them into 0.1.
- **The old browser repository** (once `ggbillyjoe3526/Airsoft`, frozen at `0.1-beta.1`) is no longer on GitHub; that
  name now opens this repository (renamed from Airsoft-Next to `airsoft`). Its code, once copied to `legacy/browser/`,
  was removed on 2026-11-05 (owner) and is read from git at the tag `0.1-dev.1`.
- Future ideas go in `docs/IDEAS.md`; don't implement them unless asked.

## 7. How to Work

**Start of a session:** read the task block or brief and project memory, then only the files the task names. Fetch
first; grep `docs/` for anything else. Details in `docs/PROCESS.md` › Sessions.

**For each substantial change,** state briefly **Goal**, **Approach** (files, scenes and systems) and **Risks**. Then
implement, then **verify**: the headless tests, an export build and the gates; report what changed, what was tested,
what passed, what failed and what's incomplete. Never claim something works if you haven't verified it. For what you
can't verify (how it feels to play), tell the owner exactly what to test.

**Token and context hygiene** (owner, 2026-10-02 and 2026-10-06; usage runs out fast):
- **One task per thread.**
- **Grep first, then read ranges.** Big docs are read by heading, never whole; the old browser game is grepped in git
  at the tag `0.1-dev.1`.
- **Quiet output:** filter every command's output to failures and totals.
- **One push when the gates are green:** records in the same push, no separate status pushes, no pull request title
  edits.
- **Ask the owner at once** when a check can only pass by changing an acceptance criterion.
- Screenshots only when you need to see something.
- Agent reports stay short: QA, performance and the critic about 30 lines, triage 15.
- **Models** (`docs/PROCESS.md` › Models): Opus for code, design, the critic and bug passes; Sonnet for UI, QA and
  performance; Haiku 5.5 as the cheap "minion army" for grunt work (summaries, lookups, logs, triage, changelog), many
  in parallel, each under 100k context (owner, 2026-10-23).

**Design decisions:** if unsure, ask the owner before acting. For small details that are easy to change later, pick a
sensible default, note it with a one-line reason in the task's record (`docs/records/`), or in `docs/DECISIONS.md` if
it is an owner ruling or binds later tasks, and keep going.

## 8. Code Standards

- Small, focused scripts and scenes. No giant classes, no autoload dumping grounds, no hidden global state.
- Static types on every variable, parameter and return.
- Data-driven configuration for replicas, maps, bots and tuning values (data tables and typed resources). No magic
  numbers in gameplay code.
- Separate simulation (pure logic) from presentation (scenes, audio, HUD).
- Free what you create; no orphan nodes, leaked resources or duplicate signal connections. No per-frame allocations in
  hot loops.
- Profile before optimising.
- A debug overlay (FPS, entity count, toggleable hitbox and BB-path display) early.
- Fix root causes, not symptoms. Classify technical debt as fix now / document / can wait. Don't endlessly refactor.
- No new add-ons without a clear reason stated in the change summary.

## 9. Repository Hygiene

- Commit-sized changes with clear messages. Don't touch unrelated files. Never commit secrets, export builds or the
  `.godot/` cache; do commit `.import` and `.uid` files. When editing `.tscn` or `.tres` text, keep UIDs, resource ids
  and node paths. Keep `README.md` current with setup and run instructions.
- Keep the docs brief and current, in the house style (`docs/PROCESS.md` › Writing docs): VISION, ARCHITECTURE,
  DECISIONS, ASSETS, IDEAS, KNOWN_ISSUES, PROCESS, HANDOFF in `docs/`. Each task's record goes in `docs/records/`,
  finished history in `docs/archive/`.
- Each pull request adds one note, `changelog.d/<short-name>.md`, written by the changelog agent; never edit
  `CHANGELOG.md` in a pull request (parallel pull requests would conflict). `docs/FEATURES.md` is kept by the same agent.
- **The wiki** (owner, 2026-10-25): a change players notice updates its page in `docs/wiki/` in the same pull request
  (`docs/wiki/README.md`). Tables and Patch Notes are generated from the data and the notes; the Wiki workflow
  publishes to the GitHub wiki on every merge. No dev content outside Roadmap and In development; robots never.

## 10. Tone Check

The game should feel: physical, playful, tactical, readable, approachable, social, and authentic to airsoft.
It should not feel: grimdark, gory, militaristic, simulation-heavy, bloated, or esports-first.

The goal is a genuinely fun airsoft game, not an impressive codebase.

## 11. The Pipeline

Every task runs through the pipeline: `pipeline/README.md` (the protocol, the critic's verdict and the attempt rule),
`.claude/skills/pipeline/SKILL.md` (steps), `docs/TASKS.md` (open tasks), `.claude/agents/` (agents).

## 12. Repo-Specific

- **Checks:** `tools/check.sh` runs every local gate (gdlint, the changelog notes, the GUT unit tests, the headless
  smoke test, the licence notices); CI runs the same on every pull request. Output is failures and totals only.
- **Cloud sessions** get the pinned Godot from `.claude/hooks/session-start.mjs`, as `godot` on PATH. Export templates
  are not installed; CI builds releases.
- **Releases:** the owner's tag starts `.github/workflows/release.yml` (Windows installer and zip, Linux build,
  notes from the changelog). Never create a tag. Never change the installer's `AppId`.
- **Data tables** in `data/*.md` are read at start with `FileAccess`; an unreadable cell keeps its built-in value and
  warns. Every export preset includes `data/*` as non-resource files.
- **Reading big files:** a hook stops whole-file reads over 40 KB; grep, then read with offset and limit.
- **Exit-time leak warnings** (`RID allocations ... leaked at exit`, `ObjectDB instances were leaked`) at the end of a
  headless run are known and are not script errors.

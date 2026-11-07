# Development

How Airsoft is built, for anyone reading the code, building it from source or testing it. The repository is
[ggbillyjoe3526/airsoft](https://github.com/ggbillyjoe3526/airsoft); its
[README](https://github.com/ggbillyjoe3526/airsoft#readme) has the full setup.

## The stack

| Area | Choice |
| --- | --- |
| Engine | Godot <!-- wiki:godot --> (standard, not .NET), Forward+ renderer, pinned in `project.godot` |
| Language | GDScript, statically typed everywhere |
| Physics | Jolt, built into Godot |
| Models | Blender, exported as glTF (`.glb`) by scripts in `tools/blender/` |
| Tests | GUT unit tests in `tests/unit/`, gdlint for style |
| Platforms | Windows first, Linux built in CI, macOS later |

The game runs on a fixed 60 Hz simulation, separate from drawing. Players and bots act through the same commands, so
a bot is just another controller. Game state lives in plain classes; scene nodes only read it.

## Building and running

1. Install Godot <!-- wiki:godot --> (standard build).
2. Clone the repository and open `project.godot`, or run `godot --path .`.
3. `tools/check.sh` runs every local check: gdlint, the changelog notes, the unit tests, the headless smoke test, the
   licence notices and this wiki.

Launch options, given after `--`:

- `-- --seed 1234` replays the exact same match (every Play otherwise starts a fresh random seed; the pause menu and
  F3 show it).
- `--rendering-method gl_compatibility` starts on the simpler renderer, as the safe graphics shortcut does.

F3, F4 and F5 show the performance readout, BB paths and hit areas ([Controls](Controls#keys-you-cant-change)).

## The data tables

Tuning lives in Markdown tables the game reads when it starts, so a change needs no code. A cell the game can't read
keeps its built-in value with a warning.

| File | What it holds |
| --- | --- |
| [`data/pool.md`](https://github.com/ggbillyjoe3526/airsoft/blob/main/data/pool.md) | Every replica, part and power source: IDs, names, what fits what, public or dev |
| [`data/stats.md`](https://github.com/ggbillyjoe3526/airsoft/blob/main/data/stats.md) | How each of them shoots and handles |
| [`data/levels.md`](https://github.com/ggbillyjoe3526/airsoft/blob/main/data/levels.md) | Levels, unlocks and XP |
| [`data/maps.md`](https://github.com/ggbillyjoe3526/airsoft/blob/main/data/maps.md) | Which maps are listed, public or dev, and their team sizes |
| [`data/bots.md`](https://github.com/ggbillyjoe3526/airsoft/blob/main/data/bots.md) | Bot names and personalities |
| [`data/bot-kits.md`](https://github.com/ggbillyjoe3526/airsoft/blob/main/data/bot-kits.md) | What the other team's bots carry |
| [`data/graphics.md`](https://github.com/ggbillyjoe3526/airsoft/blob/main/data/graphics.md) | The graphics presets |
| [`data/accessibility.md`](https://github.com/ggbillyjoe3526/airsoft/blob/main/data/accessibility.md) | Team colour sets and reduced motion |

## Dev settings

**Settings › Dev** is a tab of tools for trying things out, always there; each is off until you turn it on.
A match with Game speed, Bottomless magazines, Ghost, Bots hold fire, Bots run low on BBs, Spectate any bot, Bot
intentions, Time of day or Disable levelling changed, or on dev content, stays out of the records and gives no XP.

- **Game speed** from 25 % to 200 %, **Bottomless magazines**, **Ghost** (BBs pass through you), **Bots hold fire**, **Bots run low on BBs** (8 s into each round one bot a team, in
  turn, is put on its last magazine, to watch the hand-off).
- **Spectate any bot** (the fire key moves to the next) and **Bot intentions** (a label over each bot saying what it
  is doing, including bringing or waiting for a magazine; hidden while the order wheel, the field map or your sight
  is up).
- **Dev content** shows what is still being built (below), and **Time of day** plays any map by day or at night.
- **Disable levelling** unlocks everything and gives no XP; **Reset level** goes back to level 0.
- **Retro pixels**, **Pretend slow frames** (to try the graphics step-down), **Log a test error** and **Crash the game
  now** (to try the crash screen). **End the round now** is in the pause menu.

### Dev content

Every map and item is tagged public or dev in the data tables. Dev content is invisible with the switch off, not
even greyed out, and becomes public when its tag changes after a playtest. Today the switch shows:

<!-- wiki:dev-content -->

## Versions and releases

Versions run 0.1 Dev 1, Dev 2 … then 0.1 Beta 1, Beta 2 … then **0.1** (Early Access), followed by themed updates up
to 1.0. The current version in the code is **<!-- wiki:version -->**. Only the owner creates release tags; a tag
starts the release workflow, which exports Windows and Linux, builds the Windows installer, runs the smoke tests and
publishes a GitHub release with notes from the changelog.

## How changes land

Every change is a pull request from its own branch, never a push to `main`. CI runs the checks on every pull request,
and code changes also pass three review agents (quality, bugs and performance) before merging. Each pull request adds
one changelog note in `changelog.d/`; the notes become the release notes and this wiki's
[Patch Notes](Patch-Notes).

The rules are in the repository: [VISION](https://github.com/ggbillyjoe3526/airsoft/blob/main/docs/VISION.md),
[ROADMAP](https://github.com/ggbillyjoe3526/airsoft/blob/main/docs/ROADMAP.md),
[ARCHITECTURE](https://github.com/ggbillyjoe3526/airsoft/blob/main/docs/ARCHITECTURE.md),
[DECISIONS](https://github.com/ggbillyjoe3526/airsoft/blob/main/docs/DECISIONS.md),
[PROCESS](https://github.com/ggbillyjoe3526/airsoft/blob/main/docs/PROCESS.md),
[KNOWN_ISSUES](https://github.com/ggbillyjoe3526/airsoft/blob/main/docs/KNOWN_ISSUES.md) and
[ASSETS](https://github.com/ggbillyjoe3526/airsoft/blob/main/docs/ASSETS.md).

## How this wiki stays current

The wiki's pages live in the repository, in
[`docs/wiki/`](https://github.com/ggbillyjoe3526/airsoft/tree/main/docs/wiki), and are reviewed in pull requests
like the code. Table numbers are never typed into a page: the stats, parts, unlocks, XP, maps, keys, graphics presets, bot
kits and rules tables are read from the game's own files by `tools/wiki.py`, and Patch Notes is written from the
changelog notes. On every merge to `main`, the Wiki workflow builds the pages and publishes them here. A pull request
that changes what players see updates the page that describes it, and CI fails if a link breaks, a page leaves the
sidebar, dev content shows on a public page or a public item goes unmentioned. Edits made in the wiki's web editor
are overwritten by the next publish: edit `docs/wiki/` instead.

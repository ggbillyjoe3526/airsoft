# Handoff

What is happening now (as of 2026-10-30), for a session picking up the work. The plan is `docs/ROADMAP.md`, the
rulings `docs/DECISIONS.md`, how work runs `docs/PROCESS.md`.

## Now

- **The game has moved from the browser to Godot (owner, 2026-10-18).** This repository restarts at 0.1 Dev 1. The
  browser game (frozen at `0.1-beta.1`; its repository is no longer on GitHub) was copied into `legacy/browser/` as the
  reference to rewrite from, and removed on 2026-11-05 (owner): read it from git at the tag `0.1-dev.1`, its handover
  pack at `legacy/browser/docs/handover/` there.
- **The salvage runs as three pull requests** from the "Salvage audit and roadmap" thread: the docs, the owner's data
  tables and the legacy reference (merged); the Godot bootstrap (project, boot screen, CI, tests, release, agents and
  pipeline, from the owner's katanashotgun project, whose remaining useful scripts are in `legacy/katanashotgun/`);
  then the assets (models, fonts, sounds, map layouts).
- **The salvage is done** (pull requests #1 to #3).
- **The simulation core is done (SC1):** BBs, hit calling, Elimination rounds, the AEG Rifle and GBB Pistol, and
  movement as plain, tested GDScript on the 60 Hz tick (`game/sim/README.md`).
- **The first playable is done (FP1):** Play Depot from the title screen, walk, sprint, crouch, jump, aim and shoot
  both replicas against four Beta stand-ins that call their hits (`game/map/`, `game/play/`, `game/input/`).
- **Bots and Elimination are done (BE1):** you and two bot teammates against three bots on Depot, first to five; the nav
  grid is ported (`game/nav/`), bots are controllers (`game/ai/README.md`), lean (Q, E) and vault are in.
- **Magazines on the HUD are done (MZ1):** a gauge per magazine, and the GBB Pistol's slide locks back on empty.
- **The BB physics pass is done (BB1):** a breeze per match, the hop-up dial on 4 and 5 in play, and ricochets off
  concrete and steel (they only tick you unless the match counts them).
- **The holster and a smoother lean and vault are done (MO1):** 3 puts the replica away for a faster run (bots too),
  a lean a wall cuts short eases out, a vault dips and tips the view, and "Space to vault" shows when Jump would vault.
- **Bots vault low walls (BV1):** the nav grid links low walls a body can vault, bots take a link where it saves more
  than 3 m on foot and press Jump there; on Depot that is the hall wall.
- **Settings are done (SE1):** Controls (sensitivity as a slider or cm/360, invert, crouch and aim hold or toggle, two
  keys per action), Audio (five volumes) and Display (window mode, V-Sync, field of view, show FPS), from the title and
  the pause menu, saved in `user://settings.save`.
- **The debug view is done (DV1):** F3 also shows the match seed, your position and the entity count, F4 draws BB paths
  and F5 hit areas in the world (made only while on, keys reserved), and `-- --seed <n>` replays a match.
- **Step 27 is done (2026-10-29).** Steps 1 to 26 are built (parity with the browser's 0.1 Beta 1), plus three bot
  levels. Step 27 added bot callouts (CO1, CO2; #124, #125), the overtime flag (OV1 to OV3; #126 to #128), pings and
  ping markers (PN1, PN2; #129, #131) and the magazine hand-off (MH1 to MH3; #133, #134 and this one).
- **0.1 Dev 1 is out (2026-10-30):** the owner tagged `0.1-dev.1` on 33271ac after his playtest and the bug pass, and
  its installer check passed. `config/version` reads "0.1 Dev 2", the build being made (owner, 2026-10-30).
- **0.1 Dev 2 (owner, 2026-10-30):** basic smoke and flash bombs first, thrown by bots too; the Depot and Woodland
  redesign and CC0 dressing come later. Blender starts when he says (Depot, then Woodland).
- **Crouch and aim are both held** (owner, 2026-10-18), changed in the Depot thread.

## Where to look

- **Rulings in force:** `docs/DECISIONS.md`. **Open issues:** `docs/KNOWN_ISSUES.md`.
- **The browser game's files** below were removed on 2026-11-05; read them from git at the tag `0.1-dev.1`
  (`git show 0.1-dev.1:legacy/browser/<path>`, `git grep <terms> 0.1-dev.1 -- legacy/browser`).
- **How a system worked in the browser game:** `legacy/browser/src/<folder>/README.md`, then its tests.
- **Why a number is what it is:** `legacy/browser/docs/records/` and `legacy/browser/docs/archive/`.
- **What to rebuild:** `legacy/browser/docs/FEATURES.md` is the parity list; `docs/FEATURES.md` fills as features land.

# Airsoft

An original first-person airsoft shooter for Windows and Linux, built with Godot and Blender. Round-based team
matches against bots on purpose-built airsoft fields: plastic replicas, visible BBs, one hit and you're out, hand up,
"HIT!", walk off, reset, go again. Single player against bots only.

It is the same game as the browser version (frozen at `0.1-beta.1`; its code was kept in `legacy/browser/` until
2026-11-05 and is still in git at the tag `0.1-dev.1`), rebuilt as an installable desktop game. Versions restarted
at 0.1 Dev 1.

The [wiki](https://github.com/ggbillyjoe3526/airsoft/wiki) explains the game for players: controls, rules, every
replica's stats, maps, modes, bots, settings, patch notes and the roadmap. Its pages are `docs/wiki/`, published on
every merge (`docs/wiki/README.md`).

## Status

**[0.1 Dev 1](https://github.com/ggbillyjoe3526/airsoft/releases/tag/0.1-dev.1) is out (2026-10-30); 0.1 Dev 2 is
being built.** The plan is `docs/ROADMAP.md`; what is happening now is `docs/HANDOFF.md`.

**What's in 0.1 Dev 1:** the first build. Two maps, Depot and Woodland, and a practice range; the AEG Rifle and the GBB
Pistol, with attachments, power options and the Armory to earn them; Elimination and Attack / Defend against bots on
three difficulty levels, with squad orders, callouts and the magazine hand-off; the hit call, the walk-off and the
dead zone; settings, saves, accessibility options and a bug report button. Its full notes are `CHANGELOG.md` ›
0.1 Dev 1.

**Built for 0.1 Dev 2 so far:** smoke and flash bombs (bots throw them too), Depot and Woodland redesigned and dressed,
The Street (dev content only), a public Sniper Rifle, models built in Blender for the replicas, attachments, figures
and gear, first-person arms, and the owner's own recorded sounds.

## Run it

- **Players:** download the Windows installer or zip, or the Linux build, from the
  [0.1 Dev 1 release page](https://github.com/ggbillyjoe3526/airsoft/releases/tag/0.1-dev.1): the Windows
  installer (`Airsoft-0.1-dev.1-Windows-Setup.exe`), the Windows zip or the Linux zip. The installer is not signed
  yet, so Windows warns about it: choose *More info*, then *Run anyway*.
- **From source:** install Godot **4.7.2** (standard, not .NET), choose *Import*, pick this folder's `project.godot`
  and press F5.
- **If the game won't open, or closes while drawing:** start it on the simpler renderer, which runs on almost any
  graphics card. On Windows use the *Airsoft (safe graphics)* shortcut in the Start menu; on Linux, or from source,
  start it as `./Airsoft.x86_64 --rendering-method gl_compatibility` (`godot --path . --rendering-method
  gl_compatibility`). Once it opens, *Settings › Graphics › Renderer: Compatibility* keeps it for every start, and
  updating the graphics driver often brings the normal renderer back. A start that closed while drawing restarts by
  itself on the simpler renderer and Low and asks whether to keep them.
- **Controls:** move WASD, walk Shift, sprint Alt, crouch C or Ctrl, jump Space, fire and aim the left and
  right mouse buttons, reload R, fire mode B, replicas 1, 2 or the mouse wheel, pause Esc. Debug keys (not rebindable): F3 the overlay (FPS, seed, position), F4 BB paths, F5 hit areas; `-- --seed <n>` replays a match. Every key, the mouse and the volumes change under *Settings* (title
  screen or pause menu).

## Layout

| Folder | What it holds |
|---|---|
| `game/` | The game's scripts and scenes, by system (`docs/ARCHITECTURE.md`) |
| `data/` | The owner's data tables (replicas, stats, levels, bots, kits, callouts) and the map layouts |
| `assets/` | Models (glTF), fonts and sounds; every one is logged in `docs/ASSETS.md` |
| `tests/` | GUT unit tests, run headless |
| `tools/` | Check, test, release and asset scripts; `tools/blender/` builds the figures |
| `docs/` | Vision, art direction, rulings, roadmap, process, the playtest guide and the wiki's pages (`docs/wiki/`) |
| `legacy/` | Read-only reference, removed at 0.1: a few katanashotgun scripts still to port (the browser game's code went on 2026-11-05; see `legacy/README.md`) |

## Checks

`tools/check.sh` runs every check CI runs (lint, the wiki, unit tests, a headless smoke test, the licence notices); it
needs `godot` on PATH (or `GODOT=/path/to/godot`) and, for lint, `pip install "gdtoolkit==4.5.0"`. How work moves:
`docs/PROCESS.md` and `CLAUDE.md`.

## Licence

The code is MIT (`LICENSE`), copyright ggbillyjoe3526. Third-party assets keep their own licences (`docs/ASSETS.md`);
every build ships `THIRD_PARTY_NOTICES.txt`.

# PP1 · Preliminary Dev 3 pass: balance, bugs, QA and performance

**Review (part 1):** pending

The owner's preliminary run of the Dev 3 final passes (2026-11-10, "search thoroughly for any bugs, issues (quality,
balance, performance)", "check against all known issues"); the full passes run again after Subway's models and the
sounds. Six read-only reviewers swept the code since `0.1-dev.2` (Subway, the other maps, replicas and UI,
performance, a balance model of the data) and every `docs/KNOWN_ISSUES.md` row, the 2026-11-07 list, the BP7 and BP8
playtest notes and the Dev 3 checklist's partly checked items. Bot balance runs on every map (Normal 32 seeds, Easy and
Hard 16, both modes) ran alongside. The fixes ship in parts.

## Part 1: bugs, performance and docs

- **Door frames in their walls.** Every leaf hangs on its wall's face (`tools/depot/build_map.py`), but
  `DoorView._add_frames` put the frame at the leaf: 0.19 m proud on Depot's 15 doors, 0.3 m on Woodland's 0.5 m hut
  walls, and its jamb probe missed the wall, so the depth fell back to 0.3 m. The frame now finds the thinnest wall
  either jamb meets within `WALL_REACH` (0.1 m) of the leaf and sits in its middle. The DM1 depth test read the
  MultiMesh back, which is the identity headless, so it passed whatever; `frame_at()` gives tests the placed transform.
- **The Armory and old saves.** `ArmoryFacts` judged unlocked by level alone; LV15 moved items up a level and saves keep
  them, so a Dev 2 save at the old cap saw five owned items locked. It now takes `Progress.unlocked` and dims only
  items not owned; the count follows.
- **Button press.** A still press (Reduced motion) cutting a dip short left the button shrunk; it is reset at the cut.
- **Lamps and fixtures.** `LightFixtures` made a fresh Shader per match (the BP2 regression); it uses `CodeShaders`.
  `RoofView` kept flicker levels as 32-bit floats, so a low step never compared equal and the lamp was written every
  frame of a burst; 64-bit now.
- **The scope's shadow slots.** `OpticGlass` set only its atlas size, so its picture kept the viewport's 88 slots under
  Depot's 91 and Subway's 103 lit lamps; it takes `GraphicsApply.apply_slots` as the main view does.
- **Weapon rail keys** relabel on resume (`WeaponRail.refresh_keys`); the KNOWN_ISSUES row is deleted.
- **The Loadout's sheet and the wiki** give Spread from the hip (Spread × Hip spread): the Sniper Rifle read 0.10°, the
  tightest, when from the hip it is 0.60°. Pace and Spread moving rows show for a replica off ×1 (the Compact SMG); the
  KNOWN_ISSUES row on it is deleted.
- **Docs** that disagreed with the code: wading's noise (Maps, Movement), "a replica every five levels" (public players
  get one at 5 and 15), Woodland's "dry stream" (data/maps.md), the bot kits' personality lean and column sums
  (data/bot-kits.md), and three stale KNOWN_ISSUES rows (Subway on Medium, Depot's baked details, "row 104").

## Decisions

- **Not fixed, logged instead** (`docs/KNOWN_ISSUES.md`): the locker's silent run-in (a per-block noise is a bigger
  change than one block warrants), the button dip's lost edge click (the owner's "dips about its middle" look kept),
  the lamps' per-frame shadow redraw (needs a frame time from the owner's card first), SDFGI after a lamp switch, the
  Retro filter in the glass, and the stale map pictures (render again before the Dev 3 tag).

## Known issues left

- The rows above, each added to `docs/KNOWN_ISSUES.md`.

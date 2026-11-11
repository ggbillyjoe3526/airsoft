# PP1 · Preliminary Dev 3 pass: balance, bugs, QA and performance

**Review:** part 1 (#305) 2 attempts · critic Accept 8/8 · qa Pass · performance Pass; part 2 1 attempt · critic
Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Part | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|---|
| 2026-11-11 | 1 | 1 | Opus 5.5 (build thread) | targeted ✓, CI unit part 1 ✗ | 6/8 Retry | test_armory_cards read the list's dim; the next level's tiles dimmed; a stale row |
| 2026-11-11 | 1 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |
| 2026-11-11 | 2 | 1 | Opus 5.5 (worker) | targeted ✓ | 7/8 Accept | (non-blocking) the mid-ride stop limit had no row: added |

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

## Part 2: climbing and Subway's lifts

- **Props climbed (High).** CL1's climb checked only that a 0.6 to 0.95 m top ran on 1.5 m, so Depot's desks and sofa,
  Subway's benches and the Range's long crate could be climbed from an end, against the wiki and CL1's "never crates or
  props". `VaultConfig.climb_kinds` (`[floor]`) lists what a climb may end on; a top no listed block owns (the ground)
  still counts. Bots' climb links go through `Vault.plan`, so they follow. A sweep of every non-floor block on all four
  maps at 16 headings guards it; Subway's track pits still climb at 0.9 m.
- **A full lift held open (High).** A bot waiting at a car standing open but full pressed its button every tick (304
  presses in 3.5 s, a beep and a ping each), so the car never left. It presses only when the car isn't open there and,
  while it shuts, only with room aboard.
- **Riders in the doorway (Medium).** Riders' spots on a small circle sat as close as 0.16 m, so keeping apart pushed one
  into the doorway and held the doors. Riders stand in the corners by rank, 0.6 m in, and don't keep apart aboard.
- **Routes from a moving car (Medium).** A route planned mid-ride started at the nearest stop's landing, not the stop
  the car heads for; a hit player's walk-off began with the doors shut. Routes start at the car's destination and a
  walk-off waits for the doors.
- **Bombs in a car (High)** stayed in the shaft as the car left; they ride with it now.
- **A "Lift" area** over each well, so a contact in a car has a place name (it had none at two stops).
- **Vault links' price** is each take-off node's own weight, not the first node's (a wet first node would price every
  vault ×8).
- MT2's three unlisted limits, and the mid-ride stop-on-the-way limit, are KNOWN_ISSUES rows.

## Decisions

- **Not fixed, logged instead** (`docs/KNOWN_ISSUES.md`): the locker's silent run-in (a per-block noise is a bigger
  change than one block warrants), the button dip's lost edge click (the owner's "dips about its middle" look kept),
  the lamps' per-frame shadow redraw (needs a frame time from the owner's card first), SDFGI after a lamp switch, the
  Retro filter in the glass, and the stale map pictures (render again before the Dev 3 tag).

- **`climb_kinds` is floor alone:** every shipped platform and dock top is kind floor. **Riders' corners 0.6 m in:**
  the body's radius (0.32 m) and the 0.2 m a bot stops short, with a margin.

## Known issues left

- The rows above, each added to `docs/KNOWN_ISSUES.md`; and a bot replanning mid-ride whose car stops on the way walks
  out on the wrong floor's leg once (can wait).

# FM2 · A more detailed full-screen map

**Review:** critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | Opus 5.5 (build thread) | ✓ (4211 of 4211); QA Fail (a stale test), performance Fail (Woodland build +130 %, then +17 %) | 7/8 Retry | 6: place names too close; zone words over zones; the reports still Fail |
| 2026-11-01 | 2 | Opus 5.5 (build thread) | ✓ (4268 of 4268, with main merged in); QA Pass, performance Pass (Woodland build about +4 %) | Accept 7/8 | – (8: the record and the performance report were stale; fixed) |

## Goal

The owner's playtest feedback (2026-11-01), point 6: "the map (button M) should show objectives, location names, etc.
make it more detailed", for Depot, Woodland and The Street. The minimap stays hearing-only for the other team.

## What changed

- **The screen** (`HudFieldMap`): the field fits the room left of a key and under a header, keeping its shape (the view
  and the pointer take a non-square panel: `HudMinimap.View._half` and `MapPointer.half` are Vector2s,
  `MapPointer.frame_rect`). The header names the map, "ROUND 2 · ATTACK / DEFEND" and, in your team's colour, what your
  side must do (attack A / B, defend them, knock them out, overtime, nothing in practice).
- **The marks that never move** (`FieldMapMarks` from MapData, drawn by `FieldMapOverlay`, laid out once per size,
  storey and round): A and B badges with a ring by each pole in Attack / Defend; Elimination's overtime spot as a faint
  ring, solid once the flag is up; each end's start (its spawns, 2 m out) in the colour of the team at that end, read
  from `Character.end` so it swaps at half time; the dead zones hatched grey; each door a wood-coloured bar across its
  doorway; a compass and a 10 m scale bar.
- **Place names** (`FieldMapMarks.lay_out`): bigger type for areas of 300 m² or more in all their boxes; biggest first,
  each at its biggest box or just above, below or beside it, never over another word, a flag, a start or the compass;
  one with no room is left out (on Depot, Staging and Loading bay sit under the starts).
- **The key** (`FieldMapKey`): every mark in the map's own shapes and colours.
- **The ground** (`MinimapField`, shared with the minimap): a floor takes `ground_tint_share` of its own colour (The
  Street's) or its surface's tint (grass, leaves, earth, gravel, wood; concrete and metal stay plain); hedges, thickets
  and scrub draw green; sloping ground is its own picture (`MinimapField.ground`), shaded by its slope towards the
  north-west light and lighter the higher it stands, drawn under each layer by the panel (`HudMinimap.View`).

## Decisions

- The map's rule: `docs/DECISIONS.md` › Menus, HUD, settings and accessibility (FM2).
- **Doors show where they are, not whether they are open.** A door's state far away would be news the map has no way
  to know.
- **The overtime spot shows faint from the start in Elimination.** Where the flag will rise is part of the field, like
  the poles.
- **A word that finds no room is left out** rather than shrunk: small type over a busy map read worse than one name
  fewer.
- **Sloping ground is its own small picture, drawn under the layers by the GPU** (a pixel a metre, smoothed as it is
  drawn). Worked out on the CPU and resized to the layer it cost Woodland's field build about 450 ms at first, then
  55 ms (performance, attempts 1 and 2); drawn this way the build is as fast as main's and holds no 8 MB copy.
- **Place names keep a space's width apart across and 8 px down** (critic, attempt 1: two names 3 px apart read as
  one). Zone words go above their box, else below or beside it, clear of every zone and flag, else they are left out:
  on Depot the dead zones sit against the starts, so their words are left out and the key names the hatch.
- **The ground detail is in the shared drawing**, so the minimap reads the same ground; tints are a quarter share so
  cover and walls still stand out.

## Verified

- `tools/check.sh` on the merged head: gdlint, changelog, wiki, unit tests 4268 of 4268, smoke test and licence
  notices all pass.
- Screenshots of the screen on all three maps at 1920x1080 (`/mnt/project-files/screenshots/fm2/`): no word over
  another, a flag, a start or the compass.
- QA (attempt 2): 35 tests in `test_fm2_qa.gd`, Pass; its advisory (the ground picture fell up to a sample short of
  the far edge when the terrain's squares don't divide by the step) fixed: the last samples take what is left.
- Performance (attempt 2): Woodland's field build about +4 % over main (inside the run's noise), The Street and Depot
  unchanged; laying out the words 0.1-0.4 ms once per size; nothing new allocates per frame.
- Not verified here: how it reads in play. The owner's checks are in `docs/PLAYTEST.md` (FM2).

## Known issues left

- None.

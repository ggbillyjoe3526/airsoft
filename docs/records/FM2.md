# FM2 · A more detailed full-screen map

**Review:** critic pending · qa pending · performance pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | Opus 5.5 (build thread) | pending | pending | – |

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
  one with no room is left out (on Depot, Staging and Loading bay sit under the starts' words).
- **The key** (`FieldMapKey`): every mark in the map's own shapes and colours.
- **The ground** (`MinimapField`, shared with the minimap): a floor takes `ground_tint_share` of its own colour (The
  Street's) or its surface's tint (grass, leaves, earth, gravel, wood; concrete and metal stay plain); hedges, thickets
  and scrub draw green; sloping ground is shaded by its slope towards the north-west light and lighter the higher it
  stands, drawn per ground square and smoothed up.

## Decisions

- The map's rule: `docs/DECISIONS.md` › Menus, HUD, settings and accessibility (FM2).
- **Doors show where they are, not whether they are open.** A door's state far away would be news the map has no way
  to know.
- **The overtime spot shows faint from the start in Elimination.** Where the flag will rise is part of the field, like
  the poles.
- **A word that finds no room is left out** rather than shrunk: small type over a busy map read worse than one name
  fewer.
- **Woodland's field drawing takes about 55 ms longer to build (+17 %), once a match behind the loading screen**
  (performance, 2026-11-01: 373-392 ms against main's 318-338 ms; The Street and Depot unchanged). The first build was
  +130 %: the relief now reads the terrain's own vertices once a match, a sample a metre. What remains is mostly
  `Image.resize` smoothing the ground up to the layer (about 44 ms). Accepted as the cost of the new ground: a frame
  costs nothing more, and moving the smoothing to the GPU would mean a second texture in every minimap panel.
- **The ground detail is in the shared drawing**, so the minimap reads the same ground; tints are a quarter share so
  cover and walls still stand out.

## Verified

- To fill in after the checks.

## Known issues left

- None.

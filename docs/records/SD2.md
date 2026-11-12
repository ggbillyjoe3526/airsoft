# SD2 · Subway's small fittings: more detail in the interiors

**Review:** critic Accept 7/8 (attempt 1) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | build thread | pass | 7/8 Accept | – |

## What was asked

The owner, 2026-11-12: "Give the interiors more detail" (07:33) and "Add more signs, posters and other environmental
details to the areas" (09:15). Split with SM5 by agreement: SM5 does every sign and poster (#315, #317); this task
does the rest.

## What was built

`StationDetail` (game/play/station/station_detail.gd, `StationDetailConfig` on PlayTuning) fits every hall, passage,
plant and service room of a station's dress at load, one vertex-coloured mesh, look only (no collider, no nav cell,
no shadow), nothing run a frame:

- Along each wall and round each column: a dark skirting, a green tile dado at 0.7 m and a frieze at 2.45 m, over the
  signs' and posters' band (0.85 to 2.35 m), which is left clear.
- Under the ceilings: cable conduit with clips, two pipes on brackets in the plant and service rooms, one down a
  passage's wall; wall vents high in rooms at least 3.4 m tall.
- Ceiling access hatches on a grid, kept 1.2 m from every lamp and 0.9 m from the room's sides; floor drains along
  the halls' walls.
- A grey-green service door, framed, with a kick plate, handle and a blank plate, on each plant room's longest wall.
- Vents and doors keep 0.5 m from any of SM5's fixtures (signs, posters, clocks, cameras).
- Yellow tactile strips at each escalator's and main stair's head and foot (tools/subway/station_dress.py `heads`,
  the existing `tactile` finish).

A wall is where a room's side meets a solid block, probed at each fitting's own height, so a band never runs over an
open well or a doorway.

## Decisions

- **Look only, one mesh**: the fittings are a few thousand boxes; one draw, built once.
- **Colours off the team hues**: greys, a dark green band (2f5a46), grey-green pipes and doors.
- **No words**: the door's plate is blank; every word in the station is SM5's sheet.
- **A plain hall floor** (owner, 13:06: "more plain and minimal"): the halls' floors take a new `hall_floor` finish
  (Concrete034 at 4 m a copy, a pale warm grey) in place of the terrazzo; the passages keep their quarry tiles.
- **After the critic's accept** (its optional notes): the door's leaf stands proud of the skirting, which runs on
  behind the frame (no flicker at the door's foot); two unused parameters dropped, a stray doc comment moved.
- **Rooms under 3 m across get no door, under 2.6 m tall no conduit**: in a doorway's slice of room they would stand
  in the signs' band.

## Known issues left

- The door's own proportions (handle 1.0 m, plate 1.55 m, kick plate 0.25 m, frame 0.06 m) are inline look values,
  as GatePaddles' are; move them into StationDetailConfig the next time the file is touched (critic, advisory).

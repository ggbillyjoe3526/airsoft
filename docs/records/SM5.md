# SM5 · Subway's lamps and extras

**Review:** passed (critic 8/8 at attempt 10, QA Pass, performance Pass)

Models 31 to 33 of `art/subway-model-list.md` (William's go, 2026-11-12: "Begin work on subway models now"), from his
photos in `art/references/maps/subway/31-ceiling-lamp`, `32-tunnel-lamp` and `33-extras/<kind>/`.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | build thread | ✓ | 7/8 Retry | models too far from his photos: strip lamp's cage, tunnel lamp's outline, extinguisher's build, CCTV's arm |
| 2026-11-12 | 2 | build thread | ✓ | 7/8 Retry | strip lamp too long and shallow, its diffuser a solid slab; tunnel lamp's glass corners proud, bar ends past the outline |
| 2026-11-12 | 3 | build thread | ✓ | 7/8 Retry | strip lamp's body deeper than the photo's (attempt 2's figures were off); tunnel lamp's outline faceted at six segments |
| 2026-11-12 | 4 | build thread | ✓ | 7/8 Retry | tunnel lamp's glass folded on one crease, its edges past the outer bars; strip lamp's lip flush with the body's ends |
| 2026-11-12 | 5 | build thread | ✓ | 7/8 Retry | (past four attempts: the review-cap ruling) tunnel lamp's lugs pointed, its glass still one hard corner |
| 2026-11-12 | 6 | build thread | ✓ | 7/8 Retry | wedge holes under the tunnel lamp's raised spine, top and bottom |
| 2026-11-12 | 7 | build thread | ✓ | 8/8 Accept | |
| 2026-11-12 | 8 | build thread | ✓ | 7/8 Retry | (William's ask: more posters, large trackside ones) the jazz club's name was a real London bar's |
| 2026-11-12 | 9 | build thread | ✓ | 8/8 Accept | |
| 2026-11-12 | 10 | build thread | ✓ | 8/8 Accept | (William: trackside posters much larger, 6 x 3 m) |

## What it adds

- **Ceiling strip lamp** (`strip_lamp.glb`, 192 of 200 triangles): the caged industrial batten of his photo 121814
  (eight and a half to one, measured on the photo by pixel: a black body flaring to a lip over a wire cage as deep,
  ten hoops round a clear diffuser filling the cage with the tube's glow along its floor, four wire bails a side,
  hook hangers on plates), on
  every station ceiling in place of MT1's glowing panels (`RoofConfig.plain_lamp_model`); a room running along z turns
  its lamps a quarter (`roof.lamps[].turn`, MapData.roof_lamp_turns), so each runs along its room. The real lights
  (RoofLamps) are unchanged.
- **Tunnel bulkhead lamp** (`tunnel_lamp.glb`, 150 of 150): his caged bulkhead, a stadium outline, black like his
  fourth photo, 12 on
  the running tunnels' walls, its glass glowing (no real light).
- **Extras**, look only (`StationFixtures`, spots in `tools/subway/fixtures.py`, `dressing.station.fixtures`): 13
  name boards, 8 way-out signs, 21 posters (13 designs) and 6 large trackside ones (3 designs), 4 clocks, 11 CCTV
  cameras, 8 fire extinguishers, 7 litter bins and 12 edge warnings; printed faces from one 2048 x 2048 sign sheet
  (`assets/textures/station/signs.png`, BC7).

## Decisions

- **The station is called Copperhill** on its name boards, a made-up name: not "Kingsmere", which the map dropped
  when it became Subway (RN1). Every word is invented; no roundel, no real network's colours: the name band is dark
  grey-green with cream letters, the signs black with yellow (his photos' style, the station's one safety colour).
- **The posters are the game's own:** "Call your hits", a Sunday skirmish at the Woodland site, lost property
  (goggles, gloves, one left boot) and Copperhill Lido; muted palette colours, kept off both team hues.
- **More posters (William, 2026-11-12: "Create more posters. They can be related or have generic advertising"):**
  nine more designs, 13 in all: Goggles on, a chrono night and a club's call for new players beside the first four,
  and adverts for invented things (Halden Tea, Fizzbee lemonade, the Lamplight Room jazz club, the library's late opening, a
  Saturday market, a tram museum). The wall spots take them in turn, so no two neighbours match.
- **Large trackside posters** (William's "larger posters on the walls", through the platforms thread, then "Make the
  far trackside posters much larger"): 6 x 3 m in a 50 mm frame (`poster_wide_a..c`: Skirmish Sundays, cycle hire,
  Copperhill Pier), middle 2.4 m over the track bed (0.9 to 3.9 m, under the platforms thread's vault at 4.1), on
  the walls across the track between the name boards: two north, four south. Each is
  its own model (one MultiMesh a model); the sheet grew to 2048 x 2048 for them (posters drawn at 384 x 576 and
  fitted to 336 x 504 cells).
- **The edge warnings sit 0.7 m in from the edge**, behind PT1's yellow line (0.45 to 0.55 m) and clear of its
  "Mind the gap" words on the coping.
- **The edge warning reads "Stay behind the yellow line"**, his third photo's words, not a real network's phrase.
- **Ceiling lamp: the caged batten** (photo 1) of his five, the one that reads as a station's; dark body, opal
  diffuser, wire guard. **Tunnel lamp: black**, not his photos' brass, which sits close to the Beta team's orange.
- **The extinguisher's red leans crimson** (#a82c62): a fire red sits within 20 degrees of High contrast Beta orange
  and would read as a team colour (FieldChecks.reads_as_team).
- **Way-out signs read both ways:** "Way out" faces those heading west and up to the street, "Platforms" those heading
  east and down.
- **The cage wires are two-faced round bars** (`stationkit.Mesh.wire`, a smooth ridge with its back unseen): a real
  round wire would cost three times the triangles, and the budgets hold the cage's ten hoops only this way.
- **The tunnel lamp's 150 triangles** go on a round outline (nine segments a half circle, its top on an edge's
  middle, smooth shaded) in two bands (the body, standing in round the glass, and the dome's front); the glass runs
  down the straight sides and across the front raised along a spine under the vertical bar, an arc of three facets.
  The four bars across are flat straps bending with that arc (round bars would cost twice), the vertical one a round
  bar; blunt screw lugs top and bottom.
- **The strip lamp's clips** sit at a tenth, a third, two thirds and nine tenths of its length, measured on photo
  121814 (clips at 68, 213, 378 and 523 px of a lamp from 12 to 585 px).
- **The extinguisher is 3.6 to 1** (0.58 m by 0.16 m) as his photos, with a black label band and a round horn.
- **No collider, no shadow:** the extras change nothing in play (the model list's "look only"); bins stand against
  walls out of the routes. A spot that would stand in a doorway or a block is left out by the build.
- Budgets for the extras were not in the list; each was set to its model's need and filled to about 95%: CCTV 320,
  way sign 90, extinguisher 480, bin 320, clock 300, poster 40, name board 40, edge warning 12.

## Known issues left

- **The track bed's colour:** William asked for it dark grey, almost black (2026-11-12); the platforms thread owns the
  `ballast` finish (StationLook) and darkens it there, so this pull request leaves it.
- **The tunnel lamp at close range** (document; the budget is the owner's, model list #32): within 150 triangles its
  front reads as a ridged panel with chevron bars, not the barrel of his photo 121940; from below, the flat black lips
  under the glass show as hard facets beside the smooth dome and the bars' cut ends as light slivers past the rim. On
  the Dev 3 checklist whether the budget should rise.

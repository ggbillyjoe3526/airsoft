# SM5 · Subway's lamps and extras

**Review:** pending

Models 31 to 33 of `art/subway-model-list.md` (William's go, 2026-11-12: "Begin work on subway models now"), from his
photos in `art/references/maps/subway/31-ceiling-lamp`, `32-tunnel-lamp` and `33-extras/<kind>/`.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | build thread | ✓ | 7/8 Retry | models too far from his photos: strip lamp's cage, tunnel lamp's outline, extinguisher's build, CCTV's arm |
| 2026-11-12 | 2 | build thread | ✓ | 7/8 Retry | strip lamp too long and shallow, its diffuser a solid slab; tunnel lamp's glass corners proud, bar ends past the outline |
| 2026-11-12 | 3 | build thread | | | |

## What it adds

- **Ceiling strip lamp** (`strip_lamp.glb`, 200 of 200 triangles): the caged industrial batten of his photo 121814
  (seven to one, a black body flaring to a lip over a wire cage a little shallower, ten hoops clear of a narrower
  glowing diffuser, four wire clips a side, hook hangers on plates), on
  every station ceiling in place of MT1's glowing panels (`RoofConfig.plain_lamp_model`); a room running along z turns
  its lamps a quarter (`roof.lamps[].turn`, MapData.roof_lamp_turns), so each runs along its room. The real lights
  (RoofLamps) are unchanged.
- **Tunnel bulkhead lamp** (`tunnel_lamp.glb`, 146 of 150): his caged bulkhead, a stadium outline, black like his
  fourth photo, 12 on
  the running tunnels' walls, its glass glowing (no real light).
- **Extras**, look only (`StationFixtures`, spots in `tools/subway/fixtures.py`, `dressing.station.fixtures`): 13
  name boards, 8 way-out signs, 27 posters (four designs), 4 clocks, 10 CCTV cameras, 7 fire extinguishers, 6 litter
  bins and 12 edge warnings; printed faces from one 2048 x 1024 sign sheet (`assets/textures/station/signs.png`, BC7).

## Decisions

- **The station is called Copperhill** on its name boards, a made-up name: not "Kingsmere", which the map dropped
  when it became Subway (RN1). Every word is invented; no roundel, no real network's colours: the name band is dark
  grey-green with cream letters, the signs black with yellow (his photos' style, the station's one safety colour).
- **The posters are the game's own:** "Call your hits", a Sunday skirmish at the Woodland site, lost property
  (goggles, gloves, one left boot) and Copperhill Lido; muted palette colours, kept off both team hues.
- **The edge warning reads "Stay behind the yellow line"**, his third photo's words, not a real network's phrase.
- **Ceiling lamp: the caged batten** (photo 1) of his five, the one that reads as a station's; dark body, opal
  diffuser, wire guard. **Tunnel lamp: black**, not his photos' brass, which sits close to the Beta team's orange.
- **The extinguisher's red leans crimson** (#a82c62): a fire red sits within 20 degrees of High contrast Beta orange
  and would read as a team colour (FieldChecks.reads_as_team).
- **Way-out signs read both ways:** "Way out" faces those heading west and up to the street, "Platforms" those heading
  east and down.
- **The cage wires are two-faced round bars** (`stationkit.Mesh.wire`, a smooth ridge with its back unseen): a real
  round wire would cost three times the triangles, and the budgets hold the cage's ten hoops only this way.
- **The tunnel lamp's 150 triangles** go on a round outline (six segments a half circle, smooth shaded) in three
  bands (body, shoulder, front), the glass inset in the front band; the cage's runs back to the rim are flat straps
  seen side on, its crossings round bars, so it fits; small screw lugs top and bottom.
- **The strip lamp's clips** sit at a tenth, a third, two thirds and nine tenths of its length, measured on photo
  121814 (clips at 68, 213, 378 and 523 px of a lamp from 12 to 585 px).
- **The extinguisher is 3.6 to 1** (0.58 m by 0.16 m) as his photos, with a black label band and a round horn.
- **No collider, no shadow:** the extras change nothing in play (the model list's "look only"); bins stand against
  walls out of the routes. A spot that would stand in a doorway or a block is left out by the build.
- Budgets for the extras were not in the list; each was set to its model's need and filled to about 95%: CCTV 320,
  way sign 90, extinguisher 480, bin 320, clock 300, poster 40, name board 40, edge warning 12.

## Known issues left

- None yet.

# MT3 · Kingsmere dressed in CC0 materials (ambientCG)

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | thread | ✓ | Accept 8/8 | – (first look held until QA and performance re-signed the final head) |

## Goal

The owner (2026-11-10): "can you add CC0 assets to Kingsmere map?" Replace the metro station's greybox paint with real
CC0 materials, keeping its cover, collision and sight lines exactly as MT1 built them, the Sunlit Concrete look (muted,
grime; underground lamp-lit), 60 fps on a low-spec machine, textures at 2K or less and the install under 500 MB.

## Approach

- **CC0 materials:** 16 ambientCG sets (white bevelled wall tiles, terrazzo, quarry tiles, light and dark concrete,
  platform concrete, ballast, escalator tread, painted steel, rust, corrugated shutters, planks, boards, plant-room
  plaster, train rubber, tactile paving), fetched from a pinned GitHub mirror (ambientcg.com is out of the cloud's
  reach) by `tools/textures/station_textures.gd` and baked into two texture arrays, one 512 px layer a set: colour,
  and the OpenGL normal with roughness in its blue. Registered in `docs/ASSETS.md`, credited in
  `THIRD_PARTY_NOTICES.txt`.
- **One material, one draw:** `StationSurface` draws the level's very block faces (GreyboxFaces, as the greybox) in
  `station_surface.gdshader`: each vertex names its set, so the whole station is one mesh in one material, as the
  greybox was. UVs are each face's plane in the world, so tiles run on from block to block. Broad blotches break the
  sets' repeats and grime climbs each wall's foot (the look's grime colour); everything is pulled to the look's paint
  saturation and lit by the shared light.
- **Which finish:** `tools/kingsmere/station_dress.py` (called by build_map.py) writes `dressing.station`: every room's
  air with its style (hall, passage, escalator, plant, service, platform, track, tunnel, train). Each face takes the
  finish its room's style gives a floor, wall or ceiling facing it (StationLook); a cover block its kind's (a cabinet's
  steel, a crate's planks, a hoarding's boards, a skip's rust); a block inside a train its car's paint. A wall spanning
  storeys (MT2's lift shafts) is cut at each room's floor and ceiling, so each storey's stretch wears that room's
  walls; inside the wells the shafts are plain paint in their own colour.
- **Details, scenery only:** each platform's edge has a pale coping and a yellow tactile strip, laid 1 cm over the
  floor; both lines' track has concrete sleepers and rails, 14 cm at the rail's top (below a 15 cm step), no collider.
- **Nothing moves:** the map's blocks, spawns, lanes, flags and areas are byte for byte MT1's (the build only adds
  `dressing`); the colliders are the greybox's (test_station_dress compares them). No prop model stands in a
  Kingsmere box any more (Depot's container and crate models drew the kiosks and the cable drums).

## Defaults taken

- 512 px sets (the mirror's size), at about 850 px a metre on the wall tiles; 2K was not available from the cloud.
- Ceilings in light smooth concrete, the platforms' too, not plaster (the plaster set's bare brick patches read as
  holes); only the running tunnels are lined in dark concrete.
- Tunnels lined in sooty concrete, not cast-iron segments (the iron set read as rust walls).
- Low draws the sets without their relief (one texture read a pixel).
- The lift shafts tiled like the room they stand in (a first try in dark paint read as a black box in the hall).

## Checks

- `tools/check.sh`: green on a1a6a5a (5,752 tests, 2 pending for want of a display).
- `tests/unit/test_station_dress.gd` (19 tests, 7 of them QA's): the map's dress, every finish's set in both arrays,
  the rooms' finishes at known spots, the lift shafts' storeys, the escalators' tread and the cover kinds', the
  colliders identical with and without the dress, the strips on the platforms and the rails on the track bed under a
  step, Low, the tints off the team hues, bad input, the greybox when the arrays are missing.

## Known issues left

- Medium still draws underground in flat shade (KNOWN_ISSUES, Graphics).
- Not measured: frame time on a low-spec PC (one draw, 15,160 triangles against the greybox's 9,910, two array reads a
  pixel on High, one on Low); a play check in playtest/0.1-dev3-checklist.md.

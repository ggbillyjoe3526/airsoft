# TQ2 · Subway's street entrance, smooth train rails in a brighter orange, and adverts in the cars (Beta)

**Review:** critic Accept 8/8 (attempt 3) · qa Pass (197897e) · performance Pass (197897e)

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-21 | 1 | build thread and one worker | touched tests 177/177, QA Pass, performance Pass | Retry 7/8 | the street never shown (indoor-looking landing), black escalator treads, a dark band read as a gap, a placeholder sign, rails ending in a cushion and in mid-air, doubled tubes into the cove |
| 2026-11-21 | 2 | build thread and one worker | touched tests 183/183, QA Pass, performance Pass | Retry 7/8 | placeholder posters, a blockout street (flat windows, square railing, no shop names, no sky), jagged stroke sign, the orange still rust brown in game |
| 2026-11-21 | 3 | build thread and one worker | touched tests 237/237, QA Pass, performance Pass | Accept 8/8 | – |

## Goal

The owner's ask (2026-11-21): "add a station entrance/exit door just behind where the players start in the ticket
hall ... an escalator/stairs going up to an outside street. The player shouldn't be able to go out to the street so
maybe add a gate. Also, the subway train interior, can you make the hand rails more smooth and minimalistic with a
slightly more vibrant orange (same for any other orange that appears, like the stripe on the outside of the train
for example). And can you add adverts/posters to the signs above the windows inside the train? Give me screenshots."

## Approach

- **The doorway** (`tools/subway/layout.py`, `build_map.py`): a room may name `doors` in an outer wall, by edge
  (from, to, height); `shell()` leaves the wall out there (with a lintel over it; here the entrance block fills that).
  The hall's west wall opens 4.8 m wide and 3.2 m high on its middle, right behind the street team's start.
- **The entrance** is one solid `wall` block behind the doorway (x -66.5 to -55, 4.8 x 5 x 11.5 m), drawn as one model
  (`station_entrance.py`, 4,992 of 5,150 triangles, `PropDressConfig.models`): a tiled passage, a stair of 15 risers and
  an escalator side by side climbing 2.6 m, a glass balustrade, the street exit at the top (pavement, kerb, road, a
  round railing, a lamp post with its lantern, flanking buildings, a tea room and a newsagent with their names in
  stroke letters and glazed windows, a pale sky), a black fascia over the doorway and a locked folding lattice gate at
  the block's face. Look only: spawns, nav, routes and cover are unchanged; the gate is the block's face, so nobody
  walks, climbs or shoots through it.
- **Its signs and posters** are the station's own printed fixtures (`fixtures.py` `entrance`, after the critic's
  attempt 2): the name board over a way-out sign on the fascia, and three posters up the stair's wall. They stand on
  or in the dressed block, so they skip the room checks, as the tunnels' bend fixtures do; `test_station_fixtures.gd`
  leaves them to `test_se1_entrance.gd`.
- **Its lamps:** two lamps under its ceiling. A plain roof's lamp light reaches to `MapData.floor_under`; with no
  floor block under them it would fall back to the ground (0 m) and light 9 m too far. A lamp may now carry its own
  `floor` in the file (`MapData.roof_lamp_floors`, NAN when left out), which `RoofView.plain_reaches` takes first.
- **Rails** (`train.py`, worker): 12-sided tubes with bends in steps of 22.5 degrees or less. After the critic, each
  bay's rail and its two poles are one bent tube (an inverted U): the poles stand on the floor against the seat-end
  panels' doorway faces and bend into the rail over the seats' front edge, as the owner's photos
  (`references/maps/subway/02-train-car-inside/`); at a car's end the rail runs into the end wall. No brackets, no
  collars, nothing doubled into the cove; the draft screens lose their orange tube and keep a black frame that holds
  the glass. Every end and gangway handle is a single D tube. The rails are their own models (`train_poles`,
  `train_end_rails`, `train_gangway_rails`): a car is about 17.4k triangles (17.8k before).
- **Orange** #c0652f to **#ea6a22** (hue 21.6, Beta 28): the train's stripe and poles, the station signs' stripe
  (`signs.png` regenerated), the moquette's rings (`look_surface.gdshaderinc`), and the tests' Subway exemption
  (`_stripe` also refuses anything brighter than the stripe, so Beta's #fa8c29 stays caught). After the critic's
  attempt 2 (the poles still read rust brown in game: the look pulls every paint 40 % toward grey) the orange keeps
  its whole colour: the trains' orange faces by vertex alpha (`train.py` FULL_COLOUR, TrainView's `keep_by_alpha`,
  as Subway's safety yellow), the printed signs' orange pixels by hue (`look_vertex.gdshader` `keep_stripe`,
  `StationFixturesConfig.stripe`). A pole's median pixel in render 05 went from 104,49,26 to 149,45,0.
- **The street's daylight** (after the critic): a new surface kind 9, lit (`surface_kinds.py`,
  `look_surface.gdshaderinc`), glows by its own colour (`look_vertex.gdshader` `daylight_glow` 0.55): the street up
  the stair and the sign's letters, so the street reads as sunlit from the hall. Flanking buildings close the
  street's sides; the escalator's treads are brushed aluminium; the wall band is the hall's lighter green.
- **Adverts:** `train_adverts.py` draws `assets/textures/station/train_adverts.png` (2048 x 768, twelve invented
  cards, no blue or orange, no real brands); `train_adverts.glb` is the cove panels, drawn by `TrainView` with
  `LookMaterials.printed`, every other car turned about so neighbouring cars differ.

## Verified

- Tests: `test_se1_entrance.gd` (8: the street and sign lit; the block solid and facing the hall, the doorway opening
  only onto it, no floor past it, the lamps' floors, the file's `floor`, `plain_reaches` taking it, the model filling
  its block) and `test_tq2_train_rails_adverts.gd` (7) and QA's `test_tq2_qa.gd` (5) with the train, fixtures, station,
  props, assets and flicker files, 183/183 on attempt 2; 300 Subway tests before the merge. `test_tq1_trains_qa.gd`
  allows kind 9.
- Faces: `tools/coplanar_models.py fix` on the entrance and every train model; bounds unchanged.
- Pictures, before and after (lavapipe, in game): `art/blender/subway-entrance/` and
  `art/blender/subway-trains/tq2/` in the project files.

## Left for the owner

- The orange's vividness and the street's daylight on his card: N50 and N51 in the owner's checklist and
  docs/PLAYTEST.md's "Subway's street entrance" and "Subway's train rails and adverts".

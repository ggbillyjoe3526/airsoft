# TQ2 · Subway's street entrance, smooth train rails in a brighter orange, and adverts in the cars (Beta)

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-21 | 1 | build thread and one worker | touched tests 177/177, gates green in the worker | pending | – |

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
  (`station_entrance.py`, 4,731 of 5,000 triangles, `PropDressConfig.models`): a tiled passage, a stair of 15 risers
  and an escalator side by side climbing 2.6 m, a glass balustrade, the street exit at the top (pavement, kerb, road,
  railing, lamp post and a painted street of shop fronts under the sky), a black sign fascia over the doorway and a
  locked folding lattice gate at the block's face. Look only: spawns, nav, routes and cover are unchanged; the gate
  is the block's face, so nobody walks, climbs or shoots through it.
- **Its lamps:** two lamps under its ceiling. A plain roof's lamp light reaches to `MapData.floor_under`; with no
  floor block under them it would fall back to the ground (0 m) and light 9 m too far. A lamp may now carry its own
  `floor` in the file (`MapData.roof_lamp_floors`, NAN when left out), which `RoofView.plain_reaches` takes first.
- **Rails** (`train.py`, worker): 12-sided tubes with bends in steps of 22.5 degrees or less; each seat rail one tube
  bending up into the cove onto a flat plate, no brackets; door poles with plain plates, no collars; the draft
  screen frame one arc; every end and gangway handle a single D tube. They moved into their own models
  (`train_poles`, `train_end_rails`, `train_gangway_rails`), the body's and ends' budgets lowered by what they gave
  up: a car is about 20.7k triangles (17.8k before).
- **Orange** #c0652f to **#d8692a** (hue 21.7, Beta 28): the train's stripe and poles, the station signs' stripe
  (`signs.png` regenerated), the moquette's rings (`look_surface.gdshaderinc`), and the tests' Subway exemption.
- **Adverts:** `train_adverts.py` draws `assets/textures/station/train_adverts.png` (2048 x 768, twelve invented
  cards, no blue or orange, no real brands); `train_adverts.glb` is the cove panels, drawn by `TrainView` with
  `LookMaterials.printed`, every other car turned about so neighbouring cars differ.

## Verified

- Tests: `test_se1_entrance.gd` (7: the block solid and facing the hall, the doorway opening only onto it, no floor
  past it, the lamps' floors, the file's `floor`, `plain_reaches` taking it, the model filling its block) and
  `test_tq2_train_rails_adverts.gd` (7) with the train, fixtures, station, props, assets and flicker files, 177/177
  after the merge; 300 Subway tests before it.
- Faces: `tools/coplanar_models.py fix` on the entrance and every train model; bounds unchanged.
- Pictures, before and after (lavapipe, in game): `art/blender/subway-entrance/` and
  `art/blender/subway-trains/tq2/` in the project files.

## Left for the owner

- The orange's vividness and the street's daylight on his card: N50 and N51 in the owner's checklist and
  docs/PLAYTEST.md's "Subway's street entrance" and "Subway's train rails and adverts".

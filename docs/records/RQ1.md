# RQ1 · The Range given a firing point and detail

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-17 | 1 | build thread | ✓ touched tests (CI runs the rest) | 7/8 Retry | check 1: no reference photos; rest bag a blob, chrono a box; grey wall stripes; murky shade; zones unseen at 5 m |
| 2026-11-17 | 2 | build thread | ✓ touched tests (CI runs the rest) | pending | |

## Decisions

- **Asked for by the owner.** William's 0.1 Beta 2 playtest, item 14 (2026-11-17): "Give the range models more detail
  and higher quality. Improve the lighting/graphics to match the rest of the game. It looks too dull and plain visually
  right now. Give me screenshots."
- **The Range is outdoors.** It stands in its own lot beside Depot's yard under the day sky, not inside Depot's hall
  (the brief said indoors; the map's data says otherwise), so it keeps the sun and shadows Woodland has.
- **The lighting is kept; the content is what was plain.** The Range already uses the default day look (the same sun,
  sky and exposure as Woodland, `LookConfig`). Its pictures read flat because nearly everything in them was one timber
  tone on one grey slab. The fix is variety and shade: a sheltered firing point (its roof casts the shade the line
  stands in, lit by GI from the sunlit slab), coloured signs and a red flag.
- **A firing point** (`range_extras.py`, look-only fixtures in `dressing.fixtures`): a steel canopy over the line
  (Warren trusses, knee-braced columns, purlins, a light grey roof underside, LED battens lit as Lens, lane boards 1 to
  4 printed on the sheet), a range flag (Depot's fire red, rippled, with its "range hot" notice), the rules board in a
  timber frame and three signs (chrono, eye protection on both side walls, safe zone). Words and pictograms are drawn on
  one 1024² sheet (`range_signs.py`, cells in `range_cells.py`), no brand. The canopy and flag cast shadows
  (`StationFixturesConfig.shadow_models`); the signs don't (they sit flat on walls).
- **The shelter's shade lit by its battens.** Drawn as fixtures are (no GI), its shade took the open sky's blue; in the
  GI (SDFGI) it went near black, the bounce from the sunlit slab too weak. So the shelter and flag stand in the GI
  (`GI_MODE_STATIC`, as they cast shadows) and the four LED battens are lights (`StationFixturesConfig.lamp_points`, an
  LED's cool white, 8 m reach, energy 3, no shadow), shown with Settings › Graphics › Lamp lights (High and Ultra) like
  Subway's lamps (the tunnel lamps' warm colour at 1.5, attempt 1, left the shade murky brown). Where the GI and the
  lamp lights are off, the shade keeps the sky's fill.
- **The canopy is look only.** It has no block and no collision: it stands 3.3 m and higher over the line, above any
  BB's path from the firing line, so it changes no shot.
- **Four shooting benches are solid** (`furniture` blocks at x ±2.5 and ±7.5, 0.5 m behind the line, 1.8 × 0.9 × 0.8 m):
  a player can lean on and shoot over them. They sit between the lanes' firing points, so no practice spot is blocked
  (`test_practice_spots`). Each carries a rest bag, an ammo can and a bottle of BBs (`shooting_bench.py`, budget 4,200).
  Finish `timber` (`SiteLook.kind_finishes.furniture`).
- **The bench's rest bag** is a pillow lying along the top, its ends flat sewn seams still wide (ears), a groove pressed
  along its top where a forend beds, a stitched band over each seam and the neck's cord (attempt 1's was a smooth blob).
- **No reference photos for the new furniture.** William's folders (`art/references/maps/william-2026-11-09/`) hold the
  wall bay, targets, flag pole and roof truss, not a shooting bench, chrono table or range shelter, and the cloud can't
  fetch photos; the shelter follows his roof truss photo's Warren trusses, the wall his range wall photos.
- **The chrono table** (`chrono_table.py`, budget 3,700) is a block by the back wall at (-4, 5.6), under its sign: a
  folding table with a tube chronograph (two sensor gates on collars, the display between them, a stand of two feet), a
  clipboard, a tray of BBs, a bottle and a spare magazine.
- **Concrete kept downrange.** A gravel lane from the line to the backstop was tried (a second floor 0.09 m thick, which
  SiteLook draws as gravel): at Ultra it read near white and tiled, plainer than the stained concrete, so it came out;
  the one slab is as it was. A painted firing line (`dressing.site.lines`) runs across at z 0.
- **The wall bays weathered** (`range_wall_bay.py`): three variants of the wall and the backstop each
  (`PropDressConfig.variants`), boards mixed in three timber shades (William's photos: green-gold, paler, darker; a grey
  sun-bleached fourth, attempt 1, read as stripes across every bay), each corner its own shade so a board fades end to
  end, screw heads at the board ends and the middle batten, grime at the foot. The bevel was taken off: a chamfer pulled
  the bay's end faces 3 mm short and opened slits where bays meet (`test_bp9_flicker_qa2`). Budgets 850 and 1,150 (804
  and 1,088 triangles).
- **The targets detailed:** the plywood figure's head ring and chest zone painted a darker tan proud of the board with
  34 dark BB scuffs 12 to 20 mm across (attempt 2: darker and larger, to read at 5 to 10 m); the steel plate's paint
  chipped to bare steel at 18 spots, its face kept at the simulation's plate.
- **The crate dressed** in its model.
- **Rebaked** (`tools/bake_light.gd -- range`); `test_wl9_qa`'s Range play hash renewed for the new blocks.

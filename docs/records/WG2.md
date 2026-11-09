# WG2 · Woodland's ferns, bushes, logs, root plates, woodpiles and saw bench from the owner's photos (Dev)

**Review:** pending (attempt 3)

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | build thread | see Verified; performance Pass, QA Fail | Retry 5/8 | the models against the photos, gaps in boxes that stop BBs, two untracked files |
| 2026-11-09 | 1, fix round 1 | build thread | QA Pass | Retry 6/8 | the models against the photos; a root plate you could see through where it stops BBs |
| 2026-11-09 | 2 | build thread | focused tests | Retry 6/8 | the models against the photos; the saw bench's box open under its log |
| 2026-11-09 | 3 | build thread | see Fix rounds | pending | – |

## Goal

Dev 3's Woodland models, group WG2 (`art/woodland-model-list.md` in the project files, photos in
`woodland-models.zip`): 10 fern clump, 11 bush, 12 root plate, 13 cordwood and board stack, 14 fallen log and 18 saw
bench, modelled in Blender from the owner's photos. Each model fills its block's box, so cover, collision and sight
lines stay where they were; the ferns and bushes, drawn by code as ellipsoids, are drawn as the models.

## Approach

- **Models** (`tools/blender/maps/`, vertex-coloured like the Kenney props, through `mapkit.py`; Woodland's shared
  parts and colours in `woodkit.py`): `fern.py` (384 of 400 triangles), `bush.py` (1,500 of 1,500), `fallen_log.py`
  (5, 6 and 8 m, 1,400 of 1,500), `root_plate.py` (3,877 of 4,000), `cordwood.py` (three 2 m sections, 1,078 to
  1,106 of 1,200; the boards 1,206 of 1,500), `sawbench.py` (1,943 of 2,000) and `earth_bank.py` (320 of 340). Each script
  ends with `woodkit.fit_box`, so a model's bounds are exactly its box.
- **Grounded props** (`PropDressConfig.Lay.GROUND`, `PropLayout._ground`): Woodland's blocks reach from under the
  lowest ground to their top over the ground at their middle. A fallen log, root plate, saw bench or board stack
  stands on the ground at its box's middle, along the box's long side, half turned at random, stretched so its top
  meets the box's top. Where the ground under the box falls away more than `bank_from`, an earth bank fills the box
  under it, its top tucked 3 cm under the ground line.
- **The map** (`tools/woodland/build_map.py`, `layout.py`): logs dress as the nearest fallen log by length, log
  stacks and log piles as cordwood, windthrows as the root plate; the shed's log pile is tagged `sawbench`, the
  boards' stack `boards`. The Badger run's log lining keeps the old log. The woodpiles and log stacks are 1.8 m
  (were 2 to 2.6), at the owner's word; the camp gate screens keep their 2.8 m (see Decisions).
- **Woodpiles** (`PropDressConfig.grid_cells`, `variants`, shared with RK1's racking): one section the stack's height, so the ragged tops
  show no seams, each cell one of three sections at random, so a stack doesn't repeat one.
- **Ferns and bushes** (`BushView`): an instanced draw a kind for every `WoodsConfig.bush_chunk` (40 m) square, so a
  bed out of view is culled; the ferns cast no shadow (`fern_shadow`). The foliage up to `WoodsConfig.fern_tallest` as the fern,
  the rest as the bush, each stretched to its plant, turned and shaded at random. Without the models they fall back
  to the ellipsoids.

## Decisions and defaults

- **The owner, 2026-11-09:** "make the woodpile/cordwood stacks more uneven and less tall." The stacks are 1.8 m, still
  a standing body's height (`BodyConfig.height`), so on level ground they block what they blocked; from high ground
  you can now see and shoot over them. The camp gate screens stay 2.8 m: at 2 m the slopes north of the west camp
  saw its spawns (`test_woodland_layout`, test_no_spawn_is_seen_from_outside_its_camp).
- **The saw bench is an original yellow machine:** the photos' orange and blue are the team hues.
- **Log piles take the cordwood too**, at their knee height; there is no separate log pile model.
- **Fallen logs** take the nearest of 5, 6 and 8 m and are stretched to their box.
- **The root plate's crowns** are plain dark green, still in needle, so the box reads as the tangle that stops a BB;
  green and brown blotches read as camouflage.
- **The earth bank's budget**, 340 triangles, is this task's; the owner's list has no row for it.
- **The boards** wear a corrugated sheet on top, as stacks in the photos are covered.
- **The saw bench's log rests on two sawhorses** (an A-frame under a top beam), not the photos' X-trestles: an X's
  legs would pass through the log in the 1.4 m box.
- **The earth bank** takes the ground's own earth (`LookConfig` "earth") and litter: in dark soil it read as a black
  slab in the sawmill shed's shade.
- **No moss lid over a modelled log** (`WoodsConfig.moss_dresses`, `WoodsShapes._moss`): the woods' moss slab over a
  log's box floated as a flat olive sheet over the root plates; a log drawn as a model wears the model's own moss. The
  moss roll is still drawn for every log, so the plain logs keep theirs.
- **The root plate's crowns fill the box** to the ground along its length: it stops BBs end to end, so no daylight
  shows through it.
- **Colours:** every colour in `woodkit.COLOURS` is checked off the team hues the way `field_checks.gd` measures them
  (linear HSL), so warm wood keeps a linear hue of 36° or more, or a saturation under 0.28.

## Verified

- `tests/unit/test_wg2_woodland_models.gd`: every grounded prop inside its box up to its top; earth banks only under
  grounded props, inside the box and under the ground at its middle; every woodpile section as tall as its stack and
  inside its box; stacks 1.8 to 2 m over the ground; the tunnel's lining keeps its log; every model within budget.
- `test_bushes` (ferns and shrubs, each one draw, filling each plant on its foot; the ellipsoid fallback; the
  models' colours off the team hues), `test_props`, `test_look`.
- Pictures rendered in the game (Forward+, lavapipe) at eye height from the same spots on main and on this branch,
  posted to the owner (`art/blender/woodland-wg2/`).
- `tools/check.sh`: see the pull request.

## Fix rounds

- Critic, attempt 1 (Retry 5/8), and what changed:
  - Fern: a rosette of twelve arching fronds with three young ones standing up out of it, no core cone, wider
    leaflets. Not the low 2:1 rosette asked for: a fern bed hides a crouched player (1.25 m) by the rules, so the
    leaves must stand about a metre high where the player sees them, or a bot crouched in a bed would show.
  - Bush: a skirt of leaf clusters down to the ground, four stems not seven, faceted shading (no glossy ball).
  - Root plate: the plate 1 m thick (was 0.72), as wide as the box; the crowns long ragged sprays along the trunk.
    The plate can't be broader than tall: the box is 2 m across and 2.2 m tall.
  - Fallen logs: the bark in long unbroken furrows, moss in broad patches of one green (the small patches of other
    shades read as a camouflage print). Their girth is the boxes' (0.7 to 0.8 m), so not thickened.
  - Saw bench: a bigger black blade hood; three long logs stacked along the back so the low box reads solid.
  - Cordwood: pieces stand out of the face up to 10 cm; three sections mixed at random (`variants`); no posts.
  - The changelog note and the test's `.uid` are committed.
- QA, attempt 1 (Fail), and what changed:
  - The cordwood's dark gap read near Beta orange (`test_props`); it is duller.
  - The camp gate screens back to 2.8 m: at 2 m the slopes north of the west camp saw its spawns.
  - `bush_chunk` is held at 1 m or more; a test lays a root plate off the map's data (no terrain, a box lower than
    `ground_least`, a box long in z).
- Performance (Pass) advisories taken: the ferns chunked by area and casting no shadow.
- Critic, fix round 1 (Retry 6/8), and what changed (attempt 2):
  - Fern: a shuttlecock of nine fronds from a small crown, each a bare stalk then paired leaflets joined to the rib
    and arching over; both sides in the same greens, so no dark cone at the foot.
  - Bush: flat leaf sprays (six-pointed, cupped) spread evenly over a dome narrowing to its top, the core flat dark
    and faceted (no gloss).
  - Root plate: a ragged notched disc the box's full width, earth darkening to its middle, snapped roots round its
    rim, no light stripe; the crowns tiers of drooping needle sprays from the ground to near the top along the length.
  - Fallen logs: furrows a close dark brown, broken along their length; moss in a few broad patches; the bracket
    fungi duller (they read as white stickers).
  - Saw bench: sawhorses at the front under the log, the stacked logs behind them; nothing passes through a log.
    The black slab was the earth bank in the shed's shade: now the ground's earth colour.
  - Cordwood: the stack's ends the rounded bark sides of the pieces, two a row, each standing out its own amount;
    loose pieces on a dark top; warmer ochre wood (`Cut`, `Heart`, `Ring`, `Split`, linear hue 37 to 41°) and dark
    bark on the pieces' round sides.
  - Found in the pictures: a flat olive sheet over the root plates was the woods' moss lid on the block's top; it is
    left off logs drawn as models (test_no_moss_lid_floats_over_a_modelled_log).

- Critic, attempt 2 (Retry 6/8), and what changed (attempt 3):
  - Fern: no bare stalk; six fronds of sixteen narrow leaflet pairs from the crown at the ground, small at the foot
    and longest past the middle; inner fronds tall and arching, outer ones low and spreading.
  - Bush: 540 small leaves (about a fifteenth of its width) over a lumpy dome, a dark faceted leafy mass under them.
    Its width to height is the map's (each plant's radius and height), not the model's.
  - Root plate: the plate about a metre thick at its middle. The crowns still fill the box to the ground: the box is
    the windthrow's collision, and attempt 1's critic failed see-through gaps where it stops BBs (kept, see
    Decisions); thin sparse sprays would bring them back.
  - Cordwood: twelve rows (were nine) of smaller wedges, halves and quarters, half with a bark band; no grey pieces.
  - Logs: furrows run the length, broken now and then; the moss a darker green.
  - Saw bench: the machine upright (taller than long); three logs lie under the sawhorses' log, so the box's front
    is solid below it; the logs' bark a lighter grey-brown so it reads.

## Outstanding

- How the ferns, the root plates and the lower woodpiles feel in play, and the frame rate in the fern beds on Low:
  `playtest/0.1-dev3-checklist.md` › Woodland's models (WG2).

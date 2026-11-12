# SM2 · Subway's escalators, lifts, stairs and railing

**Review:** 6 attempts (past the cap: the project keeps fixing until the critic passes) · critic Accept 7/8 · qa Pass · performance Pass

The owner (2026-11-12): "Begin work on subway models now." SM2 is models #14 to #18 of
`art/subway-model-list.md`: the escalator banks, the lift car and doors, the spiral stair, the stair handrails and
step nosings, and the balustrade railing, after the owner's photos in `art/references/maps/subway/14-escalator/` to
`18-railing/`.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Opus 5.5 (build thread) | pass | Retry 7/8 | the escalator's proportions, finishes and the lift's tiled jambs against the photos |
| 2026-11-12 | 2 | Opus 5.5 (build thread) | pass | Retry 7/8 | the decks and capping still read beige, the lift indicator small, the leaves' panels apart, a dark stair skirting |
| 2026-11-12 | 3 | Opus 5.5 (build thread) | pass (CI) | Retry 7/8 | the landing display unlit, the vision panel two slits, the decks dull and faceted, wide yellow step edges, the railing posts |
| 2026-11-12 | 4 | Opus 5.5 (build thread) | pass (CI) | Retry 7/8 | the landing display's window still dark, the escalator's sides dull and its edges cream, the half panes narrow |
| 2026-11-12 | 5 | Opus 5.5 (build thread) | pass (CI) | Retry 6/8 | the safety yellow rendering cream, banded deck tops, dark newel ends, the landing display off its frame, two changelog lines |
| 2026-11-12 | 6 | Opus 5.5 (build thread) | pass (CI) | Accept 7/8 | – (check 7 non-blocking: a shader comment and untyped test loops, fixed after) |

## What changed

- **Escalators** (`escalator.py`, 7,412 and 6,764 triangles of 8,000): each bank is one model laid over its ramp and
  its three decks (`PropDressConfig` SET). Each bank's two escalators are 1.2 m wide between their balustrades, two
  abreast (the owner, 2026-11-12: "Escalators need to be narrower. Only wide enough for 2 people."; they were 3.2 m):
  `layout.py` gives each bank a 1.2 m middle deck and a deck from each escalator to the wall, solid 1 m blocks on the
  slope like the old middle balustrade. The shafts, their walls and ceilings are unchanged. It has ribbed steps with yellow sides and nosings, landing plates and
  combs, newel-ended stainless balustrades, black handrails looping into their inlets, skirting brushes, stop buttons,
  and bronze uplighters on the middle deck.
- **Lifts** (`lift.py`): `LiftView` draws the car model (5,622 of 6,000) turned to its door, plus a landing doorway at
  each stop (732 of 1,200, its arrows a lit 2). The leaves (48) and push buttons (128 of 160) are scaled to each use. A lift unlike the
  model keeps the plain boxes: a different well, door or wall, or a door facing s or w (`LiftViewConfig.model_*`). The
  buttons are now real lift size (`button_size` 52 mm, was 90 mm). The car's inside is from general knowledge, as
  the list asks.
- **Spiral stair** (`spiral_stair.py`, 5,854 of 6,000): five risers a flight, with ribbed yellow nosings, the corner
  landings and soffits, and a black handrail on brackets up the outer wall. It is laid over the ten flights and nine
  landings; the core stays the station's tiled pillar.
- **Platform stair** (`platform_stair.py`, 1,968 of 2,000): two flights of twenty treads, each tread's middle on the
  ramp's slope (feet within 10 cm). The nosings are ribbed aluminium, yellow on the top and bottom steps, with a sloped
  tile skirting. Round steel handrails run down both walls, level over the half landing. The handrails stand 0.922 m
  over the ramps' box: `PropDressConfig.set_heads`, new, grows a SET model's fit by this much.
- **Railing** (`railing.py`): a kit of four pieces (a chamfered bar, the round-topped capping, the foot rail and a
  post). `RailingMesh` (`game/map/railing_mesh.gd`, `MapStyle.railing_look`) fits each piece to its bar or rail of
  `Railings.parts`, so the steel drawn is the steel a BB meets. Posts stand on panel-end bars, as wide along the run as
  a bar; floor plates sit inside the run's box. A 5 m run is 728 triangles of 800. MapLevel falls back to the old
  boxes if a piece can't be read.
- **Shared** (`transit_kit.py`): paints, a mesh builder, filleted tubes, knobs and rings, and `report`, which fails a
  model that is over budget or off its box by more than 5 mm. The props' shader draws ribs where UV.x is under -1
  (`map_kit.ribbed`, 8.5 mm pitch, fading to the average far off), for step cleats and nosings that triangles can't
  carry.
- **Colour**: the safety yellow (`transit_kit.SAFETY`, `#f0c814`) on the escalators' edges, combs and stop plates
  and the stairs' nosings is drawn at full colour (`PropDressConfig.full_colour`: those four models' material sets
  `keep_by_alpha`, so their painted parts skip the look's pull to 60 % of a paint, which drew the yellow cream; their
  other paints are greys the pull leaves as they are). On screen it is about hue 45°, saturation 0.5 to 0.7 after
  the tone map (was 0.27). `docs/ART.md` › Colour names it as an exception.
- **Escalator rims**: the decks and newel ends are one strip with shared corners, so they shade smooth (separate
  quads drew flat bands), in bright stainless (`#d0d3d4`, untoned). Each newel's round end runs to its furthest point
  out and drops plumb from there, a drum on its foot with no overhang; the handrail runs on round it and into it.
- **Landing display**: seated on the architrave's head, as in the photo (it stood 4 cm over it).
- **Map**: `layout.room(..., dress=)` and `SPIRAL["dress"]`. `build_map.py` writes them on the rooms' ramps, the
  escalators' decks and the spiral's landings in `data/maps/subway.json`. Apart from the escalators' decks, no box
  moves.

## Decisions

- **The escalators narrowed with decks, not narrower shafts**: the shafts keep their walls, ceilings and the openings
  into the halls, and the wide middle deck carries the uplighters as in the photos. The decks stop BBs and bodies,
  as the middle balustrade did; a player can't climb onto them (1 m, over the 0.95 m ledge).

- **No middle handrail on the platform stair** (the photos have one): it would stand in the walkway and stop nothing,
  so the stair keeps its full width.
- **The spiral's handrail ends below the top flight**, turned into the wall, so it stays inside the stair's box.
- **The escalator uplighters are unlit** shapes; the station's own lamps light the shafts.
- **Lift models only for lifts built like them**: Subway's two both match. Another map's lift keeps the boxes until a
  model is built for it.
- **The railing's posts add no steel a BB could meet**: they are a bar's width along the run and deeper across it. At a
  grazing angle a BB may pass a post's edge it seems to touch (2.5 cm).

- **Critic attempt 1 fixes**: the middle deck is 1.2 m (it was 2 m), so a bank reads as one escalator pair; the
  steps are dark steel grey, less dusty (`model_wear` 0.25) and shinier, the stainless brighter; the balustrade body is
  smooth-shaded and the decks have seams every 1 m; the lift landing's linings run through the whole wall, 3 mm in
  from its opening, so no tile shows from inside the car, and the display's arrows are lit; the stair treads are
  ribbed and the skirting lighter.
- **Critic attempt 2 fixes**: the beige on the decks, steps and the railing's capping was the shader's settled dust,
  so Subway's escalators and stairs (`model_wear` 0.08 and 0.12) and the railing (`RailingLook.wear` 0.15) are drawn
  swept; the escalator's whole rim (decks and newel ends) is a cooler, darker brushed steel with joints 10 mm wide;
  the landing display is the architrave's width (1.28 by 0.26 m) with big lit arrows; each leaf carries half a vision
  panel at its meeting edge and `LiftView` turns the other leaf round, so the two halves meet as one panel; the stair
  skirting is a pale grey-green tile (dark, it read as a gap under the wall). The fourth handrail loop is whole: it is
  seen edge-on from the top of the bank (picture esc-loop).
- **Critic attempt 3 fixes**: the landing display's arrows are their own model (`lift_landing_lit.glb`,
  `LiftViewConfig.landing_lit_model`), drawn lit in the buttons' unshaded material at each landing; each leaf's half
  pane runs to its meeting edge, framed on its other three sides, so the two halves read as one pane split by the
  leaves' hairline (0.28 of the door's height, as in the photos); the decks are brighter brushed stainless, smooth
  shaded, the newels' round ends in 16 steps (10 showed flat bands); the steps' yellow edges are 30 mm (45 read as a
  yellow step from the top).
- **Critic attempt 4 fixes**: the landing display's window carries a lit dot-matrix row of chevrons (wordless) beside
  its arrows, both in the lit model, drawn at the lit button colour times `LiftViewConfig.landing_lit_gain` (2.5, so
  they glow past the tone map); each half pane is 0.22 m wide (the pane 0.44 of the door's width, as in the photos);
  the balustrades' sides are a brighter stainless (0xD6D8D7) and the decks 0xC4C7C8; the steps' edges, combs and stop
  plates are a stronger safety yellow (0xE8CC22, hue 52°, clear of Beta's orange).
- **The lift door is 1.1 by 2.1 m** (0.52 wide to high; the photos' about 0.49): it is the play size of
  `layout.LIFT_DOOR_W` and `LiftConfig` that MT2 built and tuned the lifts round, two abreast through it, so the
  model follows it.
- **Kept against the critic**: the railing's bar pitch is the sim's (gameplay, budget-bound); the posts stay a bar wide
  along the run, by the owner's railing ruling (`docs/DECISIONS.md` › Maps and modes, SR1: a railing is drawn as the
  bars and rails a BB meets, `RailingConfig`); a post 2.5 bars wide would show 2 cm of steel each side a BB flies
  through, and making the posts stop BBs is a play change for the owner; the bars end on the foot rail as
  the sim's do; the stair handrail is already 44 mm.

- **Posters and signs (the owner, 2026-11-12: "Add posters and signs to all the environments. Maybe only one sign
  in the elevator. Posters down the walls beside the escalator.")**: the lamps and extras thread (SM5) owns the poster
  and sign sheet and places the posters down the escalator shafts' walls and the station's signs, from the shaft
  measurements this thread sent it. This task adds the car's one sign: a white enamel plate on the back wall's middle
  panel at eye height, four standing figures for its capacity, wordless, in the car's vertex colours (SM5's sheet is
  still changing, so it is not tied to it). The blank plate over the car's door is gone, so the sign is the only one.

- **The lower shaft's posters (merged with SM5B)**: the narrower escalators put a deck between each escalator and the
  shaft wall, where SM5B's posters hang; the game's fixture test takes each deck piece as its whole box, which reached
  the lower shaft's posters at 1.7 m. The lower row now starts at -3.5 m, so each poster sits inside one 1 m ceiling
  step and one deck piece's lower half, at 1.9 m (the window that clears both runs 1.8 to 2.05 m); still 6 a wall.
  `build_map.py` now hands `fixtures.place` the escalators' deck pieces as boxes nothing stands in, so a spot the test
  would refuse is left out and named when the map is built.

## Known issues left

- The landing doorway uses 61 % of its budget and a leaf 16 %: both are flat steel in the photos, and more triangles
  would add nothing seen.
- A lift whose door faces s or w would need a mirrored car and landing model (none does today).

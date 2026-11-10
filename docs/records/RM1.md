# RM1 · The practice range's own models

**Review:** critic Accept 8/8 (fifth review under the owner's default rule, then its near-miss re-run) · qa Pass ·
performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (build thread) | QA, performance pass | Retry 5/8 | Hexagonal sandbags, a sparse generator, lavender greys, the plate's neck wedge, the toilet's frame corners, housekeeping |
| 2026-11-09 | 2 | Opus 5.5 (build thread) | QA, performance pass | Retry 6/8 | Sandbag proportions and faceting, the generator's chamfered bends and gap under the tank, faceted heads, housekeeping |
| 2026-11-09 | 3 | Opus 5.5 (build thread) | full checks pass | Retry 6/8 | The standing cut-out's outline folding back at the neck, square sandbags, the toilet's square door, the tote's valve and label, record |
| 2026-11-09 | 4 | Opus 5.5 (build thread) | full checks pass | Retry 7/8 | The swinger counted once a leg (1,512 drawn), the tote's valve half size, the toilet's front black in the fence's shade, the figures' proportions (owner's call); default taken (figures keep the hit volume's outline, coordinator confirmed the owner's rule) |
| 2026-11-09 | 5 | Opus 5.5 (build thread) | full checks pass | Retry 7/8, near-miss re-run Accept 8/8 | The tote's full-size valve ran through the cage (moved into a clear bay) |

## Decisions

- **Built from William's photos** (`reference.zip`, 2026-11-09, unpacked at `art/references/maps/william-2026-11-09/`):
  round white steel plates on a timber post in a black H-stand, hung by a hooked neck from a pin; the figures as his
  two wooden peg photos (straight body with a collar, standing; cone on a foot ring, crouched); horizontal fence boards
  on a block plinth; fat tan sandbags in stretcher bond; a grey and green-grey moulded toilet; an IBC in its cage on a
  pallet; an open-frame generator. No brands, no writing.
- **Hit sizes kept.** A plate's face is the simulation's disc (radius 0.2 or 0.1 m, its front through the plate's
  point); a figure's outline is the hit volume's (head ball 0.13 m at 1.62 m, body 0.2 m round to 1.5 m, crouch 0.62 m
  lower) on its 0.04 m hinge plate, its face through the volume's middle.
- **The figures are flat plywood cut-outs** (William, 2026-11-09: "flat (like a thick piece of cardboard) and 2D not
  3D. keep the outline of the figures"): a 0.025 m board in each peg's outline, its hinge leaf behind it; it falls back
  about the hinge 0.039 m behind its face (RangeViewConfig.hinge_behind). The hit volume stays round: a BB from the
  side still hits a figure seen edge-on.
- **Figure wood is pale beech** (`dcca9e`), not the old plywood tan (`b89466`, 8° from Beta's orange in linear hue).
- **No blue toilet:** his photos' blue walls are Alpha's hue, so the walls are grey with his green-grey door, both
  lighter than the photos so the toilet's front doesn't go black in the fence's shade in game.
- **The generator stands in a drip tray with two fuel cans:** its block is a 1.2 m cube, bigger than a portable
  generator, so the tray fills the footprint and nothing is stretched. The blocks stay as they are (default; cover and
  collision unchanged).
- **The backstop has no net:** his photos show none; it is the same fence 5 m high.
- **Budgets:** the plan's, but the sandbag section is 2,304 / 2,400 triangles, not 800: sixteen round bags 0.6 x 0.3 m,
  each with a sewn seam and a tied neck (the critic's ask), about 38 sections on the map, drawn as one MultiMesh; and
  the generator 2,968 / 3,000, not 2,500, for its round bends, a full engine and round sockets (the map has one). The
  rest are within the plan, counted as drawn (a part drawn twice counts twice): plate and stand 768 / 800, swinger
  frame 1,064 / 1,500 (two legs, two feet), cut-out 384 / 600, motor box 336 / 800, rails and trolley 794 / 1,500
  (two rails, two stops), wall bay 632 / 900, toilet 1,926 / 2,500, tote 1,372 / 2,000, distance board 164 / 300
  (two posts).
- **Sandbags two deep:** each section is two rows of bags 0.6 x 0.3 m along the wall, the offset courses ended by a
  whole bag laid across it, so a line's end never shows a cut bag. Bag ends are closed by fans (`Kit.fan`), so no cap
  triangulates across itself.
- **Figures and plate posts keep the simulation's sizes** (default; the critic asked William to choose): his pegs'
  heads are about as wide as their bodies and his plate's post is wider, but a cut-out's outline is the hit volume
  (head 0.13 m round on a body 0.2 m round) and the post is RangeConfig.post_width, so what you see is what a BB hits.
  Changing them is a balance change for William to ask for.
- **Team hues bound the colours:** the sandbags are as warm a tan as Beta's orange allows (`c4b28a`, 21° off it in
  linear hue), the generator's frame a saturated yellow (`e8cc1c`), the jerry cans olive, the tote's cap black (red
  would be Beta's) and its valve lever yellow. The steel and plastic greys are neutral, not the palette's lavender
  greys.
- **The fence's shadow gaps show a shaded timber core, not black,** so they don't shimmer at range.
- **The kit rack and crate are not here:** the racking and small-props threads model them.
- **Rebased on DH1 (#262):** its check that lower walls keep their boxes now lets a wall draw the model its block
  names (the Range's fence bays and backstop), and still never a hall wall.
- **Rebased on main of 2026-11-10** (FS1, RK1, DM1, the Woodland models, SL1, SL2, UG1, SX1): the props take SL2's
  wear through PropDress; the Range's card is re-rendered over FS1's skyline; FS1's face test now rays every RM1
  model and part too (`test_model_faces`; all under 1.5 %, the limit 2 %).

## Known issues left

- The figures' heads are narrower than William's pegs' (0.65 of the body's width, not about 0.92), because a cut-out's
  outline is the hit volume: his call whether the range's hit volume should change.
- The toilet's side ribs are moulded swells, not the photos' deep recesses; the props are vertex colour only, no grain
  or weave texture.

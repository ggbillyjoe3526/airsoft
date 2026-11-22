# WH1 · Woodland's thickets and trunks stop BBs and sight where their plants are drawn

The owner's playtest of 0.1 Beta 2 (22 November), item 5: "still seems to be some issues with hit detection/spotting
in woodland map. the highlighted area i previously uploaded a screenshot of is still causing some issues. maybe adjust
the tree placement? make sure the map is still balanced if the map is changed. also, make sure to go over hit/spot
detection again to get it more accurate."

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-22 | 1 | Opus 5.5 (build thread) | ✓ (touched tests, 318 in 24 files, and QA's; CI green on a17f32f) | 7/8 Retry | 1: Plant The Bomb not yet measured |
| 2026-11-22 | 2 | Opus 5.5 (build thread) | ✓ (CI on the head with main merged in) | 8/8 Accept | – |

## How it was measured

`tools/sight_truth.gd` (new, dev only) builds every Woodland plant as drawn: the spruces, trunks and crowns PropDress
places and the ferns and shrubs BushView draws, each leaf card cut out of its sheet where the shaders cut it (WQ1),
bark solid. Seeded lines run from a standing eye 6 to 40 m off to the knee, hip, chest and head of a standing body,
and each is judged twice: by the game (`bb_ray` or `sight_ray`, then the counted leaves) and by the drawn plants. A
line the game stops where nothing is drawn is **unseen** (a BB or a spot stopped by nothing on screen); one a drawn
plant hides that the game lets through is **through**. Spotted misses are the bodies whose chest or head is in sight
as drawn that the game sees neither of. The circled area is the stream's steep east bank west of Hut row (x 11 to 21,
z -4 to 10): five thicket blocks whose spruces stand half sunk in a slope rising up to 2.8 m across a block, with a
young and a grown pine.

| Lines (all four body points) | Circled area, 3,600 a point: main | WH1 | Whole map, 4,800 a point: main | WH1 |
|---|---|---|---|---|
| Unseen, all | 957 | 549 | 1,094 | 707 |
| Unseen at the chest, by a thicket | 105 | 54 | 55 | 24 |
| Unseen at the chest, by a trunk (pines, oak) | 139 | 79 | 211 | 136 |
| Through, all | 176 | 203 | 145 | 168 |
| Spotted misses | 23.2 % (312 of 1,345) | 13.5 % (180 of 1,335) | 21.7 % (317 of 1,463) | 13.8 % (200 of 1,454) |

## Decisions

- **A thicket's tiers stand round each spruce (TierSteps).** Each tier's boxes are cut round every spruce PropLayout
  stands in the block, three corner-cut boxes a spruce (one square where a tier reaches under half the drawn
  half-width), clipped to the block and run on as one box where neighbours' meet. TV1's tiers ran a touched side out to
  the block's face, and its seam walls filled a row's ends: on the circled bank those stood where no spruce is drawn
  (the spruces half sunk in the slope), and took half the thickets' unseen stops. A thicket other rows close on every
  side stands as its box (none on Woodland today). `docs/DECISIONS.md` › Woodland's thickets and trunks.
- **The spruce's reaches are re-measured on its leaf cards (MapStyle.tier_steps).** TV1 fitted the tiers before WQ1
  turned the spruce into cut-out cards. The 50 % contour of the model as drawn (`sight_truth.gd profile`): 0.15 under
  0.08 of its height (the bare foot), 0.8, 0.6, 0.5, 0.4, 0.3 and 0.2 up to 0.83, a spire of 0.1 to 0.92, nothing
  over it.
- **Tree trunks taper (MapStyle.round_trunk_tiers, RoundSteps).** A trunk's three round boxes stood at its foot's width
  all the way up; pines and oaks narrow as they rise, so lines past a trunk above head height stopped on air. The
  trunk's tiers are measured from the ground under the tree up (the foot stays the block's full width): young pine to
  0.58 of the foot at half its height, grown 0.64, old 0.9, oak 0.77 then 0.96 where it forks. Birch keeps one width
  (no gain measured).
- **The tiers stand on their own bodies, one a surface every 16 m (MapLevel `_tier_body`).** On the leaves' body
  beside Woodland's terrain faces 47,000 to 53,000 boxes overflowed Jolt's sub-shape ids ("Compound hierarchy is too
  deep"); merged runs and square narrow tiers brought the thickets to about 20,000 boxes, and the chunked bodies keep
  each compound small. `JoltQuery.set_tier_bodies` reports their surfaces.
- **The west camp's front palisade stands 3.4 m (tools/woodland/layout.py, `walls(tops=…)`).** With sight passing
  between spruce tops, seven lines from the high ground round (-35, -40), 58 to 77 m off, reached the west spawns over
  the west thicket's tips (`test_woodland_layout`'s spawn test); three of four checked against the drawn spruces were
  open as drawn too. They cross the camp's east wall 0.2 to 0.5 m over its 2.8 m top, so that wall (eight blocks) is
  0.6 m taller; nothing else in the layout moved and no tree was moved: the circled bank's misses were the colliders,
  not the placement.
- **`tools/thicket_opacity.gd` is archived.** It counted a leaf card's whole quad as bough; `sight_truth.gd` replaces
  it.

## Balance

Bots only, Normal, 6v6 (reports in the shared files, `pipeline/runs/WH1/attempt-1/balance/`; the probe runs in `probe/`):

| Figure (band) | main | WH1 |
|---|---|---|
| Woodland, Elimination, the west end (45 to 55 %, 32 seeds) | 45.4 % ±3.2 (TV1) | 48.3 % ±3.3 |
| Woodland, Attack / Defend, the attackers (40 to 65 %, 16 seeds) | 55.8 % ±4.4 (TV1) | 50.0 % ±4.4 |
| Woodland, Plant The Bomb, the attackers (40 to 65 %, 32 seeds, 26 s) | 47.0 % ±3.2 | 48.7 % ±3.3 |
| Woodland, Plant The Bomb, rounds that run out the clock (at most 25 %, 32 seeds) | 16.7 % ±2.4 | 22.1 % ±2.8 |

Every figure is in band, and Woodland's fuse stays 26 s: on the same 32 seeds Plant The Bomb's attackers are within
noise of main. Rounds running out the clock rose 5.4 points (within the two runs' noise, 3.7 points) and stay under
the band's 25 %: one to watch in the next pass. Route variety isn't re-measured: the only layout change is a wall 0.6 m taller where nobody walks, and the nav grid,
the bots' cover and the routes take the blocks' boxes, which keep their footprints.

## Known issues left

- About 14 % of the bodies in sight as drawn are still missed by Spotted, and some 700 of 19,200 lines a run are still
  stopped where nothing is drawn: the trunks' and spruces' tiers are boxes round cones, and a spot looks only at the
  chest and head. `docs/KNOWN_ISSUES.md`.
- On a steep slope a standing body can push 0.5 to 0.6 m into the boughs of 3 of the 225 thickets (the deepest at
  (40.6, 18.6); the critic's capsule probe), where the tiers over the low ground draw in at body height on the high
  side; main had none. Nothing is hidden there (the boughs are drawn round the body) and bots' routes keep the box.
  `docs/KNOWN_ISSUES.md`.
- How it plays on the owner's bank: the playtest checklist's N60.

# LF1 · Bushes stop only what their leaves cover; no boxes at the thickets' feet

**Review:** 2 attempts · critic (attempt 2 below) · qa Pass (attempt 1, 6074be8) · performance Pass (attempt 1, bc8b077)

The owner's playtest of 0.1 Beta 1 (2026-11-17), items 30 to 32: "i was clearly hitting an enemy bot but they seemed
stuck and hits didn't seem to register ... it may or may not be related to the woodlands map and the foliage/trees";
"trees have boxes at the bottom of them. why is this? fix it" (his screenshot 8); "spotted feature (press Z) doesn't
seem to work ... make sure that it works, targets bots properly, and that the players teammates can see where the
spotted bot is (if they are close enough) ... check that it works in all maps".

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-17 | 1 | Opus 5.5 (build thread) | pass | Retry 6/8 | Spotted shown on Woodland A/D only, teammates told not shown, 97 misses not all explained; probe header stale; the fern height in two configs |
| 2026-11-17 | 2 | Opus 5.5 (build thread) | pass | – | – |

## What was wrong

- **Hits and Spotted (items 30 and 32): one cause.** Since WG2 drew Woodland's ferns and shrubs as airy models, the
  simulation still counted each as a solid ellipsoid of its whole drawn reach (a fern 2 m across and 1.2 m tall, a
  shrub 2.6 m and 1.7 m). `tools/bush_opacity.gd` sent 3,000 lines from 15 m into and past each model: about half the
  lines the counted leaves stopped met no drawn leaf (a fern 14 % of all lines, a shrub 16 %). So a BB at a bot you
  could see in a fern stopped short, and Spotted (which uses the bots' sight rules) said it was hidden.
  `tools/spot_probe.gd` on Woodland, one Elimination match: on main, 324 Spotted misses were leaves, and for 187 of
  them the drawn plants put no frond on the lines to the chest and head.
- **The "stuck" bot:** the probe printed every bot standing still 12 s; all were defenders holding their posts (route
  goal reached), none inside a block.
- **Boxes at the trees (item 31):** a spruce thicket's dark core box (WR3, FT1) drawn between its spruces' feet to a
  fifth of its height. The spruces, drawn 1.8 times their cell along and 1.5 across, close the thicket without it
  (pictures 1 to 3).

## What changed

- `Foliage.count_leaves` (called once in `Simulation._init`): the leaves counted along a line (BBs, lasers, sight,
  Spotted, bots' line-of-fire and route string-pulling) are an ellipsoid of shares of the drawn size on the same foot:
  `BallisticsConfig.leaf_fern_shares` (0.6 across, 0.8 up) for a plant up to `leaf_fern_tallest` (1.45 m), else
  `leaf_bush_shares` (0.8, 0.8). Walking through (`holds`, `Character.in_bush`), the nav grid's slow cells, the bots'
  bush angles, the minimap and BushView keep the drawn size.
- `leaf_fern_tallest` is the one fern/shrub split: `WoodsConfig.fern_tallest` is gone and `BushView.build` takes the
  simulation's value, so what is drawn as a fern is what is counted as one.
- `PropDressConfig.model_cores` is empty: no thicket core. The core box's rules stay for a prop that names one.
- Tools: `tools/spot_probe.gd`, `tools/bush_opacity.gd` (dev only).

## Measured

- **Shares** (`tools/bush_opacity.gd`, lines whose counted leaves stop a BB but meet no drawn leaf / lines that meet a
  leaf yet get through): fern 14.0 % / 1.1 % at the drawn size, 2.1 % / 6.6 % now; shrub 16.0 % / 1.2 %, 2.2 % / 7.2 %.
  Starting the counted ellipsoid higher up the stem (tried 0.1 to 0.25 of the height) changed neither by more than
  half a point, so it sits on the foot.
- **Spotted, every map and mode** (`tools/spot_probe.gd`, seed 1 each of Elimination, Attack / Defend and Plant The
  Bomb; reports in `pipeline/runs/LF1/attempt-2/probes/`): every Spotted placed by character 0 at an enemy it saw
  marked that enemy for its team (Depot 26, Subway 34, Woodland 76), but for one in Depot and one in Woodland marked
  nobody because the body of someone hit stood in the line (sight stops there by rule); every free bot teammate within
  30 m of the enemy was told where they were (Depot 16, Subway 60, Woodland 10; none missed). Of the looks at an enemy
  in a clear level line that marked nobody (Depot 181 of 1,824, Subway 184 of 1,820, Woodland 467 of 4,094), every
  one has a cause: smoke 449, a flash 73, a body in the line 51, deep in leaves 259 (Woodland only; for 225 of them
  the drawn plants put a frond on the lines to chest and head too, for 34 they don't). The probe's one "chest inside a
  block" was on the watch tower's stair, whose ramp box reaches over its slope.
- **Leaves against the drawn plants** (Woodland Elimination, seed 1): misses for leaves where the drawn plant shows the
  enemy fell from 187 to 21; misses where it hides them too, 137 then 153.
- **Balance** (Woodland, Normal, seeds 1 to 16; the BP9 run had 32 seeds): Elimination west end 42.5 % ±4.5 on main,
  40.3 % ±4.4 now (band 45 to 55, both outside within noise as BP9's 44.4 % was); median round 57.4 s then 53.2 s;
  first hit 17.2 s then 16.9 s. Attack / Defend attackers 56.5 % ±4.5 now (BP9 54.6 %). Reports in
  `pipeline/runs/LF1/attempt-2/`.

## Decisions

- **Bushes count only the leaves their plants fill; no thicket core** (`docs/DECISIONS.md` › Maps and modes).
- **The shares favour fewer stopped-but-unseen lines over more seen-but-shot-through ones:** a BB getting past one
  visible frond is how a fern behaves; a BB stopped by nothing you can see is the bug the owner hit.
- **A lone fern no longer hides someone crouched in its middle; a bed of them still does** (counted leaves add up over
  overlapping ferns). The wiki's Maps page says so.

## Known issues left

- None.

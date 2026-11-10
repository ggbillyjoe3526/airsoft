# WS1 · Woodland's stream, varied trees and deeper log stacks

**Review:** 6 attempts · critic Accept ?/8 · qa Pass · performance Pass

The owner (2026-11-10): "Would it be possible to add a river stream through the Woodland map where the dried river
bed is? It could push players to cross the bridge as going through in foot would create noise (from splashes) and slow
the player down. Also, go over the woodland map and make tree placement more varied so they don't look so neatly
placed together. Especially give the background trees some variation. Also, for the stack of logs add more 3D depth to
them."

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (build thread) | pass | Retry 6/8 | Log ends too proud and faceted next to the photo; thicket spruces lower than their boxes; a grazing BB splashed over its landing point, not where it went in |
| 2026-11-10 | 2 | Opus 5.5 (build thread) | pass | Retry 7/8 | Log ends still unlike the photo: thick bark rims, straight-sided splits, too many faceted rounds, wide gaps, one colour |
| 2026-11-10 | 3 | Opus 5.5 (build thread) | pass | Retry 7/8 | Log ends: gaps too wide and dark, too few true wedges, faceted curves, too cool a colour, bark band unseen |
| 2026-11-10 | 4 | Opus 5.5 (build thread) | pass | Retry 7/8 | Log ends overlapping rather than packed, too many rounds and four-sided pieces, faceted growth ring, too pale |
| 2026-11-10 | 5 | Opus 5.5 (build thread) | pass | Retry 7/8 | Core a lit brown, not deep shade; pieces stretched to the ragged top; too many rounds |
| 2026-11-10 | 6 | Opus 5.5 (build thread) | pass | – | – |

## What changed

- **The stream:** `data/maps/woodland.json` gains `water`, one line of 91 points 1.5 m apart down the bed
  (`tools/woodland/build_map.py`, `water()`), 13.4 m wide so it reaches under the banks, lying flat 0.3 m over a bed
  made level its whole length (`tools/woodland/layout.py` `BED_Y`, the old floor's lowest), 0.08 m over the Ford's
  gravel bar. The old bed rose about 4 m to a hump under the North bridge (the Ridge's shoulder); it is cut down, the
  ground beside it falling into the stream in a walkable valley (0.6 at most), the bridge 4.5 m lower with its model
  rebuilt (`footbridge.py`); route times across the lanes (analyze.py) are unchanged. The simulation reads it
  through `WorldQuery.water` (`Water`, `game/sim/water.gd`): `Character.in_water` at `MovementConfig.wade_depth`
  (0.15 m) slows a character to `wade_speed_scale` 0.6, Footsteps send every wading stride as a run on the new WATER
  surface (`NoiseConfig.ground` 1.5; a walk or a crouch at `wade_quiet_carry` 0.9), and a BB stops where its path goes under
  the surface with a WATER impact. The nav grid prices points in it (`NavConfig.wade_cost` 8, `splash_cost` 1.5).
  `WaterView` draws it (`look_water.gdshader`). Sounds: `tools/water_sounds.py`.
- **Trees:** the far forest grows in clumps and glades with varied girth (`WoodsConfig.forest_clump`,
  `forest_clumping`, `forest_slim`, a wider `forest_height`); the treeline band mixes four sections (`far_tree.py`
  BANDS, trees scattered over three lanes in groves and a glade), each lowered to between 0.82 and 1 of the line's
  height and shifted up to 0.9 m across (`SkylineConfig.treeline_variants`, `treeline_rise`, `treeline_shift`); the
  thickets' spruces are scattered inside their boxes at full height (`PropDressConfig.grid_scatter`). The
  wood's own trees (Poisson-disc already) are unchanged, so cover and sight lines are too.
- **Log stacks:** every piece in `cordwood*.glb` is a solid end standing 0.3 to 5 cm proud (most 1.5 cm, near flush
  as in the owner's photo), its face tilted up to 0.08 m a metre, its sides shown only where it stands 3.5 cm or more
  out (`cordwood.py` `piece_end`). The pieces are stacked as by hand (`lay_face`): each in turn set where it rests
  lowest on the ground or the pieces under it, a split piece tried point up, point down and now and then on its side,
  so the wedges lock together, 5 mm apart, each whole and unstretched under the stack's ragged top; no outline
  crosses another (asserted at build). About 85 % are pie slices
  of their log (75 to 100 degrees, up to 14 degrees off square), a bark arc of 7 segments with a thin band of dark
  bark inside it; 3 % small 16-sided rounds (12 to 16 cm across, about 0.6 of a slice) with a thin bark ring; 5 %
  four-sided pieces from the heart; one in five with a drying crack. Each end is its own warm colour, from pale
  straw to tan to weathered grey, over a near-black core, the deep shade between them. The sides facing down below 1.6 m, never seen from eye
  height, are left out. 2,782 to 3,013 triangles of a new 3,200 budget per section.

## Decisions

- **The water lies flat and the bed is level** (the owner, 2026-11-10: "the river should be flat and not on a
  decline/incline. Adjust the map for this"; under the bridge it looked uphill). With no fall, its ripples flow north to
  south, the line's own way.
- **The water is a slightly bright, muted blue** (the owner asked for "a little blue", then "slightly brighter"):
  about a quarter saturated on screen, far from Alpha's blue.
- **The stream is 0.3 m deep and wading is 60% pace** (Claude's defaults): slow enough that the bridge is the better
  crossing, not so slow that a player caught in it is helpless.
- **The Ford is ankle deep (0.08 m, under the 0.15 m wade depth): it splashes but never slows.** The overtime flag in
  the Clearing is west of the stream, so the east team crosses there; a slowing Ford would make the race unfair.
- **Every stride in water splashes, at any pace, the Ford's shallows too** (`wade_quiet_carry` 0.9 for a walk or a
  crouch): water can't be crossed quietly, which is what pushes players to the bridge.
- **Splashes carry 1.5 times earth's** (bots hear a running wade at 16.5 m against 11 m).
- **Bots price wading at 8 times a dry point:** 4 left the free route under the North bridge; at 8 bots take the bridge
  or the road when it is near their way and wade only when a crossing is far.
- **A BB in the water stops where its path goes under the surface** (BBStep's `sink`), with a splash puff and a plop
  there; it never bounces off the bed.
- **The two mud puddles in the bed are gone,** under the water now. A gravel patch marks the Ford.
- **The splash sounds are computer-made placeholders** (`tools/water_sounds.py`), listed for the owner to record
  (`audio/record-next.md`). No running-water ambience: Woodland's background stays as the owner approved it.
- **The cordwood section's budget is 3,200 triangles** (was about 1,200): the extruded ends need the sides, and the
  stacks are few (three sections, mixed along each pile).
- **Thicket spruces scatter but keep their box's height:** trees keep to their boxes (DECISIONS, WT1), so a spruce never
  stands lower than the block that stops BBs and sight.

## Known issues left

- None.

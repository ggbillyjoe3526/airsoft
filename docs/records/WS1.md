# WS1 · Woodland's stream, varied trees and deeper log stacks

**Review:** 1 attempt · critic Accept ?/8 · qa Pass · performance Pass

The owner (2026-11-10): "Would it be possible to add a river stream through the Woodland map where the dried river
bed is? It could push players to cross the bridge as going through in foot would create noise (from splashes) and slow
the player down. Also, go over the woodland map and make tree placement more varied so they don't look so neatly
placed together. Especially give the background trees some variation. Also, for the stack of logs add more 3D depth to
them."

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (build thread) | pass | – | – |

## What changed

- **The stream:** `data/maps/woodland.json` gains `water`, one line of 91 points 1.5 m apart down the bed
  (`tools/woodland/build_map.py`, `water()`), 13.4 m wide so it reaches under the banks; its level is the bed's lowest
  ground across its middle, smoothed, 0.3 m over it, and 0.08 m over the Ford's gravel bar. The simulation reads it
  through `WorldQuery.water` (`Water`, `game/sim/water.gd`): `Character.in_water` at `MovementConfig.wade_depth`
  (0.15 m) slows a character to `wade_speed_scale` 0.6, Footsteps send every wading stride as a run on the new WATER
  surface (`NoiseConfig.ground` 1.5; a walk or a crouch at `wade_quiet_carry` 0.9), and a BB landing in it stops at its
  surface with a WATER impact. The nav grid prices points in it (`NavConfig.wade_cost` 8, `splash_cost` 1.5).
  `WaterView` draws it (`look_water.gdshader`). Sounds: `tools/water_sounds.py`.
- **Trees:** the far forest grows in clumps and glades with varied girth (`WoodsConfig.forest_clump`,
  `forest_clumping`, `forest_slim`, a wider `forest_height`); the treeline band mixes four sections (`far_tree.py`
  BANDS, trees scattered over three lanes in groves and a glade), each lowered to between 0.82 and 1 of the line's
  height and shifted up to 0.9 m across (`SkylineConfig.treeline_variants`, `treeline_rise`, `treeline_shift`); the
  thickets' spruces are scattered and of varied height inside their boxes (`PropDressConfig.grid_scatter`). The
  wood's own trees (Poisson-disc already) are unchanged, so cover and sight lines are too.
- **Log stacks:** every piece in `cordwood*.glb` is a solid end standing 3 to 20 cm proud (most 9 cm), its face tilted
  up to 0.12 rad, its sides barked or split back into the stack (`cordwood.py` `piece_end`), 2,697 to 2,761 triangles
  of a new 2,900 budget per section.

## Decisions

- **The stream is 0.3 m deep and wading is 60% pace** (Claude's defaults): slow enough that the bridge is the better
  crossing, not so slow that a player caught in it is helpless.
- **The Ford is ankle deep (0.08 m, under the 0.15 m wade depth): it splashes but never slows.** The overtime flag in
  the Clearing is west of the stream, so the east team crosses there; a slowing Ford would make the race unfair.
- **Every wading stride splashes, at any pace** (`wade_quiet_carry` 0.9 for a walk or a crouch): water can't be crossed
  quietly, which is what pushes players to the bridge.
- **Splashes carry 1.5 times earth's** (bots hear a running wade at 16.5 m against 11 m).
- **Bots price wading at 8 times a dry point:** 4 left the free route under the North bridge; at 8 bots take the bridge
  or the road when it is near their way and wade only when a crossing is far.
- **A BB in the water stops at its surface,** with a splash puff and a plop; it never bounces off the bed.
- **The two mud puddles in the bed are gone,** under the water now. A gravel patch marks the Ford.
- **The splash sounds are computer-made placeholders** (`tools/water_sounds.py`), listed for the owner to record
  (`audio/record-next.md`). No running-water ambience: Woodland's background stays as the owner approved it.
- **The cordwood section's budget is 2,900 triangles** (was about 1,200): the extruded ends need the sides, and the
  stacks are few (three sections, mixed along each pile).

## Known issues left

- None.

# FT1 · Woodland's treelines green and its thickets without plain blocks

**Review:** pending

The owner (2026-11-10): "On the woodland map the models in the distance have white trees. They should have colour.
Also there appear to be some blocks on the map? It looks like there are no models."

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## What was wrong

- **White trees:** the treelines (the band of spruces 6 m past the fence, `SkylineModels._band`) were faded toward
  the horizon by their distance from the field's middle (about 94 m, so a third of the way), though a player at the
  fence sees them from 9 m; their faces, seen from below, mirrored the bright sky at a glancing angle (the engine's
  default specular 0.5); and their greens (`treeline_colours`, made for the cones) were darkened again by the model's
  own shade. Under Sunlit Concrete's sun the three together drew them white-grey on every preset.
- **Blocks:** each spruce thicket's core box (`model_cores`, WR3) stood to 0.6 of its height in forest green, past
  the narrowing tops of its spruces, which each filled only their 1.5 m cell: between them a flat, lit box showed.

## Decisions

- **Treelines fade a fifth as far as the horizon pieces** (`SkylineConfig.treeline_fade` 0.2), as the far wood does
  (`WoodsConfig.forest_fade`), so the band and the wood behind it match.
- **The skyline mirrors no sky** (`SkylineConfig.specular` 0, look_vertex.gdshader's new `specular`, Godot's 0.5
  elsewhere): far scenery is matte. This also covers the Range's skyline pieces.
- **Treelines in the far wood's greens** (`treeline_colours` = `forest_colours`); the cones that stand in when the
  model won't load take them too.
- **Spruces drawn wider than their cell and overlapping** (`grid_spread` 1.8 along a thicket, 1.5 across), never past
  its box: the end ones flush with its ends, the rest evenly between. Every prop still stays inside its block
  (`test_props`), so what is seen still matches what stops BBs.
- **The core is a fifth of the thicket's height** (was 0.6), inset up to 0.3 of its width (`MapLevel.CORE_SHARE`, was
  0.2), in the shade under the spruces' boughs (`#183327`, spruce.py's UNDER; was the forest green). Touching thickets'
  cores still meet (WR3).
- The treeline model's section is 24.5 x 10 m against `treeline_section`'s 20 x 5, so sections overlap a little and
  stand twice as deep as their piece; left as it is (scenery past the fence, nothing changes for play).

## Known issues left

- On Low (no sun shadows) a little of the dark core shows at a thicket's foot between its spruces.

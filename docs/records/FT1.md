# FT1 · Woodland's treelines green and its thickets without plain blocks

**Review:** 4 attempts · critic Accept 8/8 · qa Pass · performance Pass

The owner (2026-11-10): "On the woodland map the models in the distance have white trees. They should have colour.
Also there appear to be some blocks on the map? It looks like there are no models."

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (build thread) | pass | Retry 7/8 | The field spruces' tops still drew white; the treeline read olive-grey at the fence |
| 2026-11-10 | 2 | Opus 5.5 (build thread) | pass | Retry 7/8 | The treeline still read olive-grey from the fence (saturation about 0.2), with near-black facets |
| 2026-11-10 | 3 | Opus 5.5 (build thread) | pass | Retry 7/8 | Band saturation 0.28 against 0.30; 5 % near-black facets on High |
| 2026-11-10 | 4 | Opus 5.5 (build thread) | pass | Accept 8/8 | – |

## What was wrong

- **White trees:** the treelines (the band of spruces 6 m past the fence, `SkylineModels._band`) were faded toward
  the horizon by their distance from the field's middle (about 94 m, so a third of the way), though a player at the
  fence sees them from 9 m; their faces, seen from below, mirrored the bright sky at a glancing angle (the engine's
  default specular 0.5); and their greens (`treeline_colours`, made for the cones) were darkened again by the model's
  own shade. Under Sunlit Concrete's sun the three together drew them white-grey on every preset. Then the look's
  paint (`look_paint`, every surface pulled to 0.6 of its colour toward grey) left their teal greens so grey that the
  warm sun turned them olive (from the fence: hue about 75, saturation 0.2; drawn at their own colour, hue about 110,
  saturation 0.29); and the band's tier skirts, at 0.58 of their tips' light (far_tree.py), went near-black on the
  sun's far side. On High and Ultra the screen-space indirect light (SSIL) darkens that far side again: with it off,
  5 % of the band's pixels under value 0.12 fell to 1.7 %, and Medium, without it, had 0.8 %; SSAO and sun shadows
  changed it by under 1 %.
- **White spruce tops:** the field's own spruces (spruce.py, laid by PropDress) took the props' default wear (SL2), so
  the look's dust settled on every upturned tier; in the sun their tops drew pale beige, white from 30 m off.
- **Blocks:** each spruce thicket's core box (`model_cores`, WR3) stood to 0.6 of its height in forest green, past
  the narrowing tops of its spruces, which each filled only their 1.5 m cell: between them a flat, lit box showed.

## Decisions

- **Treelines fade a fifth as far as the horizon pieces** (`SkylineConfig.treeline_fade` 0.2), as the far wood does
  (`WoodsConfig.forest_fade`), so the band and the wood behind it match.
- **The skyline mirrors no sky** (`SkylineConfig.specular` 0, look_vertex.gdshader's new `specular`, Godot's 0.5
  elsewhere): far scenery is matte. This also covers the Range's skyline pieces.
- **Treelines keep their own colour against the look's pull toward grey** (`SkylineConfig.treeline_keep` 1, carried
  in each skyline vertex's alpha and read by look_vertex.gdshader's `keep_by_alpha`, the skyline's material only).
  Every other skyline piece (the Range's cranes, containers, sheds) and every other surface still takes the look's
  0.6, so Sunlit Concrete's muted paint is unchanged; a treeline is foliage at the edge of the world, as green as the
  spruces in front of it.
- **The band's tier skirts at 0.95 of their tips' light** (far_tree.py `BAND_SHADE`, was 0.58; treeline.glb rebuilt,
  192 triangles as before): the sun and High's SSIL give the tiers their shape, so the sun's far side reads dark green,
  not black. SSIL stays on for the band (Godot can't leave one material out, and every surface takes it alike).
- **Treeline greens #2e7a50, #347f4a, #3f8a4c** (were #1c3024 and kin before FT1): drawn as they are, spruce greens
  of the field's spruces' hue in the sun. Measured in the final pictures (band only, sky left out): at the east fence
  (crop 0-1600 x 0-190 of 1600 x 900) High hue 112, saturation 0.39, 0.5 % under value 0.12, Low hue 122, 0.36, 0 %;
  across the woods (crop 1000-1135 x 280-410) High hue 116, 0.33, Low hue 119, 0.31.
- **A thicket's core is its own palette colour** (`bough_shade` #183328), as every colour Woodland paints is one.
- **A thicket's spruce is not worn** (`model_wear` spruce 0): it is all boughs, and dust on them read as snow.
- **Spruces drawn wider than their cell and overlapping** (`grid_spread` 1.8 along a thicket, 1.5 across), never past
  its box: the end ones flush with its ends, the rest evenly between. Every prop still stays inside its block
  (`test_props`), so what is seen still matches what stops BBs.
- **The core is a fifth of the thicket's height** (was 0.6), inset up to 0.3 of its width (`MapLevel.CORE_SHARE`, was
  0.2), in the shade under the spruces' boughs (`#183328`, spruce.py's UNDER; was the forest green). Touching thickets'
  cores still meet (WR3).
- The treeline model's section is 24.5 x 10 m against `treeline_section`'s 20 x 5, so sections overlap a little and
  stand twice as deep as their piece; left as it is (scenery past the fence, nothing changes for play).

## Known issues left

- On Low (no sun shadows) a little of the dark core shows at a thicket's foot between its spruces.

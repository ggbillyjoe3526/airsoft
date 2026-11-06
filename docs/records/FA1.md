# FA1 · The bots' faces behind their goggles

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | figure tests pass | Revise 3/8 | LOD2 skin through the knit, LOD1 shard, nose-side creases, staring eyes, wrinkle paint, looks 0/1 alike |
| 2026-11-05 | 2 | Claude (build thread) | figure tests pass | Revise 3/8 | pinched inner eye corners, skin edge zigzag under the hem, thin brows, looks 1/2 alike, LOD2 hem V |
| 2026-11-05 | 3 | Claude (build thread) | figure tests pass | Revise 5/8 | LOD2 hem slit, bottom hem step, eye hidden in profile, eye-white corners, LOD1 nose facet |
| 2026-11-05 | 4 | Claude (build thread) | figure tests pass | Revise 7/8 | bottom hem notches over the nose, eye-white corner wedges |
| 2026-11-05 | 5 | Claude (build thread) | figure tests pass | Accept 8/8 | |
| 2026-11-05 | 6 | Claude (build thread) | figure tests pass | Revise 6/8 (code) | task id FC1 already taken (now FA1), looks repeat on a head with an odd count of heads, `cull` copied from headwear.py |
| 2026-11-05 | 7 | Claude (build thread) | figure tests pass | Accept 8/8 (code) | |

## Task

The owner (2026-11-05 15:09) saw eyes and skin through the clear lenses of the new head gear (BL11) and asked whether
a face model was worth making. It is, for the part players see: bots come close in CQB, in spectating and when they
call a hit, and the "face" was a flat picture painted on the balaclava's knit. Every head look covers the lower face
(the mesh mask, the scarf or the balaclava), so only the strip round the eyes is modelled.

Acceptance: a modelled face (eyes, lids, skin) in the balaclava's opening under every head look, no clipping with any
head gear or eyewear, a few looks if the budget allows, stylised per the art direction, the head's budget used to 95
to 100 %, screenshots of the face alone and in-game close-ups with gear.

## What changed

- **`tools/blender/figures/face.py`** (new): the knit gets a clean rectangular hole (`headwear.head(..., opening=True)`
  inserts grid lines at its edges), covered by a swept, rolled knit hem. Inside, the skin is the head's own surface a
  little under the knit (deeper under the hem, which lies over its edge), each eye's socket carved to a lid shell
  riding just ahead of the eyeball, sloping gently down the side of the nose, with a crease over the upper lid and a
  roll under the lower. Round each eye the skin is even quad rings offset from the lids' outer loop (their corners round
  off instead of bunching); beyond them a constrained Delaunay fill with a column down the bridge of the nose. Each eye:
  an eyeball cap (the cornea a touch proud) and three lid loops (tucked into the eyeball, the margin, the rim) round an
  almond fissure. LOD2 keeps a coarse skin patch with the eyes painted where the eyeballs were.
- **Four looks** (skin tone, brows, eye colour: light with blue-grey, medium with green, tan with brown, deep with dark
  brown, each tone 30 to 45 levels from the next; a soft shade painted just inside the hem) are painted in four
  256 x 128 cells of the heads' atlas above the swatches. The mesh's UVs use the first;
  `FigureConfig.face_look(id)` picks one per figure (figures sharing a head never share a look until all four are
  used, for any count of heads) and `FigureModels.face_material` offsets a shared copy of the `Face` material's UVs by
  `FigureConfig.face_offsets` (`FigureModels.materials` lists every look for the shader warm-up). No extra triangles
  or textures.
- **Budget:** the heads' share grows to 9,000 / 3,200 / 900 (from 8,000 / 2,600 / 800), taking the figure split's
  unallocated 1,000 / 600 / 100 (body 34k, carrier 14k, pads 3k, heads 8k summed to 59k of 60k; the body thread was
  told). Heads: 8,988 / 8,992 / 8,982 / 8,958 at LOD0, 3,138 / 3,144 / 3,192 / 3,158 at LOD1, 896 / 880 / 896 / 874 at
  LOD2 (high cut, cap, boonie, full cut), all 97 to 99.9 % of budget; the face is 1,094-1,318 / 594-708 / 82-90
  of each. The figure (largest head, BL10 body, BL13 pads) 49,878 / 16,673 / 4,996.
- `headkit.Part.build(smooth_mats=...)`: edges inside the face's skin are never split however steep (the sockets).
  `cull` and the `GEAR` material name move to headkit from headwear.py, shared by face.py.
- `splice_heads.py` gives the new `Face` material the atlas; the knit tile loses its painted eyes.
- `HUMAN_HIGH` in `test_figure_body.gd` follows the new counts; two new tests cover the looks.

## Decisions

- Only the eye strip is modelled (owner's principle: if the player never sees it, remove it). A bare full face would
  never show under any look.
- Four looks, one per cell, by UV offset: the cheapest way to vary bots (one material per look shared by every figure
  wearing it, no new textures).
- Nothing of the face stands out of the knit surface except the lids, by at most 1.5 mm, so the gear fitted to the head
  in BL11 (lenses, gaskets, masks, scarf) clears it untouched; the drape the gear is placed on stays the hole-free head.
- The hem's bottom edge has extra points across the nose (narrower than its spacing), and its outer side tucks 3.2 mm
  under the knit, so its straight spans never dip under the knit's faces.
- The face-only review renders have the key light's shadows off: figures cast no shadow on themselves in game, and the
  nose's cast shadow on low-poly skin stair-steps in Cycles.
- No wiki page describes the bots' looks, so no wiki change.

## Known issues

- In Cycles the high cut's skin just above the mesh mask, seen through the lens's lower edge, renders as an orange
  band; the game's renderer shows none (in-game close-ups). Review sheet only.
- At 80° from the front the eye shows as a sliver behind the lashes (as a real eye does); worth a look in play.

# WT1 · Woodland's trees: pines, oaks, birches, thicket spruces and the far wood from the owner's photos (Dev)

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | build thread | QA Pass, performance Pass | Retry 6/8 | fidelity to the photos (oak too narrow and high, old pine an umbrella, young pine a lollipop, grown pine's bare twigs), crowns stretched by their trunk's box in game, changelog note and checklist link |
| 2026-11-09 | 2 | build thread | as attempt 1 | Retry 7/8 | fidelity: oak's foot flare and low limbs, holes atop its dome; grown pine widest at its foot; young pine's tufts; birch's twigs and marks |
| 2026-11-09 | 3 | build thread | see Verified | pending | – |

## Goal

Dev 3's Woodland models, the trees (`art/woodland-model-list.md` in the project files, rows 01, 02, 03, 09 and 22):
the pine in three ages (1,000, 2,000 and 3,000 triangles), the oak (8,000), the birch (2,000, no photo), the thicket
spruce (500, solid) and the far tree (12) with the treeline band (2,000 a band), modelled in Blender from the owner's
photos (`references/maps/woodland/`). Each model fills its block's box exactly at the trunk, so cover, collision and
sight lines don't change; crowns are look only, over head height. 60 FPS on Low from the Ridge and the Clearing.

## Approach

- **Models** (`tools/blender/maps/`, one vertex-coloured mesh each through `mapkit.py`'s export; shared `treekit.py`):
  `pine.py` (young 960, grown 1,936, old 2,866), `oak.py` (7,966), `birch.py` (1,996), `spruce.py` (474),
  `far_tree.py` (the far tree 12, the treeline band's 20 m section 192). Each tree is written as its trunk and its
  crown apart (`<model>.glb`, `<model>_crown.glb`). The oak's leaf clumps are knobbly and flatter, not round (owner,
  2026-11-09). Normals lean out from each crown's middle, the stylised
  tree look; every colour a palette entry, none within 20° of a team's hue. The build gates fail a model over its
  budget, with a team hue, with its trunk past its foot radius, or with any other part outside that radius under its
  clearance.
- **The map** (`tools/woodland/build_map.py`): each tree block names its model in `dress` (a pine's age by its height:
  young under 11 m, grown under 18.5 m, old above; oaks and birches by kind), the thickets `spruce`. Look only: the play
  data is unchanged.
- **Laying a tree** (`PropDressConfig.Lay.TREE`, `PropLayout.tree_fit`): the trunk's foot (`tree_feet` m round the
  origin) is stretched to the box's half-width, the model's top to the box's top, its origin on the ground under the
  box's middle (raised on a steep foot so the sunk end stays in the box). Turned a quarter at a time only, so the round
  collision steps keep hugging the trunk. Its crown (`tree_crowns`, `PropLayout.crown_fit`) stands on the same origin
  scaled evenly by the tree's height, so it keeps its modelled shape however wide its box is (a single mesh stretched
  across and up apart drifted 0.64 to 1.43 from it). Turns and shades come from the trees' own seeded stream, so the
  other props lay as before. The crowns carry their own leaves (`WoodsConfig.own_crowns`): WoodsView draws no cone
  crown over a tree whose model PropDress draws; one that won't load (or has no `tree_feet`) keeps its box and cone.
  Oaks and birches are chunked by area like the many models (`spread_models`), so they cull.
- **Collision** (`MapStyle.round_steps`): every tree model takes the drum's three stepped boxes round its trunk (a tree
  is a row of one in RoundSteps); the crown over `crown_clear` stops nothing, as the cones didn't.
- **Thickets:** the spruce fills each 1.5 m cell to its tips; the core box behind them is the deep forest green now, so
  no bright green shows between the cones.
- **Far wood** (`WoodsConfig.forest_model`): WoodsView's ~1,800 trees past the fence draw the far tree in place of the
  six-sided cone, same size and instance colours.
- **Treelines** (`SkylineConfig.treeline_model`, `SkylineModels._band`): each run of a treeline lays whole 20 m
  sections end to end, each stretched to an even share, as deep and tall as the piece, sunk as the cones were, every
  other one mirrored, each a seeded one of the treeline greens. Woodland's four bands are 1,344 to 1,728 triangles (the
  model list's 2,000 a band). Sight still reads the greybox.
- **Materials:** `PropDress` keeps one shared prop material for each roughness; the trees and spruces are matte
  (`model_roughness` 0.95).

## Defaults taken

- **Owner's ruling (decision card, 2026-11-09):** trees keep to their boxes (DECISIONS.md › Maps and modes), so young
  pines keep the 2.6 m clearance and spruces their 1.5 m cells, slimmer than the photos.

- Trees turn only a quarter at a time (their collision steps stay exact).
- Every trunk meets BBs as the drum's round steps; the old Kenney trunk's root steps in its back corners are gone.
- No branch under 2.6 m at the smallest tree of each kind, so young pines start their brush there.
- Pine bark is golden tan (`#B0A472`), not the photos' orange-brown, which reads as Beta's team colour.
- The birch is modelled from general knowledge (no photo).
- Spruces stay narrow: each keeps its 1.5 m cell.
- The oaks' crowns keep the photo's width (half again the height), so they shade much of the Clearing.

## Verified

- Frame cost on Low (draw calls and triangles from seven spots on the Ridge and round the Clearing, against main):
  15 to 37 % fewer triangles (e.g. the Ridge east 329k against 455k), about 20 % more draw calls (123 against 103
  at most). The cloud's renderer can't time frames; the owner checks F3.
- Unit tests: `test_props`, `test_round_steps`, `test_look`, `test_woods_view`, `test_woods_view_qa`, `test_wr3_qa`,
  `test_woodland_layout`, `test_skyline`, `test_model_faces`, `test_model_pictures` pass (116). New: each tree's crown
  count and even scale, a tree model that won't load keeps its cone, Woodland's treelines are the band in budget along
  their lines.
- Pictures (project files, `art/blender/woodland-trees/`): each model beside the owner's photo, and in game on High
  against main, rounds 1 and 2.

## Play this

`docs/PLAYTEST.md` › Woodland's trees (WT1), and the owner's Dev 3 checklist in the project files.

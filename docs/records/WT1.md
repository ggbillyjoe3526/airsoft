# WT1 · Woodland's trees: pines, oaks, birches, thicket spruces and the far wood from the owner's photos (Dev)

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | build thread | see Verified | pending | – |

## Goal

Dev 3's Woodland models, the trees (`art/woodland-model-list.md` in the project files, rows 01, 02, 03, 09 and 22):
the pine in three ages (1,000, 2,000 and 3,000 triangles), the oak (8,000), the birch (2,000, no photo), the thicket
spruce (500, solid) and the far tree (12) with the treeline band (2,000 a band), modelled in Blender from the owner's
photos (`references/maps/woodland/`). Each model fills its block's box exactly at the trunk, so cover, collision and
sight lines don't change; crowns are look only, over head height. 60 FPS on Low from the Ridge and the Clearing.

## Approach

- **Models** (`tools/blender/maps/`, one vertex-coloured mesh each through `mapkit.py`'s export; shared `treekit.py`):
  `pine.py` (young 938, grown 1,836, old 2,992), `oak.py` (7,540), `birch.py` (1,996), `spruce.py` (474),
  `far_tree.py` (the far tree 12, the treeline band 1,984). Normals lean out from each crown's middle, the stylised
  tree look; every colour a palette entry, none within 20° of a team's hue. The build gates fail a model over its
  budget, with a team hue, with its trunk past its foot radius, or with any other part outside that radius under its
  clearance.
- **The map** (`tools/woodland/build_map.py`): each tree block names its model in `dress` (a pine's age by its height:
  young under 11 m, grown under 18.5 m, old above; oaks and birches by kind), the thickets `spruce`. Look only: the play
  data is unchanged.
- **Laying a tree** (`PropDressConfig.Lay.TREE`, `PropLayout.tree_fit`): the trunk's foot (`tree_feet` m round the
  origin) is stretched to the box's half-width, the model's top to the box's top, its origin on the ground under the
  box's middle (raised on a steep foot so the sunk end stays in the box). Turned a quarter at a time only, so the round
  collision steps keep hugging the trunk. The crowns carry their own leaves (`WoodsConfig.own_crowns`): WoodsView draws
  no cone crown over them.
- **Collision** (`MapStyle.round_steps`): every tree model takes the drum's three stepped boxes round its trunk (a tree
  is a row of one in RoundSteps); the crown over `crown_clear` stops nothing, as the cones didn't.
- **Thickets:** the spruce fills each 1.5 m cell to its tips; the core box behind them is the deep forest green now, so
  no bright green shows between the cones.
- **Far wood** (`WoodsConfig.forest_model`): WoodsView's ~1,800 trees past the fence draw the far tree in place of the
  six-sided cone, same size and instance colours.
- **Materials:** `PropDress` keeps one shared prop material for each roughness; the trees and spruces are matte
  (`model_roughness` 0.95).

## Defaults taken

- Trees turn only a quarter at a time (their collision steps stay exact).
- Every trunk meets BBs as the drum's round steps; the old Kenney trunk's root steps in its back corners are gone.
- No branch under 2.6 m at the smallest tree of each kind, so young pines start their brush there.
- Pine bark is golden tan (`#B0A472`), not the photos' orange-brown, which reads as Beta's team colour.
- The birch is modelled from general knowledge (no photo).
- Spruces stay narrow: each keeps its 1.5 m cell.
- The treeline band is built; it stands in the skyline once the skyline models (FS1) land.

## Verified

- Frame cost on Low (draw calls and triangles from seven spots on the Ridge and round the Clearing, against main):
  15 to 37 % fewer triangles (e.g. the Ridge east 329k against 455k), about 20 % more draw calls (123 against 103
  at most). The cloud's renderer can't time frames; the owner checks F3.
- Unit tests: `test_props`, `test_round_steps`, `test_look`, `test_woods_view`, `test_woods_view_qa`, `test_wr3_qa`,
  `test_woodland_layout` pass.

## Play this

`0.1-dev3-checklist.md` › Woodland's trees (WT1).

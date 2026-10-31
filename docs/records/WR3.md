# WR3 · Woodland's CC0 dress

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-10-31 | 1 | thread | see Checks | Retry 8/8 (held for QA, performance) | thickets' cores left gaps between touching thickets |
| 2026-10-31 | 2 | thread | see Checks | pending | – |

## Goal

The last of four pull requests for the owner's Woodland concept 3 (2026-10-31: "Perfect, go ahead and add this to the
game with CC0 dressing. Give me screenshots when it's done and I will playtest it."). WR1 left Woodland's trees, logs,
crates, tyres and truck as boxes (KNOWN_ISSUES); maps are dressed with CC0 assets until the owner starts Blender map
models in Beta (2026-10-31).

## Approach

- **Models.** Seven Kenney CC0 models (the mirror at 3694c68, as DR2's) through `tools/props/build_props.py`,
  recoloured into vertex colours off the team hues: `trunk` and `log` (the Nature Kit's log, the trunk stood on end,
  `TURNS`), `logstack`, `pine` (a tall pine), `tyre` (laid flat), `crate` (teal) and `truck` (violet, dark wheels).
  452 KB in all, no textures (`docs/ASSETS.md`).
- **Which block is which prop.** A block may name its prop (`MapData.Block.dress`, the map's `dress` key):
  `tools/woodland/build_map.py` `DRESS` maps each layout piece (tree, thicket, log, log pile, crates, tyres, truck) to
  its model, so the rules' boxes stay WR1's and only the drawing changes. `PropDressConfig.model_of` / `lay_of` read
  it before the kind's (Depot's, DR2, unchanged).
- **A grid lay.** `PropLayout._grid` fills a log pile, a crate stack, a tyre stack or a thicket with its model a
  `grid_cells` cell, each stretched to its cell and turned a random half (a square model a random quarter), so a
  stack's ends and faces vary. A model laid 64 times or more is chunked (`chunk_from`), as DR2's shelving.
- **Without a site.** Woodland has no site dress, so `PlaySession` builds a `PropDress` on its own and warms its
  material; `MapLevel`'s greybox leaves a dressed block out, or draws a thicket's dark core cut to 60 % of its height
  between its spruces (`model_cores`, `MapLevel.core_box`), inset 0.7 m (at most a fifth of its width) only on a side
  no other thicket touches, so nobody sees through a thicket, or between two, that stops sight below its tops.
- `tools/eye_pictures.gd` and `tools/map_pictures.gd` draw the props, the woods and the bushes on a map without a site.
- Wiki: Maps (the CC0 props, the boxes they stand in). KNOWN_ISSUES: the greybox row becomes the props' square
  boxes (document). ROADMAP: WR3 done.

## Defaults taken

- The trunk and spruce colours are dull browns and a mid green (saturation under the team check's 0.3), so trees
  read as wood and leaves without crowding the palette's six hues; the crates teal and the truck violet carry colour.
- A prop's box stays the rule (what stops a BB and a body), as DR2's: a round trunk is hit by its square block, a
  little wide of the bark. Changing collision to the model's shape is a later pass if play says so.
- The thicket keeps a core so a thicket still blocks sight between its spruces, as WR1's solid box did.

## Checks

- gdlint clean; `check.py` TOTAL 0; `build_map.py` rebuilds `woodland.json`; `build_props.py` rebuilds the models.
- `test_props` 16/16: Woodland is dressed with no site, every prop inside the block that names it, one trunk a tree,
  a grid lays a crate a cell, a dressed block draws no box and a thicket only its core, no prop colour reads as a
  team. The full suite runs on CI.
- Eye-level pictures of the camp, Hut row, the Sawmill and the Truck bend checked by eye (trunks, spruces, log stacks,
  crates, tyres and the truck in place, no greybox boxes showing through).

## Attempt 2

- The critic found the cores inset on every side left a 1.4 m gap between touching thickets (about 5 % of sight lines
  across a clump clear, some for 26 m) and a 1 m strip's core a card. `MapLevel.core_box` now runs a core to any side
  another thicket touches and insets the rest at most a fifth of the box's width; `test_props` checks no touching
  pair leaves a gap. A lined (TILE) block keeps its box on a map without a site, and two lines over 120 columns are
  wrapped.
- Performance (Pass) advised the 2,609 spruces' shadows and up to 154 prop draws per pass; Low draws no sun shadows,
  so the owner's F3 check on Low across the thickets is in the playtest list.

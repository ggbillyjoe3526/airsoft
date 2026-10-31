# WA1 · Woodland in the art direction

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-10-31 | 1 | thread | see Checks | Retry 7/8 (held for QA, performance) | docs behind the change |
| 2026-10-31 | 2 | thread | see Checks | pending | – |

## Goal

The owner asked whether the rebuilt Woodland has the new art direction (2026-10-31), and ruled the same day that the
look applies game-wide: "Woodland and future maps should use the same art direction". AD1 built the shared look and
moved Depot onto it; this moves Woodland onto it by docs/ART.md › A map in the look.

## Approach

- **The shared light.** `LookMaterials.vertex_colour` takes `srgb` (`look_vertex.gdshader`'s `srgb_colours`) for
  meshes and MultiMeshes built in code. The greybox and the sloping ground (`MapLevel._greybox_material`), the crowns,
  the far forest and the floor pieces (`WoodsView._flat_material`) and the bushes (`BushView`) draw on it; the puddles
  on a new see-through `look_clear.gdshader` (`LookMaterials.clear_colour`). The CC0 props already were (AD1).
- **Clean.** The greybox's metre grid is gone (`MapStyle.grid_size` and `grid_shade` with it), as the art bible's
  clean surfaces ask; the Range's greybox loses it too.
- **The palette.** Fifteen Woodland colours join `LookConfig.palette` (bark, heartwood, canopy, fern, olive, pine,
  spruce, forest, meadow, litter, earth, rubber, pond, mud, mud_wet), every one off the team hues. Woodland's
  `MapStyle` kinds, its ground surfaces and ground beyond the fence, `WoodsConfig`'s crowns, forest, bark, grain, leaf
  drifts, puddles and bushes, the minimap's bush disc, the map's moss (`build_map.py`) and the seven prop recipes
  (`build_props.py`, rebuilt) take palette colours. The violet truck and teal crates carry the site colours.
- **Probes** come free: AD1's `AreaProbes` builds Woodland's from its named areas.
- `tests/unit/test_look.gd`: Woodland's paint is the palette's (every kind on the map, the ground, the woods, the
  moss, the minimap) and its prop recipes; the greybox, woods and bushes draw in the shared light.
  `test_woods_view`'s puddle test reads the new material.
- **Rebakes.** The bake's hash folds in `MapStyle`'s colours, so Depot's and the Range's bakes are rebuilt
  (`tools/bake_light.gd`); `test_dp2_qa`'s pinned base hashes follow, and `test_dd1_qa` reads the greybox as the shared
  vertex shader.
- Docs: ART.md (The wood's colours and light; A map in the look), wiki Maps (Woodland's look), KNOWN_ISSUES (doors,
  poles and skyline still outside the shared light).

## Defaults taken

- The grass tufts keep their own light: with the shared light, a two-sided blade takes the warm rim on every back
  face and the meadow glowed white.
- A thicket's core is pine green, its spruces' leaves, so it reads as the thicket's shade rather than a wall.
- The crowns are bright (canopy, green, pine, fern) where WL4's were dark olive, following the vibrant palette; the
  shade under the canopy comes from the light, not dark paint.

## Checks

- gdlint clean; `check.py` TOTAL 0; `build_map.py` and `build_props.py` rebuild the map and the models.
- Targeted GUT: test_look, test_woods_view, test_woods_view_qa, test_bushes, test_props, test_baked_light,
  test_dd1_qa, test_dp2_qa and the tests reading the changed colours or the minimap all pass. The full suite runs on CI.
- Before and after pictures at eye height on High (Vulkan, lavapipe): Hut row, the Truck bend, the Sawmill.

## Attempt 2

- The critic (Retry 7/8, held for QA and performance) found five docs behind the change: ART.md's palette table
  (the fifteen Woodland colours added), its crowns ("dark-green cone"), the test that holds the wood's colours, the
  Woodland recipes still "to join" the palette test, and `game/map/README.md`'s metre grid. All five fixed.
- `test_night_light`: timber logs, fences and boards stood ΔE 4.6 off the new leaf litter in the night fill alone (the
  floor is 5, never lowered). Litter is darker, `#7c7a58` (ΔE 7.8), in the palette and Woodland's LEAVES ground.
- Performance Pass: no blocking finding; the shared `light()` over the greybox and woods is for the owner's F3 check
  on High and Ultra at Hut row and the Sawmill, against main.

# WQ1 · Woodland's models in photo detail: leaf-card crowns, photo bark, textured timber and earth (Beta 2)

The owner, 21 November: "Also improve the quality of woodland map models. Foliage/trees should have better quality
leaves/branches. Trees should have better textures. Give me screenshots", then "I mean all models not just
foliage/trees".

**Review:** 9 critic runs · critic Retry 7/8 (the pines), shipped at the owner's call (decision card, 21 November) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-21 | 1 | Opus 5.5 (build thread) | ✓ (touched tests; CI the rest) | 7/8 Retry | 1: the pine crowns read as solid cores, not needles |
| 2026-11-21 | 2 | Opus 5.5 (build thread) | ✓ (touched tests; CI the rest) | 7/8 Retry | 1: pine crowns too sparse once the cores went |
| 2026-11-21 | 3 | Opus 5.5 (build thread) | ✓ (touched tests; CI the rest) | 7/8 Retry | 1: the needle tufts read as one smear, not separate brushes |
| 2026-11-21 | 4 | Opus 5.5 (build thread) | ✓ (touched tests; CI the rest) | 7/8 Retry | 1: the grown pine read as a cloud, not shelves (massing) |
| 2026-11-21 | 5 to 9 | Opus 5.5 (build thread) | ✓ (touched tests; CI the rest) | 7/8 Retry | 1: pine cards too large and too even; the critic wants more, smaller bottlebrush cards, 5 to 7 shelves on the grown pine and the leader ending inside the top. Everything else was accepted |

QA failed once inside attempt 1: the surfaces arrays import as `CompressedTexture2DArray`, so the cast to
`Texture2DArray` gave null and every structure drew plain; they are read as `TextureLayered` now (its 14 tests in
`tests/unit/test_wq1_qa.gd`).

## Goal

Every Woodland model looks better up close without changing how the field plays: the trees (pines in three ages, the
oak, the birch), the thicket spruces, the ferns and bushes, and the structures and props (palisade, tower, North
bridge, Sawmill shed, hut roofs, crouch tunnels, culvert, tyres, fallen logs, root plates, saw bench, earth banks,
campfire and lanterns). Bounds, triangle budgets, colliders, the layout and the bushes' counted cover stay as they
were; the woodpiles (RM2) are closed and untouched; Low keeps 60 FPS.

## Approach

- **Textures** (`tools/textures/woodland_fetch.gd`, `woodland_textures.py`, `assets/textures/woodland/`): CC0
  ambientCG sets (Bark001, Bark002, Bark014, Wood058, Concrete034, Metal038, Ground054, Moss002) from the pinned
  mirror Subway's materials came from, turned into detail (relief, not colour: the palette stays in the vertex
  colours) and normal maps; the birch's bark, the sawn ends and the 16-cell leaf sheet (needle shoots, sprigs, oak,
  birch and hazel sprays, fern fronds, leaf and needle masses, twigs) drawn by the script.
- **Foliage** (`look_foliage.gdshader`): leaf faces cut out of the sheet at `alpha_cut` with cover growing a little
  each mip level, both sides lit as the crown's shape, a little sun through the leaves (`look_light.gdshaderinc`
  LOOK_TRANSLUCENT); bark faces (UV x under -1) tile the bark and its normal map, the pine's flaking upper bole blended
  by UV2 x.
- **Surfaces** (`look_surface.gdshader`, `look_vertex.gdshaderinc` LOOK_SURFACES): look_vertex plus one layer of an
  8-layer array chosen by UV2 x, mapped along each face's longest edge (`mapkit.SURFACES`, `SURFACED`).
- **Models** (`tools/blender/maps/`): `treekit.Leafy` stands leaf cards out of each clump over a smaller, darker core;
  `fit_cards` keeps them inside the clumps' box and under the crown's own top; the fern and bush are rebuilt on
  treekit. Config: `PropDressConfig.model_barks`, `surface_models`, `WoodsConfig.bush_sheet`, `bush_bark`,
  `LightFixturesConfig.surface_maps`.

## Verified

- Every model's bounds and triangles against main's: the crowns never over their boxes' tops (`test_props`' Woodland
  dress test), trunks, fern, bush and structures unchanged; budgets young pine 920 of 1,000, grown 1,854 of 2,000, old
  2,966 of 3,000, oak 7,966 of 8,000, birch 1,528 of 2,000, spruce 474 of 500, fern 400 of 400, bush 1,496 of 1,500.
- The bushes' counted cover (LF1) against the drawn leaves, `tools/bush_opacity.gd` now reading the sheet's cut,
  at LF1's shares: fern "unseen" 2.4 % (main 2.1 %), "through" 8.6 % (6.6 %), 433 of 3,000 lines drawn hidden (383);
  bush 2.4 % (2.2 %), 8.0 % (7.2 %), 924 (908). No leaf share changed.
- Touched tests (26 files, 303 tests) and QA's 14; coplanar check 0 on all 221 models; gdlint; wiki check.
- Pictures (Medium, day, before and after at the same spots): project files `art/woodland-wq1/`.

## Decisions

- The Linux build's smoke check in `release.yml` waits 5 minutes, not 2, as the Windows build's already does: the smoke
  match takes about two minutes on a runner (main 114 s), and this branch's run went over twice by a second or two
  (head to head with main in the cloud, 130 s against 128 s).
- **Leaf cards on photo bark replace the solid clumps (default taken, DECISIONS).** The owner asked for better leaves,
  branches and textures; cut-out cards over a darker core is the way real-time trees get leaves without losing fill.
- **Low reads less (GraphicsApply.SURFACE_DETAIL 0).** The performance review measured the software renderer's GPU
  time up 70 to 100 % in leafy views; on Low Mesh detail both shaders skip the relief maps, the second bark and the mip
  query. Real cards' cost is N47 on the checklist.
- **The pickup and the tyres keep their paint.** Neither car paint nor rubber is a surfaces layer; they draw plain on
  the surfaces shader.
- **The trees keep WT1's shapes (DECISIONS):** crowns from 2.6 m up filling their boxes, golden tan (never orange)
  upper bark, closed thicket cones; measured against the photos only within that (the critic's ratio misses).
- **Pines' sprays are shoots of needle bunches** (fascicles of long, streaked needles), massed on large overlapping
  cards with no solid core, every lesser clump on a dark twig; the grown pine's whorls stand as shelves, the young
  pine's cards are narrow upright brushes, and every leader is darkened and clothed at its tip. Their cut-outs are
  read no coarser than mip 2 (`PropDressConfig.model_alpha_lod`), so a far pine stays spiky instead of averaging into
  smooth lozenges. Needle crowns grow cover 0.15 a mip level, from derivatives on every preset (Low's far crowns keep
  their fill). No card moves more than 0.1 of half its length to stay in the box, nor stands over 1.15 of its clump's
  radii off it (`treekit.fit_cards`).
- **Soft leaf edges:** alpha to coverage on the cut-outs (smooth under MSAA, plain scissor without).
- **The tunnel arch's band is the mound's sun shadow** (gone on Low, which has no sun shadows); the hood is WG4's.
- **The far wood stays as it was** (`far_tree.py`, WoodsView): out past the fence it is seen only far off.

## Known issues left

- Frame time on a real Low PC is unmeasured (lavapipe only): N47 asks the owner.
- The pines: the critic's last runs still read the pine cards as broadleaf fans at play distance; the owner shipped them
  to judge in play (decision card, 21 November). If they read wrong, the next step is the critic's list in Attempts.
- The pine crowns read their cut-out from mip 2 (alpha_lod) so far cards keep a ragged edge; that can shimmer at
  20 to 40 m: N47 asks the owner.

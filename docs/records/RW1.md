# RW1 · Lightly used AEG Rifle and GBB Pistol

**Review:** 3 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (replica wear thread) | – | 7/8 Retry (QA Pass, performance Pass) | thin strips on the pistol (the extractor in its slot, the frame's rail slot) wore or grimed whole and read as a recoloured part or a stain, not as wear |
| 2026-11-10 | 2 | Opus 5.5 (replica wear thread) | – | 7/8 Retry | the pistol's rail slot and serration grooves (welded into the big Frame and Slide parts, so out of the per-part fade) still filled with tan grime and a light rubbed lip, reading as paint at the whole-pistol distance; round rubbed patches on the black AEG read as smudges |
| 2026-11-10 | 3 | Opus 5.5 (replica wear thread) | ✓ | 8/8 Accept (QA Pass, performance Pass) | – |

## What changed

Owner, 2026-11-10: "go over all the replica models (including the work in progress SMG) except the cyber pistol and
sniper rifle and give them more realistic detail? Maybe some faint scratches/marks but keep it subtle. Just make them
look realistic and slightly used." Shapes, triangles and gameplay are unchanged.

- **Wear mask** (`tools/blender/replicas/wear.py`, called last by `aeg.py` and `gbb.py`): a second UV layer `Wear` on
  every painted mesh (Body, Furniture, Detail, Accent, Metal), four Cycles bakes (position, normal, bevel and two AO
  reaches, part ids) and a numpy compose into one 2K mask: R ambient occlusion (dirt in recesses), G rubbed edges and
  soft handling patches, B scratches drawn as tapered 3D polylines from the baked position and normal maps (so they
  never break at a UV seam), some in small clusters. No part wears whole: a loose part rubbed past a quarter of its
  surface, or a small one (under 1 % of the mask) grimed past a fifth, has that wear faded as (share / covered)².
  A lip round a recess (far reach occluded) rubs a quarter as much as an outer edge, a narrow slot or groove (near
  reach occluded) keeps only a broken fringe of its grime, and the soft rubbed patches are broken up finely.
  Seeded; hung on the glTF occlusion slot so Godot imports it as the surface's own texture (`aeg_wear.png`,
  `pistol_wear.png`). Figure copies get the mask's clean corner.
- **Worn paint** (`game/play/replica_wear.gdshader`, `ReplicaPaint`): the paint scuffs towards a worn mid grey in
  square-root light (black greys up, white dirties down, colours dull), metal parts wear to bare metal, each wear
  changes the roughness; all times `LookConfig.wear` (`look_wear`). One shared worn material per (paint, mask), the
  plain one kept as meta (`plain_of`); ReplicaView's depth press sets the shader's `z_clip_scale`; play prewarms the
  worn materials.
- **Tests** (`test_replica_wear.gd`, 15): masks on every painted surface and none on the Cyber or sniper, the UV
  layer, shared worn paints, figures and mag tosses plain, the clean corner, wear kept light (rubs over a quarter on
  under 12 % of the mask, scratches under 2 %), the pressed copy, repaint, cache bound and clear.

## Decisions

- **Bots' copies stay plain** (default): at 3,000 triangles and figure distance the wear would not read; they keep the
  plain StandardMaterial3D.
- **Magazines scratch 2.5 times as much, the pistol's slide 1.6 times** (default): the parts handled most.
- **Grime is a light, near-neutral grey** (shade 0.12, tint 0.96/0.95/0.94; attempt 1 was 0.2 and a brown
  0.85/0.78/0.70): brown on white and grey paint read as a painted stripe.
- **A metal part shows bare metal only where rubbed hard** (rub squared in the shader), so a faint rub on a lip never
  lightens it into a bar.
- **2K masks** (the texture budget's cap), BPTC with mipmaps.
- **Parts, figure parts and the sniper are not rebuilt**: their models carry no wear; clean rebuilds differ from HEAD
  only by build noise.
- **arms.glb is not rebuilt**: a rebuild against the worn pistol (more vertices from the UV seams, same shape) moves
  the pistol hold's finger curls by under 1° (quaternion components ≤ 0.009; every other hold identical), so the
  approved holds stay as they are; the next arms rebuild (the SMG's) takes that change.
- **The SMG gets its wear in its own pull request**: its model is not on `main` yet; whichever merges second adds
  `wear.apply(...)` to `smg.py`.

## Known issues left

- The wear is faint in dim Depot light by design; whether it reads in play is a checklist item for the owner.

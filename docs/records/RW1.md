# RW1 · Lightly used AEG Rifle and GBB Pistol

**Review:** 1 attempt · critic PENDING · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (replica wear thread) | – | 7/8 Retry (QA Pass, performance Pass) | thin strips on the pistol (the extractor in its slot, the frame's rail slot) wore or grimed whole and read as a recoloured part or a stain, not as wear |
| 2026-11-10 | 2 | Opus 5.5 (replica wear thread) | PENDING | PENDING | – |

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
- **Grime greys more than it browns, and lightly** (attempt 2: shade 0.12, tint 0.92/0.88/0.82): a groove welded into
  a big part (the pistol frame's rail slot) can't be faded per part, and a brown floor read as a painted stripe on white
  and grey paint; a light grey shade reads as dirt in the slot.
- **2K masks** (the texture budget's cap), BPTC with mipmaps.
- **Parts, figure parts and the sniper are not rebuilt**: their models carry no wear; clean rebuilds differ from HEAD
  only by build noise.
- **The SMG gets its wear in its own pull request**: its model is not on `main` yet; whichever merges second adds
  `wear.apply(...)` to `smg.py`.

## Known issues left

- The wear is faint in dim Depot light by design; whether it reads in play is a checklist item for the owner.

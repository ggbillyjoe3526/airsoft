# RW2 · Lightly used alternative magazines

**Review:** 1 attempt · critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (replica wear thread) | ✓ | 7/8 Accept (QA Pass, performance Pass) | – |

## What changed

Owner, 2026-11-10: "make sure that magazine models also have the cosmetic changes. for example, the aeg rifle
extended/low cap magazine models aren't touched." and "check the gbb and smg magazines too." The standard magazines
were worn with their replicas in RW1 (the AEG's, the GBB's and, in CS2, the Compact SMG's, each its replica's
`Magazine`); the alternative ones live in the parts files and were not. Shapes, triangles and gameplay are unchanged.

- **Masks for the parts files' magazines** (`tools/blender/parts/magazines.py`): RW1's `wear.apply` run on the AEG's
  Hi-Cap and Low-Cap (one 1K mask, seed 4) and the GBB's Extended (1K, seed 5), scratches times 2.5 as the replicas'
  magazines have them; Godot writes them as `replicaParts/aeg_wear.png` and `pistol_wear.png` (BPTC, mipmaps, as RW1's).
  Texel 0.32 mm (the AEG's own mask 0.44) and 0.15 mm (the GBB's 0.19).
- **Only the magazines** (`wear.apply(only=...)`): the parts file's other parts share the painted materials and carry
  no UV layer, so the worn parts get their own copies (`<name>.worn`), and `wear.unsuffix` names them back in the glb,
  so ReplicaPaint knows them by their part's name. `figure_parts.py` keeps the names through its rewrite
  (`wear.resuffix`) and puts each figures' copy on the plain paint with no UV layer (`wear.plain_copy`).
- **No game code**: ReplicaPaint already wears any surface whose material carries a mask, and a fitted part is painted
  with its replica.
- **Tests** (`test_magazine_wear.gd`, 6): the masks on every painted surface of the three magazines, unwrapped; every
  other part and figures' copy plain; the standard magazines worn with their replica; a fitted Hi-Cap and Low-Cap wear
  the worn paint with their file's mask (plain on a plain apply); the figures' copies plain; the wear light.

## Decisions

- **Parts file cap 4 MiB** (from 3; default): the AEG's parts file is 3.89 MB with the mask (0.48 MB) and the UV
  layers; the game ships the imported meshes and the compressed mask (about 1.3 MB each at 1K), not the glb, so the
  install budget is not at stake. A 512 mask without the first UV layer would still be over 3 MiB.
- **1K masks**: the nearest power of two to the replicas' own texel size.
- **Figures' copies plain**, as RW1's.
- **Build noise**: the rewrite of the AEG's and GBB's parts files moves a few vertices in other parts (import and
  export round trip, as every earlier run of these scripts); the Cyber's, Sniper's and SMG's parts files are not
  rebuilt (no magazine parts; only build noise).

## Known issues left

- The AEG's parts file has 7 % of its cap left (docs/KNOWN_ISSUES.md: a quantised export is the fix when the next part
  needs room).
- Critic advisory: the AEG magazines' mask is finer than the rifle's own (0.32 mm against 0.44 mm a texel), so their
  scratches come out a little crisper; the Low-Cap's right side is the busiest. A play check asks whether a swap
  between the standard and the Hi-Cap or Low-Cap reads the same.

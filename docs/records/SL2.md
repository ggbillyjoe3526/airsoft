# SL2 · Sunlit Concrete: wear on the models

**Review:** 1 attempt · critic Accept 7/8 (Opus) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (build thread) | ✓ | 7/8 Accept | – (check 7: a hard switch between the top and side projections, and a long line; both fixed before the PR) |

## Decisions

- **Procedural, in world space, in the shared model shader** (`look_vertex.gdshader`), not decals or new textures:
  every vertex-coloured map model wears at once, on every map and preset, at no texture or install cost, and no two
  props wear alike. Four value noises of a sin-free hash, behind a uniform branch, so a clean material pays nothing.
- **Four wears, from the concept's renderer:** grime climbing up to 0.9 m from the foot, ragged; thin streaks down the
  sides (14 a metre, faded where finer than a few pixels so they never shimmer); broad faint stains; pale dust on
  tops (normal over 0.7 up). Strengths 0.6, 0.28, 0.15 and 0.4 of the paint, tuned on Depot's renders: stronger stains
  read as lighting faults on the plywood.
- **A material's `wear` times the look's** (`LookConfig.wear` 1, with the `grime` `#4a4136` and `dust` `#b3a994`
  colours, three new globals). `wear` defaults to 0, so the greybox, bushes, woods, skyline, flags, lamps and roof
  stay as they were.
- **Per model:** `PropDressConfig.wear` 1 for the props; `model_wear` puts the racking at 0.35 (its model's floor is
  under its bottom pallets, so its goods would grime like walls) and the trees' crowns at 0. The props' materials are
  keyed by roughness and wear, so Depot gains one material (the racking) and Woodland one (the crowns).
- **Tops and sides blend** (critic): the blotch and stain noise mix the top's and the side's projections between 0.5
  and 0.7 of the normal's height, so a tyre, drum or trunk shows no ring where its top meets its side.
- **The foot is the model's floor, not its origin** (QA): PropDress sets an instance uniform `wear_floor`, the mesh
  box's bottom, as PropLayout stands it; a trunk's or tyre's origin is up to 0.36 m over its foot.
- **Left as they are:** a stack of tiled cells (a crate wall's tiers) grimes at each cell's own floor, which reads as
  dirt along the joints; grime and dust go through `look_paint` like any paint.

## Known issues left

- Doors, roof steel and lamps, light fixtures and sandbags draw clean, and no model has edge scuffs yet: SL3 repaints
  the doors and roof and paints scuffs into the models (`docs/KNOWN_ISSUES.md` › Art).
- The wear's noise runs on Low too; Depot on Low needs a frame-time check on real hardware (`docs/KNOWN_ISSUES.md` ›
  Graphics, the playtest checklist).

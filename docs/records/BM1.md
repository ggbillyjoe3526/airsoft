# BM1 · The BB model

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | see Checks | pending | – |

## Goal

The owner (2026-11-05: "Ok make a model") wants a 3D BB model the player sees in flight. The game already drew every BB
as a code-made ball (an 8-sided, 4-ring sphere, FB4) with a faint trail, and glowing BBs (WL8) as the tracer look; at
close range next to the muzzle the old ball's eight sides showed.

## Approach

- **Model.** `tools/blender/effects/bb.py` builds `assets/models/effects/bb.glb`: an icosphere of 320 triangles,
  smooth, 1 m across, centred, so `BBView.ball` keeps scaling it to `bb_size`. Imported with no LODs, shadow meshes
  or tangents.
- **Drawing.** `BBView.bb_mesh` takes the model's first mesh (`EffectsConfig.bb_model`) once a match; the white and
  glowing MultiMeshes share it, each with its own `material_override` (the rim shader, the unshaded green). An
  unreadable file warns and draws the old code-made ball. Ballistics, sizes, colours, trails and streaks unchanged.

## Decisions (Claude's defaults)

- **Tracers stay glowing BBs** (the owner's 2026-10-05 ruling cut a separate tracer option): the same mesh in the
  glowing material, no model of their own.
- **320 triangles:** round at the size a BB is seen by the muzzle at 4K; the whole 256-BB pool is 82k triangles in
  one draw, all a few pixels across past a few metres.
- **No mould seam or texture:** a BB is at most a few dozen pixels across, and a seam would never show.

## Checks

Pending.

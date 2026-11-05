# BM1 · The BB model

**Review:** critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | see Checks | Accept 7/8 (QA Pass, performance Pass) | – (must-fixes done: header comments rewrapped, `bb_mesh` notes the node transform is dropped) |

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

- gdlint, changelog notes, wiki and unit tests part 2 pass locally; part 1 stopped on its local cloud timeout, so CI on
  the pull request is the authority. `test_bb_sight.gd` and `test_glow_bbs.gd` pass 23/23.
- Before/after render of a BB 0.25 m from the eye, white and glowing, pale and dark backgrounds (shared folder
  `art/blender/bb/bb-before-after.png`): the old ball's eight corners and uneven rim are gone.
- Performance kept 320 triangles over its advice of 80: the critic measured an 80-triangle outline about 2 px off round
  at the muzzle close-up, 320 about 0.6 px.
- Not verified here: the look in a real match and frame time on a low-spec PC (docs/PLAYTEST.md › The BB model).

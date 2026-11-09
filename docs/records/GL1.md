# GL1 · Woodland's north bridge glowing (Dev 3 bug)

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## What it was

- **Seen:** in the Woodland eye pictures (WG2, DM1 threads; main at a09063b), the trunks, grass and spruces round the
  north bridge drew as black slivers with white halos, by day, from Medium up. The bridge's own blocks drew fine.
- **Cause, found by elimination** (`tools/eye_pictures.gd` on Forward+, lavapipe): with the reflection probes hidden it
  was gone; hiding only probe `Area15` (the 19 x 21 m area north of the bridge, its box 12 m tall over the stream's
  slopes) cleared it, and `Area15` alone brought it back. A mirror ball in it showed the probe's sharp level clean but
  its blurred levels (roughness 0.3 to 0.6) NaN, so every surface in its box rough enough to read them drew NaN, and
  the glow spread it into the halo. Moving its capture point 0.5 m up or down, or keeping the greybox and terrain out
  of its capture, also cleared it.
- **Why there:** Godot ends each of a probe's six views at its box's side when `max_distance` is 0
  (RendererSceneCull's probe render: far = the distance from the capture point to that side). Area15 captures at eye
  height over its middle, 2.24 m above its box's floor, so its downward view stopped inside the hillside; the cut
  through the hill is where the bad values came from. Setting its `max_distance` to 40 m cleared it.

## Decisions

- **Every probe sees at least 40 m** (`LookConfig.probe_reach`, `AreaProbes._add` sets `max_distance`), on every map,
  not only Area15: any probe on sloping ground had the same cut, and it also made shiny surfaces reflect sky where the
  hill should be. Box projection still maps what lies past the box onto its sides, so reflections stay put.
- **Look change kept (default):** surfaces on slopes now reflect the green hillside instead of sky, so a few places
  read a touch warmer (the Clearing's ground and trunks, sheet 2). More correct, so kept.
- **Cost:** the probes still capture once at the start (UPDATE_ONCE); each face now draws what lies within 40 m
  instead of within its box, a one-off cost while the round loads. Nothing per frame.

## Pictures

- `art/bugs/woodland-bridge-glow/1-north-bridge-before-after.jpg`, `2-elsewhere-before-after.jpg` (project files):
  main against the fix from the same spots, High by day.

## Known issues left

- Seen only on the cloud's software Vulkan (lavapipe); the cut-off capture was wrong on any GPU, but whether a real
  card turned it into the black marks is unverified. Play check on the Dev 3 checklist.

# GL1 · Woodland's north bridge glowing (Dev 3 bug)

**Review:** 2 attempts · critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (build thread) | tools/check.sh green | Retry 7/8 | 40 m reach darkened the Clearing about 30 %; Depot and Range not pictured; record overstated the mechanism |
| 2026-11-09 | 2 | Opus 5.5 (build thread) | tools/check.sh green | Accept 7/8 | – (should-fix taken: the test and the config comment no longer blame the view down alone; a KNOWN_ISSUES row) |

## What it was

- **Seen:** in the Woodland eye pictures (WG2, DM1 threads; main at a09063b), the trunks, grass and spruces round the
  north bridge drew as black slivers with white halos, by day, from Medium up. The bridge's own blocks drew fine.
- **Trigger, found by elimination** (`tools/eye_pictures.gd` on Forward+, lavapipe): with the reflection probes hidden
  it was gone; hiding only probe `Area15` (19 x 21 m north of the bridge, its box 12 m tall over the stream's slopes)
  cleared it, and `Area15` alone brought it back. A mirror ball in it showed the probe's sharp level clean but its
  blurred levels (roughness 0.3 to 0.6) NaN, so every surface in its box rough enough to read them drew NaN, and the
  glow spread that into the halo.
- **What clears it:** Godot ends each of a probe's six views at its box's side when `max_distance` is 0
  (RendererSceneCull's probe render: far = the distance from the capture point to that side). Area15's views ended
  2.24 m below the eye (in the hillside) and 9.5 to 10.5 m to the sides (in the trees). A `max_distance` of 12, 20 or
  40 m cleared it; reaching only the view down (box floor + 4 m, attempt 2's first try) did not, nor did hiding the
  props from its capture.
- **Not identified:** which pixels of the capture go bad. Moving the capture point 0.5 m up or down also cleared it,
  and a camera at the capture point with the probe's near, far and up vectors rendered no NaN or negative value, so the
  bad values arise in Godot's probe pass or its blur on this renderer, set off by views that end close round it.

## Decisions

- **Every probe's views reach at least 12 m** (`LookConfig.probe_reach`, `AreaProbes._add` sets `max_distance`), on
  every map. Views to a farther box side keep that side, so large areas (the Clearing, Depot's hall areas) look as
  before; small and sloping ones see a little past their box.
- **Not 40 m** (attempt 1): its views took in the dark wood far past each area, and the Clearing's ground, trunks and
  crowns drew about 30 % darker than the crowns outside its box. 12 m keeps the Clearing as it was (pictures v2).
- **Cost:** the probes still capture once at the start (UPDATE_ONCE); a face whose box side was under 12 m now draws
  out to 12 m, a one-off cost while the round loads. Nothing per frame.

## Pictures

- `art/bugs/woodland-bridge-glow/v2/1-north-bridge.jpg` (the glow gone from three spots) and
  `v2/2-unchanged-elsewhere.jpg` (Woodland north-east and the Clearing, Depot's hall and racks, the Range's firing line
  and lanes: unchanged), project files, main against the fix, High by day.

## Known issues left

- Seen only on the cloud's software Vulkan (lavapipe); whether a real card ever drew the black marks is unverified.
  Play check on the Dev 3 checklist; a playtest row in `docs/KNOWN_ISSUES.md`.

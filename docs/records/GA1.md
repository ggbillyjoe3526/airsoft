# GA1 · The figures' running animations

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | figure, hit and hitbox tests pass (23 files, 243 tests) | Retry 6/8 (QA Pass, performance Pass) | every gait a bent-knee crouch-run (hips 0.86 m), no flight, the swing foot dragging; back-pedal and strafes forced onto the forward run's 2.94 m cycle (1.47 m lunges); the crouch walk sitting back on its heels, feet ahead; knees crossing on the strafes |
| 2026-11-05 | 2 | Claude (build thread) | figure, hit, hitbox and gait tests pass (24 files, 253 tests) | pending | – |

## Why

The owner (2026-11-05): "The running animations right now are very bad so they need reworked and improved for the
figure." Filming the figure in game (`tools/gait_pictures.gd`) showed three causes:

- **The legs cycled up to twice too fast and the feet skated.** The game moved every stepping clip one cycle per
  1.33 m (`HitConfig.strides_per_metre` 0.75) whatever the speed, while the clips were made for 2.4 m (run) to 3.2 m
  (sprint) a cycle: a sprint stepped about 9 times a second and every planted foot slid.
- **The clips were thin:** 12 to 17 frames, short stance, both strafes crossing the legs through each other.
- **The upper body rode the hips.** The aim clips lie over the legs from the Spine up, so every turn of the pelvis in
  a stepping clip turned the replica with it.

## What changed

- **New clips** Walk_F, Run_F, Run_B, Run_L, Run_R, Sprint and CrouchWalk, made in code by
  `tools/blender/bot-figure/gait/gait.py` (numpy, no Blender) on the shipped skeleton and spliced into `human.glb` and
  `robot.glb` by `splice.mjs`: clips only, the rig, meshes and every other clip byte for byte as they were. Each foot
  is planted at a fixed spot for its stance and rolls heel, flat, ball (the back-pedal stays on the ball), so it never
  slides at the clip's speed; the swing is a smooth arc (the heel kicked up on a run); the pelvis bobs, sways, turns
  with the swinging leg and drops on its side; the hips sink only where a foot would be out of reach; two-bone IK
  with the knee in the foot's own plane. Keys at 60 a second. The upper body keeps the old clips' (the aim covers it).
- **Cadence by speed and way** (`HitConfig.cycle_speeds`/`cycle_metres`, crouched `crouch_cycle_*`, `back_cycle_share`,
  `side_cycle_share`; `Hitbox.cycle_length`): the walk cycle moves one cycle per the clip's own speed × seconds (walk
  1.76 m at 2.3 m/s, run 2.94 m at 4.2, sprint 3.99 m at 6.3, crouch 1.26 m at 2.1), in line between; stepping back
  it is 0.619 of the run's (Run_B 1.82 m) and aside 0.667 (Run_L/R 1.96 m), blended by the step's share each way.
  `strides_per_metre` is gone.
- **Steady upper body** (`HitConfig.upper_steady`, `FigureBend.steady_upper`, the same turn in `HitPose`): over a
  stepping clip the upper chain is turned back about the hips to standing still's hips heading (`HitFit.still_heading`,
  crouched blended), so the pelvis may swing and turn 38° into a strafe while the replica keeps its heading. The hit
  volume's upper body turns alike (test_hit_fit holds every joint within 4 cm of the drawn one).
- **Clips in step by their travel:** `FigureGraph.forward_time` measures the left leg's swing along the clip's own way
  (back for Run_B, aside for the strafes), so every clip's leading left leg meets FORWARD_PHASE and neighbours blend in
  step.
- **Hit fit** re-baked, at 32 phases (was 24): the faster crouched swing left a 5 cm gap between samples at 24.
- `tools/gait_pictures.gd`: films the figure stepping each gait in game on a chequered floor (before/after pictures).

## Defaults taken (owner not asked)

- Game speeds unchanged (walk 2.3, run 4.2, sprint 6.3, crouch 2.1 m/s); cadence set from them: walk 156, run 171,
  sprint 190, back-pedal 277, strafe 257, crouch walk 200 steps a minute (quick short steps back and aside).
- Run and sprint stand tall (hips 0.92 and 0.90 m at the top of the bob, ±4 to 4.5 cm with a flight phase), land the
  foot near under the hips and kick the heel straight up after toe-off.
- Strafes turn the pelvis 35° and the feet 25° into the step, the legs on lanes apart so the knees never cross; the
  upper body stays square to the aim.
- The crouch walk keeps the hips 0.62 m down (the crouch line) and walks on the balls of the feet, the feet under the
  hips, the knees forward, up and a little out: with the aim owning the upper body, the low hips leave no other way
  to keep the knees off the floor.
- Sprint leans the pelvis 14° forward, so the shouldered replica dips 14° while sprinting (sprinting can't aim well).

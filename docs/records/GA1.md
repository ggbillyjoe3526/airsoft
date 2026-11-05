# GA1 · The figures' running animations

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | figure, hit and hitbox tests pass (23 files, 243 tests) | Retry 6/8 (QA Pass, performance Pass) | every gait a bent-knee crouch-run (hips 0.86 m), no flight, the swing foot dragging; back-pedal and strafes forced onto the forward run's 2.94 m cycle (1.47 m lunges); the crouch walk sitting back on its heels, feet ahead; knees crossing on the strafes |
| 2026-11-05 | 2 | Claude (build thread) | figure, hit, hitbox and gait tests pass (24 files, 253 tests) | Retry 6/8 | run and sprint fixed; the crouch walk a full-squat duck walk, the swing knee splayed out like a frog, the thigh in the forearm; every standing gait's torso upright or back over hips pushed forward; no named references; the changelog over-claiming |
| 2026-11-05 | 3 | Claude (build thread) | figure, hit, hitbox and gait tests pass; tools/check.sh | Accept 8/8 (QA Pass) | – |

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
  1.76 m at 2.3 m/s, run 2.94 m at 4.2, sprint 3.99 m at 6.3, crouch 1.05 m at 2.1), in line between; stepping back
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

## References

No video was laid side by side. The numbers were checked against published gait norms instead: a recreational run at
4 m/s about 160-180 steps a minute with each foot down about a quarter to a third of the cycle and a flight phase
between; a sprint's lean and shorter ground contact; a walk always with one foot down; and the photographic running,
walking and crouching series in Muybridge's *Animal Locomotion* (1887, public domain) for the heel kick, the foot
landing near under the hips and the forward lean. The before pictures of the old clips are the comparison the owner
sees (`/mnt/project-files/art/animation/ga1/`).

## Defaults taken (owner not asked)

- Game speeds unchanged (walk 2.3, run 4.2, sprint 6.3, crouch 2.1 m/s); cadence set from them: walk 156, run 171,
  sprint 190, back-pedal 277, strafe 257, crouch walk 240 steps a minute (quick short steps back, aside and crouched).
- The pelvis leans into the step: walk 4°, run 8°, back-pedal 6° (weight over the balls of the feet), strafes 3°. The
  aim clips ride the hips, so the replica dips by about as much while stepping, as the old clips' did.
- Run and sprint stand tall (hips 0.92 and 0.90 m at the top of the bob, ±4 to 4.5 cm with a flight phase), land the
  foot near under the hips and kick the heel straight up after toe-off.
- Strafes turn the pelvis 35° and the feet 25° into the step, the legs on lanes apart so the knees never cross; the
  upper body stays square to the aim.
- The crouch walk stays as low as the crouch rule makes it (the head's top at most 1.15 m, under 1.2 m crouch cover,
  DECISIONS 2026-09-30): hips 0.39 m, the pelvis and torso 17° forward, short quick steps (1.05 m a cycle, 240 a
  minute) on the balls of the feet a little ahead of the hips, the knees over the toes 10° out (the swing knee no
  longer splays out, the trailing knee stays 16 cm or more off the floor, the thigh clears the forearm by 10 cm).
  A taller crouch walk, hips about 0.55 m with the back bent well forward and the head and replica held up, needs
  either a higher crouch_top_max (the owner's crouch-cover ruling) or a new crouched upper body over the aim; offered
  to the owner as a follow-up, not built.
- Two tests that leaned on a moving figure's exact pose were made robust, not loosened in meaning: `test_bots` caps the
  BBs that bounce into a teammate at 3.5% of the hits (was a count of 6; 3 of 224 before the new legs, 7 of 242
  after, over the same 8 seeded matches), and `test_pings` stands the body that blocks sight where the line crosses its
  chest, not the seam between its chest and head (a walking body's stride put the line through that seam).
- Sprint leans the pelvis 14° forward, so the shouldered replica dips 14° while sprinting (sprinting can't aim well).

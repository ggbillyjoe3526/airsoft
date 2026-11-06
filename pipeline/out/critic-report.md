Task: GA1 · The figures' running animations (no task block; judged against the brief and the record)
Attempt: 3 of 4
Head: 30fb3ba (targeted tests 38/38 per brief; full check.sh running separately. QA Pass at 30fb3ba, uncommitted
qa-report.md; performance Pass at a1bbbc9, attempt 3 changed only clip data, the crouch cycle and the test)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept (subject to the full check.sh passing on 30fb3ba)
Evidence (frames in scratchpad c1/, c1q/, compared with b1/, b1q/):
1. Attempt-2 must-fixes met. Crouch walk inside the 1.15 m ruling: knees forward over the toes, no frog splay
   (c1q/crouch_008, crouch_012); the trailing knee clear of the floor (c1/crouch_024); the swing knee stops under the
   forearm, not in it (c1/crouch_008); short heel-up steps (gait.py:61-64, 1.05 m, 240 a minute). Back-pedal: the torso
   now upright over the feet, no longer leaning back; the knee about over the toes (c1/back_000, back_008 against
   b1/back_000, back_008; Run_B pitch 6, bias 0.03). Run: shoulders over the hips, flight and heel kick kept
   (c1/run_000-015). Walk, sprint and strafes still read well (c1/walk_*, sprint_*, left_*). References named honestly
   (GA1.md › References). Rig and meshes unchanged, so the models rule's proportion ratios don't apply to clips.
4. test_gait_cycle.gd:+160 turns the character a quarter and steps +X (back) and -Z (aside); a sign slip in
   step_walk_cycle reads +X as ahead and fails the 0.619 share. Locks in my attempt-2 advisory.
8. changelog.d/figure-running.md no longer over-claims; PLAYTEST.md:72-74 asks about the right things now.
The owner's call, not a block: the crouch walk is still a deep squat walk (hips 0.39 m, the swing thigh above level,
c1/crouch_008, c1q/crouch_028). That is what crouch_top_max 1.15 under an aim-owned, near-upright upper body allows
(DECISIONS:279). A taller one (hips ~0.55 m, back bent forward, the replica held level) needs either his crouch-cover
ruling changed or a new crouched upper body over the aim, which is outside GA1's clips. The record offers it
(GA1.md › Defaults); the thread must put it to him in its report, not leave it only in the record.
Advisory (no fix needed now): c1q/crouch_028 the swing shin flicks out a little as it passes; the dead clip data
splice.mjs leaves in the .glb adds about 0.4 MB a figure (performance advisory); Run_F's 8° and Sprint's 14° dip the
replica while moving (recorded default).
Must-fix for the next attempt: none.
Owner should test in the game:
- Crouch-walk past a bot side on and three-quarter: is this low squat walk acceptable, or do you want the taller,
  bent-forward crouch walk (needs crouch_top_max raised or a new crouched upper body)?
- Back-pedal a bot (hold S): does it read as stepping back with weight forward, and do 4.6 steps a second look right?
- Run and sprint a bot past you: does the forward lean read well, and is the replica's dip while running acceptable?
- Strafe-duel a bot: does the 35° hip turn under a square rifle convince at range?
- Run diagonally (W+A, S+D): do the feet slide where the clips blend?

Task: GA1 · The figures' running animations
Attempt: 2 of 4
Head: 49595f5 (full check.sh still running per brief; test_gait_cycle + test_hit_fit re-run here: 13/13, 362 asserts.
QA and performance reports are attempt 1's, head a1bbbc9: neither has seen way_share in hitbox.gd)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 6/8 → Retry (check 1 blocking, judgment)
Failed checks, with evidence (frames in scratchpad b1/, b1q/, b1f/):
1. [judgment] Models rule. Run, sprint and walk are now much better: tall, a real flight phase, heel kick, feet planted
   (b1/run_000, run_008, sprint_004). Strafe lanes hold: the feet never swap order side on (b1/left_000-014). But:
   - (b) construction / (c) pose / (d) bar: the crouch walk is a full-squat duck walk, hips at 0.345 m
     (gait.py:61 height=0.345), at 2.1 m/s and 200 steps a minute. The lifted thigh drives into the plate carrier and
     forearm (b1q/crouch_004, b1/crouch_010), the trailing knee all but touches the floor (b1/crouch_010), and the swing
     knee splays out level at chest height like a frog hop (b1q/crouch_012; knee_pole out share 0.12). Nobody moves
     like that with a rifle. Attempt 1's must-fix 1 said to ask the owner if crouch_top_max 1.15 under an upright,
     aim-owned torso can't be met any other way. The record lists it as a default taken, owner not asked
     (GA1.md, Defaults).
   - (d) The upper body sits back over hips pushed forward on every standing gait: the torso is upright to slightly
     back while running (b1/run_005, b1/walk_000, Run_F pitch=3). On the back-pedal it leans back with the leading knee
     well past the toes (b1/back_000, back_008; Run_B pitch=-1). A back-pedal carries its weight forward on the balls of
     the feet. As it stands it reads as being shoved.
   - (a) No reference footage is named in the record (attempt-1 must-fix 6), so there is nothing to compare side by
     side, as the rule requires.
8. [judgment] The docs claim more than the clips do. changelog.d/figure-running.md says "instead of a frantic
   shuffle", but the back-pedal steps at 277 and the strafes at 257 steps a minute (GA1.md, Defaults).
   docs/PLAYTEST.md still asks about "feet ahead, sitting back", which was attempt 1's crouch.
Advisory: no test drives step_walk_cycle backwards at a non-zero yaw. A sign slip in the velocity-to-frame transform
(hitbox.gd:+183) would pass test_stepping_back_or_aside (it calls cycle_length directly). I checked the maths by hand
and it is right; one test would lock it in.
Must-fix for the next attempt, ranked:
1. Crouch walk: ask the owner now (request a decision). (a) Pitch the torso forward 20-30° with the hips ~0.55 m and
   the arms keeping the replica level (FigureBend's aim_lean already pitches the upper chain). (b) Raise
   crouch_top_max. Either way: no thigh into the vest or forearm, knees forward and only slightly out, the trailing
   knee at least 15 cm off the floor, and a short, quick heel-up step.
2. Back-pedal: pelvis pitch forward 5-8°, weight over the balls, the knee over the toes and not past them.
3. Run: forward lean of about 6-8° (pitch 3 → 7) so the shoulders sit over or just ahead of the hips.
4. Name the reference clips in GA1.md (a run, sprint, back-pedal and crouch walk carrying a rifle) and add a
   side-by-side sheet.
5. Fix the changelog wording and the stale PLAYTEST line. Re-run QA on hitbox.gd way_share.
Owner should test in the game:
- Crouch-walk past a bot side on and three-quarter: does a duck walk at this speed look acceptable?
- Back-pedal a bot (hold S): does 4.6 steps a second read as a scurry, and does it lean back?
- Run and sprint a bot past you: do the flight and the heel kick read well, and is the run upright enough?
- Strafe-duel a bot: is the 35° hip turn under a square rifle convincing at range?
- Run diagonally (W+A): do the feet slide where Run_F and Run_L blend?

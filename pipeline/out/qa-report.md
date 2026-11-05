Task: GA1 · QA commit 30fb3ba (no new commit; no tests added) · Verdict: Pass

Scope: git diff a1bbbc9 30fb3ba (hitbox.gd, hit_config.gd, hit_fit.tres, hit_pose.gd, gait.py, test_gait_cycle.gd).

Blocking: none. Advisory: none.

Checks
- Yaw/sign: step = (vx*cos - vz*sin, -vx*sin - vz*cos) matches FigurePose.read (figure_pose.gd:102-103: ahead, right) exactly; forward at yaw 0 is -Z (y=+1 for velocity -Z). Quarter-turn test (yaw PI/2 faces -X: +X is back, -Z is right) agrees by hand.
- way_share: total==0 returns 1.0, so no divide by zero or NaN; an unnormalised step is fine (ratio). Continuous across y=0 (ahead and back both 0 weight at the seam), so no jump in cycle rate between forward and back. Diagonals weight by |components| (L1), so a 45 degree back-left is (back+side shares)/2; a design choice, tested at the ahead/side diagonal.
- cycle_length: share applies to the standing term only; crouch lerp is clamped 0..1, partial crouch is a linear blend, MIN_CYCLE floor keeps the divisor positive even with share set to 0 or negative. Crouched length ignores the way (tested; the 1.05 crouch metres is within the table).
- step_walk_cycle: velocity zero with moved>0 (teleport/push, below max_stride) gives step zero, share 1, finite. Uses c.yaw while FigurePose uses an interpolated yaw: negligible (sub-tick). Applied to bots too: Simulation calls it per character (simulation.gd:167), same code path.
- Phase: only the rate changes with direction, never the phase, so no pop when switching direction.

Tests: test_gait_cycle.gd (11 tests incl. back/aside/diagonal/no-step/crouch and the own-frame quarter-turn case) + test_hitbox + test_figure_animator: 36 passing, 0 failing, 880 asserts. Not run: tools/check.sh (already running), smoke test.
Not testable here: how the shorter back/side cycles look against the Run_B/Run_L/R clips (needs a display; owner to eyeball foot sliding going backwards and strafing, and crouch-walk at 1.05 m).

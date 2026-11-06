Task: HC1 · The hit call's raised arm (no task block; judged against the owner's words of 2026-11-05, the record and attempt 2's must-fixes)
Attempt: 3 of 4
Head: 13f0b7c = HEAD. Checks run on it: test_hit_call_arm, the figure tests and gdlint (QA: 45/45 tests, 898 asserts). QA Pass and performance Pass, both on 13f0b7c (15:04). The full tools/check.sh runs on the PR's CI.
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence (measured with arm2.py on human.glb and robot.glb, and from the h4/h4f/h4q renders):
1. Held (f14+): elbow 15°, wrist 5.2°, curl 6.1° (robot 6.1°), hand 0.51 m over the shoulder. In h4f/h4/h4q call_030 at 4x, a flat open hand continues the forearm, thumb alongside.
   Raise: hand-sh -0.31 → 0.51 rises on every frame from f03 to f13, x at most 0.41 m, wrist ≤5.5° from f02, and the elbow eases 51° → 15° with no fold.
   Curl 45 → 34 → 22 → 11 → 6.5° at f03-f07 (robot 11° at f07). No palm-up cupped hand after f05 (h4/call_006 shows an open hand).
   call.py:28 OUT (0.20, 0.85, 0.50); call.py:156-157 the hand and fingers on their own OPEN_BY share.
4. test_hit_call_arm.gd:43-44: with RAISE_CURL 20 from 0.25 s, attempt 2's clip fails (28° at f08). The knuckle term at :92 closes the MCP gap. The test fails on the base glbs (QA ran it).
2/3/5: clips and dev tools only; no runtime code, contract or per-frame path changed.
Not blocking:
- The raise pushes forward before it climbs: z 0.49 → 0.63 m at f05 (an arm's length).
  From the side, h4/call_004-006 read as a palm-up "offering" hand, and call_007 as a stiff arm 45° forward.
  It lasts 2-3 frames and the arc reads as "hand up", but a OUT z near 0.35 would keep the hand nearer the body.
- The test's OPENED_BY is 0.25 s (:16), but call.py's OPEN_BY is 7/30 = 0.233 s, so f07 isn't checked and the comment is wrong. Use 7.0 / 30.0.
- call.py:12 is 126 columns (house width 120).
- QA's advisory: _globals skips a renamed bone silently. Assert that Hand_L and Middle1_L are found.
- Scope: hc1 is stacked on GA1 (PR #207, open). origin/main...HEAD carries GA1's gait work (gait.py, glb.py, test_gait_cycle, hitbox...).
  Open HC1's PR only after #207 merges (rebase), or base it on #207's branch, so its diff is HC1's 15 files.
Must-fix: none.
Owner should test in the game:
- A bot calling a hit at 3-5 m, seen from the side: the arm swings forward and up, not like a salute or an offered hand.
- The held hand from the front and side: flat, open, wrist in line with the forearm.
- Crouched near a hit bot: the fingertips (2.07 m) against the HIT! sign's "!" (recorded default).
- Walking off: the 3-4° sway looks alive; the dark shoulder edge is the KNOWN_ISSUES row.

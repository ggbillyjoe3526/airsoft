Task: MT1 · Kingsmere, the metro station, as a Dev-only greybox map (no task block; judged against the owner's v2 brief)
Attempt: 2 of 4
Head: 13efbccb (check.sh passed on 82002d94; since then QA's tests, 77779ede, the reports and this fix, whose tests
test_mt1, test_mt1_qa, test_two_flags and test_flag pass 53/53 and gdlint is clean, per the coordinator)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Failed checks, with evidence: none.
1. Fixed: game/play/flag_view.gd:250-261 letter_height() puts a low pole's letter middle at its top (3.4 x 0.618 =
   2.10 m) and :275-276 shrinks pixel_size by the same scale (glyph 0.36 m), so A's top is 2.28 m over the foot
   (3.18 m) under the car's ceiling at 2.4 m (3.3 m); with the 18 px outline about 2.35 m, still under it. Full-height
   poles unchanged (letter_height = pole_height + letter_rise).
4. tests/unit/test_mt1.gd:14-27 fails on attempt 1's code (A's top 0.9 + 2.41 + 0.29 = 3.60 > 3.3);
   :30-37 pins Depot/Woodland's letter. It ignores the outline (about 5 cm of margin left).
3/5/7: the new code runs once in setup; typed; values from FlagViewConfig. 8: tests/README.md:10 and
   tests/support/dev_content.gd:4-5 no longer say every shipped map is public; game/play/README.md updated.
Advisory (non-blocking): on a low pole the letter now sits on the finial and overlaps a fully raised cloth's top
corner; area_probes.gd `probe_eye * 2.0` is still a bare factor.
Must-fix for the next attempt: none.
Owner should test in the game (at most 6, one line each):
- Attack / Defend: is the small "A" in the south car readable from the platform doors, and not hidden by the cloth?
- Fall into the south track pit: does walking up to 40 m to the end steps feel like a fair trap or a chore?
- Do the Tunnel team's pushes through the south car and up the stair feel fair (attackers won 67.7 % in 8 seeds)?
- Does the 58 m platform line take over the lower level, or just open it up as the brief wanted?
- Medium preset: is the flat, unlit-looking shading underground playable (the KNOWN_ISSUES row)?
- High and Ultra on your hardware: frame time with 106 shadowed strip lamps.

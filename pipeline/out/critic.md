Task: HV1 · The hit area fitted to the drawn figure (follow-up commit, judged on git diff 5c84f56..f195e18 only)
Attempt: 2 of 4 (follow-up to attempt 2's Accept at e6c1970)
Head: f195e1827caeb18a29d70c7e1a77311ac9f9bfae (coordinator's run: seed 9 now has no friendly hit; CI pending)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✗ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Evidence for the passes:
1/6. bot_combat.gd:371-378: an in-play crouched mate's volume is also tested raised by crouch_drop x crouch_amount, then
   shifted back before the velocity and route shifts, so the later tests are unchanged. Bots still never fire with a mate
   in the line (AC6), and a mate standing up into a burst is now covered.
2/3/5. No contract touched; _shift gains a dy default (values only, no allocation); crouch_drop comes from HitConfig.
   may_touch's coarse capsule (volume_top + reach + room) still covers the raised crouched volume.
8. The test bar change (own-shooter 4 % to 5 %) is measured (10/224 over 8 seeds, 17/485 = 3.5 % over 16) and recorded
   in the test's doc comment and HV1.md › Defaults taken.
Failed checks, with evidence:
4. [judgment] The fix has no GUT test. The commit only loosens test_bots.gd:160's bar, and no test in tests/unit/test_bot*.gd
   puts a crouched teammate under the line. The CI match guard (seed 9) caught it, but it is a 16-seed whole-match run, not
   a unit test that pins the rule.
Must-fix for the next attempt: add a test in test_bots.gd next to test_a_bot_holds_fire_with_a_teammate_in_the_line
(:181). A crouched, still teammate sits just under the line, which passes over its crouched head but through its
standing head. The bot must hold fire, and the test must fail with the rise block (bot_combat.gd:371-378) removed.
Owner should test in the game:
- Crouch in front of a bot teammate in a fight, then stand: it holds fire over you and doesn't knock you out.

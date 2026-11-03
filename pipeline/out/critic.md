Task: HV1 · The hit area fitted to the drawn figure (follow-up commits, judged on git diff 5c84f56..2b89dcb only)
Attempt: 2 of 4 (follow-up to attempt 2's Accept at e6c1970)
Head: 2b89dcbf23adfba8469a41c528ed4398f5b4f26d (test_bots.gd 17/17 green on it per the coordinator; CI pending)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence:
1/6. bot_combat.gd:371-378 tests an in-play crouched mate's volume raised by crouch_drop x crouch_amount, then shifts
   it back before the velocity and route tests.
2/3/5. No contract touched; _shift's dy is a default (values only); the rise comes from HitConfig.
4. test_bots.gd:221 test_a_bot_holds_fire_over_a_crouched_teammate_who_could_stand_into_the_line: the line clears the
   crouched head but meets the standing one, and target_id == enemy proves the bot sees its target. 0 shots, then shots
   once the mate steps aside. The coordinator ran it without the rise block: 51 shots, fails.
7/8. The test sits beside its sibling. The ricochet bar change (4 % to 5 %) is measured and recorded in HV1.md.
Failed checks: none. Must-fix: none. Merge once CI is green.
Owner should test in the game:
- Crouch in front of a bot teammate in a fight, then stand: it holds fire over you and doesn't knock you out.

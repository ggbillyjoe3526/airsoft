Task: none · BP5 part 1, the second bug and performance pass (fixes)
Attempt: 1 of 4
Head: c8a6146 (= git rev-parse HEAD; test_bp5 8/8 and test_bp5_qa 9/9 re-run green, gdlint clean on the touched files)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✗
Score: 6/8 → Retry (process too: the committed pipeline/out/qa-report.md:1 still reads "QA commit 313eb5e · Verdict: Fail"
with no re-run after e1e319a, though BP5.md:3 says "qa Pass"; no BP5 performance report exists (performance.md is HS1's,
performance-report.md BL8b's), so the critic ran before performance, against the rule)
Failed checks, with evidence:
8. [judgment] docs/PLAYTEST.md:1515 and :1518 tell the owner to "take a smoke in hand (4)" and "take a bomb in hand (4 or 5)",
   but 4 and 5 are throw_smoke/throw_flash, instant throws (project.godot:185-190, player_input.gd:236-239); in hand is the
   wheel only (wiki Grenades.md:9-10). Following item 1 the AEG fires after the throw by design (BP5.md: "An instant throw
   (4 or 5) keeps a held full auto firing"), so the owner logs the fix as broken; item 2 tests the old throw path, not the fix.
8. [judgment] changelog.d/bp5-bug-fixes.md:3 and BP5.md:30 say the torch comes back on after a put-back by "the holster" too;
   it can't: put_down left the replica holstered, a holster press doesn't draw (armament.gd:286-297), light_in_hand() is null
   and torch_back is spent (QA's own test_bp5_qa.gd:187-200 asserts torch_on false). The patch notes promise what isn't true.
8. [judgment] 9 added prose lines over 120 columns (PROCESS.md:278), e.g. ROADMAP's DT1 sentence, wiki Replicas.md's "Sniper
   Rifle in both hands" line, PLAYTEST's AU1/WL2/FM2 lines. The KNOWN_ISSUES "pistols one-handed … fix now" row was dropped
   (correct per the owner's HG1 ruling, DECISIONS.md:175) without the record saying so; QA's flaky test_uf1_qa
   picking_the_same_dot (Camera3D interpolation error) went to no KNOWN_ISSUES row.
7. [judgment] The held-off rule is spread over five sites with two sources of truth: grenades.gd:163, :172, :183-186,
   step_throw's save/restore around stop() (:267-269, stop() now clears a flag one caller must put back), and
   simulation.gd:150-152 where Simulation writes c.grenades.trigger_held_off itself from the raw pre-vault `trigger`
   (:134) while held_off_command reads the post-vault cmd.fire. Belongs in one Grenades function (throwing_command(c, ...)
   or held_off_command covering the throw), with end-of-throw not routed through stop().
Must-fix for the next attempt: fix PLAYTEST:1515-1520 to "roll the wheel to the smoke" (and add one line that 4 with the
trigger held still fires after, as before); drop "or the holster" from the changelog note and BP5.md:30 (or make the draw
from the holster relight, as a design call); fold the Simulation write into Grenades and drop the stop() save/restore;
rewrap the long lines; re-run QA on head and commit its Pass report; run the performance agent; add the uf1 flake row.
Advisory: the Loadout test (test_bp5.gd:229) rebinds before the page is built, so refresh()'s new loop (loadout_gear.gd:203-204)
is untested; the reload put-back's torch and the ambience peak warning are untested; no performance work in part 1 yet.
Owner should test in the game:
- AEG on full auto, roll the wheel to a smoke, pull and hold: thrown, rifle back up, silent until you let go and pull.
- Same, but let go and pull again during the throw: it should fire as soon as the rifle is up (QA's fix).
- Press 4 with the trigger held: full auto fires after the throw, as before. Does the difference between the two feel right?
- Night, torch on, wheel to a bomb, then 1 (and R): torch back on, no click. Then 3 (holster): torch stays off.
- Rebind Primary to a long key name (Mouse 4, Right Shift): the Loadout card's chip fits and reads.

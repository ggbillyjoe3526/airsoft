Task: none · BP5 part 1, the second bug and performance pass (fixes)
Attempt: 2 of 4
Head: b46abbf (= git rev-parse HEAD; test_bp5 10/10, test_bp5_qa 10/10, test_grenades 28/28, test_torch 26/26 re-run green)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Retry (process only: the performance report doesn't cover this head's hot path)
Every attempt-1 must-fix is met: PLAYTEST.md:1516-1520 rolls the wheel to the smoke and adds the instant-throw line;
the changelog note:3 and BP5.md:31-33 drop the holster claim and document that it stays off; the rule is one function,
grenades.gd:187 trigger_command, called once at simulation.gd:150 with the raw pre-vault trigger (:135), and
end_throw() (grenades.gd:95, :274) replaces stop()'s save/restore; no added prose line over 120 columns outside the
changelog's one-line notes; KNOWN_ISSUES has the test_uf1_qa row; BP5.md:42 notes the dropped pistols row; QA Pass on
7e628b3 with a respawn test (test_bp5_qa.gd:216). New tests fail without the fix (read): the reload put-back torch
(test_bp5.gd:200, the old reload put-back never restored torch_on) and the rebind after build (test_bp5.gd:262, only
refresh()'s new loop at loadout_gear.gd:203-204 can turn the built "2" into F8; InputMap is restored in after_each).
Check 3 read myself: trigger_command is bool reads plus copy_from (scalars) into the preallocated _throwing; no alloc.
Blocking (process, pipeline/README.md:44-46 and the critic's "a report is missing" rule):
- pipeline/out/performance.md:1 reviews c8a6146 and says "no --perf bot match". The per-tick sim path changed after
  it (7e628b3: trigger_command now runs every tick for every character in play, grenades.gd:187; Torch.step's relight).
  Runtime code gets a measured --perf run, this head against origin/main. No report covers the head.
Advisory (fix in the same push, not a reason on its own):
- docs/records/BP5.md:3 still says "performance pending" (and the attempt-2 row "pending"); bring it to the reports.
- BP5.md:27-28 "The pull that throws it, or is held as a slot, the holster or a reload puts it back, is now let go"
  doesn't parse; e.g. "The pull that throws it, or a trigger held while a slot, the holster or a reload puts it back,
  is now let go".
Must-fix for the next attempt: run the performance agent on b46abbf (or the head after the record fix) with the --perf
bot match against origin/main and commit its report; no code change is asked. Then the verdict is Accept.
Owner should test in the game:
- AEG on full auto, roll the wheel to a smoke, pull and hold: thrown, rifle back up, silent until you let go and pull.
- Same, but let go and pull again during the throw: it fires as soon as the rifle is up.
- Press 4 with the trigger held: full auto fires after the throw, as before. Does the difference feel right?
- Night, torch on, wheel to a bomb, then 1 (and R): torch back on, no click. Then 3 (holster): torch stays off.
- Rebind Primary to a long key name (Mouse 4, Right Shift): the Loadout card's chip fits and reads.

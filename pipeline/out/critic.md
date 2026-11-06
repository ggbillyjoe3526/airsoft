Task: none · BP5 part 1, the second bug and performance pass (fixes)
Attempt: 3 of 4
Head: 86b043d (= git rev-parse HEAD; no change to game/, tests/, data/, assets/ or project.godot since b46abbf, where
test_bp5 10/10, test_bp5_qa 10/10, test_grenades 28/28 and test_torch 26/26 ran green)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Attempt-2 blocker cleared: pipeline/out/performance.md is a measured team_bench run, main 90b0ff4 and head b46abbf
interleaved (two runs a side, Depot and The Street at 6v6 and 8v8). Every mean tick is within 5 % of main and inside
main's own spread, and nothing regressed over 10 %. trigger_command was read and measured. b46abbf has the same code as
the head, so the report covers it. BP5.md:28 now reads, and the attempts rows are filled.
Advisory (not blocking; fix in the records commit): docs/records/BP5.md:3 still says "critic pending · qa Pass ·
performance pending"; it should read critic Accept, qa Pass, performance Pass before the PR is marked ready.
Owner should test in the game:
- AEG on full auto, roll the wheel to a smoke, pull and hold: thrown, rifle back up, silent until you let go and pull.
- Same, but let go and pull again during the throw: it fires as soon as the rifle is up.
- Press 4 with the trigger held: full auto fires after the throw, as before. Does the difference feel right?
- Night, torch on, wheel to a bomb, then 1 (and R): torch back on, no click. Then 3 (holster): torch stays off.
- Rebind Primary to a long key name (Mouse 4, Right Shift): the Loadout card's chip fits and reads.

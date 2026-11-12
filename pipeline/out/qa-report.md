Task: SH1 · QA commit (see git log, subject "SH1 QA") · Verdict: Pass

Blocking: none. Advisory: none found.

Tests added (tests/unit/test_sh1_qa.gd, 13, all pass; none could be run against a stubbed-out feature because QA edits no production code, so "fails without" is by construction: each asserts shot_bbs/pattern behaviour that is 1/0 on any replica without SH1):
- shot_bbs cell "0","10","x","-1","2.5","" keeps 3 and warns; pattern cell "-1","9","wide" keeps 1.2 and warns (a read of the optional columns; without them every cell would be accepted or ignored silently).
- stats.md with both new columns stripped reads with zero problems, aeg reads 1 and 0, shotgun row still reads.
- Partial pull: 1 BB left sends 1 BB, one SHOT, mag 0; a shell of 4 gives 3 then 1, never below 0.
- Empty shell: one DRY_FIRE, no SHOT, no BBs.
- Laser flag: one SHOT event, value2 = SHOT_LASER, mag 27; three laser BBs on one body give one CHARACTER_HIT.
- BB pool of 0, 1, 2 slots: no error, one SHOT, shell still loses 3; pool of 5 after two pulls keeps the newest three and the oldest-evicted order.
- Bots: low_on_bbs counts BBs (2 of 30 is low), reload_when_due reloads an empty shell, press_kept is true during the pump and false once home.
- Performance sheet: Figures carry shot_bbs 3 / pattern 1.2 for the shotgun, 1 / 0 for the AEG; Pattern row present only for the shotgun; rate text carries the BB count, the AEG's has no "×".

Not covered beyond the worker's tests (already passing in test_pump_shotgun.gd): spacing/first-straight-up, one-hit, ten pulls per shell, bottomless, springs/optics, sounds exist, model stand-in.

Not run (per instruction; the worker's full run is on the machine): tools/unit_tests.sh, tools/check.sh, tools/smoke_test.sh, python3 tools/wiki.py check. Only test_sh1_qa.gd was run (13/13, 0.42 s).

Could not test (needs display/audio/owner): the HUD magazine count dropping by 3 on screen, the pump cue and shell sounds actually playing (SimAudio._cycle needs the scene), saves/loadouts naming 000027 with Dev content off (not exercised; only is_offered false was seen in the worker's test), the "1.7 × 3" string's exact rendering through the translation server, a bot match with Clearer kits, wiki output of "shots/s, N BBs each".

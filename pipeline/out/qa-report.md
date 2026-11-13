Task: HA1 · QA commit 6b6101f · Verdict: Pass

Blocking: none. Advisory: none.

Delta reviewed (attempt 4, re-run 7): arms.glb rebuild, the new front-end test in test_ha1_rifle_hold.gd.
Ran test_ha1_rifle_hold, test_hands_on_replica, test_sh2_qa, test_ha1_qa3: 45 tests, all pass (512 asserts). Not run: the full suite (build thread's).

Added tests/unit/test_ha1_qa3.gd:
- test_neighbouring_left_fingers_stand_apart_on_the_sniper_and_the_smg: least distance between neighbouring finger bone segments over 12 mm (build: 16 to 19). Could NOT confirm it fails on the old glb: swapping the file did not take (import cache, headless), so its failing-without is unverified.
- test_the_front_end_search_finds_each_rifles_handguard_and_a_finger_past_it_would_fail: the replica has handguard-side surface with depth on all three rifles (the existing front-end test's search finds something). Weak guard; the existing test already asserts front < INF.
- test_the_arms_file_stays_under_the_size_budget: arms.glb 6.5 MB, under 8 MB.

Hold regression coverage: eye test (0 points, 4 replicas), bots' holds, reload clip ends and the shotgun pump are covered by the existing files, all green. The AEG's fingers are held to 15 mm past the front end, as decided.
Not tested: the triangle budget in either look (not re-measured), visual look (needs a display; owner).

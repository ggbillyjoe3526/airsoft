Task: WR2 · Woodland's doors, two flags and 3:00 rounds (no TASKS.md block; judged against the brief and docs/records/WR2.md)
Attempt: 2 of 4
Head: 847b86d (= git rev-parse HEAD; QA Pass on 847b86d, performance Pass on d646e35: the delta's only code is MapCatalog._read_round, parse-time once per catalog load, no hot path)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Attempt 1's must-fix and notes, verified in d646e35..847b86d:
8. Fixed. tools/wiki.py +366-375 round_of() and +382-383 add a generated Round column to the maps table (Depot 2:30, Woodland 3:00, Range –, read from maps.md and round_config.gd); gen_rules +524 reads "2:30, or the map's own ([Maps](Maps))". Typed "3:00 / half a minute" gone (Maps.md, Modes.md +51). `tools/wiki.py check` OK, 25 pages.
- 30 s step: map_catalog.gd +144-146 rejects off-step cells (fposmod against ROUND_TIME_STEP); maps.md +18-20 says so. test_woodland_layout +431/+437 and test_wr2_qa.gd:158-168 ("185", "100" warn once, map still listed) fail without the step check.
- KNOWN_ISSUES.md:14 records the shared physics space of a test's own level and its match's (document).
- Record: WR2.md attempt 1 row filled, attempt 2 row and section added.
- Door wording: Maps.md +84 "the other team's end ... your own end".
Notes (no fail):
- docs/wiki/Maps.md:85 rewrapped to 124 columns (PROCESS.md:278 wraps at 120); fix when the changelog note goes in.
- changelog.d note for WR2 still to come (due after review, pipeline/README.md).
Owner should test in the game:
- Woodland Skirmish: Match card chips and HUD clock show 3:00; Depot still 2:30; Custom on Woodland plays its own saved time.
- Each hut's enemy-facing door is shut at round start, its own-side door open; opening one is heard but not too far.
- Shut doors sit flush on the sloped Box and Cabin; open leaves fold flat and do not snag.
- Attack / Defend: A at the Fort and B at the Sawmill both read on the HUD; attackers can reach B in a 3:00 round.
- Bots open and pass the Hut row and Box doors without bunching in the doorway.

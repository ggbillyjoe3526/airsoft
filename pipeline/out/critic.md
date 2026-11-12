Task: SM5B · Subway's signs and posters in every room
Attempt: 2 of 4
Head: bc5bcf4 (= HEAD). Full tools/check.sh NOT run on this head (CI runs it on the PR); test_station_fixtures 9/9,
   test_sm5_qa 13/13, test_sm5b_qa 10/10, gdlint clean. QA and performance reviewed 640241d (both Pass);
   1567446..bc5bcf4 changes only two box heights, bounds, a test and the record. This verdict lapses if CI fails.
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Failed checks, with evidence: none.
Checked (what changed and what it could break):
1. [measured] Read from the glbs: departures_n Sign quad x ±0.77, y -0.715..-0.330 = 1.54 x 0.385 = 4.00:1, the same
   as its 512 x 128 cell. way_sign Sign 1.256 x 0.275 = 4.567:1 against 512 x 112 = 4.571:1 (was 4.906, 7.3 % off).
   Prop bounds -0.745 and -0.599 match fixtures.py +22, +51-52. Tris unchanged (84 of 90), so budgets hold.
   No reference photos or renders are named for these flat sign boxes; I judged them from geometry, as in attempt 1.
2/3/5. No contract, runtime script or hot path touched. The only change in code is a test.
4. test_station_fixtures.gd +99: the per-triangle ratio of world edge to sheet px. On the old departures it gives
   (1.54/512)/(0.34/128) = 1.13, a 13 % stretch, so it fails at the 2 % limit; it caught way_sign on its own.
6. Headroom: the lowest hung sign's underside is now 2.40 m (way_sign in 3.0 m passages, 3.0 - 0.599), and the boards'
   is about 2.46 m over the platforms (ceiling 4.1, floor 0.9 by lowc, 3.2 - 0.745). Both are well over a standing or
   jumping head, and they are look-only with no collision. The builder's clear() kept every spot (subway.json unchanged;
   only the 4 earlier edge_sign spots are still left out). Lamp clearance is retested against the new mesh boxes
   (test_sm5b_qa +215, which passes).
7. Docstrings are updated (station_extras.py +100, +295). Advisory: the test's `for s in ...`, `for t`, `for e` loop
   variables are untyped.
8. way_sign is an SM5 model, fixed because the new test covers every printed model. The record's Decisions says so.
   No player-facing change needs a wiki edit beyond the existing note.
Must-fix for the next attempt: none.
Owner should test in the game:
- From the platform edge, read both departure boards' rows and the bottom line. Is the text undistorted?
- Walk under a "Way out" sign in a 3 m passage. Does it hang low or crowd the view?
- Walk up to a line map: are the stop names readable at about 2 m?
- Ride both escalators: do the level posters look right on the sloped walls, and do any clip the decks?
- Are the no-smoking and handrail pictograms clear at a glance?
- Are there too many or too few notices per room (hall, concourse, lift landing, plant room)?

Task: WR1 · Woodland rebuilt as the open wood of concept 3
Attempt: 2 of 4
Head: c7e8c44 + uncommitted docs, comment and tools/woodland fixes (tools/check.sh still running: gdlint, notes, wiki passed; unit tests pending). Verdict holds only if it finishes green on this tree.
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept (QA Pass, performance Pass, both WR1 at c7e8c44; attempt 2 adds no GDScript beyond comments)
Failed checks, with evidence: none.
Attempt-1 must-fix, verified:
7. build_map.py:490-499 settle() uses keep/give locals; the loop variables are untouched; the tree/thicket branch is merged into
   :477. Rebuilt in scratch: data/maps/woodland.json byte-identical (947 blocks, 99 foliage, 244 areas), check.py TOTAL 0.
   check.py:1 docstring says it prints; analyze.py writes no files now (.npy and analysis_times.json gone, :177-180).
8. tests/README.md:10 names OldWoodland and the runner's `night`; game/nav/README.md:15-17 describes _sloped_diagonal
   (max_step x sqrt 2, a kerb's corner still a drop); docs/records/WR1.md:35 three fires, eight lanterns. QA's stale
   comments fixed (match_guard:30, match_runner:174, nav_config:31, play_session:24 and loading_screen:6 now 6 s,
   game/ai and game/map READMEs, KNOWN_ISSUES WL3/WL10 rows marked the old wood); record :79-80 says the guards play
   Woodland by night (test_woodland_guards.gd passes true) and why.
Passed, notes: 1-6 unchanged from attempt 1 (no gameplay code in this attempt's diff); the off-leg guard and the
   critic's alternative are both in the record (:51-52).
Advisory (not scored): settle() still keeps comparing block i after it is dropped (no `break` once i in drop): harmless
   for today's output, but a block given way below 0.05 m can still trim a later one. The changelog note is owed
   (written after this verdict) and the record's Review line reads pending.
Owner should test in the game (at most 6, one line each):
- Walk each lane at 5v5 by day and by night: does the wood read, and do the 100-160 m pinholes feel rare, not a sniper lane?
- Crouch in a fern bed and a bush near a bot path: are you hidden as the wiki says?
- Watch bots climb the stream banks and slides: no freezing on slopes, no walking off the North bridge's deck.
- The Ridge overlook onto the Fort (86 m): too strong for defenders or attackers?
- Load time into Woodland (about 6 s nav build plus a ~2.5 s views freeze measured headless) on your PC.
- Frame time at 6v6 by night on High, and a cross-map route's cost on a low-end PC (5.5 ms mean headless).

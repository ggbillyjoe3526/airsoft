Task: MB2 · Woodland's Long road, cleared
Attempt: 2 of 4
Head: 85e3f5295b6438806e8ba1a352813a6de6a0db70 (checks passed on it; diff read as `git diff 65ee956 HEAD`)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept

Evidence for the passes (one line each):
1. Crit. 1: tools/woodland/check.py:+61 and world.py:+157 enforce the rule, and check.py gives TOTAL 0 (re-run).
   test_mb2_qa.gd +64 and +75 test the strip; +37 holds the six gate screens. Crit. 2: test_mb1_layouts.gd +186..218.
   The critic's own raster check against the built JSON: 250 eye points on the strip west of the bend (out to ±2.4 m,
   which covers QA's 2.5 m edge advisory) against 265 east of it saw 0 pairs, and 910 strip points saw 0 of flag B's
   ring and post chests. The record's claim is honest. Crit. 3: the records recounted. Attack / Defend built 170/247 =
   68.8 %, main 147/236 = 62.3 %. Elimination west end 114/240 decided = 47.5 % (the record writes 241; one round in
   rc16d was a draw). Plant The Bomb 50/125 = 40 % against 48/117 = 41 %. rc16m gives the same rounds as rc16.
   Crit. 4: no game/ file and no new asset. Crit. 5: the docs are covered, except as noted under 8.
   The out-of-band 69 % is handled honestly and the handling is defensible. The owner ordered the clear road and was
   told the figure, main still has the road he rejected, and ten measured layouts failed to win the points back.
   KNOWN_ISSUES, DECISIONS, the record and the changelog note all state the figure. The next attempt at it is named
   (flag B's posts or pole), but it has no task id yet: give it one.
2. ARCHITECTURE has no Contracts entry for the Woodland generator or map_heat. map_heat.gd +176 adds a mode name and
   keeps the old ones.
3. No game code changed. map_heat.gd allocates per round in a dev tool, which is fine. Performance pooled +1.5 % over
   four seeds.
4. On main, test_nothing_stands_on_the_long_road fails on the three windthrows (`tag="roadblock"`, the old
   layout.py:329-331). The sight test now walks the new strip.
5. The tests are typed throughout, and every change is generator data or tests.
6. The road bends round two solid spruce stands into a 7 m corridor with no bough over the gravel (the bend render
   shows a clear strip), it uses no new model, and the tone is right. The 7-point Attack / Defend lean is a known
   issue under crit. 3.
7. Pass, with an advisory. tests/unit/test_mb2_qa.gd:10 and test_mb1_layouts.gd:84 hand-copy layout.py's ROAD, a
   third and fourth copy that will drift silently when the road moves again. layout.py:440 is an unwrapped comment
   line of about 150 chars.

Failed checks, with evidence:
8. [judgment] changelog.d/map-layouts-reworked.md:8 (MB1's note, still unreleased) still reads "three fallen trees
   across the Long road and a tall log stack across it at the Culvert". The next patch notes will announce the road
   blocked and cleared in the same release. The figures in the docs also disagree with each other:
   - The record's flag B line, "118 to 73 a hundred rounds; 123 to 75", doesn't match its own table's 269 to 167 over
     247 rounds (109 to 68 a hundred) or 285 to 161 over 236 rounds (121 to 68).
   - The sawn boards' duel is "54 to 32 over 250 rounds" in layout.py:+375, 21.6 to 12.8 a hundred, but "10 to 18 a
     hundred rounds" in docs/records/MB2.md and DECISIONS.

Must-fix before merge (non-blocking, but they are the player-facing notes):
- Change MB1's Woodland clause in changelog.d/map-layouts-reworked.md to what ships, or drop it.
- In each place, say what counts as "round flag B" (radius or area) and what the denominator is, then reconcile the
  118/73 and 54/32 figures with the 10/18 one, or recount them.
- Optional: make the two tests read layout.ROAD's points from one source, or at least name layout.py:288 as the
  source, which test_mb1_layouts already does.

Owner should test in the game:
- Walk the Long road from the Truck bend through the S to the Culvert. Does it read as a forest road and not a trench
  cut through spruce, and is the gravel visibly clear of boughs?
- Stand at the S's west mouth and at its east mouth and check that neither looks through the bend.
- Play Attack / Defend on Woodland as a defender at flag B: does B fall too easily (69 % to the attackers against
  bots)?
- Play Elimination on the south lane: are the fights close (median about 15 m), and is the fallen tree at the S's
  east mouth useful cover?
- Watch bots take the S in all three modes for snagging on the bends or on the spruce edges.
- Look at the shed's east end: do the moved boards read as natural, and does flag B still feel defensible?

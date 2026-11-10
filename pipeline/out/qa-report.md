Task: WS1 · QA commit (see git log, Agent: qa) · Verdict: Pass

Blocking: none. Advisory: none reproducible. Checked on head 8761d05 (level bed, flat water).

Tests added (tests/unit/test_ws1_qa.gd, 11; each fails without its feature, checked by stubbing the production line, then restoring it):
- test_ws1_qa.gd:16 · water reaches exactly its half width, round ends, dry box corners · `<=` made `<`: fails (2 asserts).
- :24 · repeated point (zero length segment), nearest of two streams wins, no NaN · exercised, passes (guards a divide by zero).
- :33 · depth never negative or NaN far off or far below · guard.
- :40 · Depot, Kingsmere, Range have no water and their floors and routes are the same at any wade price · regression guard (unaffected).
- :56 · a splash in a bush is WATER and carries a splash's distance, not leaves · dropping `and not wet` in footsteps.gd: fails.
- :73 · grazing BBs: one lands in the stream as WATER within it, one lands short as bank · BBStep given a constant depth: fails (3 asserts).
- :107 · BB landing on a deck over the stream is the deck's surface, not WATER · same stub: fails.
- :131 · footsteps with a null water object still work · guard.
- :145 · band without variants (bad paths, empty list, no main model) still stands / yields the cones · guard.
- :171 · band is seeded, same every build, uses more than one section · guard.
- :190 · treeline_rise 1 and shift 0 give a finite, non-flat band · guard.

Runs: test_ws1_qa 11/11 (160 asserts, 6.3 s); test_ws1_stream 11/11 (168 asserts, 11.7 s), both on 8761d05. tools/check.sh from my run was cut off by the background time limit after gdlint, changelog, wiki and unit parts 1 to 3 passed (on c90e9a2, before 8761d05); the worker reports the full suite, smoke test and notices passed on 8761d05. Raw: pipeline/out/qa/check.txt (partial).

Hunted, found fine: stream ends and exact half width; Ford ankle depth splashes without slowing; spawns, flag, bridge decks dry (existing test, updated by the worker); OT flag dry; spruce scatter stays in its block (existing test_wg4 woodland containment test).

Not tested: window look of the water shader, reduced motion on a real display, how wading and splash sound feel, bots' wading behaviour in a long match (the match guards cover stuck bots). Owner: look at the stream in a window, at night, and with reduced motion on.

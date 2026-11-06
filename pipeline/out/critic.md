Task: none · BP5 part 2, performance
Attempt: 2 of 4
Head: 07e7971 (= git rev-parse HEAD; game/sim and game/ai byte-identical to a7c1586, game/play and game/config = main)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence:
1. The brief is "optimise without losing quality". hitbox.gd:155-163: the bounding sphere is a strict superset
   (|M - C| <= half + up + r for any touching pair), so the answers are unchanged. bot_combat.gd:370-375: widest >=
   room for every reach in [0, dist], since flight is monotonic (QA test) and INF maps to 0, which skips the quick
   test. The visible-cost stride is gone (no diff in game/play or game/config). Record and changelog claim only what
   was measured: tick within main's spread. The counted 9,718 of 20,000 skipped teammate checks justify the bot test.
2. No contract in ARCHITECTURE › Contracts touched.
3. Both hunks use only float and Vector3 locals; no Array, Dictionary, String, lambda or new().
4. test_bp5_perf.gd's 4,000 rays: I counted 2,122 of them that the sphere rejects, so any unsound early-out fails
   the test. QA's margin and segment monotonicity tests and the INF case cover the guard. I ran both files: 1/1
   (2 asserts) and 3/3 (83 asserts).
5. Plain static sim code, typed; no new literals (HitConfig and BotCombat cfg values only).
6. No gameplay or feel change by construction.
7. +10 and +8 lines, comments that read. Non-blocking nit: the reviews were run at c14d732 (perf) and 7799f56 (QA)
   and still list the dropped stride. They stand because the tick code is byte-identical, but the worker's addendum
   inside pipeline/out/performance.md is the worker writing in a review agent's file. Next time, re-run the agent.
8. Changelog note rewritten (changelog.d/bp5-performance.md:2), BP5.md › Part 2 and the attempts row updated.
   Nothing a player notices, so no wiki page. Nit: the attempts row for part 2: 1 shows checks "pending"; they were
   green.
Owner should test in the game (at most 6, one line each):
- A full 8v8 Woodland round: bots still hold fire when a teammate crosses their line, and BB hits register as before.

Task: SN3 · Balancing the Sniper Rifle, its springs and the Variable Scope
Attempt: 2 of 4
Head: 704372c (= origin/main) plus the staged tree; the brief gives no tools/check.sh result for it (QA ran single test files), so this Accept holds only once tools/check.sh is green on the pushed head
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Attempt 1's points, answered:
- Fields: Attack / Defend is now measured on all three at 6v6 (docs/records/SN3.md:39-40), all in band with snipers; Depot's 67 % without them is a new KNOWN_ISSUES row. Depot's 42 and 59 are worded against the band and the ±6-point noise (:38-39). Woodland 7v7/8v8 is the known WOODLAND78 placeholder (:38), waived by the brief; fill it or note the rows as lost before the push.
- Tags: every new line and file reads SN3 (test_sn3_balance.gd, bot_config.gd:27, bot_hearing.gd:87, layout.py:468) but one: tests/unit/test_sn3_qa.gd:2 "(SN3 / BP3)".
- Null guard: bot_combat.gd:199 now guards armament as fights_aimed does.
- tests/README.md:9 names sniper_bench.gd and its command line.
- QA (pipeline/out/qa.md) and performance (pipeline/out/performance.md) both report on SN3 and Pass.
Verified, no finding:
- Check 4: test_a_near_miss_reveals_the_shooter_for_a_while fails without reveal (sight_reach stays view_distance, visible_part 0 at 65 m).
- Hot paths: sight_reach, scoped, bolt_waits and the _hit_call loop are scalar work with no allocation; _hit_call returns early on a null or out shooter, so reveal never gets a null.
- New tuning is BotConfig exports; no contract changed; the changelog's "(dev content)" heading matches sniper-rifle.md and variable-scope.md.
Advisory (not failed):
- After the bins, The Street with the shipped kits was re-run at 6v6 only (SN3.md:55); the KNOWN_ISSUES row still quotes TS1's pre-bins 16-seed figures for the other sizes. Worth a 16-seed run at 5v5, 7v7 and 8v8 when the guards next run.
- Records push: fix test_sn3_qa.gd:2's tag, add attempt 2's row (attempt 1: 5/8 Retry, with its reason) and fill the Review line.
Owner should test in the game (at most 6, one line each):
- From 60 to 65 m with the Sniper Rifle, miss a bot on purpose: does it turn and answer fairly, not instantly?
- After that reveal, AEG bots have no range gate and may pour BBs at you that fall short for 4 s: fun, or silly?
- Hard sniper bots at range: the first shot comes late but lands; beatable by closing in or flanking?
- The Street, the Path bins at mid-straight: a stop you'd use going north, and does it read as cover?
- The Street with Dev content off: does the north end still feel stronger, or did the bins even it up?
- Each field at 6v6 with Dev content on: any end that feels stacked?

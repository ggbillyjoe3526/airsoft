Task: MB3 · Woodland's flag takes 9 s to raise
Attempt: 1 of 4
Head: a63ac0e592a078e46ec0d41c8403ac0bc13d816a plus the uncommitted tree (the brief's partial checks ran on this tree)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept (all blocking checks pass, one non-blocking fails)

Evidence for the checks that pass:
1. Criterion 1: match_options.gd +115/+123-128 sets the raise for Skirmish and Custom, and the 3 s hold is left alone.
   Criterion 2: map_catalog.gd +28-31/+139 (RAISE_RANGE, _read_number keeps the default and warns). Criterion 3: I
   recounted r9f* at 139 of 231 = 60.2 % ±3.2, seeds 1 to 32, inside 40 to 65. Criterion 4: Flag.step (flag.gd:100,
   reached only from _step_flag_clock, round.gd:90) is the only reader. The overtime flag uses tuning.overtime. e9 and
   ef seeds 1 and 2 give 15 identical rounds (I compared them). Criterion 5: wiki.py +395-412.
2. No contract changed. The per-map raise follows the existing per-map round length (WR2, match_tuning), so it is in
   the right place for Contract 6.
3. Nothing changed on a per-frame path in game/. match_tuning runs once per match load. watch_flags
   (match_runner.gd +570) loops over the poles with no allocation. Judging performance from the code without a bench
   is acceptable for this diff.
4. test_mb3_raise's flag test (Woodland's flag not up at 7 s, up at 9 s) and the WOODLAND_RAISE assert fail without
   the feature. watch_flags fails to compile without it.
5. Types and constants are in place. CustomRules.applied_to shares base.flag (custom_rules.gd:39), and the
   `t.flag == base.flag` copy at +125 is what keeps the loaded tuning unwritten. QA's test pins it.
6. It is the owner's own pick. Fun before realism holds. No in-game text says "7 s" (en.po's flag lines have no
   number), so the game never contradicts itself. Leaving the in-game notice as a can-wait known issue is acceptable.
7. Small focused edits. One nit: match_runner.gd:261 is a 153-character comment line left unwrapped by the reflow.

Failed checks:
8. [judgment] The docs state the same measure two ways, which is what failed MB2's critic.
   - KNOWN_ISSUES' Woodland Attack / Defend row still reads "69 % ±3 at 6v6 (247 rounds, 32 seeds)" for MB2's road,
     then "68 % ±3 at 7 s" for the layout that shipped. It never says the hazel moved in between: 69 % is rc16 seeds
     1 to 32 at 170 of 247, 68 % is r7f at 166 of 245.
   - DECISIONS has the same split. MB2's entry says 69 % and 47 %, and MB3's new entry says "MB2's clear road …
     68 % ±3 at 7 s".
   - KNOWN_ISSUES' Woodland Hard row still opens "runs out the clock in 15.6 % ±3.2" and still says "with MB2's
     cleared road, 47 % ±3". The new Elimination row says 41 % ±3 on the shipped layout. So the file gives 47 and 41
     for the same layout, and the 15.6 % contradicts "0 of 118" in the same row.
   - DECISIONS claims more than was measured: "Both poles fell alike, so it was no fault of flag B's cover". pole.py
     gives A 72 % ±3 against B 65 % ±3, a heuristic the record itself says leans to the winners. The same row of
     KNOWN_ISSUES still says "Flag B is still the softer site".
   - The new Elimination row states the hazel as the cause outright, where the record says "6 points ±4.5 is not
     proof".

Must-fix before the push (non-blocking, but cheap):
- Rewrite the KNOWN_ISSUES Woodland Hard row's opening (15.6 % is history) and its "47 % ±3" (before the hazel
  moved; 41 % now).
- In the Attack / Defend row and in DECISIONS (MB2 and MB3 entries), label 69 % and 47 % as "before the hazel
  moved", or replace them with the shipped figures.
- Reduce "no fault of flag B's cover" to "A 72 %, B 65 %, by where the attackers stood", and mark the hazel cause as
  likely.
- Wrap match_runner.gd:261.
- Run risk: low. Hard showed 0 of 114 timeouts at 9 s and Normal 0 of 231. test_woodland_attack_defend_at_easy
  (STALLED_ROUNDS_MAX 0.25) is the one Woodland guard not yet run at 9 s. A larger top_flag only raises Depot's
  flags-raised counts.

Shipping before MB4 is defensible: the 41 % Elimination lean comes from MB2, the raise doesn't touch Elimination
(checked on the same seeds), and it is filed as fix now for MB4. Seeds 1 to 48 give 41.5 % ±2.6, so the lean holds up
with more seeds.

Owner should test in the game:
- Attack on Woodland: whether 9 s on the rope plus the 3 s hold feels tense or just exposed and slow.
- Defend Woodland from the far pole: whether you now get across in time to pull the flag down.
- Depot right after Woodland: the raise is back to 7 s and the bar's speed reads correctly.
- Custom on Woodland: the raise is 9 s and feels the same as in Skirmish.
- Whether the slower bar on Woodland confuses you with no notice on the Match card.
- Woodland Elimination: whether the east side's push over the Ridge's brow feels too strong (MB4's issue).

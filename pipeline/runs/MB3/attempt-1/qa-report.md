Task: MB3 · QA commit none (uncommitted, per instruction) · Verdict: Pass

Blocking: none.
Advisory: none new. (A Woodland Attack / Defend match can only play 7 s if a caller skips MatchOptions.match_tuning; there is none: see 1.)

Criteria
1. Woodland 9 s in Skirmish and Custom, others 7 s. Every match start goes through PlaySession._load_map (game/play/play_session.gd:380-384) into MatchOptions.match_tuning; the Match page (match_page.gd:571) uses the same call; restarts, "play again" and the smoke path reuse the PlaySession; practice and the Range take practice_tuning (no flag). Nothing outside Flag.step and the config reads raise_time: the HUD, bots and the overtime rule read only rope_step, hold_time or max_overtime. match_tuning copies t.flag before writing it; test_mb3_qa pins that the base flag object and value survive Woodland then Depot, and Custom on Woodland, and that Depot after Woodland plays the game's 7.
2. Data-driven, bad cell keeps the game's. Pinned: "9.0", " 9 ", the edges 3 and 20, "0" (a problem, keeps the game's), a row shorter than the header, the Range's blank cell, a table without the column (test_mb3_raise). I did not test a duplicated header (DataTable behaviour, not changed by MB3).
3. Attackers 40 to 65 % at 6v6: not re-run (the balance run is a measuring job; the record's figure is 60.2 % ±3.2 over 231 rounds, 32 seeds). Not verified by me.
4. Nothing else moves. Elimination and Plant The Bomb don't read the flag raise. The tally change (watch_flags, top_pole) only widens top_flag from flag A to every pole: flag_raised() (match_guard.gd:110) now also counts flag B, so a guard that passed before still does. tests/guards/test_callout_guards.gd:181 snapshots top_flag into a determinism list, so it compares run to run and still holds. No other test or tool reads top_flag as flag A.
5. Wiki Maps table: gen_maps output has a "Flag raise" column: Depot 7 s, Woodland 9 s, Range a dash, Subway (dev) absent. `python3 tools/wiki.py check` passes.

Tests added: tests/unit/test_mb3_qa.gd (6 tests, 20 asserts), gdlint clean.
- test_a_raise_cell_with_a_decimal_or_spaces_reads_and_the_edges_are_in · parser edges · fails without the feature: Entry has no raise_time, so each assert errors.
- test_a_raise_of_zero_keeps_the_games_with_a_problem · as above.
- test_a_row_shorter_than_the_header_keeps_the_games_raise · short row.
- test_the_range_has_no_raise_and_plays_the_games_flag · Range keeps 7 s.
- test_woodland_then_depot_leaves_the_shared_flag_tuning_and_each_match_its_own · fails if match_tuning writes base.flag (stub: drop the duplicate and Depot reads 9 / base changes).
- test_a_custom_match_on_woodland_does_not_write_the_loaded_flag_tuning · same through the Custom path.
I did not run the stubbed variants (no production edits allowed); the first two fail by construction on the old code, the last three assert the old value (7) first.

Suite (single files, one godot at a time): test_mb3_qa 6/6, test_mb3_raise 6/6, test_flag 10/10, test_team_sizes 18/18 (75 s), test_match_runner 10/10 (38 s), test_wr2_qa 10/10 (47 s), test_woodland_layout 17/17 (48 s). No failures. Not run: tools/check.sh, the smoke test, the full unit parts, the balance run (told to leave the cores to the measuring jobs).

Could not test: the 9 s bar and "feel" in a real play session (needs a display); the 40 to 65 % band (needs the balance run); the smoke test path.

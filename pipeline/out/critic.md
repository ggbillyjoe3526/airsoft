Task: TS1 · 6v6 on every field, 5v5 to 8v8 under Custom
Attempt: 1 of 4
Head: b7c2eb6 (checks passed on it locally; CI's last red guard fixed in this commit)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept
Evidence for the passes (short):
1. data/maps.md +26-28 (5/6/8 on all three, the row offers Min to Max so 7v7 too); custom_rules.gd +13 TEAM_SIZES to 8;
   8 spawns and 8 dead-zone spots from tools/*/layout.py and build_map.py, only `spawns`/`deadZones` changed in the
   JSON (checked); round.gd place_teams centres a 6 on slots 1-6; guards at 8v8 and frame/balance runs in the record.
2. No contract touched. 3. hud.gd +619 _fit_board: Vector2 and float only, scale written only on change.
4. test_team_sizes.gd +254 (board fits 8v8 at HUD 150 %) fails without _fit_board (QA measured 1083 of 1080 px).
5/6. Rules untouched in nodes; no props added (the van was tried and dropped); Chrono hall and the house untouched.
Failed checks, with evidence:
8. [judgment] Docs not fully current or in house style:
   - tests/README.md:8 still says the guards play "Woodland at 5v5 at night" (now 6v6).
   - Added prose over the 120-column wrap (PROCESS › Writing docs): docs/DECISIONS.md:461, tools/balance.sh:3 (152),
     game/play/play_session.gd:6, tests/guards/test_woodland_guards.gd:4, tests/support/match_guard.gd:29.
   - The Follow me guard's dazzle exemption (match_runner.gd +541) binds every later guard run like DP4's ruling
     beside it in DECISIONS (~line 455) but is recorded only in docs/records/TS1.md.
Advisory (non-blocking): hud.gd +621 floors the board with CARDS_FIT_FLOOR, a name for the cards (a BOARD_FIT_FLOOR or a
note reads better); test_team_sizes.gd +263 leaves the window at 1920x1080 if the build fails early; no test asserts
The Street's ends hold eight (Depot and Woodland do; QA checked by hand). QA and performance reviewed the pre-rebase
head 4240208: _fit_board and the guard change came after, read here and fine.
Must-fix for the next attempt: none (Accept); fold the check 8 items into this PR's last push if cheap.
Owner should test in the game:
- Woodland 8v8 on Low with --perf in a busy fight: frame time and hitches (CPU p99 14 ms headless).
- Tab at 8v8 with HUD size 150 %: all sixteen rows on screen and still readable when shrunk.
- 5v5 vs 8v8 on each field: 5v5 slower and careful, 8v8 busier, rounds about as long; does any size feel unfair?
- The Street Elimination from each end: does the north (embankment) end feel stronger (bots 55-64 %)?
- Depot 8v8: squads leave the staging chicanes and tunnels without queuing.
- 8v8 full-auto fights: do BBs ever vanish mid-flight (pool of 256)?

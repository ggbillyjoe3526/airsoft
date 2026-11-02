Task: TS1 · QA commit none (no tests added; this pass was read-only apart from this report) · Verdict: Pass

Reviewed 4240208 (origin/main..HEAD, 42 files). Blocking findings: none.

Checked, all fine
- Acceptance 1 and 2: data/maps.md gives 5/6/8 on all three fields. TEAM_SIZES is 1 to 8, and the loader accepts 7 and 8.
  Each map JSON changed only its spawns and deadZones; geometry is untouched. Loaded at 8 a side, all three read clean with
  no problems or warnings, 8 spawns and 8 dead-zone spots an end, every spot walkable on the nav grid. A ray scan of
  every spawn to the field's walkable cells (2 m grid, outside 16 m of its own end) saw none, as before. Dead-zone
  sight is the same as before (worst spot 164 vs 158 cells Woodland W, 41 vs 32 Woodland E, 67 vs 67 and 74 vs 73 Street).
- Place_teams: the middle six of eight (slots 1 to 6) at 6v6. 5v5 takes slots 1 to 5 and 7v7 slots 0 to 6, half a metre
  off centre, harmless.
- Acceptance 3: PlaySession builds Street 8v8 and 7v7 and 5v5, Depot 7v7 and Woodland 7v7 with unique spawns, every bot
  named and unique, and 600 ticks run with no script errors. Street 8v8 had no test; I ran it by hand. The en.po blurbs 7 and 8
  exist, and the key is RULE_%s_BLURB_%d.
- Acceptance 4: the balance_run argument index (8th) matches balance.sh. sized_for(picked) falls back to the standard
  for sizes a map doesn't offer. The median round length is added to both report modes. team_bench is excluded from
  exports (tools/*) and gdlint is clean on every changed .gd file.
- Nothing else assumes 6 a side: HUD pips follow wins needed, not team size. Minimap and mag-line capacity, the torch
  beams and figure_of follow characters.size(). The BB pool (256) peaked at 12 in an 8v8 autopilot match. The
  bot roster has 32 names for 15 bots, and the thrown-magazine pool recycles the oldest. Saves load through _choice, so an
  old 3 or 6 stays valid. report_facts counts team sizes from the characters.

Advisory (not blocking; for KNOWN_ISSUES or a later pass)
1. game/ui/hud.gd:53 and hud_scoreboard.gd (Tab board): measured 923 px tall at 8v8 with the Hard Pro tip (763 at 6v6),
   at top 160, so it ends at 1083 of 1080: the tip box's last 3 px clip. The match summary and round result have a height
   fit (_height_fit); the Tab board has none, so any HUD size above 1.0 pushes the 8v8 board off screen (6v6 does at
   1.16 and up). Fix: scale the board with _height_fit as the summary does, or trim ROW_HEIGHT or BOARD_TOP.
2. docs/FEATURES.md:33 (Depot "5v5 or 6v6") and :36 (The Street "5v5 or 6v6") are stale; only line 65 was updated.
3. Coverage gap: no test builds The Street at 8v8 or checks its spawns and dead zone unseen (test_street.gd loads it at
   5). Suggest a test_team_sizes case across all three maps (Woodland's exists) plus an unseen-spawn test for Street.
4. KNOWN_ISSUES records the headless frame cost; Woodland 8v8 p99 is 14.1 ms CPU, so it may drop frames on Low.
   That needs a GPU playtest (owner's list).

Tests added or changed: none. Targeted runs: not needed, the suite passed on this head; I used scratch scripts outside
the repo (measure, spots, build, bbs) and left no repo files changed.
Could not test: how 5v5 to 8v8 feels (pace and fairness) and GPU frame time; both go to the owner's playtest list.

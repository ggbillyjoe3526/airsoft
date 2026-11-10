Task: SL4 · QA commit none (no new tests; test_lo3_qa and others already updated in the diff) · Verdict: Pass

Head 3e9bf5e, `git diff origin/main...HEAD` re-checked.

Blocking: none.
Advisory: targeted GUT runs print one pair of "get_base_script / resource_path on null" SCRIPT ERRORs per script. The count equals the script count, so it comes from GUT with `-gdir=`, not from the game.

Checked:
- HudStyle.navy_box is now dark_box. No `navy_box` reference is left in game/, tests/ or tools/. The callers in match_summary, xp_card and weapon_rail use dark_box. panel_box too.
- GameTheme.DEEP and PLATE exist. MinimapConfig ink and map_backdrop read GameTheme.BG; both are consts, so the config's load order is fine.
- test_lo3_qa, test_loadout_screen and test_replica_paint compare against ReplicaPaint.drawn(...), matching the new paint code.

Runs (targeted only, whole suite left to the other process):
- 13 scripts (hud*, minimap, pause, report, nav_rail, crash_screen, lo3_qa, loadout_screen, replica_paint, game_theme): 199 tests, 199 pass.
- 38 scripts (armory, chevron, graphics, sound_cues, order_wheel, team_markers, settings, flag, hud_table, menu, loadout): 608 tests, 608 pass.
- No parse errors.

Not tested: how the new palette looks on screen, which needs a display (owner's list).

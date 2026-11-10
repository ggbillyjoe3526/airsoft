Task: SL4 · Sunlit Concrete: menus, HUD and replicas
Attempt: 2 of 4
Head: 043b63a
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Retry (procedural only: QA and performance reports named 64813e3; no code change needed)
Evidence: MinimapConfig ink and map_backdrop from GameTheme.BG; dark plates from GameTheme DEEP and PLATE in pause_menu,
report_panel, nav_rail, graphics_notice, armory_track, chevron_shape, hud_sound_cues, hud_order_wheel; one report ink
(crash_screen reuses ReportPanel's); no navy or teal literal left in game/ui. test_replica_paint's new test fails on
main. FEATURES.md no longer says teal. The KNOWN_ISSUES row left to the rebase over SL3 (#279 rewrites the same row):
acceptable if the rebased head names the replicas there.
Must-fix: QA and performance re-run on the final head after the rebase; the replicas added to the KNOWN_ISSUES Art row.
With both Pass and checks green, this verdict becomes Accept 8/8.
Nits taken in f589a2b: HudStyle.navy_box renamed dark_box; menu_backdrop's "night colour"; the remaining cool greys
(hud_team_markers OUT_GREY, hud_table CHIP_TEXT, settings_graphics_page FILLED, the minimap pole and flag mast) warmed.
Owner tests: in docs/records/SL4.md and the Dev 3 checklist.

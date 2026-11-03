Task: BP3B · QA commit uncommitted (working tree on 6b24db5) · Verdict: Pass

Blocking: none.

Advisory:
- docs/PLAYTEST.md:871 still quotes the old refusal "Nobody near has a mag to spare"; the BP3B change makes it "Nobody near has a spare mag that fits" (en.po, the wiki and test_mag_hand_off_hud.gd are updated). Docs-only fix.
- game/ui/quit_prompt.gd:14-18: the new GROUP const was inserted between the doc comment for SHADE_ALPHA/WIDTH/PAD ("The shade over the screen ... px at 1080p") and its constants, so that comment now sits over GROUP. Cosmetic; move GROUP above it.
- test_bp3_menus.gd:60 (crosshair) only pins that FirstPersonView.view_zoom exists and differs from input.zoom; it does not pin the PlaySession wiring (reverting game/play/play_session.gd:1171 to _input.zoom left it green). Covered by my test below.
- test_bp3_menus.gd:46 (Settings to ARMORY) passes if anything visible has focus, a weak pin; it does fail without the main.gd change (null focus), so it stands.
- Looked for the same "_unhandled_input runs before the prompt's _unhandled_key_input" leak elsewhere: game/ui/menu_screen.gd:263 (Loadout key while in practice) and game/main.gd:560 read keys too, but QUIT GAME? cannot open while a PlaySession exists (main.gd ask_quit guard), so it is not reachable. No other menu page reads plain keys.

Checked, no bug found: pause menu close() with Settings open (closed signal restores focus modes), repeated open/close of Settings (modes restored each time, none left at FOCUS_NONE), the Loadout chip refresh, view_zoom unchanged for iron/optic sights (equals the old input.zoom outside glass scopes) and while spectating, state.dev_content set at PlaySession start for dev maps and dev kits, and the run's helped flag (never a best, same as off_record).

Tests added/changed:
- tests/unit/test_bp3b_qa.gd:30 · PlaySession with the Sniper Rifle + 2x Scope, aim_raise 0.4: the HUD's crosshair gap equals the gap for FirstPersonView.view_zoom and differs from the glass zoom (input.zoom) · fails with play_session.gd reverted to origin/main (gap 21.2 vs 16.36).
- Reviewed worker tests, each run against a copy of the tree with game/ reverted to origin/main: test_bp3_menus pause-menu focus test fails 8 asserts (focus mode FOCUS_ALL) with pause_menu.gd reverted; Settings-to-ARMORY test fails (no focus owner) with main.gd reverted; the crosshair test errors with first_person_view.gd reverted; the GROUP test cannot compile without quit_prompt.gd (parse error); test_loadout_screen 1-5 hold fails with loadout_page.gd/quit_prompt.gd reverted; test_range_challenge dev-content-never-a-best fails with simulation.gd reverted; test_mag_hand_off_hud fails with en.po reverted. test_practice_spots (The Street) is a coverage addition, no production change.

Runs (working tree): test_bp3_menus 4/4, test_loadout_screen 26/26, test_range_challenge 20/20, test_practice_spots 15/15, test_mag_hand_off_hud 24/24, test_pause_menu 16/16, test_bp3b_qa 1/1. All green. Whole suite and smoke test not run (tools/check.sh was running separately).

Could not test (needs a display / hands on keys; already in the PLAYTEST BP3B list): real Tab/Enter focus walk under Settings, the real keypress ordering behind QUIT GAME?, and how the crosshair looks while raising a scope. Add: rebind the Loadout key in the pause menu's Settings and check the chip.

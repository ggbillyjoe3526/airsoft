Task: UB1 · QA commit PENDING · Verdict: Pass

Blocking: none. Advisory: ButtonPress.play (game/ui/button_press.gd:78-97) sets b.scale = ONE at each press; any page that scales a button itself would be reset (none found in game/ui grep). Reduced motion switched on mid-dip leaves the current dip to finish normally (harmless).

Tests added (tests/unit/test_button_press.gd, 8 new, all fail if ButtonPress.install is removed because no ring is made / no hook exists):
- freed_mid_press_leaves_nothing_behind: ring freed with button.
- pressed_twice_quickly: one ring, ends at scale 1, outline hidden (a second ring or stuck tween would fail).
- taken_out_of_the_tree_mid_press: removed and re-added, ends scale 1, no stuck outline.
- hidden_mid_press: returns at full size.
- ring_never_takes_the_mouse: MOUSE_FILTER_IGNORE, FOCUS_NONE, a viewport click on the outline beside the button does not press it.
- toggle_and_check_buttons: toggle state flips correctly through viewport clicks, CheckButton plays.
- container re-sorting mid-press: ends scale 1.
- menu_card: MenuCard pressed, its child count unchanged.
- paused tree: button with PROCESS_MODE_ALWAYS still dips and finishes while paused (pause menu).
All clicks go through push_input.

Counts: test_button_press 16/16 (4.8 s); test_title_and_menus 15, test_locked_items 5, test_loadout_screen 27, all pass. Raw output: pipeline/out/qa/. Full suite/check.sh not run (running elsewhere); smoke test not run for the same reason.

Not tested (needs a display): how the dip and outline look/feel, visible NavRail level at real window sizes and modes, focus-loss behaviour (untouched by this change).

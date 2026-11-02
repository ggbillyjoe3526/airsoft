Task: none (UR1 part 1) · QA commit 6b5eda8 · Verdict: Fail

Blocking (1)
1. game/ui/settings_screen.gd (in_menus, offset_left = NavRail.WIDTH via MenuScreen.add_over_page, menu_screen.gd:~95) with
   game/ui/settings_hud_page.gd, settings_access_page.gd, settings_graphics_page.gd: the settings tab pages are built
   for 1920 px, and the rail now takes 136 of them. Their minimum widths (HUD 1800, Accessibility 1749, Graphics 1673)
   exceed the 1664 px left, so the tab container grows past the right edge: at 1080p (and, scaled, at 1280x720) the HUD
   tab ends at x=1992 and Accessibility at 1941 of 1920, cutting off the right-hand column; Graphics overruns its margin
   by 1 px. Repro: open Settings, press the HUD tab. Fix: narrow those pages' fixed columns as loadout_gear was.

Advisory (not blocking)
- game/ui/settings_screen.gd:147 and game/ui/loadout_page.gd:76: the "could not read your settings/loadouts" load
  messages are now teal ACCENT, but they are warnings; the brief keeps WARN yellow for warnings.
- game/main.gd:_build_menus -> graphics.show_safe_notice(_menus) runs on every menus build, so while the safe-start
  question is unanswered it also shows over the practice Loadout (_open_practice_loadout); before, it sat on the
  hidden title. Repro: leave the safe-start notice unanswered, play, open practice, press the Loadout key.
- game/ui/menu_screen.gd:~48 / match_page.gd:_list_maps: the backdrop follows map_picked only; if the catalogue
  or Custom team size makes the picked map unloadable at run time, _keep_a_playable_map moves picks.map_id without
  the signal and the backdrop keeps the old field until the next pick. Unreachable today (every map is public).
- A graphics notice (bottom right) is Tab-reachable from the open settings (it is above them); harmless.

Checked, no bug found: boot focus on PLAY; focus after a match, after Credits and Report close (back on their About
buttons), after the crash screen's Continue; Esc with About, Credits or Report open (only the top layer closes, then
QUIT GAME? and focus returns into the settings); notice above settings, settings under the rail (also for a notice
shown after); repeated settings/About/credits/report cycles leave the node count and orphans unchanged; settings
opened from the Loadout and Armory tabs restore the right page and focus; a second SETTINGS press does not stack
screens; practice rail (only LOADOUT + BACK TO PRACTICE, no SETTINGS/QUIT, Esc and the button send practice_requested);
backdrop with a missing file, a non-texture and a field with no picture, and with the real pictures headless (about
13 ms each); every new translation key exists; rail words fit the 136 px rail; Match, Loadout and Armory minimum
widths fit the 1784 px beside the rail; pause-menu settings still plate, About without the menu buttons.

Tests added (tests/unit/test_ur1_qa.gd, 24 tests, 125 asserts; 23 pass, 1 fails on purpose)
- :every_settings_tab_fits_beside_the_rail_at_1080p · pins blocking bug 1 · fails now; passes on the old layout (the
  tabs fitted 1920 minus 112 px of margin) and will pass once the three pages are narrowed.
- :the_backdrop_copes_with_a_missing_or_wrong_kind_of_picture, :blurs_every_listed_fields_picture · stub blurred() to
  return a texture for any path (missing file) and the first fails; return null and the second fails.
- :the_settings_open_over_the_page_under_the_rail_and_a_notice, :opening_and_closing_the_settings_about_credits_and_report_leaves_nothing_behind,
  :credits_and_report_close_back_to_their_about_buttons, :esc_* (3), :settings_tab_pressed_twice..., :closing_the_settings_from_the_loadout/armory_tab...,
  :a_tab_pressed_with_the_settings_open..., :the_practice_rail_*, :the_rail_*, :the_pages_beside_the_rail_fit...,
  :after_the_crash_screen_continue... · regression pins; each fails if the matching line in main.gd/menu_screen.gd
  (add_over_page's move_child, _credits_closed/_report_closed focus, set_page_hidden, set_practice) is removed.
  I did not run the removals for every one; the ordering and focus ones I reasoned from the code.

Suite: only this file was run (tools/check.sh runs elsewhere): 23/24, 14.8 s; log in pipeline/out/qa/ur1-qa.log.
Not testable headless: how the glass panels and the blurred picture look, text cut by the real renderer at 1280x720
(the layout figures above are the 1920x1080 design space the stretch scales), window-mode changes. Owner: open each
Settings tab at 1280x720 and 1920x1080, and look at the HUD and Accessibility tabs' right edge.

Re-check (attempt 2, by the lead; QA's own test as the evidence): Pass.
- Blocking 1 fixed in 89d8286: the HUD and Accessibility labels, the HUD's sliders and the column gaps are narrower;
  `test_ur1_qa.gd` › test_every_settings_tab_fits_beside_the_rail_at_1080p passes, with test_ui1_menus' no-cut-words
  and no-overlap tests on every tab.
- Advisories taken: the load warnings are WARN; the safe-start notice closes for the Loadout from practice; the
  backdrop follows a field that stands in (map_picked from _keep_a_playable_map). The notice tabbable over Settings
  stays (harmless), and now takes the keyboard when it shows (critic, attempt 1).

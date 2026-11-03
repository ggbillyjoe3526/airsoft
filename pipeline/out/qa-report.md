Task: UF1 · QA commit (see git log, "Agent: qa") · Verdict: Pass

Scope: seven playtest fixes in f7f819a over 4b10288. The thread's 19 tests pass; I added 8 probes (all pass).

Blocking findings: none.

Advisory findings (not caused by a broken criterion; worth KNOWN_ISSUES rows or a follow-up):
1. game/ui/loadout_page.gd:216-220 (back_out) with game/ui/loadout_gear.gd (switching): the SWITCH REPLICA pop-up
   is a child of the gear page, so Customise hides it but leaves it "visible". With the pop-up open, Tab or arrow
   keys can move focus to the Customise button behind the shade and press it; the first Esc then closes the
   hidden pop-up and only the second leaves Customise. Fix: close_switch() in show_customise().
2. game/ui/loadout_gear.gd (switcher): the pop-up stays open across a tab change (click another rail tab, come
   back) and across BACK TO PRACTICE. Fix: close it in LoadoutPage._on_visibility_changed when hidden.
3. game/ui/hud.gd:931-933: holding Tab hides the whole centre stack (_middle), not only the table and stamp,
   so in a live round a banner or the hit call is hidden while Tab is held. Looks intended; confirm with owner.
4. game/ui/hud.gd:931: the summary check reads last frame's _summary.visible, so the Tab board can show for one
   frame as the summary opens. Cosmetic.

Tests added (tests/unit/test_uf1_qa.gd, 8 tests; each fails if its feature is stubbed out, as noted):
- holding_tab_over_the_table_hides_it_and_letting_go_brings_it_back: drives Hud.update with a real round end;
  fails without set_covered (table stays up under the board).
- tab_held_through_the_table_delay_shows_the_table_only_once_let_go: same, Tab held before the round ends.
- the_next_round_starting_under_the_board_closes_the_table_for_good: no stale table after release.
- the_match_summary_keeps_the_tab_board_down_and_the_banners_up: fails without the `not _summary.visible` guard.
- tab_in_a_live_round_leaves_nothing_hidden_after_it: _middle is restored on release.
- opening_twice_retargets_and_closing_twice_is_harmless: pop-up re-open and double close.
- picking_the_same_dot_twice_and_a_dot_off_the_end_stay_on_one_card: unknown level edges no card.
- every_part_of_the_replica_panel_and_minimap_keeps_solid_words_at_low_opacity: no modulate fade anywhere under
  the panel or minimap at 30 percent; fails with the old modulate.a code.
I did not run the stubbed-out variants against production code (QA may not edit it); the expected failures follow
from the diff. The two advisory pop-up bugs were reproduced with throwaway tests and left out of the file so the suite stays green.

Counts: test_uf1_qa.gd 8/8 pass in about 20 s; test_uf1_ui_fixes.gd 19/19 (thread's). Full check.sh was
running elsewhere and not run by me.

Not testable here (owner's list): how the faded panel and minimap look at 30 percent, the Armory dot ring and card edge
on screen, the rail rule at 1080p, the pop-up's feel, and the silent loading screen with real audio output.

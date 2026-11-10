Task: LV15 (level track paging) · QA commit pending · Verdict: Pass

Blocking: none. Advisory: none found.
Hunted, no bug: page_of/page_count at 1, 2, 11, 12, 21, 22 dots (10 levels = one page, 11 = two, 20 = two, 21 = three); first and last dots stay inside END_ROOM on every page; dot_at never leaves the shown page (x far left/right); level beyond the count opens on the last page; levelling off opens on the cap page with the on-arrow disabled and the back-arrow working; page_changed fires once per turn and not on a no-op; no extra orphan nodes after building, turning and freeing the armory page 3 times; keyboard from a pick on another page starts from the shown page's end; the page's own card arrows still use MenuParts.arrow_button (armory_cards/test_armory pass). Other users of dot_position/dot_at (test_uf1_ui_fixes, test_ur5_qa, test_armory_cards) pass.

Tests added (tests/unit/test_lv15_track.gd, 6; file now 14 tests):
- :141 test_page_counts_at_the_ten_level_edges · page_count at 1/2/11/12/21/22 · old code has no page_count (script error).
- :149 test_every_page_dot_lies_inside_the_track_and_dot_at_never_leaves_the_page · every page of every count · old code has no page API.
- :165 test_a_level_beyond_the_count_opens_on_the_last_page_and_draws · page() clamp · fails on old code (no page()).
- :172 test_with_levelling_off_the_track_opens_on_the_cap_page_and_the_arrows_work · summary with levelling off · fails on old code (no page_on_arrow).
- :186 test_freeing_the_summary_leaves_no_orphan_nodes · orphan count after 3 build/turn/free cycles · fails if arrows or the signal leaked.
- :199 test_page_changed_fires_once_per_turn_and_not_when_nothing_moves · signal count.
Stub check: restored HEAD~1 game/ui armory_dots/summary/menu_parts/armory_page; the new tests (and the original 8) fail with script errors for the missing page API. Restored afterwards.

Runs: test_lv15_track 14/14 (116 asserts, 2.6 s). tools/check.sh: gdlint, changelog, wiki, unit tests parts 1-3 pass; the run was killed at the 10-minute limit before the smoke step, so smoke ran alone: PASS, zero script errors (975 frames, 8 rounds). Raw output: pipeline/out/qa/check.txt, smoke.txt.
Not tested (needs a display): arrow/track layout at window sizes and fullscreen, arrow tooltip look, gamepad focus travel from the track to the arrows. pipeline/out/performance.md shows modified in the tree from before this run; not mine, not committed.

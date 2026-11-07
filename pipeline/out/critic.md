Task: BP6 menus part · menus, HUD, controls, debug and bug-report fixes, two UI audits
Attempt: 2 of 4
Head: d5c28ed on origin/main 158e93b (#241, #242 merged). QA and performance reports are from 03:28 and 03:32, before the retry and the rebase (03:48 to 03:58).
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept once QA, performance and tools/check.sh pass on d5c28ed. Until then it is Retry by rule (a report for this head is missing).

My first-review points, checked against the code:
- (1) Fixed. The mark is written by `SaveFile.touch` (game/save/save_file.gd:174), which refuses a held path, and removed by `SaveFile.remove` (run_record.gd:57, 157). No raw write is left in game/, so Contract 8 holds. The new locked-folder test (test_run_record.gd:373) exercises it.
- (2) Fixed. debug_ribbons.gd:88-102 hands over the kept arrays whole, zeroes the tail in a `range` loop and drops the references after the call. No GDScript arrays are made per frame, and the header says so honestly. test_debug_view.gd:189 checks a smaller second frame against the busiest frame's size.
- (3) Fixed. The test frees its ArmoryDots, and GUT reports 0 orphans now. `px_per_label` is used (bot_intent_view.gd:93). The po comments are in their right places (en.po:1929-1933). Key names go through KEY_MINUS, KEY_NUM and KEY_NUM_ENTER, so the number pad's minus reads "Num -".
- (4) Fixed. `Fe80::1` goes while `Fade::1` and `Bad::add_child` stay (IPV6 look-ahead, report_scrub.gd:49). Zero-padded octets go (line 37), WSL `/mnt/c/Users/<other>` goes (line 30), and tab or double-space names get the cut guard (lines 197-205). The linearity test still passes. Two new KNOWN_ISSUES rows (run record; "(driver " and `Dead::beef`) are honest. The changelog is softened.
- (5) and (6) Fixed. The record now says `_settle` still calls show_xp. The re-shot walk-off crop is clean and shows a 12 px gap above LOST. The pause shot shows no crosshair and no teammate markers. `_team_markers.visible` is written only in `set_paused` (hud.gd:1040), so resume can't un-hide markers that should be hidden.
- (7) Fixed. One interpolation line on the port and one on the picture ports (the turntable's own Control line is separate). test_mc1_qa.gd:536 holds zoom in and out on the wheel beside the replica actions, never keyless.

Run here on d5c28ed after `--import`: test_run_record 19/19, test_report_scrub 35/35, test_bp6_menus 8/8 with 0 orphans, test_debug_view 11/11, test_mc1_qa 20/20, test_key_bindings 21/21. gdlint is clean on the touched files.

Failed checks, with evidence:
8. [judgment] changelog.d/bp6-menus.md has one line at 121 columns (the "Settings › Accessibility says…" bullet), over the 120-column wrap in PROCESS › Writing docs 8.
   The record draft /tmp/claude-0/bp6-reports/menus-record.md:3-4 names commits that don't exist after the rebase (5c91cc7, 61d847b, 3a8cb99, cf0c888) and the old base 8d80e13. The real ones are ec8512c..d5c28ed on 158e93b, and the retry is 85c7c85, 006aadf and d5c28ed. Its "QA passed / Performance passed" (line 78 on) doesn't say which head they passed on.

Non-blocking nits:
- tests/unit/test_run_record.gd:370-372 has three blank lines before a function.
- game/play/bot_intent_view.gd:93 is a 123-column code line.
- Contract 8's text could name `SaveFile.touch` as the one header-less write.

Must-fix before merge:
- Re-run QA and performance on d5c28ed. The retry touched the ribbon hot path, the HUD pause and the scrub regexes.
- Run tools/check.sh on d5c28ed.
- Rewrap the 121-column changelog line.
- Fix the record's SHAs and base, and name the head QA and performance passed on.

Owner should test in the game:
- Customise 3/4 view at 4K, and after moving the window to a screen of another size.
- NVDA: give a squad order, skip a round, and move through Settings' sliders and switches.
- Keys rebound to `[`, `;` and number pad keys: check the names in Controls and the HUD prompts.
- Bot intentions with bots standing close and behind walls; check the labels step up and are hidden by walls.
- Pause in a match: no crosshair or teammate markers through the panel, and both come back on resume.
- F4 during a long spray: the ribbons look right and the frame rate holds.

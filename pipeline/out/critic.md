Task: UF1 · UI fixes from the owner's playtest (no TASKS block; judged against the record and the seven asks)
Attempt: 1 of 4
Head: 417833f (gdlint, UF1 and neighbour suites green; full tools/check.sh still running, verdict holds only if it passes)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept
Evidence for the passes:
1. Opacity: hud.gd +553/+419 HudStyle.restyle instead of modulate.a, hud_minimap.gd +238/+531 ring and field picture
   at opacity_of; HUD tab: settings_hud_page.gd +121 Panels moved left (screenshot: Minimap fits, no bar); Armory:
   armory_dots.gd +95/+118, armory_track.gd +83, armory_page.gd +65; Rail: nav_rail.gd +170-178 offsets only, no
   position.x; Loadout: loadout_switch.gd (new), loadout_gear.gd +263 SWITCH REPLICA, swap via LoadoutRules.equip;
   Loading: sim_audio.gd +672 start_ambience, beds no longer play() at layout (-702), play_session.gd +1212/+1242;
   Scoreboard: hud_table.gd rows 40→30, hud.gd +931-935 set_covered and board held down over the summary.
2. No ARCHITECTURE contract touched (UI and SimAudio presentation only).
3. Hud.update adds bool and visible sets only; View._draw builds a value Color; restyle runs on a pref change only.
4. test_nothing_sounds_behind_the_loading_screen_until_continue fails on base (beds played at _start_ambience);
   test_the_lit_tab_s_rule_sits_on_its_card fails with the old position.x = -RULE_WIDTH * 2.
5-7. Typed, constants named, no globals; pop-up built once, shown by visible; helpers moved, not copied.
Failed checks, with evidence:
8. [judgment] hud.gd:933 `_middle.visible = not board` hides the hit call ("HIT!") and every banner whenever Tab is
   held, in a live round too, not only over the round's table. The owner asked about after a round or match; the
   record's Decisions (docs/records/UF1.md) and the wiki say nothing about the live-round case (QA advisory 3).
Must-fix before merge (non-blocking): add a Decisions line to docs/records/UF1.md saying Tab hides the hit call and
banners while held in a live round (or limit the hide to when the round's table is up), and ask the owner.
Nits: docs/wiki/Loadout.md one line runs past 120 columns; LoadoutSwitch is not focus-trapped (Tab can still reach
the rail behind the shade).
Owner should test in the game:
- HUD opacity 20 %: panel and minimap backgrounds fade, counts, icons, mag boxes, dots stay solid over bright walls.
- Settings › HUD at your resolution: Minimap zoom and samples visible with no scroll bar.
- Armory: click several dots, including off-screen levels; ring, teal number and white card edge follow.
- Loadout: SWITCH REPLICA on each slot, pick the other slot's replica (swap), Esc, CLOSE, click outside.
- Load a match: total silence until Continue; then ambience. Also Loadout → back to match (no Continue).
- Hold Tab mid-round when hit: is losing the "HIT!" call under the board OK? After a round, 8v8, HUD size 150 %.

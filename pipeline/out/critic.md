Task: BP3B · The full-game bug pass's fixes after the Sniper Rifle
Attempt: 2 of 4
Head: 6b24db5 plus the uncommitted working tree (tools/check.sh still running: gdlint, changelog, wiki passed so far; not re-run here). This verdict holds only once check.sh is green on this tree.
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
QA (pipeline/out/qa.md) and performance (pipeline/out/performance.md) both say Pass for this tree, with no blocking findings.
Evidence:
1. All six fixes are in the diff. pause_menu.gd:376,384-394: FOCUS_NONE under Settings, restored on close, and the Loadout chip is refreshed. loadout_page.gd:242 with quit_prompt.gd:16,97. main.gd:204,213. simulation.gd:198-200 (`or state.dev_content`). first_person_view.gd:23,117 with play_session.gd:1171. en.po:2043.
2. No contract changed. The sim reads a state flag, and the HUD reads a view float.
3. Nothing is allocated per frame or per tick. The array literal at pause_menu.gd:392 runs only when Settings opens or closes. The group count at loadout_page.gd:242 runs once per key event and builds no array. The view_zoom store is a float.
4. I read test_range_challenge.gd:399: without the simulation.gd change, `helped` stays false and the test fails. QA reverted game/ for each worker test and saw each one fail. test_bp3b_qa.gd:30 now pins the PlaySession wiring that test_bp3_menus.gd:60 missed.
5. Everything is typed. There are no new gameplay literals and no new global state. The group is a const StringName on the class that joins it.
6. The changes are fixes and one clearer refusal line. No tone or pillar issue.
7. Attempt 1's failure is fixed. quit_prompt.gd:14-16: GROUP and its doc now sit above the shade block, and SHADE_ALPHA/WIDTH/PAD/RULE keep their own doc.
8. The scope is Beta fixes only. KNOWN_ISSUES has two new can-wait rows and the stale ones swept. PLAYTEST:871's quote is updated and the Loadout-chip check added (PLAYTEST:1162). The wiki line and the changelog note are there. Practice-Range.md needs no change.
Notes (not failing):
- Two added doc lines run past the 120-column house width: PLAYTEST.md:871 and wiki/Squad-Orders.md:69. Rewrap them when convenient.
- New code comments cite "(BP3)", not BP3B: first_person_view.gd:21, simulation.gd:198, quit_prompt.gd:14, pause_menu.gd:376. The record frames this as BP3's second half, so the comments read correctly.
- docs/records/BP3B.md still says `**Review:** pending` and its attempts row shows "–". Fill both in the records push.
Owner should test in the game:
- In a match: Esc, Settings, Tab many times, then Enter. Nothing behind the settings resumes or quits.
- On the range: Esc, Settings, rebind Loadout, BACK. The pause menu's Loadout chip shows the new key.
- On the Loadout page: Esc for QUIT GAME?, then press 2. Nothing changes behind the prompt; after Cancel, 2 switches.
- From Settings, go to ARMORY by the rail with the keyboard. Focus lands on something you can see, and the arrow keys move from it.
- Raise and lower the 2x Scope and the Variable Scope at 6×. The crosshair shrinks and comes back without flaring wide.
- Practice: a Timed run with the Sniper Rifle sets no best. A stock AEG run still keeps its best.

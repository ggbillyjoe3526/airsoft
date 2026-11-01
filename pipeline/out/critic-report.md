Task: MC1 · Match controls and menu fixes (no task block; judged against the brief's points 1, 5, 7, 10, 11)
Attempt: 1 of 4
Head: 3076d2e (= git rev-parse HEAD; lint, notes, wiki and targeted GUT passed on it; full unit suite and CI still running, so this verdict holds only once CI is green on 3076d2e)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept (one non-blocking check failed; QA Pass, performance Pass)
Evidence for the passes, in short:
1. Pt 1: play_session.gd:1207 _follow_hold, then ready_to_go → loading_screen.show_continue; the clock is held (_physics_process returns while _holding). Pt 5: settings_hud_page.gd:253 slider, 50 to 200 %, hud_minimap.gd:398. Pt 7: the fire press at play_session.gd:1298, _play_out :831, hold_next :1413 / round.gd:40, the match's end in test_mc1_qa:220. Pt 10: key_bindings.gd:59-62 (4, 5, G), player_input.gd:417 wheel_item never stops on the holster. Pt 11: match_rules_box.gd:28,99.
2. ready_grenade goes through PlayerCommand; Grenades.ready_command (grenades.gd:132) is a plain sim class. hold_next is written by the session the same way end_wait already was.
3. ready_command copies into the preallocated _readied; _play_out and wheel_item don't allocate; the skip clock's string is rebuilt only when its second changes.
4. test_mc1.gd:328 (a held round) can't parse or pass without hold_next; QA mutation-checked its 15 tests.
Failed checks, with evidence:
8. [judgment] The player-facing text says the skip is quick, but the brief's own measurements say otherwise. changelog.d/match-controls-and-menus.md:7 and docs/wiki/How-to-Play.md:41 both say the "Skipping the round" screen shows "for a moment". The record measured 101 s of Woodland in 16 s, and performance estimates about 30 s for a full round and up to a minute on weak PCs.
   Also, MC1.md:36 says "Known issues left: None", but QA filed advisories 3 to 5 "for KNOWN_ISSUES" and they were left unfixed: the wheel from a holstered slot 1 goes to smoke, a vault drops a wheel notch onto a bomb, and a key-migration edge can leave an action keyless. The weak-PC skip time isn't recorded either. None of these has a KNOWN_ISSUES row.
   Two comments are stale since 4960a08: play_session.gd:30 and play_tuning.gd still say the budget is "a physics frame"; it is per rendered frame now (:828).
Must-fix (none needed for Accept; do them in this PR):
- Reword "for a moment" in the changelog note and the wiki: the round plays out unseen, with its clock counting down.
- Add KNOWN_ISSUES rows for QA advisories 3 to 5 and for the skip time on weak PCs, and update MC1.md › Known issues left.
- Fix the two stale "physics frame" comments.
Not failed, but the owner's to rule: a skip takes about as long as the old 6x fast-forward did (101 s in 16 s ≈ 6.3x), only unseen. Simulating the rest honestly can't go much faster; the sim and the bots take about 4.7 ms a tick. An instant skip means approximating the rest of the round (fewer bot thinks, or a scored result), which is his call.
Owner should test in the game (at most 6, one line each):
- Skip from early in a Woodland round: is the wait under the still cover acceptable on your PC, or should it be faster and less faithful?
- Load a match: does CONTINUE appear only once the match is fully loaded, do Enter, Space and a click all start it, and is no shot fired?
- Mouse wheel: replica → smoke → flash → replica, starting from a drawn and from a holstered replica; then throw the bomb in hand with a click.
- Hop-up dial now only on Page Down / Page Up: is it reachable mid-fight, or does it need a closer default key?
- Minimap zoom at 50 % and 200 %: the samples, the field and the heard-patch rims follow the slider.
- Match page: is the Day / Night row's spacing under Ricochets and Friendly fire right?

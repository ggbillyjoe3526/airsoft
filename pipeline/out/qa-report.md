Task: MC1 · QA commit 5aadfbf · Verdict: Pass

Blocking: none.
Advisory (for KNOWN_ISSUES):
1. Skip frame cadence: game/play/play_session.gd _play_out spends skip_budget_ms in every physics step, and the engine
   runs up to max_physics_steps_per_frame=10 catch-up steps a rendered frame, so a skip renders about one frame per
   0.47 s (probe: 16 frames for a 100 s round, 7.5 s, with check.sh running alongside). Esc, Leave and the clock text
   answer within about half a second. Share one budget per rendered frame (spend it in _process) or cap catch-up.
2. play_session.gd:1107 `_frames.add(delta)` is not gated on _skipping, so a skip's 50 to 470 ms frames land in the bug
   report's frame line (FrameWindow, ReportFacts).
3. PlayerInput._wheel_to starts from the active slot even when holstered: the first notch from a holstered replica
   takes a bomb in hand instead of drawing the other replica (it drew it before MC1).
4. A wheel notch onto a bomb during a vault is lost (Vault.vaulting_command resets ready_grenade); a notch onto a replica
   is kept (held_switch_to). Inconsistent, harmless.
5. KeyBindings.load_dict: a moved default whose new key the player's own key holds is dropped without a hint, and the
   next save fixes the empty list. A layout-1 save with smoke/flash swapped (Y, G) loses the door key; one with the dial
   reordered (PgDn, 4) loses the smoke key. Documented in MC1.md; no UI says it. Never a shared key (tested).
Tests added, tests/unit/test_mc1_qa.gd (15 tests, 313 asserts; each checked in a scratch copy with the line mutated):
- :77 bomb stays in hand through a vault, no pull throws · vault drop of readied in ready_command fails it
- :104 ready_grenade + throw key in one tick · new keys/API absent at the base commit
- :125 bomb ends with the round, pull between rounds throws nothing, next round clean · same
- :148 holstered replica stays holstered after the throw · from_hand restore mutated: fails
- :169 reload puts the bomb back and draws the replica · new API absent at the base
- :186 wheel_item never lands on a bomb with none left · new API absent at the base
- :207 leaving the match mid-skip restores disable_3d · exit-tree restore removed: fails
- :220 skip to the match's end shows results, rematch starts unheld · hold_next reset removed: fails
- :254 click on the table after a skip moves on only after waiting past the delays · hold_next/end_wait absent at base
- :288,:309 Continue after go_fallback when shaders never warm; clock not started before first frame · fallback removed: fails
- :323 go() idempotent and harmless when not holding · new API absent at the base
- :360,:391,:400 old saves: five partly changed saves never share a key, keep essentials and re-save identically;
  partial save takes new defaults; any layout marker shape loads · LAYOUT_KEY absent at the base
Ran: test_mc1_qa 15/15; targeted (mc1, wg1_qa, what_got_you, sf1_qa, doors, grenades, hud_minimap, hud_prefs,
key_bindings, minimap_hearing, player_input, round, round_result, order_wheel_input) 243/243, 2030 asserts, 120 s;
second batch (callouts_feed, fb1_qa, ho1_qa, hud_hunt, hud_size, mag_hand_off_hud, match_page, mn2_qa, ping_markers,
team_sizes) 189/189, 353 s. tools/check.sh not run (running in the background from this tree). Raw output in
pipeline/out/qa/.
Could not test (owner's list, needs a display): the Continue button's look, focus and Enter/Space; mouse capture after
Continue; the skip cover and clock on a real window; wheel and bomb-in-hand feel; the Day / Night spacing; the zoom slider
and sample maps drawn; Esc latency during a skip; a click with the map (M) open while out (not probed).

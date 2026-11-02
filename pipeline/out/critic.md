Task: SN2 · The Variable Scope
Attempt: 2 of 4
Head: 300895a (full checks passed on 9472793; after e3ff224 and the clean SN1/origin-main merges only the overlapping tests re-ran, all pass; CI must confirm on this head)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Failed checks, with evidence: none.
Attempt-1 findings, now fixed:
1. Wheel zooms only with the sight up: play_session.gd:875 passes `player.aiming and player.armament.zoom_turns()`,
   player_input.gd:483 still needs cmd.aim too, armament.gd:311 requires `c.aiming` (Aiming.step runs before
   Armament.step, simulation.gd:154/177, so it is this tick's sight). test_variable_scope.gd:110 fails without the
   armament.gd:311 gate (aimed=false turn) and checks the wheel gives switch_to 1, zoom_steps 0 mid-reload.
8. KNOWN_ISSUES.md:14 (6× mouse speed, playtest) and :15 (placeholder model, document) added; vault_state.gd:26-27 wrapped.
Advisory (not failing):
- Mid-vault the sight is down (Aiming excludes c.vault.active), so the player's wheel now switches there and
  Vault's held_zoom_steps (vault.gd:192, :218) is never filled from input; records/SN2.md "Held through a vault"
  overstates it. Harmless sim-level symmetry; reword the record line or drop the plumbing later.
- test_variable_scope.gd:129 recomputes the play_session gate itself, so play_session.gd:875 has no direct test.
- Armament.zoom_now() (armament.gd:156) is still used only by tests.
Must-fix for the next attempt: none.
Owner should test in the game (at most 6, one line each):
- Aim the Variable Scope on the AEG Rifle and the Sniper Rifle; wheel 2× to 6× and back: the glass changes, the click and readout show.
- Is 6× useful at range on Woodland and The Street, and is the mouse too fast at 6×?
- From the hip, and aimed through the Red Dot or 2x Scope, the wheel still switches replicas and bombs.
- Aim held (and with toggle aim), reload, wheel to the pistol: it switches, no zoom click.
- The zoom holds through lowering, switching away and back and a new round; a new match starts it at 2×.
- It raises noticeably slower than the 2x Scope (1.9 against 1.6): too slow? The longer model looks right?

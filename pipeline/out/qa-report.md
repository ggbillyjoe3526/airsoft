Task: SN2 · QA commit ac04a2d · Verdict: Pass (after the fix; first run Fail)

Blocking
1. game/sim/armament.gd:146 (zoom_turns) with game/play/first_person_view.gd:118 and game/loadout/loadout_rules.gd:334:
   a variable optic whose stats.md row says "In the glass: no" and "Zoom to" above "Zoom" (data-legal, e.g. Red Dot with
   Zoom to 3) gets aim_zoom_to set and zoom_turns() true, so the wheel is taken, the click and "Zoom 3x" readout show,
   but the view stays at aim_zoom (aimed_zoom reads aim_zoom, never Armament.zooms; only ReplicaView's glass reads
   zooms). Scenario: edit the Red Dot row, aim, scroll: no switching, no visible zoom. Fix: aim_zoom_to only when
   zoom_in_glass (loadout_rules.gd:334), or make zoom_turns() require it; or document the column as glass-only.
   Pinned by test_the_wheel_only_turns_a_zoom_you_can_see.

Advisory
- game/input/player_input.gd:483: the wheel zooms whenever cmd.aim (the button) is held, not when aimed through it
  (Aiming sets c.aiming false while reloading, drawing, holstered, vaulting). Holding aim through a reload and scrolling
  zooms the lowered scope instead of switching replica; ignores sprint too. Owner may prefer this; check on play.
- game/ui/loadout_performance.gd:147: the Customise performance sheet's Zoom figure still reads aim_zoom (2x) for the
  Variable Scope, while part_options.gd:177 shows 6x; the two disagree and the sheet compare never credits the range.
- Window scale_with_zoom sensitivity is not scaled by the glass zoom (as the 2x Scope); at 6x aim turns feel fast.
- pipeline/out/performance.md is modified in the worktree by another agent; not part of my commit.

Tests added (tests/unit/test_sn2_qa.gd, 7 tests)
- :27 each slot keeps its own zoom (two variable rifles, active 1): checked by assertion on slot 0 staying 2x.
- :36 a new match resets zoom through Round.start_match: with reset_zooms commented out in round.gd it fails (5 vs 2).
- :53 top zoom 5.5 turns back down and bottoms at 2x (passes; guards the roundi notch maths).
- :64 zoom_step 0.5 gives 2.5x and event value 250 (passes).
- :73 a bot's 0 steps change nothing (passes).
- :80 wheel only turns a visible zoom: FAILS today (bug 1).
- :92 Customise top zoom 6x / fixed optic carries none (passes).

Run: test_sn2_qa + test_variable_scope: 16 tests, 15 passing, 1 failing (bug 1), 100/101 asserts.
Not run (told not to): tools/check.sh, unit_tests.sh, smoke test. Not testable headless: the glass drawing the live zoom
(ReplicaView.update), the HUD readout, the click sound, the wheel through a real window; owner should play: aim the
Variable Scope on AEG and Sniper, scroll 2x-6x, check the glass changes and the readout, hip-scroll still switches.

## Re-run after the fix

`aim_zoom_to` is set only for an optic zoomed in its glass (loadout_rules.gd); test_sn2_qa.gd + test_variable_scope.gd + test_customise_parts.gd: 40/40 pass. Verdict: **Pass**.

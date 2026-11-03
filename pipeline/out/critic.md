Task: BP3 · Fixes from the bug pass after the Sniper Rifle
Attempt: 2 of 4
Head: bcb0325 (brief names no check head; docs/records/BP3.md says tools/check.sh passed; not re-run)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept on the code, provided this head's QA and performance reports (pending) pass
Evidence for attempt 1's two failures:
1. Fixed. game/sim/armament.gd:453 clears pending_press in _draw, so a bolt-window press (:345) never reaches the
   slot drawn. tests/unit/test_bp3_qa.gd:44 (click at tick 48, switch at 49) and test_bp3.gd:128 would fire the
   pistol without :453, as attempt 1's scratch run showed.
6. Fixed. game/ai/bot_fire_mode.gd:46-50 ends the burst and clears auto_open once sight is lost. AUTO needs auto_open
   (:50), which only on_burst sets after open_shot passes (:70-78). test_start_mode_bots.gd:204 (re-seen in a
   doorway, no new burst: SEMI) fails without auto_open.
Notes (not failing):
- Residual, also on main: a burst stalled with the target still seen (line of fire blocked by glass or leaves at
  bot_combat.gd:162, or not ready at :151) keeps burst_left and auto_open, so when it resumes it finishes on full auto
  wherever the target now stands. This is narrower than attempt 1's case. A KNOWN_ISSUES can-wait row would cover it.
- A sight loss now zeroes burst_left without a pause, so a re-seen target gets a fresh burst, not the rest of one.
- docs/wiki/Levels-and-Unlocks.md:50 and docs/records/BP3.md item 10 run past the house line width.
- Changelog: "bots keep full auto on a target that drops out of sight" undersells the rule. They go back to full auto
  only when a new burst finds the target in the open.
Owner should test in the game:
- Sniper Rifle: click again once the handle looks home: one shot at the cycle's end; a fast double click: one.
- Shoot the rifle and switch straight to the pistol: it fires only when you click once it's up; switch back: the bolt isn't skipped.
- Variable Scope at 2x and 6x, and the 2x Scope: does the aimed turn speed feel right?
- After a crash or Safe graphics: Enter answers the notice, not PLAY; under Settings, BACK is reachable.
- Settings › HUD at 150 %: the whole panel with its bomb row shows; in a match the panel doesn't jump.
- Indoors vs bots: semi unless you're in the open down a long line, also after you duck behind cover and step out in a doorway.

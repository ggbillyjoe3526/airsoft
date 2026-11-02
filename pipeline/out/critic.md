Task: BP3 · Fixes from the bug pass after the Sniper Rifle
Attempt: 1 of 4
Head: 9f2a2a2 (brief names no check head; docs/records/BP3.md says tools/check.sh passed; not re-run)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✗ | 7 ✓ | 8 ✓
Score: 6/8 → Retry (also: pipeline/out/qa-report.md and performance.md are SN2's; no BP3 QA or performance report)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment, confirmed by a scratch run] game/sim/armament.gd:345 adds the bolt's remaining cooldown (up to 0.7 s) to
   pending_press, but _draw (armament.gd:445) never clears pending_press (holster at :290 and put_down at :432 do).
   Click on the rifle 0.6 s into its cycle, switch to the pistol next tick: the pistol fires on its own at tick 56,
   as its 0.3 s draw ends, with no click. Before BP3 the 0.15 s buffer lapsed inside the draw. A phantom shot.
6. [judgment] game/ai/bot_fire_mode.gd:45-46 restores AUTO for any re-sighted auto_for target, open or not. The open
   check runs only at a burst's start (bot_combat.gd:166-169), and burst_left is not spent while the target is
   hidden or blocked (bot_combat.gd:153-163 return first), so a target that reappears mid-burst in a doorway or room
   gets the rest of the burst on full auto indoors. That breaks NA1's owner rule (full auto only at a target in the
   open down a long line) and the record's own claim, item 10: "kept for when the target shows in the open again".
Must-fix for the next attempt:
- Clear (or drop the bolt extension of) pending_press on a switch in Armament._draw; add a GUT test: click inside
  bolt_press_window, switch to the pistol, expect no SHOT without a new click.
- Restore a kept full auto only after the open check passes again: re-run open_shot when sight returns, or end the
  burst when sight is lost. Add a test with a target re-seen out of the open, mid-burst.
- Re-run QA and performance on this head, writing their reports to pipeline/out/.
Notes (not failing): changelog.d/bug-pass-sniper.md exists but is untracked, so it is not in HEAD; commit it in the
same push. Untested here: the bot's no-fire-on-selector-tick, the notice focus and menu_choice's track (UI).
Owner should test in the game:
- Sniper Rifle: shoot, click again once the handle looks home: one shot at the cycle's end; a fast double click: one.
- Shoot the rifle, switch to the pistol at once: it fires as soon as it's up; switch back: the bolt isn't skipped.
- Aimed through the Variable Scope at 2x and 6x, and through the 2x Scope: does the turn speed feel right?
- Crash the game or pick Safe graphics: does Enter on the notice answer it, not start a match? Is BACK reachable under Settings?
- Settings › HUD at 150 %: the whole panel with its bomb row shows; in a match the panel doesn't jump.
- Indoors vs bots: they stay on semi unless you're in the open down a long line, after ducking behind cover too.

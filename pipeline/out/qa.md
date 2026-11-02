Task: BP3 (attempt 2) · QA commit 5f293f5 · Verdict: Pass

Attempt-1 findings, both fixed:
- Bolt press firing the pistol after a switch: Armament._draw now clears pending_press (game/sim/armament.gd:453). test_bp3 (click kept for the rifle, 0 shots) and test_bp3_qa (click at 0.8 s, switch a tick later; control with the window off) pass. A press made on the switch tick itself still fires after the draw (the clear runs before the fire section), as intended. Not checked by stubbing the fix out (QA may not edit game/).
- test_loadout_screen expecting "15": rate_text now shows whole from 2 BBs/s (loadout_performance.gd:211); test_loadout_screen 26/26.

New in auto_open / rate_text: no blocking findings.
- auto_open is cleared in Bot.reset, on an open_shot miss and when sight is lost; stale values on a target switch are harmless because every use also checks auto_for == target.id.
- rate_text edges: 1.99 -> "1.99", 1.999 and 2.0 -> "2", 8.05 -> "8", 0 -> "0", 0.92 -> "0.92". 2.5 would read "3" (no data row has one).

Advisory (not blocking, no failing test added):
- bot_fire_mode.gd select/on_burst: select runs before on_burst in the tick, so a burst that begins on non-open ground with auto_open still true from the last burst fires its first tick in AUTO; the selector cycles back next tick. One BB, no cmd.fire on the cycle tick. Same on a target switch A -> B -> A (auto_open stale true, auto_for == A). Fix if wanted: on_burst clears auto_open and select recomputes, or select skips AUTO while burst_left <= 0.
- bot_fire_mode.gd select: losing sight now zeroes burst_left without setting pause_left, so a bot that loses sight for a tick restarts its next burst with no burst_pause (only while auto_open was true).

Tests added (tests/unit/test_bp3_qa.gd): rate_text edges around the 2.0 cut (fails on the old 0.01-step-only code for 14.95-style rates, not run against it); a new round clears auto_open and auto_for (fails if bot.gd:321 is dropped, not run against it).
Runs (single files): test_bp3 8/8, test_bp3_qa 4/4, test_start_mode_bots 12/12 (69 asserts, 2.0 s), test_loadout_screen 26/26 (212 asserts, 4.5 s).
Not run: tools/check.sh (running separately), smoke test, full suite. Needs a display/play: whether a bot's first full-auto tick on non-open ground reads as a glitch (it should not).

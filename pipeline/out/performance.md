Task: BP3 (attempt 2) · head bcb0325 · Verdict: Pass
Run: none (CPU shared with a long benchmark; judged from code, no headless --perf run) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and the diff
Metrics: not measured (judgment only). Regressions (> 10 % worse): none measured
Blocking findings: none
Last commit (judgment):
- game/ai/bot.gd:154,321 auto_open is one bool on the existing Bot, reset in reset(); no allocation, no new node or resource.
- game/ai/bot_fire_mode.gd:44-50,67-78 select/on_burst per bot per tick: only bool and int compares, no Array/Dictionary/String/Callable; the `shown` local is a bool.
- game/sim/armament.gd (_draw) `pending_press = 0.0` is one float store on a switch or draw, not per tick.
- game/ui/loadout_performance.gd:213 rate_text allocates a String only on a Loadout row refresh (menu UI, not in play); static and shared by loadout_gear.gd:211.
Earlier commits, re-checked (judgment):
- game/sim/armament.gd stowed_cooldowns is a PackedFloat64Array built once in create(), filled in refill(); the per-tick loop over 2-3 slots is allocation-free and cheap. Armament.new() occurs only in create(), so every instance has the array.
- game/ai/bot_holster.gd put_away() reads fields only. game/ui/menu_choice.gd queue_redraw runs on sort-children only (menu).
Advisory: game/ui/hud_preview.gd builds one Grenades.Hand in _init (settings tab, freed with it); fine.
Fixes: none needed
Unexplained: none (no frame, orphan or memory numbers: re-run `--perf` vs origin/main when the CPU is free if wanted)

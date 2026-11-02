Task: SN1 · head cf67ad7 · Verdict: Pass
Run: no --perf match run (tools/check.sh and the unit tests were running in the background, so a timing run would be skewed); read-only review of `git diff origin/main...HEAD` · budget: no baseline yet (pipeline/perf-budget.json does not exist), judged against targets and the diff
Metrics: not measured. Script cost is by reading, all judgment: nothing in the diff adds a node, a signal connection, a timer, a tween or a material to the running game.
Regressions (> 10 % worse): none measured; none expected (no runtime path got a loop, a node or a growing structure).
Blocking findings: none.
Advisory (all judgment):
- game/sim/accuracy.gd:31 target_spread_scale: per tick per character, one `armament.replica()` call (array index), a float multiply and a Resource field read. No allocation. Cost: well under 1 us per character per tick.
- game/ai/bot_brain.gd:114 and game/ai/bot_combat.gd:158: `fights_aimed()` runs twice per bot per think (and once in shoot only past the target gate). Two array reads and a compare each, no allocation. Cost: negligible. If it ever shows in a profile, cache the result on the bot at weapon swap.
- game/play/sim_audio.gd:217 and :529: per SHOT event only (not per tick); `_bolt_action` is an index and a bool read, `_mechanism` is the same path as the other mechanism cues (pooled players via `_play`). Boltcycle plays at 0.8 shots/s per sniper at most, so no voice growth beyond the existing voice cap. No allocation added.
- game/play/sim_audio.gd:158: boltCycle joins the `_load` list, so the 3 wavs (75 KB each, 225 KB on disk, imported as compressed `compress/mode=2`) are loaded at setup, not on first shot: no first-use hitch. Memory: about 225 KB.
- game/loadout/loadout_rules.gd:109 `pool.comes_with()`: builds two small arrays and runs `named()` per Comes-with name, but only in default_tune (menu and loadout building, not per frame or per tick).
- game/pool/pool.gd:194,214,230: `_names` / `comes_with` allocate PackedStringArray / Array; table read at start and loadout build only.
- game/ui/xp_card.gd:130 and hud.gd:880: one extra bool in the end-of-match card; the card is built once per settle and freed by `hide_xp`. No change in node lifetime.
- game/config/replica_stats.gd:168: `col.get("optional", false)` once per column at table read. Negligible.
Assets (judgment): replicas/sniper.glb 397 KB (about 5.8k tris body, in line with the AEG), replicaParts/sniper.glb 203 KB, powerSources/spring.glb 52 KB (shared by the 3 springs through PowerModels, tinted by Label, so one mesh, not three). Loaded on demand like the other replica models. About 0.9 MB of new install size in total. The sniper replica is held in hand by one viewmodel at a time and by bot figures through the existing shared-model path; no new per-instance material or mesh code in the diff.
Shaders and presets: no new shader, particle, shadow or post effect, so no prewarm entry is needed and no quality-preset bypass.
Fixes: none required.
Unexplained: none. Not checked: draw calls and frame time (no GPU here), and the sniper's view-model draw cost in a rendered run; the owner's hardware should confirm F3 draw calls with the sniper in hand equal the AEG's, within noise.

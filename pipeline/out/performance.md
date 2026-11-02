Task: SN2 · head bdcf468 · Verdict: Pass
Run: none (brief: no unit/check runs, no targeted run needed; bots never set zoom_steps, so a bot match exercises none of the new paths) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and the diff
Metrics: not measured. Node count, orphans, draw calls and static memory cannot change: no node, timer, tween, material, shader or connection is added at runtime (judgment)
Regressions (> 10 % worse): none measured; none expected

Blocking findings: none

Advisory (all judgment)
- game/play/replica_view.gd:236-238: one float write per rendered frame, only for a glass with magnify > 0 (a PackedFloat64Array read, no allocation). OpticGlass.update already ran every frame, so no new work. A narrower glass FOV at 6x renders no more than at 2x.
- game/ui/hud.gd:1269-1273: _show_zoom does tr() % String.num().trim_suffix() on a ZOOM event (one string, a few allocations, per wheel notch). Event-rate, not per-frame, and far cheaper than _show_hop_up's BB flight at hud.gd:1257; fine.
- game/sim/armament.gd:143-146: zoom_turns() runs once per player tick from play_session.gd:870 (two array reads, two compares). Negligible. _turn_zoom (armament.gd:384-392) allocates nothing: the ZOOM event comes from the existing pool (_event).
- game/input/player_input.gd:432-486: fill() gains a bool param and one int write; no allocation.
- assets/models/replicaParts/aeg.glb, sniper.glb: +60.2 KB and +61.5 KB (+20 % and +30 % per file, +122 KB install), 2,140 tris per copy plus its figure version. Reuses the 2x Scope's materials (no new material or shader, so no prewarm entry is needed; the glass shader is the existing one). Only the fitted optic is shown, so the triangle cost is paid only when it is fitted. Within lean-asset policy; the owner sets the install budget.
- game/sim/{armament,vault,vault_state,grenades,player_command,round}.gd: zooms is a PackedFloat64Array sized per loadout in create(); reset on match start (round.gd:27), no per-round or per-frame allocation. vault held_zoom_steps is a plain int.
- game/config/*: new fields are plain exports (aim_zoom_to, zoom_step, zoom_to) and dictionary entries for scopeVar; the glass's picture size and its quality-preset sizing (_fit_side) are untouched, so no preset bypass.

Fixes, ranked: none needed
Unexplained: none

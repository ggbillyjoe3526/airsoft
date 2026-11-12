Task: EC1 · head af524bd4 · Verdict: Pass
Run: no --perf bot match run (diff changes audio bus layout and one-time setup only; headless has a dummy audio driver, so node count, orphans and script time cannot move) · budget: no baseline yet (pipeline/perf-budget.json does not exist), judged against targets and the diff
Metrics: not measured (judgment). Frame time: reported only, owner's hardware. Audio-thread cost (judgment): one AudioEffectReverb, enabled only on Subway; three 1-pole low-pass buses added (ShotsHalf, ShotsFull, Shots itself is pass-through); a fully idle bus is skipped by the mixer.
Regressions (> 10 % worse): none measured
Blocking findings: none
 - Per-shot code (sim_audio.gd:261,264) only swaps a bus constant: no new allocation, Array, Dictionary or string work per shot or tick. judgment
 - set_echo (sim_audio.gd:637-659) runs once in setup and once in _exit_tree; the string format in push_warning is on the failure path only. It writes the shared reverb resource, no new Object, node, timer, tween or connection. judgment
 - Freed state: set_echo(null) at _exit_tree turns the reverb off and resets the bus to 0 dB, so no echo outlives the match. The reverb and filter effects are layout sub-resources (one set, owned by AudioServer), not per-instance. judgment
 - No growth: voice pools unchanged, no new players, decals or particles. judgment
 - Prewarm/presets: no new material, mesh or particle, so no shader prewarm entry needed; no graphics settings touched. Shot echo lives in SoundConfig.shot_echoes (data, per map). judgment
Advisory:
 - default_bus_layout.tres: Shots reverb at the Godot default tail (room 0.72, wet 0.28) mixes many simultaneous shots (all bots) into one reverb instance, so cost is constant, not per shot. Fine, but listen on the Low preset on Subway (owner's hardware) for audio crackle.
 - sim_audio.gd:640-643: set_echo is static and touches global AudioServer state, so two PlayerSessions or a missed _exit_tree (crash/scene swap by free) leave Subway's reverb on for the next map. The setup call on every map (null for non-Subway) resets it, so the risk is covered. judgment
 - default_bus_layout.tres: bus indices shifted (Footsteps 3 -> 4 ... AmbienceRight 13 -> 14). Any code using hard-coded indices would break; the diff uses names only (grep clean in the changed files). judgment
 - The reverb tail is cut when it is disabled at match exit; harmless.
Fixes: none required.
Unexplained: none

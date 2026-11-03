Task: none (AU2) · head 31cbb53 · Verdict: Pass
Run: not measured (no --perf match run; the change adds no node or tick work beyond the lines below) · budget: no baseline yet (pipeline/perf-budget.json does not exist), judged against targets and the diff against 4b10288
Metrics: install size assets/ 17 MB, assets/audio 15 MB, cues 13 MB / 500 MB budget (ok, measured); 418 cue WAVs, largest 308 KB (smoke_pop) (measured)
Regressions (> 10 % worse): none measured; frame times not measurable here
Blocking findings: none
Advisory:
- Memory (judgment): cues import as AudioStreamWAV (compress/mode=2), all cues loaded at setup; 13 MB on disk, a few MB decoded at most. Three more impact sets (glass, plastic, cardboard) load once in SimAudio.setup (sim_audio.gd:155), not per frame.
- Voices (judgment): longer tails (impacts 0.18-0.35 s, mags 0.4 s, doors ~1 s, power_gas 0.3 s) hold voices longer, but all play is bounded: field_voices 24, own_voices 8, cue_voices 4, shot_cue_voices 6 (sound_config.gd:147-150), impact_limit 8 per impact_window via VoicePool.StartLimit (sim_audio.gd:141). A 0.35 s impact at 8 per window cannot exceed the pool; worst case is the oldest voice being reused (audible cut), not growth. Could raise cue_voices for impacts if the owner hears clipping in a heavy hose; a feel test, not a perf issue.
- sim_audio.gd:226-227 (judgment): per SHOT, `_slide_lock.get(p, &"")` is a Dictionary lookup on StringName, no allocation; `_emptied` (sim_audio.gd:546) is only called when the profile has a slide lock (gas pistols), and does two array reads and a compare. No String formatting, Array, Callable or lambda per frame. The `"%s%s_1.wav"` format at sim_audio.gd:153 is in setup only.
- Surface enum +3 (ray_hit.gd:9) (judgment): map_level makes one StaticBody3D per surface, so at most 3 more bodies per map, only for surfaces a map uses; negligible node count. Per-surface tables (SURFACE_NAMES, IMPACT_NAMES, puff_colours, noise ground, ricochet match) are extended in step; array lookups by enum, no new allocation. Depot and range bakes are the same size (130667 B; 6953 -> 6948 B).
- Presets/prewarm (judgment): no new material, particle or shader; the glass/plastic/cardboard puffs reuse existing colours. No quality-preset bypass.
- Teardown (judgment): no new nodes, timers, tweens or connections in the diff; nothing to free.
Fixes: none required.

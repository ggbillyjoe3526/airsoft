Task: AU1 · head c521599 · Verdict: Pass
Run: no match run (audio-only diff, worker's tools/check.sh in flight); targeted GUT: test_sound_occlusion, test_au1_loudness, test_voice_pool, 35/35 pass, 507 asserts · budget: no baseline yet, judged against targets and the diff
Metrics: not measured (no per-frame code path changed beyond the SHOT event handler)
Regressions: none measured
Blocking: none
Advisory:
- game/play/sim_audio.gd:206 (judgment) heard_scale per SHOT is two array reads and a float, no allocation; the shooter null check is cheap. Own shots compute it too, unused beyond the reach test; negligible.
- game/play/sim_audio.gd:209 (judgment) _power_gain.get on a typed Dictionary[StringName, float] with a StringName key: no allocation, one hash per shot.
- game/play/sim_audio.gd:571 (judgment) v.unit_size set per field play: one property write per voice start, bounded by the 24-voice pool.
- Occlusion (measured by test, judgment for reach): rays are still gated by occlusion_reach 60 m and the 24-ray budget; _play checks _in_reach before share_of, and share_of casts nothing beyond 60 m (closed_far ramps the last share 60-120 m). The longer shot reach adds no rays; shots 60-120 m away reuse the cached share.
- default_bus_layout.tres (judgment) one HardLimiter on Master: a per-block peak detector on the mix thread, no per-frame GDScript cost.
- More shots now reach the 24-voice field pool on big maps; growth stays bounded by shot_cue_voices 6 per cue and pool priority (SHOT over FIELD), so voices never exceed 24. Presentation-only; judgment.
Fixes: none needed
Unexplained: none

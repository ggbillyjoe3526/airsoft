Task: AU7 · head d98953e + uncommitted game/play/sim_audio.gd · Verdict: Pass
Run: none (audio re-cut and a few lines of sim logic; no --perf match run) · budget: no baseline yet, judged against targets and by reading the diff

Metrics: not measured (judgment only)
Regressions (> 10 % worse): none measured

Blocking findings: none

Checked (judgment unless marked):
- Per-tick allocations: none. sim_audio.gd:85 `_bounced_at` is one PackedFloat64Array, resized only in `_bomb_bounce_slot` (:625-632) when below the 12-slot pool, so at most once a match. The new `since` local (:268) is a float. `_mechanism` (:538) takes `gain: float = -1.0`, no Callable or Array; the pin handler passes `_cfg.pin_gain`.
- Stale-clock guard (`since >= 0.0`, :268-269) fixes a bounce muted after a new match; no cost.
- Voice pool: bounce/pin/flash play on cue_voices = 4 per cue within the 24 field voices (sound_config.gd:151-153). The bounce cue is now 0.6 s (was 1.1 s) and bounce_hold 0.45 s (was 1.0 s), so a bomb starts a new bounce cue every 0.45 s at most: at most ~2 voices per bomb, capped at 4 per cue (the oldest is reused). Bounded, no growth.
- Size (measured): bounce WAVs 97064 -> 53318 B each (-131 KB across 3 vs the first AU7 cut), pins 22.4 KB each (-8 KB each vs the first cut). Net against main: bounce +36 KB each, pin +4 to +5 KB each, flash +4 to +5 KB each, about +150 KB of source WAV. The .import files are unchanged: compress/mode=2 (QOA, about 4x smaller exported), loop_mode=0. Static memory impact is well under 0.1 MB.
- Loading: cues are loaded up front with the other variants, so no first-use hitch. No new material, particle or preset bypass.

Advisory:
- sound_config.gd (pin_gain 1.6, bang_gain 1.4) are loudness tuning, not performance; a playtest item.

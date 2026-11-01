Task: AU1 · QA commit PENDING · Verdict: Pass

Attempt 2, head b1c3a50 (per-play AudioStreamPlayer3D.max_db: a Kind.SHOT play capped at its own volume_db, every other kind at field_max_db 3.0).

Blocking findings: none. The attempt-1 failure (stale settings version in test_save_bundle.gd) is fixed in 795acc7 and the file passes.

Advisory findings (for KNOWN_ISSUES or a tuning pass; by design of the cap, not bugs):
- game/play/sim_audio.gd:573 · the flash bang is Kind.SHOT with bang_gain 1.0 (0 dB), so within 10 m it is now capped at 0 dB where it was 3 dB (about 3 dB quieter up close, same far off). Nothing in the notes asked for that; raise bang_gain to 1.4 if the bang should keep its old peak.
- same line · a silenced bot's shot within 10 m is capped at its own muffled level (about -4 dB) where it was up to +3 dB before; deliberate ("no louder than yours"), but a silenced bot beside you is about 6 dB quieter than before this change. Owner's play-test should confirm.
- same line · volume_db includes the per-play random spread, so the cap moves with it (a few tenths of a dB, by design). Occlusion lowers the bus, not volume_db, for the effects and power buses, so the cap is the open level and the bus does the muffling (correct).
- Checked and fine: voice reuse in both directions (shot, bang, step, steel ring: every play resets max_db), your own sounds (plain AudioStreamPlayer, no max_db, positional voices untouched), the range's steel ring and wood target (field cap), zero gain (-inf, not NaN), a shot whose shooter is gone.

Tests added (tests/unit/test_au1_qa.gd, 7 new; each fails with the max_db line removed in a scratch copy, checked: voice-cap tests fail on the 3.0 left in place):
- test_au1_qa.gd:342 · 24 rounds of shot, step and bang on one pool, with and without voices finishing, each playing voice's cap matches its cue · fails without the line (3.0 vs the shot's level)
- :369 · a shot behind a wall: capped at its own level on the full-muffle bus
- :384 · a silenced shot at 2 m capped at its muffled level
- :395 · the flash bang capped at its own level, shot_unit_size and bang_reach kept
- :408 · a steel ring after a shot on its voice keeps field_max_db
- :424 · zero shot and power gain: cap is -inf or very low, never NaN
- :440 · your own shot leaves every positional voice silent and at the default cap

Run (targeted, 26 files incl. test_save_bundle, au1_qa, au1_loudness, sound_occlusion, voice_pool, sp1_qa, parts_in_play, bot_bombs, sound_mix, ambient_calls, range_play, footsteps, settings and the other SimAudio users): 407 tests, 407 passing, 0 failing, 182.6 s, no SCRIPT ERROR. gdlint on test_au1_qa.gd clean. Raw log: pipeline/out/qa/qa-attempt2.log. Full tools/check.sh not run by me (the worker's is running).

Not testable here: how the lifted bot shots sound and whether the cap choice (own level) suits the mix; needs ears on a display machine (owner's list: bot gunfire up close and at 30 m, a silenced bot beside you, a flash bang indoors).

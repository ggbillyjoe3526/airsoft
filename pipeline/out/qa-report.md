Task: AU1 · QA commit e6758db · Verdict: Fail

## Blocking
- tests/unit/test_save_bundle.gd:64 still asserts the settings store is at version 2 (reads_the_four_stores_as_one fails:
  3 is not 2). Settings.VERSION went to 3; the worker's test updates missed it. Change the line (and its comment) to 3.

## Advisory
- game/play/sim_audio.gd:249 the flash bang is Kind.SHOT, so it now gets shot_unit_size (10 m full level) not 4 m, against
  the record's "other sounds keep 4 m and 60 m". Louder bang within 10 m; probably fine, but it was not chosen.
- game/play/sim_audio.gd:209 a silenced replica's power part is not muffled and now plays at 4.0 (motor) on the Power bus
  against 1.4 x 0.45 on the shot: the motor drowns the silenced shot by about 16 dB (was 7 dB). Halved reach still applies.
- game/play/sound_cues.gd:70 the minimap and bot hearing still use max_distance (60 m) x heard_scale; shots are now heard
  out to 120 m, so a shot you hear 60 to 120 m away leaves no patch on the minimap.
- A version 2 file whose player chose 30 % on purpose moves to 20 % (indistinguishable from the old default); a version 1
  file with the old 0.6 goes straight to 0.2. Both as the record says.
- test_fb2_qa.gd / test_gr1_qa.gd / test_settings.gd updates are right; test_save_bundle.gd was the one missed.

## Checked, no bug found
- Settings versions 1, 2, 3 and a bundle's version 2 store; bad volumes types; a later 30 % choice survives restarts; the
  version 2 path leaves window mode and V-Sync alone; the input dictionary is not changed.
- A shot from a gone shooter or an unheld slot plays nothing, no error. Voice reuse leaves no stale unit_size or
  max_distance (shot then step, shot then range ring). Range targets keep 4 m and 80 m. Calls keep 4 m and are not cut off.
- Zero ambience_gain and zero power_gain give -inf dB, no error. Edge of shot_reach plays, past it does not.

## Tests added (tests/unit/test_au1_qa.gd, 20 tests, all pass)
- :84-176 settings migration at versions 1, 2, 3, bundle, reset · mutated migrate_defaults back to "version >= 2 passes
  through" in a copy: 4 of them fail.
- :180-230 gone shooter / bad slot / voice reuse between a shot and a step or a range ring · removed the voice's unit_size
  assignment in a copy: the reuse test fails (round 0 shot on 4.0 not 10.0).
- :232-330 ambience calls and beds (every field, day and night) at ambience_gain, zero gains, reach edge, own shot.

## Run
- Targeted: 577 tests in 44 files that touch SimAudio, SoundConfig or Settings, plus the save page, screen, keeper and
  bundle files: all pass except the one above. tools/check.sh not run (the worker's is running in the same tree).

## Not tested
- How loud the bots now sound, the limiter's audible effect and the ambience level need ears and a display: owner's list.

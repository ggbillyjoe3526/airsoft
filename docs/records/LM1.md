# LM1 · A lift's button plays its motor at once

**Review:** 4 attempts · critic Accept 8/8 · qa Pass · performance Pass

The owner, 2026-11-23, after hearing the lift's files: "remove lift_motor_2.wav and up_down.wav. use lift_motor_1.wav
only. it should play as soon as the player presses a button. this means also remove the placeholder
lift_button_1.wav". Ruling in `docs/DECISIONS.md` (Audio).

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-23 | 1 | Opus 5.5 (build thread) | ✓ | 6/8 Retry | check 1: any press, even out of reach or at a call button, cut the motor riding the car; check 8: timing not on record, ASSETS and wiki stale |
| 2026-11-23 | 2 | Opus 5.5 (build thread) | ✓ | 6/8 Retry | check 7: three lines over 120 columns, a test name; check 8: KNOWN_ISSUES row stale |
| 2026-11-23 | 3 | Opus 5.5 (build thread) | ✓ | 7/8 Retry | check 7: lift_sounds.py said cut_recordings.py still made the motor |
| 2026-11-23 | 4 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Decisions

- **The press is the motor's cue.** `SimAudio.LIFT_CUES` maps BUTTON to `lift_motor` and DEPART to none; the
  simulation's events are unchanged, so the bots' hearing, the minimap and the sound cues hear a press as before
  (default: balance untouched).
- **Where it plays.** Pressed from inside the car (the presser stands in it, `LiftSpec.holds`), over the car's floor
  (`SoundConfig.lift_motor_rise`) and carried with the car as the rider was used to; from a landing, at the call
  button, not carried, as the car may be on the other floor. Heard out to the button's reach
  (`LiftConfig.button_heard`, 6 m), at `lift_motor_gain`, by anyone in reach as the beep was (default: the press is
  the presser's own feedback, wherever they stand).
- **A press heard while that lift's motor plays starts it again** (default): presses never stack into a roar, and every
  press is heard at once. Each lift keeps two motors apart (critic, attempt 1): the one pressed inside, riding the car,
  and the one pressed at a call button. A call-button press, or any press out of the listener's reach (no voice),
  never cuts or takes over the motor you ride with; a press only replaces the earlier motor of its own kind, after it
  has its own voice.
- **The timing, as asked** (default: his words, "as soon as the player presses a button"). Pressing inside with the
  doors open, the doors shut over `door_time` 1.5 s (the next tick) and the car rides `floor_time` 4.0 s; the 3.2 s
  clip covers the doors and the first ~1.7 s of the ride, so its last ~2.3 s are quiet (before LM1 the motor started
  as the car set off and covered 3.2 s of it). Calling a car from the other floor plays the motor at your call button
  and the car arrives with only its chime and doors to those inside. Both put to him on N68: if he wants the ride
  covered, the lever is to play the clip again as the car sets off.
- **The files.** `lift_motor_2` and `lift_button_1` (and their `.import`) deleted at his word (git history keeps
  them); `SoundConfig.lift_button_gain` and `tools/lift_sounds.py`'s beep removed. `lift_motor_1` is a fixed file now:
  `tools/cut_recordings.py` no longer reads `elevator/up_down.wav`. His `up_down.wav` was moved out of the raw
  folder to `audio/william/removed/elevator/` in the shared files rather than deleted (default: a recording can't
  be made again; he can ask for it gone for good).

## Known issues left

- None. Play check N68 on the Beta 2 checklist.

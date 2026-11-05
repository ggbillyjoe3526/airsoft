# AU7 · The smoke and flash bombs re-cut to sound like the owner's recordings

**Review:** critic Accept 8/8 · qa Pass · performance Pass

Owner, 2026-11-05: "the flash and smoke grenades don't sound like the recordings i made for them? i used a balloon pop
sound for the flashbang and for the smoke grenade a ring pull sound and a bouncing can." Then, on the first re-cut's
preview: "grenade pin sound is muffle/static noise?"; on the second: "perfect".

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Opus 5.5 (build thread) | ✓ (bomb tests) | 5/8 Revise | bounce cut late, hold too long, ring-out claims; owner: pin hiss |
| 2026-11-05 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Cause

The cues were his recordings since AU5 and AU6, but cut and processed past recognising:

- **Flash:** his balloon pop was driven into a soft clip (tanh, 4x over its peak) to match the synthesised bang's
  loudness, which flattened the pop's punch and tail into a 0.3 s block at -1 dB (its loudest 50 ms 4 dB under its
  peak; his pop's is 10 to 12).
- **Bounce:** each bounce played only the first 0.2 s of his can: one knock, none of its rattle; and the first take
  was cut from 0.18 s of soft pre-sound, so one bounce in three was nearly silent.
- **Smoke going off:** the "pop" was his can's knock pitched down to 0.6 under the spray: a deep clonk he never
  recorded.
- **Pin:** his takes were found 3 to 15 ms after the click's peak, so the click was cut off, and what was left (a
  click 22 to 24 dB over its loudest 50 ms) took 17 dB of gain and the limiter to match the old pin's loudness: hiss.

## Decisions

- **Every cut starts on its sound:** `from_onsets` from a little before each take, so it starts 4 ms before the sound
  first comes within 10 dB of its loudest.
- **Pin:** his click, high-passed at 300 Hz (his room's rumble; the click is mostly 6 to 12 kHz), 0.25 s, left at its
  peak (-24 dB loudest 50 ms); `SoundConfig.pin_gain` 1.6 (+6 dB over the other mechanisms) lifts it in play. Owner
  "perfect" on the preview.
- **Bounce:** his can's knock group, 0.6 s (30 dB down by 0.3 to 0.4 s), played once from a bomb's bounce; a bounce
  within `SoundConfig.bounce_hold` (0.45 s) of it is left silent, as the can's own knocks play on, so a bomb's next
  visible bounce (0.4 to 0.6 s later) is heard. A throw starts the slot afresh (`SimAudio._bounced_at`, one float a
  bomb slot, sized once); a time from before the clock went back is stale.
- **Smoke going off:** his long spray alone, from its own burst, at -14 dB loudest 50 ms (the old pop's -9.9 and
  hiss's -18.9 between). Default: no pop, as he named only the ring pull and the can; the sim's pop (bots hear it) is
  unchanged.
- **Flash:** his pop from its bang, 0.5 s, clean; `SoundConfig.bang_gain` 1.0 to 1.4 (+3 dB of the 6 the clip gave,
  so the master bus's limiter takes little off it up close). Default for the owner to judge by ear.
- `saturate()` is gone from `tools/cut_recordings.py`; nothing else used it.

## Verification

- `tests/unit/test_grenade_sounds.gd`: the can plays once from a bomb's bounce and again after the hold, a new throw
  starts it afresh, the pin and the can start on their sound, the hold is shorter than the knock group, and the pop is
  not clipped (its loudest 50 ms over 7 dB under its peak).

## Known issues left

- How it sounds in play is the owner's call: `docs/PLAYTEST.md` › Smoke and flash bombs (SF1) › Bomb sounds (AU7).

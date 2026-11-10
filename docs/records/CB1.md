# CB1 · Countdown beeps

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Goal

The owner, 2026-11-10: "When a match starts the countdown should have a beep on 3, 2 and 1", then "The whistle
should still sound on GO! Only add beeps to 3, 2, 1".

## Decisions

- **The same beep on 3, 2 and 1, no beep at GO.** The owner's recorded thermometer beep (`count_beep`, AU2, the range
  challenge's), at `SoundConfig.beep_gain`, pitch 1.0 each time, in your ear on the Interface bus. GO is the
  referee's whistle alone, as before (owner's follow-up).
- **The first round's 3 beeps as the match is first heard.** Its ROUND_COUNT falls in the build, under the loading
  screen, where no tick is heard (BP8); `PlaySession._start_sound` beeps once with the ambience if the round is still
  held, so round 1 gets all three beeps like every other round.
- **One beep function.** `SimAudio.count_beep(pitch)` plays both this countdown and the range challenge's shot timer
  (critic's advisory).
- **No new sound, no new notices.** The beep is the owner's own recording, already shipped.

## Known issues left

- None.

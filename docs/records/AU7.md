# AU7 · The smoke and flash bombs re-cut to sound like the owner's recordings

**Review:** pending

Owner, 2026-11-05: "the flash and smoke grenades don't sound like the recordings i made for them? i used a balloon pop
sound for the flashbang and for the smoke grenade a ring pull sound and a bouncing can."

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Opus 5.5 (build thread) | – | – | – |

## Cause

The cues were his recordings since AU5 and AU6, but cut and processed past recognising:

- **Flash:** his balloon pop was driven into a soft clip (tanh, 4x over its peak) to match the synthesised bang's
  loudness, which flattened the pop's punch and tail into a 0.3 s block at -1 dB (its loudest 50 ms 4 dB under its
  peak; his pop's is 10).
- **Bounce:** each bounce played only the first 0.2 s of his can: one knock, none of its rattle and little bounces
  (each of his takes rings on for 1.1 to 1.5 s).
- **Smoke going off:** the "pop" was his can's knock pitched down to 0.6 under the spray: a deep clonk he never
  recorded.
- **Pin:** cut at 0.2 s, half way through the ring's ring-out (0.3 s).

## Decisions

- **Flash:** his pop from its bang, 0.5 s, clean; `SoundConfig.bang_gain` 1.0 to 2.0 makes up the 6 dB the clip gave
  (the master bus's hard limiter holds the peaks), so it carries as far as before.
- **Bounce:** a whole take of his can (1.1 s), played once a bomb from its first bounce; a bounce within
  `SoundConfig.bounce_hold` (1.0 s) of it is left silent, as the can's own knocks play on, and a throw starts the slot
  afresh (`SimAudio._bounced_at`, one float a bomb slot, sized once). Default: the can's own knocks rather than one
  knock a bounce, since one knock a bounce was what didn't sound like his can.
- **Smoke going off:** his long spray alone, from its own burst, at -14 dB loudest 50 ms (the old pop's -9.9 and
  hiss's -18.9 between). Default: no pop, as he named only the ring pull and the can; the sim's pop (bots hear it) is
  unchanged.
- **Pin:** 0.4 s, so it rings out.
- `saturate()` is gone from `tools/cut_recordings.py`; nothing else used it.

## Verification

- `tests/unit/test_grenade_sounds.gd`: the can plays once from a bomb's first bounce and again once rung out, a new
  throw starts it afresh, the cue lengths, and the pop is not clipped (its loudest 50 ms over 7 dB under its peak).
- Measured: flash 4.0 to 10 dB crest; bounce 0.2 to 1.1 s at the same -14.2 dB loudest 50 ms; pin 0.2 to 0.32-0.36 s.

## Known issues left

- How it sounds in play is the owner's call: `docs/PLAYTEST.md` › Smoke and flash bombs (SF1) › Bomb sounds (AU7).

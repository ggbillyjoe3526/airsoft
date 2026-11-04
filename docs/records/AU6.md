# AU6 · The owner's third batch: whistle, metal, grass and gravel steps, rope, flashbang, spring rifle, woods; the toothbrush Cyber Pistol

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-04 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **The owner's pick and the defaults** are in `docs/DECISIONS.md` › Audio (the third batch).
- **Recordings that never fall quiet:** his metal steps run into each other over a steady rumble, and his running on
  gravel has no gap between strides, so `onsets()` finds where each sound starts (the 5 ms level rising 6 to 10 dB
  over the quietest of the 80 ms before it, at least 0.2 to 0.3 s after the last) and `from_onsets()` cuts from each.
  The same finds the whistle's blasts (a 30 dB rise, so a dip inside a blast doesn't count) and the spring rifle's
  bursts.
- **Steps:** gravel's run is the new `walking_gravel`, its sprint `running_gravel`, its landing the running steps 15 %
  lower (a placeholder). Grass is his: walking as the run, the walk's later takes as the sprint, `jumping_grass` as the
  landing. Metal is his walk, under 250 Hz taken out twice (its rumble buried the steps: 86 % of its energy was under
  200 Hz), as run and (later takes) sprint; its landing the steps 5 % lower, a placeholder. Earth still stands in from
  gravel, now from the new gravel file. `balance_steps()` keeps every ground within 1 dB of concrete overall and 2 dB in
  the band; metal's landing needs the most (+7 dB in the band), grass's landing +5.
- **Whistle:** his blasts under 0.9 s are the short ones (seven of 0.2 to 0.3 s), the rest long (two of 2.3 s, two of
  1.0 s); the first three short and the last three long, each cut to SoundConfig's 0.3 and 0.8 s.
- **Flag rope:** his two long pulls (8.7 s each), the first up and the second down, five 0.25 s windows of each, one
  for each step of the flag's climb.
- **Flash bomb:** his recording from its bang (0.45 s), saturated (tanh, 4x over its peak) so it lands at -5.0 dB
  loudest 50 ms against the synthesised bang's -3.4; unsaturated its peaks would hold it at -11.
- **Spring rifle:** his two shots, each from where it bursts out (0.45 s), as `shot_spring`; the 0.16 s of quieter
  run-up before each burst is `power_spring`, which plays with the shot, so the shot answers the trigger at once
  (cut from the run-up's start, it would lag 0.17 s). The test that the spring part lasts 0.16 s (AU4) holds. His
  bolt's three takes go through `bolt()` as the pistol's slide did. The AU4 mix is gone from the script (in git at
  7f1586e); `thud()` and `pea_whistle()` went with it.
- **Cyber Pistol:** the AU4 recipe with his toothbrush's whir (95 % pitch) for the motor's, no longer a placeholder.
- **Woods:** `woodlands.wav` high-passed at 150 Hz twice (63 % of its energy was 60 to 120 Hz wind rumble), 58 s,
  as `loops/woods_day.wav`, Woodland's day bed at gain 0.025 (under the yard's 0.035). Its 2 to 6 kHz content is
  birds, so the night keeps the street at night.

## Known issues left

- Woodland's night bed stays the street at night (`docs/KNOWN_ISSUES.md`).

# AU9 · The owner's wood steps, metal bin and woods at night

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-08 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **Five recordings (2026-11-08), matched by name:** `walking_wood` is the wood run (`step_wood_run`; a walk is the
  run pace, as on every other ground), `running_wood` the wood sprint, `jumping_wood` the wood landing, `metal_bang`
  the steel skip, container and van run into (`prop_steel`), `night_forest` Woodland's night bed (`woods_night`). The
  raw files sit with the others in the shared `audio/william/raw/`.
- **Cut, not processed:** the walk (a step every 0.93 s with creaks between) and the run (steps 0.25 s apart that never
  fall quiet) are cut where each step starts (`onsets`, 20 dB rise), the jumps and bangs as his takes; 5 steady steps
  of each (13, 16 and 11 found), no re-pitching. Each bang is 0.9 s of its ring with a fade, under NoiseConfig.quiet
  (1.2 s), so one knock never overlaps the next; his two bangs make 3 variants (the third the first 4 % lower).
- **Footsteps stay information:** his wood steps are a hollow floor's thuds, almost all under 300 Hz, so the existing
  `balance_steps` rule (DECISIONS › Audio, every ground within 1 dB of concrete overall and 2 dB in 0.7 to 4 kHz)
  lifts their 0.7 to 4 kHz band 12.4 dB (run), 11.2 dB (sprint) and 4.9 dB (land), the rest 2 to 3 dB down. Default:
  keep the rule (bots and players read the ground by ear); the preview has old and new side by side.
- **Woods at night** keeps the beds' 40 Hz high-pass only (no wind rumble in it, unlike his woods by day) and the
  night bed's gain, 0.02; the owl and creak calls still play over it. Its 60 s loop adds 5.3 MB to the repository
  (QOA-compressed in exports, like the other beds).
- `Walking.wav` (his first solid-floor walk) is unused now: it was the wood stand-in.

## Known issues left

- None new; 9 placeholders remain (BBs on concrete, soil and leaves; steps on soil; landings on gravel, leaves and
  metal), listed by `tools/cut_recordings.py --placeholders`.

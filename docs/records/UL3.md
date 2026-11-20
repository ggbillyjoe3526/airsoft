# UL3 · Subway's light on Ultra and the lift's sounds

**Review:** 1 attempt · critic pending · qa pending · performance pending

The owner's 0.1 Beta 2 playtest (2026-11-20), items 5 and 7: "subway map is too dark. could be a shadow issue as it
improves the closer i get to an object/surface" (two screenshots: the concourse's kiosk, the top of the escalators,
both Ultra's warm look) and "lift sounds are still out of sync. should play before doors close".

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-20 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **What was dark.** Rendered on lavapipe at each preset: High, Medium and Low light the station evenly; only Ultra
  matched his pictures. On Ultra (Global illumination Scene) the engine's scene bounce light (SDFGI) replaces the
  ambient fill, and since BP9 each interior area probe's own ambient (its captured picture) replaces SDFGI inside its
  box. Underground SDFGI has no sky for its rays: with the probes' ambient switched off the escalator shaft and the
  hall's ceiling were black, and the probes' own light was darker than High's fill. Taking the lamps' shadows off
  changed nothing, so it is not a shadow problem; walking up to a surface helped because the probes' and SDFGI's
  light is coarse with distance. UL2's stronger SDFGI underground (energy 1.5, bounce 1.0) did not reach the shafts.
- **The fix:** an underground field gathers no SDFGI and its interior probes keep no ambient on Ultra
  (`FieldLighting._bounce`, `GraphicsApply.scene_bounce`): the field's fill lights the shade as on High, under Ultra's
  every-lamp shadows, finer screen bounce, haze and screen reflections. Not brighter than High (same fill, same lamps).
  `LookConfig.sdfgi_energy_underground` and `sdfgi_bounce_underground` went with it (nothing read them).
  `RoofConfig.plain_lamp_indirect` stays: it is the strip lamps' share of any baked or gathered bounce, harmless.
  It also saves Ultra's SDFGI cost on Subway.
- **The lift's doors are heard first** (`LiftConfig.shut_lead`, 0.4 s, default): a shut keeps its door_time (1.5 s,
  so the car still sets off as before and every route and bot wait is unchanged); its sound plays as it starts, the
  leaves stand open for the lead and meet in the remaining 1.1 s (`LiftConfig.shut_time`). His recording reaches
  its full level about 0.3 s in, so its loud part now lands on the leaves moving. Bodies are kept out of the doorway
  from the start, as before; BBs pass the leaves standing open.
- **An arriving car is heard opening** (default): it chimed and its doors slid open silently; now the doors' sound
  plays with the chime (`Lifts._ride`). AU10 meant his door takes for both opening and shutting.
- **A doorway's cue plays from its face on your side** (`SimAudio.doorway_face`, the LIFT event's `direction`): the
  leaves turn solid as they start to shut, and a cue at the doorway's middle was muffled by them from a landing off
  to the side (both of Subway's lifts, a test).

## Known issues left

- The look on a real card: the cloud renders on software (lavapipe). Play check in `docs/PLAYTEST.md` (UL3) and the
  Beta 2 checklist.

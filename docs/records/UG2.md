# UG2 · No sun indoors: Depot's hall lit by its lamps alone on High and Ultra

**Review:** pending (attempt 3, after the owner's rework)

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | thread | see Checks | Retry 7/8 | the shade and lamps didn't cover the hall past 70 m from the eye; Sun shadows off still shaded |
| 2026-11-09 | 2 | thread | see Checks | Accept 8/8 | – (then reworked at the owner's word, below) |
| 2026-11-10 | 3 | thread | see Checks | pending | – |

## Goal

Step 2 of the owner's Ultra push for the whole game (2026-11-09, `docs/records/UG1.md` › Goal). Attempts 1 and 2 let
the sun into Depot's hall at its rooflights, in strips and shafts. The owner then ruled (2026-11-10): "Why are there
sun strips if there are no windows?", "Have the light sources cast realistic deep shadows", "Remove the sun light.
There is no place for sun to get inside. This is just for depot as it is indoors only", and later "I like the look of
the latest screenshots. Just not the long strips of sun light". So on a roofed field, High and Ultra light the hall
with its lamps alone, with deep shadows, keeping the wide, soft lamp look of his 2026-11-10 picture.

## Approach

- **No sun under the roof** (`RoofLamps.key_share`, `RoofConfig.lamp_sun_share` 0): while the lamps shine,
  `FieldLighting.set_key_share` puts the sun out and hides it, so its shadow passes go too. Low and Medium keep the
  overhead light as the lamps' stand-in (no real lamps there); an open field keeps its sun on every preset.
- **Less sky light** (`RoofLamps.ambient_share`, `lamp_ambient_share` 0.3, `FieldLighting.set_ambient_share`): the
  environment's ambient light (High's) drops, so shadows stay deep. On Ultra the bounce light (SDFGI) traces the sky
  instead of using the ambient, so `RoofLamps` puts the roof's ceiling into it while the lamps shine
  (GI_MODE_STATIC; out of it as before for the stand-in): the sky no longer lights the hall through the roof and the
  lamps' light bounces off the ceiling.
- **Every lamp lit over the whole hall** (`RoofLamps.reach`: the roof's diagonal and height, about 134 m on Depot,
  at least `lamp_far`): with no sun, a lamp past the old 28 m / 70 m reach would leave the hall dark. Near (High)
  shadows the lamps within `lamp_near` (28 m), Far (Ultra) every lamp.
- **Removed** the first build's sun shade, hall haze, rooflight spans and sun-shadow stretch, and their tests
  (`test_sun_shade`, `test_sun_shade_qa`); `roof_truss.py`, `test_gr2_qa` and `test_depot_hall` are back to main's.

## Owner's changes (2026-11-10)

- **Wider, softer lamps** ("the lamp lights are too focused … I can see the cone … more wider and diffused", and
  "the shadows should still be dark, not filled in"): cone 36° to 50°, its edge falloff 0.6 to 0.35 (no rim on the
  floor); wider cones (65°, 72°) filled the shadows in. Picture: `art/graphics/ug2/6-depot-wider-softer-lamps.jpg`.
- **No sun indoors** (above).
- **Wider and softer again, shadows readable** ("Again, the lamp light is too focused. It should be wider, softer and
  diffused. Also all the shadows are extremely dark. Keep them dark but the player should still be able to recognise
  objects and players"): cone 50° to 70°, edge falloff 0.35 to 0.15, reach 17 to 24 m and distance falloff 1 to 0.6,
  so neighbouring lamps overlap into one even light with soft-edged shadows; energy 6 (the overlap does the rest), the
  sky's light on High kept at 0.6. Pictures: `art/graphics/ug2/9-*.jpg`.

## Defaults taken

- Energy 6 from trial renders at Ultra (6, 7, 9.5, 11, 16 with the wide cone): the floor near the eye about as bright
  as the owner's liked picture, crate tops not blown out. A narrow cone at 26 to 32 lit pools with near-black between
  them, which the owner rejected.
- A tunnel under racking (no lamp over it) is the darkest place on Ultra, where Scene GI replaces the sky's ambient
  light: with the wide lamps the light reaching in from the hall makes its shelves readable (narrow lamps left it
  near-black; a stronger GI, energy 1.8, bounce 0.8, barely lifted it). Step 3 (eye adaptation) lifts it further.
- Depot's bake (Baked light, `tools/bake_light.gd`) is left as it is: Medium still has the sun it was baked for.
  On High and Ultra it still carries the sun's one bounce (`docs/KNOWN_ISSUES.md`); step 5 replaces it.
- On High the lamps past 28 m are lit without shadows, so a far one can light a little through a room's roof; shadowing
  all 93 on High would cost Ultra's frame time (`docs/KNOWN_ISSUES.md`).
- The rooflight panels in the roof model stay as drawn (DH1's model, pale panels, not glowing).

## Checks

- gdlint clean; `test_lamp_lights` (the sun goes out and comes back, the sky's light, the ceiling in the bounce light,
  every lamp lit over the hall), `test_lamp_lights_qa`, `test_depot_hall`, `test_graphics_apply`, `test_gr2_qa`,
  `test_night_light_qa`, `test_torch`, `test_look` and `test_baked_light` pass; CI runs the whole suite.
- Renders (Ultra and High, no sun, the hall and the West tunnel with the yard outside): `/mnt/project-files/art/graphics/ug2/`.

## Known issues left

- Frame cost on Ultra is unmeasured (no GPU in the cloud): all 93 lamps lit and shadowed, but the sun's shadow passes
  gone. The owner's check is in the playtest list.

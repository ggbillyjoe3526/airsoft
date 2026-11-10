# UG3 · Eye adaptation: the dark opens up, the tuned look holds

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | thread | see Checks | pending | – |

## Goal

Step 3 of the owner's Ultra graphics (2026-11-09, `docs/ROADMAP.md`): eye adaptation, every map, scaling per preset.
It should also lift Depot's West tunnel and Woodland's shade under the crowns, both near black on Ultra since UG2's
deep shadows and the Sunlit Concrete light.

## Approach

- **A Graphics row,** Eye adaptation, off on Low and Medium, on on High and Ultra (`data/graphics.md`; Forward+ and
  Mobile, as Compatibility has no auto exposure). The Settings page lists it under Effects, with a note.
- **Godot's auto exposure** (`CameraAttributesPractical` on the field's WorldEnvironment, `FieldLighting`): it meters
  the mean of the brightest channel before exposure and divides the picture by it over `auto_exposure_scale`.
  `eye_attributes` sets the scale to `LightingConfig.eye_middle` and clamps the meter to
  [middle / `eye_lift`, middle x `eye_drop`]: a view darker than the middle opens up, at most 3 times; with
  `eye_drop` 1 every brighter view keeps the preset's own exposure, so the looks the owner approved stay as tuned and
  only dark views change. Its sensitivity limits are ISO: 800 per unit of brightness at the default sensitivity
  (CameraAttributesPractical's 12.5 / 100 / 100), `FieldLighting.ISO_PER_BRIGHTNESS`.
- **Speed** `LookConfig.eye_speed` 0.8: the engine steps its meter by speed x the frame's time, so under 1 even a
  second-long frame never overshoots.
- **Off** clears the world's camera attributes, so a preset without it costs nothing.
- **The scope's glass** (`OpticGlass`) gets its own fixed attributes: the main view tonemaps (and so adapts) its
  picture once, with the rest.
- **The night** keeps its tuned dark: `night_lighting.tres` `eye_lift` 1.

## Measured (cloud, lavapipe, Ultra, glow off in both; `tools/_lamp_debug.gd`, local)

Mean picture brightness (0-255), Eye adaptation off / on:

| View | Off | On |
|---|---|---|
| Depot hall | 119.8 | 119.8 |
| Depot, the West tunnel from the hall | 82.5 | 102.4 |
| Depot, inside the West tunnel looking out | 13.6 | 26.9 |
| Woodland open field (logstacks) | 87.5 | 87.5 |
| Woodland under the crowns (clearing) | 11.6 | 31.1 |
| Woodland by the cabin, in shade | 11.7 | 37.6 |

Depot's hall meters about 0.35 and Woodland's open field above 0.25, so one middle (0.25) holds both looks; a
middle of 0.7 brightened Depot's hall (120 to 165) and was dropped.

## Defaults taken

- High and Ultra only: Low is the modest-PC preset and Medium keeps its look; the meter costs a small reduction pass.
- Lift only (`eye_drop` 1), at most 3 times: the dark becomes readable without losing its mood; bright views never
  darken, so nothing the owner approved changes.
- The night unchanged (`eye_lift` 1): Woodland's night was tuned dark on purpose.
- Speed 0.8: a second or two to open up, like stepping into a dark room.

## Checks

- gdlint clean; `test_eye_adaptation` (7) and QA's `test_ug3_qa` (9: old saves, Compatibility greyed, renderer switch,
  no orphans, extreme settings, the text keys) pass, with `test_graphics_table`, `test_gr1_qa`, `test_graphics_apply`,
  `test_lamp_lights`, `test_map_data`.
- Pictures: `/mnt/project-files/art/graphics/ug3/`.

## Known issues left

- In the cloud's software renderer the glow vanished with Eye adaptation on (Woodland's sky bloom: 136 to 88 mean
  brightness at a held exposure; with glow off both ways 94 and 88), though Godot's glow pass divides by the same
  meter as the picture. The owner's card decides (`docs/PLAYTEST.md` › Eye adaptation, `docs/KNOWN_ISSUES.md`).
- The cloud's frames are seconds long, so pictures there need the speed turned down (`EYE_SPEED` in the local tool);
  at 0.8 they overshoot and flash.

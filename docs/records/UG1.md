# UG1 · Lamp light: roof lamps and night pools as real shadowed lights

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | thread | see Checks | Retry 6/8 | stale comments, eye_pictures without the lamps, a duplicate picture tool, play README and DECISIONS rows |
| 2026-11-09 | 2 | thread | see Checks | Accept 8/8 | – |

## Goal

The owner (2026-11-09 19:02, 19:03 and 19:12): "use all of Godot's graphics abilities to have the best graphics
possible", baked ray- or path-traced-like light on Ultra only, scaling down per preset, for the full game, not one
map. He answered the ray-tracing card "Baked path tracing first". The plan, five steps, each shared code for every
map: (1) real lamp lights with shadows (this); (2) a roof that blocks the sun except at its skylights, so the
volumetric haze shows shafts; (3) eye adaptation; (4) finer bounce light, reflections and ambient occlusion, and
wear decals; (5) baked path-traced light (Blender Cycles onto the assembled static map's UV2).

## Approach

- **A new graphics row, Lamp light** (`lamp_lights`: off, near, far; Low and Medium off, High near, Ultra far) in
  `GraphicsQuality`, `GraphicsTable`, `data/graphics.md`, Settings › Graphics › Effects (with a tooltip) and `en.po`.
- **`RoofLamps`** (`game/play/roof_lamps.gd`), built by `RoofView` with the roof: a shadowed `SpotLight3D` under each
  lamp's lowest point, shining straight down, faded out by the engine's own distance fade (`RoofConfig.lamp_near`
  28 m, `lamp_far` 70 m, `lamp_fade` 10 m), so nothing runs per frame; no lamp is lit past its shadow's reach, since
  an unshadowed lamp would shine through the rooms' roofs. `BAKE_STATIC`, so SDFGI bakes them in rather than
  updating them each frame. Its settings are `RoofConfig`'s Lamp light group.
- **The sun dims while they shine**: the preset's overhead sun stands in for the lamps on Low and Medium;
  `FieldLighting.set_key_share` turns it down to `lamp_sun_share` (0.55) of itself while the lamps are real lights.
- **Shadows follow the shadow rows**: the root viewport's positional atlas is Shadow detail while the lamps are lit
  (the project's 4096 otherwise, which the torch was tuned on), cut into 148 slots (4, 16, 64, 64) so all 93 lamps,
  the night's pools and the torch keep one; the filter follows Softness; Softest gives each lamp the lens's size
  (contact hardening). The optic glass gets half the atlas while the lamps are lit (none before), so they don't
  shine through roofs in the glass. `any_shadows` counts the lamps, so figures keep their shadow twins.
- **Every map** (the owner): the same row gives a night's light pools (Woodland's fires and lanterns) shadows
  (`LightPools.set_shadows`), and Far gives up to `LightingConfig.real_lights_far` (8) of them a real light.
- `tools/eye_pictures.gd` draws the lamps as the preset lights them (it renders the map cards and owner pictures).

## Defaults taken

- High lights the lamps near you (28 m), Ultra the whole hall (70 m, past Depot's 65 m sight line); the coordinator's
  brief said Ultra only, but the owner wants graphics to scale per preset, so High gets the near half.
- Tuning from eleven trial renders: cone 36°, soft cone falloff 0.6, energy 26, inverse-distance falloff, sun at
  55 %, so Ultra with Lamp light Far is within about 5 % of Ultra with it Off in mean brightness at eye height (the
  roof's underside, which the downward lamps don't light, reads about 10 % darker from up high). The 93 lamps sit about 7 m apart, so the hall stays evenly lit; Ultra adds soft pools and real shadows rather
  than a stage-lit look. To re-tune once the Sunlit Concrete light model (art thread SC1) lands.
- One row for roof lamps and night pools alike, rather than a row each.

## Checks

- gdlint clean; `test_lamp_lights` 8/8 and QA's `test_lamp_lights_qa` 5/5; `test_graphics_apply`,
  `test_graphics_table`, `test_depot_hall`, `test_night_light_qa`, `test_look` pass; full `tools/check.sh` and CI:
  see the pull request.
- Before/after renders (Medium vs Ultra, same cameras): `/mnt/project-files/art/graphics/ug1/`. Frame cost is the
  owner's to measure on his card (`docs/PLAYTEST.md` › Graphics and performance).

## Known issues left

- Frame cost of 93 shadowed spots on High and Ultra, with volumetric fog on Ultra, is unmeasured (no GPU in the
  cloud); the owner's checks are in the playtest list.
- The lamps are baked into the scene's bounce light (SDFGI) as it builds, so switching Lamp light mid-match with
  Global illumination on Scene can leave their old bounce until it rebuilds as you move (critic advisory; a preset
  change from Ultra turns SDFGI off anyway). In the owner's playtest list.
- A Custom mix of Low's Mesh detail with Lamp light Far gives the pools all 8 real lights and the torch none (QA
  advisory; no preset does this).

# VF1 · Volumetric haze in four levels

**Review:** critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | touched tests, smoke test; CI | Accept 7/8 | – (doc fixes and the per-level reach after the first pictures, re-checked: Accept 7/8) |

## Goal

The owner (2026-11-15): "the volumetric haze setting should have multiple options. off, low, medium, high." Map them
onto the presets (Low must hold 60 FPS on modest PCs), measure each level's cost, convert existing saves, and show
each level on Depot, Woodland and Subway.

## Approach

- **Row:** `volumetric_fog` (label Volumetric haze) offers `off, low, medium, high` (`GraphicsQuality.VolumetricFog`);
  the Graphics tab draws it as a row of four choices with a tooltip.
- **Levels are reach and fineness, not strength:** density, colour, scattering and bounce light are LookConfig's one
  set at every level, so the haze near you is the same on every preset. A level is how far it reaches
  (`fog_length_low` 30 m, `fog_length_medium` 50 m, High `fog_length` 80 m), the froxel grid its light is worked out
  on (`fog_grid_low/medium/high`: 64 x 64, 96 x 96, 128 x 128) and whether the engine's fog filter smooths it
  (`fog_filter_from`, Medium). High is the reach and grid the old single switch drew.
- **Presets:** Low Off (its 60 FPS floor), Medium Low, High Medium, Ultra High (as before).
- **Saves:** Settings version 4; `migrate_defaults` turns an older file's Custom `volumetric_fog: "on"` into `"high"`
  (what "on" drew); "off" stays Off. A Custom save that never touched the row follows its base preset's new level.
- **Tools:** `tools/eye_pictures.gd` takes `fog=<level>` and `measure=<frames>`; `tools/menu_pictures.gd` grabs
  Settings › Graphics.

## Cost

The cloud draws on software Vulkan (lavapipe), so these are shares of a frame, not a real card's milliseconds. Each
map's card view, Low preset with only the haze row changed, 1600 x 900, mean of 12 frames after settling (measured
before the levels got their own reach; the froxel counts are unchanged, and the High-preset pictures taken after it,
8 frames each, agree: Depot +4 / +15 / +34 %, Woodland +5 / +16 / +23 % over Off):

| Map | Off | Low | Medium | High |
|---|---|---|---|---|
| Depot | 236 ms | +25 (+11 %) | +72 (+31 %) | +109 (+46 %) |
| Woodland | 246 ms | +30 (+12 %) | +72 (+29 %) | +101 (+41 %) |
| Subway | 477 ms | +6 (+1 %) | +58 (+12 %) | +102 (+21 %) |

Low costs about a fifth of High, Medium about two thirds. The froxel counts agree (0.26 M, 0.88 M, 2.1 M). A real
card's figures are a play check (`docs/PLAYTEST.md` › Volumetric haze in four levels).

## Decisions

- **Medium preset gets Low haze** (before: none below Ultra). Low haze is the engine's own default grid, unsmoothed,
  about a tenth of a Low-preset frame on the software renderer; Medium already pays for sun shadows and glow, and the
  haze is part of the look. Low (the preset) keeps none for its 60 FPS floor.
- **Same haze, finer (owner, 2026-11-15, decision card):** the levels don't change the haze's thickness.
- **Reach as well as grid (attempt 1, after the first pictures):** with grid and filter alone, Low, Medium and High
  drew the same still picture (mean difference under 1 of 255 against 4 for Off), so a player would see no reason to
  pick one. A shorter reach at the lower levels keeps the far end of a long view clearer, which the pictures show, and
  lets the coarser grid spend its slices nearer the eye.

## Known issues left

- Frame costs on a real card are unmeasured (cloud renders in software): a play check.

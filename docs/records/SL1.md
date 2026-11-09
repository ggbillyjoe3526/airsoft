# SL1 · Sunlit Concrete: the light, grade and paint

**Review:** 2 attempts · critic Accept 8/8 (Opus) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (build thread) | ✓ | 5/8 Retry | no performance report on disk; look_paint untested; stale comments; no KNOWN_ISSUES rows |
| 2026-11-09 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Decisions

- **The owner's ruling** (2026-11-09): the game's look becomes "Sunlit Concrete", game-wide, and live ray tracing
  is not planned (`docs/DECISIONS.md` › Art direction and graphics). This step changes only the shared values. Every
  map, model and material in the look follows them, with no per-map code.
- **No cel bands:** `look_band` 0.42 and `look_band_soft` 0.55 (the lit share is a smoothstep from a cosine of -0.13 to
  0.97, close to a soft Lambert), no mid step. The concept's values, kept so `light()` stays one shader for every
  preset.
- **Shade `#292826`:** the sun's far side falls to the ambient and bounce light, as in daylight. The shade only keeps
  it off pure black where no ambient reaches.
- **Paint at 60 %** (`paint_saturation`, a new global `look_paint_saturation`): one shader function (`look_paint`) in
  the shared include, applied to the albedo of every material in the look (vertex-coloured models, the site surface,
  doors, puddles). The palette hexes stay as painted, so the 20° team-hue tests are unchanged. The concept pulled
  colour 55 % back in screen space; 45 % turned Woodland's grass khaki, so 40 %.
- **Grass `#5f8a3a`** (was `#8aa860`) for sloping ground and the ground beyond the walls (MapStyle), a new palette
  entry `grass`; `meadow` keeps its value for The Street's floors. The old light green turned pale khaki once muted
  under the warmer sun.
- **The day:** sun `1.0, 0.92, 0.8` at 2.0 (was `1.0, 0.95, 0.86` at 1.25), ambient 0.55 (was 0.9), exposure 0.9. A
  more orange sun (`0.88, 0.72`) turned the grass khaki. Night keeps its own values (`night_lighting.tres`). Depot's
  and the Range's bakes were rebaked for the new sun.
- **Grade:** saturation 0.95 (was 1.14), contrast 1.12 (was 1.03), glow 0.35 (was 0.45).
- **Site surfaces:** grit 0.6, slab grain 1.0, bevel 8 % (was 30 %), foot gradient 30 % (was 22 %). The models get
  their wear in SL2.

## Known issues left

- The map pictures (loading screen, Match page) still show the Dev 2 look; they are re-rendered in SL3 once the roof
  is repainted.

- Depot's roof and trusses keep their baked violet and crimson, so they draw dark and dull until SL3 repaints them.
- Model surfaces have no wear yet (SL2).
- The site surfaces' wear (grit 0.6) costs a few more noise samples a pixel on every preset, Low included
  (performance advisory: no frame times in the cloud). If Low drops under 60 FPS on the owner's card, gate the fine
  noise by preset or set grit 0 on Low.

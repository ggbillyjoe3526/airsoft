# Graphics: the quality presets

Settings › Graphics offers four presets, Low, Medium, High and Ultra, and Custom, which is a preset with some of its
rows changed. This file is every row and each preset's value for it. The presets scale a long way (owner,
2026-10-31): Low holds 60 FPS on a reasonably modern low-powered gaming PC and draws none of the dearer effects; Ultra
is as close to ray-traced light as Godot's Forward+ renderer gets, for a card like an RTX 5090. Edge smoothing is Off
on every preset (owner, 2026-10-29); a player who wants it turns it on, which makes the preset Custom.

**The game reads this file.** It is bundled into the build and read when the game starts
(`game/config/graphics_table.gd`), like [levels.md](levels.md). After editing, run `tools/unit_tests.sh`:
`tests/unit/test_graphics_table.gd` reads this file and fails with the line number of anything it can't understand. A
cell the game can't read keeps its built-in value with a warning in the game's log ("graphics.md:12: …"), so a typo
never stops the game from starting.

---

## How to read and edit this file

- **ID** names the row for the game and in saved settings. Don't rename one: a player's Custom rows are saved by it.
  The game knows each ID and what its choices do; a row it doesn't know is skipped with a warning.
- **Label** is the row's name on the Graphics tab, as a translation key (`game/ui/text/en.po`).
- **Choices** is either the choices offered, in order (from the ones the game knows for that row: see below), or a
  range of whole numbers, lowest–highest, with its unit (`%` or `m`).
- **Cost** is what the row takes from the graphics card at its dearest, shown as squares: 0 free, 1 small, 2 medium, 3
  large.
- **Renderers** lists the renderers that can draw the row: `forward_plus` (the normal one), `mobile`, and
  `gl_compatibility` (the simpler one, for older cards), or `all`. A row the renderer in use can't draw is greyed.
- **Low, Medium, High, Ultra** are each preset's value: one of the row's choices, or a number in its range.
- **The choices the game knows:** upscaler `bilinear, fsr1, fsr2`; edge smoothing `off, fxaa, smaa, msaa_2x, msaa_4x`;
  temporal smoothing, sun shadows and baked light `off, on`; shadow detail `1024, 2048, 4096, 8192` (the sun's shadow map, in
  pixels); shadow softness `hard, soft, softer, softest`; ambient occlusion `off, half, full`; texture filtering
  `off, 2x, 4x, 8x, 16x`; mesh detail `low, medium, high, ultra`; global illumination `off, screen, scene`;
  reflections `off, probes, screen`; glow and volumetric fog `off, on`. Render scale is 10–200 % at most, shadow range
  10–500 m and wind dust 0–100 %.

## Rows

| ID | Label | Choices | Cost | Renderers | Low | Medium | High | Ultra |
|---|---|---|---|---|---|---|---|---|
| render_scale | GRAPHICS_RENDER_SCALE | 50–100 % | 3 | all | 80 % | 100 % | 100 % | 100 % |
| upscaler | GRAPHICS_UPSCALER | bilinear, fsr1, fsr2 | 1 | all | fsr1 | fsr1 | fsr1 | fsr1 |
| edge_smoothing | GRAPHICS_EDGE_SMOOTHING | off, fxaa, smaa, msaa_2x, msaa_4x | 3 | all | off | off | off | off |
| temporal_smoothing | GRAPHICS_TEMPORAL_SMOOTHING | off, on | 2 | forward_plus | off | off | off | off |
| sun_shadows | GRAPHICS_SUN_SHADOWS | off, on | 3 | all | off | on | on | on |
| shadow_detail | GRAPHICS_SHADOW_DETAIL | 1024, 2048, 4096, 8192 | 2 | all | 1024 | 2048 | 4096 | 8192 |
| shadow_softness | GRAPHICS_SHADOW_SOFTNESS | hard, soft, softer, softest | 1 | all | hard | soft | softer | softest |
| shadow_range | GRAPHICS_SHADOW_RANGE | 30–120 m | 1 | all | 40 m | 50 m | 70 m | 100 m |
| ambient_occlusion | GRAPHICS_AMBIENT_OCCLUSION | off, half, full | 3 | forward_plus | off | off | half | full |
| baked_light | GRAPHICS_BAKED_LIGHT | off, on | 1 | all | off | on | on | on |
| texture_filtering | GRAPHICS_TEXTURE_FILTERING | off, 2x, 4x, 8x, 16x | 1 | all | 2x | 4x | 16x | 16x |
| mesh_detail | GRAPHICS_MESH_DETAIL | low, medium, high, ultra | 1 | all | low | medium | high | ultra |
| wind_dust | GRAPHICS_WIND_DUST | 0–100 % | 0 | all | 0 % | 50 % | 100 % | 100 % |
| global_illumination | GRAPHICS_GLOBAL_ILLUMINATION | off, screen, scene | 3 | forward_plus | off | off | screen | scene |
| reflections | GRAPHICS_REFLECTIONS | off, probes, screen | 2 | all | off | probes | probes | screen |
| glow | GRAPHICS_GLOW | off, on | 1 | all | off | on | on | on |
| volumetric_fog | GRAPHICS_VOLUMETRIC_FOG | off, on | 3 | forward_plus | off | off | off | on |

- **Low** holds 60 FPS on a reasonably modern low-powered gaming PC: no sun shadows, ambient occlusion, baked light,
  dust, bounce light, probes, glow or haze, and an 80 % render scale sharpened back up by FSR 1. The look's shared
  light, palette and grade are the same on every preset, so Low keeps the art direction.
- **Baked light** is the map's sky shade in corners and under roofs and the sun's warm bounce off the ground and walls,
  worked out ahead by `tools/bake_light.gd` and drawn on the map's mesh cut into half-metre tiles (more triangles, no
  other cost). A map with no bake draws the same either way.
- **Ultra** is the top end: the whole scene's bounce light (SDFGI with screen-space bounce at full size and its
  finest probes), screen-space reflections over the probes, volumetric fog the sun and the bounce light up, the
  sharpest and farthest shadows with contact hardening (Softest: the sun given a size, so a shadow is sharp at its
  foot and soft away from it), full ambient occlusion and the finest mesh detail.
- **Global illumination** is light bounced off the field. Screen (High) bounces what is on screen (SSIL), cheaply;
  Scene (Ultra) adds SDFGI, the whole field's bounce and sky light, with occlusion, so a coloured wall tints the floor
  by it and a corner or a room under a roof fills with soft light. Settings and strengths: `LookConfig`'s Global
  illumination group.
- **Reflections**: Probes are the map's reflection probes, one over the field and one in each large named area,
  captured once at the start (`AreaProbes`), so a smooth floor or paint reflects the hall it is in, not the sky.
  Screen (Ultra) adds screen-space reflections over them.
- **Glow** blooms only what is brighter than white (lamp panels, a lit sky), softly. **Volumetric fog** is a faint
  haze lit by the sun and the bounce light (LookConfig's Volumetric fog group).
- **Temporal smoothing** is off on every preset: it smears the thin, fast BB streaks. It and FSR 2 are there for
  players who want them.
- **Wind dust** is a share of the specks `game/config/effects_config.gd` sets (`dust_count`), lit by the sun so they
  glint in its light and vanish in shade. At 0 % feet kick up no dust either (sprinting steps and landings).
- **Mesh detail** also draws a wood's dressing (Woodland, WL4): Low the trees' crowns alone; from Medium the forest
  beyond the fence (a share of it each step, all on Ultra), the grass tufts (denser and farther each step), the
  puddles and mud, and the leaves, fallen wood and moss. **Wind dust** is also the share of its fireflies and motes
  by night (`game/config/woods_config.gd`).
- **Your weapon torch** (WL7, night fields), when your kit carries one, is one of Mesh detail's real lights from Medium
  up for the whole match, a spot from the rail, with a shadow from High while **Sun shadows** are on
  (`GraphicsApply.TORCH_SHADOWS_FROM`); on Low, with none, a haze. Everyone else's torch is a
  drawn beam on every preset: a cone, a lens glare and a lit spot.
- **Sun shadows** off draws a soft dark disc under every other player instead (a contact shadow, free).

## Choices only some renderers draw

A choice the renderer in use can't draw is greyed, though the rest of its row can still be picked. Checked against
Godot 4.7.2 on the simpler renderer (GR4), which refuses FSR 1, FSR 2, FXAA, SMAA and temporal smoothing with a
warning and draws no ambient occlusion; MSAA and texture filtering it draws.

| Row | Choice | Renderers |
|---|---|---|
| upscaler | fsr1 | forward_plus |
| upscaler | fsr2 | forward_plus |
| edge_smoothing | fxaa | forward_plus, mobile |
| edge_smoothing | smaa | forward_plus, mobile |
| reflections | screen | forward_plus |

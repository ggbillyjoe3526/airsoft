# UG4 · Ultra's finer light: ambient occlusion, bounce and reflections at the engine's best

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | thread | see Checks | pending | – |

## Goal

Step 4 of the owner's Ultra graphics (2026-11-09, `docs/ROADMAP.md`), its first half: finer bounce light, reflections
and ambient occlusion on Ultra, every map; the wear decals follow in their own task.

## Approach

- **Ambient occlusion** (`GraphicsApply.Server.set_ao`, was `set_ssao_half`): Full (Ultra) at the engine's Ultra
  quality, whose sampling adapts per pixel up to `LookConfig.fine_adaptive` (1, the most); Half (High) keeps the
  project's medium at half size, so High sends nothing new.
- **Screen bounce** (`SSIL_QUALITY`): Scene (Ultra) at Ultra quality, same adaptive; Screen (High) stays medium, half.
- **SDFGI** (`LookConfig`): cells of 10 cm near the eye (was 20 cm) over six cascades (was five), so the farthest still
  reaches 410 m (128 cells a cascade, each twice the last); 128 rays a probe (was 96). Finer cells stop the bounce at
  a thin wall or a trunk.
- **Screen-space reflections** at full size (`project.godot`, `screen_space_reflection/half_size` false; the engine's
  roughness quality is deprecated and does nothing in 4.7). Only Screen (Ultra) draws them, so no other preset pays.

## Measured (cloud, lavapipe, Ultra; `tools/_lamp_debug.gd`, local)

Mean picture brightness (0-255), before / after: Depot hall 121.0 / 119.2, Depot overview 129.9 / 130.1, the West
tunnel from the hall 103.7 / 102.4, Woodland open field 88.1 / 88.0, under the crowns 31.6 / 32.0, cabin shade
11.8 / 11.9. The looks hold; what shows is contact shade, under the crates' pallets above all
(`/mnt/project-files/art/graphics/ug4/`).

## Defaults taken

- Ultra only: the owner's card (RTX 5090 at 4K) is what Ultra targets; High keeps exactly its frame.
- Adaptive 1 (the most samples) and 128 rays: if Ultra drops under the owner's refresh rate, `fine_adaptive` (0.5)
  gives back first, then the rays (96) and the reflections' size (`docs/KNOWN_ISSUES.md`; performance's advice).
- No VoxelGI: it needs a bake per map and SDFGI covers every map live; baked path-traced light is step 5.

## Checks

- gdlint clean; `test_fine_light` (6) and QA's `test_ug4_qa` (7: Ultra to High and back, AO off and on, custom mixes,
  the renderers, no callers of the old `set_ssao_half`, no orphans) pass, with `test_graphics_apply`, `test_look`, `test_eye_adaptation`,
  `test_ug3_qa`, `test_graphics_table`.

## Known issues left

- No frame time from a real card (the cloud renders on software): `docs/PLAYTEST.md` › Ultra's finer light.

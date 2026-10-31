# AD1 · The art direction on every map, Depot first

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-10-31 | 1 | thread | look (14), graphics, settings, site dress, props, DD1, DR2, hall, night tests; full suite on CI | – | – |

## Goal

The owner (2026-10-31): "Can you add the new art direction to Depot map" and "make sure the game is taking full
advantage of Godot's graphics capabilities"; the art direction "is just an example ... the whole idea was to get the
colour and look right, not what actually appears", and it applies game-wide, Woodland and every later map. Low holds
60 FPS on a reasonably modern low-powered gaming PC; the presets scale a long way up, Ultra as close to ray- or
path-traced light as Godot gets, for his RTX 5090.

## Approach

- **The look as shared code.** `LookConfig` (PlayTuning's `look`): the light's values, the grade, the effects'
  strengths and the palette. `game/play/look/look_light.gdshaderinc` is one `light()` for every material in the look
  (soft cel bands, violet shade, warm rim, a small soft highlight), its values global shader uniforms
  (`project.godot` [shader_globals], `LookConfig.push_globals`). `look_vertex.gdshader` and `LookMaterials` draw a
  vertex-coloured model in it.
- **Depot in the look.** The site surface includes the light; `SiteLook.grit` (0) drops every stain, chip, rust foot,
  grime band and photo grain (the photos aren't loaded), `gradient` adds the soft vertical gradient, the edges are
  lighter. Paint, accents and container colours from the palette; the CC0 props rebuilt in it
  (`tools/props/build_props.py`: crimson barrels, teal drums with ink hoops, the violet sofa, steel racking with tan
  cartons and cream boxes); the roof lit in the shared light (violet ceiling, crimson trusses), its faces wound to face
  out, out of the bounce light; the lamps brighter, so they glow. Depot's exposure 0.85 for the darker hall floor.
- **Graphics rows** (`data/graphics.md`): Bounce light (`global_illumination`: off, screen = SSIL, scene = SDFGI with
  SSIL), Reflections (off, probes = `AreaProbes`, screen = and SSR), Glow and Volumetric haze, in a new Light effects
  section of Settings › Graphics; Softest shadows give the sun a size (contact-hardening). Low none, Medium probes and
  glow, High SSIL too, Ultra everything at full quality. `FieldLighting.set_effects` switches them in place;
  `GraphicsApply.Server` sends SSIL's and SDFGI's quality and the fog's grid once a change.
- **Docs.** `docs/ART.md` rewritten to the approved look and as the standard for every map (A map in the look);
  `docs/DECISIONS.md` the two rulings; the wiki's Settings page.

## Defaults taken

- The concept's crimson (#c4405f), timber and crate sit within 20° of High contrast Beta's hue, so the palette takes
  #c23874, #a0947c and #c2b698; the shade and the rim kept off Alpha and Beta for the same reason.
- A colour global shader uniform reaches the shader unconverted on 4.7.2, `source_color` or not (a test render on the
  Vulkan renderer read #9d93bc back for a raw #564a80). The pictures had drawn it so, so the shade is named for what
  they show, #9d93bc (rim #fff9eb), and `LookConfig.globals` sends both linear.
- Racking is steel grey, not a site colour: there are dozens of racks, and any one colour on them dominates.
- The roof stays out of the bounce light, so the sky still lights the hall as its lamps would (the established
  overhead-sun fiction, DR1); SDFGI adds colour bleed and occlusion, not a darker hall.
- Temporal smoothing stays off on every preset (it smears BB streaks; owner's earlier ruling).
- Figures and replicas keep their materials until the owner's Blender models; they move onto the shared light then.

## Checks

- Locally: `tests/unit/test_look.gd` and the graphics, settings, site dress, props, DD1, DR2, hall and night tests;
  gdlint. CI runs the full suite.
- Pictures: `tools/eye_pictures.gd` with `preset=`, on the Vulkan renderer (lavapipe) in the cloud: before and after
  on High, and Low, High and Ultra side by side.
- For the owner to play: Ultra's frame rate on his RTX 5090 at 4K, the Graphics overlay's FPS with each new row on and
  off; whether the hall reads well on Low; whether any colour feels dominant.

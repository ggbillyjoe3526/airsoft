Task: WA1 · head 7310ead · Verdict: Pass
Run: none (judgment review). The smoke match is headless and plays Depot, so it cannot show shader or draw cost; the diff adds no nodes, no tick code and no per-frame code · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and the diff
Metrics: not measured (no GPU in the container; node count, orphans and static memory unchanged by construction: only material types change)
Regressions (> 10 % worse): none measured
Blocking findings: none
Advisory:
- game/play/look/look_vertex.gdshader:15 and look_clear.gdshader:12 (judgment): the sRGB-to-linear branch runs per fragment, and mix() evaluates both the pow and the linear arm, so a pow(vec3) per pixel on the greybox, 6000-instance forest and crowns. Small next to look_light's per-light smoothsteps and pow. Doing it in vertex() (COLOR is writable) would make it per vertex; costs interpolation in linear space, so only if frame time shows it.
- game/play/look/look_light.gdshaderinc:15 (judgment): the custom light() now covers the whole greybox mesh and the crowns/forest, replacing the built-in lighting (per light: 3 smoothsteps, 1-2 pow, a normalize). Pixel cost goes up on the biggest-overdraw surface wherever a map has many lights. Offset by dropping the triplanar grid (3 mipmapped anisotropic samples per pixel, map_level.gd old :495-509). Check on High/Ultra on the owner's hardware.
- game/play/woods_view.gd:210,216 (judgment): crowns and forest each get their own ShaderMaterial with the same roughness (crown_roughness), same as before; one shared material would do.
- game/play/look/look_materials.gd:28 (judgment): clear_colour keeps RENDER_PRIORITY_MIN and cast_shadow stays OFF (woods_view.gd:255), so puddle sorting and shadows are as before: two surfaces sorted by distance within one priority, ALPHA written so a depth-writing blend pass is not used for shadows. No change.
Positives (judgment):
- Shaders: 3 StandardMaterial3D permutations (triplanar-textured opaque, flat opaque, alpha) become look_vertex (already compiled for the CC0 props and Depot; srgb_colours is a uniform, so no new pipeline variant) plus one new look_clear. Net compiles about the same or fewer.
- Prewarm: look_clear's materials are returned by WoodsView.materials() (woods_view.gd:163-173) and BushView.materials(), which play_session.gd:733 feeds to ShaderPrewarm; the greybox is on screen from the first frame. No missing entry.
- Allocations: every new call (vertex_colour, clear_colour, _greybox_material) is build-time; none in _process, the tick, per-shot or per-hit code. LookMaterials loads each shader once (preload).
- Resources: the 128 px grid Image and ImageTexture (with mipmaps) per map load are gone; ShaderMaterials are refcounted and held by their MeshInstance/MultiMesh, freed with the node; no new signals, timers or tweens. Bush and woods stay MultiMesh. Bakes grow depot.res +6 KB, range.res +0.2 KB.
- Presets: no shadow, resolution or draw-distance setting changed; forest, floor and puddle shadows stay off.
Fixes: none required.
Unexplained: none. Not verified: the real GPU cost of custom light() on the greybox; test on Windows at High and Ultra with the F3 overlay, compared with main, in Woodland's Hut row and Sawmill.

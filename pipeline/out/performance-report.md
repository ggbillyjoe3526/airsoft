Task: HA1 · head 7689239 (production delta bbf29a3..010b00b) · Verdict: Pass
Run: no match (the shared cores were busy with QA's tests). The glTF JSON was measured and the code read. Budget: pipeline/perf-budget.json has no baseline yet, so judged against the owner's arms limits (docs/CC0_ASSETS.md), the targets and attempt 1.
Metrics (arms.glb, measured):
- File size is 6.48 MB (limit 8, ok). It was 5.98 MB at attempt 1 (+8 %).
- Materials: 4 (Sleeve, Glove, GloveArmour, Skin; limit 4, ok).
- Images: 9 embedded, all 2K (ok). Sizes in KB: sleeve 660/259/41, glove 582/321/168, skin 543/379/400. The images are about 3.35 MB of the file.
- Triangles drawn gloved: 38,900 (Arm 2×2,976 + GloveKit 2×2,824 + HandSurface 2×13,650).
- Triangles drawn skin only: 34,452 (Arm + Skin 2×13,650 + Nails 2×600).
- Both looks are within 40,000 (ok). The file holds 67,400.
- Clips: 28, the same count as attempt 1. Animation key data (input and output accessors) is about 613 KB. This count includes the time inputs, so it isn't the same figure as attempt 1's 377 KB.
- Draw calls and frame times: not measurable here.
Regressions (> 10 % worse): none against attempt 1 (file +8 %, triangles drawn are both lower than the 40,000 limit). Nodes and orphans: no change, since the diff adds no nodes, timers or connections.
Blocking findings: none.
Advisory:
- Hidden look (judgment): the hidden look is never skinned or drawn. ArmsView sets `visible = false` on its MeshInstance3D nodes (arms_view.gd:419-425), and Godot skins and draws only visible instances. The cost is memory only. The skin-only set (Skin_ 2×7,378 verts, Nails_ 2×365) is about 15.5k vertices, about 1 MB of CPU and GPU buffers. Each look draws the same material count or fewer, because the skin look uses Skin and the glove look uses Glove and GloveArmour.
- Per frame (judgment, read): arms_view.gd:281-292 adds no allocation. `_dress()` runs only when `_faded` or the skin look changes (:251, :290), and it does `_fade_now.clear()` and a `has` check on a small array. The per-frame `for material in _fade_now` loop covers the unique fading materials. There are still at most 4 of those, so the two extra mesh objects a side add no loop work.
- ArmsFade and ArmsTuck (judgment): they are unchanged by this delta. ArmsTuck's per-frame cost is as attempt 1 said: no heap allocation, and it runs only while the sight is raised.
- Cleanup (judgment): `_hands` and `_skin_own` are gone. That removes one retained material reference and one per-mesh array, and no new resources or nodes are created.
- game/config/viewmodel_config.gd (judgment): the hip and reload_move_by edits are data only.
- Shader prewarm (judgment): there is no new material or shader. arms_fade.gdshader is still reached through ArmsView.materials(); that check was not re-run.
- tools/blender/arms/* and tools/render_fp.gd are not shipped.
Fixes: none required.
Unexplained: none. Skinning cost of about 39k triangles with the sight raised is still unmeasured, same as attempt 1; check it on the owner's hardware under Low.

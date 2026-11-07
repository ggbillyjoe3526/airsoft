Task: none · BP6 part 3 (models) · Verdict: Pass
Performance, BP6 models, head fbdf498: PASS, no blocking. figure_bench 11 figs: main 2.07/2.15 ms vs head 2.28/2.09 (noise); load and set_body equal.
Materials (glb JSON): AEG 7->6, Sniper 7->6, human 9->8 (one draw less per instance and shadow pass); pistol 7.
Triangles summed over all meshes in each glb: AEG 40,781 and Sniper 37,966 unchanged; human 122,301 unchanged; GBB 42,250 -> 42,590 (+340) while the worker states 39,638 -> 39,590: confirm which LODs.
Install: AEG glb +259 KB, Sniper +243 KB, human +79 KB, pistol +7 KB (net ~+590 KB, why do the replicas grow?).
VRAM: human_pads_col BC1->BC7 +175 KB. New 4x4 rubber textures negligible.
Hold re-check: no heap allocs, <1 us per figure per frame. Advisory: stacked doc comments at figure_view.gd:524-529; cos(deg_to_rad(hold_view_turn)) per figure per frame could be cached.
RETRY (head 40d954c): PASS. human.glb 9,496,840 -> 9,574,920 bytes (+0.8 %), 122,301 tris unchanged, 9 -> 8 materials, 12 -> 10 images. AEG/Sniper 6 materials, pistol 7 (42,590 summed, +340 in Body). figure_bench mean head 1.525/1.624 vs main 1.601/1.541 ms (noise); one 22.6 ms max spike in a noisy run. Merged body draws: 8 a level by material count (test_bp6_graphics asserts 8 surfaces).

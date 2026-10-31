Task: DR2 · head 23c670c (attempt 2) · Verdict: Pass (one advisory the owner must check on Low)
Run: headless census + code read, no GPU · budget: no baseline yet (perf-budget.json absent); judged against DECISIONS targets. test_props 14/14 pass; test_dr2_qa 5/5 on the working tree's version.

Attempt 1 blocker (props ignore the Mesh detail preset): answered, with a limit.
- prop_dress.gd:107-135, prop_dress_config.gd:52: the shelving (156k of 182.5k tris) is now 24 chunk MultiMeshes of 20 m, each frustum-culled on its own and each taking its own mesh LOD; shelf.glb.import generate_lods=true and the test asserts the surface has LODs (test_dr2_qa/test_props). GraphicsApply.MESH_LOD maps the Mesh detail step to the viewport threshold (4 / 2 / 1 / 0.5 px, Low to Ultra), so the props now follow the preset like the project's other meshes. Draw calls: 24 shelf + 4 other models = 28 at most (High ceiling 150; base not measured).
- Limit (judgment, engine formula from memory, not measured): the shelf's simpler mesh (44 tris) has edge error 0.69 m. At Low's 4 px that switches in roughly beyond 100 to 150 m at 1080p, farther at 4K, and Depot's floor is 108 x 72 m, so on Low the LOD will rarely or never engage. The real Low saving is the chunk culling (only chunks in view are drawn; a view down the hall still shows most of both long racks, maybe 80k tris). 156k shelf tris once in view is low for a GPU, so I don't call this blocking, and hiding the shelving on Low would expose the inset backing, as the coordinator says.

Clean (measured/read)
- Nothing per frame or per tick: PropDress/PropLayout run at build only; the new `_add` bucketing (Dictionary[Vector2i, PackedInt32Array]) and views_of/all_views/count (they allocate Arrays) are build/test-only, no caller under game/ outside prop_dress.gd.
- PropDressConfig._meshes caches each model once a config; load_mesh frees the instantiated root (prop_dress_config.gd, `root.free()`); the mesh is held by the PackedScene cache and the MultiMeshes. One shared material; chunk views are children of PropDress. No orphans expected (unmeasured).
- 358 shelves in 24 chunks: about 15 instances a draw, small per draw call; shelf shadows stay OFF; drums/barrels/pallet/sofa still cast (about 26k tris a sun cascade).

Advisory
- Owner check on Low (laptop): FPS looking down Depot's long axis, with F3 showing draw calls and tris. If tight, cheapest fix is `visibility_range_end` on shelf chunks, or a coarser LOD (a lower-poly shelf model for the TILE kind) so LOD engages inside 100 m.
- The MultiMesh chunk shader is still warmed through a MeshInstance3D speck (as the bags); a first-sight hitch is possible (judgment).
- tests/unit/test_dr2_qa.gd is modified and uncommitted in the working tree (not by me); one run of it failed mid-edit, the next passed 5/5.

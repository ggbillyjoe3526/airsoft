Task: BA1 · head f8bea33 · Verdict: Pass
Run: no match run (headless, no GPU; changes are load-time and one-off picture code, nothing per frame or per tick) · budget: no perf-budget.json in tree, judged against targets, docs/CC0_ASSETS.md > Size limits and attempt 1 (7e3b7a5). Targeted tests: test_ba1_qa + test_barrel_models, 16 passing, 0 failing.
Metrics: aeg.glb 1,516,636 B / 2 MB parts-file limit (ok, measured; was 1,977,576, -23 %, 483 KB headroom) · inside/aeg.glb 410,012 B (ok, measured; not a parts file, loaded only for a part's own picture) · triangles a part 9,454 and 9,954 / 10,000 (ok, author-measured; 546 and 46 left) · drawn when fitted 882 and 5,014 (ok, down from 814/4,898 crown/extension plus inside, judgment) · barrel picture light: 1 extra DirectionalLight3D, no shadows set, 384 px max side (ok, judgment)
Regressions (> 10 % worse): none. File size and fit-time work both improved.
Blocking findings: none
 - replica_parts.gd:73-76 (removed) fit no longer instantiates or frees _Inside, so the fit does less work and the per-fit remove_child + free is gone (judgment). A fit never loads inside/aeg.glb (judgment, read from code: fit/take do not call inside()).
 - replica_parts.gd:187-205 inside(): loads, instantiates, detaches one node, frees the holder. The rest of the holder is freed with it; the returned node is owned by nothing and the caller adds it to the picture's model, which is freed with the port (replica_pictures.gd:147,154 queue_free the port, children go with it). No orphan path (judgment). The only per-call allocation is one format String and a find_children Array, once per uncached picture (not per frame).
 - replica_pictures.gd:245-260 _part_shot: the picture is cached in _part_shots (:262), so the load, turn and light happen once per part per session; the port renders UPDATE_ONCE (:168,211) after _rig sets UPDATE_DISABLED (:276). The fill light is a child of shot.port and is freed with it (judgment). It draws once; a second directional light on one 384 px frame is negligible and bypasses no quality preset (menu picture, not the match).
Advisory:
 - The inside PackedScene is not cached by the caller: if the cache is cleared (:153-155) and a part is shown again, inside/aeg.glb (0.41 MB) is re-read. Menu-only, once per card; fine (judgment).
 - Long barrel is at 9,954 / 10,000 triangles; the next change to it will breach the cap. Trim or raise the cap with the owner before adding detail (judgment).
 - Parts' own materials still have no shader prewarm entry (carried from attempt 1, BL8 record); a first-draw hitch is possible in hand. Existing gap, not new; plan for Beta (judgment).
Fixes (none required), ranked: 1. leave headroom on the long barrel's triangles; 2. add parts' materials to the shader prewarm.
Pass

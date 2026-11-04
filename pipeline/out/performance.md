Task: BL1 · head fa46a29 · Verdict: Pass
Run: static review and the .glb JSON parsed; no --perf match run (no GPU in the cloud) · budget: 40,000 triangles a
replica in the hands
Metrics: aeg.glb 39,698 in the hands + figure 328 (measured); sniper.glb 39,838 + 348 (measured); 12 meshes each
(unchanged); 7 materials (8 on main, one draw call fewer); no textures; aeg.glb 397 KB -> 1.13 MB, sniper.glb
397 KB -> 1.16 MB (one-off load, small install growth)
Regressions (>10 %): triangles +376 % by design, inside the budget
Blocking: none
 - sight_fold.gd per-frame path: set_bone_pose_rotation and set_bone_pose_scale with values cached in setup();
   no Array, Dictionary, String or lookup per frame (judgment).
Advisory:
 - Hidden sights are scaled to 0.001, not culled: about 2,070 triangles still skinned under an optic; split or hide the
   meshes if headroom is ever needed.
 - Both replicas sit at 99.2-99.6 % of the budget: new detail must be paid for.
Not measured: frame time and draw calls at 8v8 (owner's hardware).

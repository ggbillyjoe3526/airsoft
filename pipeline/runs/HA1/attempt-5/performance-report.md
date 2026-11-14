Task: HA1 · head 0296059 · Verdict: Pass
Run: static, no Godot run (QA holds the cores); glTF JSON read of arms.glb at 9f3de58 and 0296059 · budget: no baseline yet, judged against docs/CC0_ASSETS.md Size limits and attempt 4 (9f3de58)
Metrics (attempt 4 -> now): file 6,476,164 -> 6,477,008 B (6.18 MB, limit 8 MB, ok, +844 B); materials 4 -> 4 (limit 4, ok); images 9 -> 9 (unchanged); meshes 10 -> 10; index count total 67,400 tris -> 67,400 (sum of all meshes, both looks together; the per-look draw count is lower and was ok in attempt 4, and the mesh data is identical so it cannot have grown); clips 28 -> 28; animation key data (sampler input+output accessor counts) 63,774 -> 63,774 (same shape, only the left-hand finger values changed).
Regressions (> 10 % worse): none
Blocking findings: none
 - No file under game/ changed: no new allocation, node, resource, prewarm or preset path (measured, git diff stat).
 - No mesh, material or image added or changed (measured).
 - tools/blender/arms/ (hold_solve.py, hold_tables.py, sight.py) are build tools, not shipped (judgment).
 - tests/unit/test_ha1_qa3.gd (+1 test, per-finger constants) is test-only CPU vertex loops, not in the game (judgment).
Advisory: none new. Frame times, draw calls and node counts were not measured (no run, no GPU); nothing in this delta touches them.
Unexplained: none
Build thread's note: per-mesh triangle counts, read from both files' glTF JSON, are identical to attempt 4's (Arm 2 x 2,976, GloveKit 2 x 2,824, HandSurface 2 x 13,650, Skin 2 x 13,650, Nails 2 x 600): 38,900 drawn gloved and 34,452 bare, limit 40,000 in either look.

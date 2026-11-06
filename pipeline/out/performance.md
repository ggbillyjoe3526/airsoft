Task: none (BP5 part 3) · head ba2cdb3 · Verdict: Pass
Run: figure_draws.gd (opengl3, xvfb, one figure, 4 distances, both line sets) and merge_cost.gd (6 figure setups), measured; budget: no baseline yet, judged against main (90b0ff4, figure code = cc6cc80)
Draws main → head (visible, measured): human near 32 → 28, far 32 → 21; robot near 25 → 21, far 25 → 18. Matches the coordinator's probe. Primitives unchanged. (Far is less cut than at 3eee4c7 (12 / 14) because the magazine is its own node and each finish is its own surface.)
Setup (measured): first figure setup 27 ms, later ones 10.2-11.2 ms (cache hit; same as 3eee4c7's 25 / 10); made_count 2; 6 figures +2.9 MB static, +120 objects. Judgment: a few hundred ms at match load for a few dozen distinct keys, not in play.
Far paints: held_merge.gd:16 `_far_paints` is keyed by finish (roughness/metallic/specular to 3 decimals, :204-215), so it holds one StandardMaterial3D per distinct finish: a handful, bounded by the paints' finish values, not by the loadouts. Kept for the process on purpose (clear() empties _made and _far only); judgment: fine, a few KB. Nothing allocates per frame: _far_paint runs inside far_version at setup only.
Prewarm: play_session.gd:748 adds HeldMerge.far_materials() to first_use, after the figures are set up (the paints exist by then); this closes the vertex-colour shader first-use advisory from the last review.
Teardown (measured): after queue_free + ReplicaPaint.clear + HeldMerge.clear, made_count 0 and objects 1870 vs 1863 at start (+7, engine lingering, as +5 before).
Body ORM at 1024 instead of 512: about +1 MB VRAM over 3eee4c7's estimate (body_orm ~1.4 MB, so ~4.2 MB saved against 2048 rather than 5.2); total still about 10.5 MB saved (judgment, VRAM-compressed with mips assumed).
Regressions (> 10 % worse): none. Blocking findings: none.
Advisory: _far_paints is not cleared at session end (held_merge.gd:16); intended and bounded, but a test that counts materials across sessions will see the earlier ones.
Unexplained: none
Verdict: Pass

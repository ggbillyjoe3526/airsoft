Task: SM1 · head abe4794 · Verdict: Pass
Run: none (judged by reading df1016c..abe4794; no run, whole suite is busy in this tree; no GPU in the container) · budget: no baseline yet, judged against targets and origin/main
Metrics: not measured this attempt (no node, orphan or memory change expected: no new nodes, no new resources kept). Frame times: reported only, owner's hardware.
Regressions (> 10 % worse): none found (judgment)
Blocking findings: none
 - Per-frame or per-tick work (judgment): none added. mesh(), lining(), faced_boxes(), _train_round() and _round_finish() run once at map build; hide_lamps_in()/leave_out() run once at session build (play_session.gd), not in _process.
 - Build cost (judgment): faced holds ~1,300 AABBs (Subway); lining() calls _flush() once per side per train, a linear scan of faced (trains x sides x 1,300, thousands of compares). _train_round() is a loop over the few trains per drawn face, so about 1,300 x trains box checks. Both are negligible against the mesh build itself. faced_boxes() repeats faces_drawn() (a second pass, tests and tools only).
 - Allocations (judgment): build-time only: the faced array, the flush arrays per side, a lambda in flush.any per candidate cut, one Lining per repainted flush face. All freed with their refs; nothing kept after the build.
 - Lights and shadows (judgment): leave_out() only clears a bit in the existing lamp spot's light_cull_mask, once per hidden lamp. It adds no light, no shadow pass and no shadow caster; cull masks can only drop work (fewer meshes lit by that lamp). No new SpotLight, no change to shadow settings, no preset bypass.
 - Render layer (judgment): the station mesh moves to layer 1<<16 alone, still inside the camera's and default lights' 20-bit masks (bit 17). Same MeshInstance3D count and the same surface; draw calls unchanged. Check that no other light or camera mask in game/ excludes bit 16 (the lamps in the cars are the intended exception); a custom mask there would turn the walls dark.
 - Prewarm (judgment): no new material or particle; the repaint reuses the lining's finish materials, so no new first-use shader.
Advisory:
 - game/play/station/station_surface.gd: faced_boxes() duplicates the faces_drawn() pass of mesh(); reuse the list if it is ever called in the load path. Not needed now.
 - Draw calls and orphan counts of the rendered Subway should be read once on the owner's hardware (F3), since no GPU here.
Fixes: none needed.
Unexplained: none

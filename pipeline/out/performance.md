Task: BP6 menus · head (worktree-agent-a112c05c41620d0ad on 158e93b) · Verdict: Pass
Run: static diff review only (no headless --perf run; check.sh running separately) · budget: no baseline yet, judged against targets and the diff
Metrics: not measured. Regressions: none measured.
Blocking findings: none.
Advisory:
- game/debug/debug_ribbons.gd:83-96 (judgment) end() clears and re-adds one ArrayMesh surface per frame, and hands the engine the whole grown buffer (kept at the busiest frame's size, doubling), not just the used part. Debug-only (F4), arrays reused, no per-frame GDScript allocation, nulls the array refs so writes don't COW-copy. Acceptable. A frame with F4 on and no trails still calls clear_surfaces (cheap).
- debug_ribbons.gd:75 (judgment) stale vertices past _vert_count stay in the buffer; harmless because the indices past the frame's are zeroed.
- game/debug/debug_view.gd set_bb_paths(false): _path_lines.free() frees node + mesh + material (RefCounted, released with it). Off: no leak. Toggling on builds a new ArrayMesh and StandardMaterial3D (not shared, fine for debug).
- game/play/bot_intent_view.gd:_space (judgment) per frame while Bot intentions is on: reuses _order/_placed/_depth, cached Callable _nearer, no new arrays; Rect2 values only. sort_custom of <=~20 bots fine. Dev-only toggle; hidden (no update) when covered.
- game/play/bot_intent_view.gd:71 font.get_string_size only when the intent text changes. Good.
- game/ui/customise_view.gd fit_name: a Callable bind per paint tile at build, not per frame; tiles free with the card, so the connection goes with its emitter. The loop is bounded (size 10..TILE_NAME_SIZE) and only runs on label resize; the override is set only on change, so no resize loop.
- customise_view power cards: the rebuild check no longer allocates a PackedStringArray on a slider refresh. Improvement.
Checked, clean:
- Signal connections: DebugPerf (_ready connect / _exit_tree guarded disconnect), ReplicaTurntable (ENTER_TREE connect guarded by is_connected, EXIT_TREE disconnect), settings_screen size_changed (connect/disconnect pair), armory_dots focus_entered/exited (self-owned), key_binding_list focus_exited.bind (button-owned). No duplicates found.
- Nodes/resources: PlaySession _skip_said created once under skip_layer (freed with it); RetroPixels keeps one ShaderMaterial, set_look only updates uniforms (called from _apply_dev, not per frame), queue_free on off. hud.set_paused only flips visible + redraw-if-changed. StyleBoxEmpty/GameTheme.focus_box are one per instance, built once. FontVariation cache in key names is a static dict keyed by size (bounded).
- Per frame: PlaySession.intents_covered is a few bool/field reads. HUD _cross_drawn is a bool. Minimap on_field is a 2-iteration loop on Vector2s, no allocation; the turntable draws once a change (physics interpolation off).
- ReportScrub RegEx are compiled in _init / once per machine, not per line. SaveFile.touch/remove, RunRecord save_closed run at quit/start only, file handle closed.
- Shader prewarm: no new shader or particle (retro shader already existed). No preset bypass.
Fixes: none required.

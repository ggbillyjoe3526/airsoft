Task: FM1 · head 5166090 · Verdict: Pass
Run: no new run. The bot match has no `--perf` flag in this repo, and `git worktree add` would change the repo. I judged by reading `git diff b9538b4 5166090` plus the existing allocation tests (tools/check.sh passed 3987/3987 and the smoke test). Budget: no baseline yet (pipeline/perf-budget.json does not exist), judged against the targets and against main's code paths.
Metrics: none measured. Everything below is judgment from reading. Frame times are not reportable in the cloud container (no GPU).
Regressions (> 10 % worse): none (judgment). With no Go there order in force, the bot tick adds only the `_given.size()` early-continue loop.

Blocking findings: none.

Checked and clean (judgment):
- Per-frame path while M is held: `hud_field_map.gd` update() to `HudMinimap.fill`/`add_pings` to `View.begin_whole`/`_clear` to `Overlay.place`. It only reuses pooled arrays and Vector2/PackedVector2Array values. The text work (`tr()`, `%`) in update() runs only when the round number changes (hud_field_map.gd:~110). `MapPointer.frame/move/world` allocate nothing.
- Per-frame path while M is not held: update() returns right after the `visible` check (hud_field_map.gd:~97), so the closed map costs a few property reads. `_process` is off unless it is visible, and `_draw` of the backdrop runs only on resize via `_lay_out`.
- Per bot-think tick: `SquadOrderBook.move_arrivals` (squad_order_book.gd:~237) loops over characters (~10) and skips non-MOVE givers at once. A MOVE giver costs one pass over the bots. `SquadOrders.move` for MOVE adds a few compares and one `_arrived_for` call per bot per tick, the same order of cost as HOLD. `give_move` reuses `_order_team` and the insertion sort, and runs once per click.
- Ping path: `nearest_walkable` runs once per click, not per tick. The new PlayerCommand fields are plain values and are copied/reset consistently.
- Freed nodes and resources: HudFieldMap is a child of the HUD, created once in `setup_minimap` (called once, play_session.gd:382), so it is freed with the HUD. `resized.connect(_lay_out)` is a self-signal connected once. `Overlay` and `View` are children. `GameTheme.spaced_font` is cached. The textures are shared with the minimap (`textures()`), not rebuilt.
- Presets: nothing new bypasses the quality presets. There are no new shaders, materials, particles, shadows or post effects, so no prewarm entry is needed.
- Signal connections: none new beyond the one self-connect above.
- Allocation tests: `test_fm1_field_map.gd:317` asserts OBJECT_COUNT is unchanged over 100 open-map frames, and `test_fm1_go_there.gd` covers ticks walking to a Go there. These catch Object allocations only, not Array/String churn, so I also read the code for those. None found.

Advisory (judgment):
1. hud_field_map.gd Overlay._draw (~line 205): while M is held it calls `draw_string_outline` + `draw_string` for each area word on the storey every frame, and `queue_redraw()` every frame in `place`. That is at most 16 words on Depot (14 on Woodland), so up to ~32 text draw calls per frame, only while the map is held. The words only move when the pointer or you move. If it shows on the owner's low preset, cache the shaped text with `TextLine` (or skip the redraw while nothing moved). Check on hardware.
2. hud_minimap.gd View.setup (~line 360): the second View builds its own `GradientTexture2D` disc (64x64) plus capacity-sized arrays, once per match. This is trivial. The disc could be shared, but it is not worth a change.
3. hud_field_map.gd View on a large square: the whole-field texture is drawn with `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` at up to screen size, only while held. At 4K that is a full-screen-class quad with a 0.8 alpha backdrop, so a small fill cost. It needs a rendered check on the owner's hardware (the cloud container has no GPU).

Fixes: none required.
Unexplained: none. No measured metrics exist for this head. If the owner wants numbers, play with M held on Depot at 4K on the Low preset and read F3.

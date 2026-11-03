# Performance report: UF1 (4b10288..f7f819a)

Verdict: **Pass**. No baseline yet (pipeline/perf-budget.json has no lines); judged by reading the diff against the
targets. I did not run the --perf bot match (another process is running the checks); the diff touches UI only.

## Hot paths
- Hud.update (hud.gd ~925-935): adds `board`, `set_covered(board)`, `_middle.visible = ...` per frame. All are bool
  and property sets. `Control.visible` returns early when the value is unchanged, so no redraw or notification. No
  array, string, Callable or node lookup. Pass.
- HudRoundResult.update/set_covered: bool early-out, `visible = false` is a no-op once hidden. The table is refilled
  once on uncover (the `not visible` branch), not per frame. Pass.
- HudMinimap.View._draw (hud_minimap.gd ~527): `Color(1,1,1,opacity_of(self))` is a value type, one get_meta (a
  dictionary lookup) per redraw. No heap allocation. The extra modulate arg to draw_texture_rect/draw_texture costs
  nothing. _draw runs on queue_redraw, which is already per frame in play. Minor: the same get_meta is done in
  backing_on just above, so two lookups per draw. Negligible.
- HudMinimap ring _draw (hud_minimap.gd ~234): one Color and four draw_rect on redraw only. Pass.

## restyle on opacity change
- apply_prefs calls HudStyle.restyle(_replica) and (_minimap) only inside `not is_equal_approx(...)`, so once per
  change, not per frame. Slider drag fires it per step: it walks the subtree (get_children allocates an array per
  node, plus queue_redraw on each) for two small subtrees. Acceptable for a settings interaction. setup_minimap calls
  it once. Pass.

## Node and resource lifetime
- LoadoutSwitch (loadout_switch.gd): built once in LoadoutGear (`_switch = LoadoutSwitch.new(...)`, add_child) and
  freed with its parent. open/close only toggle `visible`, with no per-open instantiate, tween or timer. refresh()
  runs per loadout change (not per frame) and reuses the card, picture and label nodes, with no new nodes. The
  `.bind`/lambda connections are made once at build. No duplicate signal connections found. The old SWAP row's cards
  moved here, so the node count is roughly unchanged. Pass.
- ArmoryDots (armory_dots.gd): draw_arc (32 segments) and a draw_rect for the picked dot, on redraw only, with
  queue_redraw on click. No allocation beyond draw commands. Pass.
- SimAudio: start_ambience loops `_beds` and calls play() only if not playing (idempotent). It is called from
  _ready, `_process` (guarded by `_first_frame_due`, once) and go(). No new players, no leak. Pass.
- NavRail, settings page moves, HudTable size constants: layout only. Pass.

## Not measured
Draw calls and frame times need a rendered run on the owner's hardware. Nothing in the diff adds a draw item per
frame beyond the single ring and picked-dot marks.

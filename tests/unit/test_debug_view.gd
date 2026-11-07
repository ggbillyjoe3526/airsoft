extends GutTest
## The in-world debug draw (game/debug/debug_view.gd): the BB paths and hit areas draw from the simulation's state, cost
## nothing while off, and their keys can't be rebound; the F3 overlay's match line (DebugPerf).

var state: GameState = null
var view: DebugView = null
var cfg: DebugViewConfig = DebugViewConfig.new()
var hits: HitConfig = HitConfig.new()


func before_each() -> void:
	state = GameState.new(4242)
	for i in 4:
		state.characters.append(Character.new(i, i % 2, Vector3(i * 2.0, 0.0, 0.0), 0.0))
	view = DebugView.new()
	view.setup(state, hits, cfg)
	add_child_autofree(view)


func _press(code: Key) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = true
	Input.parse_input_event(k)


func test_nothing_runs_or_exists_while_off() -> void:
	assert_false(view.is_processing())
	assert_eq(view.get_child_count(), 0, "no mesh, no buffers")
	view.on_tick()
	state.bbs.spawn(0, Vector3.ZERO, Vector3.FORWARD, 100.0, 0.0, 0.0002, 0.0)
	view.on_tick()
	assert_eq(view.points_drawn, 0)
	assert_eq(view.shapes_drawn, 0)


func test_switching_a_draw_on_and_off_makes_and_frees_its_mesh() -> void:
	view.set_hit_areas(true)
	assert_true(view.is_processing())
	assert_eq(view.get_child_count(), 1)
	view.set_bb_paths(true)
	assert_eq(view.get_child_count(), 2)
	view.set_hit_areas(false)
	assert_true(view.is_processing(), "the paths still draw")
	view.set_bb_paths(false)
	assert_false(view.is_processing())
	assert_eq(view.get_child_count(), 0)
	view.set_bb_paths(false)
	view.set_hit_areas(false)
	assert_eq(view.get_child_count(), 0, "switching off twice is harmless")


func test_hit_areas_draw_a_volume_for_each_character_in_play() -> void:
	view.set_hit_areas(true)
	await wait_process_frames(2)
	assert_eq(view.shapes_drawn, 4 * HitShapes.SHAPES)
	state.characters[3].status = Character.Status.OUT
	await wait_process_frames(2)
	assert_eq(view.shapes_drawn, 3 * HitShapes.SHAPES, "out of play isn't drawn")
	var lines := view.get_child(0) as DebugLines
	assert_gt(lines.line_count, 0)
	view.viewer_id = 0
	await wait_process_frames(2)
	assert_eq(view.shapes_drawn, 2 * HitShapes.SHAPES, "not the one whose eyes you see through")


func test_a_volume_draws_the_shapes_the_sim_builds() -> void:
	var lines := DebugLines.new()
	add_child_autofree(lines)
	var v := Hitbox.Volume.new()
	Hitbox.build_volume(state.characters[0], hits, v)
	lines.begin()
	var n := HitShapes.draw_volume(lines, v, Color.WHITE, cfg)
	lines.end()
	assert_eq(n, Hitbox.PART_COUNT + 1)
	# The head is a sphere: a ring and two half circles in two planes; a capsule adds a second ring and four sides.
	var sphere := cfg.ring_segments + 4 * cfg.arc_segments
	var capsule := 2 * cfg.ring_segments + 4 + 4 * cfg.arc_segments
	assert_gte(lines.line_count, sphere + Hitbox.PART_COUNT * sphere)
	assert_lte(lines.line_count, sphere + Hitbox.PART_COUNT * capsule)


func test_bb_paths_show_the_trail_of_each_live_bb() -> void:
	view.set_bb_paths(true)
	var bb := state.bbs.spawn(0, Vector3(0, 1, 0), Vector3.FORWARD, 100.0, 0.0, 0.0002, 0.0)
	for i in 5:
		bb.position = Vector3(0, 1, -i)
		view.on_tick()
	await wait_process_frames(2)
	assert_eq(view.points_drawn, 5)
	bb.active = false
	view.on_tick()
	await wait_process_frames(2)
	assert_eq(view.points_drawn, 0, "a dead BB's trail is gone")


func test_a_trail_is_as_long_as_the_config_says() -> void:
	cfg.trail_seconds = 0.5
	cfg.trail_rate = 10
	view.set_bb_paths(true)
	var bb := state.bbs.spawn(0, Vector3.ZERO, Vector3.FORWARD, 100.0, 0.0, 0.0002, 0.0)
	for i in 12:
		bb.position = Vector3(i, 0, 0)
		view.on_tick()
	await wait_process_frames(2)
	assert_eq(view.points_drawn, 5)


func test_f4_and_f5_toggle_the_draws() -> void:
	_press(KEY_F4)
	await wait_process_frames(2)
	assert_true(view.bb_paths_on())
	assert_false(view.hit_areas_on())
	_press(KEY_F5)
	await wait_process_frames(2)
	assert_true(view.hit_areas_on())
	_press(KEY_F4)
	await wait_process_frames(2)
	assert_false(view.bb_paths_on())


func test_the_debug_keys_cannot_be_rebound() -> void:
	var seen := 0
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("debug_"):
			continue
		for e: InputEvent in InputMap.action_get_events(action):
			seen += 1
			var code := KeyBindings.code_of_event(e)
			assert_true(KeyBindings.UNBINDABLE.has(code), "%s is reserved" % action)
			assert_false(KeyBindings.bindable(code))
			assert_eq(KeyBindings.new().rebind(&"jump", code), KeyBindings.Result.REFUSED_KEY)
		assert_false(KeyBindings.ACTIONS.has(action), "%s isn't on the settings screen" % action)
	assert_eq(seen, 2, "F4 and F5")


func test_the_overlay_line_shows_seed_position_and_entities() -> void:
	var play := PlaySession.new()
	play.autopilot = true
	play.match_seed = 4242
	add_child_autofree(play)
	await wait_physics_frames(2)
	var perf := DebugPerf.new()
	add_child_autofree(perf)
	assert_eq(perf.match_line(), "", "no match watched")
	perf.watch(play)
	var at := play.player_position()
	var line := perf.match_line()
	assert_string_contains(line, "Seed 4242")
	assert_string_contains(line, "pos %.2f %.2f %.2f" % [at.x, at.y, at.z])
	assert_string_contains(line, "entities %d" % (play.state.characters.size() + play.state.bbs.active_count()))
	perf.watch(null)
	assert_eq(perf.match_line(), "")
	# BP6: the overlay sits bottom left, never over the minimap and its caption top left
	perf.watch(play)
	perf.toggle()
	assert_gt(perf.plate_rect().position.y, 0.0, "seated as it shows, not top left until a refresh")
	await wait_seconds(DebugPerf.REFRESH + 0.2)
	var screen := perf.get_viewport().get_visible_rect().size
	var plate := perf.plate_rect()
	assert_gt(plate.size.y, 0.0, "drawn")
	assert_almost_eq(plate.end.y, screen.y - DebugPerf.CORNER.y, 0.5, "its foot on the screen's bottom edge")
	assert_gt(plate.position.y, screen.y * 0.5, "the lower half, clear of the minimap")
	perf.watch(null)


## BP6: the trails are ribbons, as wide on screen near and far, a quad (two triangles) a segment.
func test_bb_paths_are_ribbons_of_a_fixed_screen_width() -> void:
	view.set_bb_paths(true)
	var bb := state.bbs.spawn(0, Vector3(0, 1, 0), Vector3.FORWARD, 100.0, 0.0, 0.0002, 0.0)
	for i in 5:
		bb.position = Vector3(0, 1, -i * 10.0)
		view.on_tick()
	await wait_process_frames(2)
	var ribbons := view.get_child(0) as DebugRibbons
	assert_eq(ribbons.segment_count, 4)
	var arrays := (ribbons.mesh as ArrayMesh).surface_get_arrays(0)
	assert_eq((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 4 * 6)
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var near := verts[0].distance_to(verts[1])
	var far := verts[8].distance_to(verts[9])
	assert_gt(near, 0.0)
	assert_almost_eq(far / near, 41.0 / 1.0, 41.0 * 0.05, "width grows with distance from the eye: a fixed width on screen")


## The ribbons' kept arrays go over whole each frame: a frame with fewer segments than the last leaves the rest of the
## indices zero, triangles with no area, and makes no arrays of its own.
func test_ribbons_hand_over_their_kept_arrays_with_a_tail_that_draws_nothing() -> void:
	var trails := BBTrails.new(2, 8)
	for slot in 2:
		for k in 5:
			trails._points[slot * 8 + k] = Vector3(slot, 1.0, -k)
		trails._count[slot] = 5
		trails._head[slot] = 5
	var r := DebugRibbons.new()
	add_child_autofree(r)
	r.begin(null, 3.0)
	r.strip(trails, 0, Color.WHITE, Color.WHITE)
	r.strip(trails, 1, Color.WHITE, Color.WHITE)
	r.end()
	r.begin(null, 3.0)
	r.strip(trails, 0, Color.WHITE, Color.WHITE)
	r.end()
	assert_eq(r.segment_count, 4)
	var idx := (r.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array
	assert_eq(idx.size(), 2 * 4 * 6, "the busiest frame's arrays, whole")
	var drawn := 0
	for t in idx.size() / 3:
		if idx[t * 3] != idx[t * 3 + 1] or idx[t * 3 + 1] != idx[t * 3 + 2]:
			drawn += 1
	assert_eq(drawn, 4 * 2, "two triangles a segment of this frame's, the rest draw nothing")

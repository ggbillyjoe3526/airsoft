extends GutTest
## QA for FM2 (the detailed full-screen map): what the worker's tests leave out. A screen shrunk to nothing, the pointer's
## mapping on a room that isn't square, a map with one flag / no overtime flag / an end with no spawns, practice, the
## half-time swap through the real round code, storeys and the area words, marks that keep clear of each other, the
## minimap's rim pins, the key's rows and words, and nothing leaking across many opens and resizes.

var cfg: MinimapConfig = null
var teams: TeamConfig = null
var state: GameState = null
var heard: MinimapHearing = null
var you: Character = null
var mate: Character = null
var enemy: Character = null
var pointer: MapPointer = null
var root: Control = null


func before_each() -> void:
	cfg = MinimapConfig.new()
	teams = TeamConfig.new()
	state = GameState.new(5)
	var kit: Array[ReplicaConfig] = [ReplicaConfig.new()]
	you = Character.new(0, 0, Vector3(-10.0, 0.0, 1.5), 0.0, kit)
	mate = Character.new(1, 0, Vector3(-3.5, 0.0, -3.5), 0.0, kit)
	enemy = Character.new(2, 1, Vector3(3.0, 0.0, -4.0), 0.0, kit)
	enemy.end = 1
	for c: Character in [you, mate, enemy]:
		state.characters.append(c)
		c.prev_position = c.position
	heard = MinimapHearing.new(cfg)
	heard.on_tick(state, you)
	pointer = MapPointer.new()


func _load(id: String) -> MapData:
	return MapData.load_map(id, MapStyle.new(), 2)


func _field_map(map: MapData, screen: Vector2 = Vector2(1920.0, 1080.0)) -> HudFieldMap:
	root = Control.new()
	root.size = screen
	add_child_autofree(root)
	var mm := HudMinimap.new()
	root.add_child(mm)
	mm.setup(cfg, teams, map, heard, map.display_name, state.characters.size(), Vector2(32.0, 26.0))
	var fm := HudFieldMap.new()
	root.add_child(fm)
	fm.setup(cfg, mm, map, map.display_name, state.characters.size(), 8.0, 2.0)
	return fm


func _show(fm: HudFieldMap, pointing: bool = true) -> void:
	if not pointer.open:
		pointer.start()
	fm.update(state, you, 0.0, 1.0, false, Vector3.ZERO, null, pointer, pointing, false)


func _attack_defend(attackers: int) -> void:
	state.round_state.mode = RoundState.Mode.ATTACK_DEFEND
	state.round_state.attackers = attackers


# --- a screen shrunk to nothing ---

func test_a_screen_shrunk_to_nothing_still_draws_without_a_broken_pointer_or_negative_room() -> void:
	var fm := _field_map(_load("depot"))
	_attack_defend(0)
	for s: Vector2 in [Vector2(640.0, 360.0), Vector2(300.0, 200.0), Vector2(120.0, 90.0), Vector2(1.0, 1.0),
			Vector2.ZERO, Vector2(1920.0, 1080.0)]:
		root.size = s
		_show(fm)
		var v := fm.view()
		assert_true(v.size.x >= 0.0 and v.size.y >= 0.0, "room %s" % s)
		assert_true(is_finite(v.px_per_m()) and v.px_per_m() >= 0.0, "ppm %s" % s)
		assert_true(pointer.at.is_finite(), "pointer %s" % s)
		assert_true(pointer.at.abs().x <= pointer.half.x + 0.001 and pointer.at.abs().y <= pointer.half.y + 0.001,
				"pointer inside the panel %s" % s)
		assert_true(pointer.world().is_finite(), "world %s" % s)
		var key: FieldMapKey = null
		for c in fm.get_children():
			if c is FieldMapKey:
				key = c
		assert_lte(key.size.x, maxf(s.x - cfg.map_margin * 2.0, 0.0) * 0.3 + 0.001, "key never over 30%% of %s" % s)
		assert_lte(key.position.x + key.size.x, maxf(s.x - cfg.map_margin, cfg.map_margin) + 0.001, "key on screen")


func test_a_screen_with_no_room_for_the_field_holds_the_pointer_in_the_middle_and_is_not_framed() -> void:
	var fm := _field_map(_load("depot"))
	root.size = Vector2(100.0, 100.0)
	_show(fm)
	assert_false(pointer.framed(), "no room, no panel to point on")
	assert_eq(pointer.at, Vector2.ZERO)


# --- the pointer on a room that isn't square ---

func test_the_pointer_maps_the_field_s_corners_back_to_the_world_on_every_map() -> void:
	for id: String in ["depot", "woodland", "street"]:
		var map := _load(id)
		var fm := _field_map(map)
		_show(fm)
		var v := fm.view()
		var field := fm.get_parent().get_child(0) as HudMinimap
		var f := field.field()
		var origin := f.origin
		var size := v.field_size()
		for corner: Vector2 in [origin, origin + size, origin + Vector2(size.x, 0.0), origin + Vector2(0.0, size.y)]:
			pointer.at = v.panel_of(corner)
			var w := pointer.world()
			assert_almost_eq(w.x, corner.x, 0.05, "%s x" % id)
			assert_almost_eq(w.z, corner.y, 0.05, "%s z" % id)
		# And it can't leave the room.
		pointer.move(Vector2(1.0e6, 1.0e6))
		assert_eq(pointer.at, v.size * 0.5, "%s: clamped at the room's far corner" % id)
		pointer.move(Vector2(-2.0e6, -2.0e6))
		assert_eq(pointer.at, v.size * -0.5, "%s: and the near" % id)
		pointer.close()


func test_the_pointer_starts_on_you_wherever_you_stand_on_a_wide_room() -> void:
	var map := _load("woodland")
	var fm := _field_map(map, Vector2(2560.0, 1080.0))
	you.position = Vector3(20.0, 0.0, -15.0)
	you.prev_position = you.position
	_show(fm)
	var w := pointer.world()
	assert_almost_eq(w.x, 20.0, 0.05)
	assert_almost_eq(w.z, -15.0, 0.05)


func test_a_pointer_in_the_room_outside_the_field_still_gives_a_finite_point() -> void:
	var fm := _field_map(_load("depot"))
	_show(fm)
	pointer.move(Vector2(1.0e5, 1.0e5))
	assert_true(pointer.world().is_finite())


# --- the minimap's rim pins on the square panel ---

func test_the_rim_pin_keeps_a_far_mark_on_the_square_panel_s_edge_in_its_direction() -> void:
	var v := HudMinimap.View.new()
	v.setup(cfg, [] as Array[Texture2D], 1.0, Vector2.ZERO, 4)
	v.size = Vector2(200.0, 200.0)
	add_child_autofree(v)
	v.begin(Vector2.ZERO, 0, 0.0, false, Color.WHITE, Color.WHITE)
	var p := v._pin(Vector2(500.0, 100.0), 10.0)
	assert_almost_eq(maxf(absf(p.x), absf(p.y)), 90.0, 0.001, "pad px inside the edge")
	assert_almost_eq(p.y / p.x, 0.2, 0.0001, "direction kept")
	assert_eq(v._pin(Vector2(30.0, -40.0), 10.0), Vector2(30.0, -40.0), "inside stays")
	assert_false(v._off(Vector2(100.0, -100.0)))
	assert_true(v._off(Vector2(100.1, 0.0)))


func test_the_rim_pin_on_a_wide_panel_stops_at_each_axis_own_edge() -> void:
	var v := HudMinimap.View.new()
	v.setup(cfg, [] as Array[Texture2D], 1.0, Vector2.ZERO, 4)
	v.size = Vector2(400.0, 100.0)
	add_child_autofree(v)
	v.begin(Vector2.ZERO, 0, 0.0, false, Color.WHITE, Color.WHITE)
	var p := v._pin(Vector2(0.0, 900.0), 10.0)
	assert_almost_eq(p.y, 40.0, 0.001, "short axis at its own edge")
	p = v._pin(Vector2(900.0, 0.0), 10.0)
	assert_almost_eq(p.x, 190.0, 0.001, "long axis at its own edge")
	assert_true(v._pin(Vector2(1.0e9, -1.0e9), 10.0).is_finite())


# --- marks of a map with less than Depot's ---

func test_a_map_with_one_flag_no_overtime_flag_and_an_end_without_spawns_still_draws() -> void:
	var map := _load("depot")
	var one := PackedVector3Array()
	one.append(map.poles[0])
	map.poles = one
	map.has_overtime_flag = false
	map.ends[1].spawns.clear()
	map.ends[1].dead_zone.clear()
	var fm := _field_map(map)
	_attack_defend(0)
	_show(fm)
	var ov := fm.overlay()
	assert_eq(ov._flags_px.size(), 1)
	assert_eq(fm.goal_text(), "You attack: raise the flag", "one flag has no letters to list")
	assert_false(ov._starts_px[1].has_area(), "no start box for an end with no spawns")
	assert_false(ov._dead_px[1].has_area())
	state.round_state.mode = RoundState.Mode.ELIMINATION
	state.round_state.attackers = -1
	_show(fm)
	assert_false(fm.overlay()._marks.has_overtime)
	ov.queue_redraw()
	await wait_physics_frames(2)
	assert_true(fm.visible)


func test_a_map_with_no_flag_at_all_does_not_break_attack_defend() -> void:
	var map := _load("depot")
	map.poles = PackedVector3Array()
	var fm := _field_map(map)
	_attack_defend(1)
	_show(fm)
	assert_eq(fm.overlay()._flags_px.size(), 0)
	assert_eq(fm.goal_text(), "You defend: hold the flag until time runs out")
	await wait_physics_frames(2)
	assert_true(fm.visible)


# --- practice ---

func test_practice_shows_no_flags_no_overtime_spot_and_says_practice() -> void:
	var fm := _field_map(_load("depot"))
	_attack_defend(0)
	state.round_state.practice = true
	_show(fm)
	var ov := fm.overlay()
	assert_false(ov._flags_on)
	assert_false(ov._overtime_on)
	assert_eq(fm.sub_text(), "Practice")
	assert_eq(fm.goal_text(), "")
	await wait_physics_frames(2)


# --- teams swap ends through the real round code ---

func test_attack_defend_after_half_time_puts_the_new_attackers_colour_at_end_zero_and_flips_your_goal() -> void:
	var map := _load("depot")
	var fm := _field_map(map)
	var tuning := SimTuning.load_default()
	var rs := state.round_state
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	rs.first_attackers = 0
	rs.number = 1
	rs.attackers = Round.attackers_in_round(1, tuning.rounds, 0)
	Round.place_teams(rs, state.characters, map.ends, tuning)
	_show(fm)
	var ov := fm.overlay()
	assert_eq(ov._end_colours[0], teams.colours[0], "Alpha attacks from end 0 in round 1")
	assert_string_contains(fm.goal_text(), "You attack")
	rs.number = tuning.rounds.half_time_after + 1
	rs.attackers = Round.attackers_in_round(rs.number, tuning.rounds, 0)
	Round.place_teams(rs, state.characters, map.ends, tuning)
	_show(fm)
	assert_eq(ov._end_colours[0], teams.colours[1], "Beta attacks from end 0 after half time")
	assert_eq(ov._end_colours[1], teams.colours[0])
	assert_eq(ov._end_words[1], "ALPHA START")
	assert_string_contains(fm.goal_text(), "You defend")


func test_a_drawn_round_replayed_under_the_same_number_keeps_the_header() -> void:
	var fm := _field_map(_load("depot"))
	_attack_defend(0)
	state.round_state.number = 3
	_show(fm)
	var s := fm.sub_text()
	_show(fm)
	assert_eq(fm.sub_text(), s)
	assert_eq(s, "Round 3  ·  Attack / Defend")


# --- storeys and the area words ---

func test_tower_block_shows_the_words_of_the_storey_you_stand_on_and_none_cover_another() -> void:
	var map := TowerBlock.load_map(MapStyle.new(), 1)
	assert_true(map.ok())
	var fm := _field_map(map)
	var seen: Array[PackedStringArray] = []
	for y: float in [0.0, 3.0, 6.0]:
		you.position = Vector3(0.0, y, 0.0)
		you.prev_position = you.position
		_show(fm)
		var ov := fm.overlay()
		seen.append(fm.area_words())
		var boxes: Array[Rect2] = []
		for i in ov._word_boxes.size():
			var b := ov.word_box(i)
			if b.has_area():
				boxes.append(b)
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				assert_false(boxes[i].intersects(boxes[j]), "y=%s: %d over %d" % [y, i, j])
	assert_true(seen[0] != seen[1] or seen[1] != seen[2], "the storeys do not all say the same words")


func test_a_word_is_never_left_where_its_floor_band_is_not_the_storey_shown() -> void:
	var map := TowerBlock.load_map(MapStyle.new(), 1)
	var fm := _field_map(map)
	you.position = Vector3(0.0, 3.0, 0.0)
	you.prev_position = you.position
	_show(fm)
	var ov := fm.overlay()
	var feet := ov.storey_floor + cfg.storey_pick
	for i in ov._word_boxes.size():
		if ov.word_box(i).has_area():
			var w := ov._marks.words[i]
			assert_true(feet >= w.floor_from and feet < w.floor_to, w.name)


# --- marks keep clear of each other ---

func test_words_keep_inside_the_field_and_clear_of_starts_dead_zones_flags_and_the_scale() -> void:
	for id: String in ["depot", "woodland", "street"]:
		var fm := _field_map(_load(id))
		_attack_defend(0)
		_show(fm)
		var ov := fm.overlay()
		for i in ov._word_boxes.size():
			var b := ov.word_box(i)
			if not b.has_area():
				continue
			assert_true(ov._field_px.grow(0.5).encloses(b), "%s: %s inside the field" % [id, ov._marks.words[i].name])
			for r: Rect2 in ov._starts_px:
				assert_false(r.has_area() and r.intersects(b), "%s: %s over a start" % [id, ov._marks.words[i].name])
			for r: Rect2 in ov._dead_px:
				assert_false(r.has_area() and r.intersects(b), "%s: %s over a dead zone" % [id, ov._marks.words[i].name])
			for p in ov._flags_px:
				assert_false(ov._badge_box(p).intersects(b) or ov._ring_box(p).intersects(b), "%s: over a flag" % id)
		assert_gt(fm.area_words().size(), 0, "%s: some words stay" % id)


func test_lay_out_never_overlaps_or_leaves_the_bounds_for_random_words() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261101
	for round_i in 40:
		var bounds := Rect2(Vector2(rng.randf_range(-50.0, 50.0), rng.randf_range(-50.0, 50.0)),
				Vector2(rng.randf_range(80.0, 900.0), rng.randf_range(40.0, 600.0)))
		var wants: Array[Rect2] = []
		var blocked: Array[Rect2] = []
		for i in rng.randi_range(0, 40):
			wants.append(Rect2(bounds.position + Vector2(rng.randf() * bounds.size.x, rng.randf() * bounds.size.y),
					Vector2(rng.randf_range(10.0, 120.0), rng.randf_range(8.0, 22.0))))
		for i in rng.randi_range(0, 6):
			blocked.append(Rect2(bounds.position + Vector2(rng.randf() * bounds.size.x, rng.randf() * bounds.size.y),
					Vector2(rng.randf_range(5.0, 90.0), rng.randf_range(5.0, 90.0))))
		var got := FieldMapMarks.lay_out(wants, blocked, bounds, 3.0)
		assert_eq(got.size(), wants.size())
		var placed: Array[Rect2] = []
		for i in got.size():
			if not got[i].has_area():
				continue
			assert_eq(got[i].size, wants[i].size)
			if wants[i].size.x <= bounds.size.x and wants[i].size.y <= bounds.size.y:
				assert_true(bounds.grow(0.001).encloses(got[i]), "inside the bounds")
			for o in placed:
				assert_false(got[i].grow(3.0).intersects(o), "gap kept")
			for b in blocked:
				assert_false(got[i].intersects(b), "clear of what is blocked")
			placed.append(got[i])


func test_lay_out_with_a_word_wider_than_the_bounds_does_not_crash_or_hang() -> void:
	var wants: Array[Rect2] = [Rect2(Vector2(5.0, 5.0), Vector2(500.0, 20.0)), Rect2(Vector2(5.0, 5.0), Vector2(500.0, 20.0))]
	var got := FieldMapMarks.lay_out(wants, [] as Array[Rect2], Rect2(Vector2.ZERO, Vector2(50.0, 50.0)), 3.0)
	assert_eq(got.size(), 2)
	assert_false(got[0].has_area() and got[1].has_area() and got[0].intersects(got[1]))


func test_dead_zone_hatch_covers_the_zone_on_every_map() -> void:
	# The hatch is capped at HATCH_MOST lines; a zone so big that the cap runs out leaves its far corner bare.
	for id: String in ["depot", "woodland", "street"]:
		var fm := _field_map(_load(id))
		_show(fm)
		var ov := fm.overlay()
		for r in ov._dead_px:
			if r.has_area():
				var needed := (r.size.x + r.size.y) / cfg.map_dead_hatch
				assert_lte(needed, float(FieldMapOverlay.HATCH_MOST), "%s: a dead zone %s needs %.0f lines" % [id, r.size, needed])


# --- the key and the words ---

func test_every_key_row_has_a_word_and_every_word_is_translated() -> void:
	assert_eq(FieldMapKey.ROWS.size(), FieldMapKey.WORDS.size())
	for w in FieldMapKey.WORDS:
		assert_ne(tr(w), w, "%s has text" % w)
	for k: String in ["MAP_GOAL_ATTACK", "MAP_GOAL_ATTACK_ONE", "MAP_GOAL_DEFEND", "MAP_GOAL_DEFEND_ONE",
			"MAP_GOAL_ELIMINATION", "MAP_GOAL_OVERTIME", "MAP_START", "MAP_DEAD_ZONE", "MAP_NORTH", "MAP_SCALE", "MAP_KEY"]:
		assert_ne(tr(k), k, k)


func test_the_key_fits_the_room_at_the_smallest_screen_the_game_runs_at() -> void:
	# canvas_items + expand: the smallest virtual screen is 1920 x 1080.
	var fm := _field_map(_load("depot"))
	_show(fm)
	var key: FieldMapKey = null
	for c in fm.get_children():
		if c is FieldMapKey:
			key = c
	assert_almost_eq(key.size.y, key.needed_height(), 0.01, "all rows fit")


# --- what an open map leaves behind ---

func test_opening_and_closing_the_map_and_resizing_many_times_leaks_nothing() -> void:
	var fm := _field_map(_load("woodland"))
	_attack_defend(0)
	for i in 3:
		_show(fm)
		pointer.close()
		_show(fm)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 60:
		root.size = Vector2(1920.0 + float(i % 7) * 40.0, 1080.0 + float(i % 5) * 30.0)
		_show(fm)
		pointer.close()
		fm.update(state, you, 0.0, 1.0, false, Vector3.ZERO, null, pointer, true, false)
		pointer.start()
	_show(fm)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node added")
	assert_lte(Performance.get_monitor(Performance.OBJECT_COUNT), before + 4.0, "no growth by resize and reopen")


func test_a_frame_of_the_open_map_allocates_nothing_on_depot_and_woodland_with_a_ping_and_a_heard_enemy() -> void:
	for id: String in ["depot", "woodland"]:
		var fm := _field_map(_load(id))
		_attack_defend(0)
		var patch := heard.patch_of(enemy.id)
		if patch != null:
			patch.heard_at = heard.time
		for i in 5:
			_show(fm)
		var before := Performance.get_monitor(Performance.OBJECT_COUNT)
		for i in 100:
			pointer.move(Vector2(-1.0, 0.7))
			_show(fm, i % 2 == 0)
		assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before, id)
		pointer.close()


func test_the_other_team_is_not_marked_where_it_was_not_heard() -> void:
	var fm := _field_map(_load("depot"))
	_show(fm)
	var v := fm.view()
	assert_eq(v._patch_count, 0, "nobody heard, no patch")
	assert_eq(v._dot_count, 1, "your teammate only")


# --- the zone words and the compass ---

func test_the_start_and_dead_zone_words_do_not_cover_each_other_or_the_compass_on_any_map() -> void:
	for id: String in ["depot", "woodland", "street"]:
		var fm := _field_map(_load(id))
		_show(fm)
		var ov := fm.overlay()
		var words: Array[Rect2] = []
		var names: Array[String] = []
		for i in ov._starts_px.size():
			if ov._starts_px[i].has_area():
				words.append(ov._start_words[i])
				names.append("start %d" % i)
			if ov._dead_px[i].has_area():
				words.append(ov._dead_words[i])
				names.append("dead %d" % i)
		for i in words.size():
			assert_true(Rect2(Vector2.ZERO, ov.size).encloses(words[i]), "%s: %s word on the screen" % [id, names[i]])
			for j in range(i + 1, words.size()):
				assert_false(words[i].intersects(words[j]), "%s: %s word over %s word" % [id, names[i], names[j]])
		var compass := Rect2(ov._bar - Vector2(0.0, FieldMapOverlay.COMPASS_LENGTH + FieldMapOverlay.TICK),
				Vector2(maxf(ov._bar_px, 14.0), FieldMapOverlay.COMPASS_LENGTH + FieldMapOverlay.TICK))
		for i in ov._starts_px.size():
			assert_false(ov._starts_px[i].intersects(compass), "%s: start %d under the compass" % [id, i])
			assert_false(ov._dead_px[i].intersects(compass), "%s: dead zone %d under the compass" % [id, i])


func test_ultra_wide_and_tall_windows_keep_the_field_the_pointer_and_the_words_in_step() -> void:
	for s: Vector2 in [Vector2(3440.0, 1080.0), Vector2(1920.0, 3400.0), Vector2(2560.0, 1080.0)]:
		var fm := _field_map(_load("street"), s)
		_attack_defend(0)
		_show(fm)
		var v := fm.view()
		var span := v.field_size() * v.px_per_m()
		assert_lte(span.x, v.size.x + 0.5, "%s wide" % s)
		assert_lte(span.y, v.size.y + 0.5, "%s tall" % s)
		var ov := fm.overlay()
		assert_eq(ov.size, v.size)
		for i in ov._word_boxes.size():
			if ov.word_box(i).has_area():
				assert_true(ov._field_px.grow(0.5).encloses(ov.word_box(i)), "%s: a word off the field" % s)
		pointer.at = v.panel_of(v.centre())
		assert_almost_eq(pointer.world().x, v.centre().x, 0.05)
		assert_almost_eq(pointer.world().z, v.centre().y, 0.05)
		pointer.close()

extends GutTest
## The practice range drawn and heard (game/play/range_targets_view.gd, range_view.gd and the range's part of
## sim_audio.gd; RANGE_VISUALS, M21 and M93): every target built where the simulation has it, figures falling and rising,
## plates swinging when hit, a mover's trolley and a swinger's arm following their clocks, lit targets glowing, the START
## plate shown only while it waits; the floor lines and wall boards at each marked distance; steel ringing far, a figure
## knocking, your own hit's confirmation, and the challenge's beeps.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var cfg: RangeViewConfig = RangeViewConfig.new()
var specs: Array[RangeTarget.Spec] = []


func before_all() -> void:
	specs = MapData.load_map("range", MapStyle.new(), 1).targets


func _view(targets: Array[RangeTarget]) -> RangeTargetsView:
	var v := RangeTargetsView.new()
	add_child_autofree(v)
	v.setup(targets, cfg, tuning, GameTheme.font(800))
	return v


func _first(targets: Array[RangeTarget], motion: RangeTarget.Motion, kind: RangeTarget.Kind) -> RangeTarget:
	for t in targets:
		if t.motion == motion and t.kind == kind and not t.start and not t.crouched:
			return t
	return null


func _small(targets: Array[RangeTarget]) -> RangeTarget:
	for t in targets:
		if t.kind == RangeTarget.Kind.STEEL and t.radius < tuning.targets.plate_radius and not t.start:
			return t
	return null


func _start(targets: Array[RangeTarget]) -> RangeTarget:
	for t in targets:
		if t.start:
			return t
	return null


func test_every_target_is_built_at_its_home_facing_its_way() -> void:
	var targets := RangeTargets.create(specs, tuning)
	var v := _view(targets)
	assert_eq(v._drawn.size(), targets.size())
	for i in targets.size():
		var root := v._drawn[i].root
		assert_almost_eq(root.position, Vector3(targets[i].home.x, targets[i].floor_y, targets[i].home.z),
				Vector3.ONE * 1e-5)
		# Its local +z is the way it faces.
		assert_almost_eq(root.basis.z, Vector3(targets[i].face_x, 0.0, targets[i].face_z), Vector3.ONE * 1e-5)


func test_a_plate_hangs_with_its_face_where_the_simulation_rings_it() -> void:
	var targets := RangeTargets.create(specs, tuning)
	var v := _view(targets)
	for plate: RangeTarget in [_first(targets, RangeTarget.Motion.STILL, RangeTarget.Kind.STEEL), _small(targets)]:
		var d := v._drawn[plate.id]
		var disc := d.faces[0]
		assert_almost_eq(disc.global_position, plate.position, Vector3.ONE * 1e-4, "its face's middle")
		var drawn := disc.global_transform * disc.mesh.get_aabb()
		assert_almost_eq(drawn.size.x * 0.5, plate.radius, 1e-3, "the plate's radius")
		assert_almost_eq(drawn.size.y * 0.5, plate.radius, 1e-3)
		assert_almost_eq(drawn.end.z, plate.position.z, 1e-4, "its front through the simulation's plate")


func test_a_figure_is_the_size_of_its_hit_volume() -> void:
	var targets := RangeTargets.create(specs, tuning)
	var v := _view(targets)
	var hits := tuning.hits
	for crouched: bool in [false, true]:
		var figure: RangeTarget = null
		for t in targets:
			if t.kind == RangeTarget.Kind.FIGURE and t.motion == RangeTarget.Motion.STILL and t.crouched == crouched:
				figure = t
				break
		var peg := v._drawn[figure.id].faces[0]
		var drawn := peg.global_transform * peg.mesh.get_aabb()
		var feet := figure.floor_y + tuning.body.rest_gap
		var drop := hits.crouch_drop if crouched else 0.0
		assert_almost_eq(drawn.end.y, figure.volume.head.a.y + hits.head_radius, 2e-3, "the head's top on the head's")
		assert_almost_eq(drawn.end.y, feet + hits.head_height - drop + hits.head_radius, 2e-3)
		assert_between(drawn.position.y, figure.floor_y, feet, "on its hinge plate (the hinge's knuckle a little lower)")
		var middle := drawn.get_center()
		assert_almost_eq(Vector2(middle.x, middle.z), Vector2(figure.home.x, figure.home.z), Vector2.ONE * 0.04,
				"round the hit volume's middle (a flat board, its hinge leaf just behind)")
		assert_lt(peg.mesh.get_aabb().size.z, 0.08, "flat: a plywood cut-out, not a turned peg")
		assert_between(drawn.size.x, hits.body_radius * 2.0 - 0.01, hits.body_radius * 2.0 + 0.05,
				"as wide as the body's (a crouched peg's foot a little wider: a crouch's knees)")


func test_a_figure_falls_back_lies_and_rises() -> void:
	var t := RangeTarget.new()
	var range_cfg := tuning.targets
	assert_eq(RangeTargetsView.fall_angle(t, cfg, range_cfg), 0.0, "standing")
	RangeTargets.knock_down(t, range_cfg.figure_down_time)
	t.down -= cfg.fall_time * 0.5
	assert_almost_eq(RangeTargetsView.fall_angle(t, cfg, range_cfg), cfg.down_angle * 0.5, 1e-5, "half fallen")
	t.down = range_cfg.figure_down_time * 0.5
	assert_almost_eq(RangeTargetsView.fall_angle(t, cfg, range_cfg), cfg.down_angle, 1e-6, "flat")
	t.down = range_cfg.rise_time * 0.5
	assert_almost_eq(RangeTargetsView.fall_angle(t, cfg, range_cfg), cfg.down_angle * 0.5, 1e-5, "rising")


func test_a_hit_figure_tips_back_away_from_the_line() -> void:
	var targets := RangeTargets.create(specs, tuning)
	var v := _view(targets)
	var figure := _first(targets, RangeTarget.Motion.STILL, RangeTarget.Kind.FIGURE)
	RangeTargets.knock_down(figure, tuning.targets.figure_down_time)
	figure.down -= cfg.fall_time
	v.update(targets, 0.0, DT)
	var peg := v._drawn[figure.id].faces[0]
	var aabb := peg.mesh.get_aabb()
	var crown := peg.global_transform * Vector3(aabb.get_center().x, aabb.end.y, aabb.get_center().z)
	var back := (crown - v._drawn[figure.id].root.global_position).dot(v._drawn[figure.id].root.global_basis.z)
	assert_lt(back, -1.0, "the head lies well behind the hinge")
	assert_gt(crown.y, figure.floor_y, "and above the ground")


func test_a_hit_plate_swings_back_and_settles() -> void:
	var targets := RangeTargets.create(specs, tuning)
	var v := _view(targets)
	var plate := _first(targets, RangeTarget.Motion.STILL, RangeTarget.Kind.STEEL)
	var state := GameState.new(1)
	var e := state.events.add(GameEvent.Kind.TARGET_HIT)
	e.target = plate.id
	e.value = RangeTarget.Kind.STEEL
	v.on_tick(state)
	var pivot := v._drawn[plate.id].pivot
	v.update(targets, 0.0, DT * 4.0)
	assert_gt(pivot.rotation.x, 0.0, "the bottom swings away from the line")
	for i in 120:
		v.update(targets, 0.0, DT)
	assert_eq(pivot.rotation.x, 0.0, "still again")


func test_a_mover_rides_its_track_and_a_swinger_swings_with_its_clock() -> void:
	var targets := RangeTargets.create(specs, tuning)
	var v := _view(targets)
	var mover := _first(targets, RangeTarget.Motion.MOVER, RangeTarget.Kind.FIGURE)
	var swinger := _first(targets, RangeTarget.Motion.SWINGER, RangeTarget.Kind.STEEL)
	for i in 50:
		RangeTargets.step(targets, tuning, DT)
	v.update(targets, 1.0, DT)
	var trolley := v._drawn[mover.id].carrier
	assert_almost_eq(trolley.global_position.x, mover.position.x, 1e-4)
	assert_almost_eq(trolley.global_position.z, mover.position.z, 1e-4)
	var plate := v._drawn[swinger.id].faces[0]
	assert_almost_eq(plate.global_position, swinger.position, Vector3.ONE * 1e-4, "the plate where the simulation swings it")


func test_lit_targets_glow_and_go_back_to_their_paint() -> void:
	var targets := RangeTargets.create(specs, tuning)
	var v := _view(targets)
	var figure := _first(targets, RangeTarget.Motion.STILL, RangeTarget.Kind.FIGURE)
	var faces := v._drawn[figure.id].faces
	var paint := faces[0].material_override
	figure.lit = 2.0
	v.update(targets, 0.0, DT)
	for face in faces:
		var m := face.material_override as StandardMaterial3D
		assert_true(m.emission_enabled, "lit: glowing")
		assert_eq(m.albedo_color, cfg.lit_colour)
	figure.lit = -1.0
	v.update(targets, 0.0, DT)
	assert_eq(faces[0].material_override, paint, "out: plywood again")


func test_the_start_plate_shows_only_while_the_challenge_waits_for_it() -> void:
	var targets := RangeTargets.create(specs, tuning)
	var v := _view(targets)
	var start := _start(targets)
	v.update(targets, 0.0, DT)
	assert_false(v._drawn[start.id].root.visible, "free practice: no START plate")
	var challenge := RangeChallenge.new("range")
	challenge.set_on(true, targets, tuning.targets, RandomNumberGenerator.new())
	v.update(targets, 0.0, DT)
	assert_true(v._drawn[start.id].root.visible)
	var word := v._drawn[start.id].root.find_children("*", "Label3D", true, false)
	assert_eq(word.size(), 1)
	assert_eq((word[0] as Label3D).text, "START")


func test_the_floor_lines_and_wall_boards_mark_each_distance() -> void:
	var marks := RangeView.new()
	add_child_autofree(marks)
	var range_cfg := tuning.targets
	marks.setup(cfg, range_cfg, GameTheme.font(800))
	var labels := marks.find_children("*", "Label3D", true, false)
	assert_eq(labels.size(), range_cfg.distances.size() * 2, "a board on each wall at each distance")
	for l: Label3D in labels:
		var at := l.global_position
		assert_true(absf(at.x) < range_cfg.half_width and absf(at.x) > range_cfg.half_width - 1.0, "by a wall")
		# Turned towards the firing line: its face looks across the range and back up it.
		var facing := l.global_basis.z
		assert_gt(facing.z, 0.0)
		assert_lt(facing.x * signf(at.x), 0.0)
		assert_eq(l.text, "%d m" % roundi(-at.z))


func test_steel_rings_down_the_range_a_figure_knocks_and_your_hit_confirms() -> void:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	var sound := SoundConfig.new()
	audio.setup(sound, [] as Array[StringName], BodyConfig.new(), null, null)
	var state := GameState.new(1)
	var ring := state.events.add(GameEvent.Kind.TARGET_HIT)
	ring.actor = 0
	ring.value = RangeTarget.Kind.STEEL
	ring.position = Vector3(-9.0, 1.25, -60.0)
	audio.on_tick(state, 0, null)
	assert_true((audio._streams[&"steelRing"] as Array).has(audio._field[0].stream), "steel rings")
	assert_eq(audio._field[0].max_distance, sound.target_reach)
	assert_true((audio._streams[&"hitMarker"] as Array).has(audio._own[0].stream), "your hit confirmed")
	state.events.clear()
	var knock := state.events.add(GameEvent.Kind.TARGET_HIT)
	knock.actor = 3
	knock.value = RangeTarget.Kind.FIGURE
	audio.on_tick(state, 0, null)
	assert_true((audio._streams[&"impact_wood"] as Array).has(audio._field[1].stream), "a figure knocks")
	assert_null(audio._own[1].stream, "someone else's hit: no confirmation")


func test_the_challenge_beeps_its_countdown_and_go_time_is_the_long_blast_and_the_range_has_no_start_whistle() -> void:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	var sound := SoundConfig.new()
	audio.setup(sound, [] as Array[StringName], BodyConfig.new(), null, null)
	var state := GameState.new(1)
	state.round_state.practice = true
	state.events.add(GameEvent.Kind.ROUND_START)
	audio.on_tick(state, 0, null)
	assert_null(audio._whistle.stream, "practice starts with no whistle")
	var pitches := PackedFloat64Array()
	for cue: RangeChallenge.Cue in [RangeChallenge.Cue.COUNT, RangeChallenge.Cue.GO]:
		state.events.clear()
		var e := state.events.add(GameEvent.Kind.CHALLENGE)
		e.actor = 0
		e.value = cue
		audio.on_tick(state, 0, null)
		pitches.append(audio._own[pitches.size()].pitch_scale)
	var wanted := PackedFloat64Array([1.0, sound.go_pitch])
	for i in wanted.size():
		assert_almost_eq(pitches[i], wanted[i], 1e-6)
	assert_true((audio._streams[&"count_beep"] as Array).has(audio._own[1].stream))
	state.events.clear()
	var time := state.events.add(GameEvent.Kind.CHALLENGE)
	time.actor = 0
	time.value = RangeChallenge.Cue.TIME
	audio.on_tick(state, 0, null)
	assert_true((audio._streams[&"whistle_long"] as Array).has(audio._whistle.stream), "Time: the long blast")
	assert_null(audio._own[2].stream, "no beep for Time")

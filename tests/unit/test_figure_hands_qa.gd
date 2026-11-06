extends GutTest
## FI3 QA: the upper body under the situations a match makes (rapid and cut-short switches, switching or firing while
## holstered or sprinting, pistol-only and rifle-less kits, parts and paint through the rigged figure, set_body swaps
## and rematches, a figure hidden or far then shown, the hit call then a round reset, extreme pitch, no body).
## Rigged poses are read as the skeleton finishes updating (modifiers have run).

const NEAR := Vector3(0.0, 1.6, 3.0)
const FAR := Vector3(0.0, 1.6, 300.0)
const FRAME := 1.0 / 60.0
## How near (m) the replica's grip point stays to the palm's line (wrist to knuckles): the hand wraps round the grip,
## its palm on the grip's side (HG1), so the line runs a grip's half-width and a palm's thickness off its middle.
const FIST := 0.035

var config: FigureConfig = null
var models: FigureModels = null
var hits: HitConfig = null
var _drawn: Dictionary[int, Dictionary] = {}


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()
	hits = HitConfig.new()


func _character(loadout: Array[ReplicaConfig] = []) -> Character:
	var kit: Array[ReplicaConfig] = loadout if not loadout.is_empty() else ReplicaStats.default_loadout()
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, kit)
	c.grounded = true
	return c


func _loadout(ids: Array[StringName]) -> Array[ReplicaConfig]:
	var out: Array[ReplicaConfig] = []
	for id in ids:
		out.append(ReplicaStats.load_replica(id))
	return out


func _view(kind: int, c: Character, realistic: bool = false) -> FigureView:
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null, realistic)
	v.set_body(models, kind, config.lod_high)
	_watch(v)
	return v


func _watch(v: FigureView) -> void:
	var sk := v.body().skeleton
	var id := v.get_instance_id()
	sk.skeleton_updated.connect(func() -> void:
		var view := instance_from_id(id) as FigureView
		if view == null or view.body() == null or view.body().skeleton != sk:
			return
		var hands := view.body().hands
		var d := {}
		for bone: String in ["Hand_R", "Middle1_R", "Hand_L", "Chest", "Head"]:
			d[bone] = sk.get_bone_global_pose(sk.find_bone(bone))
		var held := hands.replica(hands.in_hand)
		d[&"in_hand"] = held.transform if held != null else null
		var carried := hands.replica(hands.on_back)
		d[&"on_back"] = carried.transform if carried != null else null
		_drawn[id] = d)


func _pose(v: FigureView, c: Character, frames: int = 1, eye: Vector3 = NEAR) -> Dictionary:
	_drawn.erase(v.get_instance_id())
	for i in frames:
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, eye)
	await wait_process_frames(1)
	return _drawn.get(v.get_instance_id(), {})


static func _finite(t: Transform3D) -> bool:
	return t.origin.is_finite() and t.basis.x.is_finite() and t.basis.y.is_finite() and t.basis.z.is_finite()


## How far the grip point of the replica in the hand is from the right hand (wrist to knuckles), m.
func _grip_gap(v: FigureView, d: Dictionary) -> float:
	var hands := v.body().hands
	var held: Transform3D = d[&"in_hand"]
	var grip := held * hands.grip_point(hands.in_hand)
	var on_hand := Geometry3D.get_closest_point_to_segment(grip, (d["Hand_R"] as Transform3D).origin,
			(d["Middle1_R"] as Transform3D).origin)
	return grip.distance_to(on_hand)


func _shown(v: FigureView) -> int:
	var n := 0
	var hands := v.body().hands
	for i in 4:
		var r := hands.replica(i)
		if r != null and r.visible:
			n += 1
	return n


func test_rapid_switching_holstering_and_sprinting_never_shows_more_than_two_or_a_broken_transform() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var c := _character()
		var v := _view(kind, c)
		var a := c.armament
		var rng := RandomNumberGenerator.new()
		rng.seed = 33 + kind
		await _pose(v, c, 5)
		var worst_shown := 0
		for frame in 400:
			if rng.randf() < 0.06:
				# A switch, a holster or a draw out of it, at random moments (also mid-draw).
				var pick := rng.randi() % 4
				if pick == 0 or pick == 1:
					a.holstered = false
					a.active = rng.randi() % a.replicas.size()
					a.draw_total = rng.randf_range(0.1, 0.7)
					a.draw_left = a.draw_total
				elif pick == 2:
					a.holstered = true
					a.draw_left = 0.0
				else:
					a.holstered = false
			a.draw_left = maxf(0.0, a.draw_left - FRAME)
			c.sprinting = rng.randf() < 0.5 if frame % 30 == 0 else c.sprinting
			c.pitch = rng.randf_range(-1.55, 1.55) if frame % 20 == 0 else c.pitch
			c.prev_pitch = c.pitch
			if rng.randf() < 0.1:
				v.on_shot()
			var d: Dictionary = await _pose(v, c)
			worst_shown = maxi(worst_shown, _shown(v))
			for key: Variant in [&"in_hand", &"on_back"]:
				if d.get(key) != null:
					assert_true(_finite(d[key] as Transform3D), "kind %d frame %d: %s finite" % [kind, frame, key])
		assert_lte(worst_shown, 2, "kind %d: one in the hand and one on the back at most" % kind)
		# Settled, the replica in the hand is in the fist.
		a.holstered = false
		a.draw_left = 0.0
		c.sprinting = false
		c.pitch = 0.0
		c.prev_pitch = 0.0
		var done: Dictionary = await _pose(v, c, 60)
		assert_eq(v.body().hands.in_hand, a.active)
		assert_lt(_grip_gap(v, done), FIST, "kind %d: in the fist after the shuffle" % kind)
		assert_false(v.body().tree.get(FigureGraph.P_SWITCH_ACTIVE), "the Switch clip is over")


func test_a_switch_cut_short_by_a_holster_fades_the_switch_out_and_puts_the_rifle_on_the_back() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	var a := c.armament
	await _pose(v, c, 5)
	a.active = 1
	a.draw_total = 0.6
	a.draw_left = 0.6
	await _pose(v, c, 5)
	assert_true(v.body().tree.get(FigureGraph.P_SWITCH_ACTIVE))
	a.holstered = true
	a.draw_left = 0.0
	var d: Dictionary = await _pose(v, c, 60)
	assert_false(v.body().tree.get(FigureGraph.P_SWITCH_ACTIVE), "the switch cut with the draw")
	assert_eq(v.body().hands.in_hand, -1)
	assert_eq(v.body().hands.on_back, 0, "the rifle on the back")
	assert_not_null(d[&"on_back"])
	assert_eq(_shown(v), 2, "the rifle on the back and the pistol in the holster")


func test_a_holstered_figure_that_fires_or_switches_in_its_events_stays_holstered() -> void:
	# SHOT events can't come holstered, but a late event (a shot the tick before the holster) can: the press plays on a
	# holstered figure without moving the rifle off the back or the hand to the replica.
	var c := _character()
	c.armament.holstered = true
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 30)
	v.on_shot()
	var d: Dictionary = await _pose(v, c, 20)
	assert_eq(v.body().hands.in_hand, -1)
	assert_eq(v.body().hands.on_back, 0)
	assert_true(_finite(d[&"on_back"] as Transform3D))


func test_a_pistol_only_kit_aims_holsters_and_hangs_with_nothing_on_the_back() -> void:
	var kits: Array = [[&"pistol"], [&"cyber"], [&"pistol", &"cyber"]]
	for kit: Array in kits:
		var ids: Array[StringName] = []
		ids.assign(kit)
		var c := _character(_loadout(ids))
		var v := _view(FigureMix.HUMAN, c)
		var d: Dictionary = await _pose(v, c, 30)
		assert_eq(v.body().hands.in_hand, 0, "%s: the pistol in the hand" % [ids])
		assert_lt(_grip_gap(v, d), FIST, "%s: in the fist" % [ids])
		# Holstered: nothing in the hand, nothing on the back (no rifle), nothing shown.
		c.armament.holstered = true
		await _pose(v, c, 30)
		assert_eq(v.body().hands.in_hand, -1)
		assert_eq(v.body().hands.on_back, -1, "%s: no rifle for the back" % [ids])
		assert_eq(v.body().hands.in_holster, 0, "%s: the first pistol in the holster" % [ids])
		assert_eq(_shown(v), 1, "%s: only it drawn" % [ids])
		# Drawn again out of the holster, then the hit call.
		c.armament.holstered = false
		c.armament.draw_total = 0.8
		c.armament.draw_left = 0.8
		for i in 60:
			c.armament.draw_left = maxf(0.0, c.armament.draw_left - FRAME)
			await _pose(v, c)
		d = await _pose(v, c, 30)
		assert_eq(v.body().hands.in_hand, 0)
		assert_lt(_grip_gap(v, d), FIST, "%s: back in the fist" % [ids])
		c.status = Character.Status.CALLING
		d = await _pose(v, c, 60)
		assert_true(v.body().hands.hanging)
		assert_true(_finite(d[&"in_hand"] as Transform3D))
		v.on_shot()
		await _pose(v, c, 5)


func test_a_kit_without_a_rifle_or_a_rifle_alone_works_in_every_state() -> void:
	var c := _character(_loadout([&"aeg"]))
	var v := _view(FigureMix.ROBOT, c)
	var d: Dictionary = await _pose(v, c, 30)
	assert_lt(_grip_gap(v, d), FIST)
	# A switch to a slot that does not exist is not a draw; an active slot past the kit never crashes the pose.
	c.armament.holstered = true
	d = await _pose(v, c, 30)
	assert_eq(v.body().hands.on_back, 0)
	assert_eq(v.body().hands.in_hand, -1)
	c.armament.holstered = false
	c.armament.draw_total = 1.0
	c.armament.draw_left = 1.0
	d = await _pose(v, c, 5)
	assert_eq(v.body().hands.on_back, 0, "still on the back for the first half of the draw from the holster")


func test_parts_and_paint_read_through_the_figure_as_without_a_body() -> void:
	var rifle := ReplicaStats.load_replica(&"aeg")
	var pistol := ReplicaStats.load_replica(&"pistol")
	var loadout: Array[ReplicaConfig] = [rifle, pistol]
	var c := _character(loadout)
	var parts: Array[Dictionary] = [{&"optic": &"redDot", &"magazine": &"hiCap"}, {&"laser": &"redLaser"}]
	var plain := FigureView.new()
	add_child_autofree(plain)
	plain.setup(c, Color.RED, hits, null, false, parts)
	var rigged := FigureView.new()
	add_child_autofree(rigged)
	rigged.setup(c, Color.RED, hits, null, false, parts)
	rigged.set_body(models, FigureMix.HUMAN, config.lod_high)
	assert_not_null(rigged.body())
	assert_eq(rigged._replicas.size(), plain._replicas.size())
	assert_not_null(rigged._replicas[0].get_node_or_null("optic_redDot_Figure"), "the optic rides the rifle")
	assert_not_null(rigged._replicas[1].get_node_or_null("laser_redLaser_Figure"), "the laser rides the pistol")
	for i in plain._replicas.size():
		var a := plain._replicas[i]
		var b := rigged._replicas[i]
		assert_eq(b.get_child_count(), a.get_child_count(), "slot %d: the same parts" % i)
		assert_eq(b.mesh, a.mesh, "slot %d: the same figure mesh" % i)
		for s in a.mesh.get_surface_count():
			var ma := a.get_surface_override_material(s)
			var mb := b.get_surface_override_material(s)
			assert_eq(mb == null, ma == null, "slot %d surface %d: painted alike" % [i, s])
			if ma is StandardMaterial3D:
				assert_eq((mb as StandardMaterial3D).albedo_color, (ma as StandardMaterial3D).albedo_color,
						"slot %d surface %d: the same paint" % [i, s])
		assert_eq(b.get_parent(), rigged.body().hands, "slot %d: held by the hands" % i)


func test_set_body_swaps_leave_the_replicas_attached_once_and_no_orphans() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 3)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var first := v._replicas[0]
	for round_i in 6:
		var kind := FigureMix.ROBOT if round_i % 2 == 0 else FigureMix.HUMAN
		v.set_body(models, kind, config.lod_high)
		_watch(v)
		await wait_process_frames(2)
		await _pose(v, c, 3)
		assert_eq(first.get_parent(), v.body().hands, "round %d: handed to the new body" % round_i)
		assert_true(first.visible, "the rifle shown in the new body")
		assert_eq(_shown(v), 1 if kind == FigureMix.ROBOT else 2,
				"round %d: rifle in hand, pistol holstered (human)" % round_i)
	v.set_body(null, FigureMix.HUMAN, config.lod_high)
	await wait_process_frames(3)
	assert_eq(first.get_parent(), v)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans, "no orphans")


func test_a_cycle_of_bodies_and_none_returns_to_the_same_node_count() -> void:
	var c := _character()
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null)
	await wait_process_frames(2)
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 4:
		v.set_body(models, FigureMix.ROBOT if i % 2 == 0 else FigureMix.HUMAN, config.lod_high)
		await wait_process_frames(2)
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, NEAR)
		v.set_body(null, FigureMix.HUMAN, config.lod_high)
		await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "back to the bodiless node count")
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), 0.0)


func test_without_a_body_shots_are_ignored_and_no_replica_shows() -> void:
	var c := _character()
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null)
	v.on_shot()
	assert_false(v._fired, "no press queued without a body")
	v.update(c, 1.0)
	v.animate(c, 1.0, FRAME, NEAR)
	c.armament.active = 1
	v.update(c, 1.0)
	for r in v._replicas:
		assert_false(r.visible, "nothing to hold it")
	var round_trip := FigureView.new()
	add_child_autofree(round_trip)
	round_trip.setup(c, Color.RED, hits, null)
	round_trip.set_body(models, FigureMix.HUMAN, config.lod_high)
	_watch(round_trip)
	await _pose(round_trip, c, 5)
	round_trip.set_body(null, FigureMix.HUMAN, config.lod_high)
	round_trip.update(c, 1.0)
	for r in round_trip._replicas:
		assert_false(r.visible, "put away with the body")


func test_a_figure_hidden_while_it_holsters_has_the_rifle_on_the_back_when_shown_again() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 20)
	v.visible = false
	for i in 30:
		v.animate(c, 1.0, FRAME, NEAR)
	c.armament.holstered = true
	for i in 10:
		v.animate(c, 1.0, FRAME, NEAR)
	v.visible = true
	var d: Dictionary = await _pose(v, c, 30)
	assert_eq(v.body().hands.on_back, 0, "on the back when shown again")
	assert_eq(v.body().hands.in_hand, -1)
	var chest: Transform3D = d["Chest"]
	var on_chest := chest.affine_inverse() * (d[&"on_back"] as Transform3D)
	assert_lt(on_chest.origin.length(), 0.6, "on the chest, not left at the hand's last place")
	assert_true(v.body().hands.replica(0).visible)


func test_a_far_figure_has_its_replica_in_the_fist_when_it_comes_near() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 10)
	for i in 40:
		c.pitch = 0.5
		c.prev_pitch = 0.5
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, FAR)
	c.armament.active = 1
	var d: Dictionary = await _pose(v, c, 80, FAR)
	assert_eq(v.body().hands.in_hand, 1, "the far figure took the pistol")
	d = await _pose(v, c, 80, NEAR)
	assert_lt(_grip_gap(v, d), FIST, "the pistol in the fist after approaching")


func test_the_hit_call_walk_off_and_a_round_reset_put_the_rifle_back_in_the_hands() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var c := _character()
		var v := _view(kind, c)
		await _pose(v, c, 20)
		c.status = Character.Status.CALLING
		await _pose(v, c, 60)
		assert_true(v.body().hands.hanging)
		c.status = Character.Status.WALKING_OFF
		await _pose(v, c, 60)
		assert_true(v.body().hands.hanging, "still hanging as it walks off")
		c.status = Character.Status.LEAVING
		c.status_time = hits.vanish_time
		await _pose(v, c, 5)
		assert_false(v.visible)
		# The round resets: alive again, the armament refilled, a fresh position.
		c.status = Character.Status.ALIVE
		c.status_time = 0.0
		c.armament.refill()
		var d: Dictionary = await _pose(v, c, 90)
		assert_true(v.visible)
		assert_false(v.body().hands.hanging)
		assert_eq(v.body().hands.in_hand, 0, "kind %d: the rifle in the hands again" % kind)
		assert_true(v.body().hands.replica(0).visible)
		assert_lt(_grip_gap(v, d), FIST, "kind %d: in the fist" % kind)
		assert_eq(_shown(v), 1 if kind == FigureMix.ROBOT else 2)


func test_a_reset_while_the_figure_was_holstered_and_dead_brings_the_rifle_to_the_hands() -> void:
	var c := _character()
	c.armament.holstered = true
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 20)
	c.status = Character.Status.LEAVING
	c.status_time = hits.vanish_time
	await _pose(v, c, 5)
	c.status = Character.Status.ALIVE
	c.armament.refill()
	var d: Dictionary = await _pose(v, c, 90)
	assert_eq(v.body().hands.in_hand, 0)
	assert_lt(_grip_gap(v, d), FIST)


func test_an_extreme_pitch_keeps_the_replica_in_the_fist_pointing_the_right_way() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var c := _character()
		var v := _view(kind, c)
		for degrees: float in [89.0, -89.0, 90.0, -90.0]:
			c.pitch = deg_to_rad(degrees)
			c.prev_pitch = c.pitch
			var d: Dictionary = await _pose(v, c, 60)
			var held: Transform3D = d[&"in_hand"]
			assert_true(_finite(held), "finite")
			assert_true(_finite(d["Head"] as Transform3D))
			var way := (held.basis * Vector3.FORWARD).normalized()
			var drawn := rad_to_deg(asin(way.y))
			gut.p("kind %d pitch %.0f: muzzle %.1f°, grip gap %.3f" % [kind, degrees, drawn, _grip_gap(v, d)])
			assert_lt(_grip_gap(v, d), FIST, "kind %d at %.0f°: the fist holds it" % [kind, degrees])
			assert_almost_eq(drawn, degrees, 8.0, "kind %d at %.0f°: pointing where the BBs go" % [kind, degrees])


func test_a_pistol_at_the_extremes_points_where_the_shot_goes() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var c := _character()
		c.armament.active = 1
		var v := _view(kind, c)
		for degrees: float in [60.0, -60.0, 89.0, -89.0]:
			c.pitch = deg_to_rad(degrees)
			c.prev_pitch = c.pitch
			var d: Dictionary = await _pose(v, c, 60)
			var held: Transform3D = d[&"in_hand"]
			var way := (held.basis * Vector3.FORWARD).normalized()
			assert_almost_eq(rad_to_deg(asin(way.y)), degrees, 8.0, "kind %d pistol at %.0f°" % [kind, degrees])
			assert_lt(_grip_gap(v, d), FIST)


func _session() -> PlaySession:
	var settings := Settings.new(PlayTuning.new())
	var p := PlaySession.new()
	p.settings = settings
	p.map_id = "depot"
	p.autopilot = true
	p.match_seed = 9
	add_child_autofree(p)
	return p


func test_bodies_swapped_mid_match_keep_every_replica_on_one_parent_and_one_shown() -> void:
	var p := _session()
	await wait_physics_frames(120)
	for i in 3:
		for f in p._figures:
			f.set_body(null, 0, p._figure_lines)
		await wait_physics_frames(20)
		for f in p._figures:
			assert_null(f.body())
			for r in f._replicas:
				if r != null:
					assert_eq(r.get_parent(), f, "kept on the figure")
		for f in p._figures:
			f.set_body(p._figure_models, p.figure_kinds[f.character_id], p._figure_lines)
		await wait_physics_frames(60)
		for f in p._figures:
			assert_not_null(f.body())
			var shown := 0
			for r in f._replicas:
				if r != null:
					assert_eq(r.get_parent(), f.body().hands, "on the new body")
					shown += 1 if r.visible else 0
			assert_lte(shown, 2)


func test_a_run_of_sessions_leaves_no_orphans() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 3:
		var p := _session()
		await wait_physics_frames(90)
		remove_child(p)
		p.free()
	await wait_process_frames(3)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before, "no orphans left by the figures")


func test_a_shot_beyond_the_far_line_with_far_stride_0_does_not_play_when_the_figure_comes_near() -> void:
	var held_still := FigureConfig.new()
	held_still.far_stride = 0
	var own := FigureModels.new(held_still)
	own.load_kinds()
	var c := _character()
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null)
	v.set_body(own, FigureMix.HUMAN, held_still.lod_high)
	for i in 5:
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, NEAR)
	var tree := v.body().tree
	for i in 30:
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, FAR)
	v.on_shot()
	v.update(c, 1.0)
	v.animate(c, 1.0, FRAME, FAR)
	assert_false(v._fired, "dropped while held still out there")
	v.update(c, 1.0)
	v.animate(c, 1.0, FRAME, NEAR)
	assert_false(tree.get(FigureGraph.P_FIRE_ACTIVE), "no stale press when it comes near")


func test_two_of_a_class_show_only_the_first_stowed_and_the_one_in_hand() -> void:
	var c := _character(_loadout([&"aeg", &"pistol", &"cyber"]))
	var v := _view(FigureMix.HUMAN, c)
	var hands := v.body().hands
	c.armament.active = 2
	await _pose(v, c, 30)
	assert_eq(hands.in_hand, 2)
	assert_eq(hands.in_holster, 1, "the first pistol in the holster, not the one in the hand")
	assert_eq(hands.on_back, 0)
	c.armament.holstered = true
	await _pose(v, c, 30)
	assert_eq(hands.in_holster, 1)
	assert_eq(_shown(v), 2, "the second pistol is not drawn anywhere")


func test_a_draw_from_the_holster_keeps_the_pistol_in_the_holster_until_the_swap() -> void:
	var c := _character(_loadout([&"aeg", &"pistol"]))
	var v := _view(FigureMix.HUMAN, c)
	var hands := v.body().hands
	c.armament.holstered = true
	c.armament.active = 1
	await _pose(v, c, 30)
	c.armament.holstered = false
	c.armament.draw_total = 0.8
	c.armament.draw_left = 0.8
	await _pose(v, c, 1)
	assert_eq(hands.in_hand, -1, "start of the draw")
	assert_eq(hands.in_holster, 1)
	c.armament.draw_left = 0.0
	await _pose(v, c, 5)
	assert_eq(hands.in_hand, 1)
	assert_eq(hands.in_holster, -1)
	assert_eq(hands.on_back, 0)
	assert_false(hands.replica(1).get_parent() == null)


func test_a_fading_figure_and_a_body_swap_show_nothing_then_restore_the_holster() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 20)
	c.status = Character.Status.LEAVING
	c.status_time = hits.vanish_time * 0.5
	await _pose(v, c, 5)
	assert_eq(_shown(v), 0, "fading: nothing stowed left behind")
	c.status = Character.Status.ALIVE
	c.status_time = 0.0
	v.set_body(models, FigureMix.HUMAN, config.lod_low)
	_watch(v)
	await _pose(v, c, 5)
	assert_eq(v.body().hands.in_holster, 1)
	assert_true(v.body().hands.replica(1).visible, "the low body holsters the pistol too")

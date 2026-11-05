extends GutTest
## FI3: the upper body (game/play/figures/figure_hands.gd, figure_graph.gd's upper chain, figure_body.gd, figure_bend.gd's
## aim, figure_view.gd): the replica in the fist and pointing where the shot goes at 0 and ±45°, the Switch's pistol
## only past 0.35, one trigger press a SHOT, the rifle on the back by the back_* numbers, the hand up calling the
## hit with the rifle hanging from the other, the replicas kept by the figure without a body. FI4, the reloads: the clip at
## the reload's share of the replica's reload time (near, far, after hiding and drawn at 240 Hz), the new magazine on
## Hand_L over 0.389-0.509 of a 1.8 s reload and the old one where the replica's own clip pulls it, one copy on the hand
## at most, the old one thrown at its release and gone after 3 s, nothing more thrown once a switch, the hit call or
## hiding cuts it, no allocation, the pool built once a match and cleared at ROUND_START. Read as the skeleton finishes
## updating: Skeleton3D hands back the clips' pose after its modifiers ran.

const NEAR := Vector3(0.0, 1.6, 3.0)
const FAR := Vector3(0.0, 1.6, 200.0)
const FRAME := 1.0 / 60.0

var config: FigureConfig = null
var models: FigureModels = null
var hits: HitConfig = null

## What the last skeleton update drew, by figure: the bones' and the replicas' poses in the skeleton's frame.
var _drawn: Dictionary[FigureView, Dictionary] = {}


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()
	hits = HitConfig.new()


func _character() -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	return c


func _view(kind: int, c: Character) -> FigureView:
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null)
	v.set_body(models, kind, config.lod_high)
	var sk := v.body().skeleton
	var hands := v.body().hands
	sk.skeleton_updated.connect(func() -> void:
		var d := {}
		for bone: String in ["Hand_R", "Middle1_R", "Grip_R", "Hand_L", "Middle3_L", "Chest", "Hips", "Thigh_R"]:
			d[bone] = sk.get_bone_global_pose(sk.find_bone(bone))
		d[&"in_hand"] = hands.replica(hands.in_hand).transform if hands.replica(hands.in_hand) != null else null
		d[&"on_back"] = hands.replica(hands.on_back).transform if hands.replica(hands.on_back) != null else null
		d[&"in_holster"] = hands.replica(hands.in_holster).transform if hands.replica(hands.in_holster) != null else null
		var mag := hands.magazine(hands.mag_slot)
		d[&"magazine"] = mag.global_transform if mag != null and hands.mag_shown != FigureHands.MAG_NONE else null
		_drawn[v] = d)
	return v


## Poses `v` from `c` for `frames` frames (seen from `eye`) and waits for the skeleton to draw it.
func _pose(v: FigureView, c: Character, frames: int = 1, eye: Vector3 = NEAR) -> Dictionary:
	_drawn.erase(v)
	for i in frames:
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, eye)
	await wait_process_frames(1)
	return _drawn.get(v, {})


static func _muzzle_way(t: Transform3D) -> Vector3:
	return (t.basis * Vector3.FORWARD).normalized()


func test_aiming_the_rifle_holds_it_in_the_fist_pointing_at_the_pitch() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var c := _character()
		var v := _view(kind, c)
		for degrees: float in [0.0, 45.0, -45.0]:
			c.pitch = deg_to_rad(degrees)
			c.prev_pitch = c.pitch
			var d: Dictionary = await _pose(v, c, 30)
			assert_false(d.is_empty(), "drawn")
			if d.is_empty():
				return
			assert_eq(v.body().hands.in_hand, 0, "the rifle in the hand")
			var held: Transform3D = d[&"in_hand"]
			var grip := held * v.body().hands.grip_point(0)
			var hand: Transform3D = d["Hand_R"]
			var knuckle: Transform3D = d["Middle1_R"]
			var on_hand := Geometry3D.get_closest_point_to_segment(grip, hand.origin, knuckle.origin)
			assert_lt(grip.distance_to(on_hand), 0.03, "kind %d at %.0f°: the grip in the right hand" % [kind, degrees])
			var way := _muzzle_way(held)
			var drawn := rad_to_deg(asin(way.y))
			gut.p("kind %d pitch %.0f: muzzle %.2f°, grip %.3f m off the hand" % [kind, degrees, drawn,
					grip.distance_to(on_hand)])
			assert_almost_eq(drawn, degrees, 5.0, "kind %d at %.0f°: the muzzle at the pitch" % [kind, degrees])
			assert_gt(way.z, 0.5, "ahead (+Z in the file)")


func test_the_switch_shows_the_pistol_only_past_its_share() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 5)
	var a := c.armament
	assert_eq(a.replicas[1].site_class, &"pistol", "the default loadout's second replica is a pistol")
	a.active = 1
	a.draw_total = 0.6
	a.draw_left = a.draw_total
	var hands := v.body().hands
	var shown_before := 0
	var pistol_early := 0
	var steps := 30
	for i in steps:
		a.draw_left = a.draw_total * (1.0 - float(i) / steps)
		await _pose(v, c)
		var share := float(i) / steps
		if i == 0:
			assert_true(v.body().tree.get(FigureGraph.P_SWITCH_ACTIVE), "the Switch clip fired")
			assert_almost_eq(v.body().tree.get(FigureGraph.P_SWITCH_PACE), 0.6 / a.draw_total, 1e-4,
					"time-scaled to the draw (the clip is 0.6 s)")
		if share < config.switch_pistol_from:
			shown_before += 1 if hands.in_hand == 0 and hands.replica(0).visible else 0
			pistol_early += 1 if hands.in_hand == 1 else 0
		else:
			assert_eq(hands.in_hand, 1, "share %.2f: the pistol in the hand" % share)
			assert_true(hands.replica(1).visible)
			assert_eq(hands.on_back, 0, "the rifle on the back")
			assert_true(hands.replica(0).visible, "the rifle shows on the back")
	assert_gt(shown_before, 0)
	assert_eq(pistol_early, 0, "no pistol in the hand before 0.35 of the draw")
	a.draw_left = 0.0
	await _pose(v, c, 40)
	assert_false(v.body().tree.get(FigureGraph.P_SWITCH_ACTIVE), "done with the draw")
	assert_almost_eq(v.body().tree.get(FigureGraph.P_HOLD), 1.0, 1e-3, "the pistol's aim held")


func test_a_switch_back_to_the_rifle_plays_backwards_with_the_rifle_from_the_other_end() -> void:
	var c := _character()
	c.armament.active = 1
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 5)
	var a := c.armament
	a.active = 0
	a.draw_total = 0.45
	a.draw_left = a.draw_total * 0.6
	await _pose(v, c)
	assert_eq(v.body().tree.get(FigureGraph.P_SWITCH_WAY), 1.0, "backwards")
	assert_eq(v.body().hands.in_hand, 1, "the pistol still in the hand at 0.4 of the draw")
	a.draw_left = a.draw_total * 0.3
	await _pose(v, c)
	assert_eq(v.body().hands.in_hand, 0, "the rifle at 0.7")


func test_a_shot_plays_the_trigger_press_once() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 5)
	var tree := v.body().tree
	assert_false(tree.get(FigureGraph.P_FIRE_ACTIVE), "no press before a shot")
	v.on_shot()
	var starts := 0
	var was := false
	var active_frames := 0
	for i in 30:
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, NEAR)
		var now: bool = tree.get(FigureGraph.P_FIRE_ACTIVE)
		if now and not was:
			starts += 1
		active_frames += 1 if now else 0
		was = now
	assert_eq(starts, 1, "one press")
	var seconds := models.sidecar(FigureMix.HUMAN).clip(config.rifle_fire_clip).seconds
	assert_almost_eq(active_frames * FRAME, seconds, FRAME * 1.5, "for the clip's length")


func test_the_trigger_press_over_the_aim_draws_the_fire_clip_itself() -> void:
	# Fire's first frame is the aim's, so the additive copy (its change from frame 0) on the aim is the press itself; a
	# copy against the rest pose would add the whole hold again. Faded in at once here to compare the full press.
	var at_once := FigureConfig.new()
	at_once.settle_overlay = 0.0
	var own := FigureModels.new(at_once)
	own.load_kinds()
	var b := FigureBody.new()
	assert_true(b.setup(own, FigureMix.HUMAN, 0, 0, Color.RED, 0.0, at_once.lod_high))
	add_child_autofree(b)
	var pose := FigurePose.new(at_once)
	pose.read(_character(), 1.0, hits)
	pose.snap()
	b.animate(pose, hits, 0.0)
	var sk := b.skeleton
	var finger := sk.find_bone(&"Index2_R")
	var aimed := sk.get_bone_pose_rotation(finger)
	var press := own.library(FigureMix.HUMAN).get_animation(at_once.rifle_fire_clip)
	var track := press.find_track(NodePath("Rig/Skeleton3D:Index2_R"), Animation.TYPE_ROTATION_3D)
	assert_gte(track, 0, "the press moves the trigger finger")
	var t := press.length * 0.5
	assert_lt(aimed.angle_to(press.rotation_track_interpolate(track, 0.0)), 1e-3, "Fire starts on the aim's frame")
	b.animate(pose, hits, 0.0, true)
	b.animate(pose, hits, t)
	var pressed := sk.get_bone_pose_rotation(finger)
	assert_gt(pressed.angle_to(aimed), 0.05, "the finger moved")
	assert_lt(pressed.angle_to(press.rotation_track_interpolate(track, t)), 1e-3, "as the Fire clip has it")


func test_holstered_the_rifle_rides_on_the_back_by_the_back_numbers() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var c := _character()
		c.armament.holstered = true
		var v := _view(kind, c)
		var d: Dictionary = await _pose(v, c, 30)
		var hands := v.body().hands
		assert_eq(hands.in_hand, -1, "nothing in the hand")
		assert_eq(hands.on_back, 0, "the rifle on the back")
		assert_eq(hands.replica(1).visible, kind == FigureMix.HUMAN, "the pistol in the holster (the robot has none)")
		var worn: Transform3D = d[&"on_back"]
		var chest: Transform3D = d["Chest"]
		var box := hands.replica(0).get_aabb()
		var near := Vector3(box.position.x, 0.0, box.get_center().z)
		# Moved straight out of the back (its frame's x) onto the kit behind it; the robot has none to rest on.
		var lift := models.rest_on_back(kind, hands.replica(0).mesh, near)
		if kind == FigureMix.ROBOT:
			assert_eq(lift, 0.0, "the robot's rifle keeps its depth")
		else:
			assert_ne(lift, 0.0, "the human's rifle moved onto the pack")
			assert_lt(absf(lift), 0.06, "a small move")
		var middle := worn * (near - Vector3(lift, 0.0, 0.0))
		var depth := config.back_depth_robot if kind == FigureMix.ROBOT else config.back_depth_pack
		var lean := 0.0 if kind == FigureMix.ROBOT else config.back_lean
		assert_almost_eq(middle.x, -config.back_middle.x, 0.03, "kind %d: its middle by the spine" % kind)
		assert_almost_eq(middle.y, config.back_middle.y, 0.03, "kind %d: its middle's height" % kind)
		assert_almost_eq(middle.z, chest.origin.z - depth, 0.03, "kind %d: its near side behind the chest bone" % kind)
		var way := _muzzle_way(worn)
		assert_almost_eq(acos(-way.y), acos(cos(config.back_tilt) * cos(lean)), 0.05, "kind %d: tilted from upright" % kind)
		assert_almost_eq(asin(-way.z), lean, 0.05, "kind %d: leaning on the pack (the robot has none)" % kind)
		assert_gt(way.x, 0.0, "the muzzle to the figure's left")
		assert_lt((worn.basis * Vector3.RIGHT).z, -0.9, "its right side out of the back")
		var on_chest := chest.affine_inverse() * worn
		assert_almost_eq(on_chest.origin, (models.on_back(kind) * Transform3D(Basis.IDENTITY,
				Vector3(lift, 0.0, 0.0) - near)).origin, Vector3.ONE * 1e-3, "carried by the chest bone")


func test_the_rifle_on_the_back_rests_on_the_pack_not_in_it_or_off_it() -> void:
	for id: StringName in [&"aeg", &"sniper"]:
		var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(id), ReplicaStats.load_replica(&"pistol")]
		var c := Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
		c.grounded = true
		c.armament.holstered = true
		var v := _view(FigureMix.HUMAN, c)
		var d: Dictionary = await _pose(v, c, 30)
		var hands := v.body().hands
		assert_eq(hands.on_back, 0, "%s on the back" % id)
		var rifle := hands.replica(0)
		# Both sampled in the rifle's own frame (x out of the back) as this frame poses them, square by square: the
		# rifle's nearest point and the pack's farthest.
		var in_rifle := (d[&"on_back"] as Transform3D).affine_inverse()
		var near := _surface(rifle.mesh.get_faces(), Transform3D.IDENTITY, false)
		var pack_part := v.find_child(config.back_pack_part, true, false) as MeshInstance3D
		assert_not_null(pack_part, "the pack")
		if pack_part == null:
			return
		var chest := 0
		for b in pack_part.skin.get_bind_count():
			if pack_part.skin.get_bind_name(b) == config.chest_bone:
				chest = b
		var pack_to_rifle := in_rifle * (d["Chest"] as Transform3D) * pack_part.skin.get_bind_pose(chest)
		var far := _surface(pack_part.mesh.get_faces(), pack_to_rifle, true)
		var nearest := INF
		for cell: Vector2i in near:
			if far.has(cell):
				nearest = minf(nearest, near[cell] - far[cell])
		assert_lt(nearest, INF, "%s lies over the pack" % id)
		assert_gt(nearest, -0.004, "%s: not into the pack" % id)
		assert_lt(nearest, config.back_rest_gap + 0.01, "%s: resting on it, not floating off it" % id)


## The triangles `faces` (a mesh's, put through `to`) sampled every 1 cm: by 1 cm square across (y) and along (z), the
## smallest x (or with `farthest`, the largest).
static func _surface(faces: PackedVector3Array, to: Transform3D, farthest: bool) -> Dictionary[Vector2i, float]:
	var out: Dictionary[Vector2i, float] = {}
	for t in range(0, faces.size() - 2, 3):
		var a := to * faces[t]
		var ab := to * faces[t + 1] - a
		var ac := to * faces[t + 2] - a
		var steps := maxi(1, ceili(maxf(ab.length(), ac.length()) / 0.01))
		for u in steps + 1:
			for w in steps + 1 - u:
				var p := a + ab * (float(u) / steps) + ac * (float(w) / steps)
				var cell := Vector2i(floori(p.y / 0.01), floori(p.z / 0.01))
				if farthest:
					out[cell] = maxf(out.get(cell, -INF), p.x)
				else:
					out[cell] = minf(out.get(cell, INF), p.x)
	return out


func test_out_of_the_hand_the_pistol_sits_upright_in_the_holster_on_the_right_hip() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	var d: Dictionary = await _pose(v, c, 30)
	var hands := v.body().hands
	assert_true(models.has_holster(FigureMix.HUMAN), "the human's model has the holster's empty")
	assert_false(models.has_holster(FigureMix.ROBOT), "the robot has none")
	assert_eq(hands.in_hand, 0, "the rifle in the hand")
	assert_eq(hands.in_holster, 1, "the pistol in the holster")
	assert_true(hands.replica(1).visible)
	var seat: Transform3D = d[&"in_holster"]
	var hips: Transform3D = d["Hips"]
	var box := hands.replica(1).get_aabb()
	var muzzle := seat * Vector3(box.get_center().x, box.end.y, box.position.z)
	assert_lt(muzzle.x, hips.origin.x - 0.12, "on the figure's right hip")
	assert_lt(muzzle.y, hips.origin.y - 0.05, "its muzzle down below the belt")
	assert_gt((seat.basis * Vector3.BACK).normalized().y, 0.9, "upright, the grip up")
	assert_gt((seat.basis * Vector3.UP).normalized().z, 0.8, "the slide's top to the front")
	var on_seat := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -config.holster_depth)
			- Vector3(box.get_center().x, box.end.y, box.position.z))
	var by_hips := hips * models.holster(FigureMix.HUMAN) * on_seat
	var by_thigh: Transform3D = d["Thigh_R"] * models.holster_follow(FigureMix.HUMAN) * on_seat
	assert_almost_eq(seat.origin, by_hips.interpolate_with(by_thigh, config.holster_follow).origin, Vector3.ONE * 1e-3,
			"carried by the hips with a share of the thigh")
	c.armament.active = 1
	await _pose(v, c, 30)
	assert_eq(hands.in_holster, -1, "drawn: out of the holster")
	assert_eq(hands.on_back, 0, "and the rifle on the back")
	assert_true(hands.replica(0).visible)


func test_drawn_from_the_holster_the_rifle_comes_to_the_hand_at_half_the_draw() -> void:
	var c := _character()
	c.armament.holstered = true
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 5)
	var a := c.armament
	a.holstered = false
	a.draw_total = 0.8
	var hands := v.body().hands
	for share: float in [0.1, 0.4]:
		a.draw_left = a.draw_total * (1.0 - share)
		await _pose(v, c)
		assert_eq(hands.on_back, 0, "share %.1f: still on the back" % share)
		assert_eq(hands.in_hand, -1)
	for share: float in [0.6, 0.9]:
		a.draw_left = a.draw_total * (1.0 - share)
		await _pose(v, c)
		assert_eq(hands.in_hand, 0, "share %.1f: in the hand" % share)
		assert_eq(hands.on_back, -1)
	assert_false(v.body().tree.get(FigureGraph.P_SWITCH_ACTIVE), "out of the holster isn't a switch")


func test_calling_the_hit_raises_the_left_hand_and_the_rifle_hangs_from_the_right() -> void:
	var c := _character()
	c.status = Character.Status.CALLING
	c.status_time = 2.0
	var v := _view(FigureMix.HUMAN, c)
	var d: Dictionary = await _pose(v, c, 40)
	var hand_l: Transform3D = d["Hand_L"]
	var hand_r: Transform3D = d["Hand_R"]
	var tip: Transform3D = d["Middle3_L"]
	assert_gt(hand_l.origin.y, 1.75, "the left hand up")
	assert_gt(tip.origin.y, hand_l.origin.y, "the fingers above it")
	assert_almost_eq(hand_r.origin.y, 0.95, 0.15, "the right hand down by the side")
	var hands := v.body().hands
	assert_true(hands.hanging)
	var held: Transform3D = d[&"in_hand"]
	var way := _muzzle_way(held)
	assert_almost_eq(acos(-way.y), config.hang_tilt, 0.01, "off straight down by hang_tilt")
	assert_gte(way.z, -1e-3, "never tipped back")
	var grip: Transform3D = d["Grip_R"]
	assert_almost_eq(held * hands.grip_point(0), grip.origin, Vector3.ONE * 1e-3, "hanging from the right hand's grip")


func test_without_a_body_the_replicas_wait_hidden_on_the_figure() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 3)
	v.set_body(null, FigureMix.HUMAN, config.lod_high)
	assert_null(v.body())
	for r in v._replicas:
		assert_eq(r.get_parent(), v, "kept on the figure")
		assert_false(r.visible, "hidden: nothing to hold it")
	for m in v._magazines:
		assert_eq(m.get_parent(), v, "the magazines' copies too")
		assert_false(m.visible)
	v.update(c, 1.0)
	v.animate(c, 1.0, FRAME, NEAR)
	assert_false(v._replicas[0].visible, "no replica floats where no body holds it")
	await wait_process_frames(2)
	assert_true(is_instance_valid(v._replicas[0]), "outlived the body")
	v.set_body(models, FigureMix.HUMAN, config.lod_high)
	v.update(c, 1.0)
	v.animate(c, 1.0, FRAME, NEAR)
	assert_true(v._replicas[0].visible, "in the hand of the next body")


func test_a_fading_figure_puts_its_replicas_away() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 3)
	assert_true(v.body().hands.replica(0).visible)
	c.status = Character.Status.LEAVING
	c.status_time = hits.vanish_time * 0.5
	await _pose(v, c)
	assert_false(v.body().hands.replica(0).visible, "put away as it fades")


## Every clip a graph node plays, down through its blend spaces.
static func _clips(node: AnimationNode, into: PackedStringArray) -> void:
	if node is AnimationNodeAnimation:
		into.append(String((node as AnimationNodeAnimation).animation))
	elif node is AnimationNodeBlendSpace1D:
		var space := node as AnimationNodeBlendSpace1D
		for i in space.get_blend_point_count():
			_clips(space.get_blend_point_node(i), into)
	elif node is AnimationNodeBlendSpace2D:
		var plane := node as AnimationNodeBlendSpace2D
		for i in plane.get_blend_point_count():
			_clips(plane.get_blend_point_node(i), into)


func test_the_upper_body_takes_every_bone_but_the_legs_and_no_rest_clip_plays() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var graph := models.graph(kind)
		var upper := graph.get_node(FigureGraph.UPPER) as AnimationNodeBlend2
		assert_true(upper.filter_enabled)
		var c := _character()
		var v := _view(kind, c)
		var sk := v.body().skeleton
		for b in sk.get_bone_count():
			var bone := sk.get_bone_name(b)
			assert_eq(upper.is_path_filtered(NodePath("Rig/Skeleton3D:" + bone)), not config.lower_bones.has(bone), bone)
		var clips := PackedStringArray()
		for node_name in graph.get_node_list():
			_clips(graph.get_node(node_name), clips)
		for clip in clips:
			assert_false(clip.contains("_Rest"), "kind %d plays no Rest clip (MV1): %s" % [kind, clip])
		for clip in config.rifle_aim_clips + config.pistol_aim_clips:
			assert_true(clips.has(clip), clip)
		assert_true(clips.has(config.rifle_fire_clip + config.additive_suffix), "the additive press")
		assert_false(clips.has(config.rifle_fire_clip), "never the press itself")


func test_shots_switches_and_the_holster_allocate_no_objects() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	var a := c.armament
	await _pose(v, c, 10)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for frame in 240:
		if frame % 6 == 0:
			v.on_shot()
		if frame % 60 == 0:
			a.active = 1 - a.active
			a.draw_total = 0.3
			a.draw_left = 0.3
		a.draw_left = maxf(0.0, a.draw_left - FRAME)
		a.holstered = frame >= 150 and frame < 200
		c.pitch = sin(frame * 0.05)
		c.status = Character.Status.CALLING if frame >= 220 else Character.Status.ALIVE
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, NEAR)
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


func test_in_a_match_a_bots_shot_reaches_its_figure_by_id() -> void:
	var settings := Settings.new(PlayTuning.new())
	var p := PlaySession.new()
	p.settings = settings
	p.map_id = "depot"
	p.autopilot = true
	p.match_seed = 5
	add_child_autofree(p)
	await wait_physics_frames(2)
	assert_null(p._figure_of[PlaySession.PLAYER_ID], "you have no figure")
	for f in p._figures:
		assert_eq(p._figure_of[f.character_id], f)
		assert_not_null(f.body(), "drawn")
	var shooter := p._figures[0]
	var shot := p.state.events.add(GameEvent.Kind.SHOT)
	shot.actor = shooter.character_id
	p._after_tick()
	assert_true(shooter._fired, "its trigger press waits for its next pose")
	for f: FigureView in p._figures.slice(1):
		assert_false(f._fired, "no one else's")
	get_tree().paused = false


func test_a_branch_with_no_weight_is_gated_off_and_comes_back() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	var tree := v.body().tree
	await _pose(v, c, 5)
	assert_eq(tree.get(&"parameters/upper_gate/current_state"), FigureGraph.GATE_ON, "aiming: the upper body plays")
	assert_eq(tree.get(&"parameters/hold_gate/current_state"), FigureGraph.GATE_ON, "the aim plays")
	assert_eq(tree.get(&"parameters/holster_gate/current_state"), FigureGraph.GATE_REST, "the holster's arms don't")
	c.armament.holstered = true
	await _pose(v, c, 40)
	assert_eq(tree.get(&"parameters/hold_gate/current_state"), FigureGraph.GATE_REST, "fully holstered: the aim doesn't")
	assert_eq(tree.get(&"parameters/holster_gate/current_state"), FigureGraph.GATE_ON)
	assert_eq(tree.get(FigureGraph.P_HOLSTER), 1.0, "drawn as the holster alone")
	c.armament.holstered = false
	c.status = Character.Status.CALLING
	c.status_time = 2.0
	await _pose(v, c, 60)
	assert_eq(tree.get(&"parameters/upper_gate/current_state"), FigureGraph.GATE_REST, "calling: the upper body doesn't")
	assert_eq(tree.get(FigureGraph.P_UPPER), 0.0)
	# A switch begun behind the shut gate isn't asked for (it would play late, once the gate opens).
	c.armament.active = 1
	c.armament.draw_total = 0.3
	c.armament.draw_left = 0.3
	await _pose(v, c)
	assert_false(tree.get(FigureGraph.P_SWITCH_ACTIVE))
	c.armament.draw_left = 0.0
	c.status = Character.Status.ALIVE
	c.status_time = 0.0
	var d: Dictionary = await _pose(v, c, 60)
	assert_eq(tree.get(&"parameters/upper_gate/current_state"), FigureGraph.GATE_ON, "back on")
	assert_false(tree.get(FigureGraph.P_SWITCH_ACTIVE), "no late switch")
	var held: Transform3D = d[&"in_hand"]
	var hand: Transform3D = d["Hand_R"]
	assert_lt((held * v.body().hands.grip_point(1)).distance_to(hand.origin), 0.15, "the pistol back in the fist")


# FI4: the reloads.


## A thrown magazines' pool for `v`'s magazines, `v`'s rigged hands throwing into it.
func _thrown_for(v: FigureView) -> ThrownMagazines:
	var t := ThrownMagazines.new()
	t.setup(config.thrown_max)
	add_child_autofree(t)
	v.thrown = t
	v.body().hands.thrown = t
	return t


## Hand_L in the Hips' frame: as drawn (`d`), and as `clip` poses it at `time` (s).
func _hand_in_hips(d: Dictionary) -> Transform3D:
	return (d["Hips"] as Transform3D).affine_inverse() * (d["Hand_L"] as Transform3D)


func _clip_hand_in_hips(v: FigureView, clip: StringName, time: float) -> Transform3D:
	var sk := v.body().skeleton
	var prefix := String(v.body().tree.get_parent().get_path_to(sk))
	var anim := models.library(FigureMix.HUMAN).get_animation(clip)
	var hips := FigureGraph.bone_pose(anim, sk, prefix, sk.find_bone("Hips"), time)
	return hips.affine_inverse() * FigureGraph.bone_pose(anim, sk, prefix, sk.find_bone("Hand_L"), time)


## The centre of replica `id`'s own magazine in the replica's frame, its Reload clip at `share` (the full model).
func _replica_magazine(id: String, share: float) -> Vector3:
	var model := (load("res://assets/models/replicas/%s.glb" % id) as PackedScene).instantiate() as Node3D
	add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.play(&"Reload")
	player.seek(share * player.current_animation_length, true)
	player.pause()
	await wait_process_frames(1)
	var mag := model.find_child(config.magazine_node, true, false) as MeshInstance3D
	var centre := model.global_transform.affine_inverse() * mag.global_transform * mag.get_aabb().get_center()
	model.free()
	return centre


func test_a_reload_shows_the_new_magazine_on_hand_l_over_its_share_and_one_copy_at_most() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 5)
	var a := c.armament
	var total := a.replicas[0].reload_time
	assert_eq(total, 1.8, "the AEG reloads in 1.8 s")
	var hands := v.body().hands
	var new_shares := PackedFloat64Array()
	var old_shares := PackedFloat64Array()
	var most := 0
	a.reload_left = total
	while a.reload_left > 0.0:
		var share := 1.0 - a.reload_left / total
		var d: Dictionary = await _pose(v, c)
		var shown := 0
		for slot in a.replicas.size():
			shown += 1 if hands.magazine(slot) != null and hands.magazine(slot).visible else 0
		most = maxi(most, shown)
		if hands.mag_shown == FigureHands.MAG_NEW:
			new_shares.append(share)
		elif hands.mag_shown == FigureHands.MAG_OLD:
			old_shares.append(share)
		if hands.mag_shown != FigureHands.MAG_NONE:
			var hand: Transform3D = d["Hand_L"]
			var mag: Transform3D = d[&"magazine"]
			assert_lt(mag.origin.distance_to(v.body().skeleton.global_transform * hand.origin), 0.2,
					"share %.3f: the copy rides on Hand_L" % share)
		a.reload_left = maxf(0.0, a.reload_left - FRAME)
	var step := FRAME / total
	assert_false(new_shares.is_empty())
	assert_almost_eq(new_shares[0], 0.389, step, "the new magazine from 0.389")
	assert_almost_eq(new_shares[new_shares.size() - 1], 0.509, step, "to 0.509")
	assert_almost_eq(old_shares[0], 0.0926, step, "the old one pulled from oldMagazine.from")
	assert_almost_eq(old_shares[old_shares.size() - 1], 0.185, step, "until its release")
	assert_eq(most, 1, "one copy on the hand at most (the figure version's own magazine can't hide)")
	await _pose(v, c, 5)
	assert_false(hands.magazine(0).visible, "none after the reload")


func test_the_old_magazine_starts_where_the_replicas_own_clip_pulls_it() -> void:
	for slot: int in [0, 1]:
		var c := _character()
		c.armament.active = slot
		var v := _view(FigureMix.HUMAN, c)
		await _pose(v, c, 5)
		var a := c.armament
		var r := a.replicas[slot]
		var side := models.sidecar(FigureMix.HUMAN)
		var clip := config.pistol_reload_clip if r.site_class == &"pistol" else config.rifle_reload_clip
		var share := side.magazine_in_hand[clip].old.from + 0.005
		a.reload_left = r.reload_time
		await _pose(v, c)
		a.reload_left = r.reload_time * (1.0 - share)
		await _pose(v, c, 10)
		var hands := v.body().hands
		assert_eq(hands.mag_shown, FigureHands.MAG_OLD, r.id)
		var mag := hands.magazine(slot)
		var copy := mag.transform * mag.get_aabb().get_center()
		var own := hands.replica(slot).transform * (await _replica_magazine(r.id, share))
		gut.p("%s: the old copy %.3f m from the replica's own magazine at %.3f" % [r.id, copy.distance_to(own), share])
		assert_lt(copy.distance_to(own), 0.02, "%s: the old copy takes the magazine out of the replica" % r.id)


func test_the_reload_clip_keeps_step_with_reload_left_near_far_and_after_hiding() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 5)
	var a := c.armament
	var total := a.replicas[0].reload_time
	var tree := v.body().tree
	a.reload_left = total
	var d: Dictionary = {}
	for i in 27:
		d = await _pose(v, c)
		a.reload_left -= FRAME
	var share := 1.0 - (a.reload_left + FRAME) / total
	assert_true(tree.get(FigureGraph.P_RELOAD_ACTIVE), "the reload plays")
	var off := _hand_in_hips(d).origin.distance_to(_clip_hand_in_hips(v, config.rifle_reload_clip, share * 1.8).origin)
	assert_lt(off, 0.01, "near: Hand_L where Rifle_Reload has it at %.2f of its 1.8 s" % share)
	# Far: posed every far_stride-th frame, the time gathered; the stride's frame finds the clip at the reload's share.
	for i in config.far_stride * 6:
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, FAR)
		a.reload_left -= FRAME
	d = await _pose(v, c, config.far_stride, FAR)
	share = 1.0 - a.reload_left / total
	off = _hand_in_hips(d).origin.distance_to(_clip_hand_in_hips(v, config.rifle_reload_clip, share * 1.8).origin)
	assert_lt(off, 0.01, "far: in step at %.2f" % share)
	# Hidden (your watched bot), then shown again: in step at once, without its release thrown.
	var t := _thrown_for(v)
	for i in 20:
		v.update(c, 1.0)
		v.visible = false
		v.animate(c, 1.0, FRAME, NEAR)
		a.reload_left -= FRAME
	d = await _pose(v, c)
	share = 1.0 - a.reload_left / total
	assert_gt(share, 0.185, "past the release while hidden")
	off = _hand_in_hips(d).origin.distance_to(_clip_hand_in_hips(v, config.rifle_reload_clip, share * 1.8).origin)
	assert_lt(off, 0.02, "shown again: in step at %.2f" % share)
	assert_eq(t.count(), 0, "no throw for a release it wasn't drawn through")
	a.reload_left = 0.0
	await _pose(v, c, 20)
	assert_false(tree.get(FigureGraph.P_RELOAD_ACTIVE), "RELOAD_END: done")


func test_drawn_faster_than_the_ticks_the_reload_plays_to_its_end() -> void:
	# At 240 Hz reload_left holds for four frames a tick: the OneShot mustn't guess the clip has ended (it ends only
	# when the reload does).
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 5)
	var a := c.armament
	var tree := v.body().tree
	a.reload_left = a.replicas[0].reload_time
	var playing := 0
	var ticks := 0
	while a.reload_left > FRAME:
		for i in 4:
			v.update(c, 1.0, FRAME * 0.25)
			v.animate(c, 1.0, FRAME * 0.25, NEAR)
		playing += 1 if tree.get(FigureGraph.P_RELOAD_ACTIVE) else 0
		ticks += 1
		a.reload_left -= FRAME
	assert_eq(playing, ticks, "the reload played every tick of it")
	await wait_process_frames(1)


func test_the_old_magazine_is_thrown_at_its_release_lands_and_goes_after_3_s() -> void:
	var c := _character()
	c.velocity = Vector3(0.0, 0.0, -2.0)
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 5)
	var t := _thrown_for(v)
	var a := c.armament
	var total := a.replicas[0].reload_time
	var release := models.sidecar(FigureMix.HUMAN).magazine_in_hand[config.rifle_reload_clip].old.release
	a.reload_left = total
	var last_old: Transform3D = Transform3D.IDENTITY
	var thrown_share := -1.0
	while thrown_share < 0.0 and a.reload_left > 0.0:
		var share := 1.0 - a.reload_left / total
		var d: Dictionary = await _pose(v, c)
		if t.count() > 0:
			thrown_share = share
		elif d.get(&"magazine") != null and v.body().hands.mag_shown == FigureHands.MAG_OLD:
			last_old = d[&"magazine"]
		a.reload_left -= FRAME
	assert_almost_eq(thrown_share, release, FRAME / total, "thrown at its release")
	var m := t.thrown_at(0)
	assert_lt(m.transform.origin.distance_to(last_old.origin), 0.1, "let go where the hand held it")
	assert_eq(m.mesh, v.body().hands.magazine(0).mesh, "a copy of the replica's magazine")
	var start := m.transform.origin
	var time := 0.0
	while not t.landed_at(0) and time < 2.0:
		t.update(FRAME)
		time += FRAME
	assert_true(t.landed_at(0), "landed")
	var lying := m.transform
	assert_almost_eq(absf(lying.basis.x.y), 1.0, 1e-4, "on its side")
	assert_lt(lying.origin.y, 0.05, "at the figure's feet")
	assert_lt(lying.origin.x, start.x - 0.2, "thrown out to the figure's left (it faces -Z)")
	assert_lt(lying.origin.z, start.z, "carried ahead by the figure's own run")
	t.update(3.0 - time - FRAME)
	assert_eq(t.count(), 1)
	t.update(2.0 * FRAME)
	assert_eq(t.count(), 0, "gone after 3 s")
	while a.reload_left > 0.0:
		await _pose(v, c)
		a.reload_left -= FRAME
	assert_eq(t.count(), 0, "one throw a reload")


func test_a_reload_cut_by_a_switch_or_the_hit_call_throws_nothing_more() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c, 5)
	var t := _thrown_for(v)
	var a := c.armament
	var tree := v.body().tree
	var hands := v.body().hands
	a.reload_left = a.replicas[0].reload_time
	for i in 15:
		await _pose(v, c)
		a.reload_left -= FRAME
	assert_eq(hands.mag_shown, FigureHands.MAG_OLD, "pulling the old one")
	# The switch: the simulation zeroes reload_left and draws the pistol.
	a.reload_left = 0.0
	a.active = 1
	a.draw_total = 0.3
	a.draw_left = 0.3
	await _pose(v, c)
	assert_eq(hands.mag_shown, FigureHands.MAG_NONE, "the copy gone at once")
	assert_true(tree.get(FigureGraph.P_SWITCH_ACTIVE), "the switch plays")
	for i in 40:
		await _pose(v, c)
		a.draw_left = maxf(0.0, a.draw_left - FRAME)
	assert_false(tree.get(FigureGraph.P_RELOAD_ACTIVE), "cut")
	assert_eq(t.count(), 0, "nothing thrown")
	# Past its release, then the hit call: the one thrown stays, nothing more.
	a.reload_left = a.replicas[1].reload_time
	var release := models.sidecar(FigureMix.HUMAN).magazine_in_hand[config.pistol_reload_clip].old.release
	while 1.0 - a.reload_left / a.replicas[1].reload_time < release + 0.05:
		await _pose(v, c)
		a.reload_left -= FRAME
	assert_eq(t.count(), 1)
	c.status = Character.Status.CALLING
	for i in 60:
		await _pose(v, c)
		c.status_time += FRAME
		a.reload_left = maxf(0.0, a.reload_left - FRAME)
	assert_eq(t.count(), 1, "nothing more")
	assert_eq(hands.mag_shown, FigureHands.MAG_NONE, "calling: no magazine in the raised hand")
	assert_false(tree.get(FigureGraph.P_RELOAD_ACTIVE), "the hit call cut it")


func test_reloads_and_throws_allocate_no_objects() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c)
	var a := c.armament
	await _pose(v, c, 10)
	var t := _thrown_for(v)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for frame in 360:
		if frame % 90 == 0:
			a.reload_left = a.replicas[a.active].reload_time
		if frame == 200:
			a.reload_left = 0.0
			a.active = 1
			a.draw_total = 0.3
			a.draw_left = 0.3
		a.reload_left = maxf(0.0, a.reload_left - FRAME)
		a.draw_left = maxf(0.0, a.draw_left - FRAME)
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, NEAR if frame % 120 < 100 else FAR)
		t.update(FRAME)
		await wait_process_frames(1)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
	assert_gt(t.count(), 0, "thrown meanwhile")


func test_in_a_match_the_pool_is_built_once_and_a_new_round_clears_it() -> void:
	var settings := Settings.new(PlayTuning.new())
	var p := PlaySession.new()
	p.settings = settings
	p.map_id = "depot"
	p.autopilot = true
	p.match_seed = 5
	add_child_autofree(p)
	await wait_physics_frames(2)
	var t := p._thrown
	assert_not_null(t, "built with the figures")
	for f in p._figures:
		assert_eq(f.body().hands.thrown, t, "each figure throws into it")
	assert_eq(t.pool_size(), config.thrown_max, "12 shared by every magazine")
	var source := p._figures[0].body().hands.magazine(0)
	assert_true(t.throw(source, Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO, 0.0, 9.81, 3.0))
	p._apply_dev()
	p._refresh_kinds()
	assert_eq(p._thrown, t, "built once a session")
	assert_true(t.throw(source, Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO, 0.0, 9.81, 3.0))
	p.state.events.add(GameEvent.Kind.ROUND_START)
	p._after_tick()
	assert_eq(t.count(), 0, "cleared at ROUND_START")
	get_tree().paused = false

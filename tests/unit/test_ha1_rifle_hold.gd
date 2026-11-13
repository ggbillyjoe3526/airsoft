extends GutTest
## HA1 QA, the owner's fifth look: with no grip the rifles' left hand sits back just ahead of the magazine (between it
## and the GripMount), no fingertip rides above the handguard's top and no finger under it is knotted, the bots' left
## hand still holds where the arms'
## does for all three rifles, a bomb in both hands (PB1) carries the replica low through HA1's eased carry, and each
## reload clip ends on the hold's pose.

const DT := 1.0 / 60.0
const RIFLES: Array[StringName] = [&"aeg", &"sniper", &"smg"]
## Every replica whose handguard the left hand holds with no grip fitted (the Pump Shotgun by its pump).
const HANDGUARD_HELD: Array[StringName] = [&"aeg", &"sniper", &"smg", &"shotgun"]
const GRIPS: Array[String] = ["vertical", "angled"]
const MODEL_PATH := "res://assets/models/arms/arms.glb"
const EYE := Vector3(0.0, 1.6, 3.0)
## How far (m) behind a magazine's front the wrist may still sit, and how far (m) short of the GripMount it must stay.
const BEHIND_MAG_FRONT := 0.04
const SHORT_OF_MOUNT := 0.03
## How far (m) a fingertip may rise above the replica's top within a hand's breadth (a bare handguard's).
const ABOVE_TOP := 0.005
## The most (rad) any joint of a finger resting under a bare handguard bends from its rest (the critic, HA1: the ring
## and little fingers lay knotted, a middle joint shut to 100 degrees).
const MOST_BEND := PI / 2.0
## How near (m) a reload's last frame comes to the hold's bone places, and (rad) its turns.
## The eye's view of the left fingers: their names, every which vertex of their skin is judged, and how far (m) short
## of a vertex the replica must stand in the eye's way for it to count as hidden.
const FINGERS: Array[String] = ["Index", "Middle", "Ring", "Pinky"]
const EYE_EVERY := 3
const EYE_SKIN := 0.002
const END_PLACE := 0.003
const END_TURN := 0.02
const PLACE := 0.005
const TURN := 0.05

var config: FigureConfig = null
var models: FigureModels = null
var hits: HitConfig = null


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()
	hits = HitConfig.new()


func _hands(id: StringName) -> ReplicaView:
	var lo: Array[ReplicaConfig] = [ReplicaStats.load_replica(id)]
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(ViewModelConfig.new(), lo, BoxWorld.new())
	hands._show(0)
	hands._arms.follow(hands._held[0].anim, 0.0)
	return hands


func _verts(n: Node, root: Node3D, out: Array[Vector3]) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and n.name != "Magazine" \
			and not String(n.name).begins_with("Figure"):
		var t := root.global_transform.affine_inverse() * (n as MeshInstance3D).global_transform
		var m := (n as MeshInstance3D).mesh
		for s in m.get_surface_count():
			for v: Vector3 in m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				out.append(t * v)
	for c in n.get_children():
		_verts(c, root, out)


func test_without_a_grip_the_left_hand_sits_between_the_magazine_and_the_grip_mount() -> void:
	for id: StringName in RIFLES:
		var hands := _hands(id)
		var held: ReplicaView.Held = hands._held[0]
		var model := held.root.get_child(0) as Node3D
		var mag := model.find_child("Magazine", true, false) as MeshInstance3D
		var mount := model.find_child("GripMount", true, false) as Node3D
		assert_not_null(mag, "%s: a magazine" % id)
		assert_not_null(mount, "%s: a GripMount" % id)
		var to_root := held.root.global_transform.affine_inverse()
		var box := mag.get_aabb()
		var front := (to_root * (mag.global_transform * box.get_center())).z - box.size.z * 0.5
		var centre := (to_root * (mag.global_transform * box.get_center())).z
		var wrist := hands._arms.left_hand(held.root).origin
		var mark := (to_root * mount.global_position).z
		# The replica points down -Z: ahead is smaller.
		assert_lt(wrist.z, centre, "%s: the wrist is ahead of the magazine's middle (%.3f < %.3f)" % [id, wrist.z, centre])
		assert_gt(wrist.z, front - BEHIND_MAG_FRONT, "%s: and just ahead of the magazine, not out on the barrel" % id)
		assert_gt(wrist.z, mark + SHORT_OF_MOUNT, "%s: and well back of the GripMount (%.3f vs %.3f)" % [id, wrist.z, mark])


func test_no_left_fingertip_rides_above_the_handguard_in_the_hold() -> void:
	for id: StringName in RIFLES:
		var hands := _hands(id)
		var held: ReplicaView.Held = hands._held[0]
		var vs: Array[Vector3] = []
		_verts(held.root.get_child(0), held.root, vs)
		var sk := hands._arms._skeleton
		sk.force_update_all_bone_transforms()
		for f: String in ["Index", "Middle", "Ring", "Pinky"]:
			var p := held.root.global_transform.affine_inverse() * sk.global_transform \
					* sk.get_bone_global_pose(sk.find_bone(f + "3_L"))
			var tip := p.origin + p.basis.y.normalized() * 0.02
			var top := -INF
			for v: Vector3 in vs:
				if absf(v.z - tip.z) < 0.015 and absf(v.x - tip.x) < 0.03:
					top = maxf(top, v.y)
			if top > -INF:
				assert_lt(tip.y, top + ABOVE_TOP, "%s: the %s fingertip under the top (%.3f vs %.3f)" % [id, f, tip.y, top])


## The replica's drawn triangles (three points each) in `root`'s space, the bots' low-detail copies left out.
func _tris(n: Node, root: Node3D, out: PackedVector3Array) -> void:
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null and mi.is_visible_in_tree() and not String(n.name).begins_with("Figure"):
		var t := root.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: Variant = arrays[Mesh.ARRAY_INDEX]
			if idx == null or (idx as PackedInt32Array).is_empty():
				for v: Vector3 in vs:
					out.append(t * v)
			else:
				for i: int in idx as PackedInt32Array:
					out.append(t * vs[i])
	for c in n.get_children():
		_tris(c, root, out)


## Every EYE_EVERY-th vertex of the arms' mesh `mesh_name` that a left finger's bone carries, as the skeleton poses it
## now, in `root`'s space: those on the replica's far side.
func _finger_points(hands: ReplicaView, root: Node3D, mesh_name: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var mi := hands._arms._model.find_child(mesh_name, true, false) as MeshInstance3D
	var sk := hands._arms._skeleton
	sk.force_update_all_bone_transforms()
	var binds: Array[Transform3D] = []
	var fingers: Array[bool] = []
	for b in mi.skin.get_bind_count():
		var bone := mi.skin.get_bind_bone(b)
		if bone < 0:
			bone = sk.find_bone(mi.skin.get_bind_name(b))
		binds.append(sk.get_bone_global_pose(bone) * mi.skin.get_bind_pose(b))
		var bone_name := sk.get_bone_name(bone)
		var is_finger := false
		for f in FINGERS:
			is_finger = is_finger or (bone_name.begins_with(f) and bone_name.ends_with("_L"))
		fingers.append(is_finger)
	var to_root := root.global_transform.affine_inverse() * sk.global_transform
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / vs.size()
		for i in range(0, vs.size(), EYE_EVERY):
			var most := 0
			for k in per:
				if weights[i * per + k] > weights[i * per + most]:
					most = k
			if not fingers[bones[i * per + most]]:
				continue
			var p := Vector3.ZERO
			for k in per:
				if weights[i * per + k] > 0.0:
					p += weights[i * per + k] * (binds[bones[i * per + k]] * vs[i])
			out.append(to_root * p)
	return out


## Those of `points` on the replica's far side as `eye` sees them: beyond the plane through the eye and the replica's
## middle line beside them. A sight line that clears the replica on its far side passes its upper right edge, one
## that clears it on the near side its lower left, so the plane parts the two. The hand under the replica, seen on
## the near side, is the hand the owner approved.
func _far_side(eye: Vector3, points: Array[Vector3], tris: PackedVector3Array) -> Array[Vector3]:
	var back := -INF
	var front := INF
	for p in points:
		back = maxf(back, p.z)
		front = minf(front, p.z)
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in tris:
		if v.z >= front and v.z <= back:
			lo = lo.min(v)
			hi = hi.max(v)
	var normal := Vector3.FORWARD.cross((lo + hi) / 2.0 - eye)
	if normal.dot(Vector3.RIGHT) < 0.0:
		normal = -normal
	var out: Array[Vector3] = []
	for p in points:
		if (p - eye).dot(normal) > 0.0:
			out.append(p)
	return out


## How many of `points` the eye at `eye` sees past the triangles `tris` (all in one space): a point is hidden when a
## triangle stands in the way at least EYE_SKIN short of it.
func _seen(eye: Vector3, points: Array[Vector3], tris: PackedVector3Array) -> int:
	if points.is_empty():
		return 0
	# Only the triangles in the cone from the eye round the points can hide them.
	var mid := Vector3.ZERO
	for p in points:
		mid += p
	mid /= points.size()
	var axis := (mid - eye).normalized()
	var half := 0.0
	for p in points:
		half = maxf(half, axis.angle_to(p - eye))
	var near: PackedVector3Array = []
	for i in range(0, tris.size(), 3):
		var a := tris[i]
		var b := tris[i + 1]
		var c := tris[i + 2]
		var centre := (a + b + c) / 3.0
		var reach := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
		if axis.angle_to(centre - eye) < half + reach / maxf(0.01, centre.distance_to(eye)):
			near.append(a)
			near.append(b)
			near.append(c)
	var seen := 0
	for p in points:
		var way := p - eye
		var hidden := false
		for i in range(0, near.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(eye, way, near[i], near[i + 1], near[i + 2])
			if hit != null and eye.distance_to(hit as Vector3) < way.length() - EYE_SKIN:
				hidden = true
				break
		if not hidden:
			seen += 1
	return seen


## The owner (2026-11-12): "You can still see the players fingers on the right side of the AEG. They should not be
## visible: only the thumb of the left hand". Judged as the eye sees it (the critic's second look: a fingertip kept
## under the handguard's top on the replica still showed past its far edge from the eye at the hip): no part of a
## left finger on the replica's far side, gloved or bare, shows past the replica at the hip.
func test_no_left_finger_shows_past_the_replica_from_the_eye_at_the_hip() -> void:
	var cfg := ViewModelConfig.new()
	for id: StringName in HANDGUARD_HELD:
		var hands := _hands(id)
		var held: ReplicaView.Held = hands._held[0]
		held.root.position = cfg.hip.get(id, cfg.hip_default)
		held.root.rotation = Vector3.ZERO
		var tris: PackedVector3Array = []
		_tris(held.root.get_child(0), held.root, tris)
		# The eye is the view's own origin.
		var eye := held.root.transform.affine_inverse() * Vector3.ZERO
		for mesh_name: String in [ArmsView.HAND_PREFIX + "L", ArmsView.SKIN_PREFIX + "L"]:
			var points := _far_side(eye, _finger_points(hands, held.root, mesh_name), tris)
			assert_gt(points.size(), 50, "%s: %s has fingers on the far side to judge" % [id, mesh_name])
			assert_eq(_seen(eye, points, tris), 0,
					"%s: of %d points on %s's fingers, none shows past the replica" % [id, points.size(), mesh_name])


func test_no_finger_under_a_bare_handguard_is_knotted() -> void:
	for id: StringName in RIFLES:
		var hands := _hands(id)
		var sk := hands._arms._skeleton
		for f: String in ["Index", "Middle", "Ring", "Pinky"]:
			for k: int in [1, 2, 3]:
				var bone := sk.find_bone("%s%d_L" % [f, k])
				var bend := sk.get_bone_rest(bone).basis.get_rotation_quaternion().angle_to(sk.get_bone_pose_rotation(bone))
				assert_lt(bend, MOST_BEND, "%s: %s%d bends %.0f degrees" % [id, f, k, rad_to_deg(bend)])


func _view(first: StringName) -> Array:
	var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(first), ReplicaStats.load_replica(&"pistol")]
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
	c.grounded = true
	c.armament.active = 0
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null, false, [] as Array[Dictionary], 0.0, config)
	v.set_body(models, FigureMix.HUMAN, config.lod_high)
	return [v, c]


func test_a_bot_holds_every_rifle_s_handguard_where_the_arms_do() -> void:
	for id: StringName in RIFLES:
		var r := _view(id)
		var v: FigureView = r[0]
		var c: Character = r[1]
		var sk := v.body().skeleton
		var out := {}
		var grab := func() -> void:
			out[config.hold_hand + "_L"] = sk.get_bone_global_pose(sk.find_bone(config.hold_hand + "_L"))
		for i in 40:
			v.update(c, 1.0)
			v.animate(c, 1.0, DT, EYE)
		sk.skeleton_updated.connect(grab)
		v.update(c, 1.0)
		v.animate(c, 1.0, DT, EYE)
		await wait_process_frames(1)
		sk.skeleton_updated.disconnect(grab)
		var hands := v.body().hands
		var slot := hands.in_hand
		var held := hands.held(slot)
		assert_not_null(held, "%s: a hold" % id)
		assert_almost_eq(v.body().bend.support, 1.0, 0.01, "%s: the left hand supports" % id)
		var replica := hands.replica(slot).transform
		var hand: Transform3D = replica.affine_inverse() * (out[config.hold_hand + "_L"] as Transform3D)
		assert_lt(hand.origin.distance_to(held.left.origin), PLACE, "%s: the hand where the arms' is" % id)
		var turned := Quaternion(hand.basis.orthonormalized()).angle_to(Quaternion(held.left.basis.orthonormalized()))
		assert_lt(turned, TURN, "%s: turned as the arms' is (%.3f rad)" % [id, turned])


func _carried_drop(busy: bool, sprint: bool = false) -> float:
	var cfg := ViewModelConfig.new()
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	var base := ReplicaView.new()
	add_child_autofree(base)
	base.setup(cfg, c.armament.replicas, BoxWorld.new())
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(cfg, c.armament.replicas, BoxWorld.new())
	hands.hands_busy = busy
	c.sprinting = sprint
	var frames := ceili(cfg.carry_time / DT) + 5
	var drop := 0.0
	var plain := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	plain.grounded = true
	for i in frames:
		base.update(plain, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
		hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
	drop = base._held[base._active].root.position.y - hands._held[hands._active].root.position.y
	return drop


func test_busy_hands_carry_the_replica_low_as_a_sprint_does_and_let_it_back() -> void:
	var cfg := ViewModelConfig.new()
	assert_almost_eq(_carried_drop(true), cfg.sprint_drop, 1e-3, "hands on the bomb: carried the whole drop")
	assert_almost_eq(_carried_drop(false), 0.0, 1e-4, "free hands: not carried")
	assert_almost_eq(_carried_drop(false, true), cfg.sprint_drop, 1e-3, "a sprint carries the same")


func test_the_carry_eases_in_and_out_and_is_released_when_the_hands_are_free() -> void:
	var cfg := ViewModelConfig.new()
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(cfg, c.armament.replicas, BoxWorld.new())
	hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
	var y0 := hands._held[hands._active].root.position.y
	hands.hands_busy = true
	var share := 0.0
	var first := 0.0
	# A quarter of the way in by time, the eased share is well under a quarter (smoothstep 0.156).
	var quarter := roundi(cfg.carry_time / DT * 0.25)
	for i in quarter:
		hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
	first = (y0 - hands._held[hands._active].root.position.y) / cfg.sprint_drop
	assert_lt(first, 0.22, "a slow start (%.2f of the drop a quarter in)" % first)
	assert_gt(first, 0.05, "but under way")
	for i in ceili(cfg.carry_time / DT):
		hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
	share = (y0 - hands._held[hands._active].root.position.y) / cfg.sprint_drop
	assert_almost_eq(share, 1.0, 0.03, "all the way down")
	hands.hands_busy = false
	for i in ceili(cfg.carry_time / DT) + 2:
		hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
	share = (y0 - hands._held[hands._active].root.position.y) / cfg.sprint_drop
	assert_almost_eq(share, 0.0, 0.03, "and back up when the hands are free")


func _posed(player: AnimationPlayer, skeleton: Skeleton3D, clip: StringName, at: float) -> Dictionary:
	player.play(clip)
	player.pause()
	player.seek(at, true)
	skeleton.force_update_all_bone_transforms()
	var out := {}
	for i in skeleton.get_bone_count():
		out[i] = skeleton.get_bone_global_pose(i)
	return out


func test_each_reload_clip_ends_on_the_hold_pose() -> void:
	var model := (load(MODEL_PATH) as PackedScene).instantiate()
	add_child_autofree(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var pairs: Array[Array] = []
	for id: StringName in RIFLES:
		pairs.append([StringName("%s_Hold" % id), StringName("%s_Reload" % id)])
	for id: StringName in [&"aeg", &"sniper"]:
		for key: String in GRIPS:
			pairs.append([StringName("%s_grip_%s_Hold" % [id, key]), StringName("%s_grip_%s_Reload" % [id, key])])
	for pair: Array in pairs:
		assert_true(player.has_animation(pair[1]), "the model has %s" % pair[1])
		var hold := _posed(player, skeleton, pair[0], 0.0)
		var end := _posed(player, skeleton, pair[1], player.get_animation(pair[1]).length)
		var worst := 0.0
		var worst_turn := 0.0
		var where := ""
		for i: int in hold:
			var a: Transform3D = hold[i]
			var b: Transform3D = end[i]
			var d := a.origin.distance_to(b.origin)
			var t := Quaternion(a.basis.orthonormalized()).angle_to(Quaternion(b.basis.orthonormalized()))
			if d > worst:
				worst = d
				where = skeleton.get_bone_name(i)
			worst_turn = maxf(worst_turn, t)
		assert_lt(worst, END_PLACE, "%s ends on %s: %s %.4f m off" % [pair[1], pair[0], where, worst])
		assert_lt(worst_turn, END_TURN, "%s ends on %s: %.3f rad off" % [pair[1], pair[0], worst_turn])

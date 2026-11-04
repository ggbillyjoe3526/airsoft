extends GutTest
## FB5 QA: the high ready under the states a match puts a figure in (the hit call, the walk-off, a reload, a switch,
## crouched, leaning, in the air, vaulting, the pistol), the arms' IK at its limits, hidden and shown again, the ray
## spread over figures, and that the raise only draws (the hit volume and the character stay as they were).
## Rigged poses are read as the skeleton finishes updating (test_figure_raise.gd).

const FRAME := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 3.0)
## How far (m) an arm bone may stretch past its rest length.
const STRETCH := 0.02
const ARMS: Array = [["UpperArm_R", "Forearm_R", "Hand_R"], ["UpperArm_L", "Forearm_L", "Hand_L"]]

var config: FigureConfig = null
var models: FigureModels = null
var hits: HitConfig = null
var body: BodyConfig = null
## What the skeleton last drew, by figure: every bone finite, and the longest an arm bone stretched past its rest.
var _finite: Dictionary[FigureView, bool] = {}
var _stretch: Dictionary[FigureView, float] = {}
var _muzzle: Dictionary[FigureView, Vector3] = {}


class CountedWorld:
	extends BoxWorld
	var rays: int = 0

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		rays += 1
		return super.ray(from, to, hit)


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()
	hits = HitConfig.new()
	body = BodyConfig.new()


func _character(slot: int = 0, id: int = 1) -> Character:
	var c := Character.new(id, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	c.armament.active = slot
	return c


static func _wall(world: BoxWorld, distance: float) -> void:
	world.add_box(Vector3(0.0, 1.5, -distance - 0.1), Vector3(4.0, 3.0, 0.2))


func _view(kind: int, c: Character, world: WorldQuery) -> FigureView:
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null)
	v.set_body(models, kind, config.lod_high)
	if world != null:
		v.set_world(world, body)
	var sk := v.body().skeleton
	sk.skeleton_updated.connect(func() -> void:
		var ok := true
		for i in sk.get_bone_count():
			var t := sk.get_bone_global_pose(i)
			ok = ok and t.origin.is_finite() and t.basis.x.is_finite() and t.basis.y.is_finite() \
					and t.basis.z.is_finite()
		var most := 0.0
		for arm: Array in ARMS:
			var fore := sk.find_bone(arm[1])
			var hand := sk.find_bone(arm[2])
			var up := sk.get_bone_global_pose(sk.find_bone(arm[0])).origin
			var elbow := sk.get_bone_global_pose(fore).origin
			var wrist := sk.get_bone_global_pose(hand).origin
			most = maxf(most, up.distance_to(elbow) - sk.get_bone_rest(fore).origin.length())
			most = maxf(most, elbow.distance_to(wrist) - sk.get_bone_rest(hand).origin.length())
		_finite[v] = ok
		_stretch[v] = most
		if v.muzzle_shown(c.armament.active):
			_muzzle[v] = v.global_transform.affine_inverse() * v.muzzle_position(c.armament.active))
	return v


func _run(v: FigureView, c: Character, frames: int, shooting: bool = false) -> void:
	for i in frames:
		if shooting:
			v.on_shot()
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, EYE)
	await wait_process_frames(1)


## A state a figure is in, set on `c` (0..): 0 standing, 1 crouched, 2 leaning left, 3 leaning right, 4 in the air, 5
## vaulting, 6 mid reload, 7 mid switch to the pistol, 8 the pistol, 9 calling the hit, 10 walking off.
func _state(c: Character, s: int) -> void:
	match s:
		1:
			c.crouch_amount = 1.0
			c.prev_crouch_amount = 1.0
		2:
			c.lean = -1.0
			c.prev_lean = -1.0
		3:
			c.lean = 1.0
			c.prev_lean = 1.0
		4:
			c.grounded = false
			c.air_time = 0.2
		5:
			c.vault.active = true
			c.vault.rise_end = 0.2
			c.vault.end = 0.6
			c.vault.time = 0.1
		6:
			c.armament.reload_left = c.armament.replicas[0].reload_time * 0.5
		7:
			c.armament.active = 1
			c.armament.draw_total = 0.5
			c.armament.draw_left = 0.25
		8:
			c.armament.active = 1
		9:
			c.status = Character.Status.CALLING
		10:
			c.status = Character.Status.WALKING_OFF


func test_no_bone_goes_non_finite_and_no_arm_stretches_in_any_state_at_a_wall() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		for s in 11:
			var c := _character()
			_state(c, s)
			var world := BoxWorld.new(body)
			_wall(world, 0.45)
			var bare := _view(kind, c, null)
			var v := _view(kind, c, world)
			await _run(bare, c, 30)
			await _run(v, c, 30)
			var what := "kind %d state %d" % [kind, s]
			assert_true(_finite[v], "%s: every bone finite" % what)
			assert_lte(_stretch[v], maxf(_stretch[bare], 0.0) + STRETCH, "%s: no arm stretched by the raise" % what)


func test_the_arms_reach_at_its_limits_stays_finite() -> void:
	var c := _character()
	var v := _view(FigureMix.HUMAN, c, null)
	await _run(v, c, 5)
	var sk := v.body().skeleton
	for arm: Array in ARMS:
		var up := sk.find_bone(arm[0])
		var fore := sk.find_bone(arm[1])
		var hand := sk.find_bone(arm[2])
		var shoulder := sk.get_bone_global_pose(up).origin
		var reach := sk.get_bone_global_pose(hand).origin - shoulder
		var length := shoulder.distance_to(sk.get_bone_global_pose(fore).origin) \
				+ sk.get_bone_global_pose(fore).origin.distance_to(sk.get_bone_global_pose(hand).origin)
		var targets: Array[Vector3] = [shoulder, shoulder + reach.normalized() * length,
				shoulder + reach.normalized() * length * 3.0, shoulder - reach.normalized() * length * 0.5,
				shoulder + Vector3.DOWN * 1e-5, shoulder + Vector3.UP * length, shoulder + Vector3.BACK * length * 0.99]
		for t: Vector3 in targets:
			FigureReady.reach(sk, up, fore, hand, Transform3D(Basis.IDENTITY, t))
			for b: int in [up, fore, hand]:
				var p := sk.get_bone_global_pose(b)
				assert_true(p.origin.is_finite() and p.basis.x.is_finite() and p.basis.y.is_finite()
						and p.basis.z.is_finite(), "%s finite for a target %s" % [sk.get_bone_name(b), str(t)])
				assert_true(absf(p.basis.determinant()) > 0.5, "%s kept its scale" % sk.get_bone_name(b))
			sk.reset_bone_poses()


func test_a_raised_figure_leaves_the_hit_volume_and_the_character_untouched() -> void:
	var c := _character()
	c.position = Vector3(0.3, 0.0, 0.2)
	c.prev_position = c.position
	c.yaw = 0.4
	c.pitch = 0.2
	c.lean = 0.5
	c.prev_lean = 0.5
	var before := Hitbox.Volume.new()
	Hitbox.build_volume(c, hits, before)
	var yaw := c.yaw
	var pitch := c.pitch
	var at := c.position
	var world := BoxWorld.new(body)
	world.add_box(c.position + Vector3(-0.2, 1.5, -0.5), Vector3(6.0, 3.0, 0.2))
	var v := _view(FigureMix.HUMAN, c, world)
	v.rotation.y = c.yaw
	v.position = c.position
	await _run(v, c, 40)
	assert_gt(v.body().bend.high_ready, 0.5, "the feature engaged (the replica was raised)")
	var after := Hitbox.Volume.new()
	Hitbox.build_volume(c, hits, after)
	assert_eq(c.yaw, yaw)
	assert_eq(c.pitch, pitch)
	assert_eq(c.position, at)
	assert_eq(after.head.a, before.head.a)
	assert_eq(after.parts.size(), before.parts.size())
	for i in before.parts.size():
		assert_eq(after.parts[i].a, before.parts[i].a, "part %d" % i)
		assert_eq(after.parts[i].b, before.parts[i].b, "part %d" % i)
		assert_eq(after.parts[i].r, before.parts[i].r, "part %d" % i)


func test_the_replica_is_level_within_a_quarter_second_of_the_first_shot_at_a_wall() -> void:
	var c := _character()
	var world := BoxWorld.new(body)
	_wall(world, 0.5)
	var v := _view(FigureMix.HUMAN, c, world)
	await _run(v, c, 40)
	var raised := _muzzle[v].y
	var level := _view(FigureMix.HUMAN, c, null)
	await _run(level, c, 40)
	# The BL1 carbine (about 67 cm) clears a wall 0.5 m ahead with a smaller tilt than the old rifle did: ~0.1 m up.
	assert_gt(raised, _muzzle[level].y + 0.07, "raised before the shot (the muzzle well up)")
	# From the shot, 15 frames (0.25 s) later the muzzle is back at the shoulder.
	await _run(v, c, 15, true)
	assert_almost_eq(_muzzle[v].y, _muzzle[level].y, 0.08, "level 0.25 s into a burst")


func test_hidden_and_shown_again_the_raise_is_not_stale() -> void:
	# A figure raised at a wall, hidden (a spectated bot's own, or a round change) while the character turned away: shown
	# again, its first pose must not draw the old raise (either ray parity).
	for extra: int in [0, 1]:
		var c := _character()
		var world := BoxWorld.new(body)
		_wall(world, 0.45)
		var v := _view(FigureMix.HUMAN, c, world)
		await _run(v, c, 40 + extra)
		assert_gt(v.body().bend.high_ready, 0.9, "raised at the wall")
		v.visible = false
		v.animate(c, 1.0, FRAME, EYE)
		c.yaw = PI
		c.prev_yaw = PI
		v.visible = true
		await _run(v, c, 1)
		assert_lt(v.body().bend.high_ready, 0.2, "shown facing open ground: not raised (parity %d)" % extra)


func test_hidden_figures_cast_no_rays_and_a_null_world_none() -> void:
	var c := _character()
	var world := CountedWorld.new(body)
	_wall(world, 0.5)
	var v := _view(FigureMix.HUMAN, c, world)
	await _run(v, c, 4)
	var before := world.rays
	v.visible = false
	for i in 20:
		v.animate(c, 1.0, FRAME, EYE)
	assert_eq(world.rays, before, "hidden: no ray")
	var far := Vector3(0.0, 1.6, 400.0)
	v.visible = true
	await _run(v, c, 2)
	before = world.rays
	for i in 40:
		v.animate(c, 1.0, FRAME, far)
	assert_lte(world.rays - before, 40 / maxi(config.far_stride, 1), "beyond the far line: no more rays than poses")
	var bare := _view(FigureMix.HUMAN, c, null)
	await _run(bare, c, 10)
	assert_eq(bare.body().bend.high_ready, 0.0, "no world (menus, previews): never raised")
	bare.set_world(null, null)
	await _run(bare, c, 10)
	assert_eq(bare.body().bend.high_ready, 0.0, "a world handed back as null: still level")


func test_figures_of_odd_and_even_ids_cast_on_different_frames() -> void:
	var world := CountedWorld.new(body)
	_wall(world, 0.6)
	var a := _character(0, 0)
	var b := _character(0, 1)
	var va := _view(FigureMix.HUMAN, a, world)
	var vb := _view(FigureMix.HUMAN, b, world)
	va.character_id = 0
	vb.character_id = 1
	va.set_world(world, body)
	vb.set_world(world, body)
	var per_frame: Array[int] = []
	for i in 12:
		var n := world.rays
		va.update(a, 1.0)
		va.animate(a, 1.0, FRAME, EYE)
		vb.update(b, 1.0)
		vb.animate(b, 1.0, FRAME, EYE)
		per_frame.append(world.rays - n)
	for n: int in per_frame:
		assert_eq(n, 1, "one ray a frame across two figures, not two then none: %s" % str(per_frame))


func test_the_ray_never_sees_another_figure_only_the_level_asks() -> void:
	# The view asks the WorldQuery alone; a teammate in front is not in it. (The level's ray masks the world layer.)
	var c := _character()
	var world := BoxWorld.new(body)
	var v := _view(FigureMix.HUMAN, c, world)
	await _run(v, c, 30)
	assert_eq(v.body().bend.high_ready, 0.0, "open ground: level")
	var mate := _character(0, 2)
	mate.position = Vector3(0.0, 0.0, -0.5)
	mate.prev_position = mate.position
	var other := _view(FigureMix.HUMAN, mate, world)
	other.position = mate.position
	await _run(v, c, 30)
	assert_eq(v.body().bend.high_ready, 0.0, "a figure 0.5 m ahead does not raise it")


func test_shown_again_at_a_wall_it_is_raised_within_a_few_frames_whatever_the_ray_parity() -> void:
	for extra: int in [0, 1]:
		var c := _character()
		var world := BoxWorld.new(body)
		_wall(world, 0.45)
		var v := _view(FigureMix.HUMAN, c, world)
		await _run(v, c, 40 + extra)
		v.visible = false
		v.animate(c, 1.0, FRAME, EYE)
		v.visible = true
		var seen: Array[float] = []
		for i in 12:
			v.update(c, 1.0)
			v.animate(c, 1.0, FRAME, EYE)
			seen.append(v.body().bend.high_ready)
		# A ray this pose: raised at once; none yet: level, then eased up (no stale raise, no step half way).
		assert_true(seen[0] < 0.01 or seen[0] > 0.9, "level or fully raised on the first pose: %s" % str(seen))
		assert_gt(seen[11], 0.85, "raised again within 12 poses, parity %d: %s" % [extra, str(seen)])
		for i in range(1, seen.size()):
			assert_gte(seen[i], seen[i - 1] - 0.001, "rising, never flickering, parity %d" % extra)


func test_a_wall_at_the_edge_of_reach_never_makes_the_raise_flicker() -> void:
	# The target hovers around none (the level at the reach's edge, a figure's own sway): the drawn raise never jumps.
	for edge: float in [config.raise_reach_rifle - 0.002, config.raise_reach_rifle - 0.0001,
			config.raise_reach_rifle + 0.0001]:
		var c := _character()
		var world := BoxWorld.new(body)
		_wall(world, edge)
		var v := _view(FigureMix.HUMAN, c, world)
		var last := 0.0
		for i in 60:
			# The figure sways in and out across the edge of reach every other pose.
			c.position.z = 0.0005 * float(i % 2)
			c.prev_position = c.position
			v.update(c, 1.0)
			v.position = c.position
			v.animate(c, 1.0, FRAME, EYE)
			var now := v.body().bend.high_ready
			assert_lt(absf(now - last), 0.05, "no jump at pose %d (edge %.4f)" % [i, edge])
			last = now

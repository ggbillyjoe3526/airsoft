extends GutTest
## HV1 QA: poses the registration test leaves out (leaning, aiming up, running, the walk between samples), a fast BB
## from far off, the quick test that keeps a far character's volume unbuilt, and a BB flying past a far character.

const POSES: Array[StringName] = [&"lean_left", &"lean_right", &"aim_up", &"run_1", &"run_2", &"run_3", &"walk_1",
		&"crouch_half"]
const STRIDE := 4
const BACK := 3.0
const SPEED := 160.0
const MASS := 0.28e-3
const DT := 1.0 / 60.0
const STRIKE_SHARE := 0.93
const PASS_SHARE := 0.95
const SHOOTER := 2
const TARGET := 1

var models: FigureModels = null
var probe: HitAreaProbe = null
var holder: Node3D = null
var tuning: SimTuning = null


func before_all() -> void:
	models = FigureModels.new(FigureConfig.new())
	models.load_kinds()
	tuning = SimTuning.new()
	tuning.hits.friendly_fire = false
	holder = Node3D.new()
	add_child(holder)
	probe = HitAreaProbe.new(models, tuning.hits, MovementConfig.new(), holder)


func after_all() -> void:
	probe.free_bodies()
	holder.free()


func test_leaning_aiming_up_and_running_figures_are_struck_and_the_air_beside_them_passes() -> void:
	var head: StringName = probe.heads(FigureMix.HUMAN)[0]
	for pose in POSES:
		for inside: bool in [true, false]:
			var rays := probe.drawn_rays(FigureMix.HUMAN, head, pose, PI * 0.25, STRIDE, BACK, inside)
			var fired := rays.size() / 2
			var struck := _fire(pose, rays)
			assert_gt(fired, 20, "%s: rays fired" % pose)
			if inside:
				assert_gte(float(struck) / maxf(fired, 1.0), STRIKE_SHARE, "%s: %d of %d at the body struck" % [
						pose, struck, fired])
			else:
				assert_gte(1.0 - float(struck) / maxf(fired, 1.0), PASS_SHARE, "%s: %d of %d beside struck" % [
						pose, struck, fired])


func test_a_jumping_figure_is_struck_at_the_chest() -> void:
	var c := Character.new(TARGET, 0, Vector3(0.0, 0.5, 0.0), 0.0, ReplicaStats.default_loadout())
	c.grounded = false
	c.velocity = Vector3(0.0, 2.0, 0.0)
	var volume := Hitbox.Volume.new()
	Hitbox.build_volume(c, tuning.hits, volume)
	var chest_y := c.position.y + 1.2
	var d := Hitbox.ray_character(Vector3(0.0, chest_y, 3.0), Vector3(0.0, 0.0, -1.0), 6.0, volume)
	assert_lt(d, INF, "a BB at the airborne figure's chest strikes it")
	var beside := Hitbox.ray_character(Vector3(0.6, chest_y, 3.0), Vector3(0.0, 0.0, -1.0), 6.0, volume)
	assert_eq(beside, INF, "a BB 60 cm beside it flies on")


func test_a_bb_fast_enough_to_cross_a_body_in_a_tick_still_strikes_it() -> void:
	var target := Character.new(TARGET, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	target.grounded = true
	var shooter := Character.new(SHOOTER, 0, Vector3(60.0, 0.0, 60.0), 0.0, ReplicaStats.default_loadout())
	var characters: Array[Character] = [target, shooter]
	var pool := BBPool.new(1)
	# One tick at 400 m/s is 6.7 m: the BB starts 3 m in front and ends 3.7 m behind the target.
	pool.spawn(SHOOTER, Vector3(0.0, 1.2, 3.0), Vector3(0.0, 0.0, -1.0), 400.0, 0.0, MASS, 0.0)
	var events := SimEvents.new()
	var ends: Array[MapEnd] = []
	BBStep.step(pool, characters, WorldQuery.new(), tuning, -10.0, false, ends, events, DT)
	var struck := 0
	for i in events.count:
		if events.items[i].target == TARGET:
			struck += 1
	assert_gt(struck, 0, "a 400 m/s BB does not tunnel through the body")


func test_a_far_character_is_not_touched_and_a_near_one_is() -> void:
	var c := Character.new(TARGET, 0, Vector3(30.0, 0.0, 0.0), 0.0, ReplicaStats.default_loadout())
	var hits := tuning.hits
	assert_false(Hitbox.may_touch(c, Vector3.ZERO, Vector3(0.0, 0.0, -1.0), 50.0, hits), "a line 30 m off")
	assert_true(Hitbox.may_touch(c, Vector3(30.0, 1.0, 5.0), Vector3(0.0, 0.0, -1.0), 50.0, hits), "a line through it")
	assert_false(Hitbox.may_touch(c, Vector3(30.0, 1.0, 5.0), Vector3(0.0, 0.0, -1.0), 2.0, hits), "a segment ending short")


func test_a_standing_figure_under_the_volume_top_is_never_skipped_by_the_quick_test() -> void:
	# The quick test must never reject a ray the full volume would strike, in any fitted pose.
	var volume := Hitbox.Volume.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		var c := Character.new(TARGET, 0, Vector3.ZERO, rng.randf() * TAU, ReplicaStats.default_loadout())
		c.grounded = i % 7 != 0
		c.crouch_amount = [0.0, 1.0, 0.5][i % 3]
		c.lean = rng.randf_range(-1.0, 1.0)
		c.pitch = rng.randf_range(-1.2, 1.2)
		var way := rng.randf() * TAU
		c.velocity = Vector3(sin(way), 0.0, -cos(way)) * rng.randf_range(0.0, 6.0)
		Hitbox.build_volume(c, tuning.hits, volume)
		for k in 40:
			var o := Vector3(rng.randf_range(-3.0, 3.0), rng.randf_range(0.0, 2.2), rng.randf_range(-3.0, 3.0))
			var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.3), rng.randf_range(-1.0, 1.0)).normalized()
			var hit := Hitbox.ray_character(o, d, 8.0, volume)
			if hit < INF:
				assert_true(Hitbox.may_touch(c, o, d, 8.0, tuning.hits), "state %d ray %d: struck, so may touch" % [i, k])


func _fire(pose_name: StringName, rays: PackedVector3Array) -> int:
	var target := probe.character(pose_name)
	target.id = TARGET
	var shooter := Character.new(SHOOTER, target.team, Vector3(60.0, 0.0, 60.0), 0.0, ReplicaStats.default_loadout())
	var characters: Array[Character] = [target, shooter]
	var pool := BBPool.new(rays.size() / 2)
	for i in range(0, rays.size(), 2):
		pool.spawn(SHOOTER, rays[i], rays[i + 1], SPEED, 0.0, MASS, tuning.ballistics.spin_per_hop)
	var events := SimEvents.new()
	var ends: Array[MapEnd] = []
	for t in 3:
		BBStep.step(pool, characters, WorldQuery.new(), tuning, -10.0, false, ends, events, DT)
	var struck := 0
	for i in events.count:
		var e := events.items[i]
		if e.target == TARGET and (e.kind == GameEvent.Kind.BB_IMPACT or e.kind == GameEvent.Kind.CHARACTER_HIT):
			struck += 1
	return struck

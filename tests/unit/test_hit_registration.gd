extends GutTest
## HV1: a BB fired at the figure you see strikes the body, and one fired just beside it flies past, through BBStep as
## in a match. The owner's report (2026-11-03): "I'm sure I'm hitting the target but it's not registering"; the
## built-in volume missed 25 to 36 % of a crouched, crouch-walking or running figure (FI7). Rays on a grid from three
## sides (HitAreaProbe.drawn_rays): inside the drawn body (arms left out, as the volume leaves them) and just outside it.
## The BBs fly at a sniper spring's speed and more, so a fast BB that crosses a body inside one tick is caught too.

## The poses fired at (HitAreaProbe.POSES), the sides (rad round +Y from the figure's back), the grid's stride (cells)
## and how far out each BB starts (m).
const POSES: Array[StringName] = [&"stand", &"crouch", &"crouch_walk", &"crouch_back", &"run_0", &"between",
		&"aim_down", &"vault"]
const SIDES: Array[float] = [0.0, PI * 0.25, PI * 0.5]
const STRIDE := 4
const BACK := 3.0
## A BB this fast crosses BACK m in about one tick.
const SPEED := 160.0
const MASS := 0.28e-3
const DT := 1.0 / 60.0
const TICKS := 3
## The least share of BBs fired at the drawn body that strike it, and of BBs fired beside it that pass: M85's bar (4 %
## missed over the whole figure) with room for one side of one pose on this coarser grid. The built-in volume struck 64
## to 75 % of a crouched, crouch-walking or running figure.
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
	# Teammates with friendly fire off: a BB that reaches the target stops on it and leaves it in play, so the next BB
	# meets the same pose (a hit would start the hit call).
	tuning.hits.friendly_fire = false
	holder = Node3D.new()
	add_child(holder)
	probe = HitAreaProbe.new(models, tuning.hits, MovementConfig.new(), holder)


func after_all() -> void:
	probe.free_bodies()
	holder.free()


func test_a_bb_fired_at_the_drawn_figure_strikes_it_in_every_pose_from_every_side() -> void:
	var head: StringName = probe.heads(FigureMix.HUMAN)[0]
	for pose in POSES:
		for side in SIDES:
			var rays := probe.drawn_rays(FigureMix.HUMAN, head, pose, side, STRIDE, BACK, true)
			var struck := _fire(pose, rays)
			var fired := rays.size() / 2
			assert_gt(fired, 50, "%s from %.2f rad: rays at the drawn body" % [pose, side])
			assert_gte(float(struck) / maxf(fired, 1.0), STRIKE_SHARE,
					"%s from %.2f rad: %d of %d BBs at the drawn body struck it" % [pose, side, struck, fired])


func test_a_bb_fired_just_beside_the_drawn_figure_passes_it() -> void:
	var head: StringName = probe.heads(FigureMix.HUMAN)[0]
	for pose in POSES:
		for side in SIDES:
			var rays := probe.drawn_rays(FigureMix.HUMAN, head, pose, side, STRIDE, BACK, false)
			var struck := _fire(pose, rays)
			var fired := rays.size() / 2
			assert_gt(fired, 20, "%s from %.2f rad: rays beside the drawn body" % [pose, side])
			assert_gte(1.0 - float(struck) / maxf(fired, 1.0), PASS_SHARE,
					"%s from %.2f rad: %d of %d BBs beside the drawn body struck it" % [pose, side, struck, fired])


func test_the_fit_is_what_a_match_uses() -> void:
	var shipped := load("res://game/config/sim_tuning.tres") as SimTuning
	assert_not_null(shipped.hits.fit, "the shipped tuning's hits carry the fit")
	assert_true(shipped.hits.fit.is_complete(), "every sample baked")
	assert_not_null(HitConfig.new().fit, "a fresh HitConfig carries it too")


## Fires one BB along each (start, way) pair of `rays` at the target posed as `pose_name`, through BBStep for TICKS
## ticks; returns how many stopped on the target.
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
	for t in TICKS:
		BBStep.step(pool, characters, WorldQuery.new(), tuning, -10.0, false, ends, events, DT)
	var struck := 0
	for i in events.count:
		var e := events.items[i]
		if e.target == TARGET and (e.kind == GameEvent.Kind.BB_IMPACT or e.kind == GameEvent.Kind.CHARACTER_HIT):
			struck += 1
	return struck

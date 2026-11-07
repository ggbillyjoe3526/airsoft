extends GutTest
## One seed replays bit-exact (BP7; the known issue MN2's QA found). The cause: the level's static bodies went into the
## physics space before their shapes, and Jolt answered rays and sweeps a rounding apart until the space's first step,
## so a match whose first ticks came before that step (built in one frame) played differently from one built over the
## loading screen's frames. MapLevel now adds each body with its shapes.
##
## Two matches of one seed, each a PlaySession of its own played by the bots (you on autopilot), built one after the
## other (the first freed before the second is made, as main.gd does) and stepped tick by tick, match on every tick:
## every character's position, velocity and view, the simulation clock and the BBs fired so far, then the random
## stream. One is built in a single frame, before any physics step, and the other staged over frames (the vault links'
## search in time slices, the cover on a worker thread). Two sessions alive at once in one physics space drift by about
## 2e-6 m by tick 900 (each one's movers meet the other's colliders); the game never has two.

const SEED := 5
const TICKS := 600
## How long a staged build may take (s).
const LOAD_LIMIT := 120.0
## Rays and sweeps the level is probed with, each.
const PROBES := 3000


## Per tick, the state the replay must match exactly; the last row is the random stream's state.
func _trace(staged: bool) -> Array[PackedFloat64Array]:
	var s := PlaySession.new()
	s.autopilot = true
	s.settings = Settings.new()
	s.match_seed = SEED
	s.staged = staged
	add_child(s)
	if staged:
		await wait_until(func() -> bool: return s._running, LOAD_LIMIT)
	assert_true(s._running, "the match is built")
	# Stepped by hand, not by the pacer.
	s._holding = true
	var out: Array[PackedFloat64Array] = []
	for t in TICKS:
		s._tick()
		var row := PackedFloat64Array()
		row.append(s.state.time)
		row.append(s.state.bbs.next_serial)
		for c in s.state.characters:
			row.append_array([c.position.x, c.position.y, c.position.z, c.velocity.x, c.velocity.y, c.velocity.z,
					c.yaw, c.pitch])
		out.append(row)
	out.append(PackedFloat64Array([s.state.rng.state]))
	remove_child(s)
	s.free()
	await wait_physics_frames(2)
	return out


func test_one_seed_replays_bit_exact_built_at_once_or_staged() -> void:
	var a := await _trace(false)
	var b := await _trace(true)
	assert_eq(a.size(), b.size())
	var first := -1
	for t in mini(a.size(), b.size()):
		if a[t] != b[t]:
			first = t
			break
	assert_eq(first, -1, "no tick differs (the first that does: %d)" % first)
	if first >= 0:
		for i in a[first].size():
			if a[first][i] != b[first][i]:
				gut.p("tick %d, value %d: %.12f against %.12f" % [first, i, a[first][i], b[first][i]])
	# The bots went somewhere: the match was played, not stood still.
	var moved := 0.0
	var start := a[0]
	var end := a[TICKS - 1]
	for i in range(2, start.size(), 8):
		moved = maxf(moved, Vector2(end[i] - start[i], end[i + 2] - start[i + 2]).length())
	assert_gt(moved, 5.0, "the bots went somewhere")


## PROBES seeded rays and mover sweeps over `level`; NaN (no ground) as -1 so the rows compare.
func _probe(level: MapLevel, body: BodyConfig) -> PackedFloat64Array:
	var q := level.query()
	var mover := level.mover(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var out := PackedFloat64Array()
	var hit := RayHit.new()
	for i in PROBES:
		var a := Vector3(rng.randf_range(-50.0, 50.0), rng.randf_range(0.2, 3.0), rng.randf_range(-30.0, 30.0))
		var b := Vector3(rng.randf_range(-50.0, 50.0), rng.randf_range(0.0, 3.0), rng.randf_range(-30.0, 30.0))
		if q.sight_ray(a, b, hit):
			out.append_array([hit.position.x, hit.position.y, hit.position.z, hit.normal.x, hit.normal.y, hit.normal.z])
		else:
			out.append(-1.0)
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	for i in PROBES:
		c.position = Vector3(rng.randf_range(-50.0, 50.0), 0.05, rng.randf_range(-30.0, 30.0))
		c.grounded = true
		var d := mover.move(c, Vector3(rng.randf_range(-0.2, 0.2), -0.01, rng.randf_range(-0.2, 0.2)))
		var ground := mover.probe_ground(c, 0.5)
		out.append_array([d.x, d.y, d.z, -1.0 if is_nan(ground) else ground])
	return out


func test_the_level_answers_the_same_before_and_after_its_first_physics_step() -> void:
	var tuning := SimTuning.load_default()
	var style := MapStyle.new()
	var map := MapData.load_map("depot", style, tuning.rounds.team_size)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, style, tuning.body)
	var before := _probe(level, tuning.body)
	await wait_physics_frames(3)
	var after := _probe(level, tuning.body)
	var differ := 0
	for i in mini(before.size(), after.size()):
		if before[i] != after[i]:
			differ += 1
	assert_eq(before.size(), after.size())
	assert_eq(differ, 0, "every ray and sweep the same (before BP7 about one ray value in 20 differed)")
	assert_gt(before.size(), PROBES * 5, "most rays hit something")

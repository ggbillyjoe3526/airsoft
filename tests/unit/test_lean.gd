extends GutTest
## Leaning (game/sim/lean.gd), ported from the browser game's sim/lean.test.ts, plus the one geometry reaching the hit
## volume (Hitbox) and the BB origin (Simulation): a leaned body is hit where it appears and nowhere else, a lean stops
## short of a wall, and BBs leave from the leaned eyes. Walls are BoxWorld boxes. Vector3 is 32-bit: 1e-5 m.

const DT := 1.0 / 60.0
const CLOSE := 1e-5

var tuning: SimTuning = SimTuning.new()
var hits: HitConfig = tuning.hits
var body: BodyConfig = tuning.body
var move: MovementConfig = tuning.movement
var open_sky: BoxWorld = BoxWorld.new(body)


## A wall whose face is the plane x = `wall_x`, the wall beyond it (+x).
func wall_at_x(wall_x: float) -> BoxWorld:
	var w := BoxWorld.new(body)
	w.add_box(Vector3(wall_x + 1.0, 1.5, 0.0), Vector3(2.0, 4.0, 10.0))
	return w


## A character at the origin facing -Z (its right is +X), standing on the ground.
func standing() -> Character:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0)
	c.grounded = true
	return c


func hold(c: Character, lean: float, seconds: float, query: WorldQuery = open_sky) -> void:
	var cmd := PlayerCommand.new()
	cmd.lean = lean
	for i in roundi(seconds / DT):
		Lean.step(c, cmd, tuning, query, DT)


func test_swings_points_above_the_hips_out_along_the_right_and_a_little_down() -> void:
	var above := body.stand_eye_height - hits.pivot_height
	var out := Lean.offset(body.stand_eye_height, 1.0, 0.0, 0.0, hits)
	assert_almost_eq(out.x, above * sin(hits.lean_max_angle), CLOSE)
	assert_almost_eq(out.y, -above * (1.0 - cos(hits.lean_max_angle)), CLOSE)
	assert_almost_eq(out.z, 0.0, CLOSE)
	assert_gt(out.x, 0.35, "about 0.4 m: enough to see past a corner from a body-width back")
	assert_lt(Lean.offset(body.stand_eye_height, -1.0, 0.0, 0.0, hits).x, -0.35)
	# Facing +X (yaw -90°), the right is +Z.
	out = Lean.offset(body.stand_eye_height, 1.0, 0.0, -PI / 2.0, hits)
	assert_gt(out.z, 0.35)
	assert_almost_eq(out.x, 0.0, CLOSE)


func test_leaves_the_hips_and_legs_where_they_are_and_pivots_lower_crouched() -> void:
	assert_eq(Lean.offset(hits.pivot_height, 1.0, 0.0, 0.0, hits), Vector3.ZERO)
	assert_eq(Lean.offset(0.5, 1.0, 0.0, 0.0, hits), Vector3.ZERO)
	assert_eq(Lean.offset(body.stand_eye_height, 0.0, 0.0, 0.0, hits), Vector3.ZERO, "upright")
	assert_gt(Lean.offset(Character.eye_height(1.0, body), 1.0, 1.0, 0.0, hits).x, 0.35,
			"crouched, the lower eyes move about as far")


func test_puts_the_eyes_where_bbs_leave_from_at_the_leaned_position() -> void:
	var c := standing()
	c.lean = 1.0
	var eye := Lean.eye(c, body, hits)
	var out := Lean.offset(body.stand_eye_height, 1.0, 0.0, 0.0, hits)
	assert_almost_eq(eye.x, out.x, CLOSE)
	assert_almost_eq(eye.y, body.stand_eye_height + out.y, CLOSE)
	c.lean = 0.0
	assert_eq(Lean.eye(c, body, hits), c.eye(body), "upright, the plain eyes")


func test_eases_into_a_full_lean_while_held_and_back_upright_when_released() -> void:
	var c := standing()
	hold(c, 1.0, move.lean_time / 2.0)
	assert_almost_eq(c.lean, 0.5, 0.1)
	hold(c, 1.0, move.lean_time)
	assert_eq(c.lean, 1.0)
	hold(c, 0.0, move.lean_time + DT)
	assert_eq(c.lean, 0.0)
	hold(c, -1.0, 1.0)
	assert_eq(c.lean, -1.0)


func test_straightens_up_in_the_air() -> void:
	var c := standing()
	hold(c, 1.0, 1.0)
	c.grounded = false
	hold(c, 1.0, move.lean_time + DT)
	assert_eq(c.lean, 0.0)


func test_stops_short_of_a_wall_so_the_eyes_keep_their_clearance() -> void:
	var c := standing()
	var wall := wall_at_x(0.45) # at the right shoulder
	hold(c, 1.0, 1.0, wall)
	assert_gt(c.lean, 0.0)
	assert_lt(c.lean, 1.0)
	assert_lt(Lean.eye(c, body, hits).x, 0.45 - move.lean_wall_clearance + CLOSE)
	hold(c, -1.0, 1.0, wall)
	assert_eq(c.lean, -1.0, "leaning away from it is unaffected")


func test_cuts_a_lean_at_once_when_it_would_put_the_head_into_a_wall() -> void:
	var c := standing()
	hold(c, 1.0, 1.0)
	assert_eq(c.lean, 1.0)
	hold(c, 1.0, DT, wall_at_x(0.3)) # the wall is right there now
	assert_lt(Lean.eye(c, body, hits).x, 0.3 - move.lean_wall_clearance + CLOSE)


func test_cannot_lean_at_all_with_a_wall_against_the_body() -> void:
	var c := standing()
	hold(c, 1.0, 1.0, wall_at_x(body.radius))
	assert_lt(Lean.eye(c, body, hits).x, body.radius - move.lean_wall_clearance + CLOSE)


func test_a_leaned_body_is_hit_at_its_leaned_head_and_missed_where_the_head_was() -> void:
	# The fitted volume (HV1): its head rolls about the hip pivot by the lean's angle, as Lean.offset rolls a point on the
	# centre line (the drawn head sits a little to one side of it, so the roll is taken from where it is).
	var c := standing()
	var upright := Hitbox.Volume.new()
	Hitbox.build_volume(c, hits, upright)
	c.lean = 1.0
	var v := Hitbox.Volume.new()
	Hitbox.build_volume(c, hits, v)
	var was := upright.head.a
	var head := v.head.a
	var pivot := Vector3(0.0, hits.pivot_height, was.z)
	var rolled := pivot + (was - pivot).rotated(Vector3.BACK, -hits.lean_max_angle)
	var on_line := Lean.offset(was.y, 1.0, 0.0, 0.0, hits)
	assert_almost_eq(Vector3(0.0, was.y, was.z) + on_line, pivot + (Vector3(0.0, was.y, was.z) - pivot).rotated(
			Vector3.BACK, -hits.lean_max_angle), Vector3.ONE * CLOSE, "Lean.offset is the same roll")
	assert_almost_eq(head, rolled, Vector3.ONE * CLOSE, "the head rolled about the hip pivot")
	var t := Hitbox.ray_character(Vector3(head.x, head.y, 10.0), Vector3.FORWARD, 20.0, v)
	assert_almost_eq(t, 10.0 - head.z - v.head.r, CLOSE, "the leaned head")
	assert_eq(Hitbox.ray_character(Vector3(was.x, was.y, 10.0), Vector3.FORWARD, 20.0, v), INF,
			"where the head was upright")
	var knee := upright.parts[Hitbox.SHIN_L].a
	assert_lt(Hitbox.ray_character(Vector3(knee.x, knee.y, 10.0), Vector3.FORWARD, 20.0, v), 20.0,
			"the legs stay put")


func test_bbs_leave_from_the_leaned_eyes_in_the_simulation() -> void:
	var w := BoxWorld.new(body)
	w.add_floor(60.0, 30.0)
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-10.0 if e == 0 else 10.0, 0.0, 0.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-14.0 if e == 0 else 14.0, 0.0, 10.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var state := GameState.new(1, tuning)
	var loadout := ReplicaStats.default_loadout()
	for i in 2:
		state.characters.append(Character.new(i, i, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	var cmds: Array[PlayerCommand] = [PlayerCommand.new(), PlayerCommand.new()]
	cmds[1].yaw = state.characters[1].yaw
	var c := state.characters[0]
	cmds[0].lean = 1.0
	for i in 40:
		sim.step(state, cmds, DT)
	assert_eq(c.lean, 1.0)
	cmds[0].fire = true
	sim.step(state, cmds, DT)
	var shot := state.events.first(GameEvent.Kind.SHOT)
	assert_not_null(shot)
	assert_almost_eq(shot.position.distance_to(Lean.eye(c, body, hits)), 0.0, CLOSE)
	assert_gt(shot.position.distance_to(c.eye(body)), 0.35, "not from the upright eyes")
	assert_eq(c.prev_lean, 1.0, "last tick's lean is kept for drawing")


func test_a_lean_slows_you_to_walking_pace_and_rules_out_a_sprint() -> void:
	var c := standing()
	c.lean = 1.0
	assert_almost_eq(Movement.target_speed(c, move, false), move.walk_speed, CLOSE)
	c.lean = move.lean_quiet_from * 0.5
	var half := Movement.target_speed(c, move, false)
	assert_lt(half, move.run_speed)
	assert_gt(half, move.walk_speed)
	var cmd := PlayerCommand.new()
	cmd.forward = 1.0
	cmd.sprint = true
	cmd.lean = 1.0
	c.lean = 0.1
	Movement.step(c, cmd, move, tuning.accuracy, DT, BoxWorld.new(body).mover())
	assert_false(c.sprinting, "no running out of a peek")


func test_a_respawn_stands_you_upright() -> void:
	var c := standing()
	c.lean = 1.0
	c.prev_lean = 1.0
	c.respawn()
	assert_eq(c.lean, 0.0)
	assert_eq(c.prev_lean, 0.0)

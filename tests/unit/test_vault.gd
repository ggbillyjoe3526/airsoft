extends GutTest
## Vaulting's rules (game/sim/vault.gd), ported from the browser game's sim/vault.test.ts and the command half of
## vaultPresses.test.ts: what is vaulted (0.6 to 0.95 m, at most 1 m deep, room to land, never crouch cover), the way it
## goes (within 70° of the view), when a Jump press starts one, the path it follows and the presses kept through it.
## Geometry is BoxWorld boxes; the body walks to -Z.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var cfg: VaultConfig = tuning.vault
var body: BodyConfig = tuning.body
var r: float = tuning.body.radius
## Feet at rest on the floor at the origin.
var feet: Vector3 = Vector3(0.0, tuning.body.rest_gap, 0.0)


## Moves exactly as asked: nothing in the way.
class FreeMover:
	extends CharacterMover

	func move(_c: Character, desired: Vector3) -> Vector3:
		return desired


## Moves nothing: held back by something the plan didn't see.
class StuckMover:
	extends CharacterMover

	func move(_c: Character, _desired: Vector3) -> Vector3:
		return Vector3.ZERO


## Lifts the body onto the 0.85 m wall's top on the first move, as the mover's step does for a vault begun against
## the face; moves freely after.
class LiftingMover:
	extends CharacterMover

	var lifted := false

	func move(c: Character, desired: Vector3) -> Vector3:
		if lifted:
			return desired
		lifted = true
		return Vector3(desired.x, 0.85 - c.position.y, desired.z)


## A world of boxes, each [center, size].
func level(boxes: Array) -> BoxWorld:
	var w := BoxWorld.new(body)
	for b: Array in boxes:
		w.add_box(b[0], b[1])
	return w


func floor_box() -> Array:
	return [Vector3(0.0, -0.25, 0.0), Vector3(40.0, 0.5, 40.0)]


## An obstacle spanning x, `height` tall, `depth` deep along z, its near face at z = `face`, standing on `base_y`.
func wall(height: float, depth: float = 0.3, face: float = -0.7, base_y: float = 0.0) -> Array:
	return [Vector3(0.0, base_y + height * 0.5, face - depth * 0.5), Vector3(6.0, height, depth)]


func plan(boxes: Array, speed: float = 0.0, at: Vector3 = feet, out: VaultState = null) -> bool:
	var v := out if out != null else VaultState.new()
	return Vault.plan(at, Vector2(0.0, -1.0), speed, cfg, body, level(boxes), v)


func standing(at: Vector3 = feet) -> Character:
	var c := Character.new(4, 0, at, 0.0)
	c.grounded = true
	return c


## A character vaulting the 0.85 m wall in front of it.
func started() -> Character:
	var c := standing()
	var cmd := PlayerCommand.new()
	cmd.jump = true
	assert_true(Vault.try_start(c, cmd, tuning, level([floor_box(), wall(0.85)]), SimEvents.new()))
	return c


func test_takes_a_low_wall_in_reach_on_a_path_clear_of_its_faces_landing_past_it() -> void:
	var v := VaultState.new()
	assert_true(plan([floor_box(), wall(0.85)], 0.0, feet, v))
	assert_almost_eq(v.top_y, 0.85, 1e-4)
	assert_almost_eq(v.over_y, 0.85 + cfg.clearance, 1e-4)
	# The body's surface reaches the face (0.7 m away) less the skin, and clears the far side (1 m) likewise.
	assert_lt(v.front, 0.7 - r)
	assert_gt(v.front, 0.7 - r - 0.05)
	assert_gt(v.far, 1.0 + r)
	assert_lt(v.far, 1.0 + r + 0.05)
	assert_eq(v.speed, cfg.min_speed)
	assert_gte(v.rise_end, cfg.rise_time)
	assert_gt(v.end, v.rise_end)
	assert_lt(v.end, 0.45, "short and committed: about 0.4 s from a standstill")
	assert_false(v.active, "planned, not started")


func test_takes_obstacles_from_0_6_to_0_95_m_and_nothing_lower_or_higher() -> void:
	for h: float in [0.6, 0.7, 0.8, 0.9, 0.95]:
		assert_true(plan([floor_box(), wall(h)]), "%s m" % h)
	for h: float in [0.3, 0.55, 1.0, 1.2, 2.4]:
		assert_false(plan([floor_box(), wall(h)]), "%s m: crouch cover and railings stay peek-only" % h)
	assert_false(plan([floor_box(), wall(1.0, 0.1)]), "a 1 m railing")


func test_takes_walls_barriers_and_crates_up_to_a_metre_deep_and_climbs_a_platform() -> void:
	var v := VaultState.new()
	for d: float in [0.1, 0.3, 0.6, 1.0]:
		assert_true(plan([floor_box(), wall(0.85, d)], 0.0, feet, v), "%s m deep" % d)
		assert_false(v.climb, "%s m deep: vaulted" % d)
	for d: float in [1.2, 1.4]:
		assert_false(plan([floor_box(), wall(0.85, d)]), "%s m deep: too deep to vault, too shallow to climb" % d)
	for d: float in [1.6, 3.0, 8.0]:
		assert_true(plan([floor_box(), wall(0.85, d)], 0.0, feet, v), "%s m deep" % d)
		assert_true(v.climb, "%s m deep: a platform, climbed" % d)


## A platform `height` tall, its edge `face` m ahead, running 6 m on.
func platform(height: float, face: float = -0.7) -> Array:
	return wall(height, 6.0, face)


func test_climbs_a_platform_from_0_6_to_0_95_m_and_nothing_lower_or_higher() -> void:
	var v := VaultState.new()
	for h: float in [0.6, 0.75, 0.9, 0.95]:
		assert_true(plan([floor_box(), platform(h)], 0.0, feet, v), "%s m" % h)
		assert_true(v.climb, "%s m" % h)
		assert_almost_eq(v.top_y, h, 1e-4)
	for h: float in [0.3, 0.55, 1.0, 1.2]:
		assert_false(plan([floor_box(), platform(h)]), "%s m" % h)


func test_a_climb_ends_standing_on_the_top_past_the_edge() -> void:
	var v := VaultState.new()
	assert_true(plan([floor_box(), platform(0.9)], 0.0, feet, v))
	assert_almost_eq(v.over_y, 0.9 + cfg.clearance, 1e-4)
	assert_lt(v.front, 0.7 - r)
	assert_almost_eq(v.far, 0.7 + r + cfg.landing_room, 1e-3, "the whole body on the top, landing_room past the edge")
	assert_eq(v.speed, cfg.climb_min_speed)
	assert_gte(v.rise_end, cfg.climb_rise_time)
	assert_lt(v.end, 0.65, "a quick pull up, not a cutscene")
	assert_gt(v.end, 0.45, "slower than a vault's hop")


func test_climbs_a_ledge_over_open_space_found_at_its_lip() -> void:
	# SM1: the open cab's floor over the space under the train's end, its lip 0.75 to 0.9 m, open under it
	var lip := [Vector3(0.0, 0.825, -0.7 - 3.0), Vector3(6.0, 0.15, 6.0)]
	var v := VaultState.new()
	assert_true(plan([floor_box(), lip], 0.0, feet, v), "found at overhang_probe")
	assert_true(v.climb)
	assert_almost_eq(v.top_y, 0.9, 1e-4)
	var high := [Vector3(0.0, 0.925, -0.7 - 3.0), Vector3(6.0, 0.05, 6.0)]
	assert_false(plan([floor_box(), high]), "a lip wholly over overhang_probe is not found")
	var shelf := [Vector3(0.0, 0.825, -0.7 - 0.25), Vector3(6.0, 0.15, 0.5)]
	assert_true(plan([floor_box(), shelf]), "a thin shelf over open space is vaulted, as a wall would be")


func test_climbs_only_a_flat_open_ledge() -> void:
	var bench := [Vector3(0.0, 1.1, -1.9), Vector3(6.0, 0.4, 0.6)]
	assert_false(plan([floor_box(), platform(0.9), bench]), "something standing on the top within climb_depth")
	var hoarding := [Vector3(0.0, 2.1, -1.6), Vector3(6.0, 2.4, 0.2)]
	assert_false(plan([floor_box(), platform(0.9), hoarding]), "a wall on the top just past the edge")
	var low_roof := [Vector3(0.0, 2.3, -3.0), Vector3(6.0, 0.2, 6.0)]
	assert_false(plan([floor_box(), platform(0.9), low_roof]), "no room to stand on the top")
	var tunnel := [Vector3(0.0, 4.2, -3.0), Vector3(6.0, 0.2, 12.0)]
	assert_true(plan([floor_box(), platform(0.9), tunnel]), "a tunnel's roof 3.2 m over the platform")
	var far_wall := [Vector3(0.0, 2.0, -3.0), Vector3(6.0, 4.0, 0.3)]
	assert_true(plan([floor_box(), platform(0.9), far_wall]), "a wall 2.2 m past the edge is room enough")


func test_a_climb_rises_steps_on_and_hands_over_standing_on_the_top() -> void:
	var c := standing()
	var cmd := PlayerCommand.new()
	cmd.jump = true
	assert_true(Vault.try_start(c, cmd, tuning, level([floor_box(), platform(0.9)]), SimEvents.new()))
	var v := c.vault
	assert_true(v.climb)
	var free := FreeMover.new()
	var ticks := 0
	var top_tuck := 0.0
	while v.active and ticks < 90:
		Vault.step(c, PlayerCommand.new(), tuning, DT, free)
		ticks += 1
		top_tuck = maxf(top_tuck, c.crouch_amount)
		if -c.position.z > v.front + 0.02:
			assert_gte(c.position.y, v.over_y - 1e-5, "never lower than the top once over the edge")
		if v.time > v.rise_end:
			assert_almost_eq(c.position.y, v.over_y, 1e-5, "no hop on the top")
	assert_eq(ticks, ceili(v.end / DT - 1e-6))
	assert_almost_eq(-c.position.z, v.far, 1e-4)
	assert_almost_eq(top_tuck, cfg.climb_tuck, 0.01, "tucked most at the top of the rise")
	assert_almost_eq(c.crouch_amount, 0.0, 1e-4, "standing again on the top")
	assert_almost_eq(c.velocity.z, -v.speed, 1e-4)
	assert_eq(c.velocity.y, 0.0, "no push down: it stands on the top")
	# A vault after it is a vault again.
	assert_true(plan([floor_box(), wall(0.85)], 0.0, feet, v))
	assert_false(v.climb)


func test_reaches_further_the_faster_you_come_in_and_not_at_all_from_afar() -> void:
	var reach := r + cfg.reach
	assert_true(plan([floor_box(), wall(0.85, 0.3, -(reach - 0.05))]))
	assert_false(plan([floor_box(), wall(0.85, 0.3, -(reach + 0.3))]))
	assert_true(plan([floor_box(), wall(0.85, 0.3, -(reach + 0.3))], tuning.movement.sprint_speed))
	var v := VaultState.new()
	plan([floor_box(), wall(0.85)], tuning.movement.sprint_speed, feet, v)
	assert_eq(v.speed, cfg.max_speed, "sprinting in, the move keeps your pace up to its cap")


func test_needs_a_flat_top() -> void:
	var step := [Vector3(0.0, 0.8, -1.1), Vector3(6.0, 0.2, 0.3)]
	assert_false(plan([floor_box(), wall(0.7, 0.9), step]), "a block standing on the top")


func test_needs_room_to_land() -> void:
	var behind := [Vector3(0.0, 1.5, -1.5), Vector3(6.0, 3.0, 0.4)]
	assert_false(plan([floor_box(), wall(0.85), behind]), "a wall right behind")
	var balcony := [Vector3(0.0, -0.25, 5.0), Vector3(40.0, 0.5, 11.6)]
	var street := [Vector3(0.0, -3.25, -20.0), Vector3(40.0, 0.5, 40.0)]
	assert_false(plan([balcony, street, wall(0.85)]), "a drop off a balcony")
	var raised := [Vector3(0.0, 0.15, -10.0), Vector3(40.0, 0.5, 17.8)]
	assert_false(plan([floor_box(), raised, wall(0.85)]), "a far floor 0.4 m higher")
	var near := [Vector3(0.0, -0.25, 5.0), Vector3(40.0, 0.5, 11.7)]
	var lower := [Vector3(0.0, -0.35, -10.0), Vector3(40.0, 0.5, 17.8)]
	assert_true(plan([near, lower, wall(0.8)]), "a little lower past it")
	var downhill := [Vector3(0.0, -0.55, -10.0), Vector3(40.0, 0.5, 17.8)]
	assert_false(plan([near, downhill, wall(0.8)]), "the top 1.1 m over the far floor")


func test_never_takes_crouch_cover_from_a_raised_side() -> void:
	var platform := [Vector3(0.0, 0.15, 0.0), Vector3(6.0, 0.3, 1.8)]
	assert_false(plan([floor_box(), platform, wall(1.2)], 0.0, Vector3(0.0, 0.3 + body.rest_gap, 0.0)))


func test_needs_room_for_the_body() -> void:
	var ceiling := [Vector3(0.0, 2.4, 0.0), Vector3(6.0, 0.2, 6.0)]
	assert_false(plan([floor_box(), wall(0.85), ceiling]), "a low ceiling")
	var lintel := [Vector3(0.0, 2.2, -0.85), Vector3(6.0, 0.6, 0.3)]
	assert_false(plan([floor_box(), wall(0.85), lintel]), "an overhang")
	var post_l := [Vector3(-0.35, 1.5, -0.85), Vector3(0.2, 3.0, 0.3)]
	var post_r := [Vector3(0.35, 1.5, -0.85), Vector3(0.2, 3.0, 0.3)]
	assert_false(plan([floor_box(), wall(0.85), post_l, post_r]), "a gap 0.5 m wide")
	post_l[0] = Vector3(-0.6, 1.5, -0.85)
	post_r[0] = Vector3(0.6, 1.5, -0.85)
	assert_true(plan([floor_box(), wall(0.85), post_l, post_r]), "a gap 1 m wide")


func test_writes_nothing_when_there_is_no_vault() -> void:
	var none := VaultState.new()
	assert_false(plan([floor_box(), wall(1.2)], 0.0, feet, none))
	assert_eq(none.top_y, 0.0)
	assert_eq(none.end, 0.0)


func test_goes_the_way_the_keys_push_or_the_view_with_none_held() -> void:
	var cmd := PlayerCommand.new()
	cmd.yaw = PI / 2.0 # facing -X
	var w := Vault.way(cmd, tuning)
	assert_almost_eq(w.x, -1.0, 1e-6)
	assert_almost_eq(w.y, 0.0, 1e-6)
	cmd.forward = 1.0
	cmd.right = 1.0 # 45° off the view
	w = Vault.way(cmd, tuning)
	assert_almost_eq(w.length(), 1.0, 1e-6)
	assert_almost_eq(w.x, -sqrt(0.5), 1e-6)
	assert_almost_eq(w.y, -sqrt(0.5), 1e-6)


func test_never_goes_more_than_70_degrees_off_the_view() -> void:
	var cmd := PlayerCommand.new()
	cmd.forward = cos(deg_to_rad(65.0))
	cmd.right = sin(deg_to_rad(65.0))
	assert_ne(Vault.way(cmd, tuning), Vector2.ZERO, "65° off")
	cmd.forward = cos(deg_to_rad(75.0))
	cmd.right = sin(deg_to_rad(75.0))
	assert_eq(Vault.way(cmd, tuning), Vector2.ZERO, "75° off")
	cmd.forward = 0.0
	cmd.right = 1.0
	assert_eq(Vault.way(cmd, tuning), Vector2.ZERO, "sideways")
	cmd.right = 0.0
	cmd.forward = -1.0
	assert_eq(Vault.way(cmd, tuning), Vector2.ZERO, "backwards")


func test_a_heading_more_than_70_degrees_off_the_view_never_vaults() -> void:
	# The wall is ahead (-Z); the view is turned 80° left of it and the keys push straight at it.
	var world := level([floor_box(), wall(0.85)])
	for case: Array in [[60.0, true], [80.0, false]]:
		var c := standing()
		var cmd := PlayerCommand.new()
		var off := deg_to_rad(case[0])
		cmd.yaw = off
		cmd.forward = cos(off)
		cmd.right = sin(off)
		cmd.jump = true
		assert_eq(Vault.try_start(c, cmd, tuning, world, SimEvents.new()), case[1], "%s° off" % case[0])


func test_starts_on_a_jump_press_facing_the_wall() -> void:
	var c := standing()
	var cmd := PlayerCommand.new()
	var events := SimEvents.new()
	var world := level([floor_box(), wall(0.85)])
	assert_false(Vault.try_start(c, cmd, tuning, world, events), "no press")
	cmd.jump = true
	c.sprinting = true
	assert_true(Vault.try_start(c, cmd, tuning, world, events))
	assert_true(c.vault.active)
	assert_eq(c.jump_cooldown, tuning.movement.jump_cooldown)
	assert_false(c.sprinting)
	assert_eq(events.count, 1)
	var e := events.first(GameEvent.Kind.VAULT)
	assert_not_null(e, "a VAULT event, for its sound and the bots' hearing")
	assert_eq(e.actor, 4)
	assert_eq(e.position, c.position)


func test_takes_a_press_still_buffered() -> void:
	var c := standing()
	c.jump_wanted = tuning.movement.jump_buffer / 2.0
	assert_true(Vault.try_start(c, PlayerCommand.new(), tuning, level([floor_box(), wall(0.85)]), SimEvents.new()))
	assert_eq(c.jump_wanted, 0.0)


func test_needs_the_feet_on_the_ground_standing_the_jump_ready_and_the_wall_ahead() -> void:
	var world := level([floor_box(), wall(0.85)])
	var out := VaultState.new()
	var air := standing()
	air.grounded = false
	assert_false(Vault.find(air, 0.0, tuning, world, out), "in the air")
	var crouched := standing()
	crouched.crouch_amount = 1.0
	assert_false(Vault.find(crouched, 0.0, tuning, world, out), "crouched")
	var cooling := standing()
	cooling.jump_cooldown = 0.1
	assert_false(Vault.find(cooling, 0.0, tuning, world, out), "the jump not ready")
	assert_false(Vault.find(standing(), PI, tuning, world, out), "facing away")
	assert_true(Vault.find(standing(), 0.0, tuning, world, out))
	assert_false(standing().vault.active, "find never starts one")


func test_rises_onto_the_top_crosses_it_and_hands_over_to_a_fall_past_the_far_side() -> void:
	var c := started()
	var v := c.vault
	var cmd := PlayerCommand.new()
	var free := FreeMover.new()
	var ticks := 0
	var top_reached := false
	while c.vault.active and ticks < 60:
		Vault.step(c, cmd, tuning, DT, free)
		ticks += 1
		assert_false(c.grounded)
		assert_eq(c.fire_lockout, cfg.fire_lockout)
		# Never lower than the top once over the face (no clipping through it).
		if -c.position.z > v.front + 0.02 and -c.position.z < v.far - 0.02:
			assert_gte(c.position.y, v.over_y - 1e-5)
		if c.position.y >= v.over_y - 1e-5:
			top_reached = true
	assert_true(top_reached)
	assert_eq(ticks, ceili(v.end / DT - 1e-6))
	assert_almost_eq(-c.position.z, v.far, 1e-4)
	assert_almost_eq(c.velocity.z, -v.speed, 1e-4)
	assert_eq(c.velocity.y, -cfg.drop_speed)


func test_a_body_lifted_onto_the_top_early_carries_on_over_it_and_never_stays_there() -> void:
	var c := started()
	var v := c.vault
	var lift := LiftingMover.new()
	var ticks := 0
	while c.vault.active and ticks < 60:
		Vault.step(c, PlayerCommand.new(), tuning, DT, lift)
		ticks += 1
	assert_true(lift.lifted)
	assert_eq(ticks, ceili(v.end / DT - 1e-6), "the vault runs its course")
	assert_almost_eq(-c.position.z, v.far, 1e-4, "and ends past the far side, not on the top")
	assert_eq(c.velocity.y, -cfg.drop_speed)


func test_tucks_the_body_over_the_top_and_turns_the_view_freely() -> void:
	var c := started()
	var cmd := PlayerCommand.new()
	cmd.yaw = 0.7
	cmd.pitch = -0.3
	var free := FreeMover.new()
	for i in 12:
		Vault.step(c, cmd, tuning, DT, free)
	assert_almost_eq(c.crouch_amount, cfg.tuck, 0.01)
	assert_eq(c.yaw, 0.7)
	assert_almost_eq(c.pitch, -0.3, 1e-6)
	assert_eq(c.vault.dir, Vector2(0.0, -1.0), "the way was settled when the vault began")


func test_gives_up_and_falls_where_it_is_when_held_back() -> void:
	var c := started()
	var stuck := StuckMover.new()
	var ticks := 0
	while c.vault.active and ticks < 60:
		Vault.step(c, PlayerCommand.new(), tuning, DT, stuck)
		ticks += 1
	assert_lt(ticks, 10)
	assert_lte(c.velocity.y, 0.0)


func test_follows_only_the_view_keeping_the_trigger_and_aim_as_the_vault_found_them() -> void:
	var c := started()
	c.armament.trigger_was_down = true
	c.armament.aim_was_down = true
	var cmd := PlayerCommand.new()
	cmd.yaw = 0.4
	cmd.pitch = 0.1
	cmd.forward = 1.0
	cmd.jump = true
	cmd.fire = false
	cmd.lean = 1.0
	cmd.aim = false
	var out := Vault.vaulting_command(c, cmd, PlayerCommand.new())
	assert_eq(out.yaw, 0.4)
	assert_almost_eq(out.pitch, 0.1, 1e-6)
	assert_true(out.fire, "a trigger held into the vault is the same pull")
	assert_true(out.aim, "an aim held into the vault is no new press after it (no sight comes up mid-vault: Aiming)")
	assert_eq(out.forward, 0.0)
	assert_false(out.jump)
	assert_eq(out.lean, 0.0)


func test_keeps_each_press_made_during_the_vault_and_plays_it_after_once() -> void:
	var c := started()
	var cmd := PlayerCommand.new()
	cmd.reload = true
	cmd.switch_to = 1
	cmd.cycle_fire_mode = true
	var out := Vault.vaulting_command(c, cmd, PlayerCommand.new())
	assert_false(out.reload, "nothing starts mid-vault")
	assert_eq(out.switch_to, -1)
	assert_false(out.cycle_fire_mode)
	Vault.vaulting_command(c, cmd, out) # the selector twice
	var after := PlayerCommand.new()
	var first := Vault.with_held_presses(c.vault, after, PlayerCommand.new())
	assert_true(first.reload)
	assert_eq(first.switch_to, 1)
	assert_true(first.cycle_fire_mode)
	var second := Vault.with_held_presses(c.vault, after, PlayerCommand.new())
	assert_false(second.reload, "once")
	assert_eq(second.switch_to, -1)
	assert_true(second.cycle_fire_mode, "the second selector press on the tick after")
	assert_eq(Vault.with_held_presses(c.vault, after, PlayerCommand.new()), after, "nothing kept: the command itself")


func test_a_slot_pressed_after_the_vault_wins_over_one_pressed_during_it() -> void:
	var c := started()
	var cmd := PlayerCommand.new()
	cmd.switch_to = 0
	Vault.vaulting_command(c, cmd, PlayerCommand.new())
	var after := PlayerCommand.new()
	after.switch_to = 1
	assert_eq(Vault.with_held_presses(c.vault, after, PlayerCommand.new()).switch_to, 1)


func test_a_respawn_drops_the_vault_and_what_was_kept() -> void:
	var c := started()
	var cmd := PlayerCommand.new()
	cmd.reload = true
	Vault.vaulting_command(c, cmd, PlayerCommand.new())
	c.fire_lockout = 0.2
	c.respawn()
	assert_false(c.vault.active)
	assert_false(c.vault.held_any)
	assert_false(c.vault.held_reload)
	assert_eq(c.fire_lockout, 0.0)

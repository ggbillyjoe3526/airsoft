class_name Movement
## One tick of a character's movement (the browser game's sim/movement.ts): stance, pace, acceleration, a limited jump,
## gravity, then collision through CharacterMover and the ground probe. Pure apart from the mover.


## Pace (m/s) a move may make beyond the one asked for before it counts as a push out of geometry, not rounding.
const PUSH_PACE := 1e-3


## Moves `current` towards `target` by at most `max_delta`.
static func approach(current: float, target: float, max_delta: float) -> float:
	if current < target:
		return minf(current + max_delta, target)
	return maxf(current - max_delta, target)


## The pace (m/s) the character is aiming for in its stance: walking, sprinting or the run (both faster holstered),
## blended towards the crouch pace as it crouches. A lean slows it smoothly to walking pace, reached at lean_quiet_from of a full lean. Walk held
## while aiming down sights creeps below the aiming pace (M84).
static func target_speed(c: Character, cfg: MovementConfig, walk_held: bool) -> float:
	var holstered := c.armament.holstered
	var run := minf(cfg.holster_run_speed, cfg.sprint_speed) if holstered else cfg.run_speed
	var sprint := cfg.sprint_speed * cfg.holster_sprint_scale if holstered else cfg.sprint_speed
	var base := cfg.walk_speed if c.walking else (sprint if c.sprinting else run)
	var lean := absf(c.lean)
	if lean > 0.0 and not c.walking:
		base += (cfg.walk_speed - base) * minf(1.0, lean / cfg.lean_quiet_from)
	var speed := base + (cfg.crouch_speed - base) * c.crouch_amount
	return speed * cfg.aim_walk_scale if c.aiming and walk_held else speed


## Applies one tick of `cmd`'s movement, gravity and collision to `c`.
static func step(c: Character, cmd: PlayerCommand, cfg: MovementConfig, accuracy: AccuracyConfig, dt: float,
		mover: CharacterMover) -> void:
	c.yaw = cmd.yaw
	c.pitch = clampf(cmd.pitch, -cfg.max_pitch, cfg.max_pitch)

	# Crouched under something lower than a standing body (a tunnel's roof, CT1), it stays down whatever is held.
	var kept_down := c.low and not mover.room_to_stand(c)
	c.crouch_amount = approach(c.crouch_amount, 1.0 if cmd.crouch or kept_down else 0.0, dt / cfg.crouch_transition_time)
	var crouched := c.crouch_amount >= cfg.crouched_threshold
	c.low = crouched
	# Walking (slow, quiet) wins over sprinting, and so do aiming down sights and leaning from lean_quiet_from. Sprint:
	# forward only, never crouched, never with the lean key held (no running out of a peek); once it is let go, sprint
	# picks up as the lean eases back under lean_quiet_from.
	var lean := absf(c.lean)
	c.walking = (cmd.walk or c.aiming or lean >= cfg.lean_quiet_from) and not crouched
	c.sprinting = cmd.sprint and not c.walking and (lean == 0.0 or cmd.lean == 0.0) \
			and cmd.forward >= cfg.sprint_min_forward and not crouched
	# The moment after a vault before the replica can fire (Vault holds it full while vaulting).
	c.fire_lockout = maxf(0.0, c.fire_lockout - dt)

	# The wish direction on the ground: forward is (-sin, 0, -cos) and right (cos, 0, -sin) of the yaw.
	var f := cmd.forward
	var r := cmd.right
	var mag := sqrt(f * f + r * r)
	if mag > 1.0:
		f /= mag
		r /= mag
	var s := sin(c.yaw)
	var co := cos(c.yaw)
	var speed := target_speed(c, cfg, cmd.walk)
	var wish_x := (-s * f + co * r) * speed
	var wish_z := (-co * f - s * r) * speed
	var has_input := mag > cfg.input_deadzone

	var accel := (cfg.ground_accel if has_input else cfg.ground_decel) if c.grounded else cfg.air_accel
	var dvx := wish_x - c.velocity.x
	var dvz := wish_z - c.velocity.z
	var dv_len := sqrt(dvx * dvx + dvz * dvz)
	if dv_len > 0.0:
		var step_len := minf(dv_len, accel * dt)
		c.velocity.x += dvx / dv_len * step_len
		c.velocity.z += dvz / dv_len * step_len

	# The jump: limited by its cooldown, never crouched. A press is kept for jump_buffer, so one made just before landing
	# or while standing up still jumps once it can (audit SIM-05).
	c.jump_cooldown = maxf(0.0, c.jump_cooldown - dt)
	c.jump_wanted = cfg.jump_buffer if cmd.jump else maxf(0.0, c.jump_wanted - dt)
	if c.jump_wanted > 0.0 and c.grounded and c.jump_cooldown <= 0.0 and not crouched:
		c.velocity.y = cfg.jump_speed
		c.grounded = false
		c.jump_cooldown = cfg.jump_cooldown
		c.jump_wanted = 0.0
		c.air_time = accuracy.air_spread_delay # a deliberate jump gets the in-air spread at once

	# Standing characters move level, then settle onto the floor with the probe below: gravity folded into the move made
	# the browser game's controller stall a walk for a tick now and then.
	var on_ground := c.grounded and c.velocity.y <= 0.0
	c.velocity.y = 0.0 if on_ground else maxf(-cfg.max_fall_speed, c.velocity.y - cfg.gravity * dt)

	# Climbing a ramp: lengthen the move by what sliding up the slope takes off it (audit SIM-17; off at ramp_pace 0).
	var climb := 1.0 + cfg.ramp_pace * c.ground_rise * c.ground_rise if on_ground and c.ground_rise > 0.0 else 1.0
	var desired := Vector3(c.velocity.x * dt * climb, c.velocity.y * dt, c.velocity.z * dt * climb)
	var corrected := mover.move(c, desired)
	c.position += corrected
	c.wanted_move = desired
	c.made_move = corrected

	# Velocity follows what actually happened, so walls absorb speed instead of storing it; neither a lengthened move nor
	# a push out of geometry (a body set down into sloping ground, popped out downhill) ever adds speed.
	var pace_before := sqrt(c.velocity.x * c.velocity.x + c.velocity.z * c.velocity.z)
	c.velocity.x = corrected.x / dt
	c.velocity.z = corrected.z / dt
	var pace := sqrt(c.velocity.x * c.velocity.x + c.velocity.z * c.velocity.z)
	if pace > pace_before and (climb > 1.0 or pace - pace_before > PUSH_PACE):
		c.velocity.x *= pace_before / pace
		c.velocity.z *= pace_before / pace

	# Only the ground probe decides whether we stand: a capsule touching the top edge of cover must not count as ground
	# (players would hang on barriers). It also lands us exactly at rest height.
	var grounded := false
	var settle := 0.0
	if c.velocity.y <= 0.0:
		var dy := mover.probe_ground(c, cfg.ground_settle_distance)
		grounded = not is_nan(dy)
		if grounded:
			c.position.y += dy
			c.velocity.y = 0.0
			settle = dy
	elif desired.y > 0.0 and corrected.y < desired.y * cfg.ceiling_block_fraction:
		c.velocity.y = 0.0 # bumped a ceiling
	# The slope climbed this tick, for the next: on the ground before and after, uphill, no steeper than a ramp.
	var moved := sqrt(corrected.x * corrected.x + corrected.z * corrected.z)
	var rise := (corrected.y + settle) / moved if on_ground and grounded and moved > 0.0 else 0.0
	c.ground_rise = rise if rise > 0.0 and rise <= cfg.ramp_max_rise else 0.0
	# Held up while falling (caught on an edge): fall only as fast as we actually moved, so speed doesn't build up unseen.
	# Never upward: a push out of geometry turned into upward speed would launch the character.
	if not grounded and desired.y < 0.0 and corrected.y > desired.y:
		c.velocity.y = minf(0.0, corrected.y / dt)
	c.grounded = grounded

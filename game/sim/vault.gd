class_name Vault
## Vaulting (the browser game's sim/vault.ts, M102; owner, 2026-10-12): Jump pressed at a low obstacle (a wall, barrier
## or crate whose top is VaultConfig min_height to max_height over your floor, no deeper than max_depth, with room to land
## past it) takes the body over it in one short, committed move instead of a jump. The body rises onto the top and
## crosses it on a path the CharacterMover follows, so it never passes through anything, then falls off the far side
## and lands as from a jump. Meanwhile the replica is carried (no firing, aiming or reloading starts; fire is held
## fire_lockout after it), the body tucks (a crouch: eyes, hit volume and figure follow it) and the view turns freely.
## Presses made during it are kept for after it (BP5). The obstacle is found with level rays only (WorldQuery), so the
## rule is the same for the player and the bots. Allocation-free.

## Scratch for the level rays (used only within one call).
static var _hit: RayHit = RayHit.new()


## Would a Jump press vault now, going the way the view at `yaw` looks (the legacy findVault, for a bot at a vault on
## its route): standing on the ground, not crouched, the jump ready and an obstacle there. The vault goes into `out`
## (not started); nothing is written when there is none.
static func find(c: Character, yaw: float, tuning: SimTuning, query: WorldQuery, out: VaultState) -> bool:
	return find_along(c, Vector2(-sin(yaw), -cos(yaw)), tuning, query, out)


## As `find`, going along the unit ground-plane way `way` (x, z).
static func find_along(c: Character, way: Vector2, tuning: SimTuning, query: WorldQuery, out: VaultState) -> bool:
	if c.vault.active or not c.grounded or c.jump_cooldown > 0.0:
		return false
	if c.crouch_amount >= tuning.movement.crouched_threshold:
		return false
	var speed := c.velocity.x * way.x + c.velocity.z * way.y
	return plan(c.position, way, speed, tuning.vault, tuning.body, query, out)


## The way a vault would go for `cmd` (a unit ground-plane vector, x and z): the way the movement keys push, relative to
## the view, or the view's way with none held. Vector2.ZERO if that is more than max_view_angle off the view.
static func way(cmd: PlayerCommand, tuning: SimTuning) -> Vector2:
	var s := sin(cmd.yaw)
	var co := cos(cmd.yaw)
	var f := cmd.forward
	var r := cmd.right
	var mag := sqrt(f * f + r * r)
	if mag <= tuning.movement.input_deadzone:
		return Vector2(-s, -co)
	# The cosine of the angle off the view is f / mag (the view's way is (-sin, -cos)).
	if f / mag < cos(tuning.vault.max_view_angle):
		return Vector2.ZERO
	return Vector2((-s * f + co * r) / mag, (-co * f - s * r) / mag)


## Looks for an obstacle to vault from feet at `feet` along the unit way `way` at `speed` (m/s, towards it) and writes
## the vault into `out` (not started: `active` is left as it is). False if there is none: nothing low enough within
## reach, a top that isn't flat, deeper than a vault, no floor to land on within the heights allowed, or no room for the
## body over the top or past it.
static func plan(feet: Vector3, way: Vector2, speed: float, cfg: VaultConfig, body: BodyConfig, query: WorldQuery,
		out: VaultState) -> bool:
	var dx := way.x
	var dz := way.y
	var floor_y := feet.y - body.rest_gap
	var r := body.radius
	# Its face, within reach of the body.
	var face := _cast(query, Vector3(feet.x, floor_y + cfg.face_probe, feet.z), Vector3(dx, 0.0, dz),
			r + cfg.reach + maxf(0.0, speed) * cfg.reach_per_speed)
	if face < r * 0.5:
		return false
	# A line just over the highest top a vault takes: open until anything taller (the obstacle itself when it is cover,
	# or a wall behind it). Every sample below starts on it, in the open.
	var scan_y := floor_y + cfg.max_height + cfg.scan_above
	var reach_end := face + cfg.max_depth + 2.0 * r + cfg.landing_room + cfg.depth_step
	var hit := _cast(query, Vector3(feet.x, scan_y, feet.z), Vector3(dx, 0.0, dz), reach_end)
	var open := reach_end if hit < 0.0 else hit
	if open <= face + cfg.depth_step:
		return false
	# The top, just inside the face: at least min_height over the floor (and under the scan line).
	var s := face + cfg.depth_step * 0.5
	var t := _down(query, feet, way, s, scan_y, scan_y - (floor_y + cfg.min_height))
	if t < 0.0:
		return false
	var top := scan_y - t
	if top - floor_y > cfg.max_height:
		return false
	# Along the top to its far side: flat all the way, and no deeper than max_depth.
	var edge := -1.0
	s += cfg.depth_step
	while s <= face + cfg.max_depth + cfg.depth_step and s < open:
		var d := _down(query, feet, way, s, scan_y, scan_y - (top - cfg.top_tolerance))
		if d < 0.0:
			edge = s
			break
		if scan_y - d > top + cfg.top_tolerance:
			return false
		s += cfg.depth_step
	if edge < 0.0:
		return false
	# The far side exactly: a ray back from past it, under the top.
	var back := _cast(query, Vector3(feet.x + dx * edge, top - cfg.top_tolerance * 0.5, feet.z + dz * edge),
			Vector3(-dx, 0.0, -dz), cfg.depth_step + 1e-3)
	var far_side := edge - back if back >= 0.0 else edge - cfg.depth_step * 0.5
	# Room for the body past the far side, and a floor there no higher than max_climb over this one, with the top no
	# more than max_landing_height over it.
	var land := far_side + r + cfg.landing_room
	if land + r > open:
		return false
	var l := _down(query, feet, way, land, scan_y, scan_y - (top - cfg.max_landing_height))
	if l < 0.0 or scan_y - l > floor_y + cfg.max_climb:
		return false
	# Room for the body on its way: rising here, then over the top until clear of the far side.
	var over_y := top + cfg.clearance
	var far := far_side + r + cfg.skin
	if _cast(query, Vector3(feet.x, feet.y + body.height - cfg.head_ray, feet.z), Vector3.UP,
			over_y - feet.y + cfg.head_ray) >= 0.0:
		return false
	var pass_len := far + r
	var mid := over_y + body.height * 0.5
	var along := Vector3(dx, 0.0, dz)
	if _cast(query, Vector3(feet.x, over_y + cfg.low_ray, feet.z), along, pass_len) >= 0.0:
		return false
	if _cast(query, Vector3(feet.x, mid, feet.z), along, pass_len) >= 0.0:
		return false
	if _cast(query, Vector3(feet.x, over_y + body.height - cfg.head_ray, feet.z), along, pass_len) >= 0.0:
		return false
	# Down through the body's height along the way: a beam, a lintel or a low roof between those lines.
	var at := 0.0
	while at < pass_len + cfg.depth_step:
		if _down(query, feet, way, minf(at, pass_len), over_y + body.height, body.height - cfg.low_ray) >= 0.0:
			return false
		at += cfg.depth_step
	# Either side of the body's middle: a gap narrower than the body (a low wall between two posts) is no way through.
	var side := r - cfg.side_inset
	if _cast(query, Vector3(feet.x - dz * side, mid, feet.z + dx * side), along, pass_len) >= 0.0:
		return false
	if _cast(query, Vector3(feet.x + dz * side, mid, feet.z - dx * side), along, pass_len) >= 0.0:
		return false

	out.time = 0.0
	out.start = feet
	out.dir = way
	out.front = maxf(0.0, face - r - cfg.skin)
	out.far = far
	out.top_y = top
	out.over_y = over_y
	out.speed = clampf(speed, cfg.min_speed, cfg.max_speed)
	out.rise_end = maxf(cfg.rise_time, out.front / out.speed)
	out.end = out.rise_end + (out.far - out.front) / out.speed
	return true


## A Jump press (or one still buffered, MovementConfig.jump_buffer) at an obstacle `c` can vault starts the vault before
## the movement step would make it a jump: it takes the press and the jump's cooldown, and sends a VAULT event (hands
## and boots on the obstacle: loud, bots hear it far). Returns whether it started. For characters in play.
static func try_start(c: Character, cmd: PlayerCommand, tuning: SimTuning, query: WorldQuery,
		events: SimEvents) -> bool:
	if not cmd.jump and c.jump_wanted <= 0.0:
		return false
	var w := way(cmd, tuning)
	if w == Vector2.ZERO or not find_along(c, w, tuning, query, c.vault):
		return false
	c.vault.active = true
	c.jump_wanted = 0.0
	c.jump_cooldown = tuning.movement.jump_cooldown
	c.sprinting = false
	c.walking = false
	var e := events.add(GameEvent.Kind.VAULT)
	e.actor = c.id
	e.position = c.position
	return true


## The command `c` follows while vaulting, written into `out` (BP5): the view from `cmd`, the trigger and the aim as
## they were when the vault began (one held through it is no new pull or aim press after it, so it doesn't draw a
## holstered replica; one pressed during it counts once it is over), nothing else. `cmd`'s one-shot presses are kept
## for after the vault.
static func vaulting_command(c: Character, cmd: PlayerCommand, out: PlayerCommand) -> PlayerCommand:
	var v := c.vault
	if cmd.reload:
		v.held_reload = true
		v.held_any = true
	if cmd.switch_to >= 0:
		v.held_switch_to = cmd.switch_to
		v.held_ready_grenade = Grenade.Kind.NONE
		v.held_any = true
	if cmd.ready_grenade != Grenade.Kind.NONE:
		v.held_ready_grenade = cmd.ready_grenade
		v.held_switch_to = -1
		v.held_any = true
	if cmd.cycle_fire_mode:
		v.held_fire_modes += 1
		v.held_any = true
	if cmd.holster:
		v.held_holster = true
		v.held_any = true
	if cmd.hop_up_steps != 0:
		v.held_hop_up_steps += cmd.hop_up_steps
		v.held_any = true
	out.reset(cmd.yaw, cmd.pitch)
	out.fire = c.armament.trigger_was_down
	out.aim = c.armament.aim_was_down
	out.manual_reload = cmd.manual_reload # a setting, not a press: it holds through the vault
	return out


## The first command after a vault: `cmd` with the presses kept through it, written into `out`, and those presses
## cleared; `cmd` itself when nothing was kept. A selector pressed twice plays the second on the tick after.
static func with_held_presses(v: VaultState, cmd: PlayerCommand, out: PlayerCommand) -> PlayerCommand:
	if not v.held_any:
		return cmd
	out.copy_from(cmd)
	out.reload = out.reload or v.held_reload
	if v.held_switch_to >= 0 and out.switch_to < 0:
		out.switch_to = v.held_switch_to
	if v.held_ready_grenade != Grenade.Kind.NONE and out.ready_grenade == Grenade.Kind.NONE and out.switch_to < 0:
		out.ready_grenade = v.held_ready_grenade
	if v.held_fire_modes > 0 and not out.cycle_fire_mode:
		out.cycle_fire_mode = true
		v.held_fire_modes -= 1
	out.holster = out.holster or v.held_holster
	out.hop_up_steps += v.held_hop_up_steps
	v.held_reload = false
	v.held_holster = false
	v.held_hop_up_steps = 0
	v.held_switch_to = -1
	v.held_ready_grenade = Grenade.Kind.NONE
	v.held_any = v.held_fire_modes > 0
	return out


## One tick of a vault under way, in place of the movement step: the view turns with `cmd`; the body follows the vault's
## path through `mover` (rising onto the top, eased, then across it at the vault's speed with a slight arc). Clear of
## the far side it hands over to the movement step, falling at the vault's speed with a push down; held back by
## something the plan didn't see (lifted higher than the path is not held back), it gives up and falls where it is.
static func step(c: Character, cmd: PlayerCommand, tuning: SimTuning, dt: float, mover: CharacterMover) -> void:
	var v := c.vault
	var cfg := tuning.vault
	c.yaw = cmd.yaw
	c.pitch = clampf(cmd.pitch, -tuning.movement.max_pitch, tuning.movement.max_pitch)
	v.time += dt
	var t := minf(v.time, v.end)
	var along := 0.0
	var y := 0.0
	var rise := 1.0
	if t < v.rise_end:
		var x := t / v.rise_end
		rise = 1.0 - (1.0 - x) * (1.0 - x)
		along = v.front * x
		y = v.start.y + (v.over_y - v.start.y) * rise
	else:
		var span := v.end - v.rise_end
		along = v.front + v.speed * (t - v.rise_end)
		y = v.over_y + cfg.arc * sin(PI * ((t - v.rise_end) / span if span > 0.0 else 1.0))
	var desired := Vector3(v.start.x + v.dir.x * along - c.position.x, y - c.position.y,
			v.start.z + v.dir.y * along - c.position.z)
	var corrected := mover.move(c, desired)
	c.position += corrected
	c.velocity = corrected / dt

	c.crouch_amount = cfg.tuck * rise
	c.grounded = false
	c.sprinting = false
	c.walking = false
	c.ground_rise = 0.0
	c.jump_wanted = 0.0
	c.jump_cooldown = maxf(0.0, c.jump_cooldown - dt)
	# Carried through the vault, and up again only a moment after it.
	c.fire_lockout = cfg.fire_lockout

	# Lifted higher than the path (the mover stepping the body onto the top early, from a vault begun against the face)
	# is not held back: the path catches up with it.
	var held := desired - corrected
	held.y = maxf(held.y, 0.0)
	if held.length() > cfg.blocked_at:
		v.active = false
		c.velocity.y = minf(0.0, c.velocity.y)
	elif v.time >= v.end:
		v.active = false
		c.velocity = Vector3(v.dir.x * v.speed, -cfg.drop_speed, v.dir.y * v.speed)


## Distance along the unit `dir` from `from` to the first level surface within `max_dist`, or -1.
static func _cast(query: WorldQuery, from: Vector3, dir: Vector3, max_dist: float) -> float:
	if not query.ray(from, from + dir * max_dist, _hit):
		return -1.0
	return _hit.fraction * max_dist


## Distance down from `from_y` over the point `s` metres along `way` from `feet` to the first surface, or -1.
static func _down(query: WorldQuery, feet: Vector3, way: Vector2, s: float, from_y: float, max_dist: float) -> float:
	return _cast(query, Vector3(feet.x + way.x * s, from_y, feet.z + way.y * s), Vector3.DOWN, max_dist)

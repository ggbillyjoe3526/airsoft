class_name Footsteps
## Footsteps (the browser game's sim/footsteps.ts): after a character has moved, counts the ground it covered and sends
## a footstep event every stride while running or sprinting, and a landing when it comes down hard. Walking and moving
## crouched are silent, but for a rattling magazine (a rattle every stride). Each says what it came down on when the
## world can tell, for its sound; a landing says how hard it came down too. A run, sprint or landing step on loud ground
## (`noise`'s ground: gravel, steel plate) carries further, by the event's carry; a rattle carries as ever. One pushing
## through a bush (Character.in_bush, BP8) sounds as leaves and carries NoiseConfig.bush_carry as far.


static func step(c: Character, cfg: FootstepConfig, events: SimEvents, query: WorldQuery,
		noise: NoiseConfig = null) -> void:
	if not c.grounded:
		c.fall_speed = maxf(c.fall_speed, -c.velocity.y)
		c.airborne = true
		return
	if c.airborne:
		c.airborne = false
		var speed := c.fall_speed
		c.fall_speed = 0.0
		if speed >= cfg.land_min_speed:
			_send(c, GameEvent.Footstep.LAND, events, query, noise).direction = Vector3.DOWN * speed
			c.step_distance = 0.0
			return
	var quiet := c.walking or c.crouch_amount > cfg.silent_crouch
	if quiet and not c.armament.rattles():
		return
	var dx := c.position.x - c.prev_position.x
	var dz := c.position.z - c.prev_position.z
	c.step_distance += sqrt(dx * dx + dz * dz)
	var stride := cfg.stride_sprint if c.sprinting else cfg.stride_run
	if c.step_distance >= stride:
		c.step_distance = fmod(c.step_distance, stride)
		if quiet:
			_send(c, GameEvent.Footstep.RATTLE, events, query, null)
		else:
			_send(c, GameEvent.Footstep.SPRINT if c.sprinting else GameEvent.Footstep.RUN, events, query, noise)


static func _send(c: Character, kind: GameEvent.Footstep, events: SimEvents, query: WorldQuery,
		noise: NoiseConfig) -> GameEvent:
	var e := events.add(GameEvent.Kind.FOOTSTEP)
	e.actor = c.id
	e.value = kind
	e.value2 = query.surface_under(c.position)
	e.position = c.position
	if noise != null:
		e.carry = noise.carry(e.value2)
		if c.in_bush:
			e.value2 = RayHit.Surface.LEAVES
			e.carry = maxf(e.carry, noise.bush_carry)
	return e

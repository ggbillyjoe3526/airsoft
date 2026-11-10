class_name Accuracy
## Accuracy by stance and movement (the browser game's sim/accuracy.ts): how much a character's state scales its
## replica's spread. Holding still, crouching above all, is steady, and steadier the longer you hold; moving, jumping,
## firing on the run in a sprint and the moments after one are not; the sight raised to the eye tightens it (M84), and
## the more for a replica with a hip spread (ReplicaConfig.hip_spread, SN1). A compact replica swings less on the move
## (ReplicaConfig.move_spread, CS1).
## Bots and the player follow the same rule.

## Summed tick lengths drift below round numbers (9 × 1/60 < 0.15): keeps the delay a whole number of ticks.
const AIR_TIME_EPSILON := 1e-9


## The spread multiplier `c`'s state calls for now (before settling): movement times stance times the sight.
static func target_spread_scale(c: Character, cfg: MovementConfig, a: AccuracyConfig) -> float:
	var speed := sqrt(c.velocity.x * c.velocity.x + c.velocity.z * c.velocity.z)
	var move: float
	if not c.grounded and c.air_time >= a.air_spread_delay - AIR_TIME_EPSILON:
		move = a.air
	elif c.sprinting:
		move = a.sprint
	elif speed <= a.still_below:
		move = 1.0 + (a.steady - 1.0) * minf(1.0, c.still_time / a.steady_time)
	elif speed <= cfg.walk_speed:
		move = 1.0 + (a.walk - 1.0) * (speed - a.still_below) / (cfg.walk_speed - a.still_below)
	else:
		move = a.walk + (a.run - a.walk) * minf(1.0, (speed - cfg.walk_speed) / (cfg.run_speed - cfg.walk_speed))
	# A compact replica takes only its move_spread share of what moving adds (CS1); holding still is as steady.
	var r := c.armament.replica() if c.armament != null else null
	if move > 1.0 and r != null:
		move = 1.0 + (move - 1.0) * r.move_spread
	# Crouching steadies a still shooter fully, a moving one less (audit SIM-10).
	var moving := clampf((speed - a.still_below) / (cfg.crouch_speed - a.still_below), 0.0, 1.0)
	var crouched := a.crouched + (a.crouched_moving - a.crouched) * moving
	var aimed := 1.0 + (a.aimed - 1.0) * c.aim_raise
	# A replica with a hip spread (the Sniper Rifle) is that much wider with the sight down, less as it comes up; one
	# under 1 (the Compact SMG, CS1) that much tighter.
	var hip := 1.0 + ((r.hip_spread if r != null else 1.0) - 1.0) * (1.0 - c.aim_raise)
	return move * (1.0 + (crouched - 1.0) * c.crouch_amount) * aimed * hip


## One tick: the multiplier jumps up to the target at once and comes back down once the shake stops, within a few ticks
## after walking or running (lock_time, the "instant lock"), more slowly for carry_time after a sprint or a landing.
static func step(c: Character, cfg: MovementConfig, a: AccuracyConfig, dt: float) -> void:
	c.air_time = 0.0 if c.grounded else c.air_time + dt
	var still := c.grounded and sqrt(c.velocity.x * c.velocity.x + c.velocity.z * c.velocity.z) <= a.still_below
	c.still_time = c.still_time + dt if still else 0.0
	var shaken := c.sprinting or (not c.grounded and c.air_time >= a.air_spread_delay - AIR_TIME_EPSILON)
	var r := c.armament.replica()
	var carry := a.carry_time * (r.shake_scale if r != null else 1.0)
	c.shake_carry = carry if shaken else maxf(0.0, c.shake_carry - dt)
	var target := target_spread_scale(c, cfg, a)
	var settle := a.settle_time if c.shake_carry > 0.0 else a.lock_time
	if target >= c.spread_scale:
		c.spread_scale = target
	else:
		c.spread_scale = target + (c.spread_scale - target) * exp(-dt / settle)

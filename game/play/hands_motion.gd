class_name HandsMotion
extends RefCounted
## The life in the replica in your hands (FP1; HandsLifeConfig): `step` it each rendered frame from the character's
## state, then draw `shift` (m) and `turn` (rad: tip, yaw, roll, turned about the replica's own place) over its pose.
## A bob with each step, breathing, a lean into a strafe, a lag through a jump and a dip on landing and through a
## crouch (a spring), a flick and a roll from each shot and each draw (another spring), and a cant as the sight comes
## up. Nothing here is random, and nothing allocates.

## The longest step a spring takes at once (s): a hitch moves it no further than this.
const MAX_STEP := 0.1

var shift: Vector3 = Vector3.ZERO
var turn: Vector3 = Vector3.ZERO
## The bob: how far round its cycle (rad), and how much of it shows.
var _phase: float = 0.0
var _bob: float = 0.0
## The breath, how far round (rad; it wraps every two, its drift taking two to come round).
var _breath: float = 0.0
## Your pace across and ahead, as shares of lean_speed, followed.
var _lean: Vector2 = Vector2.ZERO
## The spring up and down: where it is (m) and its speed (m/s).
var _lift: float = 0.0
var _lift_speed: float = 0.0
## The springs of the tip and the roll (rad, rad/s).
var _tip: float = 0.0
var _tip_speed: float = 0.0
var _roll: float = 0.0
var _roll_speed: float = 0.0
## Which way the next shot rolls it.
var _side: float = 1.0
## The character last step: on the ground, how fast it fell (m/s) and how far crouched.
var _grounded: bool = true
var _fall: float = 0.0
var _crouch: float = 0.0


## A shot: the muzzle flicks up and rolls, to the other side from the last one.
func shot(cfg: HandsLifeConfig) -> void:
	_tip_speed += cfg.shot_flick
	_roll_speed += cfg.shot_roll * _side
	_side = -_side


## A draw: it arrives rolled and tipped down, and settles.
func drawn(cfg: HandsLifeConfig) -> void:
	_roll_speed += cfg.draw_roll
	_tip_speed -= cfg.draw_tip


## Still, as at a spawn or once the replica is out of view.
func rest(c: Character = null) -> void:
	shift = Vector3.ZERO
	turn = Vector3.ZERO
	_bob = 0.0
	_lean = Vector2.ZERO
	_lift = 0.0
	_lift_speed = 0.0
	_tip = 0.0
	_tip_speed = 0.0
	_roll = 0.0
	_roll_speed = 0.0
	_fall = 0.0
	_grounded = c == null or c.grounded
	_crouch = c.crouch_amount if c != null else 0.0


## Moves it on `delta` seconds for `c`, looking along `look` (the world's), the sight raised `raise` (0..1, as drawn),
## drawing `motion`'s shares (Reduced motion).
func step(cfg: HandsLifeConfig, c: Character, look: Vector3, delta: float, raise: float, motion: MotionScale) -> void:
	var dt := clampf(delta, 0.0, MAX_STEP)
	var ahead := Vector3(look.x, 0.0, look.z)
	ahead = ahead.normalized() if ahead.length_squared() > 1e-6 else Vector3.ZERO
	var pace := Vector2(c.velocity.dot(ahead.cross(Vector3.UP)), c.velocity.dot(ahead))
	var speed := pace.length()

	# Steps: the bob turns with the ground covered, and shows by the pace.
	var stepping := c.grounded and speed > cfg.bob_from
	var whole := minf(speed / maxf(cfg.bob_speed, 0.001), cfg.bob_most) if stepping else 0.0
	_bob = lerpf(_bob, whole, 1.0 - exp(-cfg.bob_rate * dt))
	if stepping:
		_phase = fposmod(_phase + speed * dt / maxf(cfg.bob_stride, 0.001) * TAU, TAU)
	_breath = fposmod(_breath + dt / maxf(cfg.breath_period, 0.001) * TAU, 2.0 * TAU)
	_lean = _lean.lerp((pace / maxf(cfg.lean_speed, 0.001)).limit_length(cfg.bob_most), 1.0 - exp(-cfg.lean_rate * dt))

	# Up and down: trailing a rise or a fall, knocked down by a landing, pushed by a crouch.
	var hang := 0.0
	if not c.grounded:
		hang = clampf(-c.velocity.y * cfg.air_lift, -cfg.air_most, cfg.air_most)
	elif not _grounded and _fall > cfg.land_from:
		_lift_speed -= minf(_fall * cfg.land_dip, cfg.land_most)
	_lift_speed += (c.crouch_amount - _crouch) * cfg.crouch_push
	_grounded = c.grounded
	_fall = maxf(-c.velocity.y, 0.0) if not c.grounded else 0.0
	_crouch = c.crouch_amount
	var sprung := spring(_lift, _lift_speed, hang, cfg.lift_spring, dt)
	_lift = sprung.x
	_lift_speed = sprung.y
	sprung = spring(_tip, _tip_speed, 0.0, cfg.turn_spring, dt)
	_tip = sprung.x
	_tip_speed = sprung.y
	sprung = spring(_roll, _roll_speed, 0.0, cfg.turn_spring, dt)
	_roll = sprung.x
	_roll_speed = sprung.y

	var calm := lerpf(1.0, cfg.aimed, clampf(raise, 0.0, 1.0))
	var soft := calm * motion.sway
	var hard := calm * motion.kick
	# Breathing gives way to the bob as you walk.
	var breath := 1.0 - minf(_bob, 1.0)
	var swing := sin(_phase)
	var tread := sin(2.0 * _phase)
	shift = Vector3(
			swing * cfg.bob_side * _bob + sin(0.5 * _breath) * cfg.breath_drift * breath - _lean.x * cfg.lean_trail,
			-tread * cfg.bob_lift * _bob + sin(_breath) * cfg.breath_lift * breath + _lift,
			_lean.y * cfg.lean_back) * soft
	turn = Vector3(
			(tread * cfg.bob_tip * _bob + cos(_breath) * cfg.breath_tip * breath) * soft + _tip * hard,
			0.0,
			(-swing * cfg.bob_roll * _bob - _lean.x * cfg.lean_roll) * soft + _roll * hard
			+ sin(PI * clampf(raise, 0.0, 1.0)) * cfg.aim_cant * motion.sway)


## A damped spring a step on: from `at`, moving at `speed`, drawn to `to` (`how`: x its rate, rad/s; y its damping),
## over `dt` s; x: where it is now, y: its speed. Steady at any step (it never gains).
static func spring(at: float, speed: float, to: float, how: Vector2, dt: float) -> Vector2:
	var drag := 1.0 + 2.0 * dt * how.y * how.x
	var pull := dt * how.x * how.x
	var over := 1.0 / (drag + dt * pull)
	return Vector2((drag * at + dt * speed + dt * pull * to) * over, (speed + pull * (to - at)) * over)

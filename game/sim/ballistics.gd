class_name Ballistics
## A BB's flight through the air (the browser game's sim/ballistics.ts, M30): gravity, drag along the airflow from the
## Reynolds number, Magnus lift across it from the hop-up's backspin, and that spin decaying. The airflow is the BB's
## velocity less the wind, so a breeze drifts it. Pure: depends only on the BB, the air and the wind. Also the hop-up
## readouts (sim/hopUp.ts) and how a replica's stats become a BB's speed, mass and spin.

## Grams in a kilogram (a replica's bb_weight is in grams, a BB's mass in kg).
const GRAMS_PER_KG := 1000.0
## Below this airspeed (m/s) there is no airflow to drag or lift a BB.
const MIN_AIRSPEED := 1e-6
## Below this |spin axis × airflow| the lift has no direction (the BB flies along its spin axis).
const MIN_CROSS := 1e-9


## What a hop-up setting does to a level shot (hop_up_reach).
class HopUpReach:
	extends RefCounted
	## Metres the BB stays within the band of the aim line (the readout range if it never leaves it).
	var on_target_to: float = 0.0
	## Highest it climbs above the aim line (m, 0 if it never does).
	var peak_rise: float = 0.0


## Advances a BB's flight by `dt` (no collision) with the air model `air`, in `wind` (m/s; still air by default).
## Second order (the midpoint method): the forces are worked out at the start of the step and again half way through,
## and the step moves on with the half-way ones, so one step a 60 Hz tick stays within millimetres of the exact flight
## at 50 m.
static func step_flight(bb: BB, air: AirModel, dt: float, wind: Vector3 = Vector3.ZERO) -> void:
	var half := dt * 0.5
	var decay := air.spin_decay / bb.mass
	var v := bb.velocity
	var speed0 := (v - wind).length()
	var mid := v + _acceleration(bb, air, v - wind, speed0, bb.spin) * half
	var mid_spin := bb.spin * (1.0 - decay * speed0 * half)
	var speed1 := (mid - wind).length()
	var a1 := _acceleration(bb, air, mid - wind, speed1, mid_spin)
	bb.position += mid * dt
	bb.velocity = v + a1 * dt
	# The air's friction torque: dω/dt = −decay · airspeed · ω (never below zero, however long the step).
	bb.spin = maxf(0.0, bb.spin * (1.0 - decay * speed1 * dt))
	bb.age += dt


## step_flight with `cfg`'s air model: for callers that fly one BB now and then (readouts, tests).
static func step_bb_flight(bb: BB, cfg: BallisticsConfig, dt: float) -> void:
	step_flight(bb, AirModel.of(cfg), dt)


## About how long (s) a BB fired at `speed` m/s takes to fly `distance` m, from drag alone (straight-line flight with
## the drag coefficient at the muzzle): t = (e^(k·d) − 1) / (k·v₀), k = ½ρ·Cd·A / m. Within a few per cent of the full
## flight over a field's ranges, and cheap enough for a bot to lead a target with every tick. INF for no speed or mass.
## `field_air` is the field's own air (GameState.air, PH1); null: the air replicas are rated in.
static func flight_time_estimate(distance: float, speed: float, mass: float, cfg: BallisticsConfig,
		field_air: AirModel = null) -> float:
	if not (speed > 0.0) or not (mass > 0.0):
		return INF
	var air := field_air if field_air != null else AirModel.of(cfg)
	var k := air.drag_factor(speed) / mass
	return (exp(k * maxf(0.0, distance)) - 1.0) / (k * speed)


## A BB's mass (kg) at `grams` (the replica's factory weight when `grams` isn't positive).
static func bb_mass(replica: ReplicaConfig, grams: float = -1.0) -> float:
	return _grams(replica, grams) / GRAMS_PER_KG


## Muzzle energy (J) of `replica` shooting `grams` BBs: its rated energy at its factory weight, shifted by
## rules.bb_energy_exponent for other weights.
static func muzzle_energy(replica: ReplicaConfig, rules: ReplicaRulesConfig, grams: float = -1.0) -> float:
	return replica.muzzle_energy * weight_energy_share(replica, rules, grams)


## The share of its rated muzzle energy `replica` shoots `grams` BBs with: 1 at its factory weight, a little more for a
## heavier BB (it takes more of the push), by rules.bb_energy_exponent.
static func weight_energy_share(replica: ReplicaConfig, rules: ReplicaRulesConfig, grams: float = -1.0) -> float:
	return pow(_grams(replica, grams) / replica.bb_weight, rules.bb_energy_exponent)


## Muzzle velocity (m/s) of `replica` shooting `grams` BBs: E = ½·m·v².
static func muzzle_velocity(replica: ReplicaConfig, rules: ReplicaRulesConfig, grams: float = -1.0) -> float:
	return sqrt(2.0 * muzzle_energy(replica, rules, grams) / bb_mass(replica, grams))


## The hop-up lift (hop_up_max units) `replica` gives with its dial at `dial`, clamped to the dial's range.
static func hop_up_lift(replica: ReplicaConfig, dial: float, rules: ReplicaRulesConfig) -> float:
	return replica.hop_up_max * clampf(dial, rules.hop_up_min_dial, rules.hop_up_max_dial)


## Flies one `grams` BB level from `replica` with its dial at `dial` (the game's flight, no spread, stepped `dt` a time
## as the game ticks) and reports how far it stays within `band` m of the aim line, following it at most
## `readout_range` m, and how high it rises. For the Loadout's readout; allocates, so never per tick. `field_air` is
## the field's own air (GameState.air, PH1: the HUD's readout in a match); null: the air replicas are rated in.
static func hop_up_reach(replica: ReplicaConfig, dial: float, tuning: SimTuning, dt: float, band: float,
		readout_range: float, grams: float = -1.0, field_air: AirModel = null) -> HopUpReach:
	var cfg := tuning.ballistics
	var bb := _level_shot(replica, dial, tuning, grams)
	var air := field_air if field_air != null else AirModel.of(cfg)
	var reach := HopUpReach.new()
	reach.on_target_to = readout_range
	while bb.age < cfg.max_lifetime:
		step_flight(bb, air, dt)
		var distance := -bb.position.z
		if distance >= readout_range:
			break
		reach.peak_rise = maxf(reach.peak_rise, bb.position.y)
		if absf(bb.position.y) > band:
			reach.on_target_to = distance
			break
	# Past the band it may still climb (over-hopped): follow it to its peak for the readout.
	while bb.age < cfg.max_lifetime and bb.velocity.y > 0.0 and -bb.position.z < readout_range:
		step_flight(bb, air, dt)
		reach.peak_rise = maxf(reach.peak_rise, bb.position.y)
	return reach


## Seconds a level-fired `grams` BB from `replica` with its dial at `dial` takes to fly `distance` m, interpolated
## between steps of `dt`, or INF if it never gets there.
static func flight_time(replica: ReplicaConfig, dial: float, distance: float, tuning: SimTuning, dt: float,
		grams: float = -1.0) -> float:
	var cfg := tuning.ballistics
	var bb := _level_shot(replica, dial, tuning, grams)
	var air := AirModel.of(cfg)
	var before := 0.0
	while bb.age < cfg.max_lifetime:
		var t := bb.age
		step_flight(bb, air, dt)
		var reached := -bb.position.z
		if reached >= distance:
			return t + dt * (distance - before) / (reached - before)
		before = reached
	return INF


## The BB's acceleration in airflow `v` (its velocity less the wind; airspeed `speed`) with spin `spin`: gravity, drag
## against the airflow and Magnus lift across it (spin axis × airflow, so backspin lifts).
static func _acceleration(bb: BB, air: AirModel, v: Vector3, speed: float, spin: float) -> Vector3:
	var acc := Vector3(0.0, -air.gravity, 0.0)
	if speed < MIN_AIRSPEED:
		return acc
	acc -= v * (air.drag_factor(speed) * speed / bb.mass)
	if spin > 0.0:
		# |axis × v| = speed · sin(angle between them); lift = ½ρA·CL·v² across the airflow, so scale axis × v by
		# ½ρA·CL·speed / (m · sin). The axis is level and square to the barrel, so the sine stays close to 1.
		var l := bb.spin_axis.cross(v)
		var cross := l.length()
		if cross > MIN_CROSS:
			acc += l * (air.lift_factor * air.lift_coefficient(spin * air.radius / speed) * speed * speed / (bb.mass * cross))
	return acc


## A BB fired level along -Z from the origin by `replica` with its dial at `dial`.
static func _level_shot(replica: ReplicaConfig, dial: float, tuning: SimTuning, grams: float) -> BB:
	var rules := tuning.replica_rules
	return BBPool.new(1).spawn(0, Vector3.ZERO, Vector3.FORWARD, muzzle_velocity(replica, rules, grams),
			hop_up_lift(replica, dial, rules), bb_mass(replica, grams), tuning.ballistics.spin_per_hop)


static func _grams(replica: ReplicaConfig, grams: float) -> float:
	return grams if grams > 0.0 else replica.bb_weight

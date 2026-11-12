class_name Wind
extends RefCounted
## The match's breeze (the browser game's sim/wind.ts, M30), drawn once a match from its seed: its mean strength and
## direction, and where each gust wave starts. Plain data; `at` turns it into the wind at a moment of the match.

## Stirs the match seed so the wind's draws don't follow the simulation's own stream.
const SALT := 0x5f3759df

## Mean strength (m/s).
var speed: float = 0.0
## The way it blows towards, as a yaw (rad; 0 blows towards -Z, as a character's yaw 0 faces).
var yaw: float = 0.0
## Start phases (rad) of the two strength waves (x, y) and the direction wave (z).
var phases: Vector3 = Vector3.ZERO
var _cfg: WindConfig = null


## Still air: no strength, so `at` is zero (tests and tools that fly BBs without a match).
static func still(cfg: WindConfig) -> Wind:
	var w := Wind.new()
	w._cfg = cfg
	return w


## Draws this match's breeze for `seed_value`: a strength between the config's least and most, from any direction,
## and `share` of it (the field's exposure, GameState.wind_share: 0 indoors, where the air stands still, PH1).
func draw(seed_value: int, cfg: WindConfig, share: float = 1.0) -> void:
	_cfg = cfg
	var rng := Seeds.stream((seed_value ^ SALT) & Seeds.MASK_32)
	speed = lerpf(cfg.min_speed, cfg.max_speed, rng.randf()) * maxf(share, 0.0)
	yaw = rng.randf() * TAU
	phases = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)


## The wind (m/s, level) `time` seconds into the match: the mean breeze, its strength rising and falling by up to
## `gust` of itself on two slow waves, its direction swinging by up to `veer` on a third. Pure.
func at(time: float) -> Vector3:
	if speed <= 0.0:
		return Vector3.ZERO
	var c := _cfg
	var swing := c.gust_mix.x * sin(TAU * time / c.gust_periods.x + phases.x) \
			+ c.gust_mix.y * sin(TAU * time / c.gust_periods.y + phases.y)
	var strength := speed * (1.0 + c.gust * swing)
	var heading := yaw + c.veer * sin(TAU * time / c.veer_period + phases.z)
	return Vector3(-sin(heading) * strength, 0.0, -cos(heading) * strength)

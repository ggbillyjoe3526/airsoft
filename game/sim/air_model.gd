class_name AirModel
extends RefCounted
## Everything a BB's flight step needs to know about the air (the browser game's sim/air.ts), worked out once per
## BallisticsConfig: the drag factor ½·ρ·Cd·A (kg/m) tabulated by airspeed, so a step costs a table read instead of a
## Reynolds number and three powers, and the constants for Magnus lift and spin decay. Get one with AirModel.of(cfg), or
## AirModel.at(cfg, temperature) for a field's own air (PH1).

## Specific gas constant of dry air, J/(kg·K).
const R_AIR := 287.05
## Sutherland's law for air: reference viscosity (Pa·s) at the reference temperature (K), and its constant (K).
const MU_REF := 1.716e-5
const T_REF := 273.15
const SUTHERLAND := 110.4
## 0 °C in kelvin.
const ZERO_CELSIUS := 273.15
## Highest airspeed (m/s) the drag table covers: faster than any replica (the fastest is about 100 m/s).
const TABLE_TOP := 200
## Table entries per m/s.
const TABLE_RES := 2

## The models built so far, by their config's instance id. A model doesn't hold its config, so a config can still be
## freed; its entry is dropped the next time a model is built.
static var _models: Dictionary[int, AirModel] = {}

## ½·ρ·Cd(Re(v))·A (kg/m) at airspeeds 0, 1/TABLE_RES, 2/TABLE_RES … TABLE_TOP m/s, and one past it.
var drag: PackedFloat64Array = PackedFloat64Array()
## ½·ρ·A (kg/m): lift force = lift_factor · CL · v².
var lift_factor: float = 0.0
## 1.25·ρ·A·spin_friction (kg/m): spin decays at spin_decay · v / m per second.
var spin_decay: float = 0.0
## BB radius (m), for the spin ratio ω·r / v.
var radius: float = 0.0
var lift_base: float = 1.0
var lift_slope: float = 0.0
var gravity: float = 0.0


## The AirModel of `cfg`, built on first use and kept for as long as the game runs. Changing `cfg` after its first use
## doesn't change its model (as in the browser game).
static func of(cfg: BallisticsConfig) -> AirModel:
	var key := cfg.get_instance_id()
	var model: AirModel = _models.get(key, null)
	if model == null:
		for id: int in _models.keys():
			if not is_instance_id_valid(id):
				_models.erase(id)
		model = AirModel.new()
		model._build(cfg, cfg.air_temperature)
		_models[key] = model
	return model


## The AirModel of `cfg` in air at `temperature` (°C) instead of its own (a field's weather, PH1): `of(cfg)` itself at
## cfg's temperature, else a new model, so once a match (Simulation.set_weather), never per tick.
static func at(cfg: BallisticsConfig, temperature: float) -> AirModel:
	if is_equal_approx(temperature, cfg.air_temperature):
		return of(cfg)
	var model := AirModel.new()
	model._build(cfg, temperature)
	return model


## Air density (kg/m³) from the ideal gas law: 1.204 at 20 °C and sea level.
static func air_density(temperature: float, pressure: float) -> float:
	return pressure / (R_AIR * (temperature + ZERO_CELSIUS))


## Dynamic viscosity of air (Pa·s) from Sutherland's law: 1.81e-5 at 20 °C.
static func air_viscosity(temperature: float) -> float:
	var t := temperature + ZERO_CELSIUS
	return MU_REF * pow(t / T_REF, 1.5) * ((T_REF + SUTHERLAND) / (t + SUTHERLAND))


## Drag coefficient of a smooth sphere at Reynolds number `re` (Morrison's 2013 fit to the measured curve, good to
## Re 10⁶; the numbers are the fit's). A BB flies at Re ~5,000–40,000, where Cd sits close to 0.4. 0 for Re ≤ 0.
static func sphere_drag_coefficient(re: float) -> float:
	if not (re > 0.0):
		return 0.0
	var a := re / 5.0
	var b := re / 263000.0
	var c := re / 1e6
	return 24.0 / re + (2.6 * a) / (1.0 + pow(a, 1.52)) + (0.411 * pow(b, -7.94)) / (1.0 + pow(b, -8.0)) \
			+ (0.25 * c) / (1.0 + c)


## ½·ρ·Cd·A (kg/m) at airspeed `speed` (m/s), read from the table with linear interpolation; past the top it holds the
## last value.
func drag_factor(speed: float) -> float:
	var x := minf(speed * TABLE_RES, float(drag.size() - 2))
	var i := int(x)
	var f := x - i
	return drag[i] + (drag[i + 1] - drag[i]) * f


## Magnus lift coefficient at spin ratio `s` (ω·r / v): about s at a hop-up's ratios, levelling off near 0.5.
func lift_coefficient(s: float) -> float:
	return s / (lift_base + lift_slope * s)


func _build(cfg: BallisticsConfig, temperature: float) -> void:
	var rho := air_density(temperature, cfg.air_pressure)
	var mu := air_viscosity(temperature)
	radius = cfg.bb_diameter / 2.0
	var area := PI * radius * radius
	drag.resize(TABLE_TOP * TABLE_RES + 2)
	for i in drag.size():
		var v := float(i) / TABLE_RES
		drag[i] = 0.5 * rho * area * sphere_drag_coefficient(rho * v * cfg.bb_diameter / mu)
	# Re 0 has no drag coefficient; the next entry's is close enough for a BB that has all but stopped.
	drag[0] = drag[1]
	lift_factor = 0.5 * rho * area
	# The air's friction torque on a spinning sphere, per unit spin ratio (the browser game's fit).
	spin_decay = 1.25 * rho * area * cfg.spin_friction
	lift_base = cfg.lift_base
	lift_slope = cfg.lift_slope
	gravity = cfg.gravity

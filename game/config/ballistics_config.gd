class_name BallisticsConfig
extends Resource
## BB flight (the browser game's config/ballistics.ts, M30): a 5.95 mm plastic sphere in air. Gravity; drag along the
## airflow, ½·ρ·Cd·A·v², with Cd from the Reynolds number; Magnus lift from the hop-up's backspin across the airflow; the
## backspin itself decays under the air's friction torque. So a hopped BB flies flat while its spin holds it up, then
## drops away as it slows. Read by game/sim/air_model.gd and game/sim/ballistics.gd.

## m/s².
@export var gravity: float = 9.81
## The air replicas are rated in (°C, Pa): sea-level air on a mild day. Density and viscosity follow from it. A field's
## own air may be colder (data/maps.md's Air column, WeatherConfig; AirModel.at).
@export var air_temperature: float = 20.0
@export var air_pressure: float = 101325.0
## BB diameter (m): the standard 5.95 mm airsoft BB.
@export var bb_diameter: float = 5.95e-3
## Backspin (rad/s) per unit of hop-up lift (a replica's hop_up_max × its dial). Tuned so the factory dials keep the
## rifle on target to ~38 m and the pistol to ~26 m.
@export var spin_per_hop: float = 5000.0
## Magnus lift coefficient's fit to the spin ratio S = ω·r / v: CL = S / (lift_base + lift_slope · S).
@export var lift_base: float = 0.981
@export var lift_slope: float = 2.022
## The air's friction torque on a spinning BB per unit spin ratio: spin decays at 1.25·ρ·A·spin_friction·v / m per second.
@export var spin_friction: float = 0.05
## Seconds before an unhit BB is removed: longer than the longest shot a replica can lob takes to land (PH1: the Sniper
## Rifle at its site limit with 0.40 g BBs, 130 m in 5.5 s at 24° up; at 2.5 s a lobbed BB vanished in the air past
## about 70 m). A level shot lands within about 1.5 s.
@export var max_lifetime: float = 6.0
## BBs in flight at once (the pool's size); a full pool reuses the oldest.
@export var max_bbs: int = 256

@export_group("Leaves")
## Bushes (FO1, the browser game's BALLISTICS.leaves; Foliage, Leaves, BBStep): a BB that runs into one pushes through
## its leaves. Once it has crossed leaf_stop_depth of them (m, counted over its whole flight) it stops there: the same
## depth bots can't see through (BotConfig.foliage_see_through; a test holds them equal), so a bush you can't see through
## is cover. One that comes out having crossed less (an edge) flies on, keeping leaf_kept_per_metre of its speed and
## backspin a metre of leaves (exponential) and thrown off its line by up to leaf_scatter_per_metre radians a metre.
@export var leaf_stop_depth: float = 0.6
@export var leaf_kept_per_metre: float = 0.35
@export var leaf_scatter_per_metre: float = 0.5

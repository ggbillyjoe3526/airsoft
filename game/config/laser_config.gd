class_name LaserConfig
extends Resource
## Dev › Lasers (LZ1, the owner's Easter egg, 2026-11-08): every replica fires a laser instead of a BB. A laser has no
## flight: it reaches the first of the level, a range target or a body along a straight line from the eyes in the tick
## it is fired (BBStep), through as much bush as a BB pushes through (BallisticsConfig.leaf_stop_depth) and never
## bouncing. Part of SimTuning (sim_tuning.tres). How its beam is drawn is EffectsConfig's (laser_*).

## How far a laser reaches (m): further than any map's longest sight line; past it the beam ends in the air.
@export var reach: float = 150.0
## At most this many bushes along one laser's line are looked at for leaves; past them it goes on through.
@export var most_bushes: int = 8

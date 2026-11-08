class_name FlagState
extends RefCounted
## Attack / Defend's flagpole as plain data (the browser game's sim/flag.ts FlagState). Flag writes it; the HUD and the
## pole read it.

## Who is working the rope: nobody, the attackers alone, the defenders alone (with the flag off the bottom), or both
## at once (it doesn't move).
enum Status { IDLE, RAISING, LOWERING, CONTESTED }

## The foot of the pole (map data: by the defenders' end).
var position: Vector3 = Vector3.ZERO
## How far up the pole the attackers' flag is: 0 the bottom, 1 raised (the attackers win).
var progress: float = 0.0
## Seconds the flag has stayed fully raised (FlagConfig.hold_time of them win); 0 off the top.
var held: float = 0.0
var status: Status = Status.IDLE


## The flag at the bottom of the pole at `at`, for a new round.
func reset(at: Vector3) -> void:
	position = at
	progress = 0.0
	held = 0.0
	status = Status.IDLE

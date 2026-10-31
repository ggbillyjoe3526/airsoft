class_name CharacterMover
extends RefCounted
## Moves characters through the level with collision (docs/ARCHITECTURE.md › Contracts 4; the browser game's
## sim/movement.ts CharacterMover). BoxWorld implements it for headless tests; the map's Jolt implementation in the game.


## The collision-corrected translation for `c` trying to move by `desired` this tick.
func move(_c: Character, desired: Vector3) -> Vector3:
	return desired


## Whether `c`, crouched, has room to stand up where it is: nothing over its crouched body lower than a standing one.
func room_to_stand(_c: Character) -> bool:
	return true


## The vertical offset that puts `c` exactly at rest on the ground beneath it (negative is down, slightly positive if it
## has crept into the floor), or NAN if there is no ground within `max_drop` below its feet.
func probe_ground(_c: Character, _max_drop: float) -> float:
	return NAN

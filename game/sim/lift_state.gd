class_name LiftState
extends RefCounted
## The level's lifts as the round has left them (MT2): where each car is, what it is doing, the stops called and
## its doors. Lifts writes it; the view and the bots read it. Sized to the level's lifts at each match's start
## (Lifts.reset), never during a tick.

## What a car is doing. OPEN: standing at `stop`, doors open. SHUTTING, then MOVING to `to`, then OPENING at it.
enum Phase { OPEN, SHUTTING, MOVING, OPENING }

## The car's floor's top (m), now and a tick ago (the view draws between them).
var y: PackedFloat32Array = PackedFloat32Array()
var prev_y: PackedFloat32Array = PackedFloat32Array()
## How far it rose this tick (m; negative: down): what its riders rise with it.
var rise: PackedFloat32Array = PackedFloat32Array()
## The stop it stands at, or last stood at while moving; the stop it is making for while moving (-1: none).
var stop: PackedInt32Array = PackedInt32Array()
var to: PackedInt32Array = PackedInt32Array()
## Its Phase, by lift.
var phase: PackedByteArray = PackedByteArray()
## Seconds left of its doors' motion (SHUTTING, OPENING), or of its wait before it may shut (OPEN).
var left: PackedFloat32Array = PackedFloat32Array()
## How open its doors stand at `stop` (0 shut, 1 open), for the view.
var doors: PackedFloat32Array = PackedFloat32Array()
## The stops called, a bit each (stop k is bit k).
var calls: PackedInt32Array = PackedInt32Array()
## The way it last moved: 1 up, -1 down, 0 not yet.
var heading: PackedInt32Array = PackedInt32Array()
## Seconds to its next buzz while too full to leave (LiftConfig.buzz_every).
var buzz_left: PackedFloat32Array = PackedFloat32Array()
## Who last pressed one of its buttons (a character's id, -1 none): its chime and motor are news of them.
var caller: PackedInt32Array = PackedInt32Array()


## How many lifts the level has.
func count() -> int:
	return y.size()


## Whether lift `i`'s car stands at stop `k` with its doors fully open: a body may walk in or out.
func open_at(i: int, k: int) -> bool:
	return phase[i] == Phase.OPEN and stop[i] == k


## Whether stop `k` of lift `i` is called.
func called(i: int, k: int) -> bool:
	return (calls[i] >> k) & 1 != 0

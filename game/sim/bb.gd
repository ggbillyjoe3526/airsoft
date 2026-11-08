class_name BB
extends RefCounted
## One BB in flight (the browser game's sim/ballistics.ts BB). Pooled in BBPool: `active` false means the slot is free.

var active: bool = false
## Grows with every BB fired, so presentation can tell a reused slot holds a new BB.
var serial: int = 0
var owner_id: int = -1
## The loadout slot of the replica that fired it (-1: none), for presentation (Glowing BBs, WL8). Never read in flight.
var slot: int = -1
var position: Vector3 = Vector3.ZERO
## Where it was at the start of the last tick: the segment checked for hits, and for drawing between ticks.
var prev_position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
## Seconds since fired.
var age: float = 0.0
## Backspin (rad/s) from the hop-up, decaying in flight: it lifts the BB (Magnus).
var spin: float = 0.0
## The spin's axis (unit): level and square to the barrel, set at the muzzle (a spinning BB keeps its axis).
var spin_axis: Vector3 = Vector3.RIGHT
## Mass (kg): drag, lift and the spin's decay all depend on it.
var mass: float = 0.0
## Times it has bounced off a surface: a BB with bounces > 0 is a ricochet.
var bounces: int = 0
## Metres of bush leaves it has pushed through so far (Foliage, BBStep): at BallisticsConfig.leaf_stop_depth it stops.
var leaf: float = 0.0
## A laser, not a BB (Dev › Lasers, LZ1): it never flies, BBStep resolves it in the tick it is fired, and it is free
## again before anything draws it.
var laser: bool = false

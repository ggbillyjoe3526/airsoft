class_name LiftConfig
extends Resource
## Lifts (MT2): how a car's doors, ride and buttons behave, how big a car is and how far it is heard. The simulation
## keeps them (Lifts); the map says where each car runs and where it stops (MapData.lifts). The concept's defaults
## (Subway v2, 2026-11-10): 4 players a car, doors 1.5 s, 4 s a floor. Part of SimTuning (sim_tuning.tres).

## A car's doors (and the landing's with them) take this long to open or to shut (s). They stop BBs and bodies from
## the moment they start to shut until they stand fully open.
@export var door_time: float = 1.5
## A car takes this long from one stop to the next (s), whatever the floors' height apart.
@export var floor_time: float = 4.0
## Once its doors stand open, a car waits at least this long (s) before it shuts them for a call: time to walk out.
@export var dwell: float = 2.0
## A car leaves with at most this many aboard; one more and it stays open, buzzing (`buzz_every`).
@export var capacity: int = 4
@export var buzz_every: float = 1.0
## A car's height inside, floor to ceiling, and its floor's and roof's thickness (m).
@export var car_height: float = 2.4
@export var floor_thickness: float = 0.15
@export var roof_thickness: float = 0.15
## Feet this far under a car's floor still ride it (m), standing on it as it starts down.
@export var ride_below: float = 0.2
## A landing's call button is in reach of feet this close to the middle of its doorway, measured level (m), outside
## the shaft and no more than reach_up below or above the landing's floor. Inside a car, its panel is in reach.
@export var reach: float = 1.6
@export var reach_up: float = 1.0
## The panel inside a car: on the inside of the door's wall, this far beside the door's far jamb (m), each stop's button
## this high over the floor (the lowest stop's lowest) and the next this much higher.
@export var panel_beside: float = 0.2
@export var panel_low: float = 1.0
@export var panel_step: float = 0.22
## A landing's call button stands this far beside its door's jamb (m), this high over the landing's floor.
@export var call_beside: float = 0.3
@export var call_height: float = 1.1
## Where a body waits for a car and walks out to: this far out from the door's face, on the landing (m).
@export var landing_out: float = 0.8
## How far a car's chime, doors and motor are heard (m), walls or none.
@export var heard: float = 24.0
## How far a button's beep carries (m): the caller's hand, not the car.
@export var button_heard: float = 6.0

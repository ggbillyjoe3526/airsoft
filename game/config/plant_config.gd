class_name PlantConfig
extends Resource
## Plant The Bomb's device (PB1, owner 2026-11-12): a game prop, as bomb games at real sites are played with a timer
## box. It lies at the attackers' start each round; one attacker carries it to a site and arms it, and the defenders
## must disarm it before its timer runs out. Read by game/sim/plant.gd and round.gd.

## The bomb lies this far (m) ahead of the middle of the attackers' spawn line on a map that names no `bombStart`.
@export var start_ahead: float = 2.5
## An attacker in play holding Use within this distance of the bomb on the ground (m, flat) picks it up: an arm's reach
## and a step.
@export var pickup_reach: float = 1.6
## ... with its feet within this height of the bomb (m): no pick-up, plant or defuse from the floor above or below
## (FlagConfig.reach_height's rule).
@export var reach_height: float = 1.0
## A site's radius (m, flat) on a map whose site names none: the carrier plants anywhere inside it.
@export var site_radius: float = 4.5
## Seconds the carrier holds Use, standing in a site, to arm the bomb. Letting go, being hit or leaving starts again.
@export var plant_time: float = 3.5
## Seconds from the bomb armed to it going off (the attackers win).
@export var fuse_time: float = 30.0
## A defender in play holding Use within this distance of the armed bomb (m, flat) disarms it ...
@export var defuse_reach: float = 1.6
## ... in this many seconds.
@export var defuse_time: float = 6.0
## Letting go past this share of the defuse keeps it (the lid is off): the next hold starts from here, not from nothing.
## 0: every let-go starts again.
@export var defuse_checkpoint: float = 0.5
## The clock running out while the carrier is arming the bomb goes on until the plant ends, for at most this long (s).
@export var max_overtime: float = 5.0
## The armed bomb beeps (a PLANT event, Plant.Cue.BEEP) every `beep_slow` s with its whole fuse left, quickening to every
## `beep_fast` s as it runs out.
@export var beep_slow: float = 1.0
@export var beep_fast: float = 0.12
## Arming and disarming take both hands (PB3, the owner's ask): the replica is put away while they do and drawn again
## after, at this times its own draw time.
@export var redraw_scale: float = 1.0
## Keyed in, it is set down this far (m) ahead of its carrier's feet, in sight below the view (PB3); nearer with a wall
## or anything ahead of them, its middle at least set_clear (m: half its length and a hair) short of it (a ray at
## set_ray_height over their feet).
@export var set_ahead: float = 0.55
@export var set_clear: float = 0.16
@export var set_ray_height: float = 0.06
## A skipped round simulated (Round.simulate): an armed bomb multiplies the attackers' chance by one plus this.
@export var simulate_planted_lead: float = 1.5

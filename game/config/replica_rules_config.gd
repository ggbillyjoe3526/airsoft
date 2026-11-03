class_name ReplicaRulesConfig
extends Resource
## How every replica handles beyond its own stats (the browser game's config/replicas.ts RECOIL, TRIGGER, BB_WEIGHT,
## HOP_UP): kick and its recovery, the trigger, BB weight and the hop-up dial's range. Read by game/sim/armament.gd.

## Recoil kick recovers with this time constant (s) and never builds past recoil_max_deg.
@export var recoil_recovery_time: float = 0.12
@export var recoil_max_deg: float = 2.0
## A shot's pitch, kick and spread included, stays within this of straight up or down (degrees).
@export var max_shot_pitch_deg: float = 89.9
## A semi trigger press while the replica isn't ready still fires if it gets ready within this (s).
@export var press_buffer: float = 0.15
## A bolt-action replica's press this close to the end of its cycle (s) is kept until the cycle ends (BP3): the Fire
## clip shows the handle home 0.71 s into the cycle, and the M150's runs 1.39 s, so a click after the handle looks home
## always fires. Earlier clicks lapse as any press does, so a double click never fires twice.
@export var bolt_press_window: float = 0.7
## BBs a burst-mode pull fires, unless the magazine runs dry first.
@export var burst_shots: int = 3
## Muzzle energy scales with (BB weight / factory weight) to this power (a heavier BB takes more of the push).
@export var bb_energy_exponent: float = 0.15
## The hop-up dial's range (share of a replica's hop_up_max).
@export var hop_up_min_dial: float = 0.0
@export var hop_up_max_dial: float = 1.0
## Drawing from the holster takes this many times the replica's draw time (the browser game's HOLSTER.drawScale: the
## rifle's 0.45 s draw becomes 0.81 s), so a holstered player is slower to the first shot than one running ready.
@export var holster_draw_scale: float = 1.8
## One notch of the dial turned in play (share of hop_up_max); never zero, the dial snaps to it.
@export_range(0.01, 0.5, 0.01) var hop_up_dial_step: float = 0.05
## A variable optic's zoom step (×) per notch of the mouse wheel while aimed through it (SN2, owner default: 1×).
@export_range(0.25, 2.0, 0.25) var zoom_step: float = 1.0
## The BB weights a player can load (g) and the Loadout's step (the browser game's BB_WEIGHT): 0.20 to 0.30 g.
@export var bb_weight_min: float = 0.2
@export var bb_weight_max: float = 0.3
@export_range(0.001, 0.05, 0.001) var bb_weight_step: float = 0.01

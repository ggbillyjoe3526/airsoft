class_name ReplicaConfig
extends Resource
## One replica's stats (the browser game's config/replicas.ts ReplicaConfig). Every replica behaviour is data: the
## built-in values are in game/config/replicas/<id>.tres, and data/stats.md's row for the replica's key wins over them
## (ReplicaStats). Replicas differ in loading, cycling, handling and how they run out, never in damage.

enum FireMode { SEMI, BURST, AUTO }

## Where the built-in replicas are (ReplicaStats.REPLICA_DIR).
const REPLICA_DIR := "res://game/config/replicas/"

## stats.md's Key, and the generic, non-brand name the HUD shows.
@export var id: StringName = &""
@export var display_name: String = ""
## What drives it: "electric" (a battery and motor, an AEG), "gas" or "spring" (a bolt-action rifle).
@export var power: StringName = &"electric"
## The sounds it makes (assets/audio/cues/shot_<sound>_*.wav and the rest), when they aren't its power's own (the Cyber
## Pistol's, which has no power part apart); "" for its power's.
@export var sound: StringName = &""
## The modes its fire selector offers, in the order the selector key steps through them, and the one it starts in.
@export var fire_modes: Array[FireMode] = [FireMode.SEMI]
@export var default_fire_mode: FireMode = FireMode.SEMI
## BBs a second with the trigger held (auto, and within a burst), or the fastest you can click (semi).
@export var fire_rate: float = 1.0
## BBs a magazine holds, and magazines carried per round (the loaded one included).
@export var mag_size: int = 1
@export var mags: int = 1
## Seconds to swap magazines, and to bring it up after a switch.
@export var reload_time: float = 1.0
@export var draw_time: float = 0.3
## Muzzle energy (J) with its factory BB weight, as a site's chrono rates it, and its site class (the energy limit).
@export var muzzle_energy: float = 1.0
@export var site_class: StringName = &"rifle"
## Factory BB weight (g): the weight bots always shoot and the player starts with.
@export var bb_weight: float = 0.25
## Hop-up lift with the dial turned right up, and where the dial is set out of the box (0..1 of hop_up_max).
@export var hop_up_max: float = 0.3
@export var hop_up_dial: float = 0.5
## Random spread, the standard deviation of the shot direction (degrees), and the upward view kick per shot (degrees).
@export var spread_deg: float = 0.5
@export var recoil_deg: float = 0.2
## How much wider the spread is with the sight down than raised (Accuracy; 1: as wide as stance and movement make it).
## A long rifle pointed from the hip goes nowhere near where a raised sight would put it (the Sniper Rifle, SN1).
@export var hip_spread: float = 1.0
## Each shot is followed by a bolt worked by hand (the Sniper Rifle): its cycle is heard and drawn after every shot, and
## its fire rate is how fast the bolt is worked.
@export var bolt_action: bool = false
## The pace it is carried at, as a share of the run and the sprint (Movement.target_speed; a compact replica is lighter
## on your feet, the Compact SMG, CS1). Holstered, the holster's pace stands instead.
@export var pace: float = 1.0
## The share of the spread that moving, jumping and sprinting add that it takes (Accuracy; 1: all of it). A compact
## replica swings less on the move (the Compact SMG, CS1).
@export var move_spread: float = 1.0
## The replica whose model, parts, first-person hold and view it is drawn with, until it has a model of its own
## (the Compact SMG wears the AEG Rifle's until the owner's reference pictures, CS1); "" for its own (`id`).
@export var model: StringName = &""

## What its parts make of it, as carried (LoadoutRules.carried; as it comes, these change nothing). The view's zoom when
## aimed (0: the iron sights', ViewConfig.aim_zoom), and the share of the usual time to raise the sight.
@export var aim_zoom: float = 0.0
@export var raise_scale: float = 1.0
## The aim_zoom is only inside the optic's glass (a scope): the view round it zooms as the iron sights'.
@export var zoom_in_glass: bool = false
## A variable optic's top zoom (SN2): aimed, the mouse wheel turns the zoom from aim_zoom up to this in
## ReplicaRulesConfig.zoom_step steps (Armament.zooms). At or below aim_zoom: a fixed zoom.
@export var aim_zoom_to: float = 0.0
## How long a sprint's or landing's shake stays in the aim, as a share.
@export var shake_scale: float = 1.0
## Its magazines rattle as you move: bots close by hear you even walking.
@export var rattles: bool = false
## How far its shots are heard, as a share, and whether they sound muffled (a silencer).
@export var heard_scale: float = 1.0
@export var muffled: bool = false


## The sound profile its shots, dry clicks and magazines play: its own, else its power's.
func sound_profile() -> StringName:
	return sound if sound != &"" else power


## The Key of the replica it is drawn as: its stand-in `model`, else its own `id`.
func model_id() -> StringName:
	return model if model != &"" else id


## The Key of the replica the built-in replica `key` is drawn as (model_id); `key` itself with no built-in config.
static func model_of(key: StringName) -> StringName:
	var path := "%s%s.tres" % [REPLICA_DIR, key]
	var r := load(path) as ReplicaConfig if ResourceLoader.exists(path) else null
	return r.model_id() if r != null else key

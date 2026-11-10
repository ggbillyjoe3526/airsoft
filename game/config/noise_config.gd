class_name NoiseConfig
extends Resource
## Noisy props and loud ground (the browser game's config/noise.ts, NP1): what gives you away besides your shots and
## steps. Run into a skip and it booms, a rack of stock rattles, a crate knocks; a BB landing hard on steel rings it;
## steps on gravel and steel plate carry further. Bots hear a knock as a step and a ring as a faint noise (BotHearing),
## you hear it from where it happened (SimAudio). Walking, crouching or brushing along a prop stays quiet, and nothing
## here is random. Units: metres, seconds.

## What a prop sounds like run into: its cue is `prop_<name>` (SOUND_NAMES) in assets/audio/cues/.
enum Sound { STEEL, CLANK, RATTLE, GLASS, PLASTIC, WOOD }
const SOUND_NAMES: PackedStringArray = ["steel", "clank", "rattle", "glass", "plastic", "wood"]

## Running into a prop at this speed or more (m/s, the wanted move's speed into the face that stopped it) knocks it: a
## run (4.2) or a sprint straight in does; a walk (2.3), a crouch (2.1) or a run glancing along it (under about 45°)
## doesn't, nor a push held against it (the speed into it rebuilds 0.75 m/s a tick).
@export var knock_speed: float = 3.0
## The move must lose at least this much (m) against the prop: a real knock, not a graze.
@export var knock_blocked_min: float = 0.002
## The prop's face within this (m) of the body's side: the movers keep a small skin.
@export var knock_touch: float = 0.08
## The way the move was stopped points at the prop within this (the cosine of the largest angle between them), so the
## crate beside you isn't what the wall in front of you stopped.
@export var knock_facing: float = 0.5
## A prop's top this far (m) or less above the feet is underfoot (standing on a crate), not run into.
@export var underfoot: float = 0.05
## Where on the prop a knock comes from: this high (m) above the feet, held within the prop's height.
@export var noise_height: float = 0.9
## A prop makes a noise at most once in this long (s), whoever sets it off, by knock or ring: it can't be drummed on.
@export var quiet: float = 1.2
## A BB rings a prop only when it lands this fast (m/s) or faster: a spent BB dropping onto a skip only ticks.
@export var ring_min_speed: float = 15.0
## A BB stopped this close (m) to a prop's faces landed on it.
@export var ring_margin: float = 0.06

## The noisy props by block kind (Sound); a kind not listed is silent: walls, barriers, gabions, sandbags, plywood,
## floors, ramps, logs, trees, planters.
@export var props: Dictionary[StringName, int] = {
	# Steel boxes: a skip, a shipping container, the van. A body into one booms; a BB pings off it.
	&"skip": Sound.STEEL,
	&"container": Sound.STEEL,
	&"van": Sound.STEEL,
	# Smaller steel: a generator, an IBC's cage.
	&"generator": Sound.CLANK,
	&"ibc": Sound.CLANK,
	# A hall's steel oil drums (DR1).
	&"drum": Sound.CLANK,
	# Loose things on and in them: a rack's stock, a stall's pans, the cans in a vending machine.
	&"rack": Sound.RATTLE,
	&"stall": Sound.RATTLE,
	&"vending": Sound.RATTLE,
	# A phone booth's panes in their frame.
	&"booth": Sound.GLASS,
	# Hollow plastic: a site toilet, an arcade cabinet.
	&"toilet": Sound.PLASTIC,
	&"cabinet": Sound.PLASTIC,
	# A hall's plastic barrels (DR1).
	&"barrel": Sound.PLASTIC,
	# Timber: crates, pallet loads, Woodland's board fence.
	&"crate": Sound.WOOD,
	&"wrapped": Sound.WOOD,
	&"fence": Sound.WOOD,
}
## How far (m) the other team's bots hear a knock, by Sound, walls muffling it as any sound: a run's own steps carry
## 11 m and a vault 18 m, so every noisy prop carries further than the run that hit it.
@export var knock_reach: PackedFloat32Array = PackedFloat32Array([20.0, 17.0, 16.0, 15.0, 14.0, 13.0])
## How far (m) a ring carries, by Sound (0: the prop doesn't ring, a BB on it only ticks). Only a bot with no fresher
## news of anyone turns to check it.
@export var ring_reach: PackedFloat32Array = PackedFloat32Array([12.0, 10.0, 0.0, 0.0, 0.0, 0.0])
## How far run, sprint and landing steps carry on each ground (RayHit.Surface; ×, a ground not listed 1): loose gravel
## and steel plate are loud. Bots hear them this many times as far; you hear them this much louder and further.
@export var ground: Dictionary[int, float] = {
	RayHit.Surface.METAL: 1.35,
	RayHit.Surface.GRAVEL: 1.35,
	RayHit.Surface.GLASS: 1.35,
	# A splash wading a stream (WS1, owner: the bridge is the quiet crossing).
	RayHit.Surface.WATER: 1.5,
}


## Run, sprint and landing steps pushing through a bush (Character.in_bush, BP8) carry this many times as far, and
## sound as leaves: bots hear them further, you hear them louder and further.
@export var bush_carry: float = 1.75
## A walk's or a crouch's stride wading a stream (WS1) splashes as a run step carrying this many times as far: never
## silent, a little quieter than a run's splash (the water's `ground` carry).
@export var wade_quiet_carry: float = 0.9


## How far a step on `surface` carries (×).
func carry(surface: int) -> float:
	return ground.get(surface, 1.0)


## How far a knock on a prop that sounds as `sound` carries (m; 0 for a sound not in the table).
func knock_reach_of(sound: int) -> float:
	return knock_reach[sound] if sound >= 0 and sound < knock_reach.size() else 0.0


## How far a ring off a prop that sounds as `sound` carries (m; 0: it doesn't ring).
func ring_reach_of(sound: int) -> float:
	return ring_reach[sound] if sound >= 0 and sound < ring_reach.size() else 0.0

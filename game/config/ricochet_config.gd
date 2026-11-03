class_name RicochetConfig
extends Resource
## BBs bounce off hard surfaces (the browser game's config/ballistics.ts ricochet, M20 and G12) instead of stopping
## dead: the part of the velocity into the surface comes back smaller, the part along it is slowed by friction, and the
## hop-up's backspin is lost. Whether a bounced BB knocks anyone out is the match's rule (HitConfig.ricochets_count).
## Read by game/sim/ricochet.gd.

## Share of the speed into the surface that comes back out, by material (0: the BB stops there). Concrete gives back
## under a third, steel containers more; crates and the ground soak a BB up (owner's G12 ruling: three quarters of
## M20's 0.4 and 0.55, so fewer bounced BBs knock players out). Gravel, grass and leaves take `earth`'s.
@export var concrete: float = 0.3
@export var metal: float = 0.41
@export var wood: float = 0.0
@export var earth: float = 0.0
## Share of the speed along the surface that is kept.
@export var slide: float = 0.75
## A BB leaving a bounce slower than this (m/s) drops dead instead.
@export var min_speed: float = 12.0
## The most times one BB bounces; it stops at the next surface after that.
@export var max_bounces: int = 2
## Random spread of the bounced direction, as a share of its speed (a rough wall doesn't bounce like a mirror).
@export var scatter: float = 0.12
## Share of the backspin left after a bounce.
@export var spin_kept: float = 0.0
## How far off the surface (m) a bounced BB restarts, so its next ray doesn't start inside it.
@export var lift_off: float = 0.002


## The restitution of `surface` (0 for none).
func restitution(surface: RayHit.Surface) -> float:
	match surface:
		RayHit.Surface.CONCRETE:
			return concrete
		RayHit.Surface.METAL, RayHit.Surface.GLASS:
			return metal
		RayHit.Surface.WOOD, RayHit.Surface.PLASTIC, RayHit.Surface.CARDBOARD:
			return wood
		RayHit.Surface.EARTH, RayHit.Surface.GRAVEL, RayHit.Surface.GRASS, RayHit.Surface.LEAVES:
			return earth
	return 0.0

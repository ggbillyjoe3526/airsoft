class_name GrenadeConfig
extends Resource
## Smoke and flash bombs (SF1): what everyone carries, a throw, a bomb's flight, a smoke's cloud and a flash's dazzle.
## The simulation keeps them (Grenades); how bots use them is BotConfig's. The same for every character at every
## difficulty. Part of SimTuning (sim_tuning.tres).

## The bombs a loadout carries each round (BP8, owner: pick which): this many slots, each a smoke or a flash, the same
## kind twice if you like (refilled at each respawn, and on the range after every throw).
@export var slots: int = 2
## The pick before one is made (a new loadout, a save from before picking, a bot kit with none listed): this many smokes,
## then this many flashes, cut to `slots`.
@export var smoke_carried: int = 1
@export var flash_carried: int = 1
## Most bombs in the air or smoking at once (GameState.grenades, made once with the state): a throw with none free is
## refused. Room for every bomb of two full teams of eight (CustomRules.TEAM_SIZES).
@export var max_grenades: int = 32

@export_group("Throw")
## From the press the replica goes down and the pin comes out for this long (s), then the bomb leaves the hand; the
## replica is drawn again, at redraw_scale of its draw time, recover s after the release.
@export var windup: float = 0.3
@export var recover: float = 0.15
@export var redraw_scale: float = 0.6
## A bomb in hand thrown by a trigger pull that is still held waits at this share of the windup (the pin out, the arm
## cocked: your arms' ViewModelConfig.bomb_cock) until the trigger is let go, then goes on; let go sooner, it never
## waits (BP8, the owner: a click throws, or hold the button and the bomb leaves on its release).
@export var hold_at: float = 0.72
## The bomb leaves the hand this fast (m/s) along the view lifted by loft (rad), plus this share of the thrower's own
## velocity.
@export var throw_speed: float = 13.0
@export var loft: float = 0.12
@export var carry_share: float = 0.5
## Where the throwing hand lets the bomb go (m: right, up and ahead of the eyes on the level, whatever the pitch; your
## arms' wrist at the release, ViewModelConfig.bomb_release). Something between the eyes and there (a wall the thrower
## stands against) and it leaves from just short of it (Grenades.release_from).
@export var release_offset: Vector3 = Vector3(0.18, 0.02, 0.32)

@export_group("Flight")
@export var gravity: float = 9.81
## Bouncing: what is kept of the speed into a surface (restitution) and along it (friction) at an impact faster than
## bounce_speed (m/s into the surface); slower, it slides and rolls, losing roll_drag of its speed a second, and settles
## once slower than rest_speed on ground no steeper than rest_slope (the normal's up share).
@export var restitution: float = 0.35
@export var friction: float = 0.55
@export var bounce_speed: float = 1.5
@export var roll_drag: float = 4.0
@export var rest_speed: float = 0.3
@export var rest_slope: float = 0.7
## Sits this far off a surface it lands on (m: the bomb's half size).
@export var radius: float = 0.04
## A bomb still going after this long (s) is gone: lost off the field.
@export var max_flight: float = 20.0
## For this long after the throw (s) a bomb passes through the thrower's team (BP6): one thrown from cover past a
## teammate at the thrower's side never bounces back off them onto the thrower. Bodies of the other team stop it at once.
@export var team_pass_time: float = 0.3

@export_group("Smoke")
## Pops this long after it leaves the hand (s), then smokes for smoke_time: the cloud grows to its full size over
## smoke_grow, holds, and thins away over the last smoke_fade.
@export var smoke_fuse: float = 1.2
@export var smoke_time: float = 18.0
@export var smoke_grow: float = 2.5
@export var smoke_fade: float = 3.0
## The full cloud: an upright ellipsoid this wide (m, radius across) and tall (m, radius up), its middle this high over
## the canister (m).
@export var smoke_radius: float = 4.0
@export var smoke_height: float = 2.2
@export var smoke_lift: float = 1.2

@export_group("Flash")
## Goes bang this long after it leaves the hand (s).
@export var flash_fuse: float = 1.5
## Anyone in play with a clear line from its eyes to the bang is dazzled: fully within flash_full m, not at all beyond
## flash_reach m, by distance in between; fully looking within flash_cone_deg of it, behind_share looking away, by the
## view's angle in between: looking straight away, nothing (SF2: turning away is the counter). A full dazzle lasts
## dazzle_max s; anything weaker at least dazzle_min, and one under dazzle_least of full not at all.
@export var flash_full: float = 6.0
@export var flash_reach: float = 22.0
@export var flash_cone_deg: float = 60.0
@export var behind_share: float = 0.0
@export var dazzle_max: float = 3.5
@export var dazzle_min: float = 0.5
@export var dazzle_least: float = 0.1


## The pick before one is made: smoke_carried smokes, then flash_carried flashes, cut to `slots`.
func default_picks() -> Array[Grenade.Kind]:
	var out: Array[Grenade.Kind] = []
	for i in maxi(0, smoke_carried):
		out.append(Grenade.Kind.SMOKE)
	for i in maxi(0, flash_carried):
		out.append(Grenade.Kind.FLASH)
	out.resize(mini(out.size(), maxi(0, slots)))
	return out


## `picks` as carried: each slot a smoke or a flash, `slots` of them; a pick of the wrong size, or with anything but a
## smoke or a flash in it, is the default pick.
func carried_picks(picks: Array[Grenade.Kind]) -> Array[Grenade.Kind]:
	if picks.size() != slots:
		return default_picks()
	for k in picks:
		if k != Grenade.Kind.SMOKE and k != Grenade.Kind.FLASH:
			return default_picks()
	return picks.duplicate()

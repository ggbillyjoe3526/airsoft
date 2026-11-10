class_name VaultState
extends RefCounted
## A character's vault (the browser game's sim/vault.ts VaultState, M102): planned by Vault.find, followed by
## Vault.step while `active`. Plain data; one per character, plus whatever scratch a caller asks Vault.find into.

## Vaulting now: the body follows the path below, not its command.
var active: bool = false
## The move is a climb up onto a ledge whose top runs on (CL1): it ends standing on the top, not falling past it.
var climb: bool = false
## Seconds since the vault began.
var time: float = 0.0
## Where it began (the feet), and the way it goes (a unit vector on the ground plane, x and z).
var start: Vector3 = Vector3.ZERO
var dir: Vector2 = Vector2(0.0, -1.0)
## Along the way from the start (m): where the body meets the obstacle's face, and where it is clear of the far side
## (a climb's: where it stands on the top, the whole body past the edge).
var front: float = 0.0
var far: float = 0.0
## The obstacle's top (world height), and the feet's height crossing it (the top plus the clearance).
var top_y: float = 0.0
var over_y: float = 0.0
## Speed across the top and out of the vault (m/s).
var speed: float = 0.0
## Seconds from the start: the rise onto the top ends, and the vault hands over to the fall.
var rise_end: float = 0.0
var end: float = 0.0
## The one-shot presses made while vaulting (BP5), played into the first command after it (Vault.with_held_presses):
## nothing starts mid-vault, and nothing pressed is lost. `held_switch_to` -1 is none; `held_fire_modes` counts presses;
## `held_hop_up_steps` adds up the dial's notches, `held_zoom_steps` a variable optic's (SN2); `held_ready_grenade` is
## a bomb the mouse wheel took in hand (NONE: none), the last of it and `held_switch_to` winning (BP2).
var held_any: bool = false
var held_reload: bool = false
var held_switch_to: int = -1
var held_fire_modes: int = 0
var held_holster: bool = false
var held_hop_up_steps: int = 0
var held_zoom_steps: int = 0
var held_ready_grenade: Grenade.Kind = Grenade.Kind.NONE


## Where in the Vault clip (0..1) this vault is: its first `top` over the rise onto the top, the rest across it to the
## hand-over to the fall, so the hop keeps to the body's path whatever the obstacle (the browser's vaultClipShare). The
## drawn figure (FigurePose) and the hit volume (Hitbox) both read it.
func clip_share(top: float) -> float:
	if time < rise_end:
		return clampf(top * time / rise_end, 0.0, 1.0) if rise_end > 0.0 else top
	var span := end - rise_end
	return clampf(top + (1.0 - top) * (time - rise_end) / span, 0.0, 1.0) if span > 0.0 else 1.0


## Ends a vault at once and drops what was kept through it (a respawn, a rescue back into the level).
func cancel() -> void:
	active = false
	time = 0.0
	drop_held()


## Forgets the presses kept through a vault.
func drop_held() -> void:
	held_any = false
	held_reload = false
	held_switch_to = -1
	held_fire_modes = 0
	held_holster = false
	held_hop_up_steps = 0
	held_zoom_steps = 0
	held_ready_grenade = Grenade.Kind.NONE

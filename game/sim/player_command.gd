class_name PlayerCommand
extends RefCounted
## The one input every character acts through (docs/ARCHITECTURE.md › Contracts 2): the player's controller and each
## bot fill one per tick, and nothing else moves a character. View angles are absolute.

## -1..1, forward positive, relative to yaw.
var forward: float = 0.0
## -1..1, right positive, relative to yaw.
var right: float = 0.0
## Absolute view yaw (rad): 0 looks down -Z, positive turns left (counter-clockwise seen from above).
var yaw: float = 0.0
## Absolute view pitch (rad), positive looks up.
var pitch: float = 0.0
var sprint: bool = false
## Walk held: slow and quiet. Wins over sprint.
var walk: bool = false
var crouch: bool = false
var jump: bool = false
## Aim down sights (held).
var aim: bool = false
## Trigger held. Semi fires on the press only.
var fire: bool = false
var reload: bool = false
## The controller's reload setting, not a press: on, an empty magazine stays in until a reload is asked (the player's
## Settings › Controls › Reload: Manual, RL2), and the trigger only clicks dry; off (bots, the pilots), the dry click
## also starts a reload when a spare has BBs.
var manual_reload: bool = false
## Loadout slot to switch to, or -1 for none.
var switch_to: int = -1
## Step the selector of the replica in hand to its next mode (one-shot).
var cycle_fire_mode: bool = false
## Lean held: -1 full left .. 1 full right, 0 upright (Lean).
var lean: float = 0.0
## Notches to turn the hop-up dial of the replica in hand this tick (one-shot): positive for more lift. Bots leave it 0.
var hop_up_steps: int = 0
## Put the replica in hand away (one-shot; the holster): nothing to fire or aim, a faster run that never passes the
## sprint. A slot, a fresh trigger pull, an aim press or a reload draws it again, slower than a switch.
var holster: bool = false
## A squad order to this character's bot teammates (one-shot; SquadOrder), and whether it was picked on the order wheel
## (picked again there, the order in force stays; its key again cancels it).
var squad_order: SquadOrder.Kind = SquadOrder.Kind.NONE
var order_from_wheel: bool = false
## Switch the weapon torch on the replica in hand on or off (one-shot; Torch). Nothing without a light in hand.
var toggle_torch: bool = false
## Ping where the view looks, for this character's bot teammates (one-shot; PN1): the simulation turns it into a PING
## event and the bots' controller into a ping (Pings).
var ping: bool = false
## The ping is a Go there (FM1): the bot teammates go to its spot and hold it (SquadOrder.Kind.MOVE).
var ping_move: bool = false
## The ping was placed on the full-screen map (FM1) at ping_target (world x and z, the y the floor of the storey shown)
## rather than along the view.
var ping_on_map: bool = false
var ping_target: Vector3 = Vector3.ZERO
## The magazine hand-off (one-shot; MH1): toss a magazine to the nearest teammate asking you who is in reach, else ask
## for one if you are low, else nothing but a refusal (MagShare.press).
var mag_hand_off: bool = false
## Throw a bomb of this kind (one-shot; Grenades, SF1): NONE throws nothing.
var throw_grenade: Grenade.Kind = Grenade.Kind.NONE
## Open or shut a door (one-shot; Doors, DO1): the one in reach nearest the view's line, or `door_to_use` when the
## controller picked one (a bot, the door its walk goes into; -1: none picked).
var use_door: bool = false
var door_to_use: int = -1


## Back to no input, looking along (yaw, pitch).
func reset(view_yaw: float = 0.0, view_pitch: float = 0.0) -> void:
	forward = 0.0
	right = 0.0
	yaw = view_yaw
	pitch = view_pitch
	sprint = false
	walk = false
	crouch = false
	jump = false
	aim = false
	fire = false
	reload = false
	manual_reload = false
	switch_to = -1
	cycle_fire_mode = false
	lean = 0.0
	hop_up_steps = 0
	holster = false
	squad_order = SquadOrder.Kind.NONE
	order_from_wheel = false
	toggle_torch = false
	ping = false
	ping_move = false
	ping_on_map = false
	ping_target = Vector3.ZERO
	mag_hand_off = false
	throw_grenade = Grenade.Kind.NONE
	use_door = false
	door_to_use = -1


func copy_from(other: PlayerCommand) -> void:
	forward = other.forward
	right = other.right
	yaw = other.yaw
	pitch = other.pitch
	sprint = other.sprint
	walk = other.walk
	crouch = other.crouch
	jump = other.jump
	aim = other.aim
	fire = other.fire
	reload = other.reload
	manual_reload = other.manual_reload
	switch_to = other.switch_to
	cycle_fire_mode = other.cycle_fire_mode
	lean = other.lean
	hop_up_steps = other.hop_up_steps
	holster = other.holster
	squad_order = other.squad_order
	order_from_wheel = other.order_from_wheel
	toggle_torch = other.toggle_torch
	ping = other.ping
	ping_move = other.ping_move
	ping_on_map = other.ping_on_map
	ping_target = other.ping_target
	mag_hand_off = other.mag_hand_off
	throw_grenade = other.throw_grenade
	use_door = other.use_door
	door_to_use = other.door_to_use

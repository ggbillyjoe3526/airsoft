class_name Character
extends RefCounted
## One character's state as plain data (the browser game's sim/character.ts): the player and every bot alike. Scene
## nodes read it to draw the figure; only the simulation's steps write it.

## Where a character is in the hit-calling cycle: playing; standing with a hand up calling the hit; walking off to the
## dead zone; leaving the field (a walk-off that couldn't finish fades out where it is); out, waiting for the next round.
enum Status { ALIVE, CALLING, WALKING_OFF, LEAVING, OUT }

var id: int = 0
## 0 Alpha (blue), 1 Beta (orange).
var team: int = 0
## The end of the map (0 or 1) it starts from this round; ends swap at half time. Starts as the team.
var end: int = 0
var status: Status = Status.ALIVE
## Seconds since status last changed.
var status_time: float = 0.0
## Who hit it this round (-1: nobody).
var hit_by: int = -1
## The dead-zone spot it walks to once hit, the way that spot faces, and the route there (waypoints).
var dead_zone_target: Vector3 = Vector3.ZERO
var dead_zone_yaw: float = 0.0
var walk_off_route: PackedVector3Array = PackedVector3Array()
var walk_off_leg: int = 0
## The route is still to be planned (one plan a tick at most).
var walk_off_route_pending: bool = false
## Seconds it has made no real progress walking off.
var walk_off_stuck: float = 0.0

## Feet: the bottom of the collision capsule.
var position: Vector3 = Vector3.ZERO
## Position at the start of the last tick, for drawing between ticks.
var prev_position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
## Where it starts the round, and returns to if it ever leaves the world.
var spawn_position: Vector3 = Vector3.ZERO
var spawn_yaw: float = 0.0
var yaw: float = 0.0
var pitch: float = 0.0
var prev_yaw: float = 0.0
var prev_pitch: float = 0.0
## 0 standing, 1 fully crouched; last tick's for drawing the eye height between ticks.
var crouch_amount: float = 0.0
var prev_crouch_amount: float = 0.0
## Its collision body is crouched (BodyConfig.crouch_height tall, Movement.step): crouched past the threshold, and kept
## crouched while there is no room to stand.
var low: bool = false
## The walk cycle's phase (rad): grows with the ground covered, so the legs' hit volumes and the drawn legs swing
## together (Hitbox). Last tick's for drawing.
var walk_cycle: float = 0.0
var prev_walk_cycle: float = 0.0
var grounded: bool = false
var jump_cooldown: float = 0.0
## Seconds a jump press is still kept for (MovementConfig.jump_buffer).
var jump_wanted: float = 0.0
## Slope climbed on the last tick on the ground (rise per metre), for ramp pace.
var ground_rise: float = 0.0
var sprinting: bool = false
## Walking slowly and quietly (walk held or aiming, not crouched).
var walking: bool = false
## This tick's move as Movement wanted it and as the level let it happen (CharacterMover), for a run into a noisy prop
## (PropNoise); a vault leaves them as they were.
var wanted_move: Vector3 = Vector3.ZERO
var made_move: Vector3 = Vector3.ZERO
## Ground covered since the last footstep (m).
var step_distance: float = 0.0
## In the air since the last tick on the ground, and the fastest it fell meanwhile (m/s), for the landing's sound.
var airborne: bool = false
var fall_speed: float = 0.0
## How much stance and movement scale the replica's spread right now (1: standing still; Accuracy).
var spread_scale: float = 1.0
## Seconds off the ground (a jump starts it at the in-air spread delay), and standing still on it.
var air_time: float = 0.0
var still_time: float = 0.0
## Seconds left in which a sprint's or a landing's shake still settles slowly.
var shake_carry: float = 0.0
## Aiming down the sights of the replica in hand, and how far the sight is raised to the eye (0..1).
var aiming: bool = false
var aim_raise: float = 0.0
## How far it leans: -1 fully left, 1 fully right, 0 upright (Lean); last tick's for drawing between ticks.
var lean: float = 0.0
var prev_lean: float = 0.0
## A vault over a low obstacle (Vault): while `vault.active` the body follows its path, not its command.
var vault: VaultState = VaultState.new()
## Seconds until the replica can fire again after a vault (0: ready): carried through it, up a moment after.
var fire_lockout: float = 0.0
var armament: Armament = null
## The weapon torch switched on (Torch: lit only on a replica in hand that has one, in play), and the seconds since it
## was last switched (a bot holds a state BotConfig.torch_min_hold at least).
var torch_on: bool = false
var torch_time: float = 0.0
## BBs pass straight through: the Dev settings' Ghost, the player's only, kept between rounds (DevCheats).
var ghost: bool = false
## Its side of the magazine hand-off (MagShare): its ask and what is coming to it, cleared at each respawn.
var mag: MagShare.Hand = MagShare.Hand.new()
## Its smoke and flash bombs and its throw under way (Grenades, SF1), refilled at each respawn.
var grenades: Grenades.Hand = Grenades.Hand.new()
## Dazzled by a flash (Grenades): seconds left, and how long the dazzle was when it began (for its fade).
var dazzle_left: float = 0.0
var dazzle_total: float = 0.0


func _init(character_id: int = 0, character_team: int = 0, spawn: Vector3 = Vector3.ZERO, facing: float = 0.0,
		loadout: Array[ReplicaConfig] = [], bb_weights: PackedFloat64Array = PackedFloat64Array()) -> void:
	id = character_id
	team = character_team
	end = character_team
	spawn_position = spawn
	spawn_yaw = facing
	armament = Armament.create(loadout, bb_weights)
	respawn()


## Eye height above the feet for `crouch` (0 standing, 1 crouched).
static func eye_height(crouch: float, body: BodyConfig) -> float:
	return body.stand_eye_height + (body.crouch_eye_height - body.stand_eye_height) * crouch


## Its collision body's height now (m): BodyConfig.crouch_height while low, else height.
func body_height(body: BodyConfig) -> float:
	return body.crouch_height if low else body.height


## The eyes standing upright (no lean); BBs leave from Lean.eye.
func eye(body: BodyConfig) -> Vector3:
	return position + Vector3(0.0, eye_height(crouch_amount, body), 0.0)


## The way it looks (unit): yaw 0 down -Z, positive yaw turning left, positive pitch up.
func view_direction() -> Vector3:
	var cp := cos(pitch)
	return Vector3(-sin(yaw) * cp, sin(pitch), -cos(yaw) * cp)


## Safety net: below `kill_y` it has escaped the level and is put back with no momentum, at its spawn while in play
## and on its dead-zone spot once hit. True if rescued.
func rescue_if_out_of_world(kill_y: float) -> bool:
	if position.y >= kill_y:
		return false
	position = spawn_position if status == Status.ALIVE else dead_zone_target
	prev_position = position
	prev_crouch_amount = crouch_amount
	prev_lean = lean
	vault.cancel()
	velocity = Vector3.ZERO
	grounded = false
	airborne = false
	fall_speed = 0.0
	air_time = 0.0
	return true


## Back at its spawn for a new round: in play, standing, full magazines, the torch off; fire selectors and hop-up dials
## kept.
func respawn() -> void:
	position = spawn_position
	prev_position = spawn_position
	velocity = Vector3.ZERO
	yaw = spawn_yaw
	pitch = 0.0
	prev_yaw = yaw
	prev_pitch = 0.0
	crouch_amount = 0.0
	prev_crouch_amount = 0.0
	low = false
	walk_cycle = 0.0
	prev_walk_cycle = 0.0
	grounded = false
	jump_cooldown = 0.0
	jump_wanted = 0.0
	ground_rise = 0.0
	sprinting = false
	walking = false
	step_distance = 0.0
	airborne = false
	fall_speed = 0.0
	spread_scale = 1.0
	air_time = 0.0
	still_time = 0.0
	shake_carry = 0.0
	aiming = false
	aim_raise = 0.0
	lean = 0.0
	prev_lean = 0.0
	vault.cancel()
	fire_lockout = 0.0
	status = Status.ALIVE
	status_time = 0.0
	hit_by = -1
	walk_off_stuck = 0.0
	walk_off_route_pending = false
	walk_off_route.clear()
	walk_off_leg = 0
	torch_on = false
	torch_time = 0.0
	mag.clear()
	armament.refill()
	grenades.refill()
	dazzle_left = 0.0
	dazzle_total = 0.0

class_name FigurePose
extends RefCounted
## What a figure's legs do (step 23, FI2; the browser game's sim/figureLegs.ts rules): `read` turns a Character between
## its last two ticks into the lower body's targets, and `settle` moves the blends towards them at the browser's settle
## times (an exponential step: about two thirds of the way in each settle time). The upper body (FI3) from its
## armament: the pitch, the rifle's or the pistol's hold, the holster and the draw out of it, a switch between replicas
## and which replica is in the hand, slung or hanging from it, and a reload's share (FI4). Pure: no node, nothing
## allocated per call; one per figure, reused every frame. FigureBody plays it.

## The step in the figure's own frame (m/s; x to its right, y ahead): zero below the walking speed (still).
var gait: Vector2 = Vector2.ZERO
## Crouched (0..1), the walk cycle (rad, never wrapped) and the lean (-1..1), between the ticks.
var crouch: float = 0.0
var cycle: float = 0.0
var lean: float = 0.0
## A crouched step going backwards: the crouched walk plays in reverse.
var backward: bool = false
## Each layer's target (0 or 1) and where in its clip it is: in the air (Jump, s), vaulting (Vault, share 0..1),
## calling the hit (HitCall, s), walking off (WalkOff, its pace scaled to walk_off_speed).
var jump: float = 0.0
var jump_time: float = 0.0
var vault: float = 0.0
var vault_share: float = 0.0
var call: float = 0.0
var call_time: float = 0.0
var walk_off: float = 0.0
var walk_off_speed: float = 0.0
## The blends as eased: the step's speed (m/s) and way (unit, the figure's frame), and each layer's weight.
var speed: float = 0.0
var way: Vector2 = Vector2(0.0, 1.0)
var jump_weight: float = 0.0
var vault_weight: float = 0.0
var call_weight: float = 0.0
var walk_off_weight: float = 0.0
## The speed below which the legs stand (HitConfig.walking_speed, as the hit volume's legs).
var still_speed: float = 0.0
## The upper body: the aim's pitch (rad, up positive) between the ticks; sprinting (Holster_Sprint's arms); the pistol's
## hold and the holster as targets (0 or 1; the holster eased out over a draw from it) and as eased; the sprint's arms
## as eased.
var pitch: float = 0.0
var sprinting: float = 0.0
var pistol: float = 0.0
var holster: float = 0.0
var pistol_weight: float = 0.0
var holster_weight: float = 0.0
var sprint_weight: float = 0.0
## Muzzle up at a wall (FB5, 0..1): FigureView's target from its ray, and as eased.
var raise_target: float = 0.0
var raise: float = 0.0
## The replica slots drawn: in the hand (-1 none), slung on the chest (-1 none), and whether the one in the hand hangs
## from it (calling the hit, walking off).
var in_hand: int = -1
var slung: int = -1
var hanging: bool = false
## A switch between replicas under way (the Switch clip: backwards to a rifle), whether it began since the last read
## (the clip is fired once), and how long the draw takes in all (s).
var switching: bool = false
var switch_started: bool = false
var switch_back: bool = false
var draw_seconds: float = 0.0
## A reload under way (FI4) in slot `reload_slot` (-1 none; not while holstered or calling the hit), whether it began
## since the last read (reload_left rose, or none was under way), whether it is a pistol's, and its share (0..1) of the
## replica's reload time, from the simulation's reload_left: a figure hidden or posed only now and then keeps step.
var reloading: bool = false
var reload_started: bool = false
var reload_slot: int = -1
var reload_pistol: bool = false
var reload_share: float = 0.0
## The figure's feet (the ground a thrown magazine lands on: no world query, plan default 15) and its velocity (m/s),
## between the ticks; and whether the blends were snapped since the last read (nothing that happened meanwhile is
## played out, such as a magazine's throw).
var feet: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var snapped: bool = false
## A bomb (GT1, Grenade.Kind; NONE: none) in the right hand: thrown, `throw_share` of the way through its throw (0..1
## the windup to the release, 1..2 the recovery after it; below 0 none), or held in hand waiting for a trigger pull
## (`bomb_held`, MC1). The windup's and the recovery's lengths (s) are `grenades`' (FigureView.set_bombs).
var bomb: int = Grenade.Kind.NONE
var throw_share: float = -1.0
var bomb_held: bool = false
## The throw under way began from a bomb held in hand (the arm already up, so it doesn't drop first).
var throw_from_hand: bool = false
var grenades: GrenadeConfig = null
## The draw under way came out of the holster; the slot in the hand before a switch; the last read's holster and draw.
var _from_holster: bool = false
var _switch_from: int = -1
var _was_holstered: bool = false
var _was_drawing: bool = false
var _drawn_slot: int = -1
var _reload_left: float = 0.0
var _config: FigureConfig = null


func _init(config: FigureConfig) -> void:
	_config = config


## The figures' tuning this reads.
func config() -> FigureConfig:
	return _config


## The targets for `c` at `fraction` of the way from its last tick to this one, by `hits`' rules.
func read(c: Character, fraction: float, hits: HitConfig) -> void:
	snapped = false
	feet = c.prev_position.lerp(c.position, fraction)
	velocity = c.velocity
	var yaw := lerp_angle(c.prev_yaw, c.yaw, fraction)
	var sin_yaw := sin(yaw)
	var cos_yaw := cos(yaw)
	var ahead := -c.velocity.x * sin_yaw - c.velocity.z * cos_yaw
	var right := c.velocity.x * cos_yaw - c.velocity.z * sin_yaw
	var moving := Vector2(c.velocity.x, c.velocity.z).length()
	still_speed = hits.walking_speed
	gait = Vector2(right, ahead) if moving > still_speed else Vector2.ZERO
	crouch = lerpf(c.prev_crouch_amount, c.crouch_amount, fraction)
	cycle = lerpf(c.prev_walk_cycle, c.walk_cycle, fraction)
	lean = lerpf(c.prev_lean, c.lean, fraction)
	backward = crouch > _config.back_crouched and ahead < -_config.back_share * moving
	var alive := c.status == Character.Status.ALIVE
	var vaulting := alive and c.vault.active
	jump = 1.0 if alive and not c.grounded and not vaulting else 0.0
	jump_time = minf(_config.jump_to, _config.jump_from + maxf(c.air_time, 0.0))
	vault = 1.0 if vaulting else 0.0
	vault_share = vault_progress(c.vault, _config.vault_top) if vaulting else 0.0
	call = 1.0 if c.status == Character.Status.CALLING else 0.0
	call_time = c.status_time if call > 0.0 else 0.0
	var off := c.status == Character.Status.WALKING_OFF or c.status == Character.Status.LEAVING
	walk_off = 1.0 if off else 0.0
	walk_off_speed = hits.walk_off_speed
	pitch = lerpf(c.prev_pitch, c.pitch, fraction)
	sprinting = 1.0 if c.sprinting else 0.0
	read_hands(c.armament, call > 0.0 or c.status == Character.Status.WALKING_OFF, alive)
	read_throw(c.grenades, alive)


## The bomb in the right hand from `hand` (none unless `alive`): its throw's share, or held in hand.
func read_throw(hand: Grenades.Hand, alive: bool) -> void:
	var was_held := bomb_held
	bomb = Grenade.Kind.NONE
	throw_share = -1.0
	bomb_held = false
	if hand == null or not alive or grenades == null:
		throw_from_hand = false
		return
	throw_from_hand = hand.throwing != Grenade.Kind.NONE and (was_held or throw_from_hand)
	if hand.throwing != Grenade.Kind.NONE:
		if hand.released:
			throw_share = 1.0 + clampf(1.0 - hand.recover_left / maxf(grenades.recover, 1e-6), 0.0, 1.0)
		else:
			throw_share = clampf(1.0 - hand.windup_left / maxf(grenades.windup, 1e-6), 0.0, 1.0)
			bomb = hand.throwing
	elif hand.readied != Grenade.Kind.NONE:
		bomb = hand.readied
		bomb_held = true


## The upper body's targets from armament `a`: what is in the hand, slung or put away, the draw and a switch under way;
## `called` the hand raised (the replica in the hand hangs from the other); a reload counts only while `alive`.
func read_hands(a: Armament, called: bool, alive: bool = true) -> void:
	switch_started = false
	reload_started = false
	if a == null or a.replicas.is_empty():
		in_hand = -1
		slung = -1
		hanging = false
		switching = false
		holster = 0.0
		reloading = false
		reload_slot = -1
		return
	read_reload(a, called or not alive)
	var drawing := a.draw_left > 0.0 and a.draw_total > 0.0
	if drawing and (not _was_drawing or a.active != _drawn_slot):
		# A new draw: out of the holster, or a switch from the replica that was in the hand.
		_from_holster = _was_holstered
		_switch_from = in_hand
		switching = not _from_holster and _switch_from >= 0 and _switch_from != a.active
		switch_started = switching
		switch_back = switching and not _is_pistol(a, a.active)
	if not drawing:
		_from_holster = false
		switching = false
	_was_drawing = drawing
	_was_holstered = a.holstered
	_drawn_slot = a.active
	draw_seconds = a.draw_total
	var share := 1.0 - a.draw_left / a.draw_total if drawing else 1.0
	var swap := _config.holster_swap
	var put_away := a.holstered or (_from_holster and share < swap)
	holster = 1.0 if a.holstered else 0.0
	if _from_holster and drawing:
		holster = 1.0 if share < swap else clampf((1.0 - share) / maxf(1.0 - swap, 1e-6), 0.0, 1.0)
	pistol = 1.0 if _is_pistol(a, a.active) else 0.0
	in_hand = -1 if put_away else a.active
	if switching and share < switch_share(switch_back):
		in_hand = _switch_from
	slung = _first_rifle(a) if put_away else -1
	hanging = called and in_hand >= 0


## The reload in `a`'s hand: under way while reload_left counts down (a switch or the holster zeroes it, cutting it),
## not while holstered or `stopped` (calling the hit or out: the simulation no longer ticks an out character's
## armament, so its reload_left stays frozen); begun anew when reload_left rose since the last read.
func read_reload(a: Armament, stopped: bool) -> void:
	var total := a.replicas[a.active].reload_time if a.active >= 0 and a.active < a.replicas.size() else 0.0
	var now := a.reload_left > 0.0 and total > 0.0 and not a.holstered and not stopped
	reload_started = now and (not reloading or a.reload_left > _reload_left or a.active != reload_slot)
	reloading = now
	reload_slot = a.active if now else -1
	reload_pistol = now and _is_pistol(a, a.active)
	reload_share = clampf(1.0 - a.reload_left / total, 0.0, 1.0) if now else 0.0
	_reload_left = a.reload_left


## The share of a switch's draw from which the new replica is in the hand: the Switch clip holds the pistol from
## switch_pistol_from on, and played backwards to a rifle, the rifle from 1 - that.
func switch_share(back: bool) -> float:
	return 1.0 - _config.switch_pistol_from if back else _config.switch_pistol_from


## The share of the aim clips' blend (-1 AimDown .. 1 AimUp) for the pitch; at a wall, towards level (the high ready
## turns the level hold, FigureReady).
func aim_blend() -> float:
	var blend := clampf(pitch / _config.aim_pitch, -1.0, 1.0) if _config.aim_pitch > 0.0 else 0.0
	return lerpf(blend, 0.0, raise)


## How far (rad) the spine leans the aim beyond what the clips turn the replica (aim_reach of the blend's pitch); at a
## wall, towards FigureConfig.raise_lean.
func aim_lean() -> float:
	var blend := clampf(pitch / _config.aim_pitch, -1.0, 1.0) if _config.aim_pitch > 0.0 else 0.0
	return lerpf(pitch - _config.aim_reach * _config.aim_pitch * blend, _config.raise_lean, raise)


static func _is_pistol(a: Armament, slot: int) -> bool:
	return slot >= 0 and slot < a.replicas.size() and a.replicas[slot].site_class == &"pistol"


## The first slot that isn't a pistol (the rifle that rides slung), or -1.
static func _first_rifle(a: Armament) -> int:
	for i in a.replicas.size():
		if not _is_pistol(a, i):
			return i
	return -1


## Moves the eased blends `delta` seconds towards the targets.
func settle(delta: float) -> void:
	var target_speed := gait.length()
	speed = lerpf(speed, target_speed, settle_share(delta, _config.settle_move))
	if target_speed > 0.0:
		var turned := way.lerp(gait / target_speed, settle_share(delta, _config.settle_direction))
		if turned.length_squared() > 0.0:
			way = turned.normalized()
	var mode := settle_share(delta, _config.settle_mode)
	call_weight = lerpf(call_weight, call, mode)
	walk_off_weight = lerpf(walk_off_weight, walk_off, mode)
	jump_weight = lerpf(jump_weight, jump, settle_share(delta, _config.settle_jump))
	vault_weight = lerpf(vault_weight, vault, settle_share(delta, _config.settle_vault))
	var hold := settle_share(delta, _config.settle_hold)
	pistol_weight = lerpf(pistol_weight, pistol, hold)
	holster_weight = lerpf(holster_weight, holster, hold)
	sprint_weight = lerpf(sprint_weight, sprinting, mode)
	raise = lerpf(raise, raise_target, settle_share(delta, _config.settle_raise))
	if raise_target == 0.0 and raise < _config.raise_rest:
		raise = 0.0


## The blends set to the targets at once: a figure's first frame, or its first after its legs were left still (hidden).
func snap() -> void:
	snapped = true
	speed = gait.length()
	if speed > 0.0:
		way = gait / speed
	jump_weight = jump
	vault_weight = vault
	call_weight = call
	walk_off_weight = walk_off
	pistol_weight = pistol
	holster_weight = holster
	sprint_weight = sprinting
	raise = raise_target


## The eased step (m/s, the figure's frame): where the gait blend stands.
func gait_position() -> Vector2:
	return way * speed


## How much the upper body's own clips show over the legs': none while calling the hit, walking off or vaulting (their
## clips move the whole body), as eased.
func upper_weight() -> float:
	return 1.0 - maxf(maxf(call_weight, walk_off_weight), vault_weight)


## Whether the legs step: the walk cycle sets the stepping clips' place (below it they run free, so Idle breathes).
func stepping() -> bool:
	return speed > still_speed


## The share of the way to the target `delta` seconds of easing covers with settle time `settle` (s).
static func settle_share(delta: float, settle: float) -> float:
	return 1.0 - exp(-maxf(delta, 0.0) / settle) if settle > 0.0 else 1.0


## Where in the Vault clip (0..1) vault `v` is: its first `top` over the rise onto the top, the rest across it to the
## hand-over to the fall, so the hop keeps to the body's path whatever the obstacle (the browser's vaultClipShare).
static func vault_progress(v: VaultState, top: float) -> float:
	return v.clip_share(top)
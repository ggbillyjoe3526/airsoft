class_name PlayerInput
extends Node
## The player's controller (the browser game's input/playerInput.ts): the mouse turns the view as events arrive, every
## rendered frame, and once a tick `fill` writes the keys and buttons into the player's PlayerCommand, the one input the
## simulation takes (docs/ARCHITECTURE.md › Contracts 2). Presses between two ticks are latched, so a tap shorter than a
## tick (a semi click, a jump, a reload) is never dropped. It reads nothing while the mouse isn't captured, so a menu
## click never fires a shot.
## Squad orders (M22, M23): an order key fills the next tick's squad order once. Held, the order wheel's key opens the
## wheel: the mouse moves its own pointer (OrderWheelPointer) instead of the view, the mouse wheel switches nothing, feet
## still move, and fire and aim need a fresh press once it closes. The order pointed at is given on letting go of the key
## (Hover) or on a click (either way); the wheel closes giving nothing on pause or focus loss (`release`) and once
## orders can't be given (`allow_orders`). Ping (PN1) fills the next tick's ping once, dead where the order keys are (on
## the range); the simulation drops one while you are out. Need a Mag (MH3: its key, or the wheel's item) fills the next
## tick's mag_hand_off once, dead on the range and while you are out (where the wheel is); `mag_from_wheel` says
## whether the last one sent was picked on the wheel, for where its refusal shows. Throw smoke and Throw flash (SF1)
## fill the next tick's throw_grenade once (the last pressed, if both). Open / shut door (DO1) fills the next tick's
## use_door once.
## Go there (FM1: its key, the wheel's Go There) is a ping along the view that sends your bot teammates there
## (PlayerCommand.ping_move). Held, the full-screen map's key opens the map (`allow_map`): as with the wheel the mouse
## moves the map's own pointer (MapPointer) instead of the view, feet still move, the mouse wheel switches nothing, and
## fire and aim need a fresh press once it closes; a click (fire) there is a Go there to that point of the field and a
## ping's press a ping there (ping_on_map), while orders can be given. The map and the wheel never open together.

## The actions in project.godot's input map.
const FORWARD := &"move_forward"
const BACK := &"move_back"
const LEFT := &"move_left"
const RIGHT := &"move_right"
const WALK := &"walk"
const SPRINT := &"sprint"
const CROUCH := &"crouch"
const JUMP := &"jump"
const LEAN_LEFT := &"lean_left"
const LEAN_RIGHT := &"lean_right"
const FIRE := &"fire"
const AIM := &"aim"
const RELOAD := &"reload"
const FIRE_MODE := &"fire_mode"
const SLOTS: Array[StringName] = [&"slot_1", &"slot_2"]
const NEXT_SLOT := &"slot_next"
const PREVIOUS_SLOT := &"slot_previous"
const HOP_UP_LESS := &"hop_up_less"
const HOP_UP_MORE := &"hop_up_more"
const HOLSTER := &"holster"
const TORCH := &"torch"
const SCOREBOARD := &"scoreboard"
## Held, the order wheel is open (the order keys are data: ControlsConfig.wheel_keys).
const ORDER_WHEEL := &"order_wheel"
## Ping where you look, for your bot teammates (PN1).
const PING := &"ping"
## Held, the full-screen map is open (FM1).
const FIELD_MAP := &"field_map"
## Go there (FM1): its key; the order wheel's Go There and a click on the map too.
const PING_MOVE := &"ping_move"
## The magazine hand-off (MH3): toss one to a teammate asking you in reach, else ask for one (MagShare).
const MAG := &"mag_hand_off"
## Throw a smoke bomb or a flash bomb (SF1).
const THROW_SMOKE := &"throw_smoke"
const THROW_FLASH := &"throw_flash"
const USE_DOOR := &"use_door"

## The view, absolute (rad): yaw 0 looks down -Z and turns left positive; pitch up positive.
var view_yaw: float = 0.0
var view_pitch: float = 0.0
## Mouse turns are read only while true (the play scene captures the mouse and sets it).
var active: bool = false
## The sight's zoom right now (1: none), which slows the mouse while aiming.
var zoom: float = 1.0

var _controls: ControlsConfig = null
var _max_pitch: float = 1.55
var _fire_latch: bool = false
var _jump_latch: bool = false
var _reload_latch: bool = false
var _mode_latch: bool = false
var _holster_latch: bool = false
var _torch_latch: bool = false
var _door_latch: bool = false
var _throw_latch: Grenade.Kind = Grenade.Kind.NONE
var _slot_latch: int = -1
## Hop-up notches pressed since the last tick (more lift positive).
var _hop_steps: int = 0
var _slot_steps: int = 0
var _crouched: bool = false
## Aiming, while aim toggles (ControlsConfig.aim_toggle).
var _aimed: bool = false
## Fire is ignored until it is let go (hold_fire), and so is aim pressed while the wheel was open.
var _fire_held_back: bool = false
var _aim_held_back: bool = false
## The squad order keyed or picked on the wheel since the last tick, and whether it came from the wheel.
var _order_latch: SquadOrder.Kind = SquadOrder.Kind.NONE
var _order_from_wheel: bool = false
## Ping pressed since the last tick, whether a Go there (FM1), and whether on the map at _ping_target.
var _ping_latch: bool = false
var _ping_move_latch: bool = false
var _ping_on_map: bool = false
var _ping_target: Vector3 = Vector3.ZERO
## Need a Mag pressed (or picked on the wheel) since the last tick, and whether picked on the wheel.
var _mag_latch: bool = false
var _mag_latch_wheel: bool = false
## The last Need a Mag sent (fill_order) was picked on the wheel; it stays until the next one is sent.
var mag_from_wheel: bool = false
## The last fill_order sent a Need a Mag of yours (the key or the wheel), not only a bot's playing you.
var mag_sent: bool = false
## Orders can be given (allow_orders): the keys, and the wheel only while `_wheel_allowed` too.
var _orders_allowed: bool = true
var _wheel_allowed: bool = true
var _wheel: OrderWheelPointer = OrderWheelPointer.new()
## The full-screen map's pointer, and whether there is a map to open (allow_map).
var _map: MapPointer = MapPointer.new()
var _map_allowed: bool = false


func setup(controls: ControlsConfig, max_pitch: float) -> void:
	_controls = controls
	_max_pitch = max_pitch
	_wheel = OrderWheelPointer.new(controls.wheel_reach, controls.wheel_dead_zone, controls.wheel_orders.size())


## The order wheel's pointer (read-only for the HUD): open, where, and the order pointed at.
func wheel() -> OrderWheelPointer:
	return _wheel


## The full-screen map's pointer (the HUD frames it each frame and draws it): open, and where.
func field_map() -> MapPointer:
	return _map


## Whether the full-screen map can open (`on`: a match on a field, not the range): it closes once it can't.
func allow_map(on: bool) -> void:
	_map_allowed = on
	if not on and _map.open:
		_close_map()


## Whether orders can be given: `keys` (false on the range: no teammates to order) lets the order keys and the wheel
## work, `wheel` (you are in play) the wheel too. The wheel closes giving nothing once it can't stay open.
func allow_orders(keys: bool, wheel_ok: bool) -> void:
	_orders_allowed = keys
	_wheel_allowed = keys and wheel_ok
	if not keys:
		_order_latch = SquadOrder.Kind.NONE
		_clear_ping()
	if not _wheel_allowed:
		_mag_latch = false
	if not _wheel_allowed and _wheel.open:
		_close_wheel()


## Whether a ping on the full-screen map would be taken now: orders can be given and you are in play (as the wheel).
func orders_allowed() -> bool:
	return _wheel_allowed


## Looks along (yaw, pitch), standing, as at a spawn.
func face(yaw: float, pitch: float = 0.0) -> void:
	_crouched = false
	_aimed = false
	view_yaw = yaw
	view_pitch = pitch


## Crouched or standing, as the crouch toggle keeps it (a held crouch key decides for itself): the range built again
## after the Loadout puts you back as you stood.
func set_crouched(on: bool) -> void:
	_crouched = on


## The crouch you chose: the toggle's, or the crouch key held. Not the body's (a vault tucks it).
func crouch_chosen() -> bool:
	return _crouched if _controls.crouch_toggle else Input.is_action_pressed(CROUCH)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if _wheel.open and _wheel_input(event):
		return
	if _map.open and _map_input(event):
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var turn := _controls.radians_per_count * _controls.sensitivity
		if _aiming():
			turn *= _controls.aim_sensitivity
		if _controls.scale_with_zoom:
			turn /= maxf(zoom, 1.0)
		view_yaw = wrapf(view_yaw - motion.screen_relative.x * turn, -PI, PI)
		var dy := motion.screen_relative.y * turn * (-1.0 if _controls.invert_y else 1.0)
		view_pitch = clampf(view_pitch - dy, -_max_pitch, _max_pitch)
		return
	if event.is_echo() or not event.is_pressed():
		return
	if _orders_allowed and _order_key(event):
		return
	if event.is_action(ORDER_WHEEL):
		if not _wheel.open and not _map.open: # a second key bound to the wheel doesn't recentre it
			_open_wheel()
	elif event.is_action(FIELD_MAP):
		if not _map.open and not _wheel.open:
			_open_map()
	elif event.is_action(FIRE):
		_fire_latch = true
	elif event.is_action(AIM) and _controls.aim_toggle:
		_aimed = not _aimed
	elif event.is_action(JUMP):
		if _controls.crouch_toggle and _crouched:
			_crouched = false
		else:
			_jump_latch = true
	elif event.is_action(CROUCH) and _controls.crouch_toggle:
		_crouched = not _crouched
	elif event.is_action(SPRINT):
		_crouched = false
	elif event.is_action(RELOAD):
		_reload_latch = true
	elif event.is_action(FIRE_MODE):
		_mode_latch = true
	elif event.is_action(HOLSTER):
		_holster_latch = true
		_slot_latch = -1
		_slot_steps = 0
	elif event.is_action(TORCH):
		_torch_latch = true
	elif event.is_action(THROW_SMOKE):
		_throw_latch = Grenade.Kind.SMOKE
	elif event.is_action(THROW_FLASH):
		_throw_latch = Grenade.Kind.FLASH
	elif event.is_action(USE_DOOR):
		_door_latch = true
	elif event.is_action(HOP_UP_LESS):
		_hop_steps -= 1
	elif event.is_action(HOP_UP_MORE):
		_hop_steps += 1
	elif event.is_action(PING):
		# Not while the wheel is open: it holds the view still, so a ping would land where the view was left.
		if _orders_allowed and not _wheel.open:
			_latch_ping(false)
	elif event.is_action(NEXT_SLOT):
		_slot_steps += 1
		_slot_latch = -1
		_holster_latch = false
	elif event.is_action(PREVIOUS_SLOT):
		_slot_steps -= 1
		_slot_latch = -1
		_holster_latch = false
	else:
		for i in SLOTS.size():
			if event.is_action(SLOTS[i]):
				_slot_latch = i
				_slot_steps = 0
				_holster_latch = false


## Whether Jump (Space) is held, which skips the round while you are out (only while the mouse is captured).
func skip_held() -> bool:
	return active and Input.is_action_pressed(JUMP)


## Whether the scoreboard's key is held (only while the mouse is captured, so a menu's Tab never shows it).
func scoreboard_held() -> bool:
	return active and Input.is_action_pressed(SCOREBOARD)


## Whether the sight is up, held or toggled, as the aimed sensitivity reads it.
func _aiming() -> bool:
	return _aimed if _controls.aim_toggle else Input.is_action_pressed(AIM) and not _aim_held_back


## An order key pressed: its order is latched for the next tick (true), else false.
func _order_key(event: InputEvent) -> bool:
	for i in _controls.wheel_keys.size():
		var key := _controls.wheel_keys[i]
		if key != &"" and i < _controls.wheel_orders.size() and event.is_action(key):
			_latch_order(_controls.wheel_orders[i], false)
			return true
	return false


func _latch_order(kind: SquadOrder.Kind, from_wheel: bool) -> void:
	if kind == SquadOrder.Kind.MAG:
		# Need a Mag is the hand-off's press, not an order: dead where the wheel is (the range, and you out).
		if _wheel_allowed:
			_mag_latch = true
			# H with the wheel held open answers in the wheel's middle too: the line under it is hidden.
			_mag_latch_wheel = from_wheel or _wheel.open
		return
	if kind == SquadOrder.Kind.MOVE:
		# Go there is a ping along the view (held still while the wheel is open: where you looked opening it).
		if _orders_allowed:
			_latch_ping(true)
		return
	_order_latch = kind
	_order_from_wheel = from_wheel


## A ping along the view latched for the next tick (`move`: a Go there).
func _latch_ping(move: bool) -> void:
	_ping_latch = true
	_ping_move_latch = move
	_ping_on_map = false


## A ping on the map at the pointer's point of the field latched for the next tick (`move`: a Go there); only while
## orders can be given and you are in play, as the wheel.
func _latch_map_ping(move: bool) -> void:
	if not _wheel_allowed or not _map.framed():
		return
	_ping_latch = true
	_ping_move_latch = move
	_ping_on_map = true
	_ping_target = _map.world()


func _clear_ping() -> void:
	_ping_latch = false
	_ping_move_latch = false
	_ping_on_map = false


## Opens the full-screen map, if there is one: the trigger is the map's until it closes and is let go.
func _open_map() -> void:
	if not _map_allowed:
		return
	_map.start()
	hold_fire()


## Closes the map; fire stays held back until it is let go (a click that pinged is not a shot).
func _close_map() -> void:
	_map.close()
	hold_fire()


## An event while the map is open: true if the map took it. The mouse moves its pointer; a click or Go there's key is a
## Go there there, the ping's press a ping there; letting go of the key closes it; aim waits for a fresh press; the mouse wheel and the
## order wheel's key do nothing. Everything else (the keys that move you, the order keys) goes on as usual.
func _map_input(event: InputEvent) -> bool:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_map.move(motion.screen_relative * _controls.map_gain * _controls.sensitivity)
		return true
	if event.is_echo():
		return false
	if event.is_action_released(FIELD_MAP):
		_close_map()
		return true
	if not event.is_pressed():
		return false
	if event.is_action(FIRE) or event.is_action(PING_MOVE):
		_latch_map_ping(true)
		return true
	if event.is_action(PING):
		_latch_map_ping(false)
		return true
	if event.is_action(AIM):
		_aim_held_back = true
		return true
	return event.is_action(NEXT_SLOT) or event.is_action(PREVIOUS_SLOT) or event.is_action(ORDER_WHEEL)


## Opens the wheel, if orders can be given: the trigger is the wheel's until it closes and is let go.
func _open_wheel() -> void:
	if not _wheel_allowed:
		return
	_wheel.start()
	hold_fire()


## An event while the wheel is open: true if the wheel took it. The mouse moves its pointer; a click on an order gives
## it; letting go of the key gives the order pointed at (Hover) and closes the wheel; aim waits for a fresh press; the
## mouse wheel switches nothing. Everything else (the keys that move you) goes on as usual.
func _wheel_input(event: InputEvent) -> bool:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_wheel.move(motion.screen_relative * _controls.wheel_gain * _controls.sensitivity)
		return true
	if event.is_echo():
		return false
	if event.is_action_released(ORDER_WHEEL):
		var pick := _wheel.pick()
		if pick != OrderWheelPointer.NONE and _controls.wheel_pick == ControlsConfig.WheelPick.HOVER:
			_latch_order(_controls.wheel_orders[pick], true)
		_close_wheel()
		return true
	if not event.is_pressed():
		return false
	if event.is_action(FIRE):
		var pick := _wheel.pick()
		if pick != OrderWheelPointer.NONE:
			_latch_order(_controls.wheel_orders[pick], true)
			_close_wheel()
		return true
	if event.is_action(AIM):
		_aim_held_back = true
		return true
	return event.is_action(NEXT_SLOT) or event.is_action(PREVIOUS_SLOT)


## Closes the wheel; fire stays held back until it is let go (a click that picked an order is not a shot).
func _close_wheel() -> void:
	_wheel.close()
	hold_fire()


## This tick's command: held keys as they are now, presses since the last tick, the view as the mouse left it.
## `held_slot` is the replica in hand, which the mouse wheel steps from.
func fill(cmd: PlayerCommand, held_slot: int = 0) -> void:
	if not active:
		cmd.reset(view_yaw, view_pitch)
		cmd.manual_reload = not _controls.auto_reload
		_clear_latches()
		return
	cmd.forward = Input.get_action_strength(FORWARD) - Input.get_action_strength(BACK)
	cmd.right = Input.get_action_strength(RIGHT) - Input.get_action_strength(LEFT)
	cmd.yaw = view_yaw
	cmd.pitch = view_pitch
	cmd.walk = Input.is_action_pressed(WALK)
	cmd.sprint = Input.is_action_pressed(SPRINT)
	cmd.crouch = crouch_chosen()
	cmd.aim = _aiming()
	# Lean is held, whatever crouch and aim do (owner, 2026-10-03).
	cmd.lean = Input.get_action_strength(LEAN_RIGHT) - Input.get_action_strength(LEAN_LEFT)
	if _map.open and not Input.is_action_pressed(FIELD_MAP):
		# its key let go unseen: closed
		_close_map()
	if not _wheel.open and not _map.open:
		if _fire_held_back and not Input.is_action_pressed(FIRE):
			_fire_held_back = false
		if _aim_held_back and not Input.is_action_pressed(AIM):
			_aim_held_back = false
	elif _wheel.open and not Input.is_action_pressed(ORDER_WHEEL):
		# its key let go unseen (a rebind, the window losing it): closed, giving nothing
		_close_wheel()
	cmd.fire = not _fire_held_back and (Input.is_action_pressed(FIRE) or _fire_latch)
	cmd.jump = _jump_latch # a press, not a hold: holding Space doesn't hop on every landing
	cmd.reload = _reload_latch
	cmd.manual_reload = not _controls.auto_reload
	cmd.cycle_fire_mode = _mode_latch
	cmd.switch_to = _slot_latch
	cmd.hop_up_steps = _hop_steps
	cmd.holster = _holster_latch
	cmd.toggle_torch = _torch_latch
	cmd.throw_grenade = _throw_latch
	cmd.use_door = _door_latch
	if _slot_steps != 0:
		cmd.switch_to = posmod(held_slot + _slot_steps, SLOTS.size())
	cmd.mag_hand_off = false
	fill_order(cmd)
	_clear_latches()


## Writes the squad order keyed or picked since the last tick, and a ping pressed since, into `cmd`, once. `fill`
## does; while a bot plays for you (the smoke test) the play scene calls it alone.
func fill_order(cmd: PlayerCommand) -> void:
	cmd.squad_order = _order_latch
	cmd.order_from_wheel = _order_from_wheel
	cmd.ping = _ping_latch
	cmd.ping_move = _ping_latch and _ping_move_latch
	cmd.ping_on_map = _ping_latch and _ping_on_map
	cmd.ping_target = _ping_target
	# A bot playing you (the smoke test) may press it too: a press of yours adds to it, never takes it away.
	mag_sent = _mag_latch
	if _mag_latch:
		cmd.mag_hand_off = true
		mag_from_wheel = _mag_latch_wheel
	_order_latch = SquadOrder.Kind.NONE
	_order_from_wheel = false
	_clear_ping()
	_mag_latch = false
	_mag_latch_wheel = false


## Ignores the fire button until it is let go: a click that moved the round on is not the next round's first shot.
func hold_fire() -> void:
	_fire_held_back = true
	_fire_latch = false


## Lets go of everything (focus lost, the menu opened), so no key stays held, and closes the wheel giving nothing.
func release() -> void:
	active = false
	_clear_latches()
	if _wheel.open:
		_close_wheel()
	if _map.open:
		_close_map()


func _clear_latches() -> void:
	_fire_latch = false
	_jump_latch = false
	_reload_latch = false
	_mode_latch = false
	_holster_latch = false
	_torch_latch = false
	_door_latch = false
	_throw_latch = Grenade.Kind.NONE
	_slot_latch = -1
	_slot_steps = 0
	_hop_steps = 0
	_order_latch = SquadOrder.Kind.NONE
	_order_from_wheel = false
	_clear_ping()
	_mag_latch = false
	_mag_latch_wheel = false

class_name KeyBindings
extends RefCounted
## The player's key bindings and their rules (the browser game's input/keyBindings.ts): each action has up to SLOTS keys
## in order, its main key first. A key belongs to one action. Taking a key another action uses swaps the two or, if
## the key was only that action's second one, just removes it there; a take that would leave an essential action
## (fire, the four moves) with no key is refused, and so are the keys in `unbindable`. Plain data and rules: `apply`
## writes them into Godot's InputMap, which PlayerInput and the HUD read at once.
## A binding is an int: a physical key (the Key enum, by position, so WASD stays WASD on any layout) or, negative, a
## mouse button (minus its MouseButton index; the wheel's two directions are buttons 4 and 5).

## Keys per action.
const SLOTS := 2
## No key.
const NONE := 0
## Actions the settings list, in the order the screen shows them.
const ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"walk", &"sprint", &"crouch", &"jump",
	&"lean_left", &"lean_right", &"fire", &"aim", &"reload", &"fire_mode", &"slot_1", &"slot_2", &"holster",
	&"torch", &"slot_next", &"slot_previous", &"hop_up_less", &"hop_up_more", &"scoreboard", &"field_map", &"order_follow",
	&"order_hold", &"order_regroup", &"order_wheel", &"ping", &"ping_move", &"mag_hand_off", &"throw_smoke", &"throw_flash",
	&"use_door",
	&"loadout",
]
## Actions that can never be left keyless (owner rule, DECISIONS › Menus, HUD, settings and accessibility).
const ESSENTIAL: Array[StringName] = [&"fire", &"move_forward", &"move_back", &"move_left", &"move_right"]
## project.godot's input map, by physical key; a test checks the two agree.
const DEFAULTS: Dictionary = {
	&"move_forward": [KEY_W, KEY_UP],
	&"move_back": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"walk": [KEY_SHIFT],
	&"sprint": [KEY_ALT],
	&"crouch": [KEY_C, KEY_CTRL],
	&"jump": [KEY_SPACE],
	&"lean_left": [KEY_Q],
	&"lean_right": [KEY_E],
	&"fire": [-MOUSE_BUTTON_LEFT],
	&"aim": [-MOUSE_BUTTON_RIGHT],
	&"reload": [KEY_R],
	&"fire_mode": [KEY_B],
	&"slot_1": [KEY_1],
	&"slot_2": [KEY_2],
	&"holster": [KEY_3],
	&"torch": [KEY_T],
	&"slot_next": [-MOUSE_BUTTON_WHEEL_DOWN],
	&"slot_previous": [-MOUSE_BUTTON_WHEEL_UP],
	&"hop_up_less": [KEY_4, KEY_PAGEDOWN],
	&"hop_up_more": [KEY_5, KEY_PAGEUP],
	&"scoreboard": [KEY_TAB],
	&"field_map": [KEY_M],
	&"order_wheel": [KEY_Z],
	&"order_follow": [KEY_F],
	&"order_hold": [KEY_X],
	&"order_regroup": [KEY_V],
	&"ping": [-MOUSE_BUTTON_MIDDLE],
	&"ping_move": [-MOUSE_BUTTON_XBUTTON1],
	&"mag_hand_off": [KEY_H],
	&"throw_smoke": [KEY_G],
	&"throw_flash": [KEY_Y],
	&"use_door": [KEY_U],
	&"loadout": [KEY_L],
}
## Keys that can't be bound: Esc (menus), PrintScreen, Pause, F11 (fullscreen), the debug keys (F3 the overlay, F4 BB
## paths, F5 hit areas; they stay reserved) and the OS keys. A test checks every `debug_*` action's key is here.
const UNBINDABLE: Array[int] = [KEY_ESCAPE, KEY_PRINT, KEY_PAUSE, KEY_F11, KEY_F3, KEY_F4, KEY_F5, KEY_META, KEY_MENU]
## The mouse buttons that can be bound (the wheel's sideways turns can't).
const MOUSE_BUTTONS: Array[int] = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP,
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]

## Why a rebind was refused, and what it did, for the screen's message.
enum Result { BOUND, SWAPPED, REFUSED_KEY, REFUSED_STRANDS }

var _map: Dictionary[StringName, PackedInt32Array] = {}
## The action a refusal or a swap named (the one left keyless or given a key), after `rebind`.
var last_other: StringName = &""


func _init() -> void:
	reset()


## Back to the defaults.
func reset() -> void:
	_map.clear()
	for action: StringName in ACTIONS:
		_map[action] = PackedInt32Array(DEFAULTS[action] as Array)


## `action`'s keys, main key first.
func codes(action: StringName) -> PackedInt32Array:
	return _map.get(action, PackedInt32Array())


## The action `code` is bound to, or an empty name.
func action_of(code: int) -> StringName:
	for action: StringName in ACTIONS:
		if _map[action].has(code):
			return action
	return &""


## Whether `code` can be bound at all.
static func bindable(code: int) -> bool:
	if code == NONE:
		return false
	if code < 0:
		return MOUSE_BUTTONS.has(-code)
	# A key Godot names: a printable one (physical keys are named on a US layout, up to the section sign) or a special one.
	var printable := code >= KEY_SPACE and code <= KEY_SECTION
	var special := code > KEY_SPECIAL and code < KEY_UNKNOWN
	return (printable or special) and not UNBINDABLE.has(code)


## The binding an input event would make, or NONE for one that isn't a key or mouse button press.
static func code_of_event(event: InputEvent) -> int:
	var key := event as InputEventKey
	if key != null:
		return int(key.physical_keycode)
	var button := event as InputEventMouseButton
	if button != null:
		return -int(button.button_index)
	return NONE


## The InputMap event for a binding.
static func event_of(code: int) -> InputEvent:
	if code < 0:
		var b := InputEventMouseButton.new()
		b.button_index = (-code) as MouseButton
		return b
	var k := InputEventKey.new()
	k.physical_keycode = code as Key
	return k


## Puts `code` in `action`'s key `slot` (0 the main key, 1 the second), keeping its other key. If another action had
## `code` as its main key it gets this slot's old key in its place (a swap) or, with none to give, its second key moves
## up; if `code` was only its second key it just loses it. Refused for keys that can't be bound and a take that would
## strand an essential action. `last_other` names the other action involved.
func rebind(action: StringName, code: int, slot: int = 0) -> Result:
	last_other = &""
	if not _map.has(action) or slot < 0 or slot >= SLOTS or not bindable(code):
		return Result.REFUSED_KEY
	var stranded := strands(action, code, slot)
	if stranded != &"":
		last_other = stranded
		return Result.REFUSED_STRANDS
	var mine := _map[action]
	var has_old := slot < mine.size()
	var old := mine[slot] if has_old else NONE
	var other := action_of(code)
	if other != &"" and other != action:
		last_other = other
		var theirs := _map[other]
		var swap_in := has_old and theirs.find(code) == 0 and not theirs.has(old)
		var rest := PackedInt32Array()
		for c in theirs:
			if c != code:
				rest.append(c)
			elif swap_in:
				rest.append(old)
		_map[other] = rest
	var k := mine.find(code)
	if k >= 0 and k != slot:
		# already this action's other key: the two change places
		if has_old:
			mine[k] = old
		else:
			mine.remove_at(k)
	if slot < mine.size():
		mine[slot] = code
	else:
		mine.append(code)
	_map[action] = mine
	return Result.SWAPPED if last_other != &"" else Result.BOUND


## The essential action that putting `code` in `action`'s `slot` would leave with no key (it is that action's only key
## and the slot has none to swap in), or an empty name.
func strands(action: StringName, code: int, slot: int = 0) -> StringName:
	var other := action_of(code)
	if other == &"" or other == action or not ESSENTIAL.has(other):
		return &""
	var theirs := _map[other]
	var mine := _map[action]
	var swap_in := theirs[0] == code and slot < mine.size() and not theirs.has(mine[slot])
	var left := theirs.size() - 1 + (1 if swap_in else 0)
	return &"" if left > 0 else other


## Clears `action`'s key `slot`; its second key moves up if the main key goes. Refused (false) for an empty slot and
## the last key of an essential action.
func unbind(action: StringName, slot: int = 0) -> bool:
	if not _map.has(action) or slot < 0 or slot >= _map[action].size():
		return false
	if _map[action].size() == 1 and ESSENTIAL.has(action):
		return false
	_map[action].remove_at(slot)
	return true


## The bindings as a saveable dictionary: action name to a list of ints.
func to_dict() -> Dictionary:
	var out := {}
	for action: StringName in ACTIONS:
		out[String(action)] = Array(_map[action])
	return out


## Takes saved bindings over the defaults, ignoring what is malformed or unknown: an action whose saved list is bad
## keeps its default. An action the save lacks (added by a later build) takes its default unless another action holds
## the key. A key on two actions, or an essential action left keyless, makes the whole set unusable and the defaults
## stand. Returns whether the saved set was used as it came.
func load_dict(data: Variant) -> bool:
	reset()
	if not data is Dictionary:
		return false
	var saved: Dictionary = data
	var ok := true
	var loaded: Dictionary[StringName, PackedInt32Array] = {}
	var taken: Dictionary[int, bool] = {}
	for action: StringName in ACTIONS:
		var name := String(action)
		if not saved.has(name):
			continue
		var list: Variant = _saved_list(saved[name])
		if list == null or (list as PackedInt32Array).is_empty() and ESSENTIAL.has(action):
			ok = false
			continue
		loaded[action] = list
		for c in loaded[action]:
			if taken.has(c):
				reset()
				return false
			taken[c] = true
	for action: StringName in ACTIONS:
		if loaded.has(action):
			_map[action] = loaded[action]
			continue
		# on its default: dropped where the player's own keys hold it
		var kept := PackedInt32Array()
		for c in _map[action]:
			if not taken.has(c):
				kept.append(c)
		_map[action] = kept
	for action: StringName in ESSENTIAL:
		if _map[action].is_empty():
			reset()
			return false
	return ok


## Writes the bindings into the InputMap (and lets go of every action whose keys changed, so a key held across the
## change doesn't stay pressed).
func apply() -> void:
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			continue
		var want := _map[action]
		var have := InputMap.action_get_events(action)
		if _same(have, want):
			continue
		InputMap.action_erase_events(action)
		for c in want:
			InputMap.action_add_event(action, event_of(c))
		Input.action_release(action)


static func _same(have: Array[InputEvent], want: PackedInt32Array) -> bool:
	if have.size() != want.size():
		return false
	for i in want.size():
		if code_of_event(have[i]) != want[i]:
			return false
	return true


## A saved list as ints (an empty list is an action the player cleared), or null if anything in it is malformed.
static func _saved_list(value: Variant) -> Variant:
	if not value is Array:
		return null
	var list: Array = value
	if list.size() > SLOTS:
		return null
	var out := PackedInt32Array()
	for v: Variant in list:
		if not (v is float or v is int) or not is_equal_approx(float(v), roundf(float(v))):
			return null
		var c := int(v)
		if not bindable(c) or out.has(c):
			return null
		out.append(c)
	return out

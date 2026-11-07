class_name KeyNames
## Names for bindings in the player's own keyboard layout: a physical key is named by what it prints (KeyW is "Z" on
## AZERTY) through DisplayServer.keyboard_get_keycode_from_physical, and a mouse button by its usual name.

const MOUSE_NAMES: Dictionary[int, String] = {
	MOUSE_BUTTON_LEFT: "KEY_MOUSE_LEFT",
	MOUSE_BUTTON_RIGHT: "KEY_MOUSE_RIGHT",
	MOUSE_BUTTON_MIDDLE: "KEY_MOUSE_MIDDLE",
	MOUSE_BUTTON_WHEEL_UP: "KEY_WHEEL_UP",
	MOUSE_BUTTON_WHEEL_DOWN: "KEY_WHEEL_DOWN",
	MOUSE_BUTTON_XBUTTON1: "KEY_MOUSE_4",
	MOUSE_BUTTON_XBUTTON2: "KEY_MOUSE_5",
}
const NO_KEY := "-"
## Keys whose own names read badly ("BracketLeft", "Kp 5", BP6): the main minus key is a word (KEY_MINUS), so it is
## never taken for NO_KEY; the number pad's keys are "Num" and what they print (KEY_NUM), Enter its own; any other
## printing key in plain ASCII shows the mark it prints.
const KEY_WORDS: Dictionary[int, String] = {KEY_MINUS: "KEY_MINUS", KEY_KP_ENTER: "KEY_NUM_ENTER"}
const NUM_MARKS: Dictionary[int, String] = {
	KEY_KP_0: "0", KEY_KP_1: "1", KEY_KP_2: "2", KEY_KP_3: "3", KEY_KP_4: "4", KEY_KP_5: "5", KEY_KP_6: "6",
	KEY_KP_7: "7", KEY_KP_8: "8", KEY_KP_9: "9", KEY_KP_ADD: "+", KEY_KP_SUBTRACT: "-", KEY_KP_MULTIPLY: "*",
	KEY_KP_DIVIDE: "/", KEY_KP_PERIOD: ".",
}
## The printing ASCII marks (a key's code is its character there); letters and digits keep their names.
const PRINTING_FIRST := 0x21
const PRINTING_LAST := 0x7E
const HEADLESS := "headless"


## The readable name of binding `code`; a dash when there is none.
static func name_of(code: int) -> String:
	if code == KeyBindings.NONE:
		return NO_KEY
	if code < 0:
		return TranslationServer.translate(MOUSE_NAMES.get(-code, "KEY_MOUSE_OTHER"))
	var physical := code as Key
	# the headless display server has no keyboard to ask (it reports an error), so keys keep their US names there
	var printed := KEY_NONE as Key
	if DisplayServer.get_name() != HEADLESS:
		printed = DisplayServer.keyboard_get_keycode_from_physical(physical)
	var key := printed if printed != KEY_NONE else physical
	if KEY_WORDS.has(key):
		return TranslationServer.translate(KEY_WORDS[key])
	if NUM_MARKS.has(key):
		return TranslationServer.translate("KEY_NUM") % NUM_MARKS[key]
	if key >= PRINTING_FIRST and key <= PRINTING_LAST and not _letter_or_digit(key):
		return char(key)
	var named := OS.get_keycode_string(key)
	return named if not named.is_empty() else str(code)


static func _letter_or_digit(key: int) -> bool:
	return (key >= KEY_0 and key <= KEY_9) or (key >= KEY_A and key <= KEY_Z)


## `codes` for display: "W / Up".
static func describe(codes: PackedInt32Array) -> String:
	if codes.is_empty():
		return NO_KEY
	var parts := PackedStringArray()
	for c in codes:
		parts.append(name_of(c))
	return " / ".join(parts)


## The name of `action`'s main key as the InputMap has it now (so a rebind shows), or a dash.
static func of_action(action: StringName) -> String:
	if not InputMap.has_action(action):
		return NO_KEY
	var events := InputMap.action_get_events(action)
	return name_of(KeyBindings.code_of_event(events[0])) if not events.is_empty() else NO_KEY

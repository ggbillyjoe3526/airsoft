class_name KeyBindingList
extends VBoxContainer
## The rebinding rows of the settings screen: an action's name and a button for each of its keys. Click a button, then
## press the key or mouse button to put there; Esc cancels, Backspace or Delete clears it. A key another action uses
## swaps the two (the rules are KeyBindings'), and what happened is said in a note. Every key and click made while it
## waits is taken here and goes no further, so it can't reach play. The wait ends with the list hidden (another tab),
## its button's focus gone or the window's.

## A change was made (the bindings are already applied to the InputMap).
signal rebound
## Something to tell the player, in one line.
signal note(text: String)

const ROW_LABEL_WIDTH := 300.0
## One fixed width for every key's box (a field, owner 2026-10-29), wide enough for the longest key name and PRESS A KEY.
const KEY_BUTTON_WIDTH := 170.0
const ROW_GAP := 6
const ROW_SEPARATION := 8

var _settings: Settings = null
var _buttons: Dictionary[StringName, Array] = {}
var _action: StringName = &""
var _slot := 0


func _init(settings: Settings = null) -> void:
	_settings = settings


func _ready() -> void:
	add_theme_constant_override("separation", ROW_GAP)
	for action: StringName in KeyBindings.ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", ROW_SEPARATION)
		var label := Label.new()
		label.text = tr(label_key(action))
		GameTheme.row_label(label)
		label.custom_minimum_size = Vector2(ROW_LABEL_WIDTH, 0.0)
		row.add_child(label)
		var pair: Array[Button] = []
		for slot in KeyBindings.SLOTS:
			var b := Button.new()
			GameTheme.small_button(b)
			b.custom_minimum_size.x = KEY_BUTTON_WIDTH
			b.pressed.connect(begin.bind(action, slot))
			b.focus_exited.connect(_on_focus_left.bind(action, slot))
			row.add_child(b)
			pair.append(b)
		_buttons[action] = pair
		add_child(row)
	refresh()


func _notification(what: int) -> void:
	if not capturing():
		return
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		cancel()


## The waiting button lost focus: the wait ends.
func _on_focus_left(action: StringName, slot: int) -> void:
	if _action == action and _slot == slot:
		cancel()


## The translation key of an action's name.
static func label_key(action: StringName) -> String:
	return "ACT_" + String(action).to_upper()


## Whether the list is waiting for a key.
func capturing() -> bool:
	return _action != &""


## Waits for the key to put in `action`'s key `slot`.
func begin(action: StringName, slot: int) -> void:
	cancel()
	_action = action
	_slot = slot
	(_buttons[action][slot] as Button).text = tr("KEYS_PRESS")


## Stops waiting; the buttons show their keys again.
func cancel() -> void:
	_action = &""
	refresh()


## Every button shows its key, in the player's keyboard layout.
func refresh() -> void:
	for action: StringName in KeyBindings.ACTIONS:
		var codes := _settings.bindings.codes(action)
		for slot in KeyBindings.SLOTS:
			var code: int = codes[slot] if slot < codes.size() else KeyBindings.NONE
			(_buttons[action][slot] as Button).text = KeyNames.name_of(code)


## Back to the default keys.
func reset_all() -> void:
	cancel()
	_settings.bindings.reset()
	_changed()
	note.emit(tr("KEYS_RESET"))


func _input(event: InputEvent) -> void:
	if _action == &"" or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	var button := event as InputEventMouseButton
	if key == null and button == null:
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	if key != null and key.physical_keycode == KEY_ESCAPE:
		cancel()
		note.emit(tr("KEYS_CANCELLED"))
	elif key != null and (key.physical_keycode == KEY_BACKSPACE or key.physical_keycode == KEY_DELETE):
		_clear()
	else:
		_bind(KeyBindings.code_of_event(event))


func _bind(code: int) -> void:
	var action := _action
	var result := _settings.bindings.rebind(action, code, _slot)
	var key_name := KeyNames.name_of(code)
	var other := tr(label_key(_settings.bindings.last_other)) if _settings.bindings.last_other != &"" else ""
	match result:
		# a refused key leaves the list waiting: the player can try another
		KeyBindings.Result.REFUSED_KEY:
			note.emit(tr("KEYS_REFUSED") % key_name)
		KeyBindings.Result.REFUSED_STRANDS:
			note.emit(tr("KEYS_STRANDS") % [other, key_name])
		KeyBindings.Result.SWAPPED:
			_done()
			note.emit(tr("KEYS_SWAPPED") % [tr(label_key(action)), key_name, other])
		_:
			_done()
			note.emit(tr("KEYS_BOUND") % [tr(label_key(action)), key_name])


func _clear() -> void:
	var action := _action
	if _settings.bindings.unbind(action, _slot):
		_done()
		note.emit(tr("KEYS_CLEARED") % tr(label_key(action)))
	else:
		note.emit(tr("KEYS_NEEDS_ONE") % tr(label_key(action)))


## A binding changed: stop waiting, apply, tell the screen.
func _done() -> void:
	_action = &""
	_changed()


func _changed() -> void:
	SettingsApply.apply_bindings(_settings)
	refresh()
	rebound.emit()

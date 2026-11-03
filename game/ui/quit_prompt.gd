class_name QuitPrompt
extends Control
## QUIT GAME? (owner, 2026-10-29): Esc anywhere in the menus, the title screen included, asks it. Over a shade, a panel in
## the settings question's look (SettingsSaveConfirm): the question, a line saying nothing is lost, and QUIT beside CANCEL.
## The focus starts on CANCEL and returns to what had it when it closes; CANCEL or Esc closes it, QUIT sends `confirmed`
## (the game quits).
## Built when asked and freed once it closes.

## QUIT was pressed.
signal confirmed
## It closed (CANCEL or Esc; not QUIT).
signal closed

## Every prompt up is in this group: a page's own keys (the Loadout page's 1 to 5) wait while one is (BP3; Godot hands
## every _unhandled_input its key before any _unhandled_key_input, where this prompt stops keys).
const GROUP := &"quit_prompt"
## The shade over the screen (the page colour, this opaque), the panel's width, its inner margins and the yellow rule on
## top (px at 1080p).
const SHADE_ALPHA := 0.72
const WIDTH := 420.0
const PAD := Vector2i(36, 30)
const RULE := 5
## The words' sizes, the gap between the parts and the buttons' margins (px).
const TITLE_SIZE := 40
const NOTE_SIZE := 19
const BUTTON_SIZE := 18
const GAP := 14
const ACTIONS_GAP := 12
const BUTTON_PAD := Vector2i(26, 12)

var _quit: Button = null
var _cancel: Button = null
## The control that had the keyboard when it opened; it gets it back when the prompt closes.
var _before: Control = null


func _init() -> void:
	name = "QuitPrompt"
	theme = GameTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(GameTheme.BG, SHADE_ALPHA)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var frame := VBoxContainer.new()
	frame.custom_minimum_size.x = WIDTH
	frame.add_theme_constant_override("separation", 0)
	centre.add_child(frame)
	var rule := ColorRect.new()
	rule.color = GameTheme.ACCENT
	rule.custom_minimum_size.y = RULE
	frame.add_child(rule)
	var panel := PanelContainer.new()
	var box := GameTheme.box(GameTheme.PANEL, GameTheme.LINE, PAD.x, PAD.y)
	box.border_width_top = 0
	panel.add_theme_stylebox_override("panel", box)
	frame.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	panel.add_child(col)
	col.add_child(MenuParts.spaced(tr("QUIT_TITLE").to_upper(), TITLE_SIZE, 800, GameTheme.TEXT, GameTheme.SPACING_TAB))
	var note := MenuParts.text(tr("QUIT_NOTE"), NOTE_SIZE, 600, GameTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", ACTIONS_GAP)
	col.add_child(actions)
	_quit = Button.new()
	_quit.name = "Quit"
	_quit.text = tr("QUIT_YES").to_upper()
	SettingsSavePage.paint(_quit, GameTheme.ACCENT, GameTheme.ACCENT, GameTheme.ACCENT_INK, BUTTON_SIZE, BUTTON_PAD)
	_quit.pressed.connect(func() -> void: confirmed.emit())
	actions.add_child(_quit)
	_cancel = Button.new()
	_cancel.name = "Cancel"
	_cancel.text = tr("QUIT_CANCEL").to_upper()
	SettingsSavePage.paint(_cancel, Color(0.0, 0.0, 0.0, 0.0), GameTheme.ACCENT, GameTheme.TEXT, BUTTON_SIZE, BUTTON_PAD)
	_cancel.pressed.connect(close)
	actions.add_child(_cancel)
	ButtonWidth.group([_quit, _cancel])
	# the focus goes between the two buttons only, never to the menu under the shade
	for b: Button in [_quit, _cancel]:
		var other := _cancel if b == _quit else _quit
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			b.set_focus_neighbor(side, b.get_path_to(other))
		b.focus_next = b.get_path_to(other)
		b.focus_previous = b.get_path_to(other)


func _ready() -> void:
	add_to_group(GROUP)
	_before = get_viewport().gui_get_focus_owner()
	_cancel.grab_focus()


## The QUIT button and CANCEL, for tests.
func quit_button() -> Button:
	return _quit


func cancel_button() -> Button:
	return _cancel


## Closes it: `closed` is sent and the prompt freed.
func close() -> void:
	if is_queued_for_deletion():
		return
	# the keyboard goes back to where it was (START, PLAY, a Settings control), never to nothing
	if _before != null and is_instance_valid(_before) and _before.is_visible_in_tree() \
			and _before.focus_mode != Control.FOCUS_NONE:
		_before.grab_focus()
	else:
		_cancel.release_focus()
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()


## Keys the focused control left stop here, so none reaches a menu underneath (Esc and the like, which the game keeps for
## itself, excepted).
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and not KeyBindings.UNBINDABLE.has(int(key.physical_keycode)):
		get_viewport().set_input_as_handled()

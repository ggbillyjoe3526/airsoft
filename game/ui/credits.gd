class_name Credits
extends Control
## The credits: who made the game, then every third-party licence it ships (THIRD_PARTY_NOTICES.txt, written by
## tools/make_notices.gd from Godot's own licence data and each add-on's and asset's licence file). Esc closes it.

const NOTICES := "res://THIRD_PARTY_NOTICES.txt"

## Hidden again (Back or Esc), so whoever opened it can take the focus back.
signal closed

var _text: TextEdit
var _back: Button


func _ready() -> void:
	theme = GameTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plate := ColorRect.new()
	plate.color = GameTheme.BG
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(plate)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 48
	box.offset_top = 32
	box.offset_right = -48
	box.offset_bottom = -32
	add_child(box)
	# the other pages' title: condensed display capitals (BP6: it was the body font)
	box.add_child(MenuParts.page_title(tr("CREDITS_TITLE")))
	_text = TextEdit.new()
	_text.editable = false
	# long lines wrap: unwrapped, a licence's copyright line ran past the box's right edge (UI1)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_text)
	_back = Button.new()
	_back.text = tr("CREDITS_BACK").to_upper()
	_back.pressed.connect(close)
	# as wide as its words, at the left (owner, 2026-10-29), not the width of the screen
	ButtonWidth.group([_back])
	box.add_child(_back)


func _body() -> String:
	var notices := FileAccess.get_file_as_string(NOTICES)
	if notices.is_empty():
		push_warning("credits: can't read %s" % NOTICES)
		notices = tr("CREDITS_UNREADABLE")
	return tr("CREDITS_BYLINE") + "\n\n" + notices


## Shows the credits. The notices (about 2,000 lines) are read and laid out on the first open, not at boot.
func open() -> void:
	if _text.text.is_empty():
		_text.text = _body()
	visible = true
	# take focus, so Tab and Enter can't reach the boot screen's buttons underneath
	_back.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func text_length() -> int:
	return _text.text.length() if _text else 0


## Whether the shipped licence notices were found (the smoke test checks this on exported builds too).
func has_notices() -> bool:
	return _text != null and _text.text.contains("Godot Engine")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

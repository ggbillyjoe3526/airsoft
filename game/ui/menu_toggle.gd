class_name MenuToggle
extends Button
## An On/Off switch with its words beside it (Customise's REALISTIC COLOURS EVERYWHERE): the Settings switch's pill
## (MenuSwitch), then the label in Settings' row style; what it does is its tooltip (UI1: one switch everywhere, and the
## note beside it only explained). A toggle button, so Space and Enter flip it and `toggled` tells the page. Its size never
## changes with its state.

const GAP := 12

var _row: HBoxContainer = null
var _pill: MenuSwitch = null


## A toggle labelled `label_text`, with `note_text` as its tooltip.
func _init(label_text: String, note_text: String) -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	tooltip_text = note_text
	# its words are a label of its own, not the button's text: a screen reader is given them (AC6, BP7)
	accessibility_name = label_text
	accessibility_description = note_text
	var none := StyleBoxEmpty.new()
	GameTheme.dress(self, none, none, none)
	add_theme_stylebox_override("focus", GameTheme.focus_box())
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", GAP)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_row)
	# the pill only draws: this button takes the clicks and the focus
	_pill = MenuSwitch.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.focus_mode = Control.FOCUS_NONE
	_row.add_child(_pill)
	var label := Label.new()
	label.text = label_text
	GameTheme.row_label(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(label)
	custom_minimum_size = Vector2(0.0, GameTheme.CONTROL_HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_row.minimum_size_changed.connect(_fit)
	toggled.connect(_pill.put)
	_fit()


## Sets the switch without sending `toggled`.
func put(on: bool) -> void:
	set_pressed_no_signal(on)
	_pill.put(on)


## As wide as the pill and its words, so the focus ring and the clicks cover them and no more.
func _fit() -> void:
	custom_minimum_size.x = _row.get_combined_minimum_size().x

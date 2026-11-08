class_name SkipSimulate
extends HBoxContainer
## SIMULATE on a skip's cover (BP8, owner: beside the fast-forward skip): the trigger's key on a chip and the button,
## shown above "Skipping the round" while a skip plays the round out, only with Settings › Gameplay › Simulate skipped
## rounds on. Pressed (a click, or a fresh press of the trigger while skipping, PlaySession), the rest of the round is
## decided at once (Round.simulate). Built once with the cover; `show_for` rewrites the key only when it shows.

## Sent when the button is pressed.
signal simulate_pressed

## Above the skip line (px), and the chip's and words' look (the skip hint's, HUD).
const GAP := 14
const ABOVE := 12
const KEY_SIZE := 14
const KEY_PAD := Vector2i(10, 4)

var _key: Label = null
var _button: Button = null


func _init() -> void:
	name = "SkipSimulate"
	add_theme_constant_override("separation", GAP)
	alignment = BoxContainer.ALIGNMENT_CENTER
	visible = false
	_key = HudStyle.label(self, KEY_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.SPACING_AIM)
	_key.add_theme_stylebox_override("normal", GameTheme.box(GameTheme.CARD_HI, GameTheme.LINE, KEY_PAD.x, KEY_PAD.y))
	_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_button = Button.new()
	_button.name = "Simulate"
	_button.text = tr("HUD_SIMULATE").to_upper()
	_button.focus_mode = Control.FOCUS_NONE
	GameTheme.small_button(_button, GameTheme.ACCENT)
	_button.pressed.connect(func() -> void: simulate_pressed.emit())
	add_child(_button)


## Seats it above `line` (the skip line, anchored at the bottom's centre), centred on it.
func seat_above(line: Control) -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -ABOVE
	offset_top = -ABOVE
	line.add_child(self)


## Shows it, the trigger's key `key` on its chip (as bound now), or hides it.
func show_for(on: bool, key: String = "") -> void:
	visible = on
	if on:
		_key.text = key.to_upper()


func button() -> Button:
	return _button

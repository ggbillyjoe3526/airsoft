class_name SkipSimulate
extends HBoxContainer
## SIMULATE on a skip's cover (BP8, owner: beside the fast-forward skip): a button, shown above "Skipping the round"
## while a skip plays the round out, only with Settings › Gameplay › Simulate skipped rounds on. Clicked (the pointer
## shows while it is on offer, PlaySession), the rest of the round is decided at once (Round.simulate). A button only:
## the trigger never presses it, so a double click to skip can't simulate by accident. Built once with the cover.

## Sent when the button is pressed.
signal simulate_pressed

## Above the skip line (px).
const ABOVE := 12

var _button: Button = null


func _init() -> void:
	name = "SkipSimulate"
	alignment = BoxContainer.ALIGNMENT_CENTER
	visible = false
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


## Shows it or hides it.
func show_for(on: bool) -> void:
	visible = on


func button() -> Button:
	return _button

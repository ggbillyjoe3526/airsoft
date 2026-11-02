class_name MenuChoice
extends HBoxContainer
## A row of buttons of which one is picked (the concept `hud-options.png`'s Cross / Cross and Dot / Circle / Dot): each a
## card-coloured box with its words in capitals, the picked one edged in yellow. Arrow keys and Tab move between them,
## Space or Enter picks; `picked` tells the page. Compact: their words as given in a plain face and the unpicked
## ones dim (the Match page's Custom rows, concept `rules-custom.png`). The buttons are all as wide as the widest one's
## words and its padding (ButtonWidth), compact or not: none is wider than its words need, and none is wider than the rest
## (owner, 2026-10-29).

## A button was picked: its index.
signal picked(index: int)

const GAP := 6
const COMPACT_SIZE := 15

var _buttons: Array[Button] = []
var _group := ButtonGroup.new()
var _width: ButtonWidth = null
## Whether the buttons are made one width: not for a row with no words (MenuSwatches' squares).
var _same_width: bool = true


## The buttons, one per word in `words` (already translated), in order. Each is GameTheme.CONTROL_HEIGHT tall and has
## one box per state, all with the same margins (GameTheme.dress), so hovering, pressing or picking one never changes
## its size or cuts its words (UI1).
func _init(words: PackedStringArray, compact: bool = false) -> void:
	add_theme_constant_override("separation", GAP)
	var pad := GameTheme.CONTROL_PAD_X
	var text_size := COMPACT_SIZE if compact else GameTheme.CONTROL_SIZE
	var font := GameTheme.font(700) if compact else GameTheme.spaced_font(800, GameTheme.SPACING_TAB, text_size)
	var plain := GameTheme.box(GameTheme.CARD, GameTheme.LINE, pad, 0)
	var hover := GameTheme.box(GameTheme.CARD_HI, GameTheme.LINE, pad, 0)
	var lit := GameTheme.box(GameTheme.CARD_HI, GameTheme.ACCENT, pad, 0)
	for i in words.size():
		var b := Button.new()
		b.text = words[i] if compact else words[i].to_upper()
		b.custom_minimum_size.y = GameTheme.CONTROL_HEIGHT
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", text_size)
		GameTheme.dress(b, plain, hover, lit)
		b.add_theme_color_override("font_color", GameTheme.DIM if compact else GameTheme.MUTED)
		b.add_theme_color_override("font_hover_color", GameTheme.TEXT)
		b.add_theme_color_override("font_pressed_color", GameTheme.TEXT)
		b.add_theme_color_override("font_hover_pressed_color", GameTheme.TEXT)
		add(b)


## Picks `index` without sending `picked`.
func put(index: int) -> void:
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == index)


## The picked index, or -1.
func selected() -> int:
	for i in _buttons.size():
		if _buttons[i].button_pressed:
			return i
	return -1


func button(index: int) -> Button:
	return _buttons[index]


## Adds `b` as the next choice.
func add(b: Button) -> void:
	b.toggle_mode = true
	b.button_group = _group
	b.pressed.connect(_on_pressed.bind(_buttons.size()))
	add_child(b)
	_buttons.append(b)
	if not _same_width:
		return
	if _width == null:
		_width = ButtonWidth.group([b])
	else:
		_width.add(b)


func _on_pressed(index: int) -> void:
	# the pick shows whoever pressed it (a click toggles the button; a `pressed` sent from code does not)
	put(index)
	picked.emit(index)

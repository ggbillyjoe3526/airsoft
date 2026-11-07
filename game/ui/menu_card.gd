class_name MenuCard
extends Button
## A card you click: a flat box with a border and content laid inside it (the Match page's maps, modes and teams).
## Picked, its border takes the accent (safety yellow; a team's colour on the team cards) and its fill the picked
## fill; with `ring` the border is doubled outwards, as the concept's picked map. Greyed: faded and not clickable.
## An optional bar runs down the inside of its left edge (the team cards). A screen reader names it by its words (its
## labels in order: the map, mode, replica or part on it; AC6, BP7) unless its builder named it (`accessibility_name`).

const GREYED_ALPHA := 0.55
const RING := 2
const BAR_WIDTH := 6.0
const HOVER_LIGHTEN := 0.06
## Between one label's words and the next in the spoken name.
const SPOKEN_JOIN := ", "

var fill: Color = GameTheme.CARD
var picked_fill: Color = GameTheme.CARD_HI
var accent: Color = GameTheme.ACCENT
var ring: bool = false
## The left bar's colour (transparent: none), and how much of it shows while the card isn't picked.
var bar: Color = Color(0.0, 0.0, 0.0, 0.0)
var bar_idle: float = 0.5
## The room a card that is only words (`text`) keeps at each side of them (px): a ButtonWidth group of such cards is as
## wide as the widest one's words and this. A card laid out with `add_content` leaves it 0.
var text_pad: int = 0

var _picked: bool = false
var _bar: ColorRect = null
## The name this card last gave itself from its words ("" none): a name that differs was set by its builder and is kept.
var _named_by_words: String = ""


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	clip_contents = false
	_restyle()


## Names the card for a screen reader as one asks (Godot sends the update only while one is listening): its words now,
## so a card whose words change says the new ones.
func _notification(what: int) -> void:
	if what == NOTIFICATION_ACCESSIBILITY_UPDATE or what == NOTIFICATION_READY:
		name_by_words()


## The words on the card, its visible labels' in order, joined ("" with none).
func spoken_words() -> String:
	var words := PackedStringArray()
	if text != "":
		words.append(text)
	_gather_words(self, words)
	return SPOKEN_JOIN.join(words)


## Takes the card's words as its accessibility_name, unless its builder named it; true if the name changed.
func name_by_words() -> bool:
	if accessibility_name != "" and accessibility_name != _named_by_words:
		return false
	var words := spoken_words()
	if words == accessibility_name:
		return false
	accessibility_name = words
	_named_by_words = words
	return true


func _gather_words(node: Node, words: PackedStringArray) -> void:
	for child in node.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is Label:
			var said := (child as Label).text.strip_edges()
			if said != "":
				words.append(said)
		elif child is RichTextLabel:
			var said := (child as RichTextLabel).get_parsed_text().strip_edges()
			if said != "":
				words.append(said)
		_gather_words(child, words)


## Lays `content` inside the border and lets clicks through it to the card.
func add_content(content: Control) -> void:
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: Side in [SIDE_LEFT, SIDE_TOP]:
		content.set_offset(side, float(GameTheme.BORDER))
	for side: Side in [SIDE_RIGHT, SIDE_BOTTOM]:
		content.set_offset(side, -float(GameTheme.BORDER))
	_ignore_mouse(content)
	add_child(content)
	if _bar != null:
		move_child(_bar, get_child_count() - 1)


func set_picked(on: bool) -> void:
	_picked = on
	_restyle()


func is_picked() -> bool:
	return _picked


func set_greyed(on: bool) -> void:
	disabled = on
	modulate.a = GREYED_ALPHA if on else 1.0


## Call after setting the colours: redraws the card and its bar.
func refresh() -> void:
	_restyle()


func _restyle() -> void:
	var edge := accent if _picked else GameTheme.LINE
	var face := picked_fill if _picked else fill
	var plain := _box(face, edge)
	GameTheme.dress(self, plain, _box(face if _picked else face.lightened(HOVER_LIGHTEN), edge), plain)
	add_theme_stylebox_override("focus", GameTheme.focus_box())
	if bar.a > 0.0:
		if _bar == null:
			_bar = ColorRect.new()
			_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_bar.anchor_bottom = 1.0
			_bar.offset_left = float(GameTheme.BORDER)
			_bar.offset_right = float(GameTheme.BORDER) + BAR_WIDTH
			_bar.offset_top = float(GameTheme.BORDER)
			_bar.offset_bottom = -float(GameTheme.BORDER)
			add_child(_bar)
		_bar.color = Color(bar, 1.0 if _picked else bar_idle)


func _box(face: Color, edge: Color) -> StyleBoxFlat:
	var s := GameTheme.box(face, edge, text_pad, 0)
	if ring and _picked:
		s.set_border_width_all(GameTheme.BORDER + RING)
		s.set_expand_margin_all(RING)
	return s


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

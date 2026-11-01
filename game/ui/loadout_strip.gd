class_name LoadoutStrip
extends HBoxContainer
## The saved loadouts strip (concept `.saved`): a card for each saved loadout with its key 1 to 5, the carried one lit, then
## "+ NEW LOADOUT" while there is room, and Rename, Duplicate, Replace and Remove on the right. Every action is
## SavedLoadouts'; the strip only asks for it. Rename types over the carried one's name, Replace asks which loadout takes
## the carried one's place and Remove asks once more, each left again with Esc (`cancel`).

enum Mode { NORMAL, RENAMING, REPLACING, REMOVING }

const HEIGHT := 56.0
const GAP := 10
const PAD_X := 22
const NAME_SIZE := 18
const KEY_SIZE := 13
const KEY_GAP := 10
const SPACING := 0.04
const ACTION_GAP := 8
const ACTION_PAD := 10
const DASH := 6.0
const EDIT_WIDTH := 260.0
## The most room a loadout's name takes on its card (px): a longer one ends in "…" and the card's tooltip is the whole
## name, so five cards of the longest names and the actions fit the window (UI1).
const NAME_WIDTH := 170.0

signal mode_changed

var saved: SavedLoadouts = null
var mode: Mode = Mode.NORMAL

## The card of each loadout (null while its name is being typed).
var _cards: Array[MenuCard] = []
## Each card's name label, by loadout (null while its name is being typed).
var _names: Array[Label] = []
var _new: MenuCard = null
var _edit: LineEdit = null
var _actions: Dictionary[StringName, Button] = {}
var _prompt: Label = null
var _signature: String = ""


func _init(saved_in: SavedLoadouts) -> void:
	name = "LoadoutStrip"
	saved = saved_in
	add_theme_constant_override("separation", GAP)
	custom_minimum_size = Vector2(0.0, HEIGHT)
	refresh()


## The card of loadout `index`.
func card(index: int) -> MenuCard:
	return _cards[index]


func new_card() -> MenuCard:
	return _new


func action(id: StringName) -> Button:
	return _actions[id]


func edit() -> LineEdit:
	return _edit


## The line that asks what the strip is waiting for ("" in the normal mode).
func prompt_text() -> String:
	return _prompt.text if _prompt != null else ""


## Leaves rename, replace or remove without doing anything; false if the strip was not in one.
func cancel() -> bool:
	if mode == Mode.NORMAL:
		return false
	_set_mode(Mode.NORMAL)
	return true


## Rebuilds the cards if the loadouts, the carried one or the mode changed since they were drawn.
func refresh() -> void:
	var sig := "%d|%d|%d|%s" % [saved.current, mode, saved.slots.size(), ",".join(saved.slots.map(
			func(l: Loadout) -> String: return l.name))]
	if sig == _signature:
		return
	_signature = sig
	_rebuild()
	# a card is as wide as its words, which can only be measured once the strip has its theme
	_fit.call_deferred()


func start_rename() -> void:
	_set_mode(Mode.RENAMING)


func start_replace() -> void:
	if saved.slots.size() > 1:
		_set_mode(Mode.REPLACING)


func start_remove() -> void:
	if saved.slots.size() > 1:
		_set_mode(Mode.REMOVING)


func _fit() -> void:
	for i in _names.size():
		if _names[i] != null and _cap_name(_names[i]):
			_cards[i].tooltip_text = saved.slots[i].name
	var all: Array[MenuCard] = _cards.duplicate()
	all.append(_new)
	for card_node: MenuCard in all:
		if card_node != null and card_node.get_child_count() > 0:
			card_node.custom_minimum_size.x = (card_node.get_child(0) as Control).get_combined_minimum_size().x \
					+ GameTheme.BORDER * 2


## A name wider than NAME_WIDTH takes NAME_WIDTH and ends in "…" (true); a shorter one keeps its own width.
static func _cap_name(label: Label) -> bool:
	var font := label.get_theme_font(&"font")
	var natural := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			label.get_theme_font_size(&"font_size")).x
	label.custom_minimum_size.x = ceilf(minf(natural, NAME_WIDTH))
	return natural > NAME_WIDTH


func _set_mode(m: Mode) -> void:
	mode = m
	_signature = ""
	refresh()
	mode_changed.emit()
	if not is_inside_tree():
		return
	if m == Mode.RENAMING and _edit != null:
		_edit.grab_focus()
		_edit.select_all()
	elif m == Mode.REMOVING:
		(_actions[&"keep"] as Button).grab_focus()
	elif m == Mode.NORMAL and _cards.size() > saved.current and _cards[saved.current] != null:
		_cards[saved.current].grab_focus()


func _rebuild() -> void:
	_edit = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_cards.clear()
	_names.clear()
	_actions.clear()
	_new = null
	_prompt = null
	for i in saved.slots.size():
		if mode == Mode.RENAMING and i == saved.current:
			_edit = _build_edit(saved.slots[i].name)
			add_child(_edit)
			_cards.append(null)
			_names.append(null)
			continue
		var c := _build_card(i)
		add_child(c)
		_cards.append(c)
	if mode == Mode.NORMAL and saved.slots.size() < SavedLoadouts.MAX_SLOTS:
		_new = _build_new()
		add_child(_new)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spacer)
	match mode:
		Mode.REPLACING:
			_say("LOADOUT_REPLACE_PROMPT", saved.carried().name)
		Mode.REMOVING:
			_say("LOADOUT_REMOVE_PROMPT", saved.carried().name)
			_link(&"remove_yes", "LOADOUT_REMOVE_YES", _remove_carried)
			_link(&"keep", "LOADOUT_KEEP", cancel)
		Mode.RENAMING:
			_say("LOADOUT_RENAME_PROMPT", "")
		_:
			_link(&"rename", "LOADOUT_RENAME", start_rename)
			_link(&"duplicate", "LOADOUT_DUPLICATE", _duplicate)
			_link(&"replace", "LOADOUT_REPLACE", start_replace)
			_link(&"remove", "LOADOUT_REMOVE", start_remove)
			_actions[&"duplicate"].disabled = saved.slots.size() >= SavedLoadouts.MAX_SLOTS
			_actions[&"replace"].disabled = saved.slots.size() <= 1
			_actions[&"remove"].disabled = saved.slots.size() <= 1


func _build_card(index: int) -> MenuCard:
	var c := MenuCard.new()
	c.name = "Slot_%d" % (index + 1)
	c.custom_minimum_size = Vector2(0.0, HEIGHT)
	var lit := index == saved.current
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", KEY_GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var key := MenuParts.text(str(index + 1), KEY_SIZE, 800, GameTheme.DIM)
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(key)
	var label := MenuParts.spaced(saved.slots[index].name.to_upper(), NAME_SIZE, 700,
			GameTheme.TEXT if lit else GameTheme.MUTED, SPACING)
	label.name = "Name"
	# its width is set once it can be measured (_fit): up to NAME_WIDTH, then "…"
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	_names.append(label)
	var pad := MenuParts.padded(PAD_X, 0, PAD_X, 0)
	pad.add_child(row)
	c.add_content(pad)
	c.set_picked(lit)
	if mode == Mode.REPLACING:
		c.set_greyed(lit)
	c.pressed.connect(_pressed.bind(index))
	return c


func _build_new() -> MenuCard:
	var c := MenuCard.new()
	c.name = "NewLoadout"
	c.custom_minimum_size = Vector2(0.0, HEIGHT)
	var pad := MenuParts.padded(PAD_X, 0, PAD_X, 0)
	var label := MenuParts.spaced(tr("LOADOUT_NEW"), NAME_SIZE, 700, GameTheme.DIM, SPACING)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pad.add_child(label)
	c.add_content(pad)
	# the dashes take the place of the card's own line
	var none := Color(0.0, 0.0, 0.0, 0.0)
	var plain := GameTheme.box(GameTheme.CARD, none, 0, 0)
	GameTheme.dress(c, plain, GameTheme.box(GameTheme.CARD_HI, none, 0, 0), plain)
	c.add_child(Dashes.new())
	c.pressed.connect(_create)
	return c


func _build_edit(text: String) -> LineEdit:
	var e := LineEdit.new()
	e.name = "RenameEdit"
	e.text = text
	e.max_length = SavedLoadouts.NAME_MAX
	e.custom_minimum_size = Vector2(EDIT_WIDTH, HEIGHT)
	e.add_theme_font_override("font", GameTheme.spaced_font(700, SPACING, NAME_SIZE))
	e.add_theme_font_size_override("font_size", NAME_SIZE)
	e.text_submitted.connect(_rename)
	e.gui_input.connect(_edit_input)
	# deferred: a strip freed with its edit still focused must not rebuild itself on the way out
	e.focus_exited.connect(commit, CONNECT_DEFERRED)
	return e


## One Esc in the name field cancels the rename. (The LineEdit would end its own editing on the first Esc and swallow
## it, so cancelling took two.)
func _edit_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		_edit.accept_event()
		cancel()


func _say(key: String, arg: String) -> void:
	_prompt = MenuParts.text(tr(key) % arg if arg != "" else tr(key), NAME_SIZE - 2, 700, GameTheme.YELLOW)
	_prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_prompt)


func _link(id: StringName, key: String, on_press: Callable) -> void:
	var b := Button.new()
	b.name = "Action_%s" % id
	b.theme_type_variation = GameTheme.LINK_UNDERLINED
	b.text = tr(key)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_constant_override("h_separation", 0)
	b.pressed.connect(on_press)
	add_child(b)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(ACTION_GAP, 0.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gap)
	_actions[id] = b


func _pressed(index: int) -> void:
	if mode == Mode.REPLACING:
		saved.replace(index)
		_set_mode(Mode.NORMAL)
	elif mode == Mode.NORMAL:
		saved.use(index)


func _create() -> void:
	saved.create()


func _duplicate() -> void:
	saved.duplicate_slot(saved.current)


func _rename(text: String) -> void:
	if mode != Mode.RENAMING:
		return
	saved.rename(saved.current, text)
	_set_mode(Mode.NORMAL)


## Keeps the name typed so far, if a rename is open: a click elsewhere, a tab change or a match starting leave it so.
## (Esc drops it instead: `cancel`.)
func commit() -> void:
	if is_inside_tree() and mode == Mode.RENAMING and _edit != null:
		_rename(_edit.text)


## Keeps the name typed in an open rename without drawing anything again: for the page being freed, where `commit` may
## do nothing (out of the tree).
func keep_typed() -> void:
	if mode == Mode.RENAMING and is_instance_valid(_edit):
		saved.rename(saved.current, _edit.text)


func _remove_carried() -> void:
	saved.remove(saved.current)
	_set_mode(Mode.NORMAL)


## The dashed outline of the "+ NEW LOADOUT" card (the concept's dashed border), drawn over the card's own line.
class Dashes:
	extends Control

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var w := float(GameTheme.BORDER)
		var half := w * 0.5
		var a := Vector2(half, half)
		var b := Vector2(r.size.x - half, half)
		var c := Vector2(r.size.x - half, r.size.y - half)
		var d := Vector2(half, r.size.y - half)
		for edge: Array in [[a, b], [b, c], [c, d], [d, a]]:
			draw_dashed_line(edge[0], edge[1], GameTheme.LINE, w, LoadoutStrip.DASH)

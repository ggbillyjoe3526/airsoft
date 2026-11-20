class_name LoadoutStrip
extends HBoxContainer
## The saved loadouts strip (concept `.saved`): a card for each saved loadout with its key 1 to 5, the carried one lit,
## then "+ NEW LOADOUT" while there is room. Rename, Duplicate, Replace and Remove are in a menu that opens on a card
## when it is right-clicked (owner, 2026-11-17: they were links on the right), or with the Menu key or Shift+F10 on a
## focused card; the card is carried first, so the menu's actions are on it. Every action is SavedLoadouts'; the strip
## only asks for it. Rename types over the carried one's name, Replace asks which loadout takes the carried one's place
## and Remove asks once more, in a small panel beside the menu (owner, 2026-11-20: it was at the strip's far right),
## each left again with Esc (`cancel`); a click off the Remove panel keeps the loadout too. A Replace can be undone for
## UNDO_SECONDS (BP7): "<name> replaced" and Undo stand where the actions were, until then, a click on a card, Esc or
## any other change.

enum Mode { NORMAL, RENAMING, REPLACING, REMOVING }
## The card's menu's items, in its order.
enum MenuItem { RENAME, DUPLICATE, REPLACE, REMOVE }

const HEIGHT := 56.0
const GAP := 10
const PAD_X := 22
const NAME_SIZE := 18
const KEY_SIZE := 13
const KEY_GAP := 10
const SPACING := 0.04
const ACTION_GAP := 16
const ACTION_PAD := 10
const DASH := 6.0
const EDIT_WIDTH := 260.0
## The room between the card menu and the Remove panel beside it, and between the panel's question and its links (px).
const CONFIRM_GAP := 6
const CONFIRM_ROW_GAP := 10
const CONFIRM_PAD := 12
## How long a Replace's Undo stays offered (s).
const UNDO_SECONDS := 6.0
## The menu's words by MenuItem (translation keys).
const MENU_KEYS: Array[String] = ["LOADOUT_RENAME", "LOADOUT_DUPLICATE", "LOADOUT_REPLACE", "LOADOUT_REMOVE"]
## The most room a loadout's name takes on its card (px): a longer one ends in "…" and the card's tooltip is the whole
## name, so five cards of the longest names and the actions fit the window (UI1).
const NAME_WIDTH := 170.0


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
## Counts Replaces, so a timer left from an earlier one never takes a later one's Undo away.
var _replaces: int = 0
## The card's menu, built on its first opening and kept (it is the strip's child, so it goes with it).
var _menu: PopupMenu = null
## Whether the card menu was last opened from the keyboard (its card keeps the keys after a pick that rebuilds the cards).
var _menu_by_key: bool = false
## Remove's question and its two links, in a panel beside the card menu (the strip's child, built on its first use).
var _confirm: PopupPanel = null
var _confirm_box: VBoxContainer = null


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


## A link the strip shows now (the Remove panel's Remove and Keep, a Replace's Undo).
func action(id: StringName) -> Button:
	return _actions[id]


## Opens the card menu on loadout `index` (carrying it first), `at` from the card's top left (px; the click's point),
## or under the card for the keyboard. Nothing outside the normal mode.
func open_menu(index: int, at: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if mode != Mode.NORMAL or index < 0 or index >= _cards.size() or _cards[index] == null:
		return
	# Carrying the loadout rebuilds the cards, and a new card has no place until it is laid out: the menu's point and
	# the keyboard's focus are taken from the card clicked, before (BP10).
	var clicked := _cards[index]
	var point := at if at.x >= 0.0 else Vector2(0.0, clicked.size.y)
	var screen := Vector2i((clicked.get_screen_position() + point * clicked.get_global_transform_with_canvas().get_scale())
			.round())
	var focused := clicked.has_focus()
	_menu_by_key = at.x < 0.0
	if index != saved.current:
		saved.use(index)
	if saved.undo_index() >= 0:
		saved.forget_undo()
	refresh()
	var c := _cards[index]
	if c == null:
		return
	if focused and not c.has_focus():
		c.grab_focus()
	if _menu == null:
		_menu = PopupMenu.new()
		_menu.name = "LoadoutMenu"
		# Remove leaves the menu up, its question beside it (_menu_picked); every other row shuts it.
		_menu.hide_on_item_selection = false
		for i in MENU_KEYS.size():
			_menu.add_item(tr(MENU_KEYS[i]), i)
		_menu.id_pressed.connect(func(id: int) -> void: _menu_picked(id as MenuItem))
		add_child(_menu, false, Node.INTERNAL_MODE_BACK)
	_menu.set_item_disabled(MenuItem.DUPLICATE, saved.slots.size() >= SavedLoadouts.MAX_SLOTS)
	_menu.set_item_disabled(MenuItem.REPLACE, saved.slots.size() <= 1)
	_menu.set_item_disabled(MenuItem.REMOVE, saved.slots.size() <= 1)
	_menu.reset_size()
	_menu.position = screen
	_menu.popup()


## The card menu (null until it first opens).
func menu() -> PopupMenu:
	return _menu


## The Remove panel (null until Remove is first asked).
func confirm_panel() -> PopupPanel:
	return _confirm


## Whether the menu's `item` can be picked now (for tests: Duplicate with five loadouts, Replace and Remove with one).
func menu_disabled(item: MenuItem) -> bool:
	return _menu != null and _menu.is_item_disabled(item)


## Does what the menu's `item` says, on the carried loadout.
func pick(item: MenuItem) -> void:
	if _menu != null and _menu.is_item_disabled(item):
		return
	match item:
		MenuItem.RENAME:
			start_rename()
		MenuItem.DUPLICATE:
			_duplicate()
		MenuItem.REPLACE:
			start_replace()
		MenuItem.REMOVE:
			start_remove()


## A row of the card menu clicked: Remove keeps the menu up with its question beside it; any other row shuts it first.
func _menu_picked(item: MenuItem) -> void:
	if item != MenuItem.REMOVE or _menu.is_item_disabled(item):
		_menu.hide()
	pick(item)


func edit() -> LineEdit:
	return _edit


## The line that asks what the strip is waiting for ("" in the normal mode).
func prompt_text() -> String:
	return _prompt.text if _prompt != null else ""


## Leaves rename, replace or remove without doing anything, or puts a Replace's Undo away; false if the strip was in
## none of them.
func cancel() -> bool:
	if mode == Mode.NORMAL:
		if saved.undo_index() < 0:
			return false
		saved.forget_undo()
		refresh()
		return true
	_set_mode(Mode.NORMAL)
	return true


## Puts back the loadout the last Replace wrote over (the Undo link).
func undo() -> void:
	saved.undo_replace()
	refresh()


## Rebuilds the cards if the loadouts, the carried one or the mode changed since they were drawn.
func refresh() -> void:
	var sig := "%d|%d|%d|%d|%s" % [saved.current, mode, saved.slots.size(), saved.undo_index(), ",".join(saved.slots.map(
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
			_cards[i].tooltip_text = "%s\n%s" % [saved.slots[i].name, tr("LOADOUT_MENU_TIP")]
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
	if m != Mode.REMOVING:
		_close_confirm()
	if not is_inside_tree():
		return
	if m == Mode.RENAMING and _edit != null:
		_edit.grab_focus()
		_edit.select_all()
	elif m == Mode.REMOVING:
		_show_confirm()
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
			_fill_confirm()
		Mode.RENAMING:
			_say("LOADOUT_RENAME_PROMPT", "")
		_ when saved.undo_index() >= 0:
			_say("LOADOUT_REPLACED", saved.slots[saved.undo_index()].name)
			_link(&"undo", "LOADOUT_UNDO", undo)


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
	c.gui_input.connect(_card_input.bind(index))
	c.tooltip_text = tr("LOADOUT_MENU_TIP")
	return c


## A right click on a card, or the Menu key or Shift+F10 with it focused, opens its menu.
func _card_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		_cards[index].accept_event()
		# deferred: carrying another loadout builds the cards again, this one too
		open_menu.call_deferred(index, click.position)
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_MENU
			or (key.keycode == KEY_F10 and key.shift_pressed)):
		_cards[index].accept_event()
		open_menu.call_deferred(index)


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


func _say(key: String, arg: String, into: Control = self) -> void:
	_prompt = MenuParts.text(tr(key) % arg if arg != "" else tr(key), NAME_SIZE - 2, 700, GameTheme.accent)
	_prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	into.add_child(_prompt)


func _link(id: StringName, key: String, on_press: Callable, into: Control = self) -> void:
	var b := Button.new()
	b.name = "Action_%s" % id
	b.theme_type_variation = GameTheme.LINK_UNDERLINED
	b.text = tr(key)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_constant_override("h_separation", 0)
	b.pressed.connect(on_press)
	into.add_child(b)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(ACTION_GAP, 0.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	into.add_child(gap)
	_actions[id] = b


## Writes Remove's question ("Remove <name>?") and its Remove and Keep links into the Remove panel, building the
## panel on its first use.
func _fill_confirm() -> void:
	if _confirm == null:
		_confirm = PopupPanel.new()
		_confirm.name = "RemoveConfirm"
		_confirm_box = VBoxContainer.new()
		_confirm_box.add_theme_constant_override("separation", CONFIRM_ROW_GAP)
		# room round the words, so the focused link's ring stays inside the panel
		var pad := MenuParts.padded(CONFIRM_PAD, CONFIRM_PAD, CONFIRM_PAD, CONFIRM_PAD)
		pad.add_child(_confirm_box)
		_confirm.add_child(pad)
		# a click off the panel, or Esc in it, shuts it: the loadout is kept
		_confirm.popup_hide.connect(_confirm_closed)
		add_child(_confirm, false, Node.INTERNAL_MODE_BACK)
	for child in _confirm_box.get_children():
		_confirm_box.remove_child(child)
		child.queue_free()
	_say("LOADOUT_REMOVE_PROMPT", saved.carried().name, _confirm_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	_confirm_box.add_child(row)
	_link(&"remove_yes", "LOADOUT_REMOVE_YES", _remove_carried, row)
	_link(&"keep", "LOADOUT_KEEP", cancel, row)


## Pops the Remove panel up beside the card menu, its foot level with the menu's (Remove is the menu's last row): on the
## menu's right, or on its left where the window has no room. With no menu up (Remove asked another way), under the
## carried card.
func _show_confirm() -> void:
	if _confirm == null:
		return
	_confirm.reset_size()
	var size_now := _confirm.size
	var at := Vector2i.ZERO
	if _menu != null and _menu.visible:
		at = Vector2i(_menu.position.x + _menu.size.x + CONFIRM_GAP, _menu.position.y + _menu.size.y - size_now.y)
		if at.x + size_now.x > int(get_viewport_rect().size.x):
			at.x = _menu.position.x - CONFIRM_GAP - size_now.x
	elif saved.current < _cards.size() and _cards[saved.current] != null:
		var c := _cards[saved.current]
		at = Vector2i((c.get_screen_position() + Vector2(0.0, c.size.y) * c.get_global_transform_with_canvas().get_scale())
				.round())
	_confirm.position = at
	_confirm.popup()


## Shuts the Remove panel and the card menu beside it.
func _close_confirm() -> void:
	if _confirm != null and _confirm.visible:
		_confirm.hide()
	if _menu != null and _menu.visible:
		_menu.hide()


## The Remove panel shut by a click off it or Esc: the loadout is kept.
func _confirm_closed() -> void:
	if mode == Mode.REMOVING:
		cancel()
	elif _menu != null and _menu.visible:
		_menu.hide()


func _pressed(index: int) -> void:
	if mode == Mode.REPLACING:
		if saved.replace(index):
			_offer_undo()
		_set_mode(Mode.NORMAL)
		if _actions.has(&"undo"):
			_actions[&"undo"].grab_focus()
	elif mode == Mode.NORMAL:
		saved.use(index)
		# a click on the carried card changes nothing, but puts the Undo away too
		if saved.undo_index() >= 0:
			saved.forget_undo()
			refresh()


## Takes the Undo away UNDO_SECONDS after this Replace, unless another came since.
func _offer_undo() -> void:
	_replaces += 1
	if not is_inside_tree():
		return
	# a method, not a lambda: a strip freed first drops the connection with it
	get_tree().create_timer(UNDO_SECONDS, true).timeout.connect(_undo_expired.bind(_replaces))


func _undo_expired(replace_number: int) -> void:
	if replace_number == _replaces and saved.undo_index() >= 0:
		saved.forget_undo()
		refresh()


func _create() -> void:
	saved.create()


func _duplicate() -> void:
	saved.duplicate_slot(saved.current)
	# The copy rebuilds the cards: a menu opened from the keyboard leaves the keys on the carried card (BP10).
	if _menu_by_key:
		refresh()
		if saved.current >= 0 and saved.current < _cards.size() and _cards[saved.current] != null:
			_cards[saved.current].grab_focus()


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

class_name LoadoutSwitch
extends Control
## SWITCH REPLICA's pop-up on the Loadout page (owner, 2026-11-03: it replaces the SWAP row): over a shade, a panel
## titled with the slot being switched, a line saying that the replica carried in the other slot swaps the two, and a
## card for every replica to carry (the ones carried tagged with their slot, the one in this slot ringed, the ones the
## game can't play yet greyed LATER, the ones not unlocked yet greyed with their level), each drawn at the cards' one
## scale (owner, 2026-10-19: replicas to scale). A card sends `picked` and the pop-up closes; CLOSE, Esc (the page's
## back_out) or a click on the shade closes it with nothing changed. Built once with the page, shown by `open`. While
## it is open the keyboard stays inside it (BP4): Tab or an arrow that would leave it lands back on the card it left.

## A replica card was pressed: its id (the page equips it in the slot being switched).
signal picked(id: String)
## It closed, by a pick or with nothing changed (the page puts the keyboard back on SWITCH REPLICA).
signal closed

## The shade (the page colour, this opaque), the panel's width, its padding and the accent rule on top (px at 1080p).
const SHADE_ALPHA := 0.72
const WIDTH := 1120.0
const PAD := Vector2i(36, 30)
const RULE := 5
## The title's and the note's sizes, the gaps between the parts, and CLOSE's padding.
const TITLE_SIZE := 34
const NOTE_SIZE := 17
const GAP := 14
const GRID_GAP := 12
const CLOSE_SIZE := 16
const CLOSE_PAD := Vector2i(20, 8)
## The cards: how many to a row, each one's height and padding, the picture box the longest replica fits, and the words.
const COLUMNS := 3
const CARD_HEIGHT := 96.0
const CARD_PAD := Vector2(14.0, 10.0)
const LIST_BOX := Vector2(150.0, 64.0)
const NAME_SIZE := 18
const SUB_SIZE := 13
const TEXT_GAP := 3
const TAG_GAP := 6
const PIC_GAP := 14

var _pictures: ReplicaPictures = null
var _facts: LoadoutFacts = null
var _slot: Loadout.Slot = Loadout.Slot.PRIMARY
## Pixels per metre of replica on the cards.
var _scale: float = 1.0
var _title: Label = null
var _close: Button = null
var _cards: Dictionary[String, MenuCard] = {}
var _pics: Dictionary[String, TextureRect] = {}
var _slot_tags: Dictionary[String, Label] = {}
var _rests: Dictionary[String, Label] = {}
## A card's line under its name, and whether it has tags: the line hides when it has neither tags nor a slot, so the name
## sits in the middle.
var _subs: Dictionary[String, HBoxContainer] = {}
## The control inside the pop-up that last had the keyboard, where focus that strays outside comes back to.
var _inside: Control = null
var _tagged: Dictionary[String, bool] = {}


func _init(pictures: ReplicaPictures, facts: LoadoutFacts) -> void:
	name = "LoadoutSwitch"
	_pictures = pictures
	_facts = facts
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(GameTheme.BG, SHADE_ALPHA)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_shade_input)
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
	panel.name = "Panel"
	var box := GameTheme.box(GameTheme.BG, GameTheme.LINE, PAD.x, PAD.y)
	box.border_width_top = 0
	panel.add_theme_stylebox_override("panel", box)
	frame.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", GAP)
	column.add_child(head)
	_title = MenuParts.spaced("", TITLE_SIZE, 800, GameTheme.TEXT, GameTheme.SPACING_TAB)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_close = Button.new()
	_close.name = "Close"
	_close.text = tr("LOADOUT_SWITCH_CLOSE").to_upper()
	SettingsSavePage.paint(_close, GameTheme.CARD_HI, GameTheme.LINE, GameTheme.TEXT, CLOSE_SIZE, CLOSE_PAD)
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close)
	head.add_child(_close)
	var note := MenuParts.text(tr("LOADOUT_SWITCH_NOTE"), NOTE_SIZE, 600, GameTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	var grid := GridContainer.new()
	grid.name = "Replicas"
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GRID_GAP)
	grid.add_theme_constant_override("v_separation", GRID_GAP)
	column.add_child(grid)
	_set_scale()
	var rules := _facts.rules()
	for item in listed(rules):
		var later := rules.config(item) == null
		var lock := rules.unlock_level(item.id) if not later and rules.is_locked(item.id) else -1
		grid.add_child(_card(item, later, lock))


## The replicas to list: the ones a new player carries first (ReplicaStats.DEFAULT_LOADOUT), then the rest in the pool's
## order; dev replicas only with Dev content on. The order stays put as replicas are switched.
static func listed(rules: LoadoutRules) -> Array[Pool.Item]:
	var out: Array[Pool.Item] = []
	for key in ReplicaStats.DEFAULT_LOADOUT:
		var it := rules.pool.replica_by_key(key)
		if it != null and not (it.is_dev() and not rules.dev_content):
			out.append(it)
	for it in rules.pool.replicas:
		if not out.has(it) and not (it.is_dev() and not rules.dev_content):
			out.append(it)
	return out


## The largest extent (m) of the replicas `rules` lists that the game can play, in `pictures` (zero for none): every
## replica on a page is drawn at the scale that lets this one fit its box.
static func longest(pictures: ReplicaPictures, rules: LoadoutRules) -> Vector2:
	var out := Vector2.ZERO
	for item in listed(rules):
		# a replica the game can't play yet has no model to measure (its extent is a stand-in), so it sets no scale
		if rules.config(item) == null:
			continue
		var e := pictures.extent(item.key)
		out = Vector2(maxf(out.x, e.x), maxf(out.y, e.y))
	return out


## Shows the pop-up for switching what is carried in `slot`, the keyboard on the card carried there.
func open(slot: Loadout.Slot) -> void:
	_slot = slot
	_title.text = (tr("LOADOUT_SWITCH_TITLE") % tr(LoadoutFacts.SLOT_KEYS[slot])).to_upper()
	visible = true
	for id: String in _cards:
		_cards[id].set_picked(_facts.slot_of(id) == int(slot))
	var here := _cards.get(_facts.item(slot).id if _facts.has(slot) else "") as MenuCard
	if not is_inside_tree():
		return
	_inside = here if here != null else _close
	_inside.grab_focus()
	var focus := get_viewport().gui_focus_changed
	if not focus.is_connected(_on_focus_changed):
		focus.connect(_on_focus_changed)


## Hides it with nothing changed.
func close() -> void:
	var was_open := visible
	visible = false
	_inside = null
	if is_inside_tree() and get_viewport().gui_focus_changed.is_connected(_on_focus_changed):
		get_viewport().gui_focus_changed.disconnect(_on_focus_changed)
	if was_open:
		closed.emit()


func _exit_tree() -> void:
	if get_viewport().gui_focus_changed.is_connected(_on_focus_changed):
		get_viewport().gui_focus_changed.disconnect(_on_focus_changed)


## The keyboard moved: inside the pop-up it is remembered; anywhere else (a control hidden behind the shade) it is
## sent back, so Enter never acts on something unseen.
func _on_focus_changed(to: Control) -> void:
	if not visible:
		return
	if is_ancestor_of(to):
		_inside = to
		return
	var back := _inside if is_instance_valid(_inside) and _inside.is_visible_in_tree() else _close
	back.grab_focus.call_deferred()


func slot() -> Loadout.Slot:
	return _slot


func close_button() -> Button:
	return _close


func card(id: String) -> MenuCard:
	return _cards.get(id)


func picture(id: String) -> TextureRect:
	return _pics[id]


func ids() -> PackedStringArray:
	return PackedStringArray(_cards.keys())


## Shows each card as the carried loadout stands, the paints named as the Realistic colours switch says.
func refresh(realistic: bool) -> void:
	var f := _facts
	_set_scale()
	for id: String in _cards:
		var item := f.pool().item(id)
		var t := f.rules().tune_of(f.saved.carried(), id)
		_pics[id].texture = _pictures.texture(item.key, t.paint, realistic, f.fitted_keys(item))
		_pics[id].custom_minimum_size = _size_of(item)
		var carried_in := f.slot_of(id)
		_cards[id].set_picked(visible and carried_in == int(_slot))
		_slot_tags[id].visible = carried_in >= 0
		_subs[id].visible = carried_in >= 0 or _tagged[id]
		if carried_in >= 0:
			_slot_tags[id].text = tr(LoadoutFacts.SLOT_KEYS[carried_in])
		var config := f.rules().config(item)
		if config != null:
			var rest := tr("LOADOUT_REPLICA_SUB") % [_class_word(config.site_class),
					LoadoutPerformance.rate_text(config.fire_rate)]
			_rests[id].text = (" · " + rest) if carried_in >= 0 else rest
		elif carried_in < 0:
			_rests[id].text = tr("LOADOUT_COMES_WITH_LEVELS") % _class_word(_site_class(item))
		_cards[id].tooltip_text = _rests[id].text.trim_prefix(" · ")


## The cards' one scale: the longest replica listed fills the picture box (and none is taller than it).
func _set_scale() -> void:
	var e := longest(_pictures, _facts.rules())
	if e != Vector2.ZERO:
		_scale = minf(LIST_BOX.x / e.x, LIST_BOX.y / e.y)


## A replica's picture size on its card: at the cards' scale, and never past the box (a replica the game can't play yet
## has only a stand-in extent, so it is fitted to the box instead).
func _size_of(item: Pool.Item) -> Vector2:
	var want := _pictures.extent(item.key) * _scale
	var fit := minf(1.0, minf(LIST_BOX.x / want.x, LIST_BOX.y / want.y)) if want.x > 0.0 and want.y > 0.0 else 1.0
	return want * fit


## A replica's card; `lock_level` >= 0: not unlocked yet, greyed with the level that unlocks it.
func _card(item: Pool.Item, later: bool, lock_level: int) -> MenuCard:
	var c := MenuCard.new()
	c.name = "Replica_%s" % item.id
	c.ring = true
	c.custom_minimum_size = Vector2(0.0, CARD_HEIGHT)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MenuParts.padded(CARD_PAD.x, CARD_PAD.y, CARD_PAD.x, CARD_PAD.y)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PIC_GAP)
	var stage := CenterContainer.new()
	stage.custom_minimum_size = Vector2(LIST_BOX.x, 0.0)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := MenuParts.picture(_size_of(item))
	stage.add_child(pic)
	row.add_child(stage)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", TEXT_GAP)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var item_name := MenuParts.text(item.display_name, NAME_SIZE, 700, GameTheme.TEXT)
	item_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(item_name)
	# under the name: the slot it is carried in, or its tags (LATER, the level that unlocks it, DEV)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", TAG_GAP)
	if later:
		sub.add_child(MenuTag.later())
	if lock_level >= 0:
		sub.add_child(MenuTag.level(lock_level))
	if item.is_dev():
		sub.add_child(MenuTag.dev())
	_subs[item.id] = sub
	_tagged[item.id] = sub.get_child_count() > 0
	var slot_tag := MenuParts.text("", SUB_SIZE, 700, GameTheme.ACCENT)
	# the class and fire rate: the card's tooltip, not a line cut short
	var rest := MenuParts.text("", SUB_SIZE, 500, GameTheme.MUTED)
	rest.visible = false
	sub.add_child(slot_tag)
	sub.add_child(rest)
	text.add_child(sub)
	row.add_child(text)
	pad.add_child(row)
	c.add_content(pad)
	c.set_greyed(later or lock_level >= 0)
	c.pressed.connect(_on_card.bind(item.id))
	_cards[item.id] = c
	_pics[item.id] = pic
	_slot_tags[item.id] = slot_tag
	_rests[item.id] = rest
	return c


func _on_card(id: String) -> void:
	close()
	picked.emit(id)


## A click on the shade outside the panel closes it.
func _on_shade_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		close()
		accept_event()


func _class_word(site_class: StringName) -> String:
	return tr("LOADOUT_CLASS_" + String(site_class).to_upper())


## The class a replica the game can't play yet belongs to: from its pool tags.
func _site_class(item: Pool.Item) -> StringName:
	return &"pistol" if item.tags.has("pistol") else &"rifle"

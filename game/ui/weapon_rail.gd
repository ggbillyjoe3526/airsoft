class_name WeaponRail
extends VBoxContainer
## The weapon rail above the ammo panel, as Valorant and Counter-Strike list what you carry (BP8): a row per replica in
## its slot (its picture from its own model, ReplicaPictures) and per bomb kind carried (GrenadeGlyph: one icon per
## bomb, two side by side for two, no numbers, straight on the row with no plate of their own), and at the right of
## each row the key that takes it in hand (read once, when the rail is built). The one in hand has an accent edge and
## full brightness; the rest are dim, a bomb with none left dimmer. Nothing is lit while the replica is holstered. No
## names. Rows are rebuilt only when what is lit or carried changes. Carrying Plant The Bomb's bomb (PB3, the owner's
## ask) adds its row at the foot, its picture from its model and the Use key that sets it; the row is lit while it is
## being set down and armed.

## A row's plate (px at 1080p): the picture's box, the key's width and size, the gap between rows and inside one.
const ICON_SIZE := Vector2(112.0, 44.0)
const BOMB_ICON := 44.0
const KEY_WIDTH := 16.0
const KEY_SIZE := 14
## Most icons a bomb row shows side by side.
const BOMB_ICONS_MAX := 2
const ROW_GAP := 8
const INNER_GAP := 6
const PLATE_PAD := Vector2i(8, 5)
## The replicas' pictures are drawn this many px on their longer side (drawn once each).
const PICTURE_SIDE := 256
## A dim row's opacity, and a bomb with none left's.
const DIM_ALPHA := 0.6
const EMPTY_ALPHA := 0.25
## The input action that takes each row in hand: the replica slots, then the bombs (Grenade.Kind order from SMOKE).
const SLOT_ACTIONS: Array[StringName] = [&"slot_1", &"slot_2"]
const BOMB_ACTIONS: Array[StringName] = [&"throw_smoke", &"throw_flash"]
## Plant The Bomb's bomb on the one watched: none, carried, or being set down and armed (its row lit).
enum Carry { NONE, CARRIED, SETTING }

var _pictures: ReplicaPictures = null
var _plates: Array[PanelContainer] = []
var _icons: Array[Control] = []
## Each row's key label and the input it names, so a rebind mid-match relabels them (refresh_keys).
var _keys: Array[Label] = []
var _actions: Array[StringName] = []
## Each bomb kind's icons (Grenade.Kind order from SMOKE), BOMB_ICONS_MAX of them, the first n shown for n carried.
var _glyphs: Array = []
var _lit_box: StyleBoxFlat = null
var _dim_box: StyleBoxFlat = null
## Rows: the replica slots first, then SMOKE and FLASH. What is lit now (-1: none) and how many of each bomb is left.
var _slots: int = 0
var _shown_lit: int = -2
var _shown_left: PackedInt32Array = PackedInt32Array()
## The most of each bomb kind seen carried: a kind never carried has no row (a loadout with 2 smoke and no flash shows
## the smoke row, two icons, and no flash row); one carried and thrown stays, dim at 0.
var _carried: PackedInt32Array = PackedInt32Array()
## Plant The Bomb's bomb's row (after the bombs'; -1: none built) and what it shows now.
var _bomb_row: int = -1
var _shown_carry: Carry = Carry.NONE


## Builds a row per replica in `replicas` (drawn in `paints`, one per slot) and one per bomb kind.
func setup(replicas: Array[ReplicaConfig], paints: Array[StringName], realistic: bool = false) -> void:
	name = "WeaponRail"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", ROW_GAP)
	_pictures = ReplicaPictures.new()
	_pictures.name = "Pictures"
	_pictures.replica_side = PICTURE_SIDE
	add_child(_pictures)
	_lit_box = HudStyle.dark_box(HudStyle.BACKING_PANEL, GameTheme.ACCENT, PLATE_PAD.x, PLATE_PAD.y)
	_dim_box = HudStyle.dark_box(HudStyle.BACKING_PANEL, Color(0.0, 0.0, 0.0, 0.0), PLATE_PAD.x, PLATE_PAD.y)
	_slots = mini(replicas.size(), SLOT_ACTIONS.size())
	_shown_left.resize(BOMB_ACTIONS.size())
	_shown_left.fill(-1)
	_carried.resize(BOMB_ACTIONS.size())
	_carried.fill(0)
	for i in _slots:
		var picture := TextureRect.new()
		picture.custom_minimum_size = ICON_SIZE
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var paint := paints[i] if i < paints.size() else &""
		picture.texture = _pictures.texture(replicas[i].id, paint, realistic)
		_row(SLOT_ACTIONS[i], picture)
	for kind in BOMB_ACTIONS.size():
		var side := HBoxContainer.new()
		side.mouse_filter = Control.MOUSE_FILTER_IGNORE
		side.alignment = BoxContainer.ALIGNMENT_CENTER
		side.add_theme_constant_override("separation", INNER_GAP)
		var glyphs: Array[GrenadeGlyph] = []
		for n in BOMB_ICONS_MAX:
			var glyph := GrenadeGlyph.new(Grenade.Kind.SMOKE + kind, BOMB_ICON)
			glyph.shared_pictures = _pictures # one set of pictures for the whole rail
			side.add_child(glyph)
			glyphs.append(glyph)
		_glyphs.append(glyphs)
		_row(BOMB_ACTIONS[kind], side)
	var bomb := TextureRect.new()
	bomb.custom_minimum_size = ICON_SIZE
	bomb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bomb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bomb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bomb.texture = _pictures.bomb_texture(PICTURE_SIDE)
	_bomb_row = _plates.size()
	_row(PlayerInput.USE_DOOR, bomb)
	_plates[_bomb_row].visible = false


func _row(action: StringName, icon: Control) -> void:
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# one width for every row, so the rail is a tidy column
	plate.size_flags_horizontal = Control.SIZE_FILL
	plate.add_theme_stylebox_override("panel", _dim_box)
	add_child(plate)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", INNER_GAP)
	plate.add_child(row)
	# the icon centred in the room the key leaves, the key at the right
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = ICON_SIZE
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(holder)
	holder.add_child(icon)
	var key := HudStyle.label(row, KEY_SIZE, 800, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	key.text = key_text(action)
	key.custom_minimum_size.x = KEY_WIDTH
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_keys.append(key)
	_actions.append(action)
	_plates.append(plate)
	_icons.append(icon)


## Every row's key label read again: after the pause menu's settings may have rebound one (PP1).
func refresh_keys() -> void:
	for i in _keys.size():
		_keys[i].text = key_text(_actions[i])


## The key that fires input `action`, as its label ("1"; a rebind shows); a dash with none bound.
static func key_text(action: StringName) -> String:
	return KeyNames.of_action(action)


## The row in hand (replica slots first, then the bombs, then Plant The Bomb's), or -1 for none: Plant The Bomb's bomb
## being set, a bomb in hand, else the replica unless it is holstered.
static func lit_row(a: Armament, hand: Grenades.Hand, slots: int, carry: Carry = Carry.NONE) -> int:
	if carry == Carry.SETTING:
		return slots + BOMB_ACTIONS.size()
	if hand != null and hand.readied != Grenade.Kind.NONE:
		return slots + hand.readied - Grenade.Kind.SMOKE
	if a.holstered or a.active < 0 or a.active >= slots:
		return -1
	return a.active


## Follows what is in hand, the bombs left and Plant The Bomb's bomb (`carry`), rebuilding a row only on a change.
func refresh(a: Armament, hand: Grenades.Hand = null, carry: Carry = Carry.NONE) -> void:
	var lit := lit_row(a, hand, _slots, carry)
	var changed := lit != _shown_lit or carry != _shown_carry
	for kind in BOMB_ACTIONS.size():
		var left := hand.left(Grenade.Kind.SMOKE + kind) if hand != null else 0
		_carried[kind] = maxi(_carried[kind], left)
		changed = changed or left != _shown_left[kind]
		_shown_left[kind] = left
	if not changed:
		return
	_shown_lit = lit
	_shown_carry = carry
	for i in _plates.size():
		var on := i == lit
		var left := -1
		if i == _bomb_row:
			_plates[i].visible = carry != Carry.NONE
		elif i >= _slots:
			left = _shown_left[i - _slots]
			_plates[i].visible = _carried[i - _slots] > 0
			# one icon per bomb carried (up to the row's room); a spent kind keeps one, dim
			for n in BOMB_ICONS_MAX:
				(_glyphs[i - _slots][n] as Control).visible = n < maxi(left, 1)
		_plates[i].add_theme_stylebox_override("panel", _lit_box if on else _dim_box)
		var alpha := 1.0 if on else DIM_ALPHA
		if left == 0:
			alpha = EMPTY_ALPHA
		# self_modulate, not modulate: the panel's icons keep their own alpha (HudStyle.restyle fades backgrounds only).
		_icons[i].self_modulate.a = alpha
		if i >= _slots and i != _bomb_row:
			for n in BOMB_ICONS_MAX:
				(_glyphs[i - _slots][n] as Control).self_modulate.a = alpha


## Whether Plant The Bomb's bomb's row shows (for tests).
func bomb_shown() -> bool:
	return _bomb_row >= 0 and _plates[_bomb_row].visible


## How many rows are showing (a bomb kind never carried has none), for tests, and the row now lit.
func rows() -> int:
	var n := 0
	for p in _plates:
		if p.visible:
			n += 1
	return n


func lit() -> int:
	return _shown_lit

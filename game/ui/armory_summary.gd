class_name ArmorySummary
extends VBoxContainer
## The Armory's left column (concept armory.png): your level of the cap with the XP bar, what the next level takes, the XP
## earned in all and how much is unlocked; the next unlock with its picture; and how XP is earned with the difficulty
## multipliers. With levelling off it says everything is unlocked, and at the cap that XP stops counting. Built from
## ArmoryFacts once; the page is built again when the level changes.

const GAP := 18
const PANEL_PAD := Vector2i(24, 22)
const BIG_SIZE := 64
const OFF_SIZE := 48
const OF_SIZE := 20
const OF_GAP := 14
const BAR_GAP := Vector2i(14, 10)
const ROW_SIZE := 17
const FACT_SIZE := 15
const FACT_GAP := 18
const NEXT_PICTURE := Vector2(170.0, 90.0)
const NEXT_PICTURE_MAX := Vector2(160.0, 70.0)
const NEXT_HEAD_SIZE := 15
const NEXT_NAME_SIZE := 30
const NEXT_NOTE_SIZE := 15
const NEXT_COLUMN_GAP := 12
const EARN_ROW_HEIGHT := 32
## The XP a typical first-to-5 win on Normal gives, in levels.md's pace note ("about 250 XP").
const TYPICAL_WIN_XP := 250
const MULTIPLIER_SEPARATOR := " · "

var _facts: ArmoryFacts = null
var _pictures: ItemPictures = null
var _bar: XpBar = null


func _init(facts: ArmoryFacts, pictures: ItemPictures) -> void:
	name = "ArmorySummary"
	_facts = facts
	_pictures = pictures
	add_theme_constant_override("separation", GAP)
	add_child(_level_panel())
	add_child(_next_panel())
	add_child(_earn_panel())


func bar() -> XpBar:
	return _bar


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.PANEL, GameTheme.LINE, PANEL_PAD.x, PANEL_PAD.y))
	return p


func _level_panel() -> Control:
	var panel := _panel()
	panel.name = "LevelPanel"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var s := _facts.standing()
	if _facts.levelling_off:
		column.add_child(MenuParts.spaced(tr("ARMORY_OFF_BIG"), OFF_SIZE, 800, GameTheme.TEXT, GameTheme.SPACING_TAB))
		var note := MenuParts.text(tr("ARMORY_OFF_NOTE") % _facts.level, ROW_SIZE, 600, GameTheme.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(_gapped(note, BAR_GAP.x, 0))
	else:
		column.add_child(_level_line(s))
		_bar = XpBar.new()
		_bar.set_fraction(1.0 if s.at_cap() else float(s.into) / float(s.next))
		column.add_child(_gapped(_bar, BAR_GAP.x, BAR_GAP.y))
		column.add_child(_xp_row(s))
	column.add_child(_gapped(_facts_row(), BAR_GAP.x, 0))
	return panel


## "LEVEL 3 of 10": the level in yellow, the cap small after it.
func _level_line(s: LevelTable.Standing) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", OF_GAP)
	var big := HBoxContainer.new()
	big.add_theme_constant_override("separation", 0)
	big.add_child(MenuParts.spaced(tr("ARMORY_LEVEL") + " ", BIG_SIZE, 800, GameTheme.TEXT, 0.02))
	big.add_child(MenuParts.spaced(str(s.level), BIG_SIZE, 800, GameTheme.ACCENT, 0.02))
	row.add_child(big)
	var of := MenuParts.text(tr("ARMORY_OF") % _facts.table.cap(), OF_SIZE, 700, GameTheme.MUTED)
	of.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(of)
	return row


## "120 / 500 XP" and "380 XP to level 4" (at the cap: that XP stops counting).
func _xp_row(s: LevelTable.Standing) -> Control:
	var row := HBoxContainer.new()
	var left := MenuParts.text(tr("ARMORY_XP_INTO") % [ArmoryFacts.grouped(s.into), ArmoryFacts.grouped(s.next)]
			if not s.at_cap() else tr("ARMORY_CAP_LEFT"), ROW_SIZE, 700, GameTheme.TEXT)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)
	var right := MenuParts.text(tr("ARMORY_XP_TO_NEXT") % [ArmoryFacts.grouped(s.next - s.into), s.level + 1]
			if not s.at_cap() else tr("ARMORY_CAP_RIGHT"), ROW_SIZE, 700, GameTheme.MUTED)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(right)
	return row


## "920 XP earned in all" and "9 / 19 unlocked".
func _facts_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", FACT_GAP)
	row.add_child(_fact(ArmoryFacts.grouped(_facts.xp), tr("ARMORY_FACT_XP")))
	row.add_child(_fact("%d / %d" % [_facts.unlocked_count, _facts.item_count], tr("ARMORY_FACT_UNLOCKED")))
	return row


func _fact(figure: String, words: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(MenuParts.text(figure, FACT_SIZE, 700, GameTheme.TEXT))
	row.add_child(MenuParts.text(words, FACT_SIZE, 600, GameTheme.MUTED))
	return row


func _next_panel() -> Control:
	var panel := _panel()
	panel.name = "NextPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", NEXT_COLUMN_GAP)
	panel.add_child(row)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 6)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	var next := _facts.next_row()
	if next == null:
		text.add_child(MenuParts.spaced(tr("ARMORY_NEXT"), NEXT_HEAD_SIZE, 800, GameTheme.MUTED, 0.1))
		text.add_child(MenuParts.text(tr("ARMORY_NEXT_NONE"), NEXT_NAME_SIZE, 800, GameTheme.TEXT))
		text.add_child(_note(tr("ARMORY_NEXT_OFF") if _facts.levelling_off else tr("ARMORY_NEXT_NONE_NOTE")))
		return panel
	var first := next.items[0]
	text.add_child(MenuParts.spaced(tr("ARMORY_NEXT_LEVEL") % next.number, NEXT_HEAD_SIZE, 800, GameTheme.MUTED, 0.1))
	text.add_child(MenuParts.text(first.display_name, NEXT_NAME_SIZE, 800, GameTheme.TEXT))
	var words := ArmoryFacts.blurb(first)
	if next.items.size() > 1:
		var others := PackedStringArray()
		for it: Pool.Item in next.items.slice(1):
			others.append(it.display_name)
		words += " " + tr("ARMORY_NEXT_ALSO") % ", ".join(others)
	text.add_child(_note(words))
	row.add_child(_picture(first))
	return panel


func _note(words: String) -> Label:
	var l := MenuParts.text(words, NEXT_NOTE_SIZE, 600, GameTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## The item's picture in a glow, at most NEXT_PICTURE_MAX.
func _picture(item: Pool.Item) -> Control:
	var box := Control.new()
	box.custom_minimum_size = NEXT_PICTURE
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var glow := TextureRect.new()
	glow.texture = MenuParts.glow(GameTheme.PANEL)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(glow)
	var pic := MenuParts.picture()
	pic.name = "NextPicture"
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE,
			roundi((NEXT_PICTURE.y - NEXT_PICTURE_MAX.y) * 0.5))
	pic.texture = _pictures.texture(item)
	box.add_child(pic)
	return box


func _earn_panel() -> Control:
	var panel := _panel()
	panel.name = "EarnPanel"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	column.add_child(_gapped(MenuParts.heading(tr("ARMORY_EARN_HEAD")), 0, MenuParts.HEADING_GAP))
	var earn := _facts.table.earn
	column.add_child(_earn_row(tr("ARMORY_EARN_MATCH"), tr("ARMORY_EARN_XP") % earn[&"match_played"]))
	column.add_child(_earn_row(tr("ARMORY_EARN_WIN"), tr("ARMORY_EARN_MORE") % earn[&"match_won"]))
	column.add_child(_earn_row(tr("ARMORY_EARN_ROUND"), str(earn[&"round_won"])))
	column.add_child(_earn_row(tr("ARMORY_EARN_HIT"), str(earn[&"hit"])))
	var multipliers := PackedStringArray()
	for level in MatchOptions.BOT_LEVELS:
		multipliers.append(tr("ARMORY_MULTIPLIER") % [tr("BOT_" + level.to_upper()),
				ArmoryFacts.multiplier_text(_facts.table.multiplier(StringName(level)))])
	# one row of the multipliers; the rest of what it means is the row's tooltip (UI1 round 3: no paragraph)
	var difficulty := _earn_row(tr("ARMORY_EARN_DIFFICULTY"), MULTIPLIER_SEPARATOR.join(multipliers))
	difficulty.name = "Difficulty"
	difficulty.tooltip_text = tr("ARMORY_EARN_NOTE") % [MULTIPLIER_SEPARATOR.join(multipliers), TYPICAL_WIN_XP]
	difficulty.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(difficulty)
	return panel


func _earn_row(what: String, xp: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, EARN_ROW_HEIGHT)
	var left := MenuParts.text(what, ROW_SIZE, 600, GameTheme.TEXT)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)
	var right := MenuParts.text(xp, ROW_SIZE, 800, GameTheme.TEXT)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	return row


## `c` with `above` and `below` px of room round it.
func _gapped(c: Control, above: int, below: int) -> Control:
	var m := MenuParts.padded(0.0, above, 0.0, below)
	m.add_child(c)
	return m

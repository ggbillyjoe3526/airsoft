class_name XpCard
extends PanelContainer
## The XP a finished match gave, under the win banner (concept step11-armory/over.png): each line (match played, match won,
## rounds won, hits, the difficulty's multiplier), the total, a level-up card naming what it unlocked with its picture, and
## the XP bar with what the next level takes. A match that gave none says why. Everything it makes (and the pictures it
## draws) goes with it; the HUD frees it when the next match starts.

const WIDTH := 560.0
const PAD := Vector2i(26, 20)
const LINE_HEIGHT := 30
const LINE_SIZE := 17
const TOTAL_SIZE := 24
const TOTAL_GAP := Vector2i(8, 10)
const UP_GAP := 14
const UP_PAD := Vector2i(16, 10)
const UP_NAME_SIZE := 26
const UP_NOTE_SIZE := 15
const UP_PICTURE := Vector2(120.0, 50.0)
## The most pictures a level-up card shows (a jump over several levels can unlock more).
const UP_PICTURES_MAX := 3
const BAR_GAP := 12
const BAR_ROW_SIZE := 15
const BACKING := 0.9

var _progress: Progress = null
var _pool: Pool = null
var _pictures: ReplicaPictures = null


## The card for `settled` (what PlayerTally.settle returned), with `progress` as it stands now.
func _init(settled: PlayerTally.Settled, progress: Progress, pool: Pool) -> void:
	name = "XpCard"
	_progress = progress
	_pool = pool
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0.0)
	add_theme_stylebox_override("panel", HudStyle.navy_box(BACKING, GameTheme.LINE, PAD.x, PAD.y))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	if settled.earned == null:
		var why := MenuParts.text(tr(settled.why_none), LINE_SIZE, 600, GameTheme.MUTED)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(why)
		return
	for l in settled.earned.lines:
		column.add_child(_line(_line_words(l), str(l.xp)))
	column.add_child(_line(_multiplier_words(settled.earned),
			tr("XP_MULTIPLIER") % ArmoryFacts.multiplier_text(settled.earned.multiplier)))
	column.add_child(_total(settled.earned.total))
	var up := settled.level_up
	if up != null and up.to > up.from:
		column.add_child(_level_up(up))
	column.add_child(_bar())


func pictures() -> ReplicaPictures:
	return _pictures


## The multiplier's line names the row it came from: "Hard bots", "Easy teammates" or "Custom rules".
func _multiplier_words(e: MatchXp.Earned) -> String:
	if e.multiplier_from == MatchXp.FROM_CUSTOM:
		return tr("XP_LINE_CUSTOM")
	var level := tr("BOT_" + String(e.multiplier_level).to_upper())
	if e.multiplier_from == MatchXp.FROM_TEAMMATES:
		return tr("XP_LINE_DIFFICULTY_MATES") % level
	return tr("XP_LINE_DIFFICULTY") % level


## "Match played", "Rounds won · 5 × 20" (an uneven share says just the count).
func _line_words(l: MatchXp.Line) -> String:
	var key := "XP_LINE_" + String(l.key).to_upper()
	if l.key == &"match_played" or l.key == &"match_won":
		return tr(key)
	if l.xp % l.count == 0:
		return tr(key) % [l.count, l.xp / l.count]
	return tr(key + "_COUNT") % l.count


func _line(left: String, right: String) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0.0, LINE_HEIGHT)
	var a := MenuParts.text(left, LINE_SIZE, 600, GameTheme.MUTED)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(a)
	var b := MenuParts.text(right, LINE_SIZE, 800, GameTheme.TEXT)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	return row


## A rule, then "XP EARNED" and the total in yellow.
func _total(total: int) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	var rule := ColorRect.new()
	rule.color = GameTheme.LINE
	rule.custom_minimum_size = Vector2(0.0, GameTheme.BORDER)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := MenuParts.padded(0.0, TOTAL_GAP.x, 0.0, 0.0)
	pad.add_child(rule)
	box.add_child(pad)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := MenuParts.text(tr("XP_EARNED"), TOTAL_SIZE, 800, GameTheme.TEXT)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	row.add_child(MenuParts.text(tr("XP_TOTAL") % total, TOTAL_SIZE, 800, GameTheme.YELLOW))
	var below := MenuParts.padded(0.0, TOTAL_GAP.y, 0.0, 0.0)
	below.add_child(row)
	box.add_child(below)
	return box


## "LEVEL 4!", "Unlocked: Silencer" and the picture of what it unlocked.
func _level_up(up: Progress.LevelUp) -> Control:
	var items: Array[Pool.Item] = []
	for id in up.unlocked:
		var it := _pool.item(id)
		if it != null:
			items.append(it)
	var panel := PanelContainer.new()
	panel.name = "LevelUp"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.CARD_HI, GameTheme.YELLOW, UP_PAD.x, UP_PAD.y))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_child(MenuParts.text(tr("XP_LEVEL_UP") % up.to, UP_NAME_SIZE, 800, GameTheme.YELLOW))
	if not items.is_empty():
		var names := PackedStringArray()
		for it in items:
			names.append(it.display_name)
		var note := MenuParts.text(tr("XP_UNLOCKED") % ", ".join(names), UP_NOTE_SIZE, 700, GameTheme.TEXT)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(note)
	row.add_child(text)
	if not items.is_empty():
		row.add_child(_pictures_of(items))
	var gap := MenuParts.padded(0.0, UP_GAP, 0.0, 0.0)
	gap.add_child(panel)
	return gap


## The unlocked items' pictures side by side in UP_PICTURE between them.
func _pictures_of(items: Array[Pool.Item]) -> Control:
	_pictures = ReplicaPictures.new()
	_pictures.name = "Pictures"
	_pictures.replica_side = ReplicaPictures.PART_LONG_SIDE
	add_child(_pictures)
	var draw := ItemPictures.new(_pool, _pictures)
	var shown := mini(items.size(), UP_PICTURES_MAX)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 0)
	for i in shown:
		var pic := MenuParts.picture(Vector2(UP_PICTURE.x / shown, UP_PICTURE.y))
		pic.texture = draw.texture(items[i])
		row.add_child(pic)
	return row


## The bar to the next level and what that takes (at the top level: that XP stops counting).
func _bar() -> Control:
	var s := _progress.standing()
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	var bar := XpBar.new()
	bar.set_fraction(1.0 if s.at_cap() else float(s.into) / float(s.next))
	var pad := MenuParts.padded(0.0, BAR_GAP, 0.0, BAR_GAP - 2.0)
	pad.add_child(bar)
	box.add_child(pad)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := MenuParts.text(tr("ARMORY_XP_INTO") % [ArmoryFacts.grouped(s.into), ArmoryFacts.grouped(s.next)]
			if not s.at_cap() else tr("ARMORY_CAP_LEFT"), BAR_ROW_SIZE, 700, GameTheme.TEXT)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var right := MenuParts.text(tr("ARMORY_XP_TO_NEXT") % [ArmoryFacts.grouped(s.next - s.into), s.level + 1]
			if not s.at_cap() else tr("ARMORY_CAP_RIGHT"), BAR_ROW_SIZE, 700, GameTheme.MUTED)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(right)
	box.add_child(row)
	return box

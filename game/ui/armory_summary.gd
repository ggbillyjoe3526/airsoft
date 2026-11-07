class_name ArmorySummary
extends PanelContainer
## The Armory's level panel (UI concept B v2 `armory.png`): LEVEL n large with the XP into the next level and what is
## unlocked beside it, how XP is earned at the right (the difficulty's note its tooltip), and the level track under them
## (ArmoryDots). With levelling off it says everything is unlocked, and at the cap that XP stops counting. Built from
## ArmoryFacts once; the page is built again when the level changes.

const PAD := Vector2i(30, 24)
const ROW_GAP := 18
const BIG_SIZE := 88
const OFF_SIZE := 64
const BIG_GAP := 18
const LINE_SIZE := 18
const FACT_SIZE := 15
const LINE_GAP := 4
const EARN_SIZE := 15
const JOIN := " · "

var _facts: ArmoryFacts = null
var _dots: ArmoryDots = null
var _earn: Label = null


func _init(facts: ArmoryFacts) -> void:
	name = "ArmorySummary"
	_facts = facts
	add_theme_stylebox_override("panel", GameTheme.panel_box(PAD.x, PAD.y))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", BIG_GAP)
	column.add_child(top)
	var s := _facts.standing()
	if _facts.levelling_off:
		top.add_child(MenuParts.head_text(tr("ARMORY_OFF_BIG"), OFF_SIZE, 700, GameTheme.TEXT, 0.02))
		var note := MenuParts.text(tr("ARMORY_OFF_NOTE") % _facts.level, LINE_SIZE, 500, GameTheme.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(note)
	else:
		var big := MenuParts.head_text("%s %d" % [tr("ARMORY_LEVEL"), s.level], BIG_SIZE, 700, GameTheme.TEXT, 0.02)
		big.name = "Level"
		top.add_child(big)
		top.add_child(_lines(s))
	top.add_child(_earn_line())
	var reached := _facts.table.cap() if _facts.levelling_off else s.level
	_dots = ArmoryDots.new(_facts.rows.size(), reached,
			0.0 if _facts.levelling_off or s.at_cap() else float(s.into) / float(s.next))
	column.add_child(_dots)


## The level track: its dots and how far into the next level.
func bar() -> ArmoryDots:
	return _dots


## How XP is earned, the line at the right; the difficulty's note is its tooltip.
func earn_line() -> Label:
	return _earn


## "120 / 500 XP · 380 XP to level 4" over "920 XP earned in all · 10 / 20 unlocked" (at the cap: that XP stops counting).
func _lines(s: LevelTable.Standing) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", LINE_GAP)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var xp := PackedStringArray()
	if s.at_cap():
		xp.append_array([tr("ARMORY_CAP_LEFT"), tr("ARMORY_CAP_RIGHT")])
	else:
		xp.append(tr("ARMORY_XP_INTO") % [ArmoryFacts.grouped(s.into), ArmoryFacts.grouped(s.next)])
		xp.append(tr("ARMORY_XP_TO_NEXT") % [ArmoryFacts.grouped(s.next - s.into), s.level + 1])
	var line := MenuParts.text(JOIN.join(xp), LINE_SIZE, 600, GameTheme.TEXT)
	line.name = "XpLine"
	column.add_child(line)
	var facts := MenuParts.text(JOIN.join(PackedStringArray([
			"%s %s" % [ArmoryFacts.grouped(_facts.xp), tr("ARMORY_FACT_XP")],
			"%d / %d %s" % [_facts.unlocked_count, _facts.item_count, tr("ARMORY_FACT_UNLOCKED")]])), FACT_SIZE, 500,
			GameTheme.MUTED)
	facts.name = "FactsLine"
	column.add_child(facts)
	return column


## "Every match 100 XP · a win +100 · round won 20 · hit 10 · Easy ×0.5 · Normal ×1 · Hard ×1.5"; what the multipliers mean
## is its tooltip.
func _earn_line() -> Label:
	var earn := _facts.table.earn
	var multipliers := PackedStringArray()
	for level in MatchOptions.BOT_LEVELS:
		multipliers.append(tr("ARMORY_MULTIPLIER") % [tr("BOT_" + level.to_upper()),
				ArmoryFacts.multiplier_text(_facts.table.multiplier(StringName(level)))])
	var words := tr("ARMORY_EARN_LINE") % [earn[&"match_played"], earn[&"match_won"], earn[&"round_won"], earn[&"hit"]] \
			+ JOIN + JOIN.join(multipliers)
	_earn = MenuParts.text(words, EARN_SIZE, 500, GameTheme.MUTED)
	_earn.name = "Earn"
	_earn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_earn.size_flags_vertical = Control.SIZE_SHRINK_END
	_earn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_earn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_earn.mouse_filter = Control.MOUSE_FILTER_PASS
	_earn.tooltip_text = tr("ARMORY_EARN_NOTE") % [JOIN.join(multipliers), win_xp(_facts.table, 0),
			win_xp(_facts.table, 1) - win_xp(_facts.table, 0)]
	return _earn


## What a first-to-5 win on Normal with `hits` hits gives, worked out from `table` (levels.md's XP, MatchXp's rules)
## rather than typed (BP7: the note said "about 250" while the table gave 300 before a hit).
static func win_xp(table: LevelTable, hits: int) -> int:
	var o := MatchXp.Outcome.new()
	o.won = true
	o.wins_needed = MatchXp.FULL_MATCH_WINS
	o.rounds_won = MatchXp.FULL_MATCH_WINS
	o.hits = hits
	o.difficulty = &"normal"
	return MatchXp.earned(table, o).total

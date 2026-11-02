class_name ArmoryPage
extends Control
## The ARMORY tab (docs/TASKS.md AR1; UI concept B v2 `armory.png`): ARMORY with its line and the arrows that browse the
## levels, a load problem under it, the level panel (ArmorySummary: your level, XP, how XP is earned, the level track) and
## the level cards (ArmoryTrack) from your level on. Built when the tab is opened, from the player's progress as it
## stands, and freed when it is left, with the pictures it drew; `stale` says the level changed under it (the Settings'
## Dev buttons).

const NOTICE_SIZE := 15
const ARROW_SIZE := 22
const ARROW_PAD := Vector2i(14, 4)
const ARROW_GAP := 10

var progress: Progress = null
var records: Records = null
var settings: Settings = null

var _facts: ArmoryFacts = null
var _pictures: ReplicaPictures = null
var _summary: ArmorySummary = null
var _track: ArmoryTrack = null
var _notice: Label = null
var _back: Button = null
var _on: Button = null
var _signature: String = ""


func _init(settings_in: Settings = null, progress_in: Progress = null, records_in: Records = null,
		pool: Pool = null) -> void:
	name = "ArmoryPage"
	settings = settings_in if settings_in != null else Settings.shared()
	progress = progress_in if progress_in != null else Progress.shared()
	records = records_in if records_in != null else Records.shared()
	theme = GameTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dev := settings.dev
	_signature = _now()
	_facts = ArmoryFacts.new(progress.table, pool if pool != null else Pool.shared(), progress.xp,
			dev.disable_levelling, dev.dev_content)
	# Small pictures: each item shows at about 200 px at most.
	_pictures = ReplicaPictures.new()
	_pictures.name = "Pictures"
	_pictures.replica_side = ReplicaPictures.PART_LONG_SIDE
	add_child(_pictures)
	var items := ItemPictures.new(_facts.pool, _pictures)
	var margin := MenuParts.padded(MenuParts.PAGE_MARGIN.x, MenuParts.PAGE_MARGIN.y, MenuParts.PAGE_MARGIN.z,
			MenuParts.PAGE_MARGIN.w)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", MenuParts.PAGE_TITLE_AFTER)
	margin.add_child(page)
	page.add_child(_title_row())
	_notice = MenuParts.text(_load_problems(), NOTICE_SIZE, 700, GameTheme.WARN)
	_notice.name = "Notice"
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.visible = _notice.text != ""
	page.add_child(_notice)
	_summary = ArmorySummary.new(_facts)
	page.add_child(_summary)
	_track = ArmoryTrack.new(_facts, items)
	_track.moved.connect(_refresh_arrows)
	page.add_child(_track)
	_summary.bar().level_picked.connect(_track.show_from)
	_refresh_arrows()


## The arrows that browse the level cards: back a level, and on.
func back_arrow() -> Button:
	return _back


func on_arrow() -> Button:
	return _on


func facts() -> ArmoryFacts:
	return _facts


func summary() -> ArmorySummary:
	return _summary


func track() -> ArmoryTrack:
	return _track


func pictures() -> ReplicaPictures:
	return _pictures


func _title_row() -> Control:
	var row := HBoxContainer.new()
	row.add_child(MenuParts.page_title(tr("MENU_TAB_ARMORY"), MenuParts.page_line(tr("ARMORY_LINE"))))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var arrows := HBoxContainer.new()
	arrows.add_theme_constant_override("separation", ARROW_GAP)
	arrows.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrows)
	_back = _arrow("‹", "ARMORY_BROWSE_BACK", -1)
	arrows.add_child(_back)
	_on = _arrow("›", "ARMORY_BROWSE_ON", 1)
	arrows.add_child(_on)
	return row


func _arrow(glyph: String, tip_key: String, step: int) -> Button:
	var b := Button.new()
	b.name = "Back" if step < 0 else "On"
	b.text = glyph
	b.tooltip_text = tr(tip_key)
	b.add_theme_font_size_override("font_size", ARROW_SIZE)
	GameTheme.dress(b, GameTheme.box(GameTheme.CARD, GameTheme.LINE, ARROW_PAD.x, ARROW_PAD.y),
			GameTheme.box(GameTheme.CARD_HI, GameTheme.LINE, ARROW_PAD.x, ARROW_PAD.y),
			GameTheme.box(GameTheme.CARD_HI, GameTheme.ACCENT, ARROW_PAD.x, ARROW_PAD.y))
	# at an end the arrow fades right back, not just its glyph
	b.add_theme_stylebox_override("disabled", GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), GameTheme.LINE, ARROW_PAD.x,
			ARROW_PAD.y))
	b.pressed.connect(func() -> void: _track.browse(step))
	return b


func _refresh_arrows() -> void:
	if _back == null or _track == null:
		return
	_back.disabled = _track.first() <= 0
	_on.disabled = _track.first() >= _track.last_first()


## The load problems shown at the top ("" when there were none).
func notice_text() -> String:
	return _notice.text if _notice.visible else ""


## True if the level, the XP, Disable levelling or Dev content changed since the page was built.
func stale() -> bool:
	return _now() != _signature


func _now() -> String:
	var dev := settings.dev
	return "%s:%s:%d:%d" % [dev.disable_levelling, dev.dev_content, progress.xp, progress.unlocked.size()]


## What the player's level and records files said when they were read, one line each.
func _load_problems() -> String:
	var lines := PackedStringArray()
	for message: String in [progress.load_message, records.load_message]:
		if message != "":
			lines.append(message)
	return "\n".join(lines)

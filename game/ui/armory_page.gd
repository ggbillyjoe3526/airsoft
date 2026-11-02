class_name ArmoryPage
extends Control
## The ARMORY tab (docs/TASKS.md AR1, concept step11-armory/armory.png): your level and XP, the next unlock and how XP is
## earned on the left (ArmorySummary), every level with its items on the right (ArmoryTrack). A progress or records file
## that couldn't be used is said at the top. Built when the tab is opened, from the player's progress as it stands, and freed
## when it is left, with the pictures it drew; `stale` says the level changed under it (the Settings' Dev buttons).

const MARGIN_X := 56
const TOP := 28
const BOTTOM := 28
const COLUMN_GAP := 32
const SUMMARY_WIDTH := 540.0
const NOTICE_SIZE := 15
const NOTICE_GAP := 10

var progress: Progress = null
var records: Records = null
var settings: Settings = null

var _facts: ArmoryFacts = null
var _pictures: ReplicaPictures = null
var _summary: ArmorySummary = null
var _track: ArmoryTrack = null
var _notice: Label = null
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
	# Small pictures: each item shows at about 90 px, a replica no bigger than its chip.
	_pictures = ReplicaPictures.new()
	_pictures.name = "Pictures"
	_pictures.replica_side = ReplicaPictures.PART_LONG_SIDE
	add_child(_pictures)
	var items := ItemPictures.new(_facts.pool, _pictures)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", MARGIN_X)
	margin.add_theme_constant_override("margin_right", MARGIN_X)
	margin.add_theme_constant_override("margin_top", TOP)
	margin.add_theme_constant_override("margin_bottom", BOTTOM)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", NOTICE_GAP)
	margin.add_child(page)
	_notice = MenuParts.text(_load_problems(), NOTICE_SIZE, 700, GameTheme.ACCENT)
	_notice.name = "Notice"
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.visible = _notice.text != ""
	page.add_child(_notice)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", COLUMN_GAP)
	page.add_child(body)
	var left := ScrollContainer.new()
	left.name = "SummaryScroll"
	left.custom_minimum_size = Vector2(SUMMARY_WIDTH, 0.0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(left)
	_summary = ArmorySummary.new(_facts, items)
	_summary.custom_minimum_size = Vector2(SUMMARY_WIDTH, 0.0)
	left.add_child(_summary)
	_track = ArmoryTrack.new(_facts, items)
	body.add_child(_track)


func facts() -> ArmoryFacts:
	return _facts


func summary() -> ArmorySummary:
	return _summary


func track() -> ArmoryTrack:
	return _track


func pictures() -> ReplicaPictures:
	return _pictures


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

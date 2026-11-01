class_name Settings
extends RefCounted
## The player's settings: plain typed state, saved through SaveFile at user://settings.save (kind "settings", version
## 3). Nothing here touches the engine; SettingsApply writes the values into the game, and SettingsScreen edits them.
## A missing file is silent defaults. A file that is damaged, unreadable or of a version this build doesn't know falls
## back to the defaults with `load_message` (one from a newer build is never written over: the defaults last for the
## session); a value that is the wrong type or out of range keeps its default alone. Keys this build doesn't know are
## kept.

## Sent when a value changed (after SettingsApply has applied it), so a readout can follow.
signal changed

const PATH := "user://settings.save"
const KIND := "settings"
## 2 moved the first-start defaults (FB2), 3 the ambience's (AU1); an older file is brought over once by
## `migrate_defaults`.
const VERSION := 3
## The keys this build reads (with two it reads once and no longer writes: "dev_enabled", FB3, and "robots", FI6); any
## other key in the file is kept as it was.
const KNOWN_KEYS: Array[String] = [
	"sensitivity", "aim_sensitivity", "invert_y", "crouch_toggle", "aim_toggle", "auto_reload", "wheel_pick",
	"mouse_dpi", "bindings", "volumes", "window_mode", "vsync", "fov", "show_fps", "realistic_colours",
	"what_got_you", "hud", "custom_rules", "practice_challenge", "dev", "dev_enabled", "graphics_base",
	"graphics_choice", "graphics_custom", "frame_limit", "monitor", "last_fullscreen", "renderer", "first_start_seen",
	"team_colours", "gauge_patterns", "sound_cues", "sound_cue_size", "sound_cue_colour", "read_out", "reduced_motion",
	"robots",
]
## Windowed leaves the window as it is (the project starts maximised); the other two are the DisplayServer's
## borderless and exclusive fullscreen. The first start is Exclusive (WINDOW_MODE_DEFAULT).
enum WindowMode { WINDOWED, BORDERLESS, EXCLUSIVE }
## When the "What got you" card shows: against Hard bots, always, or never.
enum WhatGotYou { AUTO, ON, OFF }
## The renderer the next start asks for: Auto (Forward+, falling back by itself) or the simpler Compatibility one.
enum Renderer { AUTO, COMPATIBILITY }
## Reduced motion: follow the system's "reduce animation" (never written to the file), or the player's Off or On.
enum ReducedMotion { SYSTEM, OFF, ON }

## Volumes are linear shares, 0 to 1, by audio bus (docs/DECISIONS.md › Menus, HUD, settings and accessibility).
const VOLUME_BUSES: Array[StringName] = [&"Master", &"Effects", &"Power", &"Ambience", &"Interface"]
const VOLUME_DEFAULTS: Dictionary[StringName, float] = {
	&"Master": 1.0,
	&"Effects": 0.7,
	&"Power": 1.0,
	&"Ambience": 0.2,
	&"Interface": 0.4,
}
## The volumes a version 1 file started with: one still equal to its old default was never touched.
const VOLUME_DEFAULTS_V1: Dictionary[StringName, float] = {
	&"Master": 1.0,
	&"Effects": 0.8,
	&"Power": 1.0,
	&"Ambience": 0.6,
	&"Interface": 0.5,
}
## The volumes a version 2 file started with (FB2): only the ambience has moved since (AU1).
const VOLUME_DEFAULTS_V2: Dictionary[StringName, float] = {
	&"Master": 1.0,
	&"Effects": 0.7,
	&"Power": 1.0,
	&"Ambience": 0.3,
	&"Interface": 0.4,
}
## Exclusive fullscreen on the display the game opens on, and V-Sync off, from the first start (owner, 2026-10-29).
const WINDOW_MODE_DEFAULT := WindowMode.EXCLUSIVE
const VSYNC_DEFAULT := false
## Version 1's defaults for the two (Windowed, V-Sync on).
const WINDOW_MODE_DEFAULT_V1 := WindowMode.WINDOWED
const LAST_FULLSCREEN_DEFAULT_V1 := WindowMode.BORDERLESS
const VSYNC_DEFAULT_V1 := true
## Horizontal field of view on a 16:9 screen (degrees): the range and the default (owner, 2026-10-04: 90).
const FOV_MIN := 70.0
const FOV_MAX := 110.0
const FOV_DEFAULT := 90.0
## The frame-rate limits offered besides Unlimited (UNLIMITED, 0); a saved number that isn't one reads as the nearest,
## the higher on a tie (the browser game's FRAME_RATE_CAPS, with katanashotgun's 165 and 360).
const FRAME_LIMITS: Array[int] = [30, 60, 120, 144, 165, 240, 360]
const UNLIMITED := 0
## The monitor the window opens on: MONITOR_HERE is wherever it is; a saved index above MONITOR_MOST is a typo. A
## saved monitor that is gone is SettingsApply's to fall back from (GR3).
const MONITOR_HERE := -1
const MONITOR_MOST := 63
## The graphics choice that means the automatic pick (GraphicsPick), never written to the file.
const GRAPHICS_AUTOMATIC := &""

var sensitivity: float = 1.0
var aim_sensitivity: float = 1.0
var invert_y: bool = false
## Crouch and aim are held by default (owner, 2026-10-18).
var crouch_toggle: bool = false
var aim_toggle: bool = false
## Reloads are manual by default: R loads an empty replica, with a prompt (owner, 2026-10-29). A file from before has no
## value, so it loads Manual too.
var auto_reload: bool = false
## How an order on the order wheel is given: Hover by default.
var wheel_pick: ControlsConfig.WheelPick = ControlsConfig.WheelPick.HOVER
## The mouse's DPI, only to show sensitivity as cm/360 and to type it.
var mouse_dpi: int = Sensitivity.DPI_DEFAULT
var bindings: KeyBindings = KeyBindings.new()
var volumes: Dictionary[StringName, float] = VOLUME_DEFAULTS.duplicate()
var window_mode: WindowMode = WINDOW_MODE_DEFAULT
var vsync: bool = VSYNC_DEFAULT
var fov: float = FOV_DEFAULT
var show_fps: bool = false
## The graphics preset chosen (GraphicsTable.PRESETS or GraphicsQuality.CUSTOM), or GRAPHICS_AUTOMATIC for the pick from
## the card. Custom is graphics_base's column with the graphics_custom rows over it (GraphicsQuality.resolve).
var graphics_choice: StringName = GRAPHICS_AUTOMATIC
var graphics_base: StringName = GraphicsTable.DEFAULT_PRESET
## Custom's own rows: a row's ID to its choice's name, or a range row's number.
var graphics_custom: Dictionary[String, Variant] = {}
## The `--graphics=` preset forcing this run (GraphicsPick.forced), or "": never saved.
var graphics_forced: StringName = &""
## Frames a second at most, or UNLIMITED.
var frame_limit: int = UNLIMITED
## The monitor's index, or MONITOR_HERE.
var monitor: int = MONITOR_HERE
## The fullscreen mode F11 goes back to: Borderless or Exclusive (the first start's mode until one is left).
var last_fullscreen: WindowMode = WINDOW_MODE_DEFAULT
## Read at the next start (GR4).
var renderer: Renderer = Renderer.AUTO
## The first-start notice has been shown (GR5).
var first_start_seen: bool = false
## Replica colours: every bold scheme shows as its plain family colour (LO3).
var realistic_colours: bool = false
## The "What got you" card once you are hit: Auto shows it against Hard bots only.
var what_got_you: WhatGotYou = WhatGotYou.AUTO
## The HUD tab's choices: the crosshair, the hit marker, the ammo counter, the hit feed and the panels' opacity.
var hud: HudPrefs = HudPrefs.new()
## Settings › Accessibility (AC1): the team colour set (TeamColours), shown from the next match.
var team_colours: TeamColours.Set = TeamColours.Set.STANDARD
## Stripes on Beta's gauges and a low magazine, so they read without colour.
var gauge_patterns: bool = true
## Markers round the crosshair for the sounds you hear: off by default, so playing by ear stays the norm; their size
## (AccessibilityConfig.CUE_SIZE_RANGE) and colour (an index into HudPrefs.COLOURS).
var sound_cues: bool = false
var sound_cue_size: float = AccessibilityConfig.CUE_SIZE_DEFAULT
var sound_cue_colour: int = AccessibilityConfig.CUE_COLOUR_DEFAULT
## Follows the system until the player picks (reduces_motion).
var reduced_motion: ReducedMotion = ReducedMotion.SYSTEM
## Hit calls, your hit and round results sent to a screen reader while one runs.
var read_out: bool = true
## The Custom rule set's switches, kept between Custom matches (the Match screen picks Skirmish or Custom).
var custom_rules: CustomRules = CustomRules.new()
## Practice's timed challenge, switched on or off from the pause menu and kept for the next visit to the range.
var practice_challenge: bool = false
## The Dev tab's switches, in force whenever they are set (owner, 2026-10-29: no Dev settings box any more).
var dev: DevSettings = DevSettings.new()
## What the settings write into: the camera and the mouse (the same resource PlaySession loads).
var tuning: PlayTuning = null
## Why the saved settings weren't used, or empty (and empty again once a save has written a good file).
var load_message: String = ""
## Changed since the last save.
var dirty: bool = false
## The file is from a newer build: it is never written over.
var _newer_on_disk: bool = false
## Keys in the file this build doesn't know, written back as they were.
var _extra: Dictionary = {}

static var _shared: Settings = null


func _init(play_tuning: PlayTuning = null) -> void:
	tuning = play_tuning if play_tuning != null else PlayTuning.load_default()


## The game's settings: read from PATH and applied on first use, then the same object. The menus share it because the
## pause menu is built inside a match and can't be handed one.
static func shared() -> Settings:
	if _shared == null:
		var s := Settings.new()
		s.load_file()
		s.graphics_forced = GraphicsPick.forced(OS.get_cmdline_user_args()) # before apply, so it sees the flag
		SettingsApply.apply_all(s)
		_shared = s
	return _shared


## Reads `path`. Silent when there is no file; otherwise a message if it can't be used.
func load_file(path: String = PATH) -> void:
	load_message = ""
	_newer_on_disk = false
	var r := SaveFile.read(path, KIND)
	if not r.ok:
		if r.found:
			load_message = TranslationServer.translate("SETTINGS_DAMAGED")
			push_warning("settings: %s is damaged; using the defaults" % path)
			SaveFile.quarantine(path)
		return
	if int(r.version) < 1 or int(r.version) > VERSION:
		load_message = TranslationServer.translate("SETTINGS_NEWER")
		push_warning("settings: %s is version %d; using the defaults" % [path, int(r.version)])
		_newer_on_disk = int(r.version) > VERSION
		return
	from_dict(migrate_defaults(r.data, int(r.version)))


## `data` as a version `version` file's, with every value still at the old default moved to the new one (a value the
## player changed is kept): the volumes (from version 1 or 2), Windowed and V-Sync (from version 1). The current
## version or later is returned as it is. A new dictionary; `data` is not changed.
static func migrate_defaults(data: Dictionary, version: int) -> Dictionary:
	if version >= VERSION:
		return data
	var moved := data.duplicate(true)
	var old_volumes := VOLUME_DEFAULTS_V1 if version < 2 else VOLUME_DEFAULTS_V2
	var saved_vol: Variant = moved.get("volumes")
	if saved_vol is Dictionary:
		var vol: Dictionary = saved_vol
		for bus: StringName in VOLUME_BUSES:
			var key := String(bus)
			var v: Variant = vol.get(key)
			if (v is float or v is int) and is_equal_approx(float(v), old_volumes[bus]):
				vol[key] = VOLUME_DEFAULTS[bus]
	if version >= 2:
		return moved
	var mode: Variant = moved.get("window_mode")
	if (mode is float or mode is int) and roundi(float(mode)) == WINDOW_MODE_DEFAULT_V1:
		moved["window_mode"] = int(WINDOW_MODE_DEFAULT)
		# a window that never left the old default has the old default remembered for F11 too
		var remembered: Variant = moved.get("last_fullscreen")
		if (remembered is float or remembered is int) and roundi(float(remembered)) == LAST_FULLSCREEN_DEFAULT_V1:
			moved["last_fullscreen"] = int(WINDOW_MODE_DEFAULT)
	var vsync_saved: Variant = moved.get("vsync")
	if vsync_saved is bool and vsync_saved == VSYNC_DEFAULT_V1:
		moved["vsync"] = VSYNC_DEFAULT
	return moved


## Writes `path`; false if it could not be written (or holds a newer build's settings).
func save(path: String = PATH) -> bool:
	if _newer_on_disk:
		return false
	var ok := SaveFile.write(path, KIND, VERSION, to_dict())
	dirty = not ok
	if ok:
		# the file is good again: what was wrong with the last one is said no more
		load_message = ""
	return ok


## Marks a change: saved later by whoever debounces, and `changed` is sent.
func mark_changed() -> void:
	dirty = true
	changed.emit()


## Saves if anything changed since the last save.
func save_if_dirty(path: String = PATH) -> void:
	if dirty:
		save(path)


func to_dict() -> Dictionary:
	var vol := {}
	for bus: StringName in VOLUME_BUSES:
		vol[String(bus)] = volumes[bus]
	var out := _extra.duplicate(true)
	out.merge({
		"sensitivity": sensitivity, "aim_sensitivity": aim_sensitivity, "invert_y": invert_y,
		"crouch_toggle": crouch_toggle, "aim_toggle": aim_toggle, "auto_reload": auto_reload,
		"wheel_pick": int(wheel_pick), "mouse_dpi": mouse_dpi,
		"bindings": bindings.to_dict(), "volumes": vol, "window_mode": int(window_mode), "vsync": vsync,
		"fov": fov, "show_fps": show_fps, "realistic_colours": realistic_colours, "what_got_you": int(what_got_you),
		"hud": hud.to_dict(), "custom_rules": custom_rules.to_dict(), "practice_challenge": practice_challenge,
		"dev": dev.to_dict(), "graphics_base": String(graphics_base),
		"graphics_custom": graphics_custom.duplicate(), "frame_limit": frame_limit, "monitor": monitor,
		"last_fullscreen": int(last_fullscreen), "renderer": int(renderer), "first_start_seen": first_start_seen,
		"team_colours": int(team_colours), "gauge_patterns": gauge_patterns, "sound_cues": sound_cues,
		"sound_cue_size": sound_cue_size, "sound_cue_colour": sound_cue_colour, "read_out": read_out,
	}, true)
	# Following the system is never written, so the file holds only the player's own pick.
	if reduced_motion != ReducedMotion.SYSTEM:
		out["reduced_motion"] = reduced_motion == ReducedMotion.ON
	# The automatic pick is never written, so a better card later gets its own preset.
	if graphics_choice != GRAPHICS_AUTOMATIC:
		out["graphics_choice"] = String(graphics_choice)
	return out


## Takes saved values over the defaults, each checked on its own; keys this build doesn't know are kept for to_dict.
func from_dict(data: Dictionary) -> void:
	_extra = {}
	for k: Variant in data:
		if not KNOWN_KEYS.has(str(k)):
			_extra[k] = data[k]
	sensitivity = _number(data, "sensitivity", 1.0, Sensitivity.MIN, Sensitivity.MAX)
	aim_sensitivity = _number(data, "aim_sensitivity", 1.0, Sensitivity.AIM_MIN, Sensitivity.AIM_MAX)
	invert_y = _flag(data, "invert_y", false)
	crouch_toggle = _flag(data, "crouch_toggle", false)
	aim_toggle = _flag(data, "aim_toggle", false)
	auto_reload = _flag(data, "auto_reload", false)
	var picks := ControlsConfig.WheelPick.size() - 1.0
	wheel_pick = roundi(_number(data, "wheel_pick", ControlsConfig.WheelPick.HOVER, 0.0, picks)) as ControlsConfig.WheelPick
	mouse_dpi = roundi(_number(data, "mouse_dpi", Sensitivity.DPI_DEFAULT, Sensitivity.DPI_MIN, Sensitivity.DPI_MAX))
	bindings.load_dict(data.get("bindings"))
	var saved_vol: Variant = data.get("volumes")
	var vol: Dictionary = saved_vol if saved_vol is Dictionary else {}
	for bus: StringName in VOLUME_BUSES:
		volumes[bus] = _number(vol, String(bus), VOLUME_DEFAULTS[bus], 0.0, 1.0)
	var mode := roundi(_number(data, "window_mode", WINDOW_MODE_DEFAULT, 0.0, WindowMode.size() - 1.0))
	window_mode = mode as WindowMode
	vsync = _flag(data, "vsync", VSYNC_DEFAULT)
	fov = _number(data, "fov", FOV_DEFAULT, FOV_MIN, FOV_MAX)
	show_fps = _flag(data, "show_fps", false)
	realistic_colours = _flag(data, "realistic_colours", false)
	what_got_you = roundi(_number(data, "what_got_you", WhatGotYou.AUTO, 0.0, WhatGotYou.size() - 1.0)) as WhatGotYou
	var saved_hud: Variant = data.get("hud")
	hud.from_dict(saved_hud if saved_hud is Dictionary else {})
	var saved_rules: Variant = data.get("custom_rules")
	custom_rules.from_dict(saved_rules if saved_rules is Dictionary else {})
	practice_challenge = _flag(data, "practice_challenge", false)
	var saved_dev: Variant = data.get("dev")
	# A save from when the Dev settings box ruled (FB3) with it unticked: its switches never applied, so they go back
	# to off once here rather than suddenly taking effect. Saves no longer write the box, so this happens only once.
	var box_unticked: bool = data.get("dev_enabled") is bool and not data.get("dev_enabled")
	dev.from_dict(saved_dev if saved_dev is Dictionary and not box_unticked else {})
	_graphics_from(data)
	frame_limit = nearest_frame_limit(_number(data, "frame_limit", UNLIMITED, UNLIMITED, INF))
	monitor = roundi(_number(data, "monitor", MONITOR_HERE, MONITOR_HERE, MONITOR_MOST))
	var fullscreen := roundi(_number(data, "last_fullscreen", WINDOW_MODE_DEFAULT, WindowMode.BORDERLESS,
			WindowMode.EXCLUSIVE))
	last_fullscreen = fullscreen as WindowMode
	renderer = roundi(_number(data, "renderer", Renderer.AUTO, 0.0, Renderer.size() - 1.0)) as Renderer
	first_start_seen = _flag(data, "first_start_seen", false)
	_accessibility_from(data)
	# The public Looks › Robots ("robots", FI6) is passed over: robots are the Dev tab's Easter egg now (RB1).


## Whether motion is reduced: On, or Follow system while the system asks for it (`system_answer` is
## DisplayServer.accessibility_should_reduce_animation()'s: 1 yes, 0 no, -1 it can't say).
func reduces_motion(system_answer: int) -> bool:
	if reduced_motion == ReducedMotion.SYSTEM:
		return system_answer == 1
	return reduced_motion == ReducedMotion.ON


## reduces_motion with the display's answer now.
func reduces_motion_now() -> bool:
	return reduces_motion(DisplayServer.accessibility_should_reduce_animation())


## The graphics values in force: the `--graphics=` preset, else the automatic pick (`picked`, GraphicsPick's), else
## the chosen preset or Custom.
func graphics_in_force(picked: StringName, table: GraphicsTable = null) -> GraphicsQuality:
	var t := table if table != null else GraphicsTable.shared()
	if graphics_forced != &"":
		return t.preset(graphics_forced)
	if graphics_choice == GRAPHICS_AUTOMATIC:
		return t.preset(picked)
	return GraphicsQuality.resolve(graphics_choice, graphics_base, graphics_custom, t)


## The preset in force, or the one Custom is built on: what a changed row makes Custom from.
func graphics_preset_on(picked: StringName) -> StringName:
	if graphics_forced != &"":
		return graphics_forced
	if graphics_choice == GRAPHICS_AUTOMATIC:
		return picked
	return graphics_base if graphics_choice == GraphicsQuality.CUSTOM else graphics_choice


## Chooses a preset, Custom or GRAPHICS_AUTOMATIC. Custom chosen from a preset starts as that preset with no rows of
## its own; chosen again it keeps its rows. A preset or automatic drops Custom's rows. False (and nothing changes) for
## a name that is none of these.
func choose_graphics(choice: StringName, picked: StringName) -> bool:
	if choice == GraphicsQuality.CUSTOM:
		if graphics_choice != GraphicsQuality.CUSTOM:
			graphics_base = graphics_preset_on(picked)
			graphics_custom = {}
	elif choice != GRAPHICS_AUTOMATIC and not GraphicsTable.PRESETS.has(choice):
		return false
	else:
		graphics_custom = {} # a preset or automatic sets every row again (QA)
	graphics_choice = choice
	return true


## Sets one row (a choice's name, or a range row's number), making the choice Custom, based on the preset you were on.
## False (and nothing changes) if the table doesn't offer that value.
func change_graphics_row(row: StringName, value: Variant, picked: StringName, table: GraphicsTable = null) -> bool:
	var t := table if table != null else GraphicsTable.shared()
	var level := t.level_of(row, value)
	if level == GraphicsTable.NO_LEVEL:
		return false
	var values := graphics_in_force(picked, t)
	values.set_level(row, level)
	var base := graphics_preset_on(picked)
	graphics_choice = GraphicsQuality.CUSTOM
	graphics_base = base
	graphics_custom = GraphicsQuality.overrides(values, base, t)
	return true


## `limit` as one of FRAME_LIMITS, the nearest and the higher on a tie, or UNLIMITED for 0 or less.
static func nearest_frame_limit(limit: float) -> int:
	if is_nan(limit) or limit <= UNLIMITED:
		return UNLIMITED
	var best := FRAME_LIMITS[0]
	for l in FRAME_LIMITS:
		if absf(limit - l) <= absf(limit - best):
			best = l
	return best


## The settings file and its backups go and every setting is back to its default, applied at once: the first-launch
## state, as for a new player. (Settings › Save file's Delete replaces the whole save instead, with Undo.)
func reset_save(path: String = PATH) -> void:
	SaveFile.remove(path)
	from_dict({})
	load_message = ""
	dirty = false
	SettingsApply.apply_all(self)


## The value at `key` if it is a number within [lo, hi], else `fallback`; an end taken from a Vector2 range is single
## precision, so HudPrefs.RANGE_SLACK past it still counts, clamped (QA).
static func _number(data: Dictionary, key: String, fallback: float, lo: float, hi: float) -> float:
	var v: Variant = data.get(key)
	if not (v is float or v is int):
		return fallback
	var f := float(v)
	if is_nan(f) or f < lo - HudPrefs.RANGE_SLACK or f > hi + HudPrefs.RANGE_SLACK:
		return fallback
	return clampf(f, lo, hi)


## The graphics choice, base and Custom rows, each checked on its own: a Custom row of an unknown row, or with a value
## of the wrong type or one the game doesn't know, is dropped alone (GraphicsQuality.resolve also drops one the table
## doesn't offer).
func _graphics_from(data: Dictionary) -> void:
	var choice: Variant = data.get("graphics_choice")
	graphics_choice = GRAPHICS_AUTOMATIC
	if choice is String and (GraphicsTable.PRESETS.has(StringName(choice)) or choice == GraphicsQuality.CUSTOM):
		graphics_choice = StringName(choice)
	var base: Variant = data.get("graphics_base")
	graphics_base = GraphicsTable.DEFAULT_PRESET
	if base is String and GraphicsTable.PRESETS.has(StringName(base)):
		graphics_base = StringName(base)
	graphics_custom = {}
	var saved: Variant = data.get("graphics_custom")
	if not saved is Dictionary:
		return
	var rows: Dictionary = saved
	for key: Variant in rows:
		var value: Variant = rows[key]
		if not key is String or not GraphicsQuality.ROWS.has(StringName(key)):
			continue
		var row := StringName(key)
		if GraphicsQuality.is_range(row):
			var limits: Vector2i = GraphicsQuality.LIMITS[row]
			var n := _number(rows, key, NAN, limits.x, limits.y)
			if not is_nan(n):
				graphics_custom[key] = roundi(n)
		elif value is String and GraphicsQuality.CHOICES[row].has(value):
			graphics_custom[key] = value


## Settings › Accessibility's values, each checked on its own; a size between the slider's steps reads as the nearest
## step.
func _accessibility_from(data: Dictionary) -> void:
	var sets := TeamColours.Set.size() - 1.0
	team_colours = roundi(_number(data, "team_colours", TeamColours.Set.STANDARD, 0.0, sets)) as TeamColours.Set
	gauge_patterns = _flag(data, "gauge_patterns", true)
	sound_cues = _flag(data, "sound_cues", false)
	var sizes := AccessibilityConfig.CUE_SIZE_RANGE
	var size := _number(data, "sound_cue_size", AccessibilityConfig.CUE_SIZE_DEFAULT, sizes.x, sizes.y)
	sound_cue_size = snappedf(size, AccessibilityConfig.CUE_SIZE_STEP)
	var colours := HudPrefs.COLOURS.size() - 1.0
	sound_cue_colour = roundi(_number(data, "sound_cue_colour", AccessibilityConfig.CUE_COLOUR_DEFAULT, 0.0, colours))
	var motion: Variant = data.get("reduced_motion")
	reduced_motion = ReducedMotion.SYSTEM
	if motion is bool:
		reduced_motion = ReducedMotion.ON if motion else ReducedMotion.OFF
	read_out = _flag(data, "read_out", true)


static func _flag(data: Dictionary, key: String, fallback: bool) -> bool:
	var v: Variant = data.get(key)
	return v if v is bool else fallback


## Whether the file on disk is a newer build's, kept as it is (no save writes over it this session).
func from_newer_build() -> bool:
	return _newer_on_disk

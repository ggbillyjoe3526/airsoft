class_name ReportFacts
extends RefCounted
## Gathers a bug report's facts (SV4): a ReportInfo for BugReport, from the running game (`live`: the machine, the
## renderer, the settings, PlaySession's match and player, ErrorLog, RecentEvents, FrameWindow) or, for a crash, from
## the run record's `previous` and the old log (`crash`: LogTail's last lines, and the errors the log names). The
## wording of each field is a pure function below, so tests need no GPU, window or match. Called only when a report is
## made. English throughout: the report is read by the developer.

const WEEKDAYS: PackedStringArray = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const MONTHS: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const EXPORTED := "exported, %s"
const SOURCE_RUN := "source run"
const RELEASE := "release"
const DEBUG := "debug"
## The graphics driver's version after the card's name; ReportScrub keeps this machine's whole.
const DRIVER_TEXT := "(driver %s)"
## DisplayServer.WindowMode, in its order.
const WINDOW_MODES: PackedStringArray = ["windowed", "minimized", "maximized", "borderless fullscreen", "fullscreen"]
const RENDERING_METHODS: Dictionary[String, String] = {
	"forward_plus": "Forward+", "mobile": "Mobile", "gl_compatibility": "Compatibility",
}
const DRIVERS: Dictionary[String, String] = {
	"vulkan": "Vulkan", "d3d12": "Direct3D 12", "metal": "Metal", "opengl3": "OpenGL", "opengl3_es": "OpenGL ES",
	"opengl3_angle": "OpenGL (ANGLE)",
}
## Where the run record's `place` puts the player.
const PLACES: Dictionary[String, String] = {
	RunRecord.MATCH: "in play", RunRecord.PRACTICE: "practice", RunRecord.MENUS: "in the menus",
}
const PRACTICE := "Practice"
const STANDARD_RULES := "Standard rules"
const CUSTOM_RULES := "Custom rules"
const OFF := "off"
const ON := "on"
## RoundState.Phase, in its order.
const PHASES: PackedStringArray = ["live", "over", "match over"]
const SEP := " · "
## Godot's short commit hash, as its own version string gives it.
const HASH_CHARS := 9
const BYTES_PER_GB := 1024.0 * 1024.0 * 1024.0
const MS_PER_SECOND := 1000.0
const SECONDS_PER_MINUTE := 60
const SECONDS_PER_HOUR := 3600
const FULL_TURN := 360.0
## Settings left out of Settings changed: Dev has its own line, bindings are counted, the rest are the game's own notes.
const NOT_SETTINGS: PackedStringArray = ["dev", "bindings", "first_start_seen", "last_fullscreen"]
## The log's error lines (Godot's own words), the longer first so "SCRIPT ERROR" isn't read as "ERROR".
const LOG_TYPES: PackedStringArray = ["SCRIPT ERROR", "SHADER ERROR", "ERROR", "WARNING"]
const LOG_AT := "at: "
const LOG_FRAME := "[0] "


## A report from the running game: `session` the match on (null on the title), `screen` where the player is,
## `errors` this run's ErrorLog (null: none kept). Fails closed: no `scrub` scrubs for this machine.
static func live(session: PlaySession, settings: Settings, errors: ErrorLog, screen: String, note: String,
		config: ReportConfig, scrub: ReportScrub) -> BugReport.ReportInfo:
	var info := BugReport.ReportInfo.new()
	_machine(info, settings)
	info.version = version_text(Version.current(), OS.has_feature("template"), OS.is_debug_build())
	info.note = note
	info.note_chars = config.note_chars
	info.time = "%s, %s after start" % [utc_text(int(Time.get_unix_time_from_system())),
			clock_text(Time.get_ticks_msec() / MS_PER_SECOND)]
	info.screen = screen
	if errors != null:
		info.errors = newest(errors.entries(), config.errors)
	if session != null and session.state != null:
		var state := session.state
		info.seed_text = str(state.match_seed)
		if session.practice:
			info.match_text = practice_text(session.map_id)
		else:
			info.match_text = match_text(session.map_id, session.mode, session.custom_rules != null,
					team_sizes(state), String(session.difficulty), String(session.teammate_difficulty))
			info.round_text = round_text(state.round_state, state.tick, state.time)
		info.player = player_text(session.player, config)
		info.frames = session.frame_window().line()
		info.events = newest(session.recent_events().lines(state, PlaySession.PLAYER_ID), config.events)
	info.scrub = scrub if scrub != null else ReportScrub.for_this_machine(config)
	return info


## A crash report: the run that closed unexpectedly (`previous`, RunRecord's) and its log (`tail`).
static func crash(previous: Dictionary, tail: LogTail, settings: Settings, note: String, config: ReportConfig,
		scrub: ReportScrub) -> BugReport.ReportInfo:
	var info := BugReport.ReportInfo.new()
	info.crash = true
	_machine(info, settings)
	info.version = version_text(_text(previous.get("version")), OS.has_feature("template"), OS.is_debug_build())
	info.note = note
	info.note_chars = config.note_chars
	var log_path := tail.path() if tail != null else ""
	var closed := FileAccess.get_modified_time(log_path) if log_path != "" else 0
	info.time = closed_text(closed, _whole(previous.get("started")))
	var place := _text(previous.get("place"))
	info.screen = PLACES.get(place, "")
	var facts: Dictionary = previous.get("match", {}) if previous.get("match") is Dictionary else {}
	if place == RunRecord.PRACTICE:
		info.match_text = practice_text(_text(facts.get("map")))
	elif place == RunRecord.MATCH:
		info.seed_text = _text(facts.get("seed"))
		var sizes: Array[int] = []
		var given: Variant = facts.get("team_sizes")
		if given is Array:
			for n: Variant in given:
				sizes.append(_whole(n))
		var rules: Variant = facts.get("rules")
		info.match_text = match_text(_text(facts.get("map")), _text(facts.get("mode")),
				rules is Dictionary and not (rules as Dictionary).is_empty(), sizes, _text(facts.get("difficulty")),
				_text(facts.get("teammates")))
		info.round_text = started_round_text(_whole(previous.get("round")), previous.get("score", []))
	if log_path != "":
		info.errors = errors_in_log(tail.recent_lines(), config.errors)
		info.log_lines = newest(tail.lines(), config.log_lines)
		info.log_count = tail.line_count()
	info.scrub = scrub if scrub != null else ReportScrub.for_this_machine(config)
	return info


## "0.1 Dev 3 (exported, release)", or "(source run)" from the editor or a source checkout.
static func version_text(version: String, exported: bool, debug: bool) -> String:
	var how := EXPORTED % (DEBUG if debug else RELEASE) if exported else SOURCE_RUN
	return "%s (%s)" % [version if version != "" else BugReport.UNKNOWN, how]


## Engine.get_version_info() as "4.7.2.stable.official.ed1daf0bf".
static func godot_text(v: Dictionary) -> String:
	if not v.has("major"):
		return ""
	var hash_part := str(v.get("hash", "")).left(HASH_CHARS)
	var out := "%d.%d.%d.%s.%s" % [int(v.get("major")), int(v.get("minor")), int(v.get("patch", 0)),
			str(v.get("status", "")), str(v.get("build", ""))]
	return out + ("." + hash_part if hash_part != "" else "")


## "Windows 11 (10.0.22631), 16 threads, 32 GB": the system's name, OS.get_version_alias()'s name for the release
## ("11" of Windows' "11 (build 22631)", "Sequoia" of macOS'; Linux' is its version, already in the distribution's
## name) and the version.
static func system_text(os_name: String, alias: String, version: String, threads: int, memory_bytes: int) -> String:
	var parts := PackedStringArray()
	var release := alias.get_slice(" (", 0).strip_edges()
	var named := os_name
	if release != "" and release != version and not os_name.contains(release):
		named += " " + release
	parts.append(named if version == "" or named.contains(version) else "%s (%s)" % [named, version])
	if threads > 0:
		parts.append("%d threads" % threads)
	if memory_bytes > 0:
		parts.append("%d GB" % roundi(memory_bytes / BYTES_PER_GB))
	return ", ".join(parts)


## "NVIDIA GeForce RTX 3070 (driver 566.36)"; "" when the driver names no card (headless).
static func card_text(adapter: String, driver_info: PackedStringArray) -> String:
	if adapter == "":
		return ""
	var version := driver_info[1] if driver_info.size() > 1 else ""
	return adapter if version == "" else adapter + " " + DRIVER_TEXT % version


## "Forward+ (Vulkan) · High".
static func renderer_text(method: String, driver: String, preset: String) -> String:
	var out: String = RENDERING_METHODS.get(method, method)
	if driver != "":
		out += " (%s)" % DRIVERS.get(driver, driver)
	return out + (SEP + preset.capitalize() if preset != "" else "")


## "fullscreen 2560 × 1440 at 144 Hz" (no rate when the screen doesn't say).
static func window_text(mode: int, size: Vector2i, hz: float) -> String:
	var word := WINDOW_MODES[mode] if mode >= 0 and mode < WINDOW_MODES.size() else str(mode)
	var out := "%s %d × %d" % [word, size.x, size.y]
	return out + (" at %d Hz" % roundi(hz) if hz > 0.0 else "")


## A Unix time as "Fri 23 Oct 2026 14:32 UTC".
static func utc_text(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%s %d %s %d %02d:%02d UTC" % [WEEKDAYS[int(d.weekday)], int(d.day), MONTHS[int(d.month) - 1], int(d.year),
			int(d.hour), int(d.minute)]


## Seconds as "m:ss", or "h:mm:ss" from an hour.
static func clock_text(seconds: float) -> String:
	var s := maxi(0, floori(seconds))
	var hours := s / SECONDS_PER_HOUR
	var minutes := (s % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE
	var rest := s % SECONDS_PER_MINUTE
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, rest]
	return "%d:%02d" % [minutes, rest]


## A crash's Closed: "about <the log's last write> UTC (the log's last line), 12:40 after start"; "" when not known.
static func closed_text(closed: int, started: int) -> String:
	if closed <= 0:
		return ""
	var since := ", %s after start" % clock_text(closed - started) if started > 0 and closed >= started else ""
	return "about %s (the log's last line)%s" % [utc_text(closed), since]


## "Depot · Elimination · Standard rules · 3v3 · Normal", with ", teammates Easy" when they differ.
static func match_text(map_id: String, mode: String, custom: bool, sizes: Array[int], difficulty: String,
		teammates: String) -> String:
	if map_id == "":
		return ""
	var parts := PackedStringArray([map_id.capitalize(), mode.capitalize() if mode != "" else BugReport.UNKNOWN,
			CUSTOM_RULES if custom else STANDARD_RULES])
	if sizes.size() == 2:
		parts.append("%dv%d" % [sizes[0], sizes[1]])
	var level := difficulty.capitalize() if difficulty != "" else BugReport.UNKNOWN
	if teammates != "" and teammates != difficulty:
		level += ", teammates %s" % teammates.capitalize()
	parts.append(level)
	return SEP.join(parts)


static func practice_text(map_id: String) -> String:
	return PRACTICE + (SEP + map_id.capitalize() if map_id != "" else "")


## Alpha's and Beta's sizes as the match has them.
static func team_sizes(state: GameState) -> Array[int]:
	var sizes: Array[int] = [0, 0]
	for c in state.characters:
		if c.team >= 0 and c.team < sizes.size():
			sizes[c.team] += 1
	return sizes


## "4 (live), score 2–1, tick 11523, 3:12 in".
static func round_text(rounds: RoundState, tick: int, match_seconds: float) -> String:
	if rounds == null:
		return ""
	var phase := PHASES[rounds.phase] if rounds.phase < PHASES.size() else str(rounds.phase)
	return "%d (%s), score %s, tick %d, %s in" % [rounds.number, phase, score_text(rounds.score), tick,
			clock_text(match_seconds)]


## A crash's round: "4 had started, score 2–1"; "" before the first.
static func started_round_text(number: int, score: Variant) -> String:
	if number <= 0:
		return ""
	var s := PackedInt32Array()
	if score is Array or score is PackedInt32Array:
		for n: Variant in score:
			s.append(_whole(n))
	return "%d had started, score %s" % [number, score_text(s)] if s.size() >= 2 else "%d had started" % number


static func score_text(score: PackedInt32Array) -> String:
	return "%d–%d" % [score[0], score[1]] if score.size() >= 2 else BugReport.UNKNOWN


## "at (12.4, 0.0, -8.1) facing 212°, crouched, AEG Rifle 17/60, 3 spare", with what else the player is doing.
static func player_text(c: Character, config: ReportConfig) -> String:
	if c == null:
		return ""
	var facing := fposmod(rad_to_deg(c.yaw), FULL_TURN)
	var doing := PackedStringArray(["at (%.1f, %.1f, %.1f) facing %d°" % [c.position.x, c.position.y, c.position.z,
			roundi(facing) % roundi(FULL_TURN)]])
	if c.status != Character.Status.ALIVE:
		doing.append(str(Character.Status.keys()[c.status]).to_lower().replace("_", " "))
	doing.append("crouched" if c.crouch_amount > config.crouched_at else "standing")
	if c.airborne:
		doing.append("in the air")
	if c.sprinting:
		doing.append("sprinting")
	if c.aiming:
		doing.append("aiming")
	var a := c.armament
	if a != null and a.replica() != null:
		if a.reloading():
			doing.append("reloading")
		if a.holstered:
			doing.append("holstered")
		var r := a.replica()
		var spares := 0
		if a.active < a.ammo.size():
			for m in a.ammo[a.active].pouch:
				if m > 0:
					spares += 1
		doing.append("%s %d/%d, %d spare" % [r.display_name, a.mag(), r.mag_size, spares])
	return ", ".join(doing)


## Dev settings: each switch changed from `fresh`'s, or "none".
static func dev_text(now: Dictionary, fresh: Dictionary) -> String:
	var changed := _changed(now, fresh, "", PackedStringArray())
	return ", ".join(changed) if not changed.is_empty() else BugReport.NONE


## Settings changed: every value that differs from a new player's (Settings.to_dict, nested ones as "hud.size"),
## enums by name, and the key bindings as a count; "none" when nothing differs.
static func settings_text(now: Dictionary, fresh: Dictionary) -> String:
	var changed := _changed(now, fresh, "", NOT_SETTINGS)
	var bound := bindings_changed(now.get("bindings", {}), fresh.get("bindings", {}))
	if bound > 0:
		changed.append("bindings %d changed" % bound)
	return ", ".join(changed) if not changed.is_empty() else BugReport.NONE


## How many actions' keys differ between two KeyBindings.to_dict.
static func bindings_changed(now: Variant, fresh: Variant) -> int:
	if not now is Dictionary or not fresh is Dictionary:
		return 0
	var n := 0
	for action: Variant in now:
		if now[action] != fresh.get(action):
			n += 1
	return n


## The newest `most` of `entries` (all when fewer).
static func newest(entries: PackedStringArray, most: int) -> PackedStringArray:
	return entries.slice(maxi(0, entries.size() - maxi(0, most)))


## The errors and warnings in a Godot log's lines, as ErrorLog words them ("SCRIPT ERROR res://a.gd:88 (_row): msg"),
## the place the first script frame when there is one, else the "at:" line's; a repeat of the newest counts up
## (" ×3" at its end, as ErrorLog's). The newest `most`, oldest first.
static func errors_in_log(lines: PackedStringArray, most: int) -> PackedStringArray:
	var out := PackedStringArray()
	var last := ""
	var repeats := 1
	var i := 0
	while i < lines.size():
		var text := lines[i].strip_edges()
		var type := _log_type(text)
		i += 1
		if type == "":
			continue
		var message := text.substr(type.length() + 2).strip_edges()
		var frame_place := ""
		var at_place := ""
		while i < lines.size() and lines[i].begins_with(" ") and _log_type(lines[i].strip_edges()) == "":
			var detail := lines[i].strip_edges()
			if detail.begins_with(LOG_FRAME) and frame_place == "":
				frame_place = detail.substr(LOG_FRAME.length())
			elif detail.begins_with(LOG_AT) and at_place == "":
				at_place = detail.substr(LOG_AT.length())
			i += 1
		var entry := "%s %s: %s" % [type, _place_words(frame_place if frame_place != "" else at_place), message]
		if entry == last:
			repeats += 1
			out[out.size() - 1] = "%s ×%d" % [entry, repeats]
			continue
		last = entry
		repeats = 1
		out.append(entry)
	return newest(out, most)


## This machine's System line, from the engine's own calls.
static func system_now() -> String:
	var os_name := OS.get_distribution_name() if OS.get_name() == "Linux" else OS.get_name()
	return system_text(os_name, OS.get_version_alias(), OS.get_version(), OS.get_processor_count(),
			int(OS.get_memory_info().get("physical", 0)))


## The machine's own facts, the same for a live report and a crash's (it is this machine that crashed).
static func _machine(info: BugReport.ReportInfo, settings: Settings) -> void:
	info.godot = godot_text(Engine.get_version_info())
	info.system = system_now()
	info.graphics_card = card_text(RenderingServer.get_video_adapter_name(), OS.get_video_adapter_driver_info())
	var machine := GraphicsApply.machine()
	var preset := String(settings.graphics_preset_on(machine.preset)) if settings != null else String(machine.preset)
	if settings != null and settings.graphics_choice == GraphicsQuality.CUSTOM:
		preset = String(GraphicsQuality.CUSTOM)
	info.renderer = renderer_text(RenderingServer.get_current_rendering_method(),
			RenderingServer.get_current_rendering_driver_name(), preset)
	if DisplayServer.get_name() != "headless":
		info.window = window_text(DisplayServer.window_get_mode(), DisplayServer.window_get_size(),
				DisplayServer.screen_get_refresh_rate())
	info.language = TranslationServer.get_locale()
	if settings != null:
		info.dev_settings = dev_text(settings.dev.to_dict(), DevSettings.new().to_dict())
		info.settings_changed = settings_text(settings.to_dict(), Settings.new(settings.tuning).to_dict())


## `prefix.key value` for each value of `now` that differs from `fresh`'s, nested dictionaries walked.
static func _changed(now: Dictionary, fresh: Dictionary, prefix: String, skip: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var keys := now.keys()
	keys.sort()
	for key: Variant in keys:
		var name := str(key)
		if skip.has(name):
			continue
		var v: Variant = now[key]
		var was: Variant = fresh.get(key)
		if v is Dictionary:
			out.append_array(_changed(v, was if was is Dictionary else {}, prefix + name + ".", PackedStringArray()))
		elif not _same(v, was):
			out.append("%s%s %s" % [prefix, name, _value_text(name, v)])
	return out


static func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


## A setting's value as a report gives it: enums by name, whole numbers without ".0", switches on or off.
static func _value_text(key: String, v: Variant) -> String:
	var names := _enum_names(key)
	if v is int and not names.is_empty():
		return str(names[v]).to_lower() if v >= 0 and v < names.size() else str(v)
	if v is bool:
		return ON if v else OFF
	if v is float and is_equal_approx(v, roundf(v)):
		return str(roundi(v))
	return str(v)


static func _enum_names(key: String) -> Array:
	match key:
		"team_colours":
			return TeamColours.Set.keys()
		"window_mode", "last_fullscreen":
			return Settings.WindowMode.keys()
		"what_got_you":
			return Settings.WhatGotYou.keys()
		"renderer":
			return Settings.Renderer.keys()
		"wheel_pick":
			return ControlsConfig.WheelPick.keys()
	return []


static func _log_type(text: String) -> String:
	for type in LOG_TYPES:
		if text.begins_with(type + ": "):
			return type
	return ""


## "func (res://a.gd:88)" as "res://a.gd:88 (func)"; anything else as it is.
static func _place_words(place: String) -> String:
	var open := place.rfind(" (")
	if open < 0 or not place.ends_with(")"):
		return place if place != "" else BugReport.UNKNOWN
	return "%s (%s)" % [place.substr(open + 2, place.length() - open - 3), place.left(open)]


## A record's value as text; "" for a missing or null one (the report then reads "-").
static func _text(v: Variant) -> String:
	return "" if v == null else str(v)


static func _whole(v: Variant) -> int:
	return maxi(int(v), 0) if v is int or v is float else 0

class_name BugReport
extends RefCounted
## The bug report's text (SV4), the browser game's layout as the step 22 pictures show it: the title, then one
## "Label: value" line a field ("-" for anything not known), then the lists, each entry indented under its label: Recent
## errors, Recent events and, for a crash, Last log lines. Pure over a ReportInfo (ReportFacts gathers one); every line
## goes through the info's ReportScrub. A Cut gives less of it, for Report a Bug's address (IssueLink): each list's
## newest entries only, and fields left out.

const TITLE := "Airsoft bug report"
const CRASH_TITLE := "Airsoft crash report"
const UNKNOWN := "-"
const NONE := "none"
const LEFT_OUT := "(left out to fit)"
const INDENT := "  "
const MORE := "…"
## A note is cut to this many times its length before it is scrubbed, at a word's end (a huge pasted note costs no
## more than a short one, and no part of a name is left to slip past the scrub), and to its length after.
const SCRUB_MARGIN := 2
## The field labels, in the report's order (Cut.drop and ReportConfig.drop_fields name them).
const NOTE := "Note"
const VERSION := "Version"
const GODOT := "Godot"
const SYSTEM := "System"
const GRAPHICS_CARD := "Graphics card"
const RENDERER := "Renderer"
const WINDOW := "Window"
const LANGUAGE := "Language"
const TIME := "Time"
const CLOSED := "Closed"
const SEED := "Seed"
const MATCH := "Match"
const ROUND := "Round"
const SCREEN := "Screen"
const PLAYER := "Player"
const FRAMES := "Frames"
const DEV_SETTINGS := "Dev settings"
const SETTINGS_CHANGED := "Settings changed"
const ERRORS := "Recent errors"
const EVENTS := "Recent events"
const LOG_LINES := "Last log lines"


## What a report says: plain values, each "" when not known, and the lists oldest first.
class ReportInfo:
	extends RefCounted
	## A crash report (the run before closed unexpectedly): Closed for Time, no Player, Frames or Recent events, and
	## Last log lines.
	var crash: bool = false
	## The player's note (one line in the report; the whole of it heads the issue), and how many characters of it the
	## report gives once scrubbed (0: all).
	var note: String = ""
	var note_chars: int = 0
	var version: String = ""
	var godot: String = ""
	var system: String = ""
	var graphics_card: String = ""
	var renderer: String = ""
	var window: String = ""
	var language: String = ""
	## When the report was made, or for a crash when the run closed; and how long after its start.
	var time: String = ""
	var seed_text: String = ""
	var match_text: String = ""
	var round_text: String = ""
	var screen: String = ""
	var player: String = ""
	var frames: String = ""
	var dev_settings: String = ""
	var settings_changed: String = ""
	var errors := PackedStringArray()
	var events := PackedStringArray()
	## A crash's old log: its last lines and how many it had.
	var log_lines := PackedStringArray()
	var log_count: int = 0
	## Takes names and folders out of every line; null for none (tests of the layout: ReportFacts and IssueLink always
	## give one).
	var scrub: ReportScrub = null


## How much of a report to give: each list's newest `keep` entries (-1: all) and the fields `drop` names left out.
class Cut:
	extends RefCounted
	var keep: int = -1
	var drop := PackedStringArray()

	func _init(keep_entries: int = -1, drop_fields: PackedStringArray = PackedStringArray()) -> void:
		keep = keep_entries
		drop = drop_fields


## The report's text, whole or as `cut` gives it; `scrub` in place of the info's when given.
static func write(info: ReportInfo, cut: Cut = null, scrub: ReportScrub = null) -> String:
	return "\n".join(write_lines(info, cut, scrub))


## The report's lines, whole or as `cut` gives it, each through `scrub` (else the info's).
static func write_lines(info: ReportInfo, cut: Cut = null, scrub: ReportScrub = null) -> PackedStringArray:
	var c := cut if cut != null else Cut.new()
	var by := scrub if scrub != null else info.scrub
	var out := PackedStringArray()
	out.append(CRASH_TITLE if info.crash else TITLE)
	var note := note_line(info, by)
	if note != "":
		out.append(note)
	_field(out, c, VERSION, info.version)
	_field(out, c, GODOT, info.godot)
	_field(out, c, SYSTEM, info.system)
	_field(out, c, GRAPHICS_CARD, info.graphics_card)
	_field(out, c, RENDERER, info.renderer)
	_field(out, c, WINDOW, info.window)
	_field(out, c, LANGUAGE, info.language)
	_field(out, c, CLOSED if info.crash else TIME, info.time)
	_field(out, c, SEED, info.seed_text)
	_field(out, c, MATCH, info.match_text)
	_field(out, c, ROUND, info.round_text)
	_field(out, c, SCREEN, info.screen)
	if not info.crash:
		_field(out, c, PLAYER, info.player)
		_field(out, c, FRAMES, info.frames)
	_field(out, c, DEV_SETTINGS, info.dev_settings)
	_field(out, c, SETTINGS_CHANGED, info.settings_changed)
	_list(out, c, ERRORS, info.errors)
	if info.crash:
		_log(out, c, info.log_lines, info.log_count)
	else:
		_list(out, c, EVENTS, info.events)
	return by.lines(out) if by != null else out


## The Note line, "" without a note: the note on one line, through `scrub` (else the info's), then cut to note_chars.
## Scrubbed before it is cut, so a cut can't leave part of a name ("Willia") that no longer matches.
static func note_line(info: ReportInfo, scrub: ReportScrub = null) -> String:
	var by := scrub if scrub != null else info.scrub
	var chars := info.note_chars * SCRUB_MARGIN
	var cut := info.note
	if info.note_chars > 0:
		cut = by.cut(info.note, chars) if by != null else ReportScrub.cut_whole(info.note, chars)
	var note := one_line(cut)
	if by != null:
		note = by.line(note)
	if info.note_chars > 0:
		note = note.left(info.note_chars)
	return "%s: %s" % [NOTE, note] if note != "" else ""


## `text` on one line: its runs of spaces, tabs and line breaks as one space, trimmed.
static func one_line(text: String) -> String:
	var words := text.strip_edges().split(" ", false)
	var out := PackedStringArray()
	for w in words:
		for part in w.replace("\t", "\n").replace("\r", "\n").split("\n", false):
			out.append(part)
	return " ".join(out)


## 4812 as "4,812".
static func thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


static func _field(out: PackedStringArray, cut: Cut, label: String, value: String) -> void:
	if cut.drop.has(label):
		out.append("%s: %s" % [label, LEFT_OUT])
	else:
		out.append("%s: %s" % [label, value if value != "" else UNKNOWN])


## "Recent errors (2):" and its entries; "(newest 3 of 30)" when cut, "none" when empty.
static func _list(out: PackedStringArray, cut: Cut, label: String, entries: PackedStringArray) -> void:
	var n := entries.size()
	if n == 0:
		out.append("%s: %s" % [label, NONE])
		return
	var keep := n if cut.keep < 0 else mini(cut.keep, n)
	if keep == n:
		out.append("%s (%d):" % [label, n])
	elif keep == 0:
		out.append("%s: %d %s" % [label, n, LEFT_OUT])
	else:
		out.append("%s (newest %d of %d):" % [label, keep, n])
	for i in range(n - keep, n):
		out.append(INDENT + entries[i].trim_suffix("\r"))


## "Last log lines (last 40 of 4,812):", a "…" when the log was longer, and the lines.
static func _log(out: PackedStringArray, cut: Cut, lines: PackedStringArray, count: int) -> void:
	var n := lines.size()
	if n == 0:
		out.append("%s: %s" % [LOG_LINES, UNKNOWN])
		return
	var keep := n if cut.keep < 0 else mini(cut.keep, n)
	var total := maxi(count, n)
	if keep == 0:
		out.append("%s: %s lines, %s" % [LOG_LINES, thousands(total), LEFT_OUT])
		return
	out.append("%s (last %d of %s):" % [LOG_LINES, keep, thousands(total)])
	if keep < total:
		out.append(INDENT + MORE)
	for i in range(n - keep, n):
		out.append(INDENT + lines[i].trim_suffix("\r"))

class_name LogTail
extends RefCounted
## The last log (SV3): the end of the previous run's log, for the crash screen and the bug report. Godot writes each
## run's output to user://logs/godot.log (debug/file_logging, desktop) and at each start renames the last one to
## godot<date>T<time>.log, keeping a few; so godot.log is this run's and the newest renamed one the run before, unless
## that one is the safe start's own restart (it holds RESTART_LINE): the run that crashed is then one
## further back (SV6). Read once, and only when asked: only each log's last TAIL_BYTES are read and decoded, for its last
## LINES lines and the errors a crash report names, and the one taken has its lines counted over the rest of the file a
## piece at a time (natively, as bytes), so no log is held whole.

const DIR := "user://logs"
## This run's log, never the previous one.
const CURRENT := "godot.log"
const PREFIX := "godot"
const SUFFIX := ".log"
## The line the safe start (GraphicsStartUp) prints in the log of the start it restarts: that short log is passed over
## for the crashed run's.
const RESTART_LINE := "[boot] the last start closed while drawing: restarting on the simpler renderer and Low"
## How many lines from the end are kept.
const LINES := 40
## How much of the log's end is decoded into lines (bytes): the last lines and the errors a crash report names.
const TAIL_BYTES := 262144
## How much of the log before that is read at a time to count its lines (bytes).
const COUNT_BYTES := 1048576
const NEWLINE := 10

## The folder to look in (tests point it at their own).
var dir: String = DIR
## A log holding this line, as a whole line, is passed over for the one before it ("" passes over none).
var skip_line: String = RESTART_LINE
var _read: bool = false
var _path: String = ""
var _tail := PackedStringArray()
var _recent := PackedStringArray()
var _count: int = 0


## The previous run's log: the newest renamed godot*.log in `dir` (the names sort by date and time) not holding
## `skip_line`, "" when none.
func path() -> String:
	_read_once()
	return _path


## Its last LINES lines (fewer if it is shorter), oldest first; empty when there is none.
func lines() -> PackedStringArray:
	_read_once()
	return _tail


## Its whole lines within its last TAIL_BYTES, oldest first; empty when there is none.
func recent_lines() -> PackedStringArray:
	_read_once()
	return _recent


## How many lines it had, 0 when there is none.
func line_count() -> int:
	_read_once()
	return _count


func _read_once() -> void:
	if _read:
		return
	_read = true
	for f in _logs():
		var p := dir.path_join(f)
		var file := FileAccess.open(p, FileAccess.READ)
		if file == null:
			continue
		var size := file.get_length()
		var start := maxi(0, size - TAIL_BYTES)
		file.seek(start)
		var bytes := file.get_buffer(size - start)
		var cut := 0
		# a cut lands past the next newline, so no line (nor a character) is decoded in part
		if start > 0:
			var after := bytes.find(NEWLINE)
			cut = after + 1 if after >= 0 else bytes.size()
		var recent := bytes.slice(cut).get_string_from_utf8().split("\n")
		# a last line ended with a newline leaves an empty piece behind it
		if not recent.is_empty() and recent[recent.size() - 1] == "":
			recent.resize(recent.size() - 1)
		if _holds_skip(recent):
			continue
		_path = p
		_recent = recent
		_count = bytes.count(NEWLINE) + _newlines_before(file, start)
		if not bytes.is_empty() and bytes[bytes.size() - 1] != NEWLINE:
			_count += 1
		_tail = recent.slice(maxi(0, recent.size() - LINES))
		return


## The newlines in `file`'s first `end` bytes, counted COUNT_BYTES at a time (natively, as bytes), so a long log is
## never held whole.
static func _newlines_before(file: FileAccess, end: int) -> int:
	var count := 0
	file.seek(0)
	while file.get_position() < end:
		var piece := file.get_buffer(mini(COUNT_BYTES, end - file.get_position()))
		# a log cut short meanwhile ends the count rather than looping on nothing
		if piece.is_empty():
			break
		count += piece.count(NEWLINE)
	return count


func _holds_skip(lines: PackedStringArray) -> bool:
	if skip_line == "":
		return false
	for line in lines:
		if line.strip_edges() == skip_line:
			return true
	return false


## The renamed logs in `dir`, newest first.
func _logs() -> PackedStringArray:
	var found := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return found
	for f in DirAccess.get_files_at(dir):
		if f != CURRENT and f.begins_with(PREFIX) and f.ends_with(SUFFIX):
			found.append(f)
	found.sort()
	found.reverse()
	return found

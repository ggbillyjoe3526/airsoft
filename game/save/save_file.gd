class_name SaveFile
## Crash-safe JSON files, from the owner's katanashotgun project (owner, 2026-10-18). A file is one header line,
## "ASAVE <kind> <version> <sha256 of the payload>", then the JSON payload.
## Writes go to <path>.tmp first and are read back and checked before the old
## file is rotated to <path>.bak, so a crash or a full disk at any point leaves
## at least one good copy. Loading tries .tmp (a finished write that never got
## renamed), then the file, then the backup; a copy whose checksum fails is
## skipped, never trusted.
## After the save is replaced (SaveKeeper: a restore, Undo or delete), `hold` keeps its files from being written,
## removed or set aside for the rest of the run, so nothing the running game still holds writes over the new save
## before the restart. `last_failure` is the newest write that failed, for the Save file tab's warning.

## A write that failed: the file and when (Unix seconds).
class Failure:
	extends RefCounted
	var path: String = ""
	var time: float = 0.0


## Every copy of one file as it was (`snapshot`), to put back byte for byte (`put_back`). `ok` is false when a copy
## that exists couldn't be read, so it can't be put back.
class Snapshot:
	extends RefCounted
	var path: String = ""
	var copies: Dictionary[String, PackedByteArray] = {}
	var ok: bool = true


const MAGIC := "ASAVE"
const TMP := ".tmp"
const BAK := ".bak"
const SUFFIXES: Array[String] = ["", TMP, BAK]
## A copy being put back is written here first, beside it, then renamed.
const PUT := ".put"
## Whole numbers up to this size are written as integers (a double holds every integer up to 2^53 exactly).
const MAX_EXACT := 9007199254740992.0

## The newest write that failed, or null; a later good write of the same file clears it.
static var last_failure: Failure = null
static var _held: Dictionary[String, bool] = {}


## The payload as written: JSON with sorted keys, whole numbers as integers. JSON reads every number back as a float,
## so the payload of data read back from a file is the file's own payload, byte for byte (a restore point keeps it).
static func payload(data: Dictionary) -> String:
	return JSON.stringify(_plain(data), "  ")


static func encode(kind: String, version: int, data: Dictionary) -> String:
	var text := payload(data)
	return "%s %s %d %s\n%s" % [MAGIC, kind, version, text.sha256_text(), text]


## Parses one file's text. Returns {ok, version, data} or {ok: false, error}.
static func decode(text: String, kind: String) -> Dictionary:
	var nl := text.find("\n")
	if nl < 0:
		return {"ok": false, "error": "no header"}
	var head := text.substr(0, nl).split(" ")
	var payload := text.substr(nl + 1)
	if head.size() != 4 or head[0] != MAGIC:
		return {"ok": false, "error": "not a save file"}
	if head[1] != kind:
		return {"ok": false, "error": "wrong kind %s" % head[1]}
	if not head[2].is_valid_int():
		return {"ok": false, "error": "bad version"}
	if payload.sha256_text() != head[3]:
		return {"ok": false, "error": "checksum mismatch"}
	var data: Variant = JSON.parse_string(payload)
	if not data is Dictionary:
		return {"ok": false, "error": "payload is not an object"}
	return {"ok": true, "version": int(head[2]), "data": data}


static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## Writes atomically and keeps one backup. Returns false (and leaves the old
## file untouched) if the new copy could not be written and verified.
## A held file (`hold`) is never written: logged, false.
static func write(path: String, kind: String, version: int, data: Dictionary) -> bool:
	if _refuse_held(path, "written"):
		return false
	var text := encode(kind, version, data)
	var tmp := path + TMP
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save: can't open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		_failed(path)
		return false
	f.store_string(text)
	f.flush()
	var err := f.get_error()
	f.close()
	# read it back: a full disk can leave a short file without reporting it, and a kind with a space would make a
	# header decode() refuses
	if err != OK or read_text(tmp) != text or not decode(text, kind).ok:
		push_warning("save: %s did not write cleanly" % tmp)
		DirAccess.remove_absolute(tmp)
		_failed(path)
		return false
	if FileAccess.file_exists(path):
		if decode(read_text(path), kind).ok:
			# the current file is good: it becomes the backup
			if FileAccess.file_exists(path + BAK):
				DirAccess.remove_absolute(path + BAK)
			DirAccess.rename_absolute(path, path + BAK)
		else:
			# a damaged file never replaces a good backup
			DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(tmp, path) != OK:
		# the verified .tmp stays on disk and read() still finds it
		push_warning("save: can't rename %s" % tmp)
		_failed(path)
		return false
	if last_failure != null and last_failure.path == path:
		last_failure = null
	return true


## Loads the newest good copy. Returns {ok, version, data, source} where
## source is "tmp", "main" or "backup", or {ok: false, found} when no copy is
## good (found says whether any file existed at all).
static func read(path: String, kind: String) -> Dictionary:
	var found := false
	var copies: Array[String] = [path + TMP, path, path + BAK]
	var sources: Array[String] = ["tmp", "main", "backup"]
	for i in copies.size():
		var text := read_text(copies[i])
		if text == "":
			found = found or FileAccess.file_exists(copies[i])
			continue
		found = true
		var r := decode(text, kind)
		if r.ok:
			r["source"] = sources[i]
			return r
		push_warning("save: skipping %s (%s)" % [copies[i], r.error])
	return {"ok": false, "found": found}


## Moves every copy aside as <path>.corrupt-<n> so a fresh file can be written
## without destroying anything a player might want recovered.
static func quarantine(path: String) -> void:
	if _refuse_held(path, "set aside"):
		return
	# microseconds since start too, so two quarantines in the same millisecond don't collide
	var stamp := "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	for suffix: String in SUFFIXES:
		if FileAccess.file_exists(path + suffix):
			DirAccess.rename_absolute(path + suffix, "%s%s.corrupt-%s" % [path, suffix, stamp])


## Deletes every copy. True when none is left; false for a held file or a copy that wouldn't go.
static func remove(path: String) -> bool:
	if _refuse_held(path, "removed"):
		return false
	var ok := true
	for suffix: String in SUFFIXES:
		if FileAccess.file_exists(path + suffix) and DirAccess.remove_absolute(path + suffix) != OK:
			push_warning("save: can't remove %s" % (path + suffix))
			ok = false
	return ok


## Makes an empty file at `path`, a mark whose name is all it says (RunRecord's clean quit). False for a held path or
## one that can't be made. A mark goes as any save does (`remove`).
static func touch(path: String) -> bool:
	if _refuse_held(path, "marked"):
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	return true


## Keeps `paths` from being written, removed or set aside for the rest of the run (the save was replaced and the
## game restarts to read it).
static func hold(paths: PackedStringArray) -> void:
	for path: String in paths:
		_held[path] = true
	print("[save] held until the restart: %s" % ", ".join(paths))


static func held(path: String) -> bool:
	return _held.has(path)


## Tests: lets `paths` be written again.
static func release(paths: PackedStringArray) -> void:
	for path: String in paths:
		_held.erase(path)


## Every copy of `path` as it is now.
static func snapshot(path: String) -> Snapshot:
	var snap := Snapshot.new()
	snap.path = path
	for suffix: String in SUFFIXES:
		if not FileAccess.file_exists(path + suffix):
			continue
		var bytes := FileAccess.get_file_as_bytes(path + suffix)
		if FileAccess.get_open_error() != OK:
			push_warning("save: can't read %s to keep it" % (path + suffix))
			snap.ok = false
		snap.copies[suffix] = bytes
	return snap


## Puts every copy back as `snap` found it, byte for byte: a copy it didn't find is removed, one unchanged is left. Only
## bytes this class wrote are put back (contract 8). Each copy is written beside it and renamed. False if any copy
## couldn't be.
static func put_back(snap: Snapshot) -> bool:
	if not snap.ok or _refuse_held(snap.path, "put back"):
		return false
	var ok := true
	for suffix: String in SUFFIXES:
		var copy := snap.path + suffix
		if not snap.copies.has(suffix):
			if FileAccess.file_exists(copy) and DirAccess.remove_absolute(copy) != OK:
				ok = false
			continue
		if FileAccess.file_exists(copy) and FileAccess.get_file_as_bytes(copy) == snap.copies[suffix]:
			continue # unchanged
		ok = _put(copy, snap.copies[suffix]) and ok
	if not ok:
		push_warning("save: couldn't put every copy of %s back" % snap.path)
	return ok


static func _put(copy: String, bytes: PackedByteArray) -> bool:
	var f := FileAccess.open(copy + PUT, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	if FileAccess.get_file_as_bytes(copy + PUT) != bytes:
		DirAccess.remove_absolute(copy + PUT)
		return false
	if FileAccess.file_exists(copy):
		DirAccess.remove_absolute(copy)
	return DirAccess.rename_absolute(copy + PUT, copy) == OK


static func _refuse_held(path: String, what: String) -> bool:
	if not _held.has(path):
		return false
	push_warning("save: %s is held until the restart; not %s" % [path, what])
	return true


static func _failed(path: String) -> void:
	last_failure = Failure.new()
	last_failure.path = path
	last_failure.time = Time.get_unix_time_from_system()


## `data` with every whole number an integer, nested dictionaries and arrays too.
static func _plain(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var f: float = value
			if is_finite(f) and f == floorf(f) and absf(f) <= MAX_EXACT:
				return int(f)
			return f
		TYPE_DICTIONARY:
			var d: Dictionary = value
			var out := {}
			for key: Variant in d:
				out[key] = _plain(d[key])
			return out
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var out: Array = []
			for item: Variant in value:
				out.append(_plain(item))
			return out
	return value

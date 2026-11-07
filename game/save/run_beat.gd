class_name RunBeat
extends RefCounted
## The running game's heartbeat (BP7): every RunRecord.BEAT_SECONDS its process id and the time, written off the main
## thread (WorkerThreadPool) so a match never waits on the disk. Two small files beside the run record, written in
## turn: a write cut short spoils only the one being written, and a reader takes the newer of the two that read whole.
## RunRecord and GraphicsGuard read it to tell a copy still running from a crashed run whose process id another copy
## has since (a reboot, say).

const HEAD := "airsoft-beat"

var _base: String = ""
var _next: int = 0
var _task: int = -1


## A heartbeat for the run whose record is at `record_path`.
func _init(record_path: String) -> void:
	_base = record_path


## Writes `pid` beating at `now` (Unix s) on a worker thread; skipped while the last write is still going.
func beat(pid: int, now: int) -> void:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = WorkerThreadPool.add_task(_write.bind(file_of(_base, _next), pid, now), false, "RunBeat")
	_next = 1 - _next


## Waits for a write under way (on the way out).
func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Beat file `which` (0 or 1) of the record at `record_path`.
static func file_of(record_path: String, which: int) -> String:
	return "%s.beat%d" % [record_path, which]


## The newest whole beat beside the record at `record_path`: [process id, time (Unix s)], both 0 for none.
static func read(record_path: String) -> PackedInt64Array:
	var best := PackedInt64Array([0, 0])
	for which in 2:
		var path := file_of(record_path, which)
		if not FileAccess.file_exists(path):
			continue
		var parts := FileAccess.get_file_as_string(path).split(" ", false)
		if parts.size() != 3 or parts[0] != HEAD or not parts[1].is_valid_int() or not parts[2].is_valid_int():
			continue
		var pid := parts[1].to_int()
		var at := parts[2].to_int()
		if pid > 0 and at > best[1]:
			best = PackedInt64Array([pid, at])
	return best


## Takes both beat files away (tests).
static func remove(record_path: String) -> void:
	for which in 2:
		var path := file_of(record_path, which)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


static func _write(path: String, pid: int, now: int) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("%s %d %d" % [HEAD, pid, now])
	f.close()

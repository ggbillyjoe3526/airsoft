class_name RunRecord
extends RefCounted
## The run record (SV3): what the game is doing, kept on disk so the next start knows whether the last run closed
## cleanly and, if not, where it was. Pure over its record, which SaveFile keeps at PATH; the entry scene does the files
## (game/main.gd). A start writes RUNNING with the version, the start time and the process; Play writes the match (or
## practice its map), each round start the round and score, leaving play the menus, and a clean quit CLOSED. A start
## that finds RUNNING from a process no longer running keeps that run as `previous`: the last run closed unexpectedly
## (a crash, a freeze closed by hand, a power cut). RUNNING from a process still running is a second copy beside the
## first: it leaves the record alone, unless its heartbeat (the record's `beat`, or the newer one RunBeat writes beside
## it every BEAT_SECONDS) is over STALE_SECONDS old, when another copy of the game has the crashed run's id since (a
## reboot, say) and it is a crash. `previous` stays until the crash screen has shown it (SV6); a newer crash replaces it. Not kept for the smoke run, headless runs or an editor run (main.gd), and started after the safe start
## (GraphicsGuard), so its own restart never counts as a crash and the restarted start sees the run that crashed.

const PATH := "user://run.save"
const KIND := "run"
const VERSION := 1
## CLOSED: the last run quit cleanly (or there was none). RUNNING: a run is under way, or closed without saying so.
enum State { CLOSED, RUNNING }
const STATE_NAMES: Array[String] = ["closed", "running"]
## Where the run is: on the title or in the menus, in a match, on the range.
const MENUS := "menus"
const MATCH := "match"
const PRACTICE := "practice"
const PLACES: Array[String] = [MENUS, MATCH, PRACTICE]
## How often a running game writes its heartbeat (s, game/main.gd through RunBeat, off the main thread), and how old
## one is when no game is beating it.
const BEAT_SECONDS := 10.0
const STALE_SECONDS := 60

var state: State = State.CLOSED
## Version.current() of the run.
var version: String = ""
## When the run started (Unix time, s).
var started: int = 0
## The process that wrote the record (OS.get_process_id), 0 when not known.
var pid: int = 0
## The run's last heartbeat (Unix time, s): its start, then every BEAT_SECONDS while it runs (a record from before BP7
## reads its start).
var beat: int = 0
## MENUS, MATCH or PRACTICE.
var place: String = MENUS
## The match (MATCH: seed, map, mode, rules, team, difficulties, team sizes; see `play`) or the range (PRACTICE: map);
## empty in the menus.
var match_facts: Dictionary = {}
## The round under way in a match (0 before the first) and the score as it started (Alpha, Beta).
var round_number: int = 0
var score: Array[int] = []
## The run before this one, as it was when it closed unexpectedly (this record's fields, without its own `previous`);
## empty when the last run closed cleanly or the crash screen has shown it.
var previous: Dictionary = {}
## Whose record the file holds as far as this run knows (not saved): the run read from it or last written to it, and
## whether that one is under way. A start whose own write failed leaves the run before it there, so its clean quit
## marks that run, the one the next start will read.
var _disk_pid: int = 0
var _disk_started: int = 0
var _disk_running: bool = false


## The record at `path`: a missing or damaged file is a closed one (nothing to recover from), and so is a run under
## way with its clean quit's mark beside it (`save_closed`), the mark then gone.
static func load_file(path: String = PATH) -> RunRecord:
	var r := RunRecord.new()
	var read := SaveFile.read(path, KIND)
	if read.ok:
		r.from_dict(read.data)
	elif read.found:
		push_warning("run record: %s is damaged; starting as closed" % path)
	var mark := closed_mark(path, r.pid, r.started)
	if r.state == State.RUNNING and FileAccess.file_exists(mark):
		# the mark stays until a newer run's record is written over this one (`save` sweeps it): a start that can't
		# write leaves this record, and its mark, for the next start to read
		r.state = State.CLOSED
	r._disk_pid = r.pid
	r._disk_started = r.started
	r._disk_running = r.state == State.RUNNING
	return r


## The empty file a clean quit leaves beside `path` when it can't write the record: named for the run (its process
## and start), as a full disk may still take a name but no bytes, and a locked record leaves its folder free.
static func closed_mark(path: String, run_pid: int, run_started: int) -> String:
	return "%s.closed-%d-%d" % [path, run_pid, run_started]


## The record written to `path`. The first write of a run over another run's record sweeps every closed mark beside
## it: they name runs whose records are gone, and would otherwise pile up.
func save(path: String = PATH) -> bool:
	if not SaveFile.write(path, KIND, VERSION, to_dict()):
		return false
	var newer := _disk_pid != pid or _disk_started != started
	_disk_pid = pid
	_disk_started = started
	_disk_running = state == State.RUNNING
	if newer:
		sweep_marks(path)
	return true


## Takes away every closed mark beside `path` (closed_mark's, whatever run it names). False if one stays.
static func sweep_marks(path: String) -> bool:
	var dir := path.get_base_dir()
	var prefix := path.get_file() + ".closed-"
	var ok := true
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(prefix) and not SaveFile.remove(dir.path_join(f)):
			ok = false
	return ok


func to_dict() -> Dictionary:
	var d := _run_dict()
	d["previous"] = previous.duplicate(true)
	return d


## Each value checked on its own: an unknown state reads as closed, an unknown place as the menus.
func from_dict(data: Dictionary) -> void:
	var at := STATE_NAMES.find(str(data.get("state", "")))
	state = (at if at >= 0 else State.CLOSED) as State
	var v: Variant = data.get("version")
	version = v if v is String else ""
	started = _whole(data.get("started"))
	pid = _whole(data.get("pid"))
	beat = _whole(data.get("beat")) if data.has("beat") else started
	var where: Variant = data.get("place")
	place = where if where is String and PLACES.has(where) else MENUS
	var facts: Variant = data.get("match")
	match_facts = (facts as Dictionary).duplicate(true) if facts is Dictionary else {}
	round_number = _whole(data.get("round"))
	score = []
	var s: Variant = data.get("score")
	if s is Array:
		for n: Variant in s:
			score.append(_whole(n))
	var kept: Variant = data.get("previous")
	previous = (kept as Dictionary).duplicate(true) if kept is Dictionary else {}


## Whether a run under way belongs to another copy of the game, still running (`running` says whether a process id
## is) and beating (its heartbeat at most STALE_SECONDS before `now`, Unix s): a second copy opened beside the first,
## not a crash. `seen` is RunBeat.read's newest beat beside the record, counted when it is this run's process's. A
## heartbeat ahead of `now` (the clock set back) is fresh.
func held_by_other(me: int, running: Callable, now: int, seen: PackedInt64Array = PackedInt64Array()) -> bool:
	if state != State.RUNNING or pid <= 0 or pid == me:
		return false
	var last := maxi(beat, seen[1]) if seen.size() == 2 and seen[0] == pid else beat
	return now - last <= STALE_SECONDS and bool(running.call(pid))


## The heartbeat: the run is still going at `now` (Unix s). Write it after (`save`).
func heartbeat(now: int) -> void:
	beat = now


## A start: `version`, the time (Unix s) and this process. A run still RUNNING closed unexpectedly and becomes
## `previous`. Write it before anything else (after the safe start).
func start(run_version: String, now: int, me: int) -> void:
	if state == State.RUNNING:
		previous = _run_dict()
	state = State.RUNNING
	version = run_version
	started = now
	pid = me
	beat = now
	_to(MENUS, {})


## Play: the match as the entry scene set it up. `match_seed` is the seed it gave the match, kept as text (a whole number
## past 2^53 would not survive JSON); `rules` its Custom rules (CustomRules.to_dict), empty for the mode's own;
## `team_sizes` Alpha's and Beta's.
func play(match_seed: int, map: String, mode: String, rules: Dictionary, team: int, difficulty: String,
		teammates: String, team_sizes: Array[int]) -> void:
	_to(MATCH, {"seed": str(match_seed), "map": map, "mode": mode, "rules": rules.duplicate(true), "team": team,
			"difficulty": difficulty, "teammates": teammates, "team_sizes": team_sizes.duplicate()})


## Practice on `map`.
func practise(map: String) -> void:
	_to(PRACTICE, {"map": map})


## A round started: its number and the score it started on (Alpha, Beta).
func round_started(number: int, round_score: PackedInt32Array) -> void:
	round_number = number
	score.clear()
	for n in round_score:
		score.append(n)


## Left play: back on the title or in the menus.
func to_menus() -> void:
	_to(MENUS, {})


## A clean quit.
func close() -> void:
	state = State.CLOSED


## A clean quit, written to `path`, so the next start doesn't take it for a crash. If the write fails (a full disk, a
## locked file) the closed mark goes beside it instead, for the run whose record the file still holds (this run's, or
## the one before it when this run's start couldn't write), and failing that the record's files go (a missing record
## reads as closed; `previous` goes with them). A file holding no run under way needs neither. Whether the next start
## will read the run as closed.
func save_closed(path: String = PATH) -> bool:
	close()
	if save(path):
		return true
	return _mark_disk_closed(path)


## The crash screen has shown `previous`: it is forgotten and the record written. If that can't be written the record on
## disk still tells of the crash, so it is marked closed as a clean quit's is (its mark, failing that its removal), or
## the next start would show the crash again, and so on for as long as the folder takes no file. Whether the next start
## will not show it again; false where nothing can be written, or where the record on disk is already this run's (it
## still names the seen crash, and no mark can say otherwise without hiding a crash of this run), which is warned of.
func crash_seen(path: String = PATH) -> bool:
	previous = {}
	if save(path):
		return true
	# Only the run before this one is marked. Once this run's own record is on disk (the start's write worked, this one
	# did not) the mark would be this run's, and a crash of this run would then read as a clean quit.
	if _disk_pid == pid and _disk_started == started:
		return false
	return _mark_disk_closed(path)


## When `save` failed: the record on disk, if it holds a run under way, made to read as closed by the empty mark named
## for that run, failing that by taking the record's files away (a missing record reads as closed). A file holding no run
## under way needs neither. Whether the next start will read the run as closed.
func _mark_disk_closed(path: String) -> bool:
	if not _disk_running:
		return true
	if SaveFile.touch(closed_mark(path, _disk_pid, _disk_started)):
		push_warning("run record: %s not written; its clean quit marked beside it" % path)
		return true
	push_warning("run record: %s not written nor marked; taking it away" % path)
	return SaveFile.remove(path)


## Whether the last run closed unexpectedly (and the crash screen hasn't shown it yet).
func crashed_before() -> bool:
	return not previous.is_empty()


func _to(where: String, facts: Dictionary) -> void:
	place = where
	match_facts = facts
	round_number = 0
	score.clear()


## The run's own fields (to_dict without `previous`).
func _run_dict() -> Dictionary:
	return {"state": STATE_NAMES[state], "version": version, "started": started, "pid": pid, "beat": beat,
			"place": place,
			"match": match_facts.duplicate(true), "round": round_number, "score": score.duplicate()}


## A JSON number as a whole number of 0 or more; anything else 0.
static func _whole(v: Variant) -> int:
	return maxi(int(v), 0) if v is int or v is float else 0

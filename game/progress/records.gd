class_name Records
extends RefCounted
## Local records (the browser game's stats/records.ts): wins and losses per difficulty and mode, the best match accuracy,
## the longest run of match wins and the timed challenge's best per course. Records only, never levels or unlocks. Saved
## through SaveFile at user://records.save (kind "records", version 2), apart from the settings, loadouts and progress;
## a damaged file is set aside and empty records used, one from a newer build is never written over. Fields this build
## doesn't know are kept. Version 1 is read with its levels moved up (LEVELS_BEFORE_2).

const PATH := "user://records.save"
const KIND := "records"
const VERSION := 2
## Version 1's difficulty ids as they read since the bots' levels moved up a name (owner, 2026-10-25): each record stays
## with the bots it was won against. Easy's and old Normal's results, both now Easy's bots or easier, add up; an id not
## here (Custom, one this build doesn't know) is kept as it is.
const LEVELS_BEFORE_2: Dictionary[String, String] = {"easy": "easy", "normal": "easy", "hard": "normal", "pro": "hard"}
const KNOWN_KEYS: Array[String] = ["results", "best_accuracy", "streak", "best_streak", "best_challenge"]
## A match counts towards best accuracy only with at least this many BBs fired, so three lucky shots aren't a record
## (the browser game's minBBsForAccuracyRecord).
const ACCURACY_MIN_BBS := 30
## "normal.elimination" or "hard.attack_defend": a difficulty and a mode id (MatchOptions.MODES, "_" and all).
const RESULT_KEY_PATTERN := "^[a-z][a-zA-Z0-9]*\\.[a-z][a-zA-Z0-9_]*$"
## "range": a timed challenge course (RangeChallenge.course, a map's id).
const COURSE_PATTERN := "^[a-z][a-zA-Z0-9]*\\z"


## A finished match, as the records see it.
class Result:
	extends RefCounted
	var difficulty: StringName = &"normal"
	var mode: String = "elimination"
	var won: bool = false
	var hits: int = 0
	var bbs_fired: int = 0


## What a match changed, for "new record" tags: which bests it beat, and the best accuracy before it (-1: none).
class News:
	extends RefCounted
	var best_accuracy: bool = false
	var best_streak: bool = false
	var was_accuracy: float = -1.0


## Wins and losses by "<difficulty>.<mode>", each [wins, losses].
var results: Dictionary[String, PackedInt32Array] = {}
## Best share of BBs on an opponent in one match (0..1); -1 before one with enough BBs fired.
var best_accuracy: float = -1.0
## Match wins in a row now, and the most ever.
var streak: int = 0
var best_streak: int = 0
## The timed challenge's best (lit targets hit in one run) by course (M93); absent from files saved before it.
var best_challenge: Dictionary[String, int] = {}
var dirty: bool = false
var load_message: String = ""
var _newer_on_disk: bool = false
var _extra: Dictionary = {}
var _key_pattern: RegEx = RegEx.create_from_string(RESULT_KEY_PATTERN)
var _course_pattern: RegEx = RegEx.create_from_string(COURSE_PATTERN)

static var _shared: Records = null


static func shared() -> Records:
	if _shared == null:
		_shared = Records.new()
		_shared.load_file()
	return _shared


static func result_key(difficulty: StringName, mode: String) -> String:
	return "%s.%s" % [difficulty, mode]


## Adds a finished match; returns which bests it beat.
func add(r: Result) -> News:
	var news := News.new()
	var key := result_key(r.difficulty, r.mode)
	var wl: PackedInt32Array = results.get(key, PackedInt32Array([0, 0]))
	wl[0 if r.won else 1] += 1
	results[key] = wl
	if r.won:
		streak += 1
		if streak > best_streak:
			best_streak = streak
			news.best_streak = true
	else:
		streak = 0
	if r.bbs_fired >= ACCURACY_MIN_BBS:
		var acc := clampf(float(r.hits) / r.bbs_fired, 0.0, 1.0)
		if acc > best_accuracy:
			news.was_accuracy = best_accuracy
			best_accuracy = acc
			news.best_accuracy = true
	dirty = true
	return news


## The timed challenge's best on `course` (0 before a run is kept).
func challenge_best(course: String) -> int:
	return best_challenge.get(course, 0)


## A finished timed challenge run on `course`: kept if it beats the best and no Dev setting that changes play was on
## during it (RangeChallenge.Run.helped); true when it was.
func add_challenge_run(course: String, run: RangeChallenge.Run) -> bool:
	if run.helped or run.hits <= challenge_best(course) or _course_pattern.search(course) == null:
		return false
	best_challenge[course] = run.hits
	dirty = true
	return true


## Wins and losses at `difficulty` in `mode`: [wins, losses].
func win_loss(difficulty: StringName, mode: String) -> PackedInt32Array:
	return results.get(result_key(difficulty, mode), PackedInt32Array([0, 0]))


func load_file(path: String = PATH) -> void:
	load_message = ""
	_newer_on_disk = false
	var r := SaveFile.read(path, KIND)
	if not r.ok:
		if r.found:
			load_message = TranslationServer.translate("RECORDS_DAMAGED")
			push_warning("records: %s is damaged; starting empty" % path)
			SaveFile.quarantine(path)
		return
	if int(r.version) < 1 or int(r.version) > VERSION:
		load_message = TranslationServer.translate("RECORDS_NEWER")
		push_warning("records: %s is version %d; it is kept and not written over" % [path, int(r.version)])
		_newer_on_disk = int(r.version) > VERSION
		return
	for p in from_dict(r.data):
		push_warning("records: " + p)
	if int(r.version) < 2:
		move_levels_up()


## Version 1's results under the level names they read by now (LEVELS_BEFORE_2); silent, as the player lost nothing.
func move_levels_up() -> void:
	var moved: Dictionary[String, PackedInt32Array] = {}
	for key: String in results:
		var dot := key.find(".")
		var level := key.substr(0, dot)
		var now := result_key(StringName(LEVELS_BEFORE_2.get(level, level)), key.substr(dot + 1))
		var wl: PackedInt32Array = moved.get(now, PackedInt32Array([0, 0]))
		wl[0] += results[key][0]
		wl[1] += results[key][1]
		moved[now] = wl
	results = moved


func save(path: String = PATH) -> bool:
	if _newer_on_disk:
		return false
	var ok := SaveFile.write(path, KIND, VERSION, to_dict())
	dirty = not ok
	if ok:
		# the file is good again: what was wrong with the last one is said no more
		load_message = ""
	return ok


func save_if_dirty(path: String = PATH) -> void:
	if dirty:
		save(path)


func to_dict() -> Dictionary:
	var out := _extra.duplicate(true)
	var res := {}
	for key: String in results:
		res[key] = [results[key][0], results[key][1]]
	out["results"] = res
	out["best_accuracy"] = best_accuracy if best_accuracy >= 0.0 else null
	out["streak"] = streak
	out["best_streak"] = best_streak
	out["best_challenge"] = best_challenge.duplicate()
	return out


## Takes saved values, each checked on its own; what won't do is listed and left out.
func from_dict(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	_extra = {}
	for k: Variant in data:
		if not KNOWN_KEYS.has(str(k)):
			_extra[k] = data[k]
	results = {}
	var res: Variant = data.get("results")
	if res is Dictionary:
		for key: Variant in res:
			var pair: Variant = res[key]
			if not key is String or _key_pattern.search(key) == null or not pair is Array or (pair as Array).size() != 2 \
					or _count(pair[0]) < 0 or _count(pair[1]) < 0:
				problems.append("a result \"%s\" won't do: left out" % str(key))
				continue
			results[key] = PackedInt32Array([_count(pair[0]), _count(pair[1])])
	var acc: Variant = data.get("best_accuracy")
	best_accuracy = clampf(float(acc), 0.0, 1.0) if (acc is float or acc is int) and float(acc) >= 0.0 else -1.0
	streak = maxi(0, _count(data.get("streak")))
	best_streak = maxi(streak, _count(data.get("best_streak")))
	# The timed challenge's bests: absent from older files; a course this build doesn't know is kept.
	best_challenge = {}
	var challenge: Variant = data.get("best_challenge")
	if challenge is Dictionary:
		for course: Variant in challenge:
			if not course is String or _course_pattern.search(course) == null or _count(challenge[course]) < 0:
				problems.append("a timed challenge best \"%s\" won't do: left out" % str(course))
			elif _count(challenge[course]) > 0:
				best_challenge[course] = _count(challenge[course])
	dirty = false
	return problems


## A whole number from 0, or -1.
static func _count(v: Variant) -> int:
	if (v is int or v is float) and float(v) >= 0.0 and float(v) == floorf(float(v)):
		return int(v)
	return -1

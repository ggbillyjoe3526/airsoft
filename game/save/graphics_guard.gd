class_name GraphicsGuard
extends RefCounted
## The safe start (docs/DECISIONS.md, 2026-10-23): a start that never got its first match's graphics drawn (the
## driver crashed, or the game was killed while it hung) makes the next start restart itself once on the simpler
## renderer and Low, then ask whether to keep them. Pure over its record, which SaveFile keeps at PATH; the entry scene
## does the files and the restart. A start writes STARTING; the first match's shaders warmed or a clean quit write
## SETTLED. A start that finds STARTING trips: the player's graphics are kept in `previous`, the settings go safe and
## the state RESTARTING, so the restarted start (or the next, if the restart never came) asks. While an answer waits,
## or when the graphics in force are already the safe ones, a start that never settled trips nothing: one automatic
## restart per crash, never a loop. A start that finds STARTING written by a copy still running (`pid`) and beating
## (the run's heartbeat, RunBeat, or the start's own time `at`, at most RunRecord.STALE_SECONDS old) is a second copy,
## not a crash: it leaves the record alone. A stale one is a crash whose id another copy holds since (a reboot, say). Also remembers the reason the title last gave for the simpler
## renderer, so it says so once per change.

const PATH := "user://graphics_guard.save"
const KIND := "graphics_guard"
const VERSION := 1
## SETTLED: the last start drew its first match or quit cleanly. STARTING: a start is under way. RESTARTING: a start
## tripped and asked for the restart on safe graphics.
enum State { SETTLED, STARTING, RESTARTING }
## What a start does: go on, restart on safe graphics (`trip` first), or go on and ask on the title (`previous` waits).
enum Action { NONE, RESTART_SAFE, ASK }
const STATE_NAMES: Array[String] = ["settled", "starting", "restarting"]
## The safe graphics: the simpler renderer and this preset.
const SAFE_PRESET := &"low"
## `previous`'s keys, as Settings.to_dict names them; the choice is "" for the automatic pick.
const KEEP_KEYS: Array[String] = ["graphics_choice", "graphics_base", "graphics_custom", "renderer"]

var state: State = State.SETTLED
## The player's graphics before the safe start (KEEP_KEYS), until they answer the notice; empty when nothing waits.
var previous: Dictionary = {}
## The reason the title last gave for the simpler renderer (RendererOverride.reason), "" when not on it.
var renderer_notice: String = ""
## The process that wrote the record (OS.get_process_id), 0 when not known.
var pid: int = 0
## When that start wrote it (Unix s), -1 when not known (a record from before BP7: its process id alone decides).
var at: int = -1


## The record at `path`: a missing or damaged file is a settled one (nothing to recover from).
static func load_file(path: String = PATH) -> GraphicsGuard:
	var g := GraphicsGuard.new()
	var r := SaveFile.read(path, KIND)
	if r.ok:
		g.from_dict(r.data)
	elif r.found:
		push_warning("graphics guard: %s is damaged; starting as settled" % path)
	return g


func save(path: String = PATH) -> bool:
	return SaveFile.write(path, KIND, VERSION, to_dict())


func to_dict() -> Dictionary:
	return {"state": STATE_NAMES[state], "previous": previous.duplicate(true), "renderer_notice": renderer_notice,
			"pid": pid, "at": at}


## Each value checked on its own: an unknown state reads as settled, a `previous` without every key as none.
func from_dict(data: Dictionary) -> void:
	var named := STATE_NAMES.find(str(data.get("state", "")))
	state = (named if named >= 0 else State.SETTLED) as State
	previous = {}
	var kept: Variant = data.get("previous")
	if kept is Dictionary and (kept as Dictionary).has_all(KEEP_KEYS):
		previous = (kept as Dictionary).duplicate(true)
	var notice: Variant = data.get("renderer_notice")
	renderer_notice = notice if notice is String else ""
	var by: Variant = data.get("pid")
	pid = maxi(int(by), 0) if by is int or by is float else 0
	var when: Variant = data.get("at")
	at = maxi(int(when), -1) if when is int or when is float else -1


## Whether a start under way belongs to another copy of the game, still running (`running` says whether a process id
## is) and beating at `now` (Unix s): its start's `at` or `seen` (RunBeat.read: [pid, time], counted when it is that
## process's) at most RunRecord.STALE_SECONDS old. A second copy opened beside the first, not a crash. A heartbeat
## ahead of `now` (the clock set back) is fresh.
func held_by_other(me: int, running: Callable, now: int, seen: PackedInt64Array = PackedInt64Array()) -> bool:
	if state != State.STARTING or pid <= 0 or pid == me:
		return false
	if at >= 0:
		var last := maxi(at, seen[1]) if seen.size() == 2 and seen[0] == pid else at
		if now - last > RunRecord.STALE_SECONDS:
			return false
	return bool(running.call(pid))


## Whether an answer waits (the notice shows on the title).
func asking() -> bool:
	return not previous.is_empty()


## A start, `safe_now` when the graphics in force are already the safe ones: what to do. The state it leaves is the one
## to write before anything is drawn.
func start(safe_now: bool) -> Action:
	if state == State.RESTARTING:
		# the restarted start, or the next one if the restart never came
		state = State.STARTING
		return Action.ASK
	if state == State.STARTING and not safe_now and not asking():
		state = State.RESTARTING
		return Action.RESTART_SAFE
	# settled, or a crash that safe graphics can't help (already on them, or the safe start crashed too)
	state = State.STARTING
	return Action.ASK if asking() else Action.NONE


## The first match's shaders warmed, or a clean quit. The trip's own quit (RESTARTING) is not one. True if it changed.
func settle() -> bool:
	if state != State.STARTING:
		return false
	state = State.SETTLED
	return true


## Keeps `s`'s graphics in `previous` and sets the safe ones (the simpler renderer and Low), `picked` being the card's
## pick. Call on RESTART_SAFE.
func trip(s: Settings, picked: StringName) -> void:
	var saved := s.to_dict()
	previous = {"graphics_choice": String(s.graphics_choice)}
	for key in KEEP_KEYS:
		if key != "graphics_choice":
			previous[key] = saved[key]
	s.renderer = Settings.Renderer.COMPATIBILITY
	s.choose_graphics(SAFE_PRESET, picked)


## Keep safe graphics: nothing waits any more.
func keep() -> void:
	previous = {}


## Try my settings again: `s` gets its graphics back (each value checked as a saved file's), nothing waits, and the
## restart that follows starts settled.
func try_again(s: Settings) -> void:
	if not asking():
		return
	var merged := s.to_dict()
	merged.erase("graphics_choice")
	for key in KEEP_KEYS:
		merged[key] = previous[key]
	if str(previous["graphics_choice"]) == String(Settings.GRAPHICS_AUTOMATIC):
		merged.erase("graphics_choice")
	s.from_dict(merged)
	previous = {}
	state = State.SETTLED


## Whether the title should say why the game is on the simpler renderer, for `reason` (RendererOverride.reason, "" when
## not on it): once per change of reason. Remembers it; save after.
func notice_due(reason: String) -> bool:
	if reason == renderer_notice:
		return false
	renderer_notice = reason
	return reason != ""

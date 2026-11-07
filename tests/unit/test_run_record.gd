extends GutTest
## SV3: the run record (RunRecord) through every state (a clean quit, a crash in play, in practice, in the menus, a second
## copy, the safe start's restart), the entry scene's writes, PlaySession's round starts, the crash handler's line and
## what a round-start write costs. Headless: files and states, never a real crash.

const ROOT := "user://test-sv3-run"
const MAIN := preload("res://game/main.tscn")
## Round-start writes timed, and the budget each must stay under (ms, acceptance 6).
const WRITES := 50
const WRITE_BUDGET_MS := 2.0
## A process id nothing runs as (the record is checked through an injected `running`).
const GONE := 999999

var _run_path := ROOT.path_join("run.save")
var _guard_path := ROOT.path_join("guard.save")
var _renderer_path := ROOT.path_join("renderer.cfg")
var _settings_path := ROOT.path_join("settings.save")
var _shared_before: Dictionary = {}


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	_shared_before = Settings.shared().to_dict()


func after_each() -> void:
	var s := Settings.shared()
	s.from_dict(_shared_before)
	s.dirty = false
	for f: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(f))


func after_all() -> void:
	DirAccess.remove_absolute(ROOT)


func _no(_id: int) -> bool:
	return false


func _yes(_id: int) -> bool:
	return true


## A record left by a run (`pid`) that got as far as `step` (it calls the record's own steps), never closed; its
## heartbeat now, as a copy still running would have written it.
func _left_running(step: Callable, pid: int = GONE) -> void:
	var r := RunRecord.new()
	r.start("0.1 Dev 1", 1000, pid)
	step.call(r)
	r.heartbeat(_now())
	assert_true(r.save(_run_path))


func _now() -> int:
	return int(Time.get_unix_time_from_system())


## The next start, as the entry scene makes it (RunRecord's own steps, `running` for ProcessCheck.is_running).
func _next_start(running: Callable = _no) -> RunRecord:
	var r := RunRecord.load_file(_run_path)
	if r.held_by_other(OS.get_process_id(), running, _now()):
		return null
	r.start("0.1 Dev 2", 2000, OS.get_process_id())
	r.save(_run_path)
	return RunRecord.load_file(_run_path)


func _play(r: RunRecord) -> void:
	r.play(1 << 60, "depot", "attack_defend", {"team_size": 2}, 1, "hard", "easy", [2, 2])
	r.round_started(4, PackedInt32Array([2, 1]))


func _practise(r: RunRecord) -> void:
	r.practise("range")


func _back_to_menus(r: RunRecord) -> void:
	_play(r)
	r.to_menus()


func _quit(r: RunRecord) -> void:
	_back_to_menus(r)
	r.close()


# --- RunRecord: every state ---

func test_a_start_writes_running_with_the_version_time_and_process() -> void:
	var r := _next_start()
	assert_eq(r.state, RunRecord.State.RUNNING)
	assert_eq(r.version, "0.1 Dev 2")
	assert_eq(r.started, 2000)
	assert_eq(r.pid, OS.get_process_id())
	assert_eq(r.place, RunRecord.MENUS)
	assert_false(r.crashed_before(), "no file: nothing closed unexpectedly")


func test_a_clean_quit_leaves_nothing_behind() -> void:
	_left_running(_quit)
	var r := _next_start()
	assert_false(r.crashed_before())
	assert_eq(r.state, RunRecord.State.RUNNING)


func test_a_crash_in_play_keeps_the_match_and_its_round() -> void:
	_left_running(_play)
	var prev := _next_start().previous
	assert_eq(str(prev["state"]), "running")
	assert_eq(str(prev["version"]), "0.1 Dev 1")
	assert_eq(int(prev["started"]), 1000)
	assert_eq(int(prev["pid"]), GONE)
	assert_eq(str(prev["place"]), RunRecord.MATCH)
	var facts: Dictionary = prev["match"]
	assert_eq(str(facts["seed"]), str(1 << 60), "the seed exactly, past JSON's 2^53")
	assert_eq(str(facts["map"]), "depot")
	assert_eq(str(facts["mode"]), "attack_defend")
	assert_eq(int((facts["rules"] as Dictionary)["team_size"]), 2)
	assert_eq(int(facts["team"]), 1)
	assert_eq(str(facts["difficulty"]), "hard")
	assert_eq(str(facts["teammates"]), "easy")
	assert_eq((facts["team_sizes"] as Array).size(), 2)
	assert_eq(int(prev["round"]), 4)
	assert_eq(int((prev["score"] as Array)[0]), 2)
	assert_eq(int((prev["score"] as Array)[1]), 1)
	assert_false((prev as Dictionary).has("previous"), "one run back, never a chain")


func test_a_crash_in_practice_keeps_its_map() -> void:
	_left_running(_practise)
	var prev := _next_start().previous
	assert_eq(str(prev["place"]), RunRecord.PRACTICE)
	assert_eq(str((prev["match"] as Dictionary)["map"]), "range")
	assert_eq(int(prev["round"]), 0)


func test_a_crash_in_the_menus_says_so() -> void:
	_left_running(_back_to_menus)
	var prev := _next_start().previous
	assert_eq(str(prev["place"]), RunRecord.MENUS)
	assert_true((prev["match"] as Dictionary).is_empty())
	assert_eq(int(prev["round"]), 0)
	assert_eq((prev["score"] as Array).size(), 0)


func test_previous_waits_through_clean_starts_and_a_newer_crash_replaces_it() -> void:
	_left_running(_practise)
	var r := _next_start()
	r.close()
	r.save(_run_path)
	assert_eq(str(_next_start().previous["place"]), RunRecord.PRACTICE, "until the crash screen shows it (SV6)")
	# that start crashed in the menus
	assert_eq(str(_next_start().previous["place"]), RunRecord.MENUS, "the newest crash")


func test_a_second_copy_leaves_the_running_record_alone() -> void:
	_left_running(_play, OS.get_process_id() + 1)
	var before := FileAccess.get_file_as_string(_run_path)
	assert_null(_next_start(_yes))
	assert_eq(FileAccess.get_file_as_string(_run_path), before)
	var r := RunRecord.load_file(_run_path)
	assert_true(r.held_by_other(OS.get_process_id(), _yes, _now()))
	assert_false(r.held_by_other(OS.get_process_id(), _no, _now()), "its writer gone: a crash")
	assert_false(r.held_by_other(r.pid, _yes, _now()), "this process's own record is not another copy")
	r.close()
	assert_false(r.held_by_other(OS.get_process_id(), _yes, _now()), "only a run under way")


## BP7 (row 85): a run under way whose heartbeat is stale crashed, even if another copy of the game holds its id now.
func test_a_stale_heartbeat_is_a_crash_though_another_copy_holds_the_id() -> void:
	var r := RunRecord.new()
	r.start("0.1 Dev 1", 1000, OS.get_process_id() + 1)
	assert_eq(r.beat, 1000, "a start beats")
	assert_true(r.held_by_other(OS.get_process_id(), _yes, 1000 + RunRecord.STALE_SECONDS), "fresh enough")
	assert_false(r.held_by_other(OS.get_process_id(), _yes, 1001 + RunRecord.STALE_SECONDS), "stale: a crash")
	assert_true(r.held_by_other(OS.get_process_id(), _yes, 900), "a beat ahead of the clock is fresh")
	r.heartbeat(5000)
	assert_true(r.save(_run_path))
	var read := RunRecord.load_file(_run_path)
	assert_eq(read.beat, 5000, "the heartbeat is written")
	assert_true(read.held_by_other(OS.get_process_id(), _yes, 5030))
	assert_false(read.held_by_other(OS.get_process_id(), _yes, 5100))
	var older := read.to_dict()
	older.erase("beat")
	var before_bp7 := RunRecord.new()
	before_bp7.from_dict(older)
	assert_eq(before_bp7.beat, 1000, "a record with no heartbeat reads its start")
	assert_lt(RunRecord.BEAT_SECONDS * 3.0, float(RunRecord.STALE_SECONDS), "a few beats missed before it is stale")


## The entry scene beats: its timer writes the run's heartbeat beside the record, paused or not, off the main thread
## (BP7 performance: the record itself, an atomic write, is not rewritten every beat).
func test_the_entry_scene_writes_a_heartbeat() -> void:
	var main: Node = _main()
	add_child_autofree(main)
	await wait_process_frames(1)
	var beat: Timer = main.get("_beat")
	assert_not_null(beat)
	assert_almost_eq(beat.wait_time, RunRecord.BEAT_SECONDS, 0.001)
	assert_eq(beat.process_mode, Node.PROCESS_MODE_ALWAYS)
	main.run.beat = 7
	main.run.save(main.run_path)
	beat.timeout.emit()
	(main.get("_run_beat") as RunBeat).finish()
	var seen := RunBeat.read(_run_path)
	assert_eq(seen[0], OS.get_process_id(), "this run's process")
	assert_gt(seen[1], 7, "beating now")
	assert_eq(RunRecord.load_file(_run_path).beat, 7, "the record not rewritten for it")


## BP7: the two beat files are written in turn, so a write cut short leaves the other one to read.
func test_the_newer_whole_beat_is_read_and_a_cut_one_is_passed_over() -> void:
	var beat := RunBeat.new(_run_path)
	assert_eq(RunBeat.read(_run_path), PackedInt64Array([0, 0]), "none yet")
	beat.beat(41, 1000)
	beat.finish()
	beat.beat(41, 1010)
	beat.finish()
	assert_eq(RunBeat.read(_run_path), PackedInt64Array([41, 1010]), "the newer")
	var cut := FileAccess.open(RunBeat.file_of(_run_path, 1), FileAccess.WRITE)
	cut.store_string("airsoft-be")
	cut.close()
	assert_eq(RunBeat.read(_run_path), PackedInt64Array([41, 1000]), "a cut write: the other one")
	var r := RunRecord.new()
	r.start("0.1 Dev 1", 900, 41)
	assert_false(r.held_by_other(OS.get_process_id(), _yes, 900 + RunRecord.STALE_SECONDS + 50), "its record alone: stale")
	assert_true(r.held_by_other(OS.get_process_id(), _yes, 900 + RunRecord.STALE_SECONDS + 50, RunBeat.read(_run_path)),
			"its beat beside the record: still going")
	assert_false(r.held_by_other(OS.get_process_id(), _yes, 900 + RunRecord.STALE_SECONDS + 50,
			PackedInt64Array([42, 2000])), "another process's beat does not count")


func test_damaged_and_odd_files_read_as_closed() -> void:
	var f := FileAccess.open(_run_path, FileAccess.WRITE)
	f.store_string("not a save")
	f.close()
	var r := RunRecord.load_file(_run_path)
	assert_push_warning("damaged")
	assert_eq(r.state, RunRecord.State.CLOSED)
	r.from_dict({"state": "flying", "place": "moon", "pid": -4, "started": "soon", "score": [1, "x"], "match": 3,
			"previous": "yes", "version": 7})
	assert_eq(r.state, RunRecord.State.CLOSED)
	assert_eq(r.place, RunRecord.MENUS)
	assert_eq(r.pid, 0)
	assert_eq(r.started, 0)
	assert_eq(r.score, [1, 0] as Array[int])
	assert_true(r.match_facts.is_empty())
	assert_false(r.crashed_before())
	assert_eq(r.version, "")


# --- The entry scene ---

## The entry scene recording a headless run at `_run_path`, its writer check `running`; the safe start guarded at the
## test's own files (the guard's restart only noted).
func _main(running: Callable = _no) -> Node:
	var main := MAIN.instantiate()
	main.run_path = _run_path
	main.run_process_running = running
	var graphics: GraphicsStartUp = main.graphics
	graphics.guard_path = _guard_path
	graphics.renderer_path = _renderer_path
	graphics.settings_path = _settings_path
	graphics.restart = func() -> void: main.set_meta(&"restarted", true)
	return main


func test_the_smoke_run_and_headless_runs_record_nothing() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(1)
	assert_null(main.run)
	assert_false(FileAccess.file_exists(RunRecord.PATH) and RunRecord.load_file().pid == OS.get_process_id(),
			"the player's record untouched")


func test_the_entry_scene_records_a_match_its_rounds_the_menus_and_a_clean_quit() -> void:
	var main: Node = _main()
	add_child(main)
	await wait_process_frames(2)
	var r := RunRecord.load_file(_run_path)
	assert_eq(r.state, RunRecord.State.RUNNING)
	assert_eq(r.version, Version.current())
	assert_eq(r.pid, OS.get_process_id())
	assert_almost_eq(r.started, int(Time.get_unix_time_from_system()), 5)
	main._picks.bots = "hard"
	main._start_play()
	var play: PlaySession = main._play
	r = RunRecord.load_file(_run_path)
	assert_eq(r.place, RunRecord.MATCH)
	assert_eq(str(r.match_facts["seed"]), str(play.match_seed), "the seed main gave the match")
	assert_eq(str(r.match_facts["map"]), play.map_id)
	assert_eq(str(r.match_facts["difficulty"]), "hard")
	assert_eq(int(r.match_facts["team"]), play.player_team)
	play.round_started.emit(3, PackedInt32Array([1, 1]))
	r = RunRecord.load_file(_run_path)
	assert_eq(r.round_number, 3)
	assert_eq(r.score, [1, 1] as Array[int])
	main._end_play()
	await wait_process_frames(2)
	r = RunRecord.load_file(_run_path)
	assert_eq(r.place, RunRecord.MENUS)
	main.free()
	r = RunRecord.load_file(_run_path)
	assert_eq(r.state, RunRecord.State.CLOSED, "a clean quit")
	assert_false(r.crashed_before())


func test_the_entry_scene_records_practice_its_loadout_and_leaving_it() -> void:
	var main: Node = _main()
	add_child_autofree(main)
	await wait_process_frames(2)
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._picks.map_id = "range"
	main._start_play()
	var r := RunRecord.load_file(_run_path)
	assert_eq(r.place, RunRecord.PRACTICE)
	assert_eq(str(r.match_facts["map"]), "range")
	var play: PlaySession = main._play
	await wait_for_signal(play.started, 10.0)
	main._open_practice_loadout()
	assert_eq(RunRecord.load_file(_run_path).place, RunRecord.MENUS, "practice's Loadout")
	main._back_to_practice()
	assert_eq(RunRecord.load_file(_run_path).place, RunRecord.PRACTICE, "back on the range")
	await wait_process_frames(2)
	main._end_play()
	assert_eq(RunRecord.load_file(_run_path).place, RunRecord.MENUS, "leaving practice")
	await wait_process_frames(2)


func test_a_start_after_a_crash_keeps_it_as_previous() -> void:
	_left_running(_play)
	var main: Node = _main()
	add_child_autofree(main)
	await wait_process_frames(1)
	var run: RunRecord = main.run
	assert_true(run.crashed_before())
	assert_eq(str(run.previous["place"]), RunRecord.MATCH)
	assert_eq(int(RunRecord.load_file(_run_path).previous["pid"]), GONE, "written at once")


func test_a_second_copy_records_nothing_and_its_quit_closes_nothing() -> void:
	_left_running(_play, OS.get_process_id() + 1)
	var main: Node = _main(_yes)
	add_child(main)
	await wait_process_frames(1)
	assert_null(main.run)
	main.free()
	var r := RunRecord.load_file(_run_path)
	assert_eq(r.state, RunRecord.State.RUNNING, "the first copy's record, untouched")
	assert_eq(r.pid, OS.get_process_id() + 1)
	assert_eq(r.place, RunRecord.MATCH)


func test_the_safe_start_s_restart_never_counts_and_the_restarted_start_sees_the_crash() -> void:
	_left_running(_play)
	var guard := GraphicsGuard.new()
	guard.state = GraphicsGuard.State.STARTING
	guard.save(_guard_path)
	var main: Node = _main()
	add_child(main)
	assert_true(main.has_meta(&"restarted"), "the safe start restarts")
	assert_null(main.run, "before the run record")
	main.free()
	var r := RunRecord.load_file(_run_path)
	assert_eq(r.pid, GONE, "the restart wrote nothing")
	assert_false(r.crashed_before())
	var again: Node = _main()
	add_child_autofree(again)
	await wait_process_frames(1)
	assert_false(again.has_meta(&"restarted"))
	var run: RunRecord = again.run
	assert_true(run.crashed_before(), "the run that crashed")
	assert_eq(int(run.previous["pid"]), GONE)
	assert_eq(str(run.previous["place"]), RunRecord.MATCH)


# --- PlaySession's round starts ---

func test_a_match_says_each_round_start_and_practice_says_none() -> void:
	for practice: bool in [false, true]:
		var play := PlaySession.new()
		play.settings = Settings.new(PlayTuning.new())
		play.match_seed = 43
		play.practice = practice
		play.map_id = "range" if practice else "depot"
		var heard: Array[int] = []
		play.round_started.connect(func(n: int, score: PackedInt32Array) -> void: heard.append_array([n, score[0] + score[1]]))
		add_child_autofree(play)
		await wait_physics_frames(3)
		assert_eq(heard, ([] as Array[int]) if practice else ([1, 0] as Array[int]), "practice %s" % practice)


# --- The crash handler's line, and the cost of a round-start write ---

func test_the_crash_handler_names_the_game_and_the_next_start() -> void:
	assert_eq(ProjectSettings.get_setting("debug/settings/crash_handler/message"),
			"Airsoft crashed. Start it again: it offers to report the bug.")


func test_a_round_start_write_costs_under_two_ms() -> void:
	var r := RunRecord.new()
	r.start("0.1 Dev 1", 1000, OS.get_process_id())
	_play(r)
	r.save(_run_path)
	var worst := 0
	var total := 0
	for i in WRITES:
		var t := Time.get_ticks_usec()
		r.round_started(i + 1, PackedInt32Array([i, i]))
		r.save(_run_path)
		var took := Time.get_ticks_usec() - t
		worst = maxi(worst, took)
		total += took
	gut.p("round-start write: mean %.3f ms, worst %.3f ms over %d" % [total / 1000.0 / WRITES, worst / 1000.0, WRITES])
	assert_lt(total / 1000.0 / WRITES, WRITE_BUDGET_MS)


## BP6: a clean quit whose write fails leaves its closed mark, so the next start keeps no crash; the mark then goes.
func test_a_clean_quit_whose_write_fails_is_still_no_crash() -> void:
	_left_running(_back_to_menus)
	var r := RunRecord.load_file(_run_path)
	SaveFile.hold(PackedStringArray([_run_path]))
	var marked := r.save_closed(_run_path)
	SaveFile.release(PackedStringArray([_run_path]))
	assert_true(marked)
	var mark := RunRecord.closed_mark(_run_path, GONE, 1000)
	assert_true(FileAccess.file_exists(mark), "the mark beside the record")
	assert_eq(RunRecord.load_file(_run_path).state, RunRecord.State.CLOSED)
	assert_true(FileAccess.file_exists(mark), "kept while its run's record is the one on disk")
	assert_false(_next_start().crashed_before())
	assert_false(FileAccess.file_exists(mark), "gone once a newer run's record is written")
	_left_running(_back_to_menus)
	assert_true(_next_start().crashed_before(), "the mark used up: a run left running is a crash again")
	_left_running(_back_to_menus)
	FileAccess.open(mark, FileAccess.WRITE).close()
	assert_false(_next_start().crashed_before(), "the run's own mark: no crash")
	_left_running(_back_to_menus, GONE + 1)
	FileAccess.open(mark, FileAccess.WRITE).close()
	assert_true(_next_start().crashed_before(), "another run's mark: still a crash")



## BP7 (row 83): a full disk that takes names but no bytes, two runs running: the second start can't write its own
## record, so its clean quit marks the run before it, still the one on disk, and the third start reads no crash.
func test_a_start_that_cannot_write_marks_the_run_on_disk_at_its_quit() -> void:
	_left_running(_back_to_menus)
	var first := RunRecord.load_file(_run_path)
	SaveFile.hold(PackedStringArray([_run_path]))
	assert_true(first.save_closed(_run_path), "first run: marked")
	var second := RunRecord.load_file(_run_path)
	assert_false(second.crashed_before())
	second.start("0.1 Dev 2", 2000, OS.get_process_id())
	assert_false(second.save(_run_path), "the second start can't write")
	assert_true(second.save_closed(_run_path), "second run: marked")
	SaveFile.release(PackedStringArray([_run_path]))
	assert_true(FileAccess.file_exists(RunRecord.closed_mark(_run_path, GONE, 1000)), "the first run's mark, kept")
	assert_false(FileAccess.file_exists(RunRecord.closed_mark(_run_path, OS.get_process_id(), 2000)),
			"no mark for a run no record names")
	assert_false(_next_start().crashed_before(), "the third start: no false crash")


## A start that can't write over a closed record needs no mark at its quit: the record already reads as closed.
func test_a_quit_over_a_closed_record_it_could_not_write_makes_no_mark() -> void:
	_left_running(_quit)
	var r := RunRecord.load_file(_run_path)
	r.close()
	assert_true(r.save(_run_path))
	var next := RunRecord.load_file(_run_path)
	next.start("0.1 Dev 2", 2000, OS.get_process_id())
	SaveFile.hold(PackedStringArray([_run_path]))
	assert_true(next.save_closed(_run_path))
	SaveFile.release(PackedStringArray([_run_path]))
	assert_eq(_marks(), 0)
	assert_false(_next_start().crashed_before())


## Marks whose runs' records are gone go with a newer run's first write, so none pile up.
func test_stale_marks_are_swept_by_the_next_written_start() -> void:
	for i in 3:
		FileAccess.open(RunRecord.closed_mark(_run_path, GONE + i, 1000 + i), FileAccess.WRITE).close()
	FileAccess.open(ROOT.path_join("other.save.closed-1-1"), FileAccess.WRITE).close()
	assert_eq(_marks(), 3)
	_next_start()
	assert_eq(_marks(), 0, "swept")
	assert_true(FileAccess.file_exists(ROOT.path_join("other.save.closed-1-1")), "another file's marks are not ours")
	var r := RunRecord.load_file(_run_path)
	FileAccess.open(RunRecord.closed_mark(_run_path, GONE, 1), FileAccess.WRITE).close()
	r.round_started(2, PackedInt32Array([1, 0]))
	assert_true(r.save(_run_path))
	assert_eq(_marks(), 1, "a run's later writes don't list the folder again")


func _marks() -> int:
	var n := 0
	for f in DirAccess.get_files_at(ROOT):
		if f.begins_with(_run_path.get_file() + ".closed-"):
			n += 1
	return n


## A folder locked whole (the record and its mark both held, as SaveFile.hold keeps a replaced save): no mark is made
## and nothing is taken away, so the next start honestly reads a crash.
func test_a_clean_quit_in_a_locked_folder_writes_no_mark_past_the_hold() -> void:
	_left_running(_back_to_menus)
	var r := RunRecord.load_file(_run_path)
	var mark := RunRecord.closed_mark(_run_path, GONE, 1000)
	var locked := PackedStringArray([_run_path, mark])
	SaveFile.hold(locked)
	var marked := r.save_closed(_run_path)
	SaveFile.release(locked)
	assert_false(marked, "the hold kept the mark out")
	assert_false(FileAccess.file_exists(mark))
	assert_true(FileAccess.file_exists(_run_path), "the held record is not taken away")
	assert_true(_next_start().crashed_before(), "so the next start says it closed unexpectedly")

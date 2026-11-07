extends GutTest
## SV3 QA: the second-copy checks with real processes, not an injected stand-in. On Godot 4.7.2
## OS.is_process_running knows only this process's own children (any other id logs an error and reads as gone), so a
## second copy took the first one's live run for a crash. ProcessCheck answers for any process, with no error, and
## only for a copy of this game: a crashed run's id taken since by another program reads as gone (critic, attempt 2).


func test_a_running_process_that_is_not_a_child_reads_as_running() -> void:
	var r := RunRecord.new()
	r.start("0.1 Dev 1", 100, OS.get_process_id())
	# the first copy is this very process, running; "me" is another copy's pid
	assert_true(r.held_by_other(OS.get_process_id() + 1, ProcessCheck.is_running, 100))


## A copy of the game: this executable, waiting (killed by the test).
const WAITING_COPY := """extends SceneTree
func _init() -> void:
	OS.delay_msec(30000)
	quit()
"""


func test_processes_running_and_gone() -> void:
	assert_true(ProcessCheck.is_running(OS.get_process_id()), "this one")
	assert_false(ProcessCheck.is_running(0))
	assert_false(ProcessCheck.is_running(-3))
	if OS.get_name() != "Linux":
		return
	assert_false(ProcessCheck.is_running(1), "init runs, but it isn't the game: a crashed run's id taken since")
	var other := OS.create_process("sleep", ["30"])
	assert_gt(other, 0)
	# Until the child execs, its exe link is still the game's: wait for it to become sleep.
	await wait_until(func() -> bool: return FileAccess.get_file_as_string("/proc/%d/comm" % other).strip_edges() == "sleep", 5.0)
	assert_false(ProcessCheck.is_running(other), "a live program that isn't the game")
	OS.kill(other)
	assert_false(ProcessCheck.is_running(4194304 + 7), "past Linux's highest pid")


func test_another_copy_of_the_game_reads_as_running_until_it_is_gone() -> void:
	if OS.get_name() != "Linux":
		pass_test("Linux only here; Windows' tasklist is test_the_tasklist_rows")
		return
	var script := ProjectSettings.globalize_path("user://test-sv3-waiting-copy.gd")
	var f := FileAccess.open(script, FileAccess.WRITE)
	f.store_string(WAITING_COPY)
	f.close()
	var copy := OS.create_process(OS.get_executable_path(), ["--headless", "-s", script])
	assert_gt(copy, 0)
	await wait_until(func() -> bool: return ProcessCheck.is_running(copy), 5.0)
	assert_true(ProcessCheck.is_running(copy), "the same executable")
	var r := RunRecord.new()
	r.start("0.1 Dev 1", 100, copy)
	assert_true(r.held_by_other(OS.get_process_id(), ProcessCheck.is_running, 100), "a second copy")
	OS.kill(copy)
	await wait_until(func() -> bool: return not ProcessCheck.is_running(copy), 5.0)
	assert_false(ProcessCheck.is_running(copy), "gone once killed (a zombie left unreaped reads as gone too)")
	DirAccess.remove_absolute(script)


func test_the_tasklist_rows() -> void:
	var row := "\"Airsoft.exe\",\"4120\",\"Console\",\"1\",\"210,544 K\"\r\n"
	assert_true(ProcessCheck.parse_tasklist(row, 4120, "Airsoft.exe"), "a match")
	assert_true(ProcessCheck.parse_tasklist(row, 4120, "AIRSOFT.EXE"), "names case aside")
	assert_false(ProcessCheck.parse_tasklist("\"chrome.exe\",\"4120\",\"Console\",\"1\",\"98,000 K\"\r\n", 4120,
			"Airsoft.exe"), "another program holds the id")
	assert_false(ProcessCheck.parse_tasklist("INFO: No tasks are running which match the specified criteria.\r\n", 4120,
			"Airsoft.exe"), "none")
	assert_false(ProcessCheck.parse_tasklist(row, 412, "Airsoft.exe"), "an id inside another")
	assert_false(ProcessCheck.parse_tasklist(row, 41200, "Airsoft.exe"), "an id around another")
	assert_false(ProcessCheck.parse_tasklist("", 4120, "Airsoft.exe"), "no output")
	assert_true(ProcessCheck.parse_tasklist("\r\n" + row.strip_edges(), 4120, "Airsoft.exe"), "a blank line first")


const FILES: Array[String] = ["user://test-sv3-real-run.save", "user://test-sv3-real-guard.save",
		"user://test-sv3-real-renderer.cfg"]


func test_the_entry_scene_and_the_safe_start_ask_it_by_default() -> void:
	var main: Node = preload("res://game/main.tscn").instantiate()
	main.run_path = FILES[0]
	var g := GraphicsStartUp.new()
	g.guard_path = FILES[1]
	g.renderer_path = FILES[2]
	g.settings_path = "user://test-sv3-real-settings.save"
	g.restart = func() -> void: pass
	g.start(false)
	assert_eq(g.process_running, Callable(ProcessCheck.is_running))
	add_child(main)
	assert_eq(main.run_process_running, Callable(ProcessCheck.is_running))
	main.free()
	for path in FILES:
		SaveFile.remove(path)


## A /proc cmdline file holds the arguments NUL-separated: the first is read without a NUL ever reaching a String
## (BP1: `char(0)` logged two "Unexpected NUL character" errors at every start).
func test_the_first_argument_of_a_cmdline_file_is_the_bytes_before_the_first_nul() -> void:
	var path := "user://bp1_cmdline"
	var cases: Dictionary[String, PackedByteArray] = {
		"godot": "godot".to_utf8_buffer() + PackedByteArray([0]) + "--path".to_utf8_buffer() + PackedByteArray([0]),
		"Airsoft Next": "Airsoft Next".to_utf8_buffer(),
		"": PackedByteArray([0]) + "after".to_utf8_buffer(),
	}
	for want: String in cases:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(cases[want])
		f.close()
		assert_eq(ProcessCheck._first_arg(path), want)
	DirAccess.remove_absolute(path)
	if OS.get_name() == "Linux":
		var own := ProcessCheck._first_arg("/proc/%d/cmdline" % OS.get_process_id())
		assert_true(own != "" and not own.contains("--"), "this process's own: the program it was started by, alone")



## Every error line the engine logs while it is added (OS.add_logger).
class ErrorLines:
	extends Logger
	var lines: PackedStringArray = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		lines.append(code + " " + rationale)

	func _log_message(message: String, error: bool) -> void:
		if error:
			lines.append(message)


func test_compiling_the_process_check_logs_no_error() -> void:
	# a fresh compile, as at every start, logs nothing (BP1: two "Unexpected NUL character" lines did)
	var errors := ErrorLines.new()
	OS.add_logger(errors)
	var fresh: Resource = ResourceLoader.load("res://game/core/process_check.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	OS.remove_logger(errors)
	assert_not_null(fresh)
	assert_eq(errors.lines, PackedStringArray())

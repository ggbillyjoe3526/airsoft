extends GutTest
## The automatic graphics step-down (GR5; the browser game's QUALITY_STEP_DOWN): FrameWatch, fed frame times, asks for
## one preset down after two slow 2 s windows in a row, once a match; a pause, focus loss or a player's own pick starts
## it over; the frame-rate limit raises the slow frame's time; it allocates nothing per frame. In a match on Depot the
## step waits for the round's end, goes one preset down for the run without saving, and the HUD says so for 5 s; Low
## never steps.

const FRAME := 1.0 / 60.0
const SLOW := 0.030
const SECONDS := 2.0

var _preset_before: StringName = &""
var _drawn_before: GraphicsQuality = null
var _scale_before: float = 1.0
var session: PlaySession = null
var s: Settings = null


func before_each() -> void:
	_preset_before = GraphicsApply.machine().preset
	_drawn_before = GraphicsApply.server().drawn
	_scale_before = get_tree().root.scaling_3d_scale
	s = Settings.new(PlayTuning.new())


func after_each() -> void:
	get_tree().paused = false
	GraphicsApply.pick_for_run(_preset_before)
	GraphicsApply.server().drawn = _drawn_before
	if _drawn_before != null:
		GraphicsApply.apply(_drawn_before, get_tree().root)
	get_tree().root.scaling_3d_scale = _scale_before


## `seconds` of frames of `frame` each (a frame more, so a window's sum is over its time whatever the rounding): true if
## the watch asked on any of them.
func _feed(watch: FrameWatch, frame: float, seconds: float, limit: int = Settings.UNLIMITED,
		counting: bool = true) -> bool:
	var asked := false
	for i in ceili(seconds / frame) + 1:
		asked = watch.feed(frame, limit, counting) or asked
	return asked


# --- The numbers ---

func test_the_browser_games_numbers_are_the_display_configs() -> void:
	var c := DisplayConfig.new()
	assert_eq([c.step_window, c.step_slow_ms, c.step_limit_slack, c.step_slow_share, c.step_windows,
			c.step_notice_seconds], [2.0, 20.0, 1.25, 0.05, 2, 5.0])
	assert_eq(FrameWatch.new().config.step_window, 2.0, "a watch made without one uses the defaults")


func test_the_limit_raises_the_slow_frames_time() -> void:
	var w := FrameWatch.new()
	assert_eq(w.slow_ms(Settings.UNLIMITED), 20.0)
	assert_eq(w.slow_ms(240), 20.0, "a fast limit's frame is under 20 ms")
	assert_almost_eq(w.slow_ms(60), 20.833, 0.001)
	assert_almost_eq(w.slow_ms(30), 41.667, 0.001)


func test_one_preset_down_and_low_has_none() -> void:
	assert_eq(FrameWatch.preset_below(&"ultra"), &"high")
	assert_eq(FrameWatch.preset_below(&"high"), &"medium")
	assert_eq(FrameWatch.preset_below(&"medium"), &"low")
	assert_eq(FrameWatch.preset_below(&"low"), &"")
	assert_eq(FrameWatch.preset_below(&"custom"), &"")


# --- The watch ---

func test_steady_frames_never_step() -> void:
	var w := FrameWatch.new()
	assert_false(_feed(w, FRAME, 60.0), "a minute at 60 FPS")
	# one frame in 25 over 20 ms is 4 %: under the 5 % share
	var asked := false
	for i in 3000:
		asked = w.feed(SLOW if i % 25 == 0 else FRAME, Settings.UNLIMITED, true) or asked
	assert_false(asked, "a hitch now and then")
	assert_false(w.due())


func test_two_slow_windows_in_a_row_step_once() -> void:
	var w := FrameWatch.new()
	assert_false(_feed(w, SLOW, SECONDS), "one slow window")
	assert_eq(w.slow_windows(), 1)
	assert_true(_feed(w, SLOW, SECONDS), "the second asks")
	assert_true(w.due())
	assert_false(_feed(w, SLOW, SECONDS * 4.0), "once a match")
	assert_true(w.take(), "the round's end takes it")
	assert_false(w.take(), "once")
	assert_false(_feed(w, SLOW, SECONDS * 4.0), "still once a match after it applied")
	w.new_match()
	assert_false(_feed(w, SLOW, SECONDS))
	assert_true(_feed(w, SLOW, SECONDS), "a new match may ask again")


func test_a_share_just_over_five_percent_is_a_slow_window() -> void:
	var w := FrameWatch.new()
	var asked := false
	# one frame in 15 is 6.7 %
	for i in roundi(SECONDS * 2.0 / FRAME) + 2:
		asked = w.feed(SLOW if i % 15 == 0 else FRAME, Settings.UNLIMITED, true) or asked
	assert_true(asked)


func test_the_slow_windows_must_come_in_a_row() -> void:
	var w := FrameWatch.new()
	assert_false(_feed(w, SLOW, SECONDS))
	assert_false(_feed(w, FRAME, SECONDS), "a smooth window between")
	assert_eq(w.slow_windows(), 0)
	assert_false(_feed(w, SLOW, SECONDS))
	assert_true(_feed(w, SLOW, SECONDS))


func test_a_frame_that_doesnt_count_starts_it_over() -> void:
	var w := FrameWatch.new()
	assert_false(_feed(w, SLOW, SECONDS))
	assert_false(w.feed(SLOW, Settings.UNLIMITED, false), "paused, unfocused or between rounds")
	assert_eq(w.slow_windows(), 0)
	assert_false(_feed(w, SLOW, SECONDS), "a slow window again is only the first")
	assert_true(_feed(w, SLOW, SECONDS))
	w.reset()
	assert_true(w.due(), "a step asked for stays due through a pause")


func test_a_players_own_pick_drops_a_step_waiting() -> void:
	var w := FrameWatch.new()
	assert_false(_feed(w, SLOW, SECONDS))
	w.drop()
	assert_eq(w.slow_windows(), 0, "the count starts over")
	assert_false(_feed(w, SLOW, SECONDS))
	assert_true(_feed(w, SLOW, SECONDS))
	w.drop()
	assert_false(w.due(), "dropped")
	assert_false(_feed(w, SLOW, SECONDS))
	assert_true(_feed(w, SLOW, SECONDS), "never applied: back on the automatic pick it may ask again")
	assert_true(w.take())
	w.drop()
	assert_false(_feed(w, SLOW, SECONDS * 4.0), "applied: not again this match")


func test_the_limit_keeps_its_own_frames_from_counting_slow() -> void:
	var w := FrameWatch.new()
	assert_false(_feed(w, 1.0 / 30.0, SECONDS * 4.0, 30), "a 30 FPS limit's 33 ms frames")
	assert_false(_feed(w, 0.040, SECONDS * 4.0, 30), "40 ms under a 30 FPS limit")
	w.reset()
	assert_true(_feed(w, 0.045, SECONDS * 2.0, 30), "45 ms is over 1.25 of its frame")
	var unlimited := FrameWatch.new()
	assert_true(_feed(unlimited, 1.0 / 30.0, SECONDS * 2.0), "33 ms frames with no limit")


func test_what_counts() -> void:
	var fwd := "forward_plus"
	assert_true(FrameWatch.counts(true, &"high", true, false, true, fwd))
	assert_true(FrameWatch.counts(true, &"medium", true, false, true, fwd))
	assert_false(FrameWatch.counts(false, &"high", true, false, true, fwd), "a player's own pick")
	assert_false(FrameWatch.counts(true, &"low", true, false, true, fwd), "Low never steps")
	assert_false(FrameWatch.counts(true, &"high", false, false, true, fwd), "unfocused")
	assert_false(FrameWatch.counts(true, &"high", true, true, true, fwd), "paused")
	assert_false(FrameWatch.counts(true, &"high", true, false, false, fwd), "not in play")
	assert_false(FrameWatch.counts(true, &"high", true, false, true, GraphicsPick.COMPATIBILITY),
			"the simpler renderer")


func test_pretend_slow_frames_count_slow_at_any_time() -> void:
	var w := FrameWatch.new()
	var asked := false
	for i in ceili(SECONDS * 2.0 / FRAME) + 2:
		asked = w.feed(FRAME, Settings.UNLIMITED, true, true) or asked
	assert_true(asked, "two windows of real time")


func test_the_watch_allocates_nothing_per_frame() -> void:
	var w := FrameWatch.new()
	w.feed(FRAME, Settings.UNLIMITED, true)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 5000:
		w.feed(SLOW if i % 3 == 0 else FRAME, 144 if i % 2 == 0 else Settings.UNLIMITED, i % 500 != 0)
		FrameWatch.counts(true, &"high", true, false, true, "forward_plus")
	w.take()
	w.new_match()
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


# --- In a match ---

func _play() -> void:
	session = PlaySession.new()
	session.settings = s
	session.autopilot = true
	add_child_autofree(session)
	await wait_physics_frames(2)


## The watch asking, as two slow windows of a live round would.
func _make_due() -> void:
	var w := session.frame_watch()
	assert_false(_feed(w, SLOW, SECONDS))
	assert_true(_feed(w, SLOW, SECONDS))


func test_the_step_waits_for_the_rounds_end_and_goes_one_preset_down_unsaved() -> void:
	GraphicsApply.pick_for_run(&"high")
	await _play()
	RoundHold.release(session.state)
	_make_due()
	await wait_physics_frames(10)
	assert_true(session.state.round_state.is_live())
	assert_eq(GraphicsApply.machine().preset, &"high", "never mid-round")
	assert_null(session.hud().graphics_step_line())
	assert_true(DevCheats.end_round(session.state))
	await wait_physics_frames(3)
	assert_eq(GraphicsApply.machine().preset, &"medium", "one preset down at the round's end")
	assert_eq(s.graphics_choice, Settings.GRAPHICS_AUTOMATIC, "still the automatic pick")
	assert_false(s.dirty, "nothing to save: the pick never is")
	assert_eq(s.graphics_in_force(GraphicsApply.machine().preset).equals(GraphicsTable.shared().preset(&"medium")),
			true, "Medium's values in force")
	var line := session.hud().graphics_step_line()
	assert_not_null(line, "the HUD says so")
	var words := PackedStringArray()
	for l in line.find_children("*", "Label", true, false):
		words.append((l as Label).text)
	assert_eq(words, PackedStringArray(["GRAPHICS", "Set to Medium to keep the game smooth",
			"Settings › Graphics to pick your own"]))
	assert_false(session.frame_watch().due())


func test_the_hud_line_shows_for_five_seconds() -> void:
	await _play()
	var hud := session.hud()
	hud.show_graphics_step("Medium", DisplayConfig.new().step_notice_seconds)
	hud.update(session.state, 1.0, 4.9)
	assert_not_null(hud.graphics_step_line())
	hud.update(session.state, 1.0, 0.2)
	assert_null(hud.graphics_step_line(), "gone after 5 s")


func test_low_never_steps() -> void:
	GraphicsApply.pick_for_run(&"low")
	await _play()
	_make_due()
	assert_true(DevCheats.end_round(session.state))
	await wait_physics_frames(3)
	assert_eq(GraphicsApply.machine().preset, &"low")
	assert_null(session.hud().graphics_step_line())


func test_a_players_own_pick_drops_the_step_and_keeps_their_preset() -> void:
	GraphicsApply.pick_for_run(&"high")
	await _play()
	_make_due()
	s.choose_graphics(&"ultra", GraphicsApply.machine().preset)
	s.changed.emit()
	assert_false(session.frame_watch().due())
	assert_true(DevCheats.end_round(session.state))
	await wait_physics_frames(3)
	assert_eq(GraphicsApply.machine().preset, &"high")
	assert_eq(s.graphics_choice, &"ultra")
	assert_null(session.hud().graphics_step_line())


func test_a_forced_preset_never_steps() -> void:
	GraphicsApply.pick_for_run(&"high")
	s.graphics_forced = &"high"
	await _play()
	assert_false(session.graphics_automatic())
	_make_due()
	assert_true(DevCheats.end_round(session.state))
	await wait_physics_frames(3)
	assert_eq(GraphicsApply.machine().preset, &"high")


func test_a_pause_and_focus_loss_start_the_count_over() -> void:
	await _play()
	var w := session.frame_watch()
	_feed(w, SLOW, SECONDS)
	assert_eq(w.slow_windows(), 1)
	session.call("_open_pause")
	assert_eq(w.slow_windows(), 0, "paused")
	get_tree().paused = false
	_feed(w, SLOW, SECONDS)
	session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(w.slow_windows(), 0, "focus lost")
	session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)


func test_the_smoke_tests_pilot_never_counts() -> void:
	GraphicsApply.pick_for_run(&"high")
	s.dev.pretend_slow_frames = true
	await _play()
	await wait_process_frames(30)
	assert_eq(session.frame_watch().slow_windows(), 0)
	assert_false(session.frame_watch().due())


func test_a_rematch_may_ask_again() -> void:
	await _play()
	var w := session.frame_watch()
	_make_due()
	assert_true(w.take())
	assert_false(_feed(w, SLOW, SECONDS * 4.0))
	session.set("_rematch_left", 0.0)
	await wait_physics_frames(2)
	assert_false(_feed(w, SLOW, SECONDS))
	assert_true(_feed(w, SLOW, SECONDS), "the next match's watch")


# --- The screen's rate and hitches (QA) ---

func test_a_50_hz_screen_under_v_sync_raises_the_threshold() -> void:
	var watch := FrameWatch.new()
	assert_almost_eq(watch.slow_ms(Settings.UNLIMITED, 50.0), 25.0, 0.001)
	assert_almost_eq(watch.slow_ms(Settings.UNLIMITED, 144.0), 20.0, 0.001, "fast screens keep the floor")
	assert_almost_eq(watch.slow_ms(Settings.UNLIMITED, -1.0), 20.0, 0.001, "an unknown rate is none")
	assert_almost_eq(watch.slow_ms(30, 60.0), 1.25 * 1000.0 / 30.0, 0.001, "the longer frame of the two")
	var asked := false
	for i in int(4.0 * 50.0):
		asked = watch.feed(0.0201, Settings.UNLIMITED, true, false, 50.0) or asked
	assert_false(asked, "a 50 Hz screen's steady frames aren't slow")
	assert_eq(watch.slow_windows(), 0)


func test_hitches_in_steady_play_never_step() -> void:
	var watch := FrameWatch.new()
	var asked := false
	for window in 4:
		asked = _feed(watch, FRAME, 1.4) or asked
		asked = watch.feed(2.5, Settings.UNLIMITED, true) or asked
	assert_false(asked, "one hitch a window is under the slow share")
	assert_eq(watch.slow_windows(), 0)


func test_a_machine_under_two_frames_a_second_still_steps() -> void:
	var watch := FrameWatch.new()
	var asked := false
	for i in 10:
		asked = watch.feed(0.8, Settings.UNLIMITED, true) or asked
	assert_true(asked)

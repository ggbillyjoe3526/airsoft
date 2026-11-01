extends Node
## The entry scene: the title (TitleScreen: START, Licences, Quit), the menus (MenuScreen: the top bar over the Match page
## with its map, mode, team, bots and rules, the Loadout page, which the LOADOUT tab builds and leaving it saves and
## frees, or the Armory, built and freed the same way), the settings under the top bar, the credits, the F3 performance overlay, the Show FPS readout and the window's keys and focus (WindowWatch). The Match page
## lists the public maps, and the dev ones too while the Dev settings' Dev content switch is on (MapCatalog). PLAY saves the
## loadouts, frees the title and the menus (no menu nodes live during a match) and opens a match (PlaySession) on the picked
## map and team, on the `--seed` launch option's seed if given, else a fresh one, behind the loading screen until it has
## drawn its first frame; leaving it builds them again and comes back to the title. The picks live in a MatchPicks kept
## here. The menus grow with a tall window (MenuScale).
## `--smoke` (tools/smoke_test.sh) opens and closes the settings, the credits, the Loadout page (with Customise) and the Armory,
## plays a whole match on Depot with a bot in your place (faster than real time), giving squad orders once the first
## round is live (F twice, then the order wheel held, pointed up and let go), leaves, opens practice on the range where
## a pilot shoots till it rings a plate, leaves, then quits with a report line.
## The Loadout from practice: the range's Loadout key (or the pause menu's row) takes where you stood (PracticeSpot), frees
## the range and opens the menus as the Loadout alone (MenuScreen.open_practice_loadout); BACK TO PRACTICE, the key or Esc
## saves it and builds the range again on that spot.
## The graphics at start-up (GraphicsStartUp): boot logs the renderer in force; a start that never drew its first match
## restarts once on safe graphics and the title asks; the title says once why the game is on the simpler renderer, and
## on the first start which preset the card picked (its Graphics settings opens Settings › Graphics). Then today's
## restore point (SaveKeeper.keep_today), not in the smoke run, a headless one or one the editor started.
## The run record and the error log (SV3): the ErrorLog keeps this run's last errors from boot to exit; after the safe
## start, a RunRecord notes the run (a crashed one kept as `previous`), each match or practice, round start and return
## to the menus, and the clean quit. Neither prints.
## Report a Bug (SV5): the title's link opens the ReportPanel on this run's facts (built when asked for, freed once
## closed); a match hands the ErrorLog to its pause menu, which has its own. The smoke test opens and closes it from the
## title, never pressing Report.
## The crash screen (SV6, CrashScreen): a start whose record kept a `previous` (the last run closed unexpectedly) shows it
## before the title and its notices; Continue, Report a Bug or quitting from it clears `previous`, so it shows once.

const SMOKE_SETTINGS_OPEN := 10
const SMOKE_SETTINGS_CLOSE := 20
const SMOKE_CREDITS_OPEN := 30
const SMOKE_CREDITS_CLOSE := 60
const SMOKE_LOADOUT_OPEN := 65
const SMOKE_CUSTOMISE_OPEN := 72
const SMOKE_LOADOUT_CLOSE := 80
const SMOKE_ARMORY_OPEN := 83
const SMOKE_ARMORY_CLOSE := 87
const SMOKE_PLAY := 90
## Simulation ticks per physics tick in the smoke match; the most ticks it may take (a match that runs longer fails:
## 30 min of match time); and frames it waits after leaving, as a player back on the title screen would, so the audio
## server lets go of the match's last sounds before the exit check.
const SMOKE_SPEED := 8
const SMOKE_MAX_TICKS := 108000
const SMOKE_SETTLE := 30
## The smoke match's seed and map, so every run plays the same match.
const SMOKE_SEED := 1
const SMOKE_MAP := "depot"
## The most ticks the smoke test's practice may take to ring a plate (a minute).
const SMOKE_RANGE_MAX_TICKS := 3600
## The smoke test's practice is played on the range (M21); a player's is on the map picked, the Range's card.
const PRACTICE_MAP := "range"
## The smoke match's squad orders, one step a frame once the first round is live: Follow me's key pressed (+) and let
## go (-) twice (given, then cancelled), then the order wheel's key held, the mouse flicked up onto its top order (an
## empty step), and let go; then Need a Mag (MH3) asked for on its key, and picked on the wheel (flicked up left onto
## it: a "<" step).
const SMOKE_ORDER_STEPS: PackedStringArray = ["+order_follow", "-order_follow", "+order_follow", "-order_follow",
		"+order_wheel", "", "-order_wheel", "+mag_hand_off", "-mag_hand_off", "+order_wheel", "<", "-order_wheel"]
const SMOKE_WHEEL_FLICK := Vector2(0.0, -400.0)
const SMOKE_MAG_FLICK := Vector2(-380.0, -124.0)
## The smoke test's Report a Bug, from the title before the menus open: the frames it opens and closes on.
const SMOKE_REPORT_OPEN := 3
const SMOKE_REPORT_CLOSE := 6
## Where a report from the title says the player was (English: reports are read by the developer).
const REPORT_SCREEN_TITLE := "title"

var _credits: Credits
## Report a Bug over the title, while it is open.
var _report_panel: ReportPanel = null
var _settings_screen: SettingsScreen
## QUIT GAME? while it is asked (Esc in the menus), else null.
var _quit_prompt: QuitPrompt = null
var _title: TitleScreen
var _menus: MenuScreen
var _play: PlaySession
var _loading: LoadingScreen
## Practice, while its Loadout is open: where you stood on the range, for the range built again. Null otherwise.
var _spot: PracticeSpot = null
## What the Match page has picked, kept while the menus are freed for a match.
var _picks := MatchPicks.new()
## Loading into a match or the range waits for the loading screen's Continue once fully loaded (MC1). Off in a headless
## run (the tests and tools: nobody there to press it); a test turns it on to check it.
var continue_after_loading: bool = DisplayServer.get_name() != "headless"
var _perf: DebugPerf
var _smoke := false
## The `--seed` launch option, or LaunchSeed.NONE.
var _launch_seed := LaunchSeed.NONE
var _frame := 0
var _smoke_shots := -1
var _smoke_impacts := -1
var _smoke_rounds := -1
var _smoke_matches := -1
var _smoke_left_at := -1
var _smoke_plates := -1
var _smoke_range_left_at := -1
var _smoke_order_step := 0
var _smoke_orders := -1
var _smoke_mags := -1
## The graphics at start-up: the safe start's record and the title's notices (tests set its paths and hooks first).
var graphics: GraphicsStartUp = GraphicsStartUp.new()
## This run's last errors and warnings, added as a Logger at boot and removed at exit.
var error_log: ErrorLog = ErrorLog.new()
## The run record, or null where no run is recorded (the smoke run, a headless one, one the editor started) and for a
## second copy beside a running one. Tests set `run_path` to record a headless run and replace `run_process_running`
## (whether a process id is another running copy of this game: ProcessCheck.is_running).
var run: RunRecord = null
var run_path: String = ""
var run_process_running: Callable = Callable()
## The crash screen while it shows, else null. Tests give what it opens (OS.shell_open) and copies to (the clipboard),
## and the folder its log is read from.
var crash_screen: CrashScreen = null
var crash_open: Callable = Callable()
var crash_copy: Callable = Callable()
var crash_log_dir: String = LogTail.DIR


func _ready() -> void:
	OS.add_logger(error_log)
	_smoke = OS.get_cmdline_user_args().has("--smoke")
	_launch_seed = LaunchSeed.parse(OS.get_cmdline_user_args())
	TooltipWrap.install(get_tree())
	print("[boot] Airsoft %s on Godot %s" % [Version.current(), Engine.get_version_info()["string"]])
	print(RendererOverride.boot_line(GraphicsApply.machine()))
	if not graphics.restart.is_valid():
		graphics.restart = _restart
	if graphics.start(_smoke) == GraphicsGuard.Action.RESTART_SAFE:
		return
	# today's restore point, the save as it was at start; never from the smoke run, a headless one or the editor's
	if not (_smoke or DisplayServer.get_name() == "headless" or EngineDebugger.is_active()):
		SaveKeeper.new().keep_today()
	# after the safe start, so its own restart never reads as a crash
	_start_run()
	# the last match's map and team, kept with the progress; not in the smoke run or a headless one (the tests')
	if _keeps_picks():
		_picks.recall(Progress.shared())
	graphics.graphics_settings_requested.connect(_open_graphics_settings)
	# before the settings screens and the match, so a key list waiting for a key has F11 first
	add_child(WindowWatch.new())
	_build_screens()
	_title.focus_start()
	SettingsApply.set_menus(Settings.shared(), true)
	_credits = Credits.new()
	_credits.visible = false
	_credits.closed.connect(_credits_closed)
	add_child(_credits)
	add_child(FpsReadout.new(Settings.shared()))
	_perf = DebugPerf.new()
	add_child(_perf)
	_scale_menus()
	get_window().size_changed.connect(_scale_menus)
	set_process(_smoke)
	if not _show_crash_screen():
		graphics.show_boot_notices(_title)


func _exit_tree() -> void:
	# a clean quit: the graphics started (the trip's own restart is not one)
	graphics.settle()
	if run != null:
		if crash_screen != null:
			run.previous = {}
		run.close()
		run.save(run_path)
	OS.remove_logger(error_log)
	var window := get_window()
	if window.size_changed.is_connected(_scale_menus):
		window.size_changed.disconnect(_scale_menus)
	MenuScale.apply(window, false)


## The title and the menus page, built at boot and after each match; a match frees them (a hidden menu would keep
## its nodes for the whole match).
func _build_screens() -> void:
	_build_menus()
	_build_title()
	# first in the tree, under the credits, the readouts and any match
	move_child(_menus, 0)
	move_child(_title, 1)


func _free_screens() -> void:
	_title.queue_free()
	_title = null
	_menus.queue_free()
	_menus = null


## Sizes the menus for the window: grown while they show, plain in play (the HUD has its own scale).
func _scale_menus() -> void:
	MenuScale.apply(get_window(), _play == null)


func _build_title() -> void:
	_title = TitleScreen.new()
	_title.start_pressed.connect(_show_menus)
	_title.credits_pressed.connect(_show_credits)
	_title.report_pressed.connect(_show_report)
	_title.quit_pressed.connect(get_tree().quit)
	add_child(_title)
	graphics.show_safe_notice(_title)


func _build_menus() -> void:
	_menus = MenuScreen.new(_picks, Settings.shared())
	_menus.visible = false
	_menus.title_requested.connect(_on_title_requested)
	_menus.tab_requested.connect(_on_tab)
	_menus.match_page().play_pressed.connect(_start_play)
	_menus.practice_requested.connect(_back_to_practice)
	add_child(_menus)


func _show_menus() -> void:
	_title.visible = false
	_menus.visible = true
	_menus.focus_play()


## The AIRSOFT wordmark: the settings, if open, close (saving), then the title shows.
func _on_title_requested() -> void:
	if _settings_screen != null:
		_settings_screen.close()
	_show_title()


func _show_title() -> void:
	# the Loadout page is saved and freed; the menus open on the Match page again
	_menus.show_match()
	_menus.visible = false
	_title.visible = true
	_title.focus_start()


## A top bar tab: Settings opens the settings under the bar; Match, Loadout and Armory close them and show their page.
func _on_tab(tab: TopBar.Tab) -> void:
	if tab == TopBar.Tab.SETTINGS:
		_open_settings()
		return
	if _settings_screen != null:
		_settings_screen.close()
	if tab == TopBar.Tab.LOADOUT:
		_menus.show_loadout()
	elif tab == TopBar.Tab.ARMORY:
		_menus.show_armory()
	elif tab == TopBar.Tab.MATCH:
		_menus.show_match()


## The settings over the menus, built when asked for and freed once closed (a hidden screen would keep its
## couple of hundred nodes for the whole session).
func _open_settings() -> void:
	if _settings_screen == null:
		_settings_screen = SettingsScreen.new()
		_settings_screen.settings = Settings.shared()
		_settings_screen.restart = _restart
		# under the top bar, whose lit SETTINGS tab names the screen
		_settings_screen.show_heading = false
		_settings_screen.closed.connect(_settings_closed)
		add_child(_settings_screen)
		# under the top bar, which stays on show
		_settings_screen.offset_top = TopBar.HEIGHT
	_menus.top_bar().set_current(TopBar.Tab.SETTINGS)
	_settings_screen.open()


func _settings_closed() -> void:
	_settings_screen.queue_free()
	_settings_screen = null
	if _menus != null:
		# Disable levelling or Reset level may have changed it.
		_menus.show_level()
		_menus.top_bar().set_current(_menus.page_tab())
		if _menus.visible:
			_menus.focus_page()


func _show_credits() -> void:
	_credits.open()


## The credits only open from the title: Enter starts again once they close.
func _credits_closed() -> void:
	if _title != null and _title.visible:
		_title.focus_start()


## Report a Bug from the title: the panel over it on this run's facts as they stand now.
func _show_report() -> void:
	if _report_panel == null:
		_report_panel = ReportPanel.new()
		_report_panel.closed.connect(_report_closed)
		add_child(_report_panel)
	var config := _report_panel.config
	_report_panel.open(ReportFacts.live(null, Settings.shared(), error_log, REPORT_SCREEN_TITLE, "", config,
			ReportScrub.for_this_machine(config)))


func _report_closed() -> void:
	_report_panel.queue_free()
	_report_panel = null
	if _title != null and _title.visible:
		_title.report_button().grab_focus()


## The smoke test's Report a Bug: opened from the title's link and closed with Back; Report is never pressed.
func _smoke_bug_report() -> void:
	if _frame == SMOKE_REPORT_OPEN:
		_title.report_button().pressed.emit()
		if _report_panel == null or not _report_panel.report_text().begins_with(BugReport.TITLE):
			push_error("smoke: Report a Bug showed no report from the title")
			set_process(false)
			get_tree().quit(1)
	elif _frame == SMOKE_REPORT_CLOSE and _report_panel != null:
		_report_panel.back_button().pressed.emit()


## Whether the Match page's map and team are kept across launches: not in the smoke run or a headless one.
func _keeps_picks() -> bool:
	return not (_smoke or DisplayServer.get_name() == "headless")


## Opens the match picked: practice when the Match page has Practice picked (PRACTICE) or `smoke_practice` is given
## (the smoke test's way in).
func _start_play(smoke_practice: bool = false) -> void:
	if _play != null:
		return
	# No menu nodes live during a match: the title and the menus are freed now and built again when it ends. The loadouts
	# are saved first (the Loadout page, if open, is part of what is freed).
	if _settings_screen != null:
		_settings_screen.close()
	_menus.leave_loadout()
	SavedLoadouts.shared().save_if_dirty()
	_free_screens()
	var practice := smoke_practice or _spot != null or (not _smoke and _picks.mode == MatchOptions.MODE_PRACTICE)
	var team := PlaySession.TEAM_ALPHA if _smoke else _picks.team
	var map_id := PRACTICE_MAP if smoke_practice else SMOKE_MAP if _smoke else _picks.map_id
	if _keeps_picks() and _spot == null:
		Progress.shared().remember_picks(_picks.map_id, _picks.team)
		Progress.shared().save_if_dirty()
	_play = PlaySession.new()
	_play.autopilot = _smoke
	_play.counts = not _smoke
	_play.practice = practice
	_play.challenge_on = practice and not _smoke and Settings.shared().practice_challenge
	_play.resume = _spot
	_play.mode = MatchOptions.MODE_PRACTICE if practice else _picks.mode
	_play.difficulty = StringName(_picks.bots)
	_play.teammate_difficulty = StringName(_picks.teammates)
	var custom: CustomRules = null if _smoke else _picks.custom_rules(Settings.shared())
	_play.custom_rules = custom.copy() if custom != null else null
	_play.map_id = map_id
	_play.lighting_pick = &"" if _smoke else _picks.lighting
	_play.player_team = team
	# --seed replays a match; else a fresh seed each Play (the smoke test keeps one fixed seed, so it plays the same match).
	if _spot != null:
		# back from the Loadout: the same range, its breeze and pop-ups as they were
		_play.match_seed = _spot.match_seed
		_play.challenge_on = _spot.challenge_on
	elif _launch_seed != LaunchSeed.NONE:
		_play.match_seed = _launch_seed
	else:
		_play.match_seed = SMOKE_SEED if _smoke else LaunchSeed.fresh()
	if _smoke:
		_play.speed = SMOKE_SPEED
	_play.staged = true
	# Loading into a match or the range waits for Continue once fully loaded (MC1); the smoke test and the way back
	# from practice's Loadout don't.
	_play.wait_for_go = continue_after_loading and not _smoke and _spot == null
	_show_loading(map_id, team)
	_play.progressed.connect(_loading.set_progress_step)
	_play.started.connect(_on_play_started)
	_play.ready_to_go.connect(_loading.show_continue)
	_loading.continued.connect(_on_continue)
	_play.left.connect(_end_play)
	_play.shaders_warmed.connect(graphics.settle)
	_play.loadout_requested.connect(_open_practice_loadout)
	_play.round_started.connect(_on_round_started)
	_play.error_log = error_log
	_spot = null
	_record_play(custom)
	add_child(_play)
	_scale_menus()
	_perf.watch(_play)


## The loading screen over everything, from PLAY until the match has drawn.
func _show_loading(map_id: String, team: int) -> void:
	var catalog := MapCatalog.shared()
	var entry := catalog.find(map_id)
	_loading = LoadingScreen.new()
	add_child(_loading)
	_loading.setup(map_id, entry.display_name if entry != null else map_id, entry.blurb if entry != null else "",
			MatchOptions.kicker(_play.mode, _team_size(), team))


## Players per team in the match starting: what its map plays under its rules (MatchOptions.team_size).
func _team_size() -> int:
	return MatchOptions.team_size(MapCatalog.shared().find(_play.map_id), _play.custom_rules)


## The match has drawn: the loading screen goes (unless it waits for Continue) and the frame rate is the player's limit
## (no menu cap).
func _on_play_started() -> void:
	if _play == null or not _play.holding():
		_free_loading()
	SettingsApply.set_menus(Settings.shared(), false)


## Continue on the loading screen: the match starts and the screen goes.
func _on_continue() -> void:
	if _play != null:
		_play.go()
	_free_loading()


func _free_loading() -> void:
	if _loading != null:
		_loading.queue_free()
		_loading = null


## Practice's Loadout (its key, or the pause menu's row): where you stand is kept, the range is freed and the menus open as
## the Loadout alone, on the slot in hand.
func _open_practice_loadout() -> void:
	if _play == null or not _play.practice or _smoke:
		return
	_spot = _play.practice_spot()
	_record_menus()
	_perf.watch(null)
	_free_loading()
	_play.queue_free()
	_play = null
	_build_screens()
	SettingsApply.set_menus(Settings.shared(), true)
	_title.visible = false
	_menus.visible = true
	_menus.open_practice_loadout(_spot.slot as Loadout.Slot)
	_scale_menus()


## From the Loadout from practice: the range is built again on the spot (the loadouts are saved by `_start_play`).
func _back_to_practice() -> void:
	if _spot != null:
		_start_play()


func _end_play() -> void:
	if _play == null:
		return
	if _smoke and _play.practice:
		_smoke_plates = _play.plate_hits
		_smoke_range_left_at = _frame
	elif _smoke:
		_smoke_shots = _play.all_shots
		_smoke_impacts = _play.impacts
		_smoke_rounds = _play.rounds_played
		_smoke_matches = _play.matches_played
		_smoke_orders = _play.orders_given
		_smoke_mags = _play.mag_presses
		_smoke_left_at = _frame
	_record_menus()
	_perf.watch(null)
	_free_loading()
	_play.queue_free()
	_play = null
	_build_screens()
	SettingsApply.set_menus(Settings.shared(), true)
	# Leaving a match or the range lands on the Match page with Play focused, the picks kept (owner, 2026-10-30); the
	# title is the AIRSOFT wordmark away.
	_show_menus()
	_scale_menus()


# --- The run record ---

## The run's start, written before anything is built: a run that never closed is kept as `previous`; a second copy
## beside a running one records nothing.
func _start_run() -> void:
	if run_path == "":
		if _smoke or DisplayServer.get_name() == "headless" or EngineDebugger.is_active():
			return
		run_path = RunRecord.PATH
	if not run_process_running.is_valid():
		run_process_running = ProcessCheck.is_running
	var r := RunRecord.load_file(run_path)
	if r.held_by_other(OS.get_process_id(), run_process_running):
		return
	r.start(Version.current(), int(Time.get_unix_time_from_system()), OS.get_process_id())
	run = r
	run.save(run_path)


## The match (or the range) about to open, `custom` its Custom rules (null for the mode's own).
func _record_play(custom: CustomRules) -> void:
	if run == null:
		return
	if _play.practice:
		run.practise(_play.map_id)
	else:
		var size := _team_size()
		run.play(_play.match_seed, _play.map_id, _play.mode, custom.to_dict() if custom != null else {},
				_play.player_team, String(_play.difficulty), String(_play.teammate_difficulty), [size, size])
	run.save(run_path)


func _on_round_started(number: int, score: PackedInt32Array) -> void:
	if run == null:
		return
	run.round_started(number, score)
	run.save(run_path)


func _record_menus() -> void:
	if run == null:
		return
	run.to_menus()
	run.save(run_path)


# --- The crash screen ---

## The crash screen over the hidden title when the last run closed unexpectedly: true if it shows.
func _show_crash_screen() -> bool:
	if run == null or not run.crashed_before():
		return false
	var config := ReportConfig.load_default()
	var tail := LogTail.new()
	tail.dir = crash_log_dir
	crash_screen = CrashScreen.new(run.previous, tail, Settings.shared(), config, ReportScrub.for_this_machine(config))
	if crash_open.is_valid():
		crash_screen.open_url = crash_open
	if crash_copy.is_valid():
		crash_screen.copy_text = crash_copy
	crash_screen.log_dir = crash_log_dir
	crash_screen.reported.connect(_crash_shown)
	crash_screen.continued.connect(_crash_continued)
	_title.visible = false
	add_child(crash_screen)
	move_child(crash_screen, _title.get_index() + 1)
	return true


## The crash has been seen: the record forgets it.
func _crash_shown() -> void:
	run.previous = {}
	run.save(run_path)


## Continue: the title, and its notices as on any start.
func _crash_continued() -> void:
	# a second Continue in the same frame finds the screen gone
	if crash_screen == null:
		return
	_crash_shown()
	crash_screen.queue_free()
	crash_screen = null
	_title.visible = true
	_title.focus_start()
	graphics.show_boot_notices(_title)


# --- Graphics at start-up ---

## Starts the game again with the same options (less a renderer option, GraphicsStartUp.restart_args), once this one
## has quit: the safe start's trip, and Settings › Save file after a restore, an Undo or a delete.
func _restart() -> void:
	OS.set_restart_on_exit(true, GraphicsStartUp.restart_args(OS.get_cmdline_args()))
	get_tree().quit()


## The first start's Graphics settings: the menus, and the settings on their Graphics tab.
func _open_graphics_settings() -> void:
	if _title == null or _menus == null:
		return
	_show_menus()
	_open_settings()
	_settings_screen.show_graphics()


## Esc in the menus, the title included, asks QUIT GAME? (owner, 2026-10-29). Whatever has Esc of its own took it first
## (a dialog or popup, a key being rebound, the Loadout's rename and Customise, the credits): this only sees what is left.
## In a match Esc is the pause menu's.
func _unhandled_input(event: InputEvent) -> void:
	if _play != null or _loading != null or crash_screen != null or _quit_prompt != null or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		ask_quit()


## Opens QUIT GAME? over whatever shows; QUIT leaves the game, CANCEL (or Esc again) closes it.
func ask_quit() -> void:
	if _quit_prompt != null:
		return
	_quit_prompt = QuitPrompt.new()
	_quit_prompt.confirmed.connect(get_tree().quit)
	_quit_prompt.closed.connect(_quit_closed)
	add_child(_quit_prompt)
	_quit_prompt.cancel_button().grab_focus()


func _quit_closed() -> void:
	_quit_prompt = null
	# the prompt gave the keyboard back to what had it; if that is gone, the screen's own default button takes it
	if get_viewport().gui_get_focus_owner() != null:
		return
	if _title != null and _title.visible:
		_title.focus_start()
	elif _menus != null and _menus.visible:
		_menus.focus_page()


func _process(_delta: float) -> void:
	if not _smoke:
		return
	_frame += 1
	_smoke_bug_report()
	if _frame == SMOKE_SETTINGS_OPEN:
		_show_menus()
		_open_settings()
	elif _frame == SMOKE_SETTINGS_CLOSE:
		if _settings_screen != null:
			_settings_screen.close()
	elif _frame == SMOKE_CREDITS_OPEN:
		_credits.open()
	elif _frame == SMOKE_CREDITS_CLOSE:
		_credits.close()
	elif _frame == SMOKE_LOADOUT_OPEN:
		_on_tab(TopBar.Tab.LOADOUT)
	elif _frame == SMOKE_CUSTOMISE_OPEN:
		if _menus.loadout_page() != null:
			_menus.loadout_page().show_customise()
	elif _frame == SMOKE_LOADOUT_CLOSE:
		_on_tab(TopBar.Tab.MATCH)
	elif _frame == SMOKE_ARMORY_OPEN:
		_on_tab(TopBar.Tab.ARMORY)
	elif _frame == SMOKE_ARMORY_CLOSE:
		_on_tab(TopBar.Tab.MATCH)
	elif _frame == SMOKE_PLAY:
		_start_play()
	elif _smoke_ordering():
		_smoke_order()
	elif _play != null and not _play.practice and (_play.matches_played > 0 or _play.ticks() >= SMOKE_MAX_TICKS):
		_end_play()
	elif _play != null and _play.practice and (_play.plate_hits > 0 or _play.ticks() >= SMOKE_RANGE_MAX_TICKS):
		_end_play()
	elif _play == null and _smoke_range_left_at < 0 and _smoke_left_at >= 0 and _frame >= _smoke_left_at + SMOKE_SETTLE:
		_start_play(true)
	elif _smoke_range_left_at >= 0 and _frame >= _smoke_range_left_at + SMOKE_SETTLE:
		_smoke_report()


## Whether the smoke match is ready for its next squad order step: the first round live, you in play.
func _smoke_ordering() -> bool:
	if _play == null or _play.practice or _play.ticks() == 0 or _smoke_order_step >= SMOKE_ORDER_STEPS.size():
		return false
	return _play.state.round_state.is_live() and Elimination.is_in_play(_play.player)


## The next squad order step, through the input as a player's keys and mouse would come (a step's key is let go on the
## step after).
func _smoke_order() -> void:
	var step := SMOKE_ORDER_STEPS[_smoke_order_step]
	_smoke_order_step += 1
	if step.is_empty() or step == "<":
		var flick := SMOKE_WHEEL_FLICK if step.is_empty() else SMOKE_MAG_FLICK
		var motion := InputEventMouseMotion.new()
		motion.relative = flick
		motion.screen_relative = flick
		Input.parse_input_event(motion)
		return
	var e := InputEventAction.new()
	e.action = StringName(step.substr(1))
	e.pressed = step.begins_with("+")
	Input.parse_input_event(e)


func _smoke_report() -> void:
	set_process(false)
	if not _credits.has_notices():
		push_error("smoke: the credits have no licence notices (is THIRD_PARTY_NOTICES.txt exported?)")
		get_tree().quit(1)
		return
	if _smoke_shots <= 0 or _smoke_impacts <= 0 or _smoke_matches <= 0:
		push_error("smoke: Depot played %d shots, %d impacts, %d rounds and %d whole matches with bots" % [_smoke_shots,
				_smoke_impacts, _smoke_rounds, _smoke_matches])
		get_tree().quit(1)
		return
	if _smoke_plates <= 0:
		push_error("smoke: practice on the range rang no plate")
		get_tree().quit(1)
		return
	if _smoke_orders <= 0:
		push_error("smoke: no squad order of yours reached the match (%d of %d steps)" % [_smoke_order_step,
				SMOKE_ORDER_STEPS.size()])
		get_tree().quit(1)
		return
	if _smoke_mags <= 0:
		push_error("smoke: no Need a Mag of yours reached the match")
		get_tree().quit(1)
		return
	print("[smoke] ok frames=%d credits_chars=%d shots=%d impacts=%d rounds=%d plates=%d orders=%d mags=%d" % [_frame,
			_credits.text_length(), _smoke_shots, _smoke_impacts, _smoke_rounds, _smoke_plates, _smoke_orders,
			_smoke_mags])
	get_tree().quit(0)

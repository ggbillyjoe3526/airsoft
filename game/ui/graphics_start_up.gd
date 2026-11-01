class_name GraphicsStartUp
extends RefCounted
## The graphics at start-up, for the entry scene (game/main.gd): the safe start's check before anything is built
## (GraphicsGuard, RendererOverride) and its question on the title; once per change of reason, why the game is on the
## simpler renderer; and once ever, the first start's notice (concept `first-run.png`: the automatic pick, the card and
## the screen; OK or Graphics settings; Settings.first_start_seen). Nothing is guarded in the smoke run, a headless one
## or one the editor started (its Stop button ends a run as a crash would), unless a test gives `guard_path`; the
## first start's notice never shows in the smoke run or a headless one, unless a test sets `headless_notices`.

## Graphics settings on the first start's notice: the entry scene opens Settings › Graphics.
signal graphics_settings_requested

## The safe start's record, or null where nothing is guarded. Tests point the paths at their own files and replace
## `restart` (the entry scene's own quits and starts the game again with the same options) and `process_running`
## (whether a process id is another running copy of this game: ProcessCheck.is_running).
var guard: GraphicsGuard = null
var guard_path: String = ""
var renderer_path: String = RendererOverride.PATH
var settings_path: String = Settings.PATH
var restart: Callable = Callable()
var process_running: Callable = Callable()
## Tests: the first start's notice in a headless run.
var headless_notices: bool = false
var _smoke: bool = false


## The safe start's check, before anything is built: on a start that never drew its first match, the safe graphics are
## written and `restart` is called (RESTART_SAFE). `smoke`: the smoke run.
func start(smoke: bool) -> GraphicsGuard.Action:
	_smoke = smoke
	var unguarded := smoke or _headless() or EngineDebugger.is_active()
	if guard_path == "" and unguarded:
		return GraphicsGuard.Action.NONE
	if guard_path == "":
		guard_path = GraphicsGuard.PATH
	if not process_running.is_valid():
		process_running = ProcessCheck.is_running
	var s := Settings.shared()
	var machine := GraphicsApply.machine()
	RendererOverride.sync(s.renderer, renderer_path)
	guard = GraphicsGuard.load_file(guard_path)
	if guard.held_by_other(OS.get_process_id(), process_running):
		# a second copy beside the first: the first one's record, untouched
		guard = null
		return GraphicsGuard.Action.NONE
	guard.pid = OS.get_process_id()
	var low := GraphicsTable.shared().preset(GraphicsGuard.SAFE_PRESET)
	var safe_now := machine.rendering_method == GraphicsPick.COMPATIBILITY \
			and s.graphics_in_force(machine.preset).equals(low)
	var action := guard.start(safe_now)
	if action == GraphicsGuard.Action.RESTART_SAFE:
		guard.trip(s, machine.preset)
		s.save(settings_path)
		RendererOverride.put(s.renderer, renderer_path)
		print(LogTail.RESTART_LINE)
	guard.save(guard_path)
	if action == GraphicsGuard.Action.RESTART_SAFE and restart.is_valid():
		restart.call()
	return action


## `args` without `--rendering-method` and its value: a restart's options, so the renderer the restart is for
## (user://renderer.cfg) is the one it gets, not the safe graphics shortcut's.
static func restart_args(args: PackedStringArray) -> PackedStringArray:
	var kept := PackedStringArray()
	var i := 0
	while i < args.size():
		if args[i] == "--rendering-method":
			i += 2
			continue
		if not args[i].begins_with("--rendering-method="):
			kept.append(args[i])
		i += 1
	return kept


## The graphics started: the first match's shaders warmed, or a clean quit.
func settle() -> void:
	if guard != null and guard.settle():
		guard.save(guard_path)


## The safe start's question on `title`, while it waits for an answer (each title built).
func show_safe_notice(title: TitleScreen) -> void:
	if guard == null or not guard.asking():
		return
	var machine := GraphicsApply.machine()
	var was := guard.previous
	var words := GraphicsNotice.graphics_words(StringName(str(was["graphics_choice"])),
			GraphicsPick.pick(machine.adapter_type, RendererOverride.FORWARD_PLUS),
			clampi(int(was["renderer"]), 0, Settings.Renderer.size() - 1) as Settings.Renderer)
	var s := Settings.shared()
	var now := GraphicsNotice.graphics_words(s.graphics_choice, machine.preset, s.renderer)
	var notice := GraphicsNotice.safe_start(words, now)
	notice.chosen.connect(_on_safe_answer.bind(title))
	title.show_notice(notice)
	# the safe notice says why the game is on the simpler renderer
	guard.notice_due(RendererOverride.REASON_SETTINGS)
	guard.save(guard_path)


## The notices of a start, on its first title: why the game is on the simpler renderer (once per change of reason),
## else the first start's (once ever). Neither while the safe start asks.
func show_boot_notices(title: TitleScreen) -> void:
	if title.notice() != null:
		return
	if not _show_renderer_notice(title):
		_show_first_start(title)


## Whether the first start's notice is due for `s`: never seen, the graphics the automatic pick (nothing chosen, no
## `--graphics=` preset), and a player at the screen (not the smoke run, nor a headless one).
static func first_start_due(s: Settings, unattended: bool) -> bool:
	# A newer build's file is kept as it is and can't be marked seen, so its first start was that build's (BP2).
	return not unattended and not s.first_start_seen and s.graphics_choice == Settings.GRAPHICS_AUTOMATIC \
			and s.graphics_forced == &"" and not s.from_newer_build()


## Keep safe graphics (0), or Try my settings again (1): the player's graphics back, and a restart.
func _on_safe_answer(index: int, title: TitleScreen) -> void:
	title.close_notice()
	if index == 0:
		guard.keep()
		guard.save(guard_path)
		return
	var s := Settings.shared()
	guard.try_again(s)
	s.save(settings_path)
	RendererOverride.put(s.renderer, renderer_path)
	guard.save(guard_path)
	if restart.is_valid():
		restart.call()


## Once per change of reason, why the game is on the simpler renderer: true if it showed.
func _show_renderer_notice(title: TitleScreen) -> bool:
	if guard == null or guard.asking():
		return false
	var machine := GraphicsApply.machine()
	var shown := guard.renderer_notice
	var due := guard.notice_due(RendererOverride.reason_now(machine.rendering_method))
	if guard.renderer_notice != shown:
		guard.save(guard_path)
	if not due:
		return false
	var card := SettingsGraphicsPage.card_words(machine)
	var renderer := SettingsGraphicsPage.renderer_words(machine)
	var notice := GraphicsNotice.simpler_renderer(guard.renderer_notice, card, renderer)
	notice.chosen.connect(func(_i: int) -> void: title.close_notice())
	title.show_notice(notice)
	return true


## The first start's notice, once: marked seen and saved as it shows, so it never comes back.
func _show_first_start(title: TitleScreen) -> void:
	var s := Settings.shared()
	if not first_start_due(s, _smoke or (_headless() and not headless_notices)):
		return
	var machine := GraphicsApply.machine()
	var at := DisplayServer.window_get_current_screen()
	var screen := GraphicsNotice.screen_words(DisplayServer.screen_get_size(at),
			DisplayServer.screen_get_refresh_rate(at), s.window_mode)
	var notice := GraphicsNotice.first_start(machine.preset, SettingsGraphicsPage.card_words(machine), screen)
	notice.chosen.connect(_on_first_start_answer.bind(title))
	title.show_notice(notice)
	s.first_start_seen = true
	s.save(settings_path)


## OK (0), or Graphics settings (1), which opens Settings › Graphics.
func _on_first_start_answer(index: int, title: TitleScreen) -> void:
	title.close_notice()
	if index == 1:
		graphics_settings_requested.emit()


static func _headless() -> bool:
	return DisplayServer.get_name() == "headless"

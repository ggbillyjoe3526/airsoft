class_name WindowWatch
extends Node
## The window's keys and focus, everywhere (menus, play, the pause menu): F11 or Alt+Enter switches between a window and
## the last fullscreen mode and saves it (SettingsApply.toggle_fullscreen), and while the game is in the background
## (unfocused or minimised) it draws DisplayConfig.background_fps (SettingsApply.set_focused).
##
## The keys are read in `_input`, before a focused button takes Enter. A node later in the tree has its `_input` first,
## and the main scene adds this before any settings screen or match, so a key list waiting for a key to bind takes F11
## and Alt+Enter itself.

## What it switches and saves; the game's own when unset.
var settings: Settings = null
## Where it saves (a test points this at a temporary file).
var save_path: String = Settings.PATH


func _ready() -> void:
	name = "WindowWatch"
	process_mode = Node.PROCESS_MODE_ALWAYS
	if settings == null:
		settings = Settings.shared()
	var screens := SettingsApply.screens()
	screens.set_min_size(screens.config.min_window)


func _input(event: InputEvent) -> void:
	if not SettingsApply.screens().config.is_toggle(event):
		return
	get_viewport().set_input_as_handled()
	SettingsApply.toggle_fullscreen(settings)
	settings.mark_changed()
	settings.save_if_dirty(save_path)


func _notification(what: int) -> void:
	if settings == null:
		return
	# the window's own focus and the application's, whichever the system sends (minimising loses focus)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		SettingsApply.set_focused(settings, false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		SettingsApply.set_focused(settings, true)

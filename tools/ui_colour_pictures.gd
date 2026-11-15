extends SceneTree
## Pictures of each interface colour (UA2): Settings › Display with the colour picked there (the real click, so the
## menus are built again as in play), then the Match page once the settings close, grabbed whole to
## `<folder>/<n>_<name>_display.png` and `<folder>/<n>_<name>_match.png`. Needs a display and OpenGL, and a scratch save
## folder (the settings are saved):
##   XDG_DATA_HOME=/tmp/x XDG_CONFIG_HOME=/tmp/xc xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
##       --rendering-driver opengl3 -s res://tools/ui_colour_pictures.gd -- <folder>
## Dev only: tools/ never ships. Puts the colour back to the default at the end.

const SIZE := Vector2i(1920, 1080)
const SETTLE := 10


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab(path: String) -> void:
	await _frames(SETTLE)
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(path)
	print("[ui_colour_pictures] ", path)


func _run() -> void:
	var folder := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(folder)
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE
	await _frames(4)
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await _frames(SETTLE)
	main._menus.close_notice()
	for pick: int in UiColours.Pick.values():
		var name := String(UiColours.Pick.keys()[pick]).to_lower()
		main._on_tab(NavRail.Tab.SETTINGS)
		var screen: SettingsScreen = main._settings_screen
		screen.show_display_colour()
		screen._display_page.ui_colour().button(pick).pressed.emit()
		await _frames(SETTLE)
		await _grab("%s/%d_%s_display.png" % [folder, pick, name])
		main._settings_screen.close()
		await _grab("%s/%d_%s_match.png" % [folder, pick, name])
	var s := Settings.shared()
	s.ui_colour = UiColours.DEFAULT
	SettingsApply.apply_ui_colour(s)
	s.save()
	main.queue_free()
	await _frames(4)
	quit()

extends SceneTree
## A picture of the Settings On/Off switch, off then on, big, for review (BP8): `<folder>/<tag>_switches.png`. Needs a
## display and OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 800x300x24" godot --path . --rendering-driver opengl3 -s res://tools/switch_pictures.gd \
##       -- <folder> <tag>
## Dev only: tools/ never ships.

const SCALE := 4.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(args[0])
	DisplayServer.window_set_size(Vector2i(800, 300))
	root.size = Vector2i(800, 300)
	var back := ColorRect.new()
	back.color = GameTheme.BG
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)
	var row := HBoxContainer.new()
	row.theme = GameTheme.get_theme()
	row.scale = Vector2(SCALE, SCALE)
	row.position = Vector2(60.0, 110.0)
	row.add_theme_constant_override("separation", 40)
	root.add_child(row)
	for on: bool in [false, true]:
		var s := MenuSwitch.new("On", "Off")
		s.put(on)
		row.add_child(s)
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s_switches.png" % [args[0], args[1]])
	quit(0)

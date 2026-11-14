extends SceneTree
## A held button, drawn the old way (the control's `scale` shrunk about its middle) and the new (ButtonPress drawing it
## through the shrunk transform while the control keeps its size: AUD2, KNOWN_ISSUES 29), compared pixel for pixel.
## Saves `<folder>/<name>_{rest,scale,drawn}.png` (the button's own rectangle, 12 px over) and prints how many pixels
## differ between the two ways. Needs a display and OpenGL; under xvfb:
##   XDG_DATA_HOME=/tmp/x XDG_CONFIG_HOME=/tmp/xc xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
##       --rendering-driver opengl3 -s res://tools/button_dip_pictures.gd -- <folder>
## Dev only: tools/ never ships.

const SETTLE := 8
const MARGIN := 12.0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The picture over `area`, the button's own rectangle at rest (a scaled control's rectangle shrinks with it).
func _crop(area: Rect2) -> Image:
	await _frames(SETTLE)
	var image := root.get_viewport().get_texture().get_image()
	return image.get_region(Rect2i(area.grow(MARGIN)))


func _diff(a: Image, b: Image) -> Vector2i:
	var count := 0
	var worst := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			var d := maxf(maxf(absf(p.r - q.r), absf(p.g - q.g)), maxf(absf(p.b - q.b), absf(p.a - q.a)))
			var d8 := roundi(d * 255.0)
			if d8 > 0:
				count += 1
				worst = maxi(worst, d8)
	return Vector2i(count, worst)


func _one(folder: String, name: String, b: Button, ring_shown: bool) -> void:
	var ring := ButtonPress.new()
	b.add_child(ring, false, Node.INTERNAL_MODE_BACK)
	if ring_shown:
		ring.visible = true
	await _frames(2)
	var area := b.get_global_rect()
	var rest := await _crop(area)
	var longest := maxf(b.size.x, b.size.y)
	var dip := maxf(ButtonPress.PRESS_SCALE, 1.0 - 2.0 * ButtonPress.MAX_DIP / longest)
	# the old way: the control itself scaled about its middle
	b.pivot_offset_ratio = ButtonPress.PIVOT
	b.scale = Vector2.ONE * dip
	var by_scale := await _crop(area)
	var again := await _crop(area)
	var engine := b.get_transform()
	b.scale = Vector2.ONE
	await _frames(2)
	# the new way: the control untouched, its drawing shrunk
	var ours := ButtonPress.dipped(b.get_transform(), b.size, dip)
	ring._set_dip(dip)
	var drawn := await _crop(area)
	ring._set_dip(1.0)
	var kept := b.scale == Vector2.ONE
	rest.save_png("%s/%s_rest.png" % [folder, name])
	by_scale.save_png("%s/%s_scale.png" % [folder, name])
	drawn.save_png("%s/%s_drawn.png" % [folder, name])
	var d := _diff(by_scale, drawn)
	var from_rest := _diff(rest, drawn)
	print("[dip] %s engine %s ours %s; the same picture twice differs in %d px" % [name, engine, ours, _diff(by_scale, again).x])
	print("[dip] %s dip %.4f size %s: %d px differ between scale and drawn (worst %d/255); the dip itself changes %d px; control scale kept: %s" % [
			name, dip, b.size, d.x, d.y, from_rest.x, kept])
	ring.queue_free()


func _run() -> void:
	var folder := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(folder)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	await _frames(4)
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await _frames(SETTLE)
	var menus: MenuScreen = main._menus
	menus.close_notice()
	await _frames(SETTLE)
	var page := menus.match_page()
	await _one(folder, "play_card", page.play_button(), false)
	await _one(folder, "play_card_ringed", page.play_button(), true)
	var card: Button = page._map_cards["depot"]
	await _one(folder, "field_card", card, false)
	await _one(folder, "field_card_ringed", card, true)
	var skirmish: Button = page.rules_box().rules_button(MatchOptions.RULES_SKIRMISH)
	await _one(folder, "small_button", skirmish, false)
	main.queue_free()
	await _frames(2)
	quit()

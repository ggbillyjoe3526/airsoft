extends GutTest
## BP6's menus, HUD and debug fixes that have no older test file of their own: the bot intention labels spaced apart
## (test_dev_play checks they are hidden by walls).


## Labels over three bots standing together, seen from a camera in front: the nearest stays, the others step up.
func test_intention_labels_that_would_overlap_step_up_a_line_each() -> void:
	var port := SubViewport.new()
	port.size = Vector2i(1920, 1080)
	port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(port)
	var view := BotIntentView.new()
	port.add_child(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position = Vector3(0.0, 1.8, 10.0)
	camera.current = true
	for i in 3:
		var l := Label3D.new()
		l.fixed_size = true
		l.pixel_size = BotIntentView.PIXEL
		l.font_size = BotIntentView.FONT_SIZE
		l.text = "Bot %d advancing" % i
		view.add_child(l)
		view._labels.append(l)
		view._widths.append(200.0)
		l.position = Vector3(0.1 * i, 2.2, -0.3 * i)
	view._depth.resize(3)
	await wait_process_frames(1)
	view._space(camera)
	assert_eq(view._labels[0].offset.y, 0.0, "the nearest stays")
	var steps := [roundi(view._labels[1].offset.y / BotIntentView.LINE), roundi(view._labels[2].offset.y / BotIntentView.LINE)]
	assert_eq(steps, [1, 2], "one and two lines up")
	await wait_process_frames(1)
	var top_up := view._labels[2].get_aabb().end.y
	view._labels[2].offset.y = 0.0
	await wait_process_frames(1)
	assert_gt(top_up, view._labels[2].get_aabb().end.y, "a positive offset is up")
	view._labels[1].position = Vector3(5.0, 2.2, 0.0)
	view._labels[2].position = Vector3(-5.0, 2.2, 0.0)
	view._space(camera)
	for l in view._labels:
		assert_eq(l.offset.y, 0.0, "apart on screen: none moves")


## The UI audit: a paint's name too long for its tile is set smaller to fit, never cut; a short one keeps its size.
func test_a_long_paint_name_is_set_smaller_to_fit_its_tile() -> void:
	var label := MenuParts.text("Ranger green", CustomiseView.TILE_NAME_SIZE, 700, GameTheme.TEXT)
	label.clip_text = true
	label.resized.connect(CustomiseView.fit_name.bind(label))
	add_child_autofree(label)
	label.size = Vector2(78.0, 20.0)
	var size := label.get_theme_font_size("font_size")
	assert_lt(size, CustomiseView.TILE_NAME_SIZE)
	var wide := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	assert_lte(wide, 78.0 - CustomiseView.TILE_NAME_ROOM * 2.0, "the whole name fits")
	label.text = "Tan"
	label.size = Vector2(71.0, 20.0)
	assert_eq(label.get_theme_font_size("font_size"), CustomiseView.TILE_NAME_SIZE, "a short name keeps its size")


## The UI audit: the credits' title is in the display face other pages' titles use.
func test_the_credits_title_is_a_page_title() -> void:
	var credits := Credits.new()
	add_child_autofree(credits)
	var title := credits.find_child("Title", true, false) as Label
	assert_not_null(title)
	var font := title.get_theme_font("font") as FontVariation
	assert_eq(font.base_font, GameTheme.heading_face(700), "Barlow Condensed, as the other pages")


## The UI audit: the map pictures carry mipmaps, so the Match page's cards (a fifth of their size) draw them smooth.
func test_the_map_pictures_have_mipmaps() -> void:
	for map_id: String in ["depot", "range", "street", "woodland"]:
		var picture := load("res://assets/maps/%s.jpg" % map_id) as Texture2D
		assert_true(picture.get_image().has_mipmaps(), map_id)
	assert_eq(MenuBackdrop.blurred("res://assets/maps/depot.jpg").get_image().has_mipmaps(), false, "the blur needs none")


## BP6: the Armory's level track takes focus, and left and right pick the dot beside the picked one.
func test_the_level_dots_step_with_the_keyboard() -> void:
	var dots := ArmoryDots.new(5, 2, 0.5)
	dots.size = Vector2(600.0, ArmoryDots.HEIGHT)
	add_child_autofree(dots)
	assert_eq(dots.focus_mode, Control.FOCUS_ALL)
	var got: Array[int] = []
	dots.level_picked.connect(func(n: int) -> void: got.append(n))
	var right := InputEventAction.new()
	right.action = &"ui_right"
	right.pressed = true
	var left := InputEventAction.new()
	left.action = &"ui_left"
	left.pressed = true
	dots._gui_input(right)
	assert_eq(dots.picked(), 3, "unpicked: the next level first")
	dots._gui_input(right)
	dots._gui_input(right)
	assert_eq(dots.picked(), 4, "past the end it stays")
	dots._gui_input(left)
	dots._gui_input(left)
	assert_eq(dots.picked(), 2)
	assert_eq(got, [3, 4, 3, 2] as Array[int])


## BP6: the replica panel's count stands in a line as tall as its size (the concept's line height 1), not the font's.
func test_the_replica_count_line_is_its_size() -> void:
	var font := HudStyle.tight_font(800, HudStyle.COUNT_SIZE)
	assert_almost_eq(font.get_height(HudStyle.COUNT_SIZE), float(HudStyle.COUNT_SIZE), 1.0)
	assert_gt(GameTheme.font(800).get_height(HudStyle.COUNT_SIZE), HudStyle.COUNT_SIZE + 4.0, "Inter's own line is taller")
	var label := Label.new()
	label.text = "30"
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", HudStyle.COUNT_SIZE)
	add_child_autofree(label)
	assert_almost_eq(label.get_minimum_size().y, float(HudStyle.COUNT_SIZE), 1.0)


## BP6: the settings' custom-drawn controls carry their row's name for a screen reader, and so do the paint tiles and the
## Armory's level track.
func test_custom_controls_have_accessible_names() -> void:
	var screen := SettingsScreen.new()
	screen.settings = Settings.new(PlayTuning.new())
	screen.save_path = "user://test-bp6-names/settings.save"
	add_child_autofree(screen)
	assert_eq(screen._speed.accessibility_name, tr("DEV_GAME_SPEED"))
	assert_eq((screen._dev_checks[&"ghost"] as Control).accessibility_name, tr("DEV_GHOST"))
	assert_eq(screen._time_of_day.accessibility_name, tr("DEV_TIME_OF_DAY"))
	var dots := ArmoryDots.new(3)
	assert_ne(dots.accessibility_name, "")
	dots.free()


## The pause menu's panel is see-through: the crosshair is not drawn under it, and comes back on resume.
func test_the_crosshair_hides_while_the_pause_menu_is_up() -> void:
	var session := PlaySession.new()
	session.bots_active = false
	add_child_autofree(session)
	await wait_physics_frames(2)
	var hud := session.hud()
	var before := hud.crosshair_drawn()
	session._open_pause()
	assert_true(get_tree().paused)
	assert_false(hud.crosshair_drawn(), "not under the pause panel")
	assert_false(hud.team_markers_shown(), "nor the teammates' markers")
	session._resume()
	assert_false(get_tree().paused)
	assert_eq(hud.crosshair_drawn(), before, "back as it was")
	assert_true(hud.team_markers_shown())
	get_tree().paused = false

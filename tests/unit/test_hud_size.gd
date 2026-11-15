extends GutTest
## HUD size (AC5, concept `settings-hud-size.png`): every part of the HUD scales about its anchor and stays on the
## screen from 80 to 150 % at 1280×720 and 1920×1080, while the crosshair, the hit marker and the sound cue ring keep
## their own size; the markers over the field stay over what they mark; the HUD tab's slider, its mark at 100 % and the
## preview following it; and a change reaching a match at once, as from the pause menu.

const SIZES: Array[float] = [0.8, 1.5]
## The windows played in: the HUD is laid out on the game's canvas (1920×1080, project.godot's canvas_items stretch with
## aspect expand), so a window sets its shape, not its pixels. 4:3 and 21:9 too, for the canvas's other shapes.
const WINDOWS: Array[Vector2] = [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0), Vector2(1024.0, 768.0),
		Vector2(2560.0, 1080.0)]
## A rect may touch the screen's edge within this (px, float rounding).
const EDGE_SLACK := 0.5

var map: MapData = null
var you: Character = null
var state: GameState = null


func before_all() -> void:
	map = MapData.load_map("depot", MapStyle.new(), 1)


func before_each() -> void:
	you = Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	you.prev_position = you.position
	state = GameState.new(1)
	state.characters.append(you)


func after_each() -> void:
	get_tree().paused = false


## The canvas a window of `window` px shows the HUD on: the project's base size, widened or heightened to the window's
## shape (Godot's canvas_items stretch, aspect expand).
static func canvas_of(window: Vector2) -> Vector2:
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	if window.x / window.y > base.x / base.y:
		return Vector2(base.y * window.x / window.y, base.y)
	return Vector2(base.x, base.x * window.y / window.x)


## A HUD on a screen of `area` with every part a match shows built (minimap, orders, sound cues).
func _hud(area: Vector2) -> Hud:
	var frame := Control.new()
	frame.size = area
	add_child_autofree(frame)
	var hud := Hud.new()
	frame.add_child(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	var cfg := MinimapConfig.new()
	hud.setup_minimap(map, cfg, MinimapHearing.new(cfg), "Depot", 1)
	hud.setup_orders(ControlsConfig.new())
	var access := AccessibilityConfig.new()
	hud.setup_sound_cues(SoundCues.new(access, PlayTuning.new().sound), access)
	hud.set_sound_cues(true, 1.0, 0)
	hud._stats = MatchStats.new()
	hud._names = PackedStringArray(["You"])
	return hud


## Shows what a busy moment shows: the score bar with the step-down line, a banner, whom you watch and the skip hint,
## What got you; then lays it out.
func _busy(hud: Hud) -> void:
	hud.show_graphics_step("Low", 5.0)
	hud._show_banner("ROUND 3", "Alpha wins")
	hud.set_watching("Beta 2")
	hud.set_skip_hint(true)
	hud.show_what_got_you(HitFacts.new(), "Beta 2", Color.ORANGE, "")
	hud.update(state, 1.0, 0.0)


func _prefs_at(hud_size: float) -> HudPrefs:
	var p := HudPrefs.new()
	p.hud_size = hud_size
	return p


## The parts drawn as the HUD's own (not the crosshair's), by name.
func _parts(hud: Hud) -> Dictionary[String, Control]:
	return {
		"score bar": hud._top, "replica panel": hud._replica, "hit feed": hud.feed(), "minimap": hud.minimap(),
		"banner": hud._banner, "bottom line": hud._bottom, "skip hint": hud._skip_hint,
		"step-down line": hud.graphics_step_line(), "what got you": hud.what_got_you(), "scoreboard": hud.board(),
	}


## Each part shown on `hud` inside `area`; returns how many were checked.
func _on_screen(hud: Hud, area: Vector2, label: String) -> int:
	var screen := Rect2(Vector2.ZERO, area).grow(EDGE_SLACK)
	var parts := _parts(hud)
	var checked := 0
	for part_name in parts:
		var part := parts[part_name]
		if not part.is_visible_in_tree():
			continue
		checked += 1
		var r := part.get_global_rect()
		assert_true(screen.encloses(r), "%s %s: %s off %s" % [part_name, label, r, area])
	return checked


func test_every_part_stays_on_screen_from_80_to_150_percent() -> void:
	for window in WINDOWS:
		var area := canvas_of(window)
		for hud_size in SIZES:
			var hud := _hud(area)
			hud.apply_prefs(_prefs_at(hud_size))
			_busy(hud)
			await wait_process_frames(2)
			var label := "at %d%% in %s" % [roundi(hud_size * 100.0), window]
			assert_eq(_on_screen(hud, area, label), 9, "every part but the scoreboard shows " + label)
			# Tab held: the scoreboard over the middle, What got you put away.
			hud.show_board(true)
			hud.update(state, 1.0, 0.0)
			await wait_process_frames(2)
			assert_true(hud.board().is_visible_in_tree())
			_on_screen(hud, area, label + " with the scoreboard")
			hud.get_parent().queue_free()


func test_the_canvas_is_the_game_s() -> void:
	assert_eq(canvas_of(Vector2(1280.0, 720.0)), Vector2(1920.0, 1080.0), "720p shows the 1080p canvas, smaller")
	assert_eq(canvas_of(Vector2(1024.0, 768.0)), Vector2(1920.0, 1440.0), "4:3 is taller")
	assert_eq(canvas_of(Vector2(2560.0, 1080.0)), Vector2(2560.0, 1080.0), "21:9 is wider")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand")


func test_the_root_covers_the_screen_and_each_part_keeps_its_anchor() -> void:
	var area := canvas_of(WINDOWS[1])
	for hud_size in SIZES:
		var hud := _hud(area)
		hud.apply_prefs(_prefs_at(hud_size))
		_busy(hud)
		await wait_process_frames(1)
		assert_almost_eq(hud.get_global_rect().size, area, Vector2.ONE * 0.01, "the root covers the screen")
		assert_eq(hud.hud_size(), hud_size)
		# The replica panel keeps its margin to the bottom-right corner, grown with it.
		var panel := hud._replica.get_global_rect()
		assert_almost_eq(panel.end, area - Vector2.ONE * Hud.MARGIN * hud_size, Vector2.ONE * 0.01, "panel %s" % hud_size)
		assert_almost_eq(panel.size, Hud.PANEL_LANE * hud_size, Vector2.ONE * 0.01)
		# The score bar stays centred at the top.
		var top := hud._top.get_global_rect()
		assert_almost_eq(top.get_center().x, area.x * 0.5, 0.01, "score bar centred")
		assert_almost_eq(top.position.y, HudStyle.SCORE_TOP * hud_size, 0.01)
		hud.get_parent().queue_free()


func test_the_crosshair_and_the_cue_ring_keep_their_own_size() -> void:
	var area := canvas_of(WINDOWS[1])
	var gaps: Array[float] = []
	for hud_size: float in [1.0, 0.8, 1.5]:
		var hud := _hud(area)
		hud.apply_prefs(_prefs_at(hud_size))
		hud.update(state, 1.0, 0.0)
		gaps.append(hud._gap)
		var ring := hud.sound_cues()
		assert_almost_eq(ring.get_global_transform().get_scale(), Vector2.ONE, Vector2.ONE * 1e-5, "the ring at 1")
		var drawn := ring.get_global_rect()
		assert_almost_eq(drawn.position, Vector2.ZERO, Vector2.ONE * 0.01)
		assert_almost_eq(drawn.size, area, Vector2.ONE * 0.01, "the ring's middle is the screen's")
		hud.get_parent().queue_free()
	assert_gt(gaps[0], 0.0, "the crosshair shows")
	assert_almost_eq(gaps[1], gaps[0], 1e-4, "the crosshair's gap is the spread on the screen at 80 %")
	assert_almost_eq(gaps[2], gaps[0], 1e-4, "and at 150 %")


func test_a_change_rescales_the_ring_and_the_root_again() -> void:
	var area := canvas_of(WINDOWS[0])
	var hud := _hud(area)
	hud.apply_prefs(_prefs_at(1.5))
	hud.apply_prefs(_prefs_at(0.8))
	await wait_process_frames(1)
	assert_almost_eq(hud.scale, Vector2.ONE * 0.8, Vector2.ONE * 1e-6)
	assert_almost_eq(hud.get_global_rect().size, area, Vector2.ONE * 0.01)
	assert_almost_eq(hud.sound_cues().get_global_rect().size, area, Vector2.ONE * 0.01)
	for m: Node in [hud.team_markers(), hud._flag_marker, hud.hold_marker()]:
		assert_almost_eq(m.get("hud_size"), 0.8, 1e-6, "%s places by the size" % m.name)


func test_the_flag_marker_stays_over_the_pole_and_grows_with_the_hud() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.position = Vector3(0.0, 1.6, 0.0)
	var pole := Vector3(4.0, 0.0, -30.0)
	var top := pole + Vector3.UP * HudConfig.new().flag_marker_height
	var widths: Array[float] = []
	for hud_size in SIZES:
		var hud := _hud(get_viewport().get_visible_rect().size)
		hud.apply_prefs(_prefs_at(hud_size))
		# Placed every frame, as in play: the plate takes its size from its words a frame on.
		for i in 2:
			hud.place_flag_marker(camera, pole, true)
			await wait_process_frames(1)
		hud.place_flag_marker(camera, pole, true)
		var drawn := hud._flag_marker.get_global_rect()
		var tip := camera.unproject_position(top)
		assert_almost_eq(Vector2(drawn.get_center().x, drawn.end.y), tip, Vector2.ONE * 0.5, "its tail on the pole")
		widths.append(drawn.size.x)
		hud.get_parent().queue_free()
	assert_almost_eq(widths[1] / widths[0], SIZES[1] / SIZES[0], 0.05, "its plate grows with the HUD")


func test_a_teammate_s_marker_stays_over_their_head() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.position = Vector3(0.0, 1.6, 0.0)
	var mate := Character.new(1, 0, Vector3(-3.0, 0.0, -12.0), 0.0, ReplicaStats.default_loadout())
	mate.prev_position = mate.position
	state.characters.append(mate)
	var body := BodyConfig.new()
	var cfg := HudConfig.new()
	var top := mate.position + Vector3.UP * (Character.eye_height(0.0, body) + cfg.team_marker_lift)
	for hud_size in SIZES:
		var hud := _hud(get_viewport().get_visible_rect().size)
		hud.setup_field(BoxWorld.new(), body, PackedStringArray(["You", "Alpha 2"]), state.characters, hud._stats)
		hud.apply_prefs(_prefs_at(hud_size))
		await wait_process_frames(1)
		hud.place_team_markers(camera, state.characters, you, 1.0)
		var marker := hud.team_markers().get_child(0) as Control
		var drawn := marker.get_global_rect()
		assert_almost_eq(Vector2(drawn.get_center().x, drawn.end.y), camera.unproject_position(top), Vector2.ONE * 0.5,
				"over their head at %s" % hud_size)
		assert_almost_eq(drawn.size.x, HudTeamMarkers.SIZE.x * hud_size, 0.01, "grown with the HUD")
		hud.get_parent().queue_free()


func test_the_summary_row_keeps_its_size_at_100_and_fits_at_150() -> void:
	for window in WINDOWS:
		var area := canvas_of(window)
		for hud_size: float in [1.0, 1.5]:
			var hud := _hud(area)
			hud.apply_prefs(_prefs_at(hud_size))
			hud.open_summary(state, true, "Hold the angle")
			hud.update(state, 1.0, 0.0)
			await wait_process_frames(2)
			var summary: MatchSummary = hud.summary()
			assert_true(summary.is_visible_in_tree())
			if hud_size == 1.0 and area.x >= 1920.0:
				assert_eq(summary.fit(), 1.0, "as built at 100 %% in %s" % window)
			for part: Control in [summary.table(), summary._side]:
				var r := part.get_global_rect()
				assert_true(Rect2(Vector2.ZERO, area).grow(EDGE_SLACK).encloses(r),
						"%s at %d%% in %s: %s" % [part.name, roundi(hud_size * 100.0), window, r])
			hud.get_parent().queue_free()


func test_the_order_wheel_fits_the_smallest_canvas_at_150() -> void:
	var half := OrderWheelLayout.new(ControlsConfig.new()).half_extent()
	var smallest := canvas_of(WINDOWS[1])
	for window in WINDOWS:
		smallest = smallest.min(canvas_of(window))
	assert_lt(half.y * 2.0 * SIZES[1], smallest.y, "the wheel's columns, at 150 %, inside the canvas's height")
	assert_lt(half.x * 2.0 * SIZES[1], smallest.x, "and both columns inside its width")


# --- the HUD tab ---

func _page() -> SettingsHudPage:
	var s := Settings.new(PlayTuning.new())
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = "user://test-hud-size/settings.save"
	DirAccess.make_dir_recursive_absolute("user://test-hud-size")
	add_child_autofree(screen)
	screen.open()
	return screen._hud_page


func test_the_tab_s_slider_runs_80_to_150_by_5_and_marks_100() -> void:
	var page := _page()
	var slider := page.hud_size()
	assert_eq([slider.min_value, slider.max_value, slider.step], [80.0, 150.0, 5.0])
	assert_eq(slider.value, 100.0, "100 % by default")
	var mark := slider.get_node("Mark") as Control
	assert_not_null(mark, "a mark at 100 %")
	await wait_process_frames(1)
	var share := (100.0 - 80.0) / (150.0 - 80.0)
	assert_almost_eq(mark.call("at") / slider.size.x, share, 0.05, "two sevenths along")
	assert_false(page.preview().size_tag().visible, "at 100 % the preview needs no tag")
	assert_false(page.preview().ghosts().visible)


func test_the_preview_follows_the_slider() -> void:
	var page := _page()
	var slider := page.hud_size()
	slider.value = 125.0
	assert_almost_eq(page._screen.settings.hud.hud_size, 1.25, 1e-6, "lands in the settings")
	var preview := page.preview()
	assert_almost_eq(preview.panel().scale.x, HudPreview.PART_SCALE * 1.25, 1e-5, "the panel grows")
	assert_almost_eq(preview.feed_row().scale.x, HudPreview.PART_SCALE * 1.25, 1e-5, "the feed line grows")
	assert_true(preview.size_tag().visible)
	assert_eq(preview.size_tag().text(), "HUD SIZE 125%")
	assert_true(preview.ghosts().visible, "dashed outlines at 100 %")
	await wait_process_frames(1)
	var ghosts := preview.ghost_rects()
	var panel := preview.panel().get_global_rect()
	assert_almost_eq(ghosts[1].size * 1.25, panel.size, Vector2.ONE * 0.5, "the outline is the panel at 100 %")
	assert_almost_eq(ghosts[1].end + preview.global_position, panel.end, Vector2.ONE * 0.5, "both from its corner")
	slider.value = 100.0
	assert_false(preview.size_tag().visible)


# --- in play ---

func test_a_change_reaches_a_match_at_once() -> void:
	var settings := Settings.new(PlayTuning.new())
	var session := PlaySession.new()
	session.settings = settings
	session.bots_active = false
	add_child_autofree(session)
	await wait_physics_frames(2)
	assert_eq(session.hud().hud_size(), 1.0)
	settings.hud.hud_size = 1.5
	settings.mark_changed()
	assert_eq(session.hud().hud_size(), 1.5, "applied at once (the settings open from the pause menu)")
	assert_almost_eq(session.hud().scale, Vector2.ONE * 1.5, Vector2.ONE * 1e-6)
	assert_almost_eq(session._skip_note.get_parent().scale, Vector2.ONE * 1.5, Vector2.ONE * 1e-6,
			"the skipping note too")

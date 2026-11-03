extends GutTest
## The HUD tab (HO1): its choices saved with the settings and read back each on its own (HudPrefs), the crosshair's
## gap, the hit feed's lines that stay, the HUD taking the choices (apply_prefs) and the tab itself with its preview.

const SAVE := "user://test-hud-prefs.save"


func after_each() -> void:
	DirAccess.remove_absolute(SAVE)


func test_the_choices_survive_a_save_and_a_load() -> void:
	var s := Settings.new(PlayTuning.new())
	s.hud.shape = HudPrefs.Shape.CIRCLE
	s.hud.colour = 3
	s.hud.size = 11.0
	s.hud.opacity = 0.45
	s.hud.dynamic = false
	s.hud.outline = true
	s.hud.marker = false
	s.hud.marker_colour = 5
	s.hud.marker_size = 2.0
	s.hud.ammo_counter = false
	s.hud.feed_corner = HudPrefs.FeedCorner.BOTTOM_LEFT
	s.hud.feed_lines = HudPrefs.FeedLines.KEEP
	s.hud.panel_opacity = 0.7
	s.hud.minimap_turn = HudPrefs.MinimapTurn.FIXED
	assert_true(s.save(SAVE))
	var back := Settings.new(PlayTuning.new())
	back.load_file(SAVE)
	assert_eq(back.hud.to_dict(), s.hud.to_dict())


func test_a_bad_value_falls_back_on_its_own() -> void:
	var p := HudPrefs.new()
	p.from_dict({"shape": 9, "colour": 2, "size": 99.0, "gap": 6, "opacity": "full", "outline": 1, "marker": false,
			"feed_corner": 1.5, "feed_lines": 1, "panel_opacity": 0.1, "minimap_turn": 2})
	var d := HudPrefs.new()
	assert_eq(p.shape, d.shape, "no fifth shape")
	assert_eq(p.colour, 2)
	assert_eq(p.size, d.size, "out of range")
	assert_eq(p.gap, 6.0, "a whole number reads as px")
	assert_eq(p.opacity, d.opacity, "not a number")
	assert_eq(p.outline, d.outline, "not a bool")
	assert_false(p.marker)
	assert_eq(p.feed_corner, d.feed_corner, "not a whole number")
	assert_eq(p.feed_lines, HudPrefs.FeedLines.KEEP)
	assert_eq(p.panel_opacity, d.panel_opacity, "under the slider's range")
	assert_eq(p.minimap_turn, HudPrefs.MinimapTurn.ROTATING, "no third turn")


func test_an_old_save_without_the_tab_keeps_the_defaults() -> void:
	var s := Settings.new(PlayTuning.new())
	var data := s.to_dict()
	data.erase("hud")
	var back := Settings.new(PlayTuning.new())
	back.from_dict(data)
	assert_eq(back.hud.to_dict(), HudPrefs.new().to_dict())


func test_no_team_colour_among_the_crosshair_colours() -> void:
	var teams := TeamConfig.new()
	for c in HudPrefs.COLOURS:
		for team in teams.colours:
			assert_false(c.is_equal_approx(team), "%s is a team's colour" % c)


func test_a_hud_saved_before_the_minimap_loads_rotating() -> void:
	var data := HudPrefs.new().to_dict()
	data.erase("minimap_turn")
	data["shape"] = int(HudPrefs.Shape.DOT)
	var p := HudPrefs.new()
	p.minimap_turn = HudPrefs.MinimapTurn.FIXED
	p.from_dict(data)
	assert_eq(p.minimap_turn, HudPrefs.MinimapTurn.ROTATING, "the default, not what was set before")
	assert_eq(p.shape, HudPrefs.Shape.DOT, "the rest still loads")


func test_a_dynamic_crosshair_opens_with_the_spread_and_a_static_one_keeps_its_gap() -> void:
	var p := HudPrefs.new()
	p.gap = 5.0
	assert_eq(CrosshairDraw.gap(p, 2.0), 5.0, "never closer than the gap")
	assert_eq(CrosshairDraw.gap(p, 20.0), 20.0)
	p.dynamic = false
	assert_eq(CrosshairDraw.gap(p, 20.0), 5.0)


func test_kept_lines_stay_and_never_fade() -> void:
	var feed := HitFeed.new()
	feed.setup(HudPrefs.KEPT_LINES, 6.0, 1.0)
	feed.stay = true
	feed.add(1, 2, 0.0)
	feed.add(3, 4, 1.0)
	feed.prune(100.0)
	assert_eq(feed.count(), 2)
	assert_eq(feed.alpha(0, 100.0), 1.0)
	for i in HudPrefs.KEPT_LINES:
		feed.add(1, 2, 2.0 + i)
	assert_eq(feed.count(), HudPrefs.KEPT_LINES, "only the newest ten")


func test_the_hud_takes_the_choices() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	p.feed_corner = HudPrefs.FeedCorner.BOTTOM_LEFT
	p.feed_lines = HudPrefs.FeedLines.KEEP
	p.ammo_counter = false
	p.panel_opacity = 0.5
	hud.apply_prefs(p)
	assert_eq(hud.feed().corner, HudFeed.Place.BOTTOM_LEFT)
	assert_true(hud.hit_lines().stay)
	assert_eq(hud.hit_lines().max_lines, HudPrefs.KEPT_LINES)
	assert_false(hud._replica.counted())
	assert_almost_eq(hud._replica.modulate.a, 0.5, 0.001, "the replica panel fades (UR8)")
	p.feed_lines = HudPrefs.FeedLines.FADE
	p.ammo_counter = true
	p.panel_opacity = 1.0
	hud.apply_prefs(p)
	assert_false(hud.hit_lines().stay)
	assert_eq(hud.hit_lines().max_lines, HudConfig.new().feed_lines)
	assert_true(hud._replica.counted())
	assert_almost_eq(hud._replica.modulate.a, 1.0, 0.001)


func test_the_panel_opacity_stays_with_the_hud() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	p.panel_opacity = 0.6
	hud.apply_prefs(p)
	assert_almost_eq(hud._replica.modulate.a, 0.6, 0.001, "the replica panel")
	assert_almost_eq(HudStyle.backing_on(hud.score(), 1.0).a, 1.0, 0.001, "the score stays solid (UR8)")
	var row := HudFeedRow.new()
	add_child_autofree(row)
	assert_almost_eq(HudStyle.backing_on(row, 1.0).a, 1.0, 0.001, "a part outside it draws as built")


func test_the_tab_saves_a_pick_and_the_preview_follows() -> void:
	var s := Settings.new(PlayTuning.new())
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = SAVE
	add_child_autofree(screen)
	screen.open()
	var page: SettingsHudPage = screen._hud_page
	page._shape.button(HudPrefs.Shape.DOT).pressed.emit()
	assert_eq(s.hud.shape, HudPrefs.Shape.DOT)
	assert_false(s.dirty, "a click saves at once")
	page._colour.button(4).pressed.emit()
	assert_eq(s.hud.colour, 4)
	page._opacity.value = 40.0
	assert_almost_eq(s.hud.opacity, 0.4, 0.001)
	page._corner.button(HudPrefs.FeedCorner.BOTTOM_LEFT).pressed.emit()
	assert_eq(s.hud.feed_corner, HudPrefs.FeedCorner.BOTTOM_LEFT)
	assert_eq(page.preview().feed_row().anchor_left, 0.0, "the preview's feed line moved")
	page._ammo.toggled.emit(false)
	assert_false(s.hud.ammo_counter)
	assert_false(page.preview().panel().counted())
	page._panels.value = 60.0
	assert_almost_eq(s.hud.panel_opacity, 0.6, 0.001)
	assert_eq(s.hud.minimap_turn, HudPrefs.MinimapTurn.ROTATING, "turning north up is the player's to pick")
	page._turn.button(HudPrefs.MinimapTurn.FIXED).pressed.emit()
	assert_eq(s.hud.minimap_turn, HudPrefs.MinimapTurn.FIXED)
	assert_false(s.dirty, "a click saves at once")
	screen.close()
	var back := Settings.new(PlayTuning.new())
	back.load_file(SAVE)
	var saved := back.hud.to_dict()
	for key: String in saved:
		assert_almost_eq(float(saved[key]), float(s.hud.to_dict()[key]), 0.0001, "%s saved by the closing" % key)


func test_the_tab_shows_the_saved_choices() -> void:
	var s := Settings.new(PlayTuning.new())
	s.hud.shape = HudPrefs.Shape.CROSS_DOT
	s.hud.marker_size = 1.5
	s.hud.feed_lines = HudPrefs.FeedLines.KEEP
	s.hud.minimap_turn = HudPrefs.MinimapTurn.FIXED
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = SAVE
	add_child_autofree(screen)
	screen.open()
	var page: SettingsHudPage = screen._hud_page
	assert_eq(page._shape.selected(), HudPrefs.Shape.CROSS_DOT)
	assert_eq(page._marker_size.value, 150.0)
	assert_eq(page._lines.selected(), HudPrefs.FeedLines.KEEP)
	assert_eq(page._turn.selected(), HudPrefs.MinimapTurn.FIXED)
	assert_eq(page._what_got_you.selected(), s.what_got_you)


func _hud() -> Hud:
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(),
			Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	return hud



func test_the_hud_size_is_saved_checked_and_kept_on_the_sliders_steps() -> void:
	assert_eq(HudPrefs.new().hud_size, 1.0, "100 % by default")
	var p := HudPrefs.new()
	p.hud_size = 1.25
	var back := HudPrefs.new()
	back.from_dict(p.to_dict())
	assert_almost_eq(back.hud_size, 1.25, 1e-6, "saved and read back")
	for bad: Variant in [0.5, 1.6, "big", null, NAN]:
		back.from_dict({"hud_size": bad})
		assert_eq(back.hud_size, 1.0, "%s keeps the default" % str(bad))
	back.from_dict({"hud_size": 1.27, "colour": 3})
	assert_almost_eq(back.hud_size, 1.25, 1e-6, "between steps reads as the nearest")
	assert_eq(back.colour, 3, "a good value beside it is kept")
	back.from_dict({"hud_size": 1.5})
	assert_almost_eq(back.hud_size, 1.5, 1e-6, "the top of the range")


func test_a_hud_saved_before_the_hud_size_loads_at_100_percent() -> void:
	var data := HudPrefs.new().to_dict()
	data.erase("hud_size")
	data["size"] = 9.0
	var p := HudPrefs.new()
	p.from_dict(data)
	assert_eq(p.hud_size, 1.0)
	assert_eq(p.size, 9.0, "the rest loads unchanged")

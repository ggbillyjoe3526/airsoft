extends GutTest
## QA for HO1 (the HUD tab): the HUD following a change made in the settings mid-round, the panels' opacity reaching
## every navy backing, the feed's Keep lines in the bottom-left corner, the ammo counter off, old and bad saves, the
## tab's keyboard reach and its fit at 1080p.

const SAVE := "user://test_ho1qa_settings.save"
const BAD_SAVE := "user://test_ho1qa_bad.save"


func after_each() -> void:
	for path: String in [SAVE, BAD_SAVE]:
		for end: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(path + end)


## Pause menu › Settings › HUD opacity: the tab's preview shows it, then the save tells the HUD, which fades its
## replica panel and minimap (owner, 2026-11-03).
func test_a_panel_opacity_change_from_the_open_settings_reaches_the_hud() -> void:
	var s := Settings.new(PlayTuning.new())
	var hud := _hud()
	hud.apply_prefs(s.hud)
	s.changed.connect(func() -> void: hud.apply_prefs(s.hud))
	var screen := _screen(s)
	screen.open()
	screen._hud_page._panels.value = 50.0
	screen.close()
	assert_almost_eq(s.hud.panel_opacity, 0.5, 0.001)
	assert_almost_eq(HudStyle.opacity_of(hud._replica), 0.5, 0.001, "the replica panel follows the tab")


## A preview showing a choice never reaches the HUD: each holds its own opacity.
func test_the_preview_s_opacity_never_reaches_the_hud() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	hud.apply_prefs(p)
	var preview := HudPreview.new()
	add_child_autofree(preview)
	var shown := HudPrefs.new()
	shown.panel_opacity = 0.6
	preview.show_prefs(shown)
	assert_almost_eq(HudStyle.opacity_of(hud._replica), 1.0, 0.001)
	assert_almost_eq(HudStyle.backing_on(hud.score(), 1.0).a, 1.0, 0.001)


## The HUD opacity fades only the replica panel and the minimap (owner, 2026-11-03): the flag marker, plate and tail,
## stays solid.
func test_the_flag_marker_stays_solid_whatever_the_hud_opacity() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	p.panel_opacity = 0.5
	hud.apply_prefs(p)
	var marker: HudFlagMarker = hud._flag_marker
	var plate := marker._plate.get_theme_stylebox("panel") as StyleBoxFlat
	assert_almost_eq(plate.bg_color.a, HudStyle.BACKING_CLOCK, 0.001, "the plate stays")
	assert_almost_eq(HudStyle.backing_on(marker, HudStyle.BACKING_CLOCK).a, plate.bg_color.a, 0.001,
			"the tail matches its plate")
	assert_almost_eq(marker.modulate.a, 1.0, 0.001)


## Parts outside the replica panel and the minimap (What got you, the summary's panels) stay solid at any HUD opacity.
func test_other_parts_stay_solid_whatever_the_hud_opacity() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	p.panel_opacity = 0.7
	hud.apply_prefs(p)
	var records := hud.summary().records().get_theme_stylebox("panel") as StyleBoxFlat
	assert_almost_eq(records.bg_color.a, MatchSummary.BACKING, 0.001, "the summary's records panel")
	hud.show_what_got_you(HitFacts.new(), "Dash", Color.ORANGE, "")
	var card := hud.what_got_you().get_theme_stylebox("panel") as StyleBoxFlat
	assert_almost_eq(card.bg_color.a, WhatGotYouCard.BACKING, 0.001, "What got you")
	assert_almost_eq(hud.what_got_you().modulate.a, 1.0, 0.001)
	assert_almost_eq(HudStyle.opacity_of(hud._replica), 0.7, 0.001, "the replica panel fades")


## The restyle leaves a box that isn't a navy one (no meta) alone.
func test_the_restyle_leaves_other_boxes_alone() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var other := PanelContainer.new()
	var own := GameTheme.box(GameTheme.CARD, GameTheme.LINE, 0, 0)
	var alpha := own.bg_color.a
	other.add_theme_stylebox_override("panel", own)
	root.add_child(other)
	HudStyle.restyle(root, 0.5)
	assert_eq(own.bg_color.a, alpha)


## Keep in the bottom-left corner: ten lines show, newest at the bottom, and none fades or ages out.
func test_ten_kept_lines_show_bottom_left_newest_last() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	p.feed_corner = HudPrefs.FeedCorner.BOTTOM_LEFT
	p.feed_lines = HudPrefs.FeedLines.KEEP
	hud.apply_prefs(p)
	var people := _people()
	for i in 12:
		hud.hit_lines().add(1, 0 if i == 11 else 2, float(i))
	hud.hit_lines().prune(1000.0)
	hud.feed().refresh(hud.hit_lines(), 1000.0, people, people[0])
	assert_eq(hud.feed().shown(), HudPrefs.KEPT_LINES)
	var newest := hud.feed().row_of(0)
	assert_eq(newest.get_index(), hud.feed().get_child_count() - 1, "newest at the bottom")
	assert_eq(newest.modulate.a, 1.0)


## Applying the same choice again (every other setting's save) must not clear a Keep feed mid-match.
func test_another_settings_change_keeps_the_kept_lines() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	p.feed_lines = HudPrefs.FeedLines.KEEP
	hud.apply_prefs(p)
	hud.hit_lines().add(1, 2, 0.0)
	hud.hit_lines().add(2, 1, 1.0)
	p.colour = 3
	hud.apply_prefs(p)
	assert_eq(hud.hit_lines().count(), 2)
	p.feed_lines = HudPrefs.FeedLines.FADE
	hud.apply_prefs(p)
	assert_eq(hud.hit_lines().count(), 0, "switching to Fade clears, as the record says")
	assert_eq(hud.hit_lines().max_lines, HudConfig.new().feed_lines)


## Keep with the round's own line (you were hit): released at the round's end, it still stays.
func test_a_kept_line_released_at_the_round_end_stays_in_keep() -> void:
	var feed := HitFeed.new()
	feed.setup(HudPrefs.KEPT_LINES, 6.0, 1.0)
	feed.stay = true
	feed.add(1, 0, 0.0, true)
	feed.release_kept()
	feed.prune(500.0)
	assert_eq(feed.count(), 1)
	assert_eq(feed.alpha(0, 500.0), 1.0)


## Ammo counter off: the counts stay hidden through a refresh with an empty loaded magazine and a holster.
func test_ammo_counter_off_stays_off_through_refreshes() -> void:
	var panel := ReplicaPanel.new()
	add_child_autofree(panel)
	panel.setup(HudConfig.new())
	var a := Armament.create(ReplicaStats.default_loadout())
	panel.set_counted(false)
	if not a.replicas.is_empty():
		a.ammo[0].mag = 0
		panel.refresh(a)
	assert_false(panel.counted())
	panel.set_counted(true)
	assert_true(panel.counted())


## A save whose "hud" is not a table, or holds the wrong types, keeps the defaults; the rest still loads.
func test_a_bad_hud_entry_in_the_save_keeps_the_defaults() -> void:
	var s := Settings.new(PlayTuning.new())
	s.fov = 95.0
	var data := s.to_dict()
	data["hud"] = "crosshair"
	assert_true(SaveFile.write(BAD_SAVE, Settings.KIND, Settings.VERSION, data))
	var back := Settings.new(PlayTuning.new())
	back.load_file(BAD_SAVE)
	assert_eq(back.hud.to_dict(), HudPrefs.new().to_dict())
	assert_eq(back.fov, 95.0)
	var p := HudPrefs.new()
	p.from_dict({"shape": 2.0, "colour": -1, "size": INF, "gap": 0, "thickness": NAN, "marker_size": 2.5,
			"feed_lines": true, "panel_opacity": 0.5})
	assert_eq(p.shape, HudPrefs.Shape.CIRCLE, "JSON reads whole numbers as floats")
	assert_eq(p.colour, 0)
	assert_eq(p.size, 7.0)
	assert_eq(p.gap, 0.0)
	assert_eq(p.thickness, 2.0)
	assert_eq(p.marker_size, 2.5)
	assert_eq(p.feed_lines, HudPrefs.FeedLines.FADE)
	assert_eq(p.panel_opacity, 0.5)


## The crosshair draws at every extreme and shape without a script error, gap 0 included.
func test_every_shape_draws_at_the_extremes() -> void:
	var hud := _hud()
	for shape in HudPrefs.Shape.size():
		for corner: Vector3 in [Vector3(HudPrefs.SIZE_RANGE.x, HudPrefs.THICKNESS_RANGE.x, HudPrefs.GAP_RANGE.x),
				Vector3(HudPrefs.SIZE_RANGE.y, HudPrefs.THICKNESS_RANGE.y, HudPrefs.GAP_RANGE.y)]:
			var p := HudPrefs.new()
			p.shape = shape as HudPrefs.Shape
			p.size = corner.x
			p.thickness = corner.y
			p.gap = corner.z
			p.outline = true
			hud.apply_prefs(p)
			hud._marker_left = 0.2
			hud.queue_redraw()
			await wait_process_frames(1)
	assert_eq(hud.prefs().shape, HudPrefs.Shape.DOT)


## Every button the tab adds takes keyboard focus.
func test_the_tabs_buttons_take_keyboard_focus() -> void:
	var screen := _screen(Settings.new(PlayTuning.new()))
	screen.open()
	var page: SettingsHudPage = screen._hud_page
	for choice: MenuChoice in [page._shape, page._colour, page._spread, page._marker_colour, page._corner, page._lines,
			screen._what_got_you]:
		for b in choice.get_children():
			assert_ne((b as Button).focus_mode, Control.FOCUS_NONE)


## The What got you choice (on the Gameplay tab since BP7) still sets the setting the card reads.
func test_what_got_you_on_the_gameplay_tab_sets_the_setting() -> void:
	var s := Settings.new(PlayTuning.new())
	var screen := _screen(s)
	screen.open()
	screen._what_got_you.button(Settings.WhatGotYou.OFF).pressed.emit()
	assert_eq(s.what_got_you, Settings.WhatGotYou.OFF)
	assert_false(s.dirty, "saved at once")


## At 1920x1080 the HUD tab fits its page with no overflow.
func test_the_tab_fits_at_1080p() -> void:
	var frame := Control.new()
	frame.size = Vector2(1920.0, 1080.0)
	add_child_autofree(frame)
	var screen := SettingsScreen.new()
	screen.settings = Settings.new(PlayTuning.new())
	screen.save_path = SAVE
	frame.add_child(screen)
	screen.open()
	screen._tabs.current_tab = screen._hud_page.get_parent().get_parent().get_index()
	await wait_process_frames(2)
	var scroll := screen._hud_page.get_parent().get_parent() as Control
	assert_lte(screen._hud_page.get_combined_minimum_size().x, scroll.size.x, "the tab fits its page")
	assert_lte(screen._tabs.get_combined_minimum_size().x, 1920.0, "the tabs fit the window")


func _hud() -> Hud:
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), _people()[0])
	return hud


func _people() -> Array[Character]:
	var out: Array[Character] = []
	for i in 3:
		out.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	return out


func _screen(s: Settings) -> SettingsScreen:
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = SAVE
	add_child_autofree(screen)
	return screen


## The preview's replica panel takes the tab's HUD opacity; its feed line stays solid.
func test_the_preview_s_parts_take_the_tab_s_opacity() -> void:
	var preview := HudPreview.new()
	add_child_autofree(preview)
	var p := HudPrefs.new()
	p.panel_opacity = 0.6
	preview.show_prefs(p)
	assert_almost_eq(HudStyle.backing_on(preview.feed_row(), 1.0).a, 1.0, 0.001, "the feed line's backing")
	assert_almost_eq(HudStyle.opacity_of(preview.panel()), 0.6, 0.001, "the replica panel's background (UF1)")
	assert_almost_eq(preview.panel().modulate.a, 1.0, 0.001, "its words stay solid")


## The What got you card's dial (a part that draws its own backing) stays solid with its card.
func test_the_what_got_you_dial_stays_solid() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	p.panel_opacity = 0.5
	hud.apply_prefs(p)
	hud.show_what_got_you(HitFacts.new(), "Dash", Color.ORANGE, "")
	var dials: Array[Node] = []
	for n in hud.what_got_you().find_children("*", "Control", true, false):
		if n.get_class() == "Control" and n.get_script() != null and n.get_parent() is HBoxContainer:
			dials.append(n)
	for d in dials:
		assert_almost_eq(HudStyle.backing_on(d as CanvasItem, 1.0).a, 1.0, 0.001)
	assert_gt(dials.size(), 0, "the dial was found")

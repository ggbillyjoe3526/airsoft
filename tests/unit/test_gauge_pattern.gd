extends GutTest
## Gauge patterns (AC3; game/ui/gauge_pattern.gd): 45° stripes cached per shape and kept inside it, built again only
## when the shape changes; Beta's score pips, block and flag fill striped and Alpha's solid in both colour sets with
## the switch on, nothing striped with it off; redrawn only on a change and nothing allocated per frame; the
## Accessibility tab's Patterns row live with its sample.

const EPS := 0.01


## Whether every stripe of `p`, at its full width, lies inside the convex polygon `shape`.
func _inside(p: GaugePattern, shape: PackedVector2Array) -> bool:
	var half := GaugePattern.ACROSS * HudStyle.STRIPE_WIDTH * 0.5
	var centre := Vector2.ZERO
	for q in shape:
		centre += q
	centre /= shape.size()
	for end in p.lines:
		for corner: Vector2 in [end + half, end - half]:
			for e in shape.size():
				var a := shape[e]
				var edge := shape[(e + 1) % shape.size()] - a
				var m := Vector2(-edge.y, edge.x).normalized()
				if m.dot(centre - a) < 0.0:
					m = -m
				if m.dot(corner - a) < -EPS:
					return false
	return true


func _corners(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


# --- the pattern ---

func test_stripes_are_45_degrees_apart_by_width_and_gap_and_inside_the_rect() -> void:
	var p := GaugePattern.new()
	var r := Rect2(10.0, 20.0, 64.0, 73.0)
	p.set_rect(r)
	assert_gt(p.lines.size(), 20, "a score block holds many stripes")
	assert_eq(p.lines.size() % 2, 0, "pairs for draw_multiline")
	var across := PackedFloat32Array()
	for i in range(0, p.lines.size(), 2):
		var d := (p.lines[i + 1] - p.lines[i]).normalized()
		assert_almost_eq(d.dot(GaugePattern.ALONG), 1.0, 0.0001, "rising to the right at 45°")
		across.append(p.lines[i].dot(GaugePattern.ACROSS))
	for i in range(1, across.size()):
		assert_almost_eq(across[i] - across[i - 1], HudStyle.STRIPE_WIDTH + HudStyle.STRIPE_GAP, 0.001)
	assert_true(_inside(p, _corners(r)), "no stripe pokes out of the fill")


func test_a_slanted_pip_keeps_its_stripes_inside_too() -> void:
	var p := GaugePattern.new()
	var pip := HudStyle.pip_shape(Vector2(100.0, 25.0))
	p.set_shape(pip)
	assert_gt(p.lines.size(), 0)
	assert_true(_inside(p, pip))


func test_stripes_line_up_across_neighbouring_shapes() -> void:
	var a := GaugePattern.new()
	var b := GaugePattern.new()
	a.set_rect(Rect2(0.0, 0.0, 30.0, 12.0))
	b.set_rect(Rect2(33.0, 0.0, 30.0, 12.0))
	var period := HudStyle.STRIPE_WIDTH + HudStyle.STRIPE_GAP
	for p: GaugePattern in [a, b]:
		for i in range(0, p.lines.size(), 2):
			var c := p.lines[i].dot(GaugePattern.ACROSS) - HudStyle.STRIPE_WIDTH * 0.5
			assert_almost_eq(fposmod(c + period * 0.5, period) - period * 0.5, 0.0, 0.001, "on the canvas' grid")


func test_built_again_only_when_the_rect_changes() -> void:
	var p := GaugePattern.new()
	p.set_rect(Rect2(0.0, 0.0, 40.0, 20.0))
	assert_eq(p.builds, 1)
	var before := p.lines
	for i in 5:
		p.set_rect(Rect2(0.0, 0.0, 40.0, 20.0))
	assert_eq(p.builds, 1, "the same rect reuses the cached stripes")
	assert_eq(p.lines, before)
	p.set_rect(Rect2(0.0, 0.0, 40.0, 10.0))
	assert_eq(p.builds, 2)
	p.set_shape(HudStyle.pip_shape(Vector2.ZERO))
	p.set_shape(HudStyle.pip_shape(Vector2.ZERO))
	assert_eq(p.builds, 3, "a shape too")


func test_a_sliver_too_thin_for_a_stripe_has_none() -> void:
	var p := GaugePattern.new()
	p.set_rect(Rect2(0.0, 0.0, 8.0, 1.5))
	assert_eq(p.lines.size(), 0)
	p.set_rect(Rect2())
	assert_eq(p.lines.size(), 0)


func test_the_stripe_look_is_hud_style_s() -> void:
	assert_eq(HudStyle.STRIPE_INK, Color(GameTheme.BG, HudStyle.STRIPE_ALPHA), "dark ink at the stripe alpha")
	assert_eq(HudStyle.STRIPED_TEAM, 1, "Beta's fills are the striped ones")


# --- the score bar and the flag gauge ---

func _score(teams: TeamConfig) -> HudScore:
	var s := HudScore.new()
	add_child_autofree(s)
	s.setup(teams, 5)
	s.set_score(3, 2)
	return s


func test_beta_s_pips_and_block_are_striped_alpha_s_solid_in_both_sets() -> void:
	for colour_set: int in TeamColours.Set.values():
		var teams := TeamColours.resolve(colour_set as TeamColours.Set, false).hud
		var s := _score(teams)
		s.set_patterned(true)
		assert_false(s.striped(0), "Alpha solid, set %d" % colour_set)
		assert_true(s.striped(1), "Beta striped, set %d" % colour_set)
		assert_eq(s._score_labels[1].get_theme_constant("outline_size"), HudStyle.NUMBER_EDGE, "a dark edge")
		assert_eq(s._score_labels[0].get_theme_constant("outline_size"), 0)
		assert_eq(s._pip_stripes.size(), 5, "one cached pattern per Beta pip")
		assert_gt(s._block_stripes.lines.size(), 0)
		s.set_patterned(false)
		assert_false(s.striped(1), "off draws as today")
		assert_eq(s._score_labels[1].get_theme_constant("outline_size"), 0)


func test_beta_s_flag_fill_is_striped_and_alpha_s_solid() -> void:
	var g := HudFlagGauge.new()
	g.setup(12, 600.0)
	add_child_autofree(g)
	g.size = Vector2(600.0, HudStyle.GAUGE_HEIGHT)
	g.set_patterned(true)
	g.set_flag(0.5, Color.ORANGE, true)
	assert_true(g.striped())
	await wait_process_frames(1)
	assert_gt(g.notch_stripes(0).lines.size(), 0, "each filled notch's stripes built when drawn")
	assert_true(_inside(g.notch_stripes(3), _corners(g.notch_rect(3))))
	g.set_flag(0.5, Color.BLUE, false)
	assert_false(g.striped(), "Alpha raising: solid")
	g.set_flag(0.5, Color.ORANGE, true)
	g.set_patterned(false)
	assert_false(g.striped(), "off draws as today")


func test_redrawn_only_on_a_change_and_a_frame_allocates_nothing() -> void:
	var s := _score(TeamConfig.new())
	s.set_patterned(true)
	var g := HudFlagGauge.new()
	g.setup(12, 600.0)
	add_child_autofree(g)
	g.size = Vector2(600.0, HudStyle.GAUGE_HEIGHT)
	g.set_patterned(true)
	g.set_flag(0.5, Color.ORANGE, true)
	await wait_process_frames(2)
	var draws := [0]
	s.draw.connect(func() -> void: draws[0] += 1)
	g.draw.connect(func() -> void: draws[0] += 1)
	var builds := s._block_stripes.builds + g.notch_stripes(0).builds
	await wait_process_frames(3)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 10:
		s.set_score(3, 2)
		s.set_patterned(true)
		g.set_flag(0.5, Color.ORANGE, true)
		g.set_patterned(true)
		await wait_process_frames(1)
	assert_eq(draws[0], 0, "no change, no redraw")
	assert_eq(s._block_stripes.builds + g.notch_stripes(0).builds, builds, "the cached stripes kept")
	assert_lte(Performance.get_monitor(Performance.OBJECT_COUNT), objects, "no objects made in those frames (others may be freed)")
	s.set_score(3, 3)
	await wait_process_frames(1)
	assert_eq(draws[0], 1, "a change redraws")
	assert_eq(s._block_stripes.builds, 1, "a redraw rebuilds nothing")


# --- in play ---

func test_the_switch_reaches_the_hud_in_play_and_follows_the_attackers() -> void:
	var session := PlaySession.new()
	session.mode = MatchOptions.MODE_ATTACK_DEFEND
	session.bots_active = false
	session.settings = Settings.new(PlayTuning.new())
	add_child_autofree(session)
	await wait_physics_frames(2)
	var hud := session.hud()
	assert_true(session.settings.gauge_patterns, "on by default")
	assert_true(hud.score().striped(1))
	var rs := session.state.round_state
	rs.flag.progress = 0.5
	rs.attackers = 1
	hud.update(session.state, 1.0, 0.0)
	assert_true(hud.flag_gauge().striped(), "Beta raising: striped")
	rs.attackers = 0
	hud.update(session.state, 1.0, 0.0)
	assert_false(hud.flag_gauge().striped(), "Alpha raising: solid")
	rs.attackers = 1
	session.settings.gauge_patterns = false
	session.settings.changed.emit()
	hud.update(session.state, 1.0, 0.0)
	assert_false(hud.flag_gauge().striped(), "switched off mid-match")
	assert_false(hud.score().striped(1))
	get_tree().paused = false


# --- Settings › Accessibility ---

func test_the_patterns_row_is_live_and_its_sample_follows_the_switch_and_the_set() -> void:
	var s := Settings.new(PlayTuning.new())
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = "user://test-gauge-pattern/settings.save"
	DirAccess.make_dir_recursive_absolute("user://test-gauge-pattern")
	add_child_autofree(screen)
	screen.open()
	var page: SettingsAccessPage = screen._access_page
	assert_false(SettingsAccessPage.LATER.has(SettingsAccessPage.Section.GAUGE_PATTERNS), "no LATER")
	assert_false(page.greyed(SettingsAccessPage.Section.GAUGE_PATTERNS))
	var parts := page.sample_parts()
	assert_eq(parts.size(), 5, "each team's pips and block, and a low magazine")
	var striped: Array[bool] = []
	for p in parts:
		striped.append(p.striped)
	assert_eq(striped, [false, false, true, true, true] as Array[bool], "Beta's and the low magazine striped")
	assert_eq(parts[4].colour, GameTheme.WARN)
	page.patterns().toggled.emit(false)
	for p in parts:
		assert_false(p.striped, "off: solid")
	page.set_card(TeamColours.Set.HIGH_CONTRAST).pressed.emit()
	var hc := TeamColours.resolve(TeamColours.Set.HIGH_CONTRAST, false).hud
	assert_eq(parts[0].colour, hc.colours[0], "the picked set's HUD colours")
	assert_eq(parts[3].colour, hc.colours[1])
	screen.close()
	get_tree().paused = false


func test_a_centred_rect_has_a_stripe_through_its_middle() -> void:
	var p := GaugePattern.new()
	var fill := Rect2(1.5, 13.5, 8.0, 3.0)
	p.set_rect(fill, true)
	assert_eq(p.lines.size(), 2, "one short stripe in a magazine's low fill")
	assert_almost_eq(p.lines[0].dot(GaugePattern.ACROSS), fill.get_center().dot(GaugePattern.ACROSS), 0.001)
	assert_true(_inside(p, _corners(fill)))
	var builds := p.builds
	p.set_rect(fill, true)
	assert_eq(p.builds, builds)
	p.set_rect(fill)
	assert_eq(p.builds, builds + 1, "back on the grid")

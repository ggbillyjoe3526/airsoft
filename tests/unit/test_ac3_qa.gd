extends GutTest
## QA for AC3 (gauge patterns): stripes stay inside any convex shape (fuzzed), the HUD follows the striped team when the
## player is on Beta, in Skirmish and after the sides swap, the switch is idempotent, and the magazine's threshold.

const EPS := 0.01


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
				if edge.is_zero_approx():
					continue
				var m := Vector2(-edge.y, edge.x).normalized()
				if m.dot(centre - a) < 0.0:
					m = -m
				if m.dot(corner - a) < -EPS:
					return false
	return true


func _corners(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func test_fuzzed_rects_keep_every_stripe_inside_including_negative_and_thin_ones() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for n in 400:
		var r := Rect2(rng.randf_range(-300.0, 300.0), rng.randf_range(-300.0, 300.0), rng.randf_range(0.0, 120.0),
				rng.randf_range(0.0, 60.0))
		for centred: bool in [false, true]:
			var p := GaugePattern.new()
			p.set_rect(r, centred)
			assert_true(_inside(p, _corners(r)), "rect %s centred %s" % [r, centred])
			assert_eq(p.lines.size() % 2, 0)


func test_fuzzed_convex_polygons_either_winding_keep_stripes_inside() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for n in 200:
		var pts := PackedVector2Array()
		var count := rng.randi_range(3, 7)
		var centre := Vector2(rng.randf_range(-80.0, 80.0), rng.randf_range(-80.0, 80.0))
		var radius := rng.randf_range(2.0, 50.0)
		for i in count:
			pts.append(centre + Vector2.from_angle(TAU * i / count) * radius * Vector2(1.0, rng.randf_range(0.3, 1.0)))
		if n % 2 == 1:
			pts.reverse()
		var p := GaugePattern.new()
		p.set_shape(pts)
		assert_true(_inside(p, pts), "polygon %d" % n)


func test_the_real_pips_in_every_score_slot_keep_their_stripes_inside() -> void:
	for wins: int in [1, 3, 5, 9]:
		var s := HudScore.new()
		add_child_autofree(s)
		s.setup(TeamConfig.new(), wins)
		for i in wins:
			assert_true(_inside(s._pip_stripes[i], s._shapes[wins + i]), "pip %d of %d" % [i, wins])


func test_a_degenerate_flat_rect_has_no_stripes_and_no_error() -> void:
	var p := GaugePattern.new()
	p.set_rect(Rect2(5.0, 5.0, 40.0, 0.0))
	assert_eq(p.lines.size(), 0)
	p.set_rect(Rect2(5.0, 5.0, 0.0, 40.0))
	assert_eq(p.lines.size(), 0)


func _session(mode: String, team: int) -> PlaySession:
	var session := PlaySession.new()
	session.mode = mode
	session.player_team = team
	session.bots_active = false
	session.settings = Settings.new(PlayTuning.new())
	# these tests are about the patterns, which start off since UB2 (owner, 2026-11-17)
	session.settings.gauge_patterns = true
	add_child_autofree(session)
	return session


func test_player_on_beta_attack_defend_follows_the_attackers_across_a_side_swap() -> void:
	var session := _session(MatchOptions.MODE_ATTACK_DEFEND, 1)
	await wait_physics_frames(2)
	var hud := session.hud()
	var rs := session.state.round_state
	rs.flag.progress = 0.5
	for attackers: int in [1, 0, 1, 0]:
		rs.attackers = attackers
		hud.update(session.state, 1.0, 0.0)
		assert_eq(hud.flag_gauge().striped(), attackers == 1, "attackers %d (player on Beta)" % attackers)
	assert_true(hud.score().striped(1))
	assert_false(hud.score().striped(0), "Alpha never striped even for a Beta player")
	get_tree().paused = false


func test_elimination_hides_the_gauge_and_still_stripes_beta_s_score_bar() -> void:
	var session := _session(MatchOptions.MODE_ELIMINATION, 1)
	await wait_physics_frames(2)
	var hud := session.hud()
	hud.update(session.state, 1.0, 0.0)
	assert_false(hud.flag_gauge().visible)
	assert_true(hud.score().striped(1))
	assert_false(hud.score().striped(0))
	get_tree().paused = false


func test_switching_twice_the_same_way_changes_nothing_and_back_on_restores() -> void:
	var session := _session(MatchOptions.MODE_ATTACK_DEFEND, 0)
	await wait_physics_frames(2)
	var hud := session.hud()
	var outline := hud.score()._score_labels[1].get_theme_constant("outline_size")
	assert_eq(outline, HudStyle.NUMBER_EDGE)
	for _i in 3:
		session.settings.changed.emit()
	assert_eq(hud.score()._score_labels[1].get_theme_constant("outline_size"), HudStyle.NUMBER_EDGE)
	session.settings.gauge_patterns = false
	session.settings.changed.emit()
	session.settings.changed.emit()
	assert_eq(hud.score()._score_labels[1].get_theme_constant("outline_size"), 0)
	assert_false(hud._replica.gauges().striped())
	session.settings.gauge_patterns = true
	session.settings.changed.emit()
	assert_true(hud.score().striped(1))
	assert_eq(hud.score()._score_labels[1].get_theme_constant("outline_size"), HudStyle.NUMBER_EDGE)
	get_tree().paused = false


func test_the_flag_gauge_keeps_its_stripes_in_step_with_a_resize() -> void:
	var g := HudFlagGauge.new()
	g.setup(12, 600.0)
	add_child_autofree(g)
	g.size = Vector2(600.0, HudStyle.GAUGE_HEIGHT)
	g.set_patterned(true)
	g.set_flag(1.0, Color.ORANGE, true)
	await wait_process_frames(2)
	g.size = Vector2(900.0, HudStyle.GAUGE_HEIGHT * 1.5)
	await wait_process_frames(2)
	for i in 12:
		assert_true(_inside(g.notch_stripes(i), _corners(g.notch_rect(i))), "notch %d after a resize" % i)
		assert_gt(g.notch_stripes(i).lines.size(), 0)


func test_the_empty_gauge_draws_no_stripes_before_any_notch_fills() -> void:
	var g := HudFlagGauge.new()
	g.setup(12, 600.0)
	add_child_autofree(g)
	g.size = Vector2(600.0, HudStyle.GAUGE_HEIGHT)
	g.set_patterned(true)
	g.set_flag(0.0, Color.ORANGE, true)
	await wait_process_frames(2)
	assert_eq(g.notch_stripes(0).builds, 0, "no notch filled, none striped")


func test_the_low_magazine_threshold_is_inclusive_and_empty_and_full_are_never_striped() -> void:
	assert_true(MagGauges.is_low(0.25, true, 0.25))
	assert_false(MagGauges.is_low(0.2501, true, 0.25))
	assert_false(MagGauges.is_low(0.1, false, 0.25), "the counter off never warns")


func test_the_settings_sample_s_low_magazine_shows_a_stripe() -> void:
	var s := Settings.new(PlayTuning.new())
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = "user://test-ac3-qa/settings.save"
	DirAccess.make_dir_recursive_absolute("user://test-ac3-qa")
	add_child_autofree(screen)
	screen.open()
	var mag: Object = screen._access_page.sample_parts()[4]
	assert_gt(mag._stripes[0].lines.size(), 0, "at least one stripe on the sample's low magazine")
	screen.close()
	get_tree().paused = false

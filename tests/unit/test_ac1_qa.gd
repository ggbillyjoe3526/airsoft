extends GutTest
## QA for AC1: the accessibility saves under old, hostile and stepped values, the table under damaged rows, and the
## colour sets against the colours the game has always drawn.

const HEX_SLACK := 1.0 / 255.0 + 1e-6


func _through_json(s: Settings) -> Settings:
	var back := Settings.new(PlayTuning.new())
	var parsed: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	back.from_dict(parsed as Dictionary)
	return back


func _loaded(data: Dictionary) -> Settings:
	var s := Settings.new(PlayTuning.new())
	s.from_dict(data)
	return s


func test_loading_a_file_without_the_keys_resets_a_used_object_to_the_defaults() -> void:
	var s := Settings.new(PlayTuning.new())
	s.team_colours = TeamColours.Set.HIGH_CONTRAST
	s.reduced_motion = Settings.ReducedMotion.ON
	s.sound_cues = true
	s.gauge_patterns = true
	s.hud.hud_size = 1.4
	s.from_dict({"fov": 90.0})
	assert_eq(s.team_colours, TeamColours.Set.STANDARD)
	assert_eq(s.reduced_motion, Settings.ReducedMotion.SYSTEM)
	assert_false(s.sound_cues)
	assert_false(s.gauge_patterns, "off by default")
	assert_eq(s.hud.hud_size, 1.0)


func test_out_of_range_and_wrong_typed_values_each_fall_back() -> void:
	var bad: Array[Dictionary] = [
		{"team_colours": 2}, {"team_colours": -1}, {"team_colours": 1.5}, {"team_colours": "1"},
		{"team_colours": true}, {"team_colours": null}, {"team_colours": [1]},
		{"sound_cue_size": 0.59}, {"sound_cue_size": 2.01}, {"sound_cue_size": "1.5"}, {"sound_cue_size": -3},
		{"sound_cue_size": INF}, {"sound_cue_size": NAN},
		{"sound_cue_colour": 6}, {"sound_cue_colour": -1}, {"sound_cue_colour": "2"},
	]
	for d in bad:
		var s := _loaded(d)
		assert_eq(s.team_colours, TeamColours.Set.STANDARD, str(d))
		assert_eq(s.sound_cue_size, 1.0, str(d))
		assert_eq(s.sound_cue_colour, AccessibilityConfig.CUE_COLOUR_DEFAULT, str(d))
	for h: Variant in [0.79, 1.51, 0.0, -1, 99, "1.2", true, null, INF, NAN, [1.0]]:
		var p := HudPrefs.new()
		p.from_dict({"hud_size": h})
		assert_eq(p.hud_size, 1.0, str(h))


func test_reduced_motion_survives_json_in_all_three_states_and_only_a_bool_counts() -> void:
	for state: Settings.ReducedMotion in [Settings.ReducedMotion.SYSTEM, Settings.ReducedMotion.OFF,
			Settings.ReducedMotion.ON]:
		var s := Settings.new(PlayTuning.new())
		s.reduced_motion = state
		assert_eq(_through_json(s).reduced_motion, state, str(state))
		assert_eq(s.to_dict().has("reduced_motion"), state != Settings.ReducedMotion.SYSTEM)
	for v: Variant in [1, 0, 1.0, "true", "off", null, [true], {}]:
		assert_eq(_loaded({"reduced_motion": v}).reduced_motion, Settings.ReducedMotion.SYSTEM, str(v))


func test_every_slider_step_is_stable_through_save_and_load_and_inside_the_range() -> void:
	var r := AccessibilityConfig.HUD_SIZE_RANGE
	for i in 15:
		var v := snappedf(r.x + i * AccessibilityConfig.HUD_SIZE_STEP, 0.0001)
		var s := Settings.new(PlayTuning.new())
		s.hud.hud_size = v
		var back := _through_json(s).hud.hud_size
		assert_almost_eq(back, v, 1e-9, "hud %s" % v)
		assert_between(back, r.x - HudPrefs.RANGE_SLACK, r.y, "hud %s stays inside the slider's range" % v)
		# Loading what was loaded changes nothing: no drift over repeated saves.
		var again := _loaded({"hud": {"hud_size": back}}).hud.hud_size
		assert_eq(again, back, "hud %s second load" % v)
	var c := AccessibilityConfig.CUE_SIZE_RANGE
	for i in 15:
		var v := snappedf(c.x + i * AccessibilityConfig.CUE_SIZE_STEP, 0.0001)
		var back := _through_json(_loaded({"sound_cue_size": v})).sound_cue_size
		assert_almost_eq(back, v, 1e-9, "cue %s" % v)
		assert_between(back, c.x - HudPrefs.RANGE_SLACK, c.y, "cue %s stays inside the range" % v)


func test_the_range_ends_load_as_the_ends() -> void:
	var p := HudPrefs.new()
	p.from_dict({"hud_size": 0.8})
	assert_almost_eq(p.hud_size, 0.8, 1e-9, "the end saved, not the default (Vector2's 0.8 is single precision)")
	p.from_dict({"hud_size": 1.5})
	assert_eq(p.hud_size, AccessibilityConfig.HUD_SIZE_RANGE.y)
	assert_almost_eq(_loaded({"sound_cue_size": 0.6}).sound_cue_size, 0.6, 1e-9)
	assert_eq(_loaded({"sound_cue_size": 2.0}).sound_cue_size, AccessibilityConfig.CUE_SIZE_RANGE.y)


func test_a_hud_dict_that_isnt_a_dictionary_leaves_the_size_default() -> void:
	assert_eq(_loaded({"hud": "big"}).hud.hud_size, 1.0)
	assert_eq(_loaded({"hud": [1.2]}).hud.hud_size, 1.0)


func test_the_reset_save_path_returns_the_accessibility_fields_to_defaults() -> void:
	var s := Settings.new(PlayTuning.new())
	s.team_colours = TeamColours.Set.HIGH_CONTRAST
	s.reduced_motion = Settings.ReducedMotion.OFF
	s.from_dict({})
	assert_eq(s.team_colours, TeamColours.Set.STANDARD)
	assert_eq(s.reduced_motion, Settings.ReducedMotion.SYSTEM)


func test_reduces_motion_treats_odd_system_answers_as_no() -> void:
	var s := Settings.new(PlayTuning.new())
	for answer: int in [-1, 0, 2, 7, -5]:
		assert_false(s.reduces_motion(answer), str(answer))
	assert_true(s.reduces_motion(1))


func test_standard_matches_the_game_tuning_teams_not_only_the_built_in_team_config() -> void:
	var tuned := PlayTuning.load_default().teams
	var out := TeamColours.resolve(TeamColours.Set.STANDARD, false, null, tuned)
	for part: TeamConfig in [out.figures, out.hud]:
		for i in 2:
			var a := part.colours[i]
			var b := tuned.colours[i]
			assert_true(absf(a.r - b.r) <= HEX_SLACK and absf(a.g - b.g) <= HEX_SLACK and absf(a.b - b.b) <= HEX_SLACK,
					"team %d: %s against %s" % [i, a.to_html(false), b.to_html(false)])
	assert_eq(out.figures.glow, 0.0)


func test_resolve_keeps_the_base_names_and_never_shares_the_base_arrays() -> void:
	var base := TeamConfig.new()
	base.names = PackedStringArray(["X", "Y"])
	var out := TeamColours.resolve(TeamColours.Set.HIGH_CONTRAST, true, null, base)
	assert_eq(out.figures.names, base.names)
	out.figures.names[0] = "changed"
	assert_eq(base.names[0], "X")
	assert_eq(out.figures.glow, 0.0, "night: no glow")
	assert_eq(out.hud.glow, 0.0)


func test_damaged_rows_never_throw_and_keep_the_built_in_values() -> void:
	var colours := "## Team colours\n\n| Set | Part | Alpha | Beta | Paint glow (day) |\n|---|---|---|---|---|\n"
	var cases: Array[String] = [
		colours + "| standard | figures | #3b87f5 | #fa8c29 | 0 |\n",
		colours + "| Standard | Figures | #3b87f5 | #fa8c29 | 0 |\n",
		colours + "| Standard | figures | #3b87f5ff | #fa8c29 | 0 |\n",
		colours + "| Standard | figures | 3b87f5 | #fa8c29 | 0 |\n",
		colours + "| High contrast | figures | #8ccfff | #b8460c | |\n",
		colours + "| High contrast | figures | #8ccfff | #b8460c | 1.5 |\n",
		colours + "| High contrast | figures | #8ccfff | #b8460c | -0.1 |\n",
		colours + "| High contrast | figures | #8ccfff | #b8460c | 1e400 |\n",
		colours + "| High contrast | figures | #8ccfff |\n",
		colours + "| High contrast |\n",
		colours + "|||||\n",
		"## Team colours\n\n| Set | Part |\n|---|---|\n| Standard | figures |\n",
	]
	var builtin := AccessibilityTable.BUILT_IN_COLOURS
	for text in cases:
		var t := AccessibilityTable.parse(text)
		assert_gt(t.problems.size(), 0, "reported: " + text)
		for i in builtin.size():
			assert_eq(t.colours[i].to_html(false), builtin[i].to_html(false), "colour %d kept: %s" % [i, text])
		assert_eq(t.glow, AccessibilityTable.BUILT_IN_GLOW, "glow kept: " + text)


func test_a_share_outside_zero_to_one_or_not_a_number_is_refused() -> void:
	var head := "## Reduced motion\n\n| ID | Motion | Share |\n|---|---|---|\n"
	for cell: String in ["-0.1", "1.01", "101%", "-5%", "abc", "", "1e400", "0,5", "nan", "inf", "--1"]:
		var t := AccessibilityTable.parse(head + "| kick | x | %s |\n" % cell)
		assert_eq(t.share(&"kick"), 0.5, "'%s' keeps the built-in" % cell)
		assert_true(t.problems.any(func(p: String) -> bool: return p.contains("Share")), "'%s' reported" % cell)
	for cell: String in ["0", "1", "100%", "0%", " 50 % "]:
		var t := AccessibilityTable.parse(head + "| kick | x | %s |\n" % cell)
		assert_between(t.share(&"kick"), 0.0, 1.0, cell)


func test_an_exception_row_with_a_case_or_spacing_slip_is_kept_loudly_not_silently_matched() -> void:
	var head := "## Prop colour exceptions\n\n| Prop | Colour | Reason |\n|---|---|---|\n"
	var t := AccessibilityTable.parse(head + "| Crate | #bd9666 | because |\n| rack | #8f6e4a | |\n| gen | #8f6e4a |\n")
	assert_true(t.exceptions.has("Crate"), "kept as typed, so the colour check can't match it to 'crate' and fails")
	assert_false(t.exceptions.has("crate"))
	assert_false(t.exceptions.has("rack"), "no reason: skipped")
	assert_false(t.exceptions.has("gen"))
	var about_exceptions := t.problems.filter(func(p: String) -> bool: return p.contains("exception"))
	assert_eq(about_exceptions.size(), 2)


func test_a_number_just_past_a_range_end_is_refused_and_one_inside_the_slack_clamped() -> void:
	var p := HudPrefs.new()
	p.from_dict({"hud_size": 0.79})
	assert_eq(p.hud_size, 1.0, "past the end: the default")
	p.from_dict({"opacity": 0.2})
	assert_almost_eq(p.opacity, 0.2, 1e-6, "the crosshair's lowest opacity loads too")
	assert_eq(_loaded({"sound_cue_size": 2.01}).sound_cue_size, AccessibilityConfig.CUE_SIZE_DEFAULT)

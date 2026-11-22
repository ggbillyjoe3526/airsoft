extends GutTest
## The team colour sets in play and in the menus (AC2): the session resolves the saved set once at Play, the figures,
## their sign outline and the flag take its figures part (High contrast's paint glowing by day), every HUD part its HUD
## part, and the menus follow the saved set at once. Standard draws as the game always has.

## Today's colours are TeamConfig's floats; Standard's table holds them as 8-bit hex, so they agree to half a step.
const SAME := 0.5 / 255.0
const HC_FIGURES: Array[Color] = [Color("8ccfff"), Color("b8460c")]
const HC_HUD: Array[Color] = [Color("8ccfff"), Color("e0601a")]

var session: PlaySession = null


func after_each() -> void:
	get_tree().paused = false


func _session(colour_set: TeamColours.Set) -> PlaySession:
	var s := Settings.new(PlayTuning.new())
	s.team_colours = colour_set
	session = PlaySession.new()
	session.settings = s
	session.mode = MatchOptions.MODE_ATTACK_DEFEND
	session.bots_active = false
	add_child_autofree(session)
	await wait_physics_frames(2)
	return session


## The figure's team paint: the first Team* surface's shared material that doesn't glow as modelled (the robot's
## TeamGlow keeps its own glow, FI1).
static func _paint(f: FigureView) -> BaseMaterial3D:
	for mi in f.body().meshes:
		for i in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(i) as BaseMaterial3D
			if m != null and not m.resource_name.to_lower().contains("glow"):
				return m
	return null


func _assert_colour(got: Color, want: Color, what: String) -> void:
	for i in 3:
		assert_almost_eq(got[i], want[i], SAME, "%s, channel %d" % [what, i])


## The figures, their signs, the flag and the HUD all in `figures` and `hud`, the figures glowing `glow`.
func _assert_drawn(figures: Array[Color], hud: Array[Color], glow: float) -> void:
	assert_false(session._figures.is_empty())
	for f in session._figures:
		var team := session.state.character(f.character_id).team
		var paint := _paint(f)
		_assert_colour(paint.albedo_color, figures[team], "figure %d" % f.character_id)
		# The HIT! sign is red whatever the team or the colours (owner, 2026-11-22).
		_assert_colour(f._sign.modulate, FigureView.SIGN_COLOUR, "sign %d" % f.character_id)
		_assert_colour(f._sign.outline_modulate, FigureView.SIGN_COLOUR.darkened(FigureView.SIGN_OUTLINE_DARKEN),
				"sign %d's edge" % f.character_id)
		assert_eq(paint.emission_enabled, glow > 0.0, "glows only with a glow")
		if glow > 0.0:
			assert_almost_eq(paint.emission_energy_multiplier, glow, 0.001)
			_assert_colour(paint.emission, figures[team], "the glow is the paint's own colour")
	var flag := session.flag_view()
	assert_not_null(flag)
	for side in 2:
		_assert_colour(flag._teams.colours[side], figures[side], "flag %d" % side)
	var attackers := session.state.round_state.attackers
	flag.refresh(session.state.round_state.flag, attackers)
	_assert_colour(flag._cloth_mat.get_shader_parameter(&"team_colour") as Color, figures[attackers], "the cloth")
	var teams := session.hud()._teams
	for side in 2:
		_assert_colour(teams.colours[side], hud[side], "HUD %d" % side)
	assert_same(session.hud().score()._teams, teams, "the score bar")
	assert_same(session.hud()._feed._teams, teams, "the hit feed")
	assert_same(session.hud().minimap()._teams, teams, "the minimap")
	assert_eq(teams.names, PlayTuning.new().teams.names, "the names stay the teams'")


func test_standard_draws_as_the_game_always_has() -> void:
	await _session(TeamColours.Set.STANDARD)
	var today := PlayTuning.new().teams.colours
	var colours: Array[Color] = [today[0], today[1]]
	_assert_drawn(colours, colours, 0.0)
	for side in 2:
		assert_eq(session.hud().score()._score_labels[side].get_theme_color("font_color"), GameTheme.TEXT,
				"white numbers on Standard's blocks, as today")


func test_high_contrast_reaches_every_consumer_and_glows_by_day() -> void:
	await _session(TeamColours.Set.HIGH_CONTRAST)
	_assert_drawn(HC_FIGURES, HC_HUD, 0.3)
	assert_eq(session.hud().score()._score_labels[0].get_theme_color("font_color"), GameTheme.BG,
			"a dark number on the light blue block")
	assert_eq(session.hud().score()._score_labels[1].get_theme_color("font_color"), GameTheme.TEXT)


func test_a_change_mid_match_shows_from_the_next_match() -> void:
	await _session(TeamColours.Set.STANDARD)
	var drawn := session.team_colours()
	session.settings.team_colours = TeamColours.Set.HIGH_CONTRAST
	session.settings.mark_changed()
	await wait_physics_frames(2)
	assert_same(session.team_colours(), drawn, "resolved once, at Play")
	var today := PlayTuning.new().teams.colours
	var colours: Array[Color] = [today[0], today[1]]
	_assert_drawn(colours, colours, 0.0)


func test_the_glow_is_0_on_a_night_preset() -> void:
	var s := Settings.new(PlayTuning.new())
	s.team_colours = TeamColours.Set.HIGH_CONTRAST
	var lighting := LightingConfig.new()
	assert_false(lighting.night, "every field is lit by day until step 26")
	var base := PlayTuning.new().teams
	assert_almost_eq(PlaySession.team_colours_for(s, lighting, base).figures.glow, 0.3, 0.001)
	lighting.night = true
	var night := PlaySession.team_colours_for(s, lighting, base)
	assert_eq(night.figures.glow, 0.0)
	_assert_colour(night.figures.colours[0], HC_FIGURES[0], "the same paint at night")
	var source := StandardMaterial3D.new()
	source.resource_name = "Team"
	var models := FigureModels.new(FigureConfig.new())
	assert_false((models.team_material(FigureMix.HUMAN, source, 0, HC_FIGURES[0], night.figures.glow)
			as BaseMaterial3D).emission_enabled)


func test_ink_is_dark_only_on_a_light_team_colour() -> void:
	var today := PlayTuning.new().teams.colours
	for c: Color in [today[0], today[1], HC_HUD[1]]:
		assert_eq(HudStyle.ink_on(c), GameTheme.TEXT, str(c))
	assert_eq(HudStyle.ink_on(HC_HUD[0]), GameTheme.BG)


# --- the menus ---

func test_the_match_page_s_team_picks_follow_the_saved_set_at_once() -> void:
	var s := Settings.new(PlayTuning.new())
	s.team_colours = TeamColours.Set.HIGH_CONTRAST
	var page := MatchPage.new(MatchPicks.new(), s)
	add_child_autofree(page)
	for side in 2:
		_assert_colour(page.team_card(side).accent, HC_HUD[side], "team card %d" % side)
		assert_eq(page.team_card(side).bar.a, 0.0, "no colour bar down the team card's edge (owner, 2026-11-17)")
	s.team_colours = TeamColours.Set.STANDARD
	s.mark_changed()
	var today := PlayTuning.new().teams.colours
	for side in 2:
		_assert_colour(page.team_card(side).accent, today[side], "team card %d, Standard" % side)
		_assert_colour(page.team_card(side).picked_fill, GameTheme.CARD.lerp(today[side], MatchPage.TEAM_TINT),
				"its tint")
	await wait_process_frames(1) # the rules' chips the change rebuilt go


## The prewarm's specks for `colour_set`: [solid, see-through] by material, and the session's figures.
func _warmed(colour_set: TeamColours.Set) -> Array:
	var s := Settings.new(PlayTuning.new())
	s.team_colours = colour_set
	var fresh := PlaySession.new()
	fresh.settings = s
	fresh.bots_active = false
	add_child_autofree(fresh)
	var warm := fresh.find_child("ShaderPrewarm", true, false) as ShaderPrewarm
	var solid: Dictionary[Material, bool] = {}
	var faded: Dictionary[Material, bool] = {}
	for speck in warm.find_children("*", "MeshInstance3D", true, false):
		var mi := speck as MeshInstance3D
		if mi.material_override != null:
			(faded if mi.transparency > 0.0 else solid)[mi.material_override] = true
	return [solid, faded, fresh._figures]


func test_the_prewarm_draws_every_figure_material_solid_and_fading() -> void:
	for colour_set: TeamColours.Set in [TeamColours.Set.HIGH_CONTRAST, TeamColours.Set.STANDARD]:
		var got := _warmed(colour_set)
		var solid: Dictionary[Material, bool] = got[0]
		var faded: Dictionary[Material, bool] = got[1]
		var figures: Array[FigureView] = got[2]
		assert_false(figures.is_empty())
		var glowing := 0
		for f in figures:
			for mi in f.body().meshes:
				for i in mi.mesh.get_surface_count():
					var m := mi.get_active_material(i)
					if m == null:
						continue
					assert_true(solid.has(m), "set %d: %s warmed solid" % [colour_set, m.resource_name])
					assert_true(faded.has(m), "set %d: %s warmed fading" % [colour_set, m.resource_name])
					var paint := m as BaseMaterial3D
					if paint != null and paint.emission_enabled and is_equal_approx(paint.emission_energy_multiplier, 0.3):
						glowing += 1
		if colour_set == TeamColours.Set.HIGH_CONTRAST:
			assert_gt(glowing, 0, "the team paint glowing by day (0.3) is among them")

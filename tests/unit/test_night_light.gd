extends GutTest
## Night light and the Day / Night switch (WL3): the night preset (the browser game's LIGHTING_PRESETS.night as first
## guesses) and a map's overrides; MapData's `night`, `lighting` and `lights`; the preset a match plays (its own, the
## Match page's Day / Night, Dev › Time of day) and the one night flag every night system reads; light pools; and the
## night swatches: earth, wood, skin and both team colour sets on figures keep a minimum brightness and contrast
## against the night ground, and the teams stay apart for every vision at night.
##
## The swatches are worked out, not rendered (the cloud has no GPU for Forward+): a colour lit by the fill alone (a
## side the moon doesn't reach, the worst light) or by the moon too (a side facing it, the ground at the moon's
## height), times the exposure, through Godot 4.7's AgX (its shader's matrices and curve, white 16.29, contrast 1.25)
## and its sRGB, then CIE Lab. Checked once against the Compatibility renderer: AGX_GREY.

const ColourVision := preload("res://tests/unit/test_colour_vision.gd")

## AgX's inset and outset matrices (Godot 4.7.2's tonemap shader), row by row as GLSL's mat3 columns.
const INSET: Array[float] = [0.544814746488245, 0.140416948464053, 0.0888104196149096, 0.373787398372697,
		0.754137554567394, 0.178871756420858, 0.0813978551390581, 0.105445496968552, 0.732317823964232]
const OUTSET: Array[float] = [1.96488741169489, -0.299313364904742, -0.164352742528393, -0.855988495690215,
		1.32639796461980, -0.238183969428088, -0.108898916004672, -0.0270845997150571, 1.40253671195648]
const AGX_WHITE := 16.29
const AGX_CONTRAST := 1.25
## Linear 0.18 grey drawn unshaded under AgX at exposure 1 reads 118 (of 255) on the Compatibility renderer (WL3's
## calibration render); the model must agree.
const AGX_GREY := 118
## The moon's light on a side facing it, and on flat ground (sin of its 18° height).
const FACING := 0.95
const FLAT := 0.31
## Skin tones standing in for the figures' heads (their skin is in a texture): a light and a mid tone (the browser
## game's night swatch measured a mid one).
const SKIN: Dictionary[String, Color] = {"light skin": Color("e0b896"), "mid skin": Color("b07a56")}
## The floor: the least a swatch's lightness (L*) may be in the fill alone, the least ΔE a figure's colours (skin, team
## paint) keep from every night ground, and the least wood (cover) keeps from the open ground it stands on (grass and
## leaves), in either light. Measured with the night preset (WL3's record); set under it, never raised to pass.
const MIN_LIGHTNESS := 8.0
const MIN_FIGURE_CONTRAST := 10.0
const MIN_WOOD_CONTRAST := 5.0
## At night every ΔE shrinks with the light: the teams stay this far apart for every vision in the fill alone (four
## times the ~10 where colours are mistaken), and High contrast's figures this far apart in lightness (the HUD's bar),
## and more than LIGHTNESS_TIMES Standard's least gap.
const MIN_NIGHT_DELTA_E := 40.0
const MIN_NIGHT_HC_GAP := 15.0

var play: PlayTuning = PlayTuning.load_default()
var woodland: MapData = null
var depot: MapData = null
## The test field offering both Day and Night (TowerBlock), with its own night overrides.
var tower: MapData = null


func before_all() -> void:
	woodland = MapData.load_map("woodland", play.map_style, 5)
	depot = MapData.load_map("depot", play.map_style, 3)
	tower = TowerBlock.load_map(play.map_style, 4)


# --- The night preset ---

func test_the_night_preset_is_the_browsers_first_guesses() -> void:
	var n := play.night_lighting
	var d := play.lighting
	assert_eq([n.id, n.night, d.id, d.night], [LightingConfig.NIGHT, true, LightingConfig.DAY, false])
	assert_almost_eq(n.sun_elevation, 18.0, 0.01, "a low moon, 18° up")
	assert_gt(n.sun_colour.b, n.sun_colour.r, "a cool moon")
	assert_true(n.fog and n.fog_from == 20.0, "haze from 20 m")
	assert_false(d.fog, "no haze by day")
	assert_gt(n.stars, 0, "stars")
	assert_gt(n.moon_size, 0.0, "the moon's disc")
	assert_lt(n.sky_top.get_luminance(), 0.1, "a dark sky")
	assert_lt(n.ambient_energy, d.ambient_energy, "a dim fill")
	assert_lt(n.sun_energy, d.sun_energy, "a dim moon")
	assert_eq(n.sky_contribution, 0.0, "the fill is its own colour alone (the swatch model's)")


func test_woodland_takes_its_overrides_and_turns_the_moon_toward_its_moon_spot() -> void:
	var n := play.night_lighting
	var w := LightingConfig.for_map(play.lighting, n, woodland, LightingConfig.NIGHT)
	assert_ne(w, n, "a copy")
	assert_almost_eq(w.sun_energy, n.sun_energy * 1.35, 1e-4, "its brighter moon (key 1.35)")
	assert_almost_eq(w.ambient_energy, n.ambient_energy * 1.4, 1e-4, "its brighter fill (hemi 1.4)")
	assert_almost_eq(w.exposure, n.exposure * 1.55 / 1.3, 1e-4, "its exposure (1.55 of the browser's 1.3)")
	assert_eq(n.sun_energy, PlayTuning.load_default().night_lighting.sun_energy, "the preset itself unchanged")
	var travel := Basis.from_euler(Vector3(deg_to_rad(-w.sun_elevation), deg_to_rad(w.sun_heading), 0.0)) * Vector3.FORWARD
	var toward_moon := Vector2(-travel.x, -travel.z).normalized()
	var spot := (woodland.moon_over - woodland.middle()).normalized()
	assert_almost_eq(toward_moon.dot(spot), 1.0, 1e-4, "the moon hangs over its spot, seen from the middle")
	assert_eq(LightingConfig.for_map(play.lighting, n, depot, LightingConfig.NIGHT), n, "Depot: the preset as it is")
	var day := LightingConfig.for_map(play.lighting, n, woodland, LightingConfig.DAY)
	assert_eq(day, play.lighting, "by day Woodland's sun keeps its heading: only the moon turns")
	var tower_night := LightingConfig.for_map(play.lighting, n, tower, LightingConfig.NIGHT)
	assert_eq(tower_night.stars, 180, "a map's fewer stars")
	assert_eq(tower_night.sky_horizon, Color.hex(0x3329_5aff), "and its horizon")


func test_every_quality_preset_draws_the_stars_moon_and_haze() -> void:
	var lighting := FieldLighting.build(play.night_lighting)
	add_child_autofree(lighting)
	var sky := lighting.environment.sky.sky_material as ShaderMaterial
	assert_not_null(sky, "the night's own sky")
	assert_gt(float(sky.get_shader_parameter(&"star_share")), 0.0)
	assert_gt(float(sky.get_shader_parameter(&"moon_size")), 0.0)
	for preset: StringName in [&"low", &"medium", &"high", &"ultra"]:
		GraphicsApply.apply_field(GraphicsTable.shared().preset(preset), lighting, null, null)
		assert_eq(lighting.environment.sky.sky_material, sky, "%s keeps the night sky" % preset)
		assert_true(lighting.environment.fog_enabled, "%s keeps the haze" % preset)
	assert_almost_eq(lighting.environment.fog_depth_begin, 20.0, 1e-4)
	var day := FieldLighting.build(play.lighting)
	add_child_autofree(day)
	assert_true(day.environment.sky.sky_material is ProceduralSkyMaterial, "the day's sky as before")
	assert_false(day.environment.fog_enabled)


# --- MapData and the preset played ---

func test_mapdata_reads_night_lighting_and_lights() -> void:
	var both: Array[StringName] = [LightingConfig.DAY, LightingConfig.NIGHT]
	assert_eq([woodland.night, woodland.lighting_presets], [false, both], "Woodland: day first, then night (WR1)")
	assert_true(woodland.has_moon_over)
	assert_eq(woodland.lights.size(), 11)
	var kinds: Array[StringName] = []
	for l in woodland.lights:
		kinds.append(l.kind)
	assert_eq(kinds.count(&"fire"), 3, "the camps' fires and the Truck bend's drum")
	assert_eq(kinds.count(&"lantern"), 8, "the huts', the Clearing's, the Fort's, the Sawmill's and the bridge's")
	assert_eq(tower.lighting_presets, [LightingConfig.NIGHT, LightingConfig.DAY] as Array[StringName])
	assert_true(tower.offers_choice())
	assert_true(woodland.offers_choice(), "Woodland offers both")
	assert_false(depot.offers_choice(), "Depot by day alone")
	var day_only: Array[StringName] = [LightingConfig.DAY]
	assert_eq([depot.night, depot.lighting_presets, depot.lights.size()], [false, day_only, 0])
	assert_eq(MapData.presets_in("woodland"), woodland.lighting_presets, "read without building the map")
	assert_eq(MapData.presets_in("neonHeights"), [&"day"] as Array[StringName], "a map taken out: day, no error")
	var bad := MapData.parse(JSON.stringify({"blocks": [], "lighting": {"presets": ["dusk"]}, "lights": [
			{"position": {"x": 0, "y": 1, "z": 0}, "radius": 0, "colour": 1}, {"radius": 2, "colour": 1},
			{"position": {"x": 0, "y": 1, "z": 0}, "radius": 2, "colour": 255, "kind": "torch"}]}), play.map_style, 1)
	assert_eq(bad.lighting_presets, [LightingConfig.DAY] as Array[StringName], "an unknown preset: day")
	assert_eq(bad.lights.size(), 0, "no radius, no position, an unknown kind: each left out")
	assert_eq(bad.warnings.size(), 5, "each with a warning: %s" % [bad.warnings])


func test_the_preset_played_is_the_maps_the_picks_or_devs() -> void:
	assert_eq(woodland.preset_played(&""), LightingConfig.DAY, "Woodland: its first, day")
	assert_eq(woodland.preset_played(LightingConfig.NIGHT), LightingConfig.NIGHT, "or the Match page's Night")
	assert_eq(woodland.preset_played(LightingConfig.NIGHT, LightingConfig.DAY), LightingConfig.DAY, "Dev wins")
	assert_eq(depot.preset_played(&""), LightingConfig.DAY)
	assert_eq(depot.preset_played(LightingConfig.NIGHT), LightingConfig.DAY, "Depot by night is Dev only")
	assert_eq(depot.preset_played(&"", LightingConfig.NIGHT), LightingConfig.NIGHT)
	assert_eq(tower.preset_played(&""), LightingConfig.NIGHT, "a map offering both: its first")
	assert_eq(tower.preset_played(LightingConfig.DAY), LightingConfig.DAY, "or the Match page's Day")
	assert_eq(tower.preset_played(LightingConfig.DAY, LightingConfig.NIGHT), LightingConfig.NIGHT, "Dev wins")


func test_one_night_flag_drives_every_night_system() -> void:
	var teams := play.teams
	for c: Array in [[woodland, LightingConfig.NIGHT, &""], [woodland, &"", &""], [depot, &"", &""],
			[depot, &"", LightingConfig.NIGHT], [tower, LightingConfig.DAY, &""], [tower, &"", &""]]:
		var m: MapData = c[0]
		var light := PlaySession.lighting_for(m, play, c[1], c[2])
		var night := light.night
		var what := "%s %s/%s" % [m.id, c[1], c[2]]
		assert_eq(night, m.preset_played(c[1], c[2]) == LightingConfig.NIGHT, what)
		var pools := LightPools.build(m, light)
		assert_eq(pools != null, night and not m.lights.is_empty(), "%s: light pools" % what)
		if pools != null:
			pools.free()
		var hc := TeamColours.resolve(TeamColours.Set.HIGH_CONTRAST, light.night, null, teams)
		assert_eq(hc.figures.glow == 0.0, night, "%s: High contrast's paint glows by day only" % what)
		var amb := play.sound.ambiences.set_for(m.ambience, light.night)
		assert_eq(amb, play.sound.ambiences.night[m.ambience] if night else play.sound.ambiences.day[m.ambience],
				"%s: the ambience's %s set" % [what, "night" if night else "day"])
		var sky := SkylineView.build(m, play.skyline, light, 1.6)
		if sky != null:
			var masts := sky.kept.any(func(p: SkylinePiece) -> bool: return p.kind == &"mast")
			assert_eq(sky.mesh().get_surface_count() == 2, night and masts, "%s: the masts' lamps lit" % what)
			sky.free()


func test_a_match_on_depot_by_dev_night_lights_everything_by_its_one_flag() -> void:
	var s := Settings.new()
	s.dev.time_of_day = LightingConfig.NIGHT
	var session := PlaySession.new()
	session.map_id = "depot"
	session.settings = s
	session.bots_active = false
	add_child_autofree(session)
	assert_true(session.lighting().night, "Dev › Time of day: Depot by night")
	assert_true(session._audio.night, "the ambience's night set")
	assert_eq(session._colours.figures.glow, 0.0, "no paint glow")
	assert_null(session.light_pools(), "Depot has no lights to pool")
	assert_null(session._skyline, "the hall has no skyline to light: its roof hides the sky (DR1)")
	assert_true(session.state.off_record or s.dev.cheats().watching, "a forced preset keeps it out of the records")
	# the night sky can't be a prewarm speck (a sky shader draws no mesh); it is the background of the frames the specks
	# are drawn on, behind the loading screen, so it compiles with them
	assert_eq(session.find_children("*", "ShaderPrewarm", true, false).size(), 1, "the prewarm is hung")
	assert_true(session._eyes.camera.current, "under the eye camera")
	var env := session.get_viewport().find_world_3d().environment
	var sky := env.sky.sky_material as ShaderMaterial if env != null else null
	assert_true(sky != null and sky.shader.code == FieldLighting.NIGHT_SKY, "which draws the night sky behind it")


# --- Light pools ---

func test_each_pool_lights_the_ground_within_its_radius() -> void:
	var night := LightingConfig.for_map(play.lighting, play.night_lighting, woodland, LightingConfig.NIGHT)
	var pools := LightPools.build(woodland, night)
	add_child_autofree(pools)
	var arrays := pools.pools_mesh().surface_get_arrays(0)
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var per := 1 + night.pool_rings * night.pool_segments
	assert_eq(pos.size(), woodland.lights.size() * per, "a disc a light")
	for i in pos.size():
		var l := woodland.lights[int(uv[i].x)]
		var flat := Vector2(pos[i].x - l.position.x, pos[i].z - l.position.z).length()
		assert_lte(flat, l.radius + 1e-3, "inside its radius")
		var ground := LightPools.ground_under(woodland, pos[i].x, pos[i].z, l.position.y)
		assert_almost_eq(pos[i].y, ground + night.pool_lift, 1e-3, "on the ground under it")
		if i % per == per - 1:
			assert_almost_eq(flat, l.radius, 1e-3, "out to its radius")
	assert_eq(pools.find_children("*", "Light3D", true, false).size(), 0, "no real light until the graphics say")


func test_the_real_lights_are_the_presets_count_on_the_nearest_pools() -> void:
	var night := play.night_lighting
	var counts: Array[int] = []
	for preset: StringName in [&"low", &"medium", &"high", &"ultra"]:
		counts.append(night.real_lights_for(GraphicsTable.shared().preset(preset).mesh_detail))
	assert_eq(counts, [0, 2, 4, 4] as Array[int], "Low 0, Medium 2, High 4")
	var old := OldWoodland.load_map(play.map_style, 5) # the first wood: the west camp's fire by this eye
	var pools := LightPools.build(old, night)
	add_child_autofree(pools)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	pools.set_real_count(2)
	var eye := Vector3(-50.0, 2.0, -10.0)
	for i in 30:
		pools.update(eye, 0.05)
	var served := pools.served()
	var fire := _nearest(old, eye)
	assert_true(served.has(fire), "the west camp's fire has a real light")
	assert_eq(pools.drawn_share(fire), 0.0, "its drawn disc faded out under it")
	assert_eq(pools.real_lights()[served.find(fire)].light_color, night.fire_colour)
	assert_false(pools.real_lights()[0].shadow_enabled, "no shadow")
	# a step toward another pool not clearly nearer keeps the lights where they are
	var before := served.duplicate()
	pools.update(eye + Vector3(0.5, 0.0, 0.0), 0.05)
	assert_eq(pools.served(), before, "hysteresis: no hopping")
	pools.set_real_count(4)
	pools.set_real_count(0)
	pools.set_real_count(2)
	await get_tree().process_frame
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes + 2, "two lights, none left over")
	for k in old.lights.size():
		if not pools.served().has(k):
			assert_eq(pools.drawn_share(k), 1.0, "pool %d drawn" % k)


func test_fires_and_lanterns_are_yellow_white_off_every_team_hue() -> void:
	var night := play.night_lighting
	assert_eq(night.fire_colour, Color8(255, 228, 160))
	assert_eq(night.lantern_colour, Color8(255, 232, 180))
	assert_eq(night.pool_colour(&"fire", Color.RED), night.fire_colour, "whatever the map says")
	assert_eq(night.pool_colour(&"", Color.MAGENTA), Color.MAGENTA, "a lamp of no kind keeps its own")
	var teams := AccessibilityTable.read_file().colours
	for c: Color in [night.fire_colour, night.lantern_colour]:
		assert_gte(FieldChecks.hue_gap(c, teams), FieldStandard.HUE_MARGIN_DEG, "#%s" % c.to_html(false))


func test_fires_flicker_and_hold_still_under_reduced_motion() -> void:
	var pools := LightPools.build(woodland, play.night_lighting)
	add_child_autofree(pools)
	var fire := 0
	var lantern := 2
	assert_eq(woodland.lights[fire].kind, &"fire")
	assert_eq(woodland.lights[lantern].kind, &"lantern")
	var seen := PackedFloat32Array()
	for t in 10:
		seen.append(pools.flicker_at(fire, t * 0.07))
		assert_eq(pools.flicker_at(lantern, t * 0.07), 1.0, "a lantern holds steady")
	assert_gt(Array(seen).max() - Array(seen).min(), 0.05, "a fire flickers")
	pools.set_motion(MotionScale.of(true))
	for t in 10:
		assert_eq(pools.flicker_at(fire, t * 0.07), 1.0, "Reduced motion: still")
	pools.set_motion(MotionScale.of(false))
	assert_ne(pools.flicker_at(fire, 0.3), 1.0)


# --- Night swatches (acceptance 5) ---

func test_the_agx_model_matches_the_calibration_render() -> void:
	var grey := _shown(Color(0.18, 0.18, 0.18), 1.0)
	assert_eq(roundi(grey.r * 255.0), AGX_GREY)


func test_earth_wood_skin_and_team_paint_stay_readable_against_the_night_ground() -> void:
	var lines := PackedStringArray()
	for preset: LightingConfig in _night_presets():
		var grounds := _grounds()
		for lit: String in ["fill", "moon"]:
			var ground_light := 0.0 if lit == "fill" else FLAT
			var side_light := 0.0 if lit == "fill" else FACING
			var shown_grounds: Dictionary[String, Color] = {}
			for g: String in grounds:
				shown_grounds[g] = _lit(grounds[g], preset, ground_light)
			var swatches := _swatches()
			for what: String in swatches:
				var c := _lit(swatches[what], preset, side_light)
				var lightness := ColourVision._lab(c, "normal").x
				if lit == "fill":
					assert_gte(lightness, MIN_LIGHTNESS, "%s, %s in the fill alone: L* %.1f" % [what, _name(preset), lightness])
				var against: Array[String] = []
				if what.begins_with("wood"):
					against = ["grass", "leaves"]
				elif what != "earth":
					against.assign(grounds.keys())
				var least := INF
				for g in against:
					least = minf(least, ColourVision._delta_e(c, shown_grounds[g], "normal"))
				var floor_de := MIN_WOOD_CONTRAST if what.begins_with("wood") else MIN_FIGURE_CONTRAST
				if not against.is_empty():
					assert_gte(least, floor_de, "%s, %s by %s: ΔE %.1f from the ground" % [what, _name(preset), lit, least])
				lines.append("%s %s %s: L* %.1f, least ΔE %s" % [_name(preset), lit, what, lightness,
						"-" if against.is_empty() else "%.1f" % least])
	gut.p("\n".join(lines))


func test_the_teams_stay_apart_for_every_vision_at_night() -> void:
	var table := AccessibilityTable.read_file()
	for preset: LightingConfig in _night_presets():
		var least_standard := INF
		var least_hc := INF
		for s: int in TeamColours.Set.values():
			var pair := PackedColorArray()
			for c in table.pair(s, TeamColours.Part.FIGURES):
				pair.append(_lit(c, preset, 0.0))
			for vision: String in ColourVision.VISIONS:
				var de := ColourVision._delta_e(pair[0], pair[1], vision)
				assert_gte(de, MIN_NIGHT_DELTA_E, "set %d, %s, %s: ΔE %.1f" % [s, vision, _name(preset), de])
			var gap := ColourVision._least_gap(pair)
			if s == TeamColours.Set.HIGH_CONTRAST:
				least_hc = gap
			else:
				least_standard = gap
		assert_gte(least_hc, MIN_NIGHT_HC_GAP, "High contrast apart in lightness at night (%s)" % _name(preset))
		assert_gt(least_hc, least_standard * ColourVision.LIGHTNESS_TIMES, "and more than Standard (%s)" % _name(preset))


# --- Dev › Time of day ---

func test_dev_time_of_day_is_saved_and_counts_as_watching() -> void:
	var d := DevSettings.new()
	assert_eq(d.time_of_day, &"", "the map's own by default")
	assert_false(d.cheats().watching)
	d.time_of_day = LightingConfig.NIGHT
	assert_true(d.cheats().watching, "a forced preset keeps the match out of the records")
	var back := DevSettings.new()
	back.from_dict(d.to_dict())
	assert_eq(back.time_of_day, LightingConfig.NIGHT, "saved and read back")
	back.from_dict({"time_of_day": "dusk"})
	assert_eq(back.time_of_day, &"", "an unknown preset: the map's own")
	back.from_dict({"time_of_day": 3})
	assert_eq(back.time_of_day, &"")


func test_the_match_page_offers_day_or_night_only_where_a_map_offers_both() -> void:
	var picks := MatchPicks.new()
	var box := MatchRulesBox.new(picks, Settings.new(), SimTuning.load_default())
	add_child_autofree(box)
	picks.map_id = "depot"
	box.show_tuning(SimTuning.load_default())
	assert_false(box.time_of_day_visible(), "Depot offers no choice")
	picks.map_id = "woodland"
	box.show_tuning(SimTuning.load_default())
	assert_true(box.time_of_day_visible(), "Woodland offers Day or Night (WR1)")
	# The test field's presets, as the box would read them.
	box._presets["tower"] = tower.lighting_presets
	picks.map_id = "tower"
	box.show_tuning(SimTuning.load_default())
	assert_true(box.time_of_day_visible(), "a map offering both")
	assert_eq(box.time_of_day_choice().selected(), LightingConfig.PRESETS.find(LightingConfig.NIGHT), "its first lit")
	box.time_of_day_choice().button(LightingConfig.PRESETS.find(LightingConfig.DAY)).pressed.emit()
	assert_eq(picks.lighting, LightingConfig.DAY, "the pick goes into the MatchPicks")
	assert_eq(box.time_of_day_blurb(), tr("RULE_TIME_BLURB_DAY"))
	box.set_unused(true)
	assert_false(box.time_of_day_visible(), "Practice: no rules, no row")


# --- Helpers ---

func _night_presets() -> Array[LightingConfig]:
	return [play.night_lighting, LightingConfig.for_map(play.lighting, play.night_lighting, woodland,
			LightingConfig.NIGHT)]


## The base night (Depot by Dev) or Woodland's, by name.
func _name(preset: LightingConfig) -> String:
	return "night" if preset == play.night_lighting else "Woodland's night"


## The night ground: Woodland's grass, leaf litter and earth, and Depot's floor.
func _grounds() -> Dictionary[String, Color]:
	var style := play.map_style
	return {"grass": style.terrain_colours[RayHit.Surface.GRASS], "leaves": style.terrain_colours[RayHit.Surface.LEAVES],
			"earth": style.terrain_colours[RayHit.Surface.EARTH], "floor": style.colours[&"floor"]}


## Earth, wood (logs, fences and boards), skin, and both sets' figure paint.
func _swatches() -> Dictionary[String, Color]:
	var style := play.map_style
	var out: Dictionary[String, Color] = {"earth": style.terrain_colours[RayHit.Surface.EARTH],
			"wood log": style.colours[&"log"], "wood fence": style.colours[&"fence"],
			"wood boards": style.terrain_colours[RayHit.Surface.WOOD]}
	out.merge(SKIN)
	var table := AccessibilityTable.read_file()
	for s: int in TeamColours.Set.values():
		var pair := table.pair(s, TeamColours.Part.FIGURES)
		for t in pair.size():
			out["set %d team %d" % [s, t]] = pair[t]
	return out


## `c` (sRGB) as `cfg` shows it: lit by its fill and `moon` of the moon's light (0 to 1), through its exposure.
static func _lit(c: Color, cfg: LightingConfig, moon: float) -> Color:
	var fill := cfg.ambient_colour.srgb_to_linear() * cfg.ambient_energy
	var key := cfg.sun_colour.srgb_to_linear() * cfg.sun_energy * moon
	var lin := c.srgb_to_linear()
	var x := cfg.exposure
	return _shown(Color(lin.r * (fill.r + key.r) * x, lin.g * (fill.g + key.g) * x, lin.b * (fill.b + key.b) * x), 1.0)


## A linear colour through AgX and Godot's sRGB, as drawn (sRGB, clamped).
static func _shown(lin: Color, exposure: float) -> Color:
	var v := Vector3(lin.r, lin.g, lin.b) * exposure
	v = _mat(INSET, v)
	v = Vector3(_curve(v.x), _curve(v.y), _curve(v.z)).min(Vector3.ONE)
	v = _mat(OUTSET, v)
	return Color(_srgb(v.x), _srgb(v.y), _srgb(v.z))


## GLSL's mat3 * v, the matrix given column by column.
static func _mat(m: Array[float], v: Vector3) -> Vector3:
	return Vector3(m[0] * v.x + m[3] * v.y + m[6] * v.z, m[1] * v.x + m[4] * v.y + m[7] * v.z,
			m[2] * v.x + m[5] * v.y + m[8] * v.z)


## The allenwp curve AgX uses, with its toe and shoulder fitted to meet at 0.18 and reach 1 at AGX_WHITE.
static func _curve(x: float) -> float:
	x = maxf(x, 0.0)
	var c := AGX_CONTRAST
	var toe := pow(0.18, c) * (0.82 / 0.18)
	var slope := 0.82 * c
	var s := AGX_WHITE - 0.18
	var w := slope * s * s / 0.82
	if x < 0.18:
		var t := pow(x, c)
		return t / (t + toe)
	var d := x - 0.18
	return slope * d * (1.0 + d / w) / (1.0 + slope * d / 0.82) + 0.18


static func _srgb(x: float) -> float:
	return clampf(1.055 * pow(maxf(x, 0.0), 1.0 / 2.4) - 0.055, 0.0, 1.0)


static func _nearest(m: MapData, eye: Vector3) -> int:
	var best := 0
	for i in m.lights.size():
		if eye.distance_to(m.lights[i].position) < eye.distance_to(m.lights[best].position):
			best = i
	return best

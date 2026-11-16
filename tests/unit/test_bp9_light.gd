extends GutTest
## BP9, light. Two of the owner's reports, both worked out headless as the engine works its light out, never pixels.
##
## "Lighting can get intensely bright in the depot map ... in some areas": on High and Ultra Depot's roof lamps are
## real lights and light the hall alone; on Low and Medium an overhead light stands in for them. Both must light the
## open floor about alike, or the hall is one brightness on one preset and another on the next: with the lamps at
## their first strength they put twice to nearly four times the stand-in's light on the floor, most where the lamps
## hang closest, and the open hall drew washed out. Worked out as the engine works a spot's light out (its distance
## falloff, its range's window, its cone's curve and the angle it falls at), with nothing in the way.
##
## "The game seems to cast harsh/sharp shadows": the sun's shadows on Medium and High had an edge a few of the shadow
## map's pixels wide, so the shade under Woodland's crowns lay in hard-edged patches. The engine widens a shadow's edge
## by the light's blur times its filter's radius and spreads the filter's samples over it; too few samples over a wide
## edge speckle, as nothing smooths the picture (Edge smoothing is Off on every preset).

## The floor's grid (m) the lamps' light is worked out on, and how far (m) inside the hall's walls it stays.
const GRID := 2.0
const INSET := 1.0
## The lamps' light on the open floor against the overhead stand-in's: the middle of the floor's, and the most.
const MIDDLE_LEAST := 0.7
const MIDDLE_MOST := 1.1
const MOST := 1.6
## The lamps' strength as first tuned (UG1), which the open hall drew washed out at with the ambient filling its
## shade (High), and which Ultra keeps (the owner's, 2026-11-16).
const LAMPS_FIRST := 6.0

## The engine's shadow filters (RenderingServer.ShadowQuality, in order): the samples each spreads over a shadow's
## edge and the radius it spreads them over, in the shadow map's pixels for each unit of the light's blur
## (RendererSceneRenderRD's directional_soft_shadow_filter_set_quality).
const FILTER_SAMPLES: Array[int] = [0, 1, 4, 8, 16, 32]
const FILTER_RADIUS: Array[float] = [1.0, 1.5, 2.0, 2.0, 3.0, 4.0]
## The sun's shadow edge on High as it was: 4 samples over a blur of 1.5 (3 px), which read hard-edged.
const EDGE_BEFORE := 3.0
## The sun's blur as it was by day, which Softest (Ultra) keeps, and the night's, which never moved.
const BLUR_BEFORE := 1.5
const NIGHT_BLUR := 2.0
## An edge's samples for each pixel of its radius, squared, below which it speckled in the pictures (8 over 6 px did,
## and 4 over 6 px badly; 16 over 6 px drew smooth, and 4 over 4 px, Medium's, sits on the limit: softer than its old
## hard edge, with a fine grain along it).
const SAMPLES_A_PIXEL := 0.25
## The outdoor fields, whose sun casts the shadows.
const OPEN_FIELDS: Array[String] = ["woodland", "range"]

var play: PlayTuning = PlayTuning.load_default()
var table: GraphicsTable = GraphicsTable.shared()
var depot: MapData = null


func before_all() -> void:
	depot = MapData.load_map("depot", play.map_style, SimTuning.new().rounds.team_size)


## The light `spots` put on a level floor at `at` with nothing in the way, as the engine's shader works a spot's out.
func _lamp_light(spots: Array[SpotLight3D], at: Vector3) -> float:
	var sum := 0.0
	for spot in spots:
		var to := at - spot.position
		var d := to.length()
		var cos_cone := cos(deg_to_rad(spot.spot_angle))
		var cos_angle := -to.y / maxf(d, 0.0001)
		if d >= spot.spot_range or cos_angle <= cos_cone:
			continue
		var window := pow(maxf(1.0 - pow(d / spot.spot_range, 4.0), 0.0), 2.0)
		var rim := maxf(0.0001, (1.0 - cos_angle) / (1.0 - cos_cone))
		var cone := 1.0 - pow(rim, 1.0 / spot.spot_angle_attenuation)
		sum += spot.light_energy * window * pow(d, -spot.spot_attenuation) * cone * cos_angle
	return sum


## The lamps' light on Depot's floor against the overhead stand-in's, over the hall's grid, sorted.
func _floor_shares(spots: Array[SpotLight3D]) -> Array[float]:
	var day := LightingConfig.for_map(play.lighting, play.night_lighting, depot, &"day")
	var overhead := day.sun_energy * sin(deg_to_rad(day.sun_elevation))
	var hall := Rect2()
	for i in spots.size():
		var p := Vector2(spots[i].position.x, spots[i].position.z)
		hall = Rect2(p, Vector2.ZERO) if i == 0 else hall.expand(p)
	hall = hall.grow(-INSET)
	var shares: Array[float] = []
	var x := hall.position.x
	while x <= hall.end.x:
		var z := hall.position.y
		while z <= hall.end.y:
			shares.append(_lamp_light(spots, Vector3(x, 0.0, z)) / overhead)
			z += GRID
		x += GRID
	shares.sort()
	return shares


func test_depots_lamps_light_its_open_floor_about_as_the_overhead_stand_in_does() -> void:
	var roof := RoofView.build(depot, play.roof)
	add_child_autofree(roof)
	var shares := _floor_shares(roof.lamp_lights().lights())
	assert_gt(shares.size(), 1000, "the whole hall's floor")
	var middle := shares[shares.size() / 2]
	assert_between(middle, MIDDLE_LEAST, MIDDLE_MOST, "the middle of the floor's light, against the stand-in's")
	assert_lt(shares[-1], MOST, "where the lamps hang closest: no patch far brighter than on Low and Medium")


func test_the_lamps_first_strength_put_twice_the_stand_ins_light_on_the_floor() -> void:
	var cfg := play.roof.duplicate() as RoofConfig
	cfg.lamp_light_energy = LAMPS_FIRST
	var roof := RoofView.build(depot, cfg)
	add_child_autofree(roof)
	var shares := _floor_shares(roof.lamp_lights().lights())
	assert_gt(shares[shares.size() / 2], 2.0, "the middle of the floor at the strength the hall drew washed out at")
	assert_gt(shares[-1], 3.5, "and its brightest patch")


func test_depots_lamps_keep_their_first_strength_under_the_bounce_light() -> void:
	# Under the scene's bounce light (Ultra) no ambient fills the hall's shade, and the owner kept Ultra's hall as it
	# was (2026-11-16: turned down to match High, it "looks better before"). With the ambient filling (High) the lamps
	# stay turned down. The presets say which: High's lamps under its screen bounce, Ultra's under the scene's.
	var cfg := play.roof
	assert_almost_eq(cfg.lamp_bounce_energy, LAMPS_FIRST, 0.0001, "Ultra's lamps as first tuned")
	var roof := RoofView.build(depot, cfg)
	add_child_autofree(roof)
	var lamps := roof.lamp_lights()
	var working := lamps.light_of(Array(depot.roof_lamp_states).find(MapData.LAMP_WORKING))
	var rs := GraphicsApply.Server.new()
	GraphicsApply.apply_field(table.preset(&"high"), null, null, rs, null, null, null, lamps)
	assert_true(lamps.visible, "High lights the lamps")
	assert_almost_eq(working.light_energy, cfg.lamp_light_energy, 0.0001, "High: turned down, the ambient fills")
	GraphicsApply.apply_field(table.preset(&"ultra"), null, null, rs, null, null, null, lamps)
	assert_almost_eq(working.light_energy, cfg.lamp_bounce_energy, 0.0001, "Ultra: the lamps light the hall alone")
	for l in lamps.lights():
		assert_almost_eq(l.light_indirect_energy, 1.0, 0.0001, "%s: the engine's own share in the bounce" % l.name)
	GraphicsApply.apply_field(table.preset(&"high"), null, null, rs, null, null, null, lamps)
	assert_almost_eq(working.light_energy, cfg.lamp_light_energy, 0.0001, "and back")


func test_a_worn_lamp_keeps_its_share_and_its_flicker_through_a_change_of_strength() -> void:
	var cfg := play.roof
	var roof := RoofView.build(depot, cfg)
	add_child_autofree(roof)
	roof.set_process(false)
	var lamps := roof.lamp_lights()
	var states := Array(depot.roof_lamp_states)
	var dim := lamps.light_of(states.find(MapData.LAMP_DIM))
	var flicker_lamp := states.find(MapData.LAMP_FLICKER)
	var flicker := lamps.light_of(flicker_lamp)
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false, false)
	lamps.set_flicker(flicker_lamp, cfg.lamp_flicker_low)
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false, true)
	assert_almost_eq(dim.light_energy, cfg.lamp_bounce_energy * cfg.lamp_dim_share, 0.0001, "a dim lamp's share")
	assert_almost_eq(flicker.light_energy, cfg.lamp_bounce_energy * cfg.lamp_flicker_low, 0.0001, "a stutter's step")
	lamps.set_flicker(flicker_lamp, 1.0)
	assert_almost_eq(flicker.light_energy, cfg.lamp_bounce_energy, 0.0001, "and its next step, at the new strength")
	lamps.set_mode(GraphicsQuality.LampLights.NEAR, true, false)
	assert_almost_eq(dim.light_energy, cfg.lamp_light_energy * cfg.lamp_dim_share, 0.0001, "and back")


func test_a_plain_roofs_lamps_shine_the_same_under_the_bounce_light() -> void:
	var cfg := play.roof
	var subway := MapData.load_map("subway", play.map_style, SimTuning.new().rounds.team_size)
	var roof := RoofView.build(subway, cfg)
	add_child_autofree(roof)
	var lamps := roof.lamp_lights()
	assert_gt(lamps.light_count(), 10, "Subway's strip lamps")
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false, false)
	var before: Array[float] = []
	for l in lamps.lights():
		before.append(l.light_energy)
	lamps.set_mode(GraphicsQuality.LampLights.FAR, false, true)
	for i in lamps.light_count():
		assert_almost_eq(lamps.lights()[i].light_energy, before[i], 0.0001, "a station's lamps: one strength")


## A viewport of its own for a preset's knobs, so the root's stay as they are.
func _port() -> SubViewport:
	var port := SubViewport.new()
	add_child_autofree(port)
	return port


## The sun's shadow filter on `preset` for `map` by `time` as a match sets it: x the edge's radius (the shadow map's
## pixels: the sun's blur times the filter's radius), y the samples spread over it.
func _sun_edge(preset: StringName, map: String, time: StringName) -> Vector2:
	var field := MapData.load_map(map, play.map_style, SimTuning.new().rounds.team_size)
	var lighting := FieldLighting.build(LightingConfig.for_map(play.lighting, play.night_lighting, field, time),
			play.look)
	add_child_autofree(lighting)
	var rs := GraphicsApply.Server.new()
	var values := table.preset(preset)
	GraphicsApply.apply(values, _port(), rs)
	GraphicsApply.apply_field(values, lighting, null, rs)
	if not lighting.sun.shadow_enabled:
		return Vector2.ZERO
	return Vector2(lighting.sun.shadow_blur * FILTER_RADIUS[rs.soft_shadows], FILTER_SAMPLES[rs.soft_shadows])


func test_the_suns_shadows_on_high_have_an_edge_twice_as_wide_as_before() -> void:
	for map in OPEN_FIELDS:
		for time: StringName in [LightingConfig.DAY, LightingConfig.NIGHT]:
			var edge := _sun_edge(&"high", map, time)
			assert_gte(edge.x, EDGE_BEFORE * 2.0, "%s by %s: the edge's radius (px)" % [map, time])


func test_medium_softens_its_shadows_edge_where_it_took_one_sample() -> void:
	for map in OPEN_FIELDS:
		var edge := _sun_edge(&"medium", map, LightingConfig.DAY)
		assert_gte(edge.y, 4.0, "%s: one sample is a hard edge" % map)
		assert_gte(edge.x, EDGE_BEFORE, "%s: the edge's radius (px)" % map)


func test_no_presets_sun_shadow_spreads_too_few_samples_over_its_edge() -> void:
	for preset: StringName in [&"medium", &"high"]:
		for map in OPEN_FIELDS:
			for time: StringName in [LightingConfig.DAY, LightingConfig.NIGHT]:
				var edge := _sun_edge(preset, map, time)
				assert_gte(edge.y, edge.x * edge.x * SAMPLES_A_PIXEL,
						"%s on %s by %s: %d samples over %.1f px speckle" % [map, preset, time, int(edge.y), edge.x])


func test_low_draws_no_sun_shadow_and_ultra_keeps_its_suns_size() -> void:
	assert_eq(_sun_edge(&"low", "woodland", LightingConfig.DAY), Vector2.ZERO, "Low: no sun shadows")
	var field := MapData.load_map("woodland", play.map_style, SimTuning.new().rounds.team_size)
	var lighting := FieldLighting.build(LightingConfig.for_map(play.lighting, play.night_lighting, field,
			LightingConfig.DAY), play.look)
	add_child_autofree(lighting)
	var rs := GraphicsApply.Server.new()
	GraphicsApply.apply(table.preset(&"ultra"), _port(), rs)
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, rs)
	assert_almost_eq(lighting.sun.light_angular_distance, play.look.sun_size, 0.0001, "Softest: the sun's size")
	assert_eq(rs.soft_shadows, RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "and its 16 samples")


func test_ultras_sun_keeps_the_blur_it_was_tuned_on() -> void:
	# Hardening at contact (Softest) the blur scales the sun's own size, so the wider blur the fixed filters took
	# would have drawn Ultra's edges a third wider. Ultra's sun is as it was: 1.5 by day, and the night's 2, which
	# this change never moved. A change of preset takes the blur with it, there and back.
	var field := MapData.load_map("woodland", play.map_style, SimTuning.new().rounds.team_size)
	for c: Array in [[LightingConfig.DAY, BLUR_BEFORE], [LightingConfig.NIGHT, NIGHT_BLUR]]:
		var cfg := LightingConfig.for_map(play.lighting, play.night_lighting, field, c[0])
		var lighting := FieldLighting.build(cfg, play.look)
		add_child_autofree(lighting)
		var rs := GraphicsApply.Server.new()
		for preset: StringName in [&"ultra", &"high", &"ultra", &"medium"]:
			GraphicsApply.apply(table.preset(preset), _port(), rs)
			GraphicsApply.apply_field(table.preset(preset), lighting, null, rs)
			var want: float = c[1] if preset == &"ultra" else cfg.shadow_blur
			assert_almost_eq(lighting.sun.shadow_blur, want, 0.0001, "%s by %s" % [preset, c[0]])
		assert_almost_eq(cfg.soft_sun_blur, c[1], 0.0001, "%s: Softest's blur as it was" % c[0])


## Every field's reflection probes as a match builds them, with the blocks round them.
func _probes(map: MapData) -> Array[ReflectionProbe]:
	var probes := AreaProbes.build(map, play.look)
	add_child_autofree(probes)
	var out: Array[ReflectionProbe] = []
	for p: ReflectionProbe in probes.get_children():
		out.append(p)
	return out


func test_no_reflection_probe_captures_from_inside_a_prop() -> void:
	# Seven of Subway's 16 captured from inside the concourse's kiosk, a works hoarding, a locker or a wagon, and six of
	# Depot's 21 from inside a crate, a drum or a plywood wall: the prop's inside pictured for its hall.
	var room := play.look.probe_clearance
	assert_gte(room, 0.5, "room enough round the eye")
	for id: String in ["depot", "woodland", "subway", "range"]:
		var map := MapData.load_map(id, play.map_style, SimTuning.new().rounds.team_size)
		var solids := AreaProbes.solids_of(map)
		for p in _probes(map):
			var eye := p.position + p.origin_offset
			for s in solids:
				assert_false(s.grow(room - 0.01).has_point(eye), "%s %s: a block within %.1f m of the eye" % [id, p.name, room])
			assert_true(AABB(p.position - p.size * 0.5, p.size).has_point(eye), "%s %s: the eye inside its box" % [id, p.name])


func test_subways_probes_moved_out_of_its_props_and_the_rest_stayed_at_their_middles() -> void:
	var subway := MapData.load_map("subway", play.map_style, SimTuning.new().rounds.team_size)
	var moved := 0
	for p in _probes(subway):
		if Vector2(p.origin_offset.x, p.origin_offset.z).length() > 0.01:
			moved += 1
	assert_gte(moved, 6, "most of the eight that stood in a prop")
	var depot := MapData.load_map("depot", play.map_style, SimTuning.new().rounds.team_size)
	var still := 0
	for p in _probes(depot):
		if Vector2(p.origin_offset.x, p.origin_offset.z).length() < 0.01:
			still += 1
	assert_gt(still, 0, "a probe with a clear middle keeps it")


func test_an_interiors_probes_give_reflections_alone_and_the_open_fields_keep_their_ambient() -> void:
	# As built (the field's ambient filling the hall: Medium and High). A probe's ambient is its own picture of its
	# hall, darker than the field's in every picture taken indoors, and it fades in over LookConfig.probe_margin from
	# each face of its box: a band at chest height along every wall of Subway (a box one storey tall), and the lockers
	# in Depot's Lounge fading to black towards their tops.
	var subway := MapData.load_map("subway", play.map_style, SimTuning.new().rounds.team_size)
	var low := 0
	var probes := _probes(subway)
	for p in probes:
		if p.size.y < play.look.probe_margin * 4.0:
			low += 1
	assert_gt(low * 2, probes.size(), "most of Subway's a storey tall, their boxes mostly fade")
	for id: String in ["subway", "depot"]:
		var roofed := _probes(MapData.load_map(id, play.map_style, SimTuning.new().rounds.team_size))
		assert_gt(roofed.size(), 1, id)
		for p in roofed:
			assert_eq(p.ambient_mode, ReflectionProbe.AMBIENT_DISABLED, "%s %s: the field's ambient alone" % [id, p.name])
			assert_true(p.interior and p.box_projection, "%s %s: still a hall's reflections" % [id, p.name])
			assert_almost_eq(p.intensity, play.look.probe_intensity, 0.0001, "%s %s: as bright as they were" % [id, p.name])
	for id: String in ["woodland", "range"]:
		for p in _probes(MapData.load_map(id, play.map_style, SimTuning.new().rounds.team_size)):
			assert_false(p.interior, "%s %s: open to the sky" % [id, p.name])
			assert_eq(p.ambient_mode, ReflectionProbe.AMBIENT_ENVIRONMENT, "%s %s: its ambient as tuned" % [id, p.name])


func test_under_the_scenes_bounce_light_an_interiors_probes_keep_their_ambient() -> void:
	# Under the scene's bounce light (Ultra) no ambient fills a hall's shade, and a probe's own is light the shade would
	# not have: without it Depot's Lounge drew its lockers' tops and its top shelves black on Ultra, and the owner kept
	# Ultra as it was (2026-11-16). The presets say which, through the field's lighting; an open field's stay as tuned.
	for id: String in ["depot", "subway", "woodland"]:
		var field := MapData.load_map(id, play.map_style, SimTuning.new().rounds.team_size)
		var lighting := FieldLighting.build(LightingConfig.for_map(play.lighting, play.night_lighting, field,
				LightingConfig.DAY), play.look)
		add_child_autofree(lighting)
		lighting.add_probes(field)
		var probes: Array[ReflectionProbe] = []
		for p in lighting.find_children("*", "ReflectionProbe", true, false):
			probes.append(p as ReflectionProbe)
		assert_gt(probes.size(), 1, id)
		var rs := GraphicsApply.Server.new()
		var indoors := id != "woodland"
		for preset: StringName in [&"medium", &"high", &"ultra", &"high"]:
			GraphicsApply.apply_field(table.preset(preset), lighting, null, rs)
			var keeps := not indoors or preset == &"ultra"
			var mode := ReflectionProbe.AMBIENT_ENVIRONMENT if keeps else ReflectionProbe.AMBIENT_DISABLED
			for p in probes:
				assert_eq(p.ambient_mode, mode, "%s on %s, %s" % [id, preset, p.name])


func test_probes_built_after_the_bounce_light_is_on_keep_their_ambient() -> void:
	var lighting := FieldLighting.build(LightingConfig.for_map(play.lighting, play.night_lighting, depot,
			LightingConfig.DAY), play.look)
	add_child_autofree(lighting)
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, GraphicsApply.Server.new())
	lighting.add_probes(depot)
	var probes := lighting.find_children("*", "ReflectionProbe", true, false)
	assert_gt(probes.size(), 1)
	for p in probes:
		assert_eq((p as ReflectionProbe).ambient_mode, ReflectionProbe.AMBIENT_ENVIRONMENT, p.name)


func test_a_probe_in_a_prop_captures_from_the_nearest_clear_spot() -> void:
	var look := play.look
	var box := Rect2(-10.0, -10.0, 20.0, 20.0)
	var kiosk: Array[AABB] = [AABB(Vector3(-2.0, 0.0, -1.0), Vector3(4.0, 3.0, 2.0))]
	var eye := AreaProbes.capture_spot(box, Vector2(0.0, 8.0), look, null, 0.0, kiosk)
	assert_almost_eq(eye.y, look.probe_eye, 0.001, "eye height over the floor")
	assert_false(kiosk[0].grow(look.probe_clearance - 0.01).has_point(eye), "clear of the kiosk")
	assert_almost_eq(absf(eye.z), 1.0 + look.probe_clearance, look.probe_clearance, "just past its long side")
	assert_almost_eq(eye.x, 0.0, 0.001, "straight out from the middle")
	var walled: Array[AABB] = [AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 3.0, 40.0))]
	var held := AreaProbes.capture_spot(box, Vector2(0.0, 8.0), look, null, 0.0, walled)
	assert_almost_eq(Vector2(held.x, held.z), box.get_center(), Vector2.ONE * 0.001, "no clear spot: the middle")


func test_the_lamps_pools_and_torch_keep_the_filters_they_were_tuned_on() -> void:
	var rs := GraphicsApply.Server.new()
	var was: Array[int] = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
			RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH]
	var presets: Array[StringName] = [&"low", &"medium", &"high", &"ultra"]
	for i in presets.size():
		GraphicsApply.apply(table.preset(presets[i]), _port(), rs)
		assert_eq(rs.lamp_soft, was[i], "%s: the lamps' filter" % presets[i])

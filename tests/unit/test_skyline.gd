extends GutTest
## The skyline (DP3): MapData reads `dressing.skyline`, SkylineView builds what a player can see over the walls
## (SkylineSight) as one vertex-coloured mesh faded toward the horizon, with no collider, Depot's landmarks (the watch
## tower, the fuselage, four masts) always among it, no colour near a team's hue, the chimneys' smoke from Medium, and
## a map with no skyline drawn as before. At night (WL3) it fades to the night horizon, its hue test passes on both
## horizons, and the masts' lamps glow with no real light. Dev 3 map models: the shed, crane, mast, fuselage, silo,
## watch tower and water tower are drawn from their models inside their pieces' boxes, in budget, off every team's hue
## at every fade step; a kind whose model won't load keeps its greybox, and sight reads the greybox either way.

## A walled yard: 4 m walls round a 20 m square, a spawn each end; beyond the north wall a 3 m shed (hidden by it), a
## 20 m chimney (seen), a kind not built yet and a shed with no height (left out with a warning).
const YARD := """{"name": "Yard", "blocks": [
	{"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0}, "size": {"x": 21, "y": 0.5, "z": 21}},
	{"kind": "wall", "center": {"x": 0, "y": 2, "z": -10.25}, "size": {"x": 21, "y": 4, "z": 0.5}},
	{"kind": "wall", "center": {"x": 0, "y": 2, "z": 10.25}, "size": {"x": 21, "y": 4, "z": 0.5}},
	{"kind": "wall", "center": {"x": -10.25, "y": 2, "z": 0}, "size": {"x": 0.5, "y": 4, "z": 20}},
	{"kind": "wall", "center": {"x": 10.25, "y": 2, "z": 0}, "size": {"x": 0.5, "y": 4, "z": 20}}],
	"spawns": [[{"position": {"x": -5, "y": 0, "z": 0}}], [{"position": {"x": 5, "y": 0, "z": 0}}]],
	"deadZones": [[{"position": {"x": -8, "y": 0, "z": 8}}], [{"position": {"x": 8, "y": 0, "z": 8}}]],
	"dressing": {"skyline": [
		{"kind": "shed", "x": 0, "z": -14, "width": 6, "depth": 4, "height": 3},
		{"kind": "chimney", "x": 0, "z": -30, "width": 2, "depth": 2, "height": 20, "smoke": true},
		{"kind": "tower", "x": 0, "z": 40, "width": 9, "depth": 9, "height": 30, "base": 0},
		{"kind": "shed", "x": 0, "z": 30, "width": 6, "depth": 4}]}}"""
const LANDMARKS: Array[StringName] = [&"watchTower", &"fuselage", &"mast"]
## The skyline's triangles at most (the Dev 3 model plan's 20k), and the lamps on a mast's model.
const TRIANGLES_MOST := 20000
const MAST_MODEL_LAMPS := 4
## Each modelled kind's triangle budget (tools/blender/maps/skyline.py, docs/ASSETS.md).
const MODEL_BUDGETS: Dictionary[StringName, int] = {&"shed": 500, &"crane": 800, &"mast": 500, &"fuselage": 700,
		&"silo": 650, &"watchTower": 1000, &"waterTower": 900}

var play: PlayTuning = PlayTuning.load_default()
var body: BodyConfig = BodyConfig.new()
var depot: MapData = null
var view: SkylineView = null


func before_all() -> void:
	depot = YardMap.load_map(play.map_style, 1) # the old yard and its skyline (DR1)
	view = SkylineView.build(depot, play.skyline, play.lighting, body.stand_eye_height)


func after_all() -> void:
	if view != null:
		view.free()


func _yard(text: String = YARD) -> MapData:
	var m := MapData.parse(text, play.map_style, 1)
	assert_true(m.ok(), "the yard loads: %s" % [m.problems])
	return m


func test_depot_lists_its_landmarks_beyond_the_walls() -> void:
	assert_eq(depot.warnings, [] as Array[String])
	var counts: Dictionary[StringName, int] = {}
	for p in depot.skyline:
		counts[p.kind] = counts.get(p.kind, 0) + 1
	assert_eq([counts.get(&"watchTower", 0), counts.get(&"fuselage", 0), counts.get(&"mast", 0)], [1, 1, 4])
	for p in depot.skyline:
		if p.kind == &"watchTower":
			assert_lt(p.at.y + p.depth * 0.5, -16.5, "the watch tower stands beyond the north wall")
		elif p.kind == &"fuselage":
			assert_gt(p.at.x - p.width * 0.5, 25.5, "the fuselage lies beyond the east wall")
		elif p.kind == &"mast":
			assert_true(absf(p.at.x) > 25.5 and absf(p.at.y) > 16.5, "a mast stands outside a corner: %s" % p.at)


func test_every_landmark_is_seen_and_built() -> void:
	assert_not_null(view)
	for p in depot.skyline:
		if p.kind in LANDMARKS:
			assert_has(view.kept, p, "%s at %s is built" % [p.kind, p.at])
	assert_eq(view.kept.size() + view.left_out.size(), depot.skyline.size())
	var stands := SkylineSight.stands(depot, play.skyline.raised_from, play.skyline.floor_inset)
	var on_dock := false
	for q in stands:
		on_dock = on_dock or is_equal_approx(q.y, 1.2)
	assert_true(on_dock, "the dock's top is a stand point")


func test_a_piece_no_one_sees_over_the_walls_is_left_out() -> void:
	var m := _yard()
	assert_eq(m.skyline.size(), 2, "the tower's kind waits for its own dressing; the shed with no height is left out")
	assert_eq(m.warnings.size(), 1, "the shed with no height: %s" % [m.warnings])
	var v := SkylineView.build(m, play.skyline, play.lighting, body.stand_eye_height)
	assert_eq(v.left_out.size(), 1)
	assert_eq(v.kept.size(), 1)
	if v.kept.size() == 1 and v.left_out.size() == 1:
		assert_eq(v.left_out[0].kind, &"shed", "the low shed behind the wall")
		assert_eq(v.kept[0].kind, &"chimney")
	v.free()


func test_a_piece_seen_only_past_a_nearer_one_is_left_out() -> void:
	var low := '{"kind": "shed", "x": 0, "z": -14, "width": 6, "depth": 4, "height": 3}'
	var near := '{"kind": "shed", "x": 0, "z": -16, "width": 30, "depth": 4, "height": 10}'
	var far := '{"kind": "shed", "x": 0, "z": -30, "width": 6, "depth": 4, "height": 10}'
	var alone := _yard(YARD.replace(low, far))
	var v := SkylineView.build(alone, play.skyline, play.lighting, body.stand_eye_height)
	assert_eq(v.kept.size(), 2, "alone, the far 10 m shed shows over the wall, as the chimney does")
	v.free()
	var both := _yard(YARD.replace(low, "%s, %s" % [far, near]))
	v = SkylineView.build(both, play.skyline, play.lighting, body.stand_eye_height)
	assert_eq(v.left_out.size(), 1, "the far shed hides behind the near one")
	if v.left_out.size() == 1:
		assert_eq(v.left_out[0].at, Vector2(0, -30), "the far shed is the one left out")
	assert_eq(v.kept.size(), 2, "the near shed and the chimney, which rises over it")
	v.free()


func test_only_solid_pieces_hide_and_a_hill_s_core_stays_inside_its_mound() -> void:
	for kind: String in ["crane", "mast", "watchTower", "chimney", "fuselage", "waterTower"]:
		var p := SkylinePiece.new()
		p.kind = StringName(kind)
		p.width = 6.0
		p.depth = 6.0
		p.height = 20.0
		assert_eq(SkylineShapes.hides_of(p, play.skyline).size(), 0, "%s hides nothing" % kind)
	var hill := SkylinePiece.new()
	hill.kind = &"hill"
	hill.width = 40.0
	hill.depth = 20.0
	hill.height = 10.0
	var box := SkylineShapes.hides_of(hill, play.skyline)
	assert_eq(box.size(), 2, "one core box")
	if box.size() == 2:
		var corner := Vector2(box[1].x / 20.0, box[1].z / 10.0).length()
		var under := 10.0 * SkylineShapes.mound_at(corner / cos(PI / play.skyline.sides), play.skyline)
		assert_true(box[1].y <= under + 1e-4, "the core's top (%.2f m) stays under the mound at its corner (%.2f m)"
				% [box[1].y, under])
		assert_gt(box[1].y, 3.0, "and it hides something")


func test_one_mesh_no_collider_and_the_layout_unchanged() -> void:
	var meshes := view.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 1, "one mesh, one draw call")
	assert_eq(view.find_children("*", "CollisionObject3D", true, false).size(), 0, "no collider")
	assert_eq(view.mesh().get_surface_count(), 1)
	assert_eq((meshes[0] as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_between(view.triangle_count(), 1000, TRIANGLES_MOST, "the skyline's triangles, its models' among them")
	var text := FileAccess.get_file_as_string(YardMap.PATH)
	var bare: Dictionary = JSON.parse_string(text)
	bare.erase("dressing")
	var without := MapData.parse(JSON.stringify(bare), play.map_style, 1)
	assert_eq(without.blocks.size(), depot.blocks.size(), "the skyline adds no block")
	assert_eq(without.lanes, depot.lanes)


func test_a_far_piece_fades_toward_the_horizon() -> void:
	var cfg := play.skyline
	var horizon := play.lighting.sky_horizon
	var red := Color(0.6, 0.2, 0.2)
	var parts: Array[SkylineShapes.Part] = [SkylineShapes.box(Vector3(19, 0, -1), Vector3(21, 2, 1), red),
			SkylineShapes.box(Vector3(199, 0, -1), Vector3(201, 2, 1), red)]
	var cols: PackedColorArray = SkylineView.mesh_of(parts, cfg, horizon, Vector2.ZERO).surface_get_arrays(0)[
			Mesh.ARRAY_COLOR]
	var near := cols[0]
	var far := cols[cols.size() - 1]
	assert_almost_eq(near.r, red.r, 0.01, "within fade_from: its own colour")
	assert_lt(_gap(far, horizon), _gap(near, horizon) * (1.0 - cfg.fade_most) + 0.02, "faded most of the way")


func test_no_skyline_colour_reads_as_a_team() -> void:
	var teams := AccessibilityTable.read_file().colours
	for id: String in ["depot", "range", "woodland"]:
		var m := MapData.load_map(id, play.map_style, 1)
		var v := SkylineView.build(m, play.skyline, play.lighting, body.stand_eye_height)
		if v == null:
			continue
		var seen: Dictionary[Color, bool] = {}
		for c: Color in v.mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
			seen[c] = true
		var team_like: Array[String] = []
		for c: Color in seen:
			if FieldChecks.reads_as_team(c, teams):
				team_like.append(c.to_html(false))
		assert_eq(team_like, [] as Array[String], "%s: no skyline colour near a team's hue" % id)
		if v != view:
			v.free()


func test_it_fades_to_the_playing_horizon_and_no_fade_step_reads_as_a_team_by_day_or_night() -> void:
	var teams := AccessibilityTable.read_file().colours
	var cfg := play.skyline
	var parts: Array[SkylineShapes.Part] = []
	for p in depot.skyline:
		parts.append_array(SkylineShapes.parts_of(p, cfg, SkylineView.middle_of(depot)))
	for preset: LightingConfig in [play.lighting, play.night_lighting]:
		var far_part: Array[SkylineShapes.Part] = [SkylineShapes.box(Vector3(299, 0, -1), Vector3(301, 2, 1),
				Color(0.6, 0.6, 0.6))]
		var far: PackedColorArray = SkylineView.mesh_of(far_part, cfg, preset.sky_horizon, Vector2.ZERO).surface_get_arrays(
				0)[Mesh.ARRAY_COLOR]
		assert_lt(_gap(far[0], preset.sky_horizon), _gap(Color(0.6, 0.6, 0.6), preset.sky_horizon) * 0.5,
				"%s: a far piece fades toward its own horizon" % preset.id)
		var bad: Array[String] = []
		var horizon := preset.sky_horizon.srgb_to_linear()
		for part in parts:
			var own := part.colour.srgb_to_linear()
			for step in 8:
				var c := own.lerp(horizon, cfg.fade_most * step / 7.0).linear_to_srgb()
				if FieldChecks.reads_as_team(c, teams):
					bad.append("#%s" % part.colour.to_html(false))
					break
		assert_eq(bad, [] as Array[String], "%s: no fade step toward its horizon near a team's hue" % preset.id)
	assert_ne(play.night_lighting.sky_horizon, play.lighting.sky_horizon, "the night has its own horizon")


func test_a_treeline_is_cones_along_its_points_across_its_depth() -> void:
	var cfg := play.skyline
	var warnings: Array[String] = []
	var pieces := SkylinePiece.read({"skyline": [
		{"kind": "treeline", "height": 15, "depth": 5, "points": [{"x": 0, "z": -40}, {"x": 40, "z": -40}]},
		{"kind": "treeline", "height": 15, "depth": -1, "points": [{"x": 0, "z": -40}, {"x": 40, "z": -40}]}]},
			warnings)
	assert_eq(pieces.size(), 1, "a negative depth is left out")
	assert_eq(warnings.size(), 1, "with a warning")
	var parts := SkylineShapes.parts_of(pieces[0], cfg, Vector2.ZERO)
	var rows := roundi(5.0 / cfg.treeline_spacing)
	assert_eq(parts.size(), roundi(40.0 / cfg.treeline_spacing) * rows, "a cone every spacing, %d rows deep" % rows)
	var shake := cfg.treeline_jitter * cfg.treeline_spacing
	var off := 0
	for part in parts:
		var top := part.b[0]
		var foot := part.a[0]
		if top.y > 15.0 or top.y < 15.0 * cfg.treeline_low or absf(top.z + 40.0) > 2.5 + shake \
				or top.x < -shake or top.x > 40.0 + cfg.treeline_spacing + shake or foot.y > 0.0:
			off += 1
	assert_eq(off, 0, "every cone in the band, its foot sunk, its height within the treeline's")
	var a := SkylineShapes.parts_of(pieces[0], cfg, Vector2.ZERO)
	assert_eq(a[3].b, parts[3].b, "the same cones every time")


func test_woodland_s_treelines_and_hills_are_built_and_read_as_no_team_by_day_or_night() -> void:
	var teams := AccessibilityTable.read_file().colours
	var woodland := MapData.load_map("woodland", play.map_style, 1)
	assert_eq(woodland.warnings, [] as Array[String])
	for preset: LightingConfig in [play.lighting, play.night_lighting]:
		var v := SkylineView.build(woodland, play.skyline, preset, body.stand_eye_height)
		var kinds: Dictionary[StringName, int] = {}
		for p in v.kept:
			kinds[p.kind] = kinds.get(p.kind, 0) + 1
		assert_gt(kinds.get(&"treeline", 0), 0, "%s: treelines built" % preset.id)
		assert_gt(kinds.get(&"hill", 0), 0, "%s: hills built" % preset.id)
		var team_like: Array[String] = []
		var seen: Dictionary[Color, bool] = {}
		for c: Color in v.mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
			seen[c] = true
		for c: Color in seen:
			if FieldChecks.reads_as_team(c, teams):
				team_like.append(c.to_html(false))
		assert_eq(team_like, [] as Array[String], "%s: no colour near a team's hue" % preset.id)
		v.free()


func test_the_masts_lamps_glow_at_night_with_no_real_light() -> void:
	var night := SkylineView.build(depot, play.skyline, play.night_lighting, body.stand_eye_height)
	add_child_autofree(night)
	assert_eq(view.mesh().get_surface_count(), 1, "by day the lamps are part of the one mesh")
	assert_eq(night.mesh().get_surface_count(), 2, "at night they are a surface of their own")
	var glow := night.mesh().surface_get_material(1) as StandardMaterial3D
	assert_true(glow.emission_enabled and glow.emission == play.skyline.mast_lamp_glow, "self-lit in the lamp's glow")
	assert_true(glow.disable_fog, "through the haze")
	var lamps: PackedVector3Array = night.mesh().surface_get_arrays(1)[Mesh.ARRAY_VERTEX]
	assert_eq(lamps.size(), 4 * MAST_MODEL_LAMPS * 6, "four masts' lamps, each lamp's glass two triangles")
	assert_eq(night.triangle_count(), view.triangle_count(), "the same triangles, split in two")
	assert_eq(night.find_children("*", "Light3D", true, false).size(), 0, "no real light")
	assert_eq(night.materials().size(), 3, "both surfaces' and the smoke's, for ShaderPrewarm")
	var teams := AccessibilityTable.read_file().colours
	assert_gte(FieldChecks.hue_gap(play.skyline.mast_lamp_glow, teams), FieldStandard.HUE_MARGIN_DEG,
			"the lamps' glow is off every team's hue")


func test_smoke_from_medium_and_frozen_under_reduced_motion() -> void:
	var smoke := view.smoke()
	assert_not_null(smoke, "Depot's chimneys smoke")
	if smoke == null:
		return
	var table := GraphicsTable.shared()
	assert_false(SkylineView.smokes(table.preset(&"low")), "Low: no smoke")
	var mats := view.materials()
	assert_eq(mats.size(), 2, "the pieces' and the smoke's materials, for ShaderPrewarm")
	assert_false(mats.has(null))
	for preset: StringName in [&"medium", &"high", &"ultra"]:
		assert_true(SkylineView.smokes(table.preset(preset)), preset)
	view.set_smoke(true)
	assert_true(smoke.visible and smoke.emitting)
	view.update(Vector3(3.0, 0.0, 0.0), 1.0)
	view.set_motion(MotionScale.of(true))
	assert_eq(smoke.speed_scale, 0.0, "Reduced motion freezes it")
	view.set_motion(MotionScale.of(false))
	view.set_smoke(false)
	assert_false(smoke.visible or smoke.emitting, "hidden, it does no work")


func test_a_map_with_no_skyline_draws_as_before() -> void:
	var bare: Dictionary = JSON.parse_string(YARD)
	bare.erase("dressing")
	assert_null(SkylineView.build(_yard(JSON.stringify(bare)), play.skyline, play.lighting, body.stand_eye_height))


## How far apart two sRGB colours are in linear light (the fade's own space).
static func _gap(a: Color, b: Color) -> float:
	var la := a.srgb_to_linear()
	var lb := b.srgb_to_linear()
	return Vector3(la.r - lb.r, la.g - lb.g, la.b - lb.b).length()


func _range() -> MapData:
	var m := MapData.load_map("range", play.map_style, 1)
	assert_true(m.ok(), "the Range loads")
	return m


func test_each_modelled_kind_is_drawn_from_its_model_inside_its_piece() -> void:
	var m := _range()
	var cfg := play.skyline
	var middle := SkylineView.middle_of(m)
	var outside: Array[String] = []
	var drawn: Dictionary[StringName, bool] = {}
	for p in m.skyline:
		if not cfg.models.has(p.kind):
			assert_eq(SkylineModels.placed_of(p, cfg, middle).size(), 0, "%s keeps its greybox" % p.kind)
			continue
		var placed := SkylineModels.placed_of(p, cfg, middle)
		assert_gt(placed.size(), 0, "%s at %s stands its model" % [p.kind, p.at])
		drawn[p.kind] = true
		var top := p.height + (minf(p.width, p.depth) * cfg.roof_rise if p.kind == &"shed" else 0.0)
		var reach := Vector2(p.width, p.depth).length() * 0.5 if p.kind == &"mast" else 0.0
		var box := AABB(Vector3(p.at.x - p.width * 0.5, 0.0, p.at.y - p.depth * 0.5), Vector3(p.width, top, p.depth))
		for one in placed:
			var verts: PackedVector3Array = one.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var q := one.at * v
				var inside := box.grow(1e-3).has_point(q) if reach == 0.0 else \
						(Vector2(q.x, q.z).distance_to(p.at) <= reach + 1e-3 and q.y >= -1e-3 and q.y <= top + 1e-3)
				if not inside:
					outside.append("%s at %s: %s" % [p.kind, p.at, q])
					break
	assert_eq(outside, [] as Array[String], "every model inside its piece's box")
	assert_eq(drawn.size(), cfg.models.size(), "every modelled kind stands on the Range: %s" % [drawn.keys()])


func test_every_skyline_model_is_inside_its_budget() -> void:
	for kind: StringName in play.skyline.models:
		var mesh := play.skyline.model_of(kind)
		assert_not_null(mesh, "%s's model loads" % kind)
		var tris := (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		assert_between(tris, 1, MODEL_BUDGETS[kind], "%s: %d triangles" % [kind, tris])


func test_no_model_colour_reads_as_a_team_at_any_fade_step_by_day_or_night() -> void:
	var teams := AccessibilityTable.read_file().colours
	var cfg := play.skyline
	var m := _range()
	var bad: Array[String] = []
	for preset: LightingConfig in [play.lighting, play.night_lighting]:
		var horizon := preset.sky_horizon.srgb_to_linear()
		for p in m.skyline:
			var mesh := cfg.model_of(p.kind)
			if mesh == null:
				continue
			var body := SkylineModels.body_of(p, cfg).srgb_to_linear()
			var seen: Dictionary[Color, bool] = {}
			for c: Color in mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
				var own := Color(body.r * c.r, body.g * c.g, body.b * c.b) if c.a < SkylineModels.BODY_BELOW \
						else Color(c.r, c.g, c.b)
				if seen.has(own):
					continue
				seen[own] = true
				for step in 8:
					var faded := own.lerp(horizon, cfg.fade_most * step / 7.0).linear_to_srgb()
					if FieldChecks.reads_as_team(faded, teams):
						bad.append("%s %s: #%s" % [preset.id, p.kind, own.linear_to_srgb().to_html(false)])
						break
	assert_eq(bad, [] as Array[String], "no model colour near a team's hue at any fade step")


func test_a_kind_whose_model_won_t_load_keeps_its_greybox_and_sight_reads_the_greybox_either_way() -> void:
	var m := _range()
	var plain := play.skyline.duplicate() as SkylineConfig
	plain.models = {&"shed": "res://assets/models/skyline/missing.glb"}
	var middle := SkylineView.middle_of(m)
	for p in m.skyline:
		assert_eq(SkylineModels.placed_of(p, plain, middle).size(), 0, "%s: no model, its greybox" % p.kind)
	assert_push_warning("won't load")
	var with_models := SkylineView.build(m, play.skyline, play.lighting, body.stand_eye_height)
	var greybox := SkylineView.build(m, plain, play.lighting, body.stand_eye_height)
	add_child_autofree(with_models)
	add_child_autofree(greybox)
	assert_eq(with_models.kept, greybox.kept, "the same pieces seen")
	assert_ne(with_models.triangle_count(), greybox.triangle_count(), "drawn from the models")


extends GutTest
## Woodland's look in placeholders (WL4): MapData reads the map's `dressing` (warning on a bad entry), WoodsView draws a
## crown over every tree on every preset, the wood beyond the fence, tufts under the grass height, puddles that lie on
## the ground and draw first, the leaves, fallen wood and moss, and by night the fireflies and motes; Low draws the
## crowns alone, the Wind dust row shares out the night air and Reduced motion stills it; no colour of it reads as a
## team's, the same map builds the same dressing, and none of it collides or changes the field checks, the nav grid or
## a seeded match.

## A yard with a bad entry of each of the dressing's kinds.
const BAD := """{"name": "Yard", "blocks": [
	{"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0}, "size": {"x": 20, "y": 0.5, "z": 20}}],
	"spawns": [[{"position": {"x": -5, "y": 0, "z": 0}}], [{"position": {"x": 5, "y": 0, "z": 0}}]],
	"deadZones": [[{"position": {"x": -6, "y": 0, "z": 6}}], [{"position": {"x": 6, "y": 0, "z": 6}}]],
	"dressing": {"seed": 3, "woods": {"leaves": "lots", "fallen": 2}, "moss": {"colour": "green", "share": 0.5},
		"puddles": [{"x": 0, "z": 0, "width": -1, "depth": 2}, {"x": 2, "z": 2, "width": 1, "depth": 1, "mud": true}],
		"fireflies": {"count": -4}, "grass": {"height": "tall"}, "motes": {"tint": []}, "forest": {"trees": 1.5}}}"""
## Seconds of a seeded match played with the dressing and without (enough to leave the spawns and meet).
const MATCH_SECONDS := 30.0
const MATCH_SEED := 11

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.load_default()
var teams: Array[Color] = []
var woodland: MapData = null
var night: LightingConfig = null
var view: WoodsView = null


func before_all() -> void:
	teams = AccessibilityTable.read_file().colours
	woodland = MapData.load_map("woodland", play.map_style, 1)
	night = LightingConfig.for_map(play.lighting, play.night_lighting, woodland, LightingConfig.NIGHT)
	view = WoodsView.build(woodland, play.woods, play.skyline, night, play.map_style)
	add_child(view)


func after_all() -> void:
	if view != null:
		view.free()
		view = null


func after_each() -> void:
	if view != null:
		view.set_quality(GraphicsQuality.MeshDetail.LOW, 0.0)


func test_woodland_reads_its_dressing_with_no_warning() -> void:
	assert_eq(woodland.warnings, [] as Array[String])
	assert_eq([woodland.forest_trees, woodland.fireflies, woodland.grass_height], [1800, 220, 0.34])
	assert_gt(woodland.puddles.size(), 3, "puddles")
	assert_true(woodland.puddles.any(func(p: MapData.Puddle) -> bool: return p.mud), "mud among them")
	assert_true(woodland.has_motes and woodland.moss_share > 0.0 and woodland.leaf_drifts > 0.0
			and woodland.fallen > 0.0, "motes, moss, leaves and fallen wood")


func test_a_bad_dressing_entry_warns_and_is_left_out() -> void:
	var m := MapData.parse(BAD, play.map_style, 1)
	assert_true(m.ok(), "the yard loads: %s" % [m.problems])
	var said := "\n".join(m.warnings)
	for what: String in ["woods.leaves", "woods.fallen", "moss.colour", "puddles 0", "fireflies.count",
			"grass.height", "motes.tint", "forest.trees"]:
		assert_string_contains(said, what)
	assert_eq([m.leaf_drifts, m.fallen, m.moss_share, m.fireflies, m.grass_height, m.forest_trees, m.has_motes],
			[0.0, 0.0, 0.0, 0, 0.0, 0, false], "each left at none")
	assert_eq(m.puddles.size(), 1, "the good puddle kept")
	assert_true(m.puddles[0].mud, "as mud")


func test_more_fireflies_or_forest_trees_than_the_most_are_cut_to_it_with_a_warning() -> void:
	var text := """{"name": "Yard", "blocks": [
		{"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0}, "size": {"x": 20, "y": 0.5, "z": 20}}],
		"spawns": [[{"position": {"x": -5, "y": 0, "z": 0}}], [{"position": {"x": 5, "y": 0, "z": 0}}]],
		"deadZones": [[{"position": {"x": -6, "y": 0, "z": 6}}], [{"position": {"x": 6, "y": 0, "z": 6}}]],
		"dressing": {"fireflies": {"count": %d}, "forest": {"trees": %d}}}"""
	var style := play.map_style
	var m := MapData.parse(text % [1000000, 100000], style, 1)
	assert_eq([m.fireflies, m.forest_trees], [style.most_fireflies, style.most_forest_trees], "cut to the most")
	var said := "\n".join(m.warnings)
	assert_string_contains(said, "dressing.fireflies.count is more than the most")
	assert_string_contains(said, "dressing.forest.trees is more than the most")
	var fine := MapData.parse(text % [style.most_fireflies, style.most_forest_trees], style, 1)
	assert_eq(fine.warnings, [] as Array[String], "the most itself is fine")
	assert_gt(style.most_forest_trees, woodland.forest_trees, "Woodland's wood under the most")
	assert_gt(style.most_fireflies, woodland.fireflies, "and its fireflies")


func test_every_tree_has_one_crown_over_everyone_s_head_and_over_its_trunk() -> void:
	var trees: Array[MapData.Block] = []
	for b in woodland.blocks:
		if b.kind == WoodsShapes.TREE:
			trees.append(b)
	var placed := WoodsShapes.crowns(woodland, play.woods)
	assert_eq(placed.size(), trees.size(), "a crown a tree")
	assert_eq(view.crowns().multimesh.instance_count, trees.size(), "all drawn")
	var low := INF
	var bare := 0
	for i in placed.size():
		var x := placed.xforms[i]
		var b := trees[i]
		assert_almost_eq(Vector2(x.origin.x, x.origin.z), Vector2(b.center.x, b.center.z), Vector2.ONE * 0.001)
		low = minf(low, x.origin.y - woodland.terrain.height_at(b.center.x, b.center.z))
		if x.origin.y + x.basis.y.length() < b.center.y + b.size.y * 0.5:
			bare += 1
	assert_gt(low, tuning.body.height, "every crown starts over a standing player's head")
	assert_eq(bare, 0, "every trunk's top is inside its crown")


func test_crowns_draw_on_every_preset_and_low_draws_nothing_else() -> void:
	view.set_quality(GraphicsQuality.MeshDetail.LOW, 1.0)
	assert_true(view.crowns().visible, "the crowns on Low")
	var drawn: Array[String] = []
	for g: GeometryInstance3D in [view.forest(), view.puddles(), view.floor_pieces()] + view.tufts():
		if g.visible:
			drawn.append(String(g.name))
	assert_eq(drawn, [] as Array[String], "Low draws only the crowns and the night air")
	var forest: Array[int] = []
	var tufts: Array[int] = []
	for step: int in [GraphicsQuality.MeshDetail.MEDIUM, GraphicsQuality.MeshDetail.HIGH,
			GraphicsQuality.MeshDetail.ULTRA]:
		view.set_quality(step, 1.0)
		assert_true(view.crowns().visible and view.puddles().visible and view.floor_pieces().visible,
				"crowns, puddles and the floor on step %d" % step)
		forest.append(view.forest().multimesh.visible_instance_count)
		var n := 0
		for t in view.tufts():
			n += t.multimesh.visible_instance_count if t.visible else 0
		tufts.append(n)
	assert_gt(forest[0], 0, "Medium draws some of the forest")
	assert_true(forest[0] < forest[1] and forest[1] < forest[2], "more forest each step up: %s" % [forest])
	assert_eq(forest[2], woodland.forest_trees, "Ultra draws it all")
	assert_true(tufts[0] > 0 and tufts[0] < tufts[1] and tufts[1] < tufts[2], "more tufts each step up: %s" % [tufts])


func test_grass_tufts_stand_on_the_grass_under_its_height_and_off_the_puddles() -> void:
	var tall := 0.0
	var wet := 0
	var tiles := WoodsShapes.tufts(woodland, play.woods, play.map_style)
	assert_gt(view.tufts().size(), 1, "the tufts come in tiles")
	for t in tiles:
		var mesh_top := t.mesh.get_aabb().end.y
		for x in t.xforms:
			tall = maxf(tall, mesh_top * x.basis.y.length())
			var at := Vector2(x.origin.x, x.origin.z)
			if WoodsShapes.on_puddle(woodland, at, 0.0):
				wet += 1
			if not is_equal_approx(x.origin.y, woodland.terrain.height_at(at.x, at.y)):
				assert_true(false, "a tuft off the ground at %s" % x.origin)
				return
	assert_lt(tall, woodland.grass_height + 0.0001, "no tuft taller than the grass height (0.34 m)")
	assert_eq(wet, 0, "no tuft in a puddle")


func test_puddles_lie_just_over_the_ground_and_draw_before_every_other_see_through_thing() -> void:
	var mesh := view.puddles().mesh
	var names: Array[String] = []
	var worst := 0.0
	for s in mesh.get_surface_count():
		names.append(mesh.surface_get_name(s))
		var mat := mesh.surface_get_material(s) as ShaderMaterial
		assert_eq(mat.render_priority, Material.RENDER_PRIORITY_MIN, "drawn first of the see-through")
		assert_eq(mat.shader, LookMaterials.CLEAR_SHADER, "seen through, in the shared light")
		assert_true(mat.shader.code.contains("ALPHA = COLOR.a"), "its colour's alpha its opacity")
		assert_false(mat.shader.code.contains("depth_draw_always"), "never hiding what is drawn after it")
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			worst = maxf(worst, absf(v.y - woodland.terrain.height_at(v.x, v.z) - play.woods.puddle_lift))
	assert_eq(names, [WoodsShapes.WATER, WoodsShapes.MUD], "water and mud, each its own draw")
	var mats := view.materials()
	assert_lt(worst, 0.001, "every puddle lies on the slope, just over it")
	var water := mesh.surface_get_material(0) as ShaderMaterial
	var mud := mesh.surface_get_material(1) as ShaderMaterial
	assert_lt(water.get_shader_parameter(&"roughness") as float, mud.get_shader_parameter(&"roughness") as float,
			"the water glossier than the mud")
	assert_true(mats.has(water) and mats.has(mud), "both prewarmed")


func test_the_night_air_flies_only_at_night_by_the_wind_dust_share_and_stands_still_under_reduced_motion() -> void:
	var day := WoodsView.build(woodland, play.woods, play.skyline, play.lighting, play.map_style)
	assert_null(day.air(), "no fireflies or motes by day")
	day.free()
	var air := view.air()
	assert_eq(air.multimesh.instance_count, woodland.fireflies + play.woods.mote_count, "every firefly and mote")
	view.set_quality(GraphicsQuality.MeshDetail.LOW, 0.0)
	assert_false(air.visible, "none at Wind dust Off")
	view.set_quality(GraphicsQuality.MeshDetail.LOW, 0.5)
	assert_eq(air.multimesh.visible_instance_count, roundi(air.multimesh.instance_count * 0.5), "half at 50 %")
	var look := air.material_override as ShaderMaterial
	view.set_motion(MotionScale.of(true))
	assert_eq(float(look.get_shader_parameter(&"motion")), 0.0, "still and steady under Reduced motion")
	view.set_motion(MotionScale.of(false))
	assert_eq(float(look.get_shader_parameter(&"motion")), 1.0, "moving again without it")
	view.update(Vector3(1, 2, 3))
	assert_eq(look.get_shader_parameter(&"eye"), Vector3(1, 2, 3), "the motes' box follows the eye")


func _colours_of(v: WoodsView, horizon: Color) -> Dictionary[Color, String]:
	var out: Dictionary[Color, String] = {}
	var parts: Array[WoodsShapes.Placed] = [WoodsShapes.crowns(woodland, play.woods), WoodsShapes.forest(woodland,
			play.woods, play.skyline, horizon)]
	parts.append_array(WoodsShapes.tufts(woodland, play.woods, play.map_style))
	for part in parts:
		for c in part.colours:
			out[c] = "the %s" % ("crowns" if part == parts[0] else "forest" if part == parts[1] else "tufts")
	for m: MeshInstance3D in [v.puddles(), v.floor_pieces()]:
		for s in m.mesh.get_surface_count():
			for c: Color in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]:
				out[Color(c, 1.0)] = String(m.name)
	return out


func test_no_dressing_colour_reads_as_a_team_by_day_or_night() -> void:
	var day := WoodsView.build(woodland, play.woods, play.skyline, play.lighting, play.map_style)
	var colours := _colours_of(day, play.lighting.sky_horizon)
	colours.merge(_colours_of(view, night.sky_horizon))
	colours[play.woods.firefly_colour] = "fireflies"
	colours[woodland.motes_tint] = "motes"
	day.free()
	var team_like: Array[String] = []
	for c: Color in colours:
		if FieldChecks.reads_as_team(c, teams):
			team_like.append("%s %s" % [colours[c], c.to_html(false)])
	assert_gt(colours.size(), 20, "the dressing's colours")
	assert_eq(team_like, [] as Array[String], "no dressing colour within 20 degrees of a team's hue")


func _placed(horizon: Color) -> Array[WoodsShapes.Placed]:
	var out: Array[WoodsShapes.Placed] = [WoodsShapes.crowns(woodland, play.woods), WoodsShapes.forest(woodland,
			play.woods, play.skyline, horizon), WoodsShapes.night_air(woodland, play.woods)]
	out.append_array(WoodsShapes.tufts(woodland, play.woods, play.map_style))
	return out


func test_the_same_map_builds_the_same_dressing() -> void:
	var a := _placed(night.sky_horizon)
	var b := _placed(night.sky_horizon)
	for i in a.size():
		assert_true(a[i].xforms == b[i].xforms and a[i].colours == b[i].colours and a[i].custom == b[i].custom,
				"part %d the same" % i)
	for build: Callable in [WoodsShapes.puddles, WoodsShapes.floor_mesh]:
		var one: ArrayMesh = build.call(woodland, play.woods)
		var two: ArrayMesh = build.call(woodland, play.woods)
		for s in one.get_surface_count():
			var x: Array = one.surface_get_arrays(s)
			var y: Array = two.surface_get_arrays(s)
			assert_true(x[Mesh.ARRAY_VERTEX] == y[Mesh.ARRAY_VERTEX] and x[Mesh.ARRAY_COLOR] == y[Mesh.ARRAY_COLOR],
					"%s surface %d the same" % [one.surface_get_name(s), s])


func test_nothing_in_it_collides_or_lights_or_moves_with_the_simulation() -> void:
	var kinds: Dictionary[String, int] = {}
	var pending: Array[Node] = [view]
	while not pending.is_empty():
		var n: Node = pending.pop_back()
		pending.append_array(n.get_children())
		if n is CollisionObject3D or n is CollisionShape3D or n is NavigationRegion3D or n is Light3D:
			kinds[n.get_class()] = kinds.get(n.get_class(), 0) + 1
	assert_eq(kinds, {} as Dictionary[String, int], "no body, shape, nav region or light under the dressing")


## How many of `a` and `b` differ (two NaNs, no floor, are the same); every one when their sizes differ.
static func _differ(a: PackedFloat32Array, b: PackedFloat32Array) -> int:
	if a.size() != b.size():
		return maxi(a.size(), b.size())
	var n := 0
	for i in a.size():
		if a[i] != b[i] and not (is_nan(a[i]) and is_nan(b[i])):
			n += 1
	return n


## Woodland's file with its `dressing` taken out of the text (the rest as written, every number as it was).
func _stripped() -> MapData:
	var text := FileAccess.get_file_as_string(MapData.DIR + "woodland.json")
	var key := text.find("\"dressing\"")
	var open := text.find("{", key)
	var depth := 0
	var close := open
	while close < text.length():
		depth += 1 if text[close] == "{" else -1 if text[close] == "}" else 0
		if depth == 0:
			break
		close += 1
	var cut := text.substr(0, key) + text.substr(close + 1)
	var comma := cut.find(",", key)
	var json := cut.substr(0, comma) + cut.substr(comma + 1) if cut.substr(key, comma - key).strip_edges() == "" \
			else cut
	assert_true(key >= 0 and depth == 0 and JSON.parse_string(json) is Dictionary, "Woodland without its dressing")
	var m := MapData.parse(json, MapStyle.new(), tuning.rounds.team_size)
	m.id = "woodland"
	return m


func test_it_is_look_only_the_field_checks_nav_grid_and_a_seeded_match_come_out_the_same_without_it() -> void:
	var bare := _stripped()
	var full := MapData.load_map("woodland", MapStyle.new(), tuning.rounds.team_size)
	assert_eq(bare.forest_trees + bare.fireflies + bare.puddles.size(), 0, "nothing of the dressing left")
	var navs: Array[NavGrid] = [NavGrid.build(full, tuning.nav, tuning.body), NavGrid.build(bare, tuning.nav,
			tuning.body)]
	assert_true(navs[0].walkable == navs[1].walkable, "the same walkable cells")
	assert_eq(_differ(navs[0].floor_y, navs[1].floor_y), 0, "the same floors")
	assert_true(navs[0].steps == navs[1].steps and navs[0].cell_start == navs[1].cell_start, "the same steps")
	var entry := MapCatalog.read_file().find("woodland")
	var said: Array[PackedStringArray] = []
	for i in 2:
		var results := FieldChecks.run(entry, [full, bare][i], navs[i], play.map_style, teams,
				FieldStandard.allowed_clashes("woodland"))
		var lines := PackedStringArray()
		for r in results:
			lines.append(str(r))
		said.append(lines)
	assert_eq(said[0], said[1], "the same field checks")
	# with the dressing, drawn at its fullest and at night in the tree beside the level, then without it
	var on := MatchRunner.new(self, "woodland", tuning)
	var dressed := WoodsView.build(on.map, play.woods, play.skyline, night, play.map_style)
	add_child(dressed)
	dressed.set_quality(GraphicsQuality.MeshDetail.ULTRA, 1.0)
	var with_it := on.play(MATCH_SEED, MATCH_SECONDS)
	on.free_level()
	dressed.free()
	# before_all's view leaves the tree too, so nothing of any wood is in the world for this run
	remove_child(view)
	var off := MatchRunner.new(self, "woodland", tuning, null, bare)
	var without := off.play(MATCH_SEED, MATCH_SECONDS)
	off.free_level()
	add_child(view)
	gut.p("%d ticks, %d hits, farthest %s" % [with_it.ticks, with_it.hits, with_it.farthest])
	assert_gt(with_it.farthest[0], 5.0, "the bots left their spawns")
	assert_eq([with_it.ticks, with_it.hits, with_it.rounds.size()], [without.ticks, without.hits, without.rounds.size()],
			"the same match")
	assert_eq(with_it.hits_by, without.hits_by, "the same hits")
	assert_eq(with_it.farthest, without.farthest, "everyone as far from their spawn")

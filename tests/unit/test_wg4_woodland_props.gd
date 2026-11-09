extends GutTest
## WG4: Woodland's small props. A crouch tunnel's walls face in across it (the SIDE lay) and its roof is a log shell at
## its own height with the mound's earth stretched over it from its shoulders (LINED), each section bent to meet the
## next halfway where the floor steps; the tyres and the pickup stand on the ground under their block (grounded) with
## their tops at its top; every prop stays inside its block; the fires and lanterns (LightFixtures) stand on the ground
## or hang from a roof, a post's nail or a pole's hook, glowing and flaming only at night; every model keeps to its
## budget.

const MODELS: Dictionary[StringName, int] = {
	&"tractor_tyre": 750, &"tractor_tyre_stack": 1500, &"pickup": 10000, &"culvert_wall": 890, &"culvert_kerb": 360,
	&"log_tunnel_side": 130, &"log_tunnel_roof": 260, &"log_tunnel_cap": 120, &"log_tunnel_mouth": 1500,
}
const FIXTURES: Dictionary[String, int] = {
	"res://assets/models/props/campfire.glb": 800, "res://assets/models/props/lantern.glb": 400,
	"res://assets/models/props/lantern_post.glb": 160, "res://assets/models/props/lantern_chain.glb": 8,
}

var play: PlayTuning = PlayTuning.load_default()
var cfg: PropDressConfig = null


func before_each() -> void:
	cfg = play.site_look.props


func _woodland() -> MapData:
	return MapData.load_map("woodland", play.map_style, SimTuning.load_default().rounds.team_size)


func _block(dress: StringName, center: Vector3, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = &"log"
	b.dress = dress
	b.center = center
	b.size = size
	return b


func _boxes() -> Dictionary[StringName, AABB]:
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in cfg.models:
		var mesh := cfg.mesh_of(model)
		if mesh != null:
			boxes[model] = mesh.get_aabb()
	return boxes


func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		n += index.size() / 3 if not index.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func test_every_wg4_model_loads_within_its_budget() -> void:
	for model: StringName in MODELS:
		var mesh := cfg.mesh_of(model)
		assert_not_null(mesh, "%s loads" % model)
		if mesh != null:
			assert_between(_tris(mesh), 1, MODELS[model], "%s keeps to its budget" % model)
	# a tunnel section (two walls, the roof and its cap) keeps to the list's 600 a section
	var section := 2 * _tris(cfg.mesh_of(&"log_tunnel_side")) + _tris(cfg.mesh_of(&"log_tunnel_roof")) \
			+ _tris(cfg.mesh_of(&"log_tunnel_cap"))
	assert_lte(section, 600, "a tunnel section keeps to 600 triangles")
	for path: String in FIXTURES:
		var mesh := PropDressConfig.load_mesh(path)
		assert_not_null(mesh, "%s loads" % path)
		if mesh != null:
			assert_between(_tris(mesh), 1, FIXTURES[path], "%s keeps to its budget" % path)


func test_a_tunnel_s_walls_face_in_across_it() -> void:
	var m := MapData.new()
	m.id = "wg4 test"
	m.blocks.append(_block(&"log_tunnel_side", Vector3(0.0, 0.7, -1.0), Vector3(1.0, 1.4, 0.55)))
	m.blocks.append(_block(&"log_tunnel_side", Vector3(0.0, 0.7, 1.0), Vector3(1.0, 1.4, 0.55)))
	m.blocks.append(_block(&"log_tunnel_side", Vector3(5.0, 0.7, 0.0), Vector3(0.55, 1.4, 1.0)))
	m.blocks.append(_block(&"log_tunnel_side", Vector3(7.0, 0.7, 0.0), Vector3(0.55, 1.4, 1.0)))
	var p: PropLayout.Placed = PropLayout.layout(m, cfg, _boxes())[&"log_tunnel_side"]
	assert_eq(p.transforms.size(), 4, "each wall placed once")
	for t in p.transforms:
		var inward := -t.basis.x.normalized()
		var across := Vector3(0.0, 0.0, -signf(t.origin.z)) if absf(t.origin.z) > 0.5 \
				else Vector3(signf(6.0 - t.origin.x), 0.0, 0.0)
		assert_gt(inward.dot(across), 0.99, "the wall at %s faces in across the tunnel" % t.origin)


func test_a_tunnel_s_sections_meet_halfway_where_its_floor_steps() -> void:
	var m := MapData.new()
	m.id = "wg4 test"
	var a := _block(&"log_tunnel_side", Vector3(0.0, 0.7, 0.0), Vector3(0.55, 1.4, 1.0))
	var b := _block(&"log_tunnel_side", Vector3(0.0, 0.8, 1.0), Vector3(0.55, 1.4, 1.0))
	m.blocks.append(a)
	m.blocks.append(b)
	var bend_a := PropLayout.joint_bend(a, m, true)
	var bend_b := PropLayout.joint_bend(b, m, true)
	assert_almost_eq((bend_a * Vector3(0.0, 1.4, 0.5)).y, 1.45, 1e-4,
			"the first section's ceiling rises to the step's middle")
	assert_almost_eq((bend_b * Vector3(0.0, 1.5, 0.5)).y, 1.45, 1e-4, "and the next one's falls to it: they meet")
	assert_almost_eq((bend_a * Vector3(0.0, 1.4, -0.5)).y, 1.4, 1e-4, "a mouth keeps its own height")
	var roof := _block(&"log_tunnel_roof", Vector3(0.0, 2.0, 0.0), Vector3(2.5, 1.2, 1.0))
	m.blocks.append(roof)
	assert_eq(PropLayout.joint_bend(roof, m, false), Transform3D.IDENTITY, "a section alone stays unbent")


func test_a_run_of_sections_ends_in_a_mouth_turned_to_its_open_side() -> void:
	var m := MapData.new()
	m.id = "wg4 test"
	m.blocks.append(_block(&"log_tunnel_roof", Vector3(0.0, 1.85, 0.0), Vector3(2.5, 0.9, 1.0)))
	m.blocks.append(_block(&"log_tunnel_roof", Vector3(0.0, 2.0, 1.0), Vector3(2.5, 1.2, 1.0)))
	m.blocks.append(_block(&"log_tunnel_roof", Vector3(0.0, 1.85, 2.0), Vector3(2.5, 0.9, 1.0)))
	var placed := PropLayout.layout(m, cfg, _boxes())
	assert_eq(placed[&"log_tunnel_mouth"].transforms.size(), 2, "a mouth at each end")
	assert_eq(placed[&"log_tunnel_roof"].transforms.size(), 1, "the middle one a section")
	for t: Transform3D in placed[&"log_tunnel_mouth"].transforms:
		var out := (t.basis * Vector3.FORWARD).normalized()
		assert_gt(out.dot(Vector3(0.0, 0.0, signf(t.origin.z - 1.0))), 0.99, "the mouth at %s faces out" % t.origin)
	# the model's front (-z) is its mouth: the earth runs down onto the log there and is full height at the back
	var tops := {-1: 0.0, 1: 0.0}
	var mesh := PropDressConfig.load_mesh(cfg.models[&"log_tunnel_mouth"])
	for s in mesh.get_surface_count():
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			if absf(v.z) > 0.45:
				tops[int(signf(v.z))] = maxf(tops[int(signf(v.z))], v.y)
	assert_lt(tops[-1] + 0.1, tops[1], "the hood is low at the mouth (-z), high where it meets the next section")


func test_woodland_loads_its_tunnels_mouths_and_caps() -> void:
	# a model is drawn only when the dress loads it: the mouths went unloaded once, so every end showed the roof
	var used := PropDress._models_used(_woodland(), cfg)
	for model: StringName in [&"log_tunnel_side", &"log_tunnel_roof", &"log_tunnel_mouth", &"log_tunnel_cap"]:
		assert_true(used.has(model), "Woodland loads %s" % model)
	var placed := PropLayout.layout(_woodland(), cfg, _boxes())
	assert_eq(placed[&"log_tunnel_mouth"].transforms.size(), 4, "both log tunnels end in a mouth at each end")


func test_a_tunnel_roof_is_a_shell_at_its_own_height_with_earth_over_the_rest() -> void:
	var boxes := _boxes()
	var shell := boxes[&"log_tunnel_roof"].size.y
	var m := MapData.new()
	m.id = "wg4 test"
	m.blocks.append(_block(&"log_tunnel_roof", Vector3(0.0, 1.4 + 0.5, 0.0), Vector3(3.5, 1.0, 1.0)))
	m.blocks.append(_block(&"log_tunnel_roof", Vector3(4.0, 1.4 + shell * 0.25, 0.0),
			Vector3(3.5, shell * 0.5, 1.0)))
	var placed := PropLayout.layout(m, cfg, boxes)
	var roofs: PropLayout.Placed = placed[&"log_tunnel_roof"]
	assert_eq(roofs.transforms.size(), 2, "each roof block gets its shell")
	assert_true(placed.has(&"log_tunnel_cap"), "a tall roof gets its earth cap")
	assert_eq(placed[&"log_tunnel_cap"].transforms.size(), 1, "only the tall one: the low one is all shell")
	for t in roofs.transforms:
		var low := (t * boxes[&"log_tunnel_roof"]).position.y
		assert_almost_eq(low, 1.4, 1e-3, "the shell's underside is the tunnel's ceiling, no lower")
	var cap: Transform3D = placed[&"log_tunnel_cap"].transforms[0]
	var cap_box := cap * boxes[&"log_tunnel_cap"]
	assert_almost_eq(cap_box.position.y, 1.4 + cfg.lined_cap_from, 1e-3, "the cap starts on the log's shoulders")
	assert_almost_eq(cap_box.end.y, 2.4, 1e-3, "and fills the block to its top")


func test_woodland_s_props_stay_inside_their_blocks_and_the_grounded_ones_stand_on_the_ground() -> void:
	var map := _woodland()
	var boxes := _boxes()
	var placed := PropLayout.layout(map, cfg, boxes)
	var blocks: Array[MapData.Block] = []
	for b in map.blocks:
		if MODELS.has(b.dress):
			blocks.append(b)
	assert_gt(blocks.size(), 50, "Woodland names the WG4 props on its blocks")
	for model: StringName in MODELS:
		assert_true(placed.has(model), "Woodland places %s" % model)
		if not placed.has(model):
			continue
		for t: Transform3D in placed[model].transforms:
			var box := t * boxes[model]
			var held := false
			for b in blocks:
				# a tunnel section is bent to meet its neighbours halfway up the floor's step (joint_bend), and a wall
				# stands at its own height with its top at the ceiling, its foot in the ground
				# (and the log's earth reaches past the box's sides onto the bank, log_tunnel.py SKIRT)
				var slack := Vector3(0.4, 0.2, 0.4) if model.begins_with("log_tunnel") else Vector3.ONE * 0.03
				var lo := b.center - b.size * 0.5 - slack
				var hi := b.center + b.size * 0.5 + slack
				if AABB(lo, hi - lo).encloses(box):
					held = true
					break
			assert_true(held, "%s at %s stays inside its block" % [model, t.origin])
	for b in blocks:
		if not cfg.grounded.has(b.dress):
			continue
		var ground := map.terrain.height_at(b.center.x, b.center.z)
		var t: Transform3D = PropLayout.grounded(Transform3D.IDENTITY, boxes[b.dress], b, map)
		assert_almost_eq(t.origin.y, ground, 1e-3, "%s at %s stands on the ground" % [b.dress, b.center])
		assert_almost_eq(t.origin.y + boxes[b.dress].end.y * t.basis.y.y, b.center.y + b.size.y * 0.5, 1e-3,
				"and its top is its block's")


func test_woodland_s_fires_stand_on_the_ground_and_its_lanterns_hang_from_something() -> void:
	var map := _woodland()
	var lc := play.light_fixtures
	var placed := LightFixtures.placings(map, lc)
	var fires := 0
	var lanterns := 0
	for l in map.lights:
		fires += 1 if l.kind == &"fire" else 0
		lanterns += 1 if l.kind == &"lantern" else 0
	assert_gt(lanterns, 0, "Woodland has lanterns")
	assert_eq(placed[lc.kind_models[&"fire"]].size(), fires, "a campfire under each fire")
	assert_eq(placed[lc.kind_models[&"lantern"]].size(), lanterns, "a lantern at each lantern's light")
	for t: Transform3D in placed[lc.kind_models[&"fire"]]:
		var ground := LightPools.ground_under(map, t.origin.x, t.origin.z, t.origin.y + 2.0)
		assert_almost_eq(t.origin.y, ground, 1e-3, "the campfire at %s stands on the ground" % t.origin)
	var chains: Array = placed.get(lc.chain_model, [])
	var posts: Array = placed.get(lc.post_model, [])
	for t: Transform3D in placed[lc.kind_models[&"lantern"]]:
		var bail := t.origin + Vector3(0.0, lc.bail, 0.0)
		var hung := false
		for c: Transform3D in chains:
			# a chain's foot (a metre down its stretched length) at the bail
			hung = hung or (c.origin - c.basis.y).distance_to(bail) < 0.01
		for p: Transform3D in posts:
			var hook := p.origin + p.basis * Vector3(lc.hook_reach, lc.hook_height, 0.0)
			hung = hung or hook.distance_to(bail) < 0.01
		assert_true(hung, "the lantern at %s hangs on a chain or a pole's hook" % t.origin)


func test_fixtures_glow_and_flame_only_at_night_and_only_on_their_maps() -> void:
	var map := _woodland()
	var day := LightingConfig.for_map(play.lighting, play.night_lighting, map, LightingConfig.DAY)
	var night := LightingConfig.for_map(play.lighting, play.night_lighting, map, LightingConfig.NIGHT)
	var by_day := LightFixtures.build(map, play.light_fixtures, day)
	var by_night := LightFixtures.build(map, play.light_fixtures, night)
	add_child_autofree(by_day)
	add_child_autofree(by_night)
	assert_eq(_flames(by_day), 0, "no flames by day")
	assert_gt(_flames(by_night), 0, "flames by night")
	var street := MapData.load_map("street", play.map_style, SimTuning.load_default().rounds.team_size)
	if street != null:
		assert_null(LightFixtures.build(street, play.light_fixtures, night), "The Street's lanterns are its own lamps")


func _flames(fixtures: LightFixtures) -> int:
	var n := 0
	for view in fixtures.views():
		var mesh := view.multimesh.mesh
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s) as ShaderMaterial
			if m != null and m.shader != null and m.shader.code.contains("blend_add"):
				n += 1
	return n

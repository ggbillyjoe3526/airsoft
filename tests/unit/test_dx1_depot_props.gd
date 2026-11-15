extends GutTest
## DX1 (Depot's new props from the owner's photos, 2026-11-15): some of Depot's rack blocks are drawn as wrapped
## racking, IBC and drum stacks or a parts cage instead of the shelving, each a 2.7 m bay of the shelf's size in its
## budget, three bays a model taking turns, the blocks' boxes untouched (only their `dress`); the hall's walls and
## pillars carry look-only extras (fire points, call points, the pipework, the safety signs), every one a
## model StationFixtures draws, in its budget, standing in no block, the fire points clear of the shutters
## and each fire exit's "keep clear" sign beside its door (tools/depot/extras.py follows PropLayout's feature bays).

const BAYS: Array[StringName] = [&"wrapped_racking", &"drum_ibc_stack", &"parts_cage"]
const BAY_BUDGET := 1500
const EXTRA_BUDGETS := {
	&"fire_point": 385, &"call_point": 50, &"pipe_run": 790, &"pipe_run_b": 1100, &"pipe_run_2": 500,
	&"depot_sign_assembly": 52, &"depot_sign_fire_action": 52, &"depot_sign_defib": 52, &"depot_sign_no_riding": 52,
	&"depot_sign_ppe": 52, &"depot_sign_pallet_storage": 52, &"depot_sign_fire_exit": 52,
}
## How far (m) a shutter's opening, its guides and their hazard posts reach from its bay's middle (hall_wall.py), and
## a fire point's half width.
const SHUTTER_REACH := 2.53
const EXTRA_HALF := 0.3

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()
var cfg: PropDressConfig = null
var fixtures_cfg: StationFixturesConfig = null
var depot: MapData = null


func before_all() -> void:
	cfg = play.site_look.props
	fixtures_cfg = play.station_fixtures
	depot = MapData.load_map("depot", play.map_style, tuning.rounds.team_size)


func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var idx: PackedInt32Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		n += idx.size() / 3 if idx.size() > 0 else (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as Array).size() / 3
	return n


func _boxes() -> Dictionary[StringName, AABB]:
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in cfg.models:
		var mesh := cfg.mesh_of(model)
		if mesh != null:
			boxes[model] = mesh.get_aabb()
	return boxes


func test_depot_loads_with_its_extras() -> void:
	assert_true(depot.ok(), "Depot loads: %s" % [depot.problems])
	assert_eq(depot.warnings.filter(func(w: String) -> bool: return w.contains("fixtures")), [],
			"every wall extra reads")
	assert_gt(depot.fixtures.size(), 40, "the hall's walls carry their extras")


func test_each_new_bay_is_the_shelf_s_size_in_its_budget_and_takes_turns() -> void:
	var shelf := cfg.mesh_of(&"shelf").get_aabb()
	for base in BAYS:
		var each := cfg.variants_of(base)
		assert_eq(each.size(), 3, "%s has three bays taking turns" % base)
		assert_eq(cfg.model_lays.get(base), PropDressConfig.Lay.TILE, "%s is laid as the racking is" % base)
		for bay in each:
			var mesh := cfg.mesh_of(bay)
			assert_not_null(mesh, "%s loads" % bay)
			if mesh == null:
				continue
			assert_almost_eq(mesh.get_aabb().size.x, shelf.size.x, 0.02, "%s is a bay wide" % bay)
			assert_almost_eq(mesh.get_aabb().end.y, shelf.end.y, 0.02, "%s is the racking's height" % bay)
			assert_lte(mesh.get_aabb().end.z, shelf.end.z + 0.01, "%s stands in the bay's depth" % bay)
			assert_lte(_tris(mesh), BAY_BUDGET, "%s within the bay's budget" % bay)


func test_some_rack_blocks_are_dressed_as_the_new_bays_and_keep_their_boxes() -> void:
	var counts: Dictionary[StringName, int] = {}
	var racks := 0
	for b in depot.blocks:
		if b.kind != &"rack":
			continue
		racks += 1
		if b.dress != &"":
			assert_true(BAYS.has(b.dress), "a rack block names one of the new bays, not %s" % b.dress)
			assert_true(cfg.dresses(b), "a dressed rack block is drawn")
			assert_true(cfg.backs(b), "and keeps its dark backing")
			counts[b.dress] = counts.get(b.dress, 0) + 1
	for base in BAYS:
		assert_gt(counts.get(base, 0), 3, "%s stands in Depot" % base)
	var dressed := 0
	for n: int in counts.values():
		dressed += n
	assert_lt(dressed, racks, "some of the racking stays")
	# laid on Depot: every bay of the new models placed
	var all := PropLayout.layout(depot, cfg, _boxes())
	for base in BAYS:
		for bay in cfg.variants_of(base):
			assert_true(all.has(bay) and (all[bay] as PropLayout.Placed).transforms.size() > 0, "%s is laid" % bay)


func test_every_wall_extra_is_a_fixture_model_in_its_budget() -> void:
	var used: Dictionary[StringName, int] = {}
	for f in depot.fixtures:
		assert_true(fixtures_cfg.models.has(String(f.model)), "%s is a fixture model" % f.model)
		used[f.model] = used.get(f.model, 0) + 1
	for model: StringName in EXTRA_BUDGETS:
		var mesh := PropDressConfig.load_mesh(fixtures_cfg.path_of(model))
		assert_not_null(mesh, "%s loads" % model)
		if mesh != null:
			assert_lte(_tris(mesh), int(EXTRA_BUDGETS[model]), "%s within its budget" % model)
	for model: StringName in [&"fire_point", &"call_point", &"pipe_run", &"pipe_run_b", &"depot_sign_fire_exit"]:
		assert_gt(used.get(model, 0), 0, "Depot has a %s" % model)
	var placed := StationFixtures.placings_of(depot.fixtures, fixtures_cfg)
	assert_eq(placed.size(), used.size(), "every extra is drawn")


func test_no_wall_extra_stands_in_a_block() -> void:
	var meshes: Dictionary[StringName, AABB] = {}
	for f in depot.fixtures:
		if not meshes.has(f.model):
			meshes[f.model] = PropDressConfig.load_mesh(fixtures_cfg.path_of(f.model)).get_aabb()
		var t := Transform3D(Basis(Vector3.UP, f.yaw).scaled(Vector3.ONE * f.scale), f.position)
		var box := t * meshes[f.model]
		# shrunk 2 cm (a thin sign by less), so touching the floor or a wall's face isn't standing in it
		var d := (box.size * 0.4).min(Vector3.ONE * 0.02)
		box = AABB(box.position + d, box.size - d * 2.0)
		for b in depot.blocks:
			if b.kind == &"pillar" or b.kind == &"floor":
				continue  # a pillar's call point and extinguisher are on its round post, inside its square box
			var solid := AABB(b.center - b.size * 0.5, b.size)
			assert_false(solid.intersects(box), "%s at %s stands in a %s block at %s" % [f.model, f.position, b.kind,
					b.center])


func test_fire_points_keep_off_the_shutters_and_each_exit_has_its_sign() -> void:
	var all := PropLayout.layout(depot, cfg, _boxes())
	var shutters: Array[Transform3D] = []
	var exits: Array[Transform3D] = []
	if all.has(&"hall_shutter"):
		shutters = (all[&"hall_shutter"] as PropLayout.Placed).transforms
	if all.has(&"hall_exit"):
		exits = (all[&"hall_exit"] as PropLayout.Placed).transforms
	for f in depot.fixtures:
		if f.model != &"fire_point":
			continue
		for s in shutters:
			var along := (f.position - s.origin).dot(s.basis.x.normalized())
			var out := absf((f.position - s.origin).dot(s.basis.z.normalized()))
			if out < 1.0:
				assert_gte(absf(along), SHUTTER_REACH + EXTRA_HALF, "%s at %s clear of a shutter" % [f.model, f.position])
	var signs: Array[StationDressing.Fixture] = []
	for f in depot.fixtures:
		if f.model == &"depot_sign_fire_exit":
			signs.append(f)
	assert_eq(signs.size(), exits.size(), "one keep-clear sign an exit")
	for e in exits:
		var near := 0
		for f in signs:
			if Vector2(f.position.x - e.origin.x, f.position.z - e.origin.z).length() < 1.6:
				near += 1
		assert_eq(near, 1, "the exit at %s has its sign beside its door" % e.origin)


func test_the_pipework_is_drawn_in_chunks_that_cull_and_every_fixture_once() -> void:
	var view := StationFixtures.build(depot, fixtures_cfg)
	assert_not_null(view, "Depot's extras drawn")
	if view == null:
		return
	add_child_autofree(view)
	var pipes := 0
	var total := 0
	for v in view.views():
		total += v.multimesh.instance_count
		if v.multimesh.mesh != null and v.name.begins_with("PipeRun") and v.multimesh.instance_count > 0:
			pipes += 1
			assert_lte(v.multimesh.get_aabb().size.x, fixtures_cfg.chunks[&"pipe_run"] + 4.5, "a chunk, not the hall")
	assert_eq(total, depot.fixtures.size(), "every extra drawn once")
	assert_gt(pipes, 4, "the pipework in chunks round the hall")

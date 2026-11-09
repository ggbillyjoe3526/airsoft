extends GutTest
## WG2 (Dev 3, Woodland's models, tools/blender/maps/): every fallen log, wind-thrown tree, woodpile, board stack and
## the saw bench stands inside its block's box, a grounded one (PropDressConfig.Lay.GROUND) reaching its box's top;
## an earth bank only under a grounded prop, inside its box and under the ground at its middle; each woodpile one
## section high, the three sections mixed in one shade, its stack 1.8 m over the ground (the gate screens 2.8 m); the
## tunnel's log lining keeps its old dress; every model keeps to its triangle budget; off the map's data, a grounded
## prop on a map without terrain or in a box lower than `ground_least` still stands in its box up to its top, any bank
## inside it; no moss lid floats over a log drawn as a model of its own (WoodsConfig.moss_dresses).

const BUDGETS := {
	&"fallen_log_5": 1500, &"fallen_log_6": 1500, &"fallen_log_8": 1500, &"root_plate": 4000, &"cordwood": 1200,
	&"cordwood_b": 1200, &"cordwood_c": 1200, &"boards": 1500, &"sawbench": 2000, &"earth_bank": 340,
}
const FOLIAGE_BUDGETS := {"fern_model": 400, "bush_model": 1500}
const GROUNDED: Array[StringName] = [
	&"fallen_log_5", &"fallen_log_6", &"fallen_log_8", &"root_plate", &"sawbench", &"boards",
]
## How far a model's corner may stand past its box (m): float error only.
const SLACK := 0.02

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()
var cfg: PropDressConfig = null
var woodland: MapData = null
var placed: Dictionary[StringName, PropLayout.Placed] = {}
var dress: PropDress = null


func before_all() -> void:
	cfg = play.site_look.props
	woodland = MapData.load_map("woodland", play.map_style, tuning.rounds.team_size)
	dress = PropDress.build(woodland, cfg)
	add_child(dress)
	placed = dress.placed()


func after_all() -> void:
	dress.free()


func _box(b: MapData.Block, grow: float) -> AABB:
	return AABB(b.center - b.size * 0.5, b.size).grow(grow)


## The block dressed with `model` whose box holds `at` (grown by SLACK), or null.
func _block_at(model: StringName, at: Vector3) -> MapData.Block:
	for b in woodland.blocks:
		if b.dress == model and _box(b, SLACK).has_point(at):
			return b
	return null


func _corners(t: Transform3D, box: AABB) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in 8:
		out.append(t * box.get_endpoint(i))
	return out


func _bounds(t: Transform3D, box: AABB) -> AABB:
	var c := _corners(t, box)
	var out := AABB(c[0], Vector3.ZERO)
	for p in c:
		out = out.expand(p)
	return out


func _triangles(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		n += (index.size() if not index.is_empty() else verts.size()) / 3
	return n


func test_every_grounded_prop_stands_inside_its_box_up_to_its_top() -> void:
	for model in GROUNDED:
		assert_true(placed.has(model), "Woodland lays %s" % model)
		if not placed.has(model):
			continue
		var box := dress.mesh_of(model).get_aabb()
		for t: Transform3D in placed[model].transforms:
			var b := _block_at(model, t.origin)
			assert_not_null(b, "%s at %s stands in a block dressed with it" % [model, t.origin])
			if b == null:
				continue
			var drawn := _bounds(t, box)
			assert_true(_box(b, SLACK).encloses(drawn), "%s at %s stays inside its box" % [model, t.origin])
			assert_almost_eq(drawn.end.y, b.center.y + b.size.y * 0.5, SLACK, "%s at %s reaches its box's top" % [
					model, t.origin])


func test_an_earth_bank_stands_only_under_a_grounded_prop_and_under_the_ground_at_its_middle() -> void:
	assert_true(placed.has(cfg.ground_bank), "the slopes under Woodland's props get earth banks")
	if not placed.has(cfg.ground_bank):
		return
	var box := dress.mesh_of(cfg.ground_bank).get_aabb()
	for t: Transform3D in placed[cfg.ground_bank].transforms:
		var b: MapData.Block = null
		for model in GROUNDED:
			b = _block_at(model, t.origin + Vector3(0.0, 0.05, 0.0)) if b == null else b
		assert_not_null(b, "the bank at %s is under a grounded prop" % t.origin)
		if b == null:
			continue
		var drawn := _bounds(t, box)
		assert_true(_box(b, SLACK).encloses(drawn), "the bank at %s stays inside its box" % t.origin)
		var ground := PropLayout.ground_at(woodland, b.center.x, b.center.z, b.center.y)
		assert_lte(drawn.end.y, ground + SLACK, "the bank at %s keeps its top under the ground at its middle" % t.origin)


func test_every_woodpile_is_one_section_high_inside_its_box_its_sections_mixed() -> void:
	var sections := cfg.variants_of(&"cordwood")
	assert_eq(sections.size(), 3, "three cordwood sections")
	for model in sections:
		assert_true(placed.has(model), "Woodland's woodpiles lay %s" % model)
		if not placed.has(model):
			continue
		var box := dress.mesh_of(model).get_aabb()
		for t: Transform3D in placed[model].transforms:
			var b := _block_at(&"cordwood", t.origin + Vector3(0.0, 0.05, 0.0))
			assert_not_null(b, "the %s at %s is in a woodpile" % [model, t.origin])
			if b == null:
				continue
			var drawn := _bounds(t, box)
			assert_true(_box(b, SLACK).encloses(drawn), "the %s at %s stays inside its box" % [model, t.origin])
			assert_almost_eq(drawn.size.y, b.size.y, SLACK, "the %s at %s is as tall as its stack" % [model, t.origin])
		# one shade along a stack, so the joins between its sections don't show as steps of light and dark
		for shade in placed[model].shades:
			assert_eq(shade, 1.0, "the %s sections keep one shade" % model)


func test_the_woodpiles_stand_1_8_m_the_gate_screens_2_8() -> void:
	var stacks := 0
	for b in woodland.blocks:
		if b.dress != &"cordwood":
			continue
		var top := b.center.y + b.size.y * 0.5
		var ground := PropLayout.ground_at(woodland, b.center.x, b.center.z, top)
		if top - ground < 1.2:
			continue  # a log pile, knee high
		stacks += 1
		var tall := top - ground
		# the woodpiles and log stacks 1.8 m (the owner, 2026-11-09); the camp gate screens keep their 2.8 m, which
		# keeps the spawns out of sight of the slopes outside (test_woodland_layout)
		assert_true(absf(tall - 1.8) < 0.05 or absf(tall - 2.8) < 0.05,
				"the stack at %s stands 1.8 m (a gate screen 2.8 m), not %.2f" % [b.center, tall])
	assert_gt(stacks, 10, "Woodland has its woodpiles, log stacks and gate screens")


func test_the_tunnel_keeps_its_log_lining() -> void:
	var lining := 0
	for b in woodland.blocks:
		if b.dress in [&"log_tunnel_side", &"log_tunnel_roof"]:
			lining += 1
	assert_gt(lining, 0, "the Badger run keeps its hollow-log lining (WG4), not a fallen log")


func test_every_model_keeps_to_its_budget() -> void:
	for model: StringName in BUDGETS:
		var mesh := cfg.mesh_of(model)
		assert_not_null(mesh, "%s loads" % model)
		if mesh != null:
			assert_between(_triangles(mesh), int(BUDGETS[model] * 0.5), int(BUDGETS[model]), "%s's triangles" % model)
	var woods := play.woods
	for key: String in FOLIAGE_BUDGETS:
		var mesh := PropDressConfig.load_mesh(woods.get(key))
		assert_not_null(mesh, "%s loads" % key)
		if mesh != null:
			assert_between(_triangles(mesh), int(FOLIAGE_BUDGETS[key] * 0.5), int(FOLIAGE_BUDGETS[key]), key)


## A map of one block dressed with `model`, `size` m, its foot at y = 0; no terrain.
func _one_block(model: StringName, size: Vector3) -> MapData:
	var m := MapData.new()
	var b := MapData.Block.new()
	b.kind = &"log"
	b.dress = model
	b.size = size
	b.center = Vector3(0.0, size.y * 0.5, 0.0)
	m.blocks.append(b)
	return m


func test_a_grounded_prop_without_terrain_or_in_a_low_box_still_fills_its_box() -> void:
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in [&"root_plate", cfg.ground_bank]:
		boxes[model] = cfg.mesh_of(model).get_aabb()
	for size: Vector3 in [Vector3(6.0, 2.2, 2.0), Vector3(2.0, 2.2, 6.0), Vector3(4.0, 0.1, 1.0)]:
		var m := _one_block(&"root_plate", size)
		var out := PropLayout.layout(m, cfg, boxes)
		assert_true(out.has(&"root_plate"), "a root plate in a %s box" % size)
		# without terrain the ground line is the box's foot, raised as far as keeps the model's buried part in the box;
		# a bank, if any, fills that gap under it inside the box
		if out.has(cfg.ground_bank):
			for t: Transform3D in out[cfg.ground_bank].transforms:
				assert_true(_box(m.blocks[0], SLACK).encloses(_bounds(t, boxes[cfg.ground_bank])),
						"the bank in a %s box stays inside it" % size)
		if not out.has(&"root_plate"):
			continue
		assert_eq(out[&"root_plate"].transforms.size(), 1)
		var drawn := _bounds(out[&"root_plate"].transforms[0], boxes[&"root_plate"])
		assert_true(_box(m.blocks[0], SLACK).encloses(drawn), "inside its %s box" % size)
		assert_almost_eq(drawn.end.y, size.y, SLACK, "up to its %s box's top" % size)
		var long := maxf(size.x, size.z)
		assert_almost_eq(maxf(drawn.size.x, drawn.size.z), long, SLACK, "along its %s box's long side" % size)


func test_no_moss_lid_floats_over_a_modelled_log() -> void:
	# the moss lid sits moss_proud over a log's box: on a log drawn as a model of its own it would float as a sheet
	var woods := play.woods
	var mesh := WoodsShapes.floor_mesh(woodland, woods)
	assert_not_null(mesh, "Woodland's floor draws")
	if mesh == null:
		return
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var modelled := 0
	for b in woodland.blocks:
		if b.kind != &"log" or woods.moss_dresses.has(b.dress):
			continue
		modelled += 1
		var lid := b.center.y + b.size.y * 0.5 + woods.moss_proud
		var lo := b.center - b.size * 0.5
		var hi := b.center + b.size * 0.5
		var over := 0
		for v in verts:
			if absf(v.y - lid) < 0.002 and v.x >= lo.x - 0.01 and v.x <= hi.x + 0.01 and v.z >= lo.z - 0.01 \
					and v.z <= hi.z + 0.01:
				over += 1
		assert_eq(over, 0, "no moss lid over the %s at %s" % [b.dress, b.center])
	assert_gt(modelled, 10, "Woodland's logs are drawn as WG2's models")

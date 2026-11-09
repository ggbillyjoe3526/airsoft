extends GutTest
## RK1: Depot's and the Range's racking and small props, built in Blender (tools/blender/maps/). Each model is one
## vertex-coloured mesh within its triangle budget, modelled at its block's size so the game's fit barely stretches it;
## Depot's desks and lockers and the Range's kit rack are drawn as their own models, inside their blocks, the desks and
## lockers facing the field and drawn without the crate's battens or the plywood's cap, the lockers ringing as steel;
## nothing else on the Range changes; prop.py's palette is the look's.

## Each model: its triangle budget (docs: art/depot-range-model-list.md) and the size it is modelled at (m, x y z in
## Godot's axes: across, up, front to back), its block's.
const MODELS := {
	&"shelf": {"budget": 1500, "size": Vector3(2.7, 3.0, 0.9)},
	&"shelf_c": {"budget": 1500, "size": Vector3(2.7, 3.0, 0.9)},
	&"kit_rack": {"budget": 2500, "size": Vector3(2.6, 2.4, 0.6)},
	&"drum": {"budget": 1400, "size": Vector3(0.532, 1.6, 0.532)},
	&"pallet": {"budget": 300, "size": Vector3(1.8, 0.15, 1.8)},
	&"barrel": {"budget": 700, "size": Vector3(0.65, 0.95, 0.65)},
	&"sofa": {"budget": 3000, "size": Vector3(3.2, 0.85, 1.0)},
	&"desk": {"budget": 2000, "size": Vector3(2.2, 0.8, 1.0)},
	&"locker": {"budget": 2000, "size": Vector3(2.0, 2.2, 1.0)},
}
## How far (m) a model's bounds may differ from its block's size: a few centimetres of a soft cushion, a stretched
## depth on the racking (only its front half shows).
const SIZE_SLACK := 0.06

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()
var look: SiteLook = null


func before_each() -> void:
	look = play.site_look


func _map(id: String) -> MapData:
	var m := MapData.load_map(id, play.map_style, 1 if id == "range" else tuning.rounds.team_size)
	assert_true(m.ok(), "%s loads: %s" % [id, m.problems])
	return m


func _dress(m: MapData) -> PropDress:
	var dress := PropDress.build(m, look.props)
	if dress != null:
		add_child_autofree(dress)
	return dress


func test_each_model_is_one_coloured_mesh_in_its_budget_at_its_block_s_size() -> void:
	for model: StringName in MODELS:
		var mesh := PropDressConfig.load_mesh(look.props.models[model])
		assert_not_null(mesh, "%s loads" % model)
		if mesh == null:
			continue
		assert_eq(mesh.get_surface_count(), 1, "%s is one mesh" % model)
		var arrays := mesh.surface_get_arrays(0)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var tris := (index.size() if not index.is_empty() else verts.size()) / 3
		assert_lte(tris, MODELS[model]["budget"] as int, "%s: %d triangles within its budget" % [model, tris])
		assert_gt(tris, (MODELS[model]["budget"] as int) / 2, "%s uses its budget for detail" % model)
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		assert_eq(colours.size(), verts.size(), "%s is painted on every vertex" % model)
		var size := mesh.get_aabb().size
		var want: Vector3 = MODELS[model]["size"]
		for a in 3:
			assert_almost_eq(size[a], want[a], SIZE_SLACK, "%s's size on axis %d" % [model, a])


func test_each_model_is_solid_from_outside() -> void:
	# FS1's check (test_model_faces): rays from all round meet a face turned toward them, so no round part is built
	# inside out and culled as a hole.
	var models: Array[StringName] = []
	models.append_array(MODELS.keys())
	models.append(&"shelf_b")
	for model in models:
		var mesh := PropDressConfig.load_mesh(look.props.models[model])
		if mesh == null:
			continue
		var share := (load("res://tests/unit/test_model_faces.gd") as GDScript).call("back_share", mesh) as float
		assert_lt(share, 0.02, "%s: %.1f%% of rays from outside meet a face turned away" % [model, share * 100.0])


func test_the_racking_mixes_its_bays_and_never_repeats_one_side_by_side() -> void:
	var m := _map("depot")
	var dress := _dress(m)
	var bays := look.props.variants_of(&"shelf")
	assert_eq(bays.size(), 3, "three bays (the owner: a mix of pallet racking)")
	var all: Array[Transform3D] = []
	var names: Array[StringName] = []
	var total := 0
	for bay in bays:
		var mesh := dress.mesh_of(bay)
		assert_not_null(mesh, "%s loads" % bay)
		if mesh == null:
			continue
		assert_almost_eq(mesh.get_aabb().size, dress.mesh_of(&"shelf").get_aabb().size, Vector3.ONE * 0.01,
				"%s is the same bay's size" % bay)
		var tris: int = (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		assert_lte(tris, 1500, "%s within the bay's budget" % bay)
		total += dress.count(bay)
		for t in dress.placed()[bay].transforms:
			all.append(t)
			names.append(bay)
	for bay in bays:
		assert_gt(dress.count(bay), total / 6, "%s is laid about its share" % bay)
	var cell := dress.mesh_of(&"shelf").get_aabb()
	var face := Vector3(cell.get_center().x, 0.0, cell.end.z)
	var same := 0
	for i in all.size():
		for j in range(i + 1, all.size()):
			# side by side in one row: facing the same way, in line, within a bay and a half of each other
			var front := Vector3(all[i].basis.z.x, 0.0, all[i].basis.z.z).normalized()
			# by their front faces' middles: rows of different depths on abutting blocks still line up there
			var gap := all[j] * face - all[i] * face
			if front.dot(Vector3(all[j].basis.z.x, 0.0, all[j].basis.z.z).normalized()) > 0.99 \
					and absf(gap.dot(front)) < 0.05 and absf(gap.y) < 0.01 and gap.length() < 4.0 \
					and names[i] == names[j]:
				same += 1
	assert_eq(same, 0, "no bay stands next to itself")


func test_depot_s_desks_and_lockers_are_their_own_models_facing_the_field() -> void:
	var m := _map("depot")
	var dress := _dress(m)
	var desks: Array[MapData.Block] = []
	var lockers: Array[MapData.Block] = []
	for b in m.blocks:
		if b.dress == &"desk":
			desks.append(b)
		elif b.dress == &"locker":
			lockers.append(b)
	assert_eq(desks.size(), 3, "the three desks")
	assert_eq(lockers.size(), 1, "the lockers")
	for b in desks:
		assert_eq(b.kind, &"crate", "a desk keeps its kind (wood to a BB)")
		assert_true(SiteDress._modelled(look, b), "drawn as the desk, without the crate's battens")
	assert_eq(lockers[0].kind, &"plywood", "the lockers keep theirs")
	assert_eq(lockers[0].surface, RayHit.Surface.METAL, "but ring as the steel they are drawn as")
	assert_true(SiteDress._modelled(look, lockers[0]), "drawn as the lockers, without the plywood's cap")
	assert_eq(dress.count(&"desk"), 3)
	assert_eq(dress.count(&"locker"), 1)
	var middle := PropLayout.field_middle(m)
	for i in desks.size():
		var t := dress.placed()[&"desk"].transforms[i]
		var front := (t.basis * Vector3(0.0, 0.0, 1.0)).normalized()
		var to := middle - t.origin
		assert_gt(front.dot(Vector3(to.x, 0.0, to.z).normalized()), 0.0, "desk %d's drawers face the field" % i)


func test_a_modelled_block_draws_no_details_and_a_plain_crate_keeps_its_battens() -> void:
	var m := _map("depot")
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body, play.baked_light, LightingConfig.for_map(play.lighting, null, m,
			LightingConfig.DAY), false, look)
	var site := SiteDress.build(m, look, level.site_material())
	add_child_autofree(site)
	# Depot's details may be none at all now its crates, walls and containers are models (DM1).
	var mesh := site.details().mesh
	var verts := PackedVector3Array()
	if mesh != null and mesh.get_surface_count() > 0:
		verts = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var plain := 0
	for b in m.blocks:
		if b.kind != &"crate" and b.kind != &"plywood":
			continue
		var box := AABB(b.center - b.size * 0.5, b.size).grow(look.proud + 1e-3)
		var inside := 0
		for v in verts:
			if box.has_point(v):
				inside += 1
		if b.dress != &"":
			assert_eq(inside, 0, "%s at %s: no battens or cap on a block drawn as its own model" % [b.dress, b.center])
		elif SiteSurface.as_props(look, b):
			assert_eq(inside, 0, "%s at %s: no battens or cap on a block drawn as its kind's model (DM1)" % [b.kind,
					b.center])
		elif b.kind == &"crate" and inside > 0:
			plain += 1
	# Depot's crate blocks are all crates or desks now (DM1, RK1); one left a box would still be battened.
	assert_eq(plain, m.blocks.filter(func(b: MapData.Block) -> bool: return b.kind == &"crate" \
			and not SiteSurface.as_props(look, b)).size(), "a crate block drawn as no prop is still battened")


func test_the_props_palette_is_the_look_s() -> void:
	# tools/blender/maps/prop.py paints by palette name from its own copy of LookConfig.palette: they must agree.
	var text := FileAccess.get_file_as_string("res://tools/blender/maps/prop.py")
	var re := RegEx.create_from_string("\"(\\w+)\": 0x([0-9a-f]{6})")
	var palette := PlayTuning.load_default().look.palette
	var found := 0
	for hit in re.search_all(text):
		var name := StringName(hit.get_string(1))
		assert_true(palette.has(name), "%s is a palette colour" % name)
		if palette.has(name):
			assert_eq(palette[name].to_html(false), hit.get_string(2), "%s is the palette's" % name)
		found += 1
	assert_gt(found, 20, "prop.py's palette was read")


func test_the_range_s_kit_rack_is_its_own_model_inside_its_block() -> void:
	var m := _map("range")
	var rack: MapData.Block = null
	for b in m.blocks:
		if b.kind == &"rack":
			rack = b
	assert_not_null(rack)
	assert_eq(rack.dress, &"kit_rack")
	assert_true(look.props.dresses(rack))
	assert_false(look.props.backs(rack), "fitted whole, no backing: both its faces show")
	var dress := _dress(m)
	assert_eq(dress.count(&"kit_rack"), 1)
	assert_false(dress.placed().has(&"shelf"), "no racking lined round it any more")
	var t := dress.placed()[&"kit_rack"].transforms[0]
	var box := AABB(rack.center - rack.size * 0.5, rack.size).grow(1e-3)
	var mesh := dress.mesh_of(&"kit_rack")
	for v: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		if not box.has_point(t * v):
			fail_test("the kit rack reaches past its block at %s" % (t * v))
			return
	var front := (t.basis * Vector3(0.0, 0.0, 1.0)).normalized()
	var to := PropLayout.field_middle(m) - rack.center
	assert_gt(front.dot(Vector3(to.x, 0.0, to.z).normalized()), 0.0, "its stands face the firing line")

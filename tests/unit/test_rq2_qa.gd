extends GutTest
## RQ2 (QA): the rebuilt skyline models keep their bounds, only the mast has lamp glass, every model keeps
## piece-coloured (BODY) faces, and no vertex is degenerate.

## Each model's size (m) at the commit before RQ2; shed models were a little wider than their box (eaves), now exact;
## the mast's box grew 0.5 -> 2.4 m deep for its three-sector head (RQ2 attempt 2).
const OLD_SIZES: Dictionary[String, Vector3] = {
	"shed": Vector3(26.265, 8.201, 14.05), "shed_long": Vector3(50.265, 12.401, 22.05),
	"shed_deep": Vector3(40.265, 12.001, 26.05), "crane": Vector3(24.8, 17.985, 4.8),
	"mast": Vector3(2.4, 14.0, 2.4), "fuselage": Vector3(24.0, 9.0, 4.45), "silo": Vector3(5.96, 15.0, 5.96),
	"watch_tower": Vector3(5.2, 12.4, 5.2), "water_tower": Vector3(6.452, 22.0, 6.445)}
const MAST_LAMP_TRIANGLES := 8


func _arrays(model: String) -> Array:
	var mesh := PropDressConfig.load_mesh("res://assets/models/skyline/%s.glb" % model)
	assert_not_null(mesh, "%s loads" % model)
	return mesh.surface_get_arrays(0)


func test_each_model_keeps_the_bounds_it_had() -> void:
	for model: String in OLD_SIZES:
		var verts: PackedVector3Array = _arrays(model)[Mesh.ARRAY_VERTEX]
		var box := AABB(verts[0], Vector3.ZERO)
		for v in verts:
			box = box.expand(v)
		var want := OLD_SIZES[model]
		var off := (box.size - want).abs()
		assert_lt(maxf(off.x, maxf(off.y, off.z)), 0.3, "%s is %s, was %s" % [model, box.size, want])
		assert_lt(absf(box.position.y), 0.01, "%s stands on the ground" % model)


func test_only_the_mast_has_lamp_glass_and_it_has_four_lamps() -> void:
	for model: String in OLD_SIZES:
		var cols: PackedColorArray = _arrays(model)[Mesh.ARRAY_COLOR]
		var idx: PackedInt32Array = _arrays(model)[Mesh.ARRAY_INDEX]
		var lamps := 0
		for t in idx.size() / 3:
			if SkylineModels._is_lamp(cols[idx[t * 3]].a):
				lamps += 1
		assert_eq(lamps, MAST_LAMP_TRIANGLES if model == "mast" else 0, "%s lamp triangles" % model)


func test_every_model_keeps_faces_that_take_the_pieces_colour() -> void:
	for model: String in OLD_SIZES:
		var cols: PackedColorArray = _arrays(model)[Mesh.ARRAY_COLOR]
		var body := 0
		for c in cols:
			if c.a < SkylineModels.BODY_BELOW:
				body += 1
		assert_gt(body, cols.size() / 20, "%s: a share of its faces are body-coloured" % model)


func test_no_model_has_a_nan_vertex_or_normal() -> void:
	for model: String in OLD_SIZES:
		var a := _arrays(model)
		for v: Vector3 in a[Mesh.ARRAY_VERTEX]:
			assert_true(v.is_finite(), "%s vertex %s" % [model, v])
			if not v.is_finite():
				break
		for n: Vector3 in a[Mesh.ARRAY_NORMAL]:
			assert_true(n.is_finite(), "%s normal" % model)
			if not n.is_finite():
				break


## The owner's "more colour, more green on the shed and yellow on the crane": every modelled piece keeps all its colour
## against the look's pull toward grey and takes under half the greybox's fade, and most of the Range's sheds are green.
func test_models_keep_their_colour_and_most_range_sheds_are_green() -> void:
	var play := PlayTuning.load_default()
	var cfg := play.skyline
	var m := MapData.load_map("range", play.map_style, 1)
	var middle := SkylineView.middle_of(m)
	var sheds := 0
	var green := 0
	for p: SkylinePiece in m.skyline:
		for placed: SkylineModels.Placed in SkylineModels.placed_of(p, cfg, middle):
			assert_eq(placed.keep, 1.0, "%s keeps all its colour" % p.kind)
			assert_lt(placed.haze, 0.5, "%s fades under half the greybox's" % p.kind)
		if p.kind == &"shed":
			sheds += 1
			var c := SkylineModels.body_of(p, cfg)
			if c.g > c.r and c.g > c.b:
				green += 1
	assert_gte(green * 4, sheds * 3, "%d of %d sheds green" % [green, sheds])
	var crane := cfg.crane_colour
	assert_gt(crane.s, 0.9, "the crane a full yellow")

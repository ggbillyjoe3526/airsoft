extends GutTest
## TQ1 QA: the subway's trains carry surface kinds (UV y >= 100); any other prop with kinds (SQ1) has whole kinds
## only; the draft screens are a car's one clear (a little more opaque than the windows), shadowless instance inside its
## box; the shader includes its kinds.

const PROPS := "res://assets/models/props/"
const KIND_BASE := 100.0

var play: PlayTuning = PlayTuning.load_default()


## The (min, max) of UV y over every surface of `mesh`, or Vector2(INF, -INF) when it has no UVs.
func _uv_y_range(mesh: Mesh) -> Vector2:
	var r := Vector2(INF, -INF)
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
		if uvs == null:
			continue
		for uv: Vector2 in (uvs as PackedVector2Array):
			r.x = minf(r.x, uv.y)
			r.y = maxf(r.y, uv.y)
	return r


func _subway() -> MapData:
	var m := MapData.load_map("subway", play.map_style, SimTuning.new().rounds.team_size)
	assert_true(m.ok(), "subway loads: %s" % [m.problems])
	return m


func test_the_train_models_carry_surface_kinds_one_to_seven_and_no_uv_x() -> void:
	var look := play.station_look.trains
	for path: String in [look.body, look.door, look.gangway, PROPS + "train_seat.glb", PROPS + "tool_cart.glb"]:
		var mesh := look.mesh(path)
		assert_not_null(mesh, path)
		var r := _uv_y_range(mesh)
		assert_true(r.y >= KIND_BASE + 1.0 - 0.01 and r.y <= KIND_BASE + 7.0 + 0.01, "%s kinds up to %s" % [path, r])
		var bad := 0
		for s in mesh.get_surface_count():
			for uv: Vector2 in (mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV] as PackedVector2Array):
				if uv.y < KIND_BASE - 0.5 or absf(uv.x) > 0.0001 or absf(uv.y - roundf(uv.y)) > 0.01:
					bad += 1
		assert_eq(bad, 0, "%s: every vertex a whole kind, UV x 0 (never perforated or ribbed)" % path)


## SQ1: the station props carry kinds too. A vertex with UV x 0 is plain (y 0, or y 100: kind 0) or a whole kind (y 101
## to 109; TQ2 added 9, lit); one with UV x set is a perforated or ribbed part (map_kit.py) whose y is a coordinate,
## never read as a kind.
func test_every_prop_with_kinds_has_whole_kinds_only() -> void:
	var seen := 0
	var with_kinds := 0
	for f in DirAccess.get_files_at(PROPS):
		if not f.ends_with(".glb"):
			continue
		var mesh := PropDressConfig.load_mesh(PROPS + f)
		if mesh == null:
			continue
		seen += 1
		if _uv_y_range(mesh).y < KIND_BASE - 0.5:
			continue
		with_kinds += 1
		var bad := 0
		for s in mesh.get_surface_count():
			for uv: Vector2 in (mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV] as PackedVector2Array):
				if absf(uv.x) > 0.0001:
					assert_true(uv.y < KIND_BASE - 0.5, "%s: a perforated or ribbed vertex read as a kind" % f)
					continue
				var plain := absf(uv.y) < 0.0001
				var whole := absf(uv.y - roundf(uv.y)) < 0.01 and uv.y > KIND_BASE - 0.5 and uv.y < KIND_BASE + 9.5
				if not (plain or whole):
					bad += 1
		assert_eq(bad, 0, "%s: every vertex plain or a whole kind 0..9" % f)
	assert_gt(seen, 20, "props were checked")
	assert_gt(with_kinds, 10, "the station props carry kinds (SQ1)")


func test_the_look_loads_with_the_screens_and_lists_their_path() -> void:
	var look := play.station_look.trains
	assert_true(look.screens in look.paths())
	assert_true(look.loads())
	var broken := TrainLook.new()
	broken.screens = "res://assets/models/props/none.glb"
	assert_false(broken.loads(), "a missing screens model leaves the boxes")


func test_every_car_gets_one_screens_instance_in_clear_glass_with_no_shadow() -> void:
	var m := _subway()
	var look := play.station_look.trains
	var view := TrainView.build(m, look)
	assert_not_null(view)
	add_child_autofree(view)
	var cars := 0
	for t in m.trains:
		cars += t.cars.size()
	assert_eq(view.count(look.screens), cars)
	var v := view.view_of(look.screens)
	assert_not_null(v)
	assert_eq(v.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	# the windows' clear glass, a little more opaque (attempt 3: the critic found the screens invisible at 0.3)
	var glass := v.material_override as ShaderMaterial
	var windows := view.view_of(look.windows).material_override as ShaderMaterial
	assert_not_null(glass)
	assert_eq(glass.shader, windows.shader, "the windows' clear shader")
	assert_almost_eq(float(glass.get_shader_parameter(&"opacity")), look.screen_opacity, 0.001)
	assert_gt(look.screen_opacity, look.glass_opacity, "the screens read as panes")
	assert_true(view.materials().has(glass), "warmed before play")
	assert_ne(v.material_override, view.view_of(look.body).material_override)


func test_each_screens_instance_lies_inside_its_trains_box() -> void:
	var m := _subway()
	var look := play.station_look.trains
	var view := TrainView.build(m, look)
	add_child_autofree(view)
	var aabb := look.mesh(look.screens).get_aabb()
	var placed := view.placed_of(look.screens)
	assert_gt(placed.size(), 0)
	for tr: Transform3D in placed:
		var box_ok := false
		for t in m.trains:
			var box: AABB = t.box.grow(0.05)
			if box.encloses(tr * aabb):
				box_ok = true
		assert_true(box_ok, "screens at %s inside a box" % tr.origin)


func test_the_seat_cushions_are_the_props_alone_not_the_trains() -> void:
	var look := play.station_look.trains
	for p in look.paths():
		assert_false(p.get_file().begins_with("train_seat"), "%s is drawn by PropDress, not TrainView" % p)


func test_the_vertex_shader_compiles_with_the_surface_kinds() -> void:
	var sh := load("res://game/play/look/look_vertex.gdshader") as Shader
	assert_not_null(sh)
	# The body is in look_vertex.gdshaderinc since WQ1 (shared with look_surface.gdshader).
	var body := FileAccess.get_file_as_string("res://game/play/look/look_vertex.gdshaderinc")
	assert_true(sh.code.contains("look_vertex.gdshaderinc"), "the body is included")
	assert_true(body.contains("look_surface("), "the kinds are applied")
	var mat := LookMaterials.vertex_colour(0.8, 0.0, Color.WHITE, false, play.station_look.trains.wear)
	assert_not_null(mat)
	assert_eq(mat.shader.get_mode(), Shader.MODE_SPATIAL)

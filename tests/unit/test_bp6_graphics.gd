extends GutTest
## BP6, the known-issues pass's graphics: the figures' detail lines scaled by the eye's zoom (a scope raised), and the
## shadow twin hidden while no light casts shadows; each level's opaque parts drawn as one merged mesh (BodyMerge), its
## bytes and mesh LODs exactly the parts'.

var config: FigureConfig = FigureConfig.new()
var view: ViewConfig = ViewConfig.new()
var models: FigureModels = null


func before_all() -> void:
	models = FigureModels.new(config)
	models.load_kinds()


func _scope(zoom: float, to: float) -> ReplicaConfig:
	var r := ReplicaConfig.new()
	r.aim_zoom = zoom
	r.aim_zoom_to = to
	r.zoom_in_glass = true
	return r


func test_the_lines_scale_with_the_zoom_and_never_shrink() -> void:
	var high := GraphicsQuality.MeshDetail.HIGH
	assert_eq(config.zoomed_lines(high, 1.0), config.lod_high)
	assert_eq(config.zoomed_lines(high, 6.0), config.lod_high * 6.0, "a figure 6x farther looks as big")
	assert_eq(config.zoomed_lines(GraphicsQuality.MeshDetail.LOW, 4.0), config.lod_low * 4.0)
	assert_eq(config.zoomed_lines(high, 0.5), config.lod_high, "no zoom below 1")


func test_the_view_zooms_as_raised_and_a_scopes_glass_as_turned() -> void:
	assert_almost_eq(FirstPersonView.aimed_zoom(null, view), view.aim_zoom, 1e-6, "iron sights: the view")
	assert_eq(FirstPersonView.glass_zoom_of(null, 0.0), 0.0, "no glass")
	var dot := ReplicaConfig.new()
	dot.aim_zoom = 1.5
	assert_eq(FirstPersonView.glass_zoom_of(dot, 1.5), 0.0, "an optic that zooms the view has no zooming glass")
	assert_almost_eq(FirstPersonView.glass_zoom_of(_scope(2.0, 6.0), 6.0), 6.0, 1e-6, "the Variable Scope at 6x")
	assert_almost_eq(FirstPersonView.glass_zoom_of(_scope(2.0, 6.0), 2.0), 2.0, 1e-6, "turned to 2x")
	assert_almost_eq(FirstPersonView.glass_zoom_of(_scope(4.0, 0.0), 0.0), 4.0, 1e-6, "a fixed scope")


func test_the_glass_cone_holds_what_the_glass_shows_and_not_the_view_round_it() -> void:
	var corner := FigureView.corner_of(view.vertical_fov(6.0), 16.0 / 9.0)
	var eye := Transform3D.IDENTITY
	assert_true(FigureView.in_cone(eye, corner, Vector3(0.0, 0.0, -40.0), 1.1), "straight down the scope")
	assert_true(FigureView.in_cone(eye, corner, Vector3(2.0, 0.0, -40.0), 1.1), "inside the glass's edge")
	assert_false(FigureView.in_cone(eye, corner, Vector3(15.0, 0.0, -40.0), 1.1), "out at the view's side")
	var wide := FigureView.corner_of(view.vertical_fov(1.0), 16.0 / 9.0)
	assert_lt(corner.y, wide.y, "narrower than the unzoomed view")


func test_a_figure_40_m_off_through_6x_draws_its_nearest_level_and_its_radio() -> void:
	var b := FigureBody.new()
	assert_true(b.setup(models, FigureMix.HUMAN, 0, 0, Color.RED, 0.0,
			config.zoomed_lines(GraphicsQuality.MeshDetail.HIGH, 6.0)))
	add_child_autofree(b)
	var radio := b.skeleton.get_node(^"Kit_Radio_LOD1") as MeshInstance3D
	assert_eq(radio.visibility_range_end, 0.0, "the radio drawn at 40 m (and every distance past its line)")
	for i in b.meshes.size():
		if b.levels[i] == 0:
			assert_gt(b.meshes[i].visibility_range_end, 40.0, "%s drawn at 40 m, as at 6.7 m unzoomed" % b.meshes[i].name)


func test_the_shadow_twin_hides_while_nothing_casts_shadows_and_a_new_body_keeps_it() -> void:
	var c := Character.new(1, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.BLUE, HitConfig.new(), GameTheme.font(800), false, [], 0.0, config)
	v.set_body(models, FigureMix.HUMAN, config.lod_high)
	var twin := v.body().meshes[-1]
	assert_eq(v.body().levels[-1], -1, "the twin is last")
	assert_true(twin.visible)
	v.set_shadow_cast(false)
	assert_false(twin.visible, "hidden on Low")
	v.set_body(models, FigureMix.ROBOT, config.lod_high)
	assert_false(v.body().meshes[-1].visible, "a new body (a rematch's kind) keeps it hidden")
	v.set_shadow_cast(true)
	assert_true(v.body().meshes[-1].visible)
	assert_false(v.body().merged.is_empty())
	for mi in v.body().merged:
		assert_true(mi.visible, "the levels are untouched")
	await get_tree().process_frame


func test_only_the_sun_casts_shadows() -> void:
	var q := GraphicsQuality.new()
	q.sun_shadows = false
	assert_false(GraphicsApply.any_shadows(q))
	assert_ne(GraphicsApply.torch_mode(q, LightingConfig.new(), true), TorchBeams.Mode.SHADOWED, "nor the torch then")
	q.sun_shadows = true
	assert_true(GraphicsApply.any_shadows(q))


## Godot's pick of a surface's mesh LOD at `x` (edge length over distance, as the threshold scales it): the last one at
## or under it, else the full indices (RenderingServer mesh_surface_get_lod).
static func _pick(surface: Dictionary, x: float) -> PackedByteArray:
	var out := surface["index_data"] as PackedByteArray
	for lod: Dictionary in surface.get("lods", []) as Array:
		if (lod["edge_length"] as float) > x:
			break
		out = lod["index_data"] as PackedByteArray
	return out


## The vertex arrays compared (positions, normals, tangents, colours, UVs, bones, weights), and the indices.
const ARRAYS: Array[int] = [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR,
		Mesh.ARRAY_TEX_UV, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_INDEX]


## `more`'s arrays after `into`'s, its indices shifted past `into`'s vertices.
static func _append(into: Array, more: Array) -> void:
	var base := (into[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() if into[Mesh.ARRAY_VERTEX] != null else 0
	for a: int in ARRAYS:
		if more[a] == null:
			continue
		var add: Variant = more[a]
		if a == Mesh.ARRAY_INDEX:
			var shifted := (more[a] as PackedInt32Array).duplicate()
			for i in shifted.size():
				shifted[i] += base
			add = shifted
		if into[a] == null:
			into[a] = add
		else:
			into[a] = into[a] + add


static func _shift(indices: PackedByteArray, base: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(indices.size())
	for i in range(0, indices.size(), 2):
		out.encode_u16(i, indices.decode_u16(i) + base)
	return out


func test_each_merged_surface_is_its_parts_bytes_and_picks_their_lods_at_every_distance() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var b := FigureBody.new()
		assert_true(b.setup(models, kind, 2, 1, Color.BLUE, 0.0, config.lod_high))
		add_child_autofree(b)
		assert_eq(b.merged.size(), 3, "kind %d: a merged mesh a level" % kind)
		for m in b.merged.size():
			var level := b.merged_levels[m]
			var merged := b.merged[m].mesh as ArrayMesh
			var sources: Array[Mesh] = []
			for i in b.meshes.size():
				var at := b.levels[i]
				if at >= 0 and not b.meshes[i].visible and (at == level or (at < level and b.meshes[i].name == "Kit_Radio_LOD1")):
					sources.append(b.meshes[i].mesh)
			for s in merged.get_surface_count():
				var material := merged.surface_get_material(s)
				var got := RenderingServer.mesh_get_surface(merged.get_rid(), s)
				var parts: Array[Dictionary] = []
				var want := []
				want.resize(Mesh.ARRAY_MAX)
				for mesh in sources:
					for t in mesh.get_surface_count():
						if mesh.surface_get_material(t) == material:
							parts.append(RenderingServer.mesh_get_surface(mesh.get_rid(), t))
							_append(want, mesh.surface_get_arrays(t))
				var name := "kind %d level %d %s" % [kind, level, material.resource_name]
				assert_false(parts.is_empty(), "%s from its parts" % name)
				var arrays := merged.surface_get_arrays(s)
				for a: int in ARRAYS:
					assert_eq(arrays[a], want[a], "%s: array %d read back as the parts'" % [name, a])
				for x: float in [0.0, 0.001, 0.01, 0.03, 0.06, 0.1, 0.2, 0.5, 1.0, 5.0]:
					var picked := PackedByteArray()
					var base := 0
					for d in parts:
						picked.append_array(_shift(_pick(d, x), base))
						base += d["vertex_count"] as int
					assert_eq(_pick(got, x), picked, "%s: the LOD picked at %.3f" % [name, x])
		assert_eq(_draws(b, 5.0), 9 if kind == FigureMix.HUMAN else 7, "kind %d: draws near" % kind)
		assert_eq(_draws(b, 40.0), 9 if kind == FigureMix.HUMAN else 7, "kind %d: draws far" % kind)


## The surfaces drawn at `distance` (shadow twin aside).
static func _draws(b: FigureBody, distance: float) -> int:
	var n := 0
	var all: Array[MeshInstance3D] = b.meshes.duplicate()
	all.append_array(b.merged)
	for mi in all:
		var inside := distance >= mi.visibility_range_begin and (mi.visibility_range_end <= 0.0
				or distance < mi.visibility_range_end)
		if mi.visible and inside and mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			n += mi.mesh.get_surface_count()
	return n


func test_while_it_fades_the_parts_draw_in_place_of_the_merged_meshes() -> void:
	var b := FigureBody.new()
	assert_true(b.setup(models, FigureMix.HUMAN, 0, 0, Color.RED, 0.0, config.lod_high))
	add_child_autofree(b)
	var folded := b.skeleton.get_node(^"Kit_Pack") as MeshInstance3D
	assert_false(folded.visible, "solid: the pack is in the merged mesh")
	assert_true(b.merged[0].visible)
	assert_true((b.skeleton.get_node(NodePath(String(b.head))) as MeshInstance3D).visible, "the head (its lens see-through) draws itself")
	b.set_fade(0.5)
	assert_true(folded.visible, "fading: each part sorted by its own depth again")
	assert_false(b.merged[0].visible)
	assert_almost_eq(folded.transparency, 0.5, 1e-6)
	b.set_fade(1.0)
	assert_false(folded.visible)
	assert_true(b.merged[0].visible)
	assert_eq(b.merged[0].transparency, 0.0)


func test_the_merged_paint_is_the_parts_paint() -> void:
	var b := FigureBody.new()
	assert_true(b.setup(models, FigureMix.ROBOT, 3, 1, Color.BLUE, 0.4, config.lod_high))
	add_child_autofree(b)
	var body := b.skeleton.get_node(^"Body") as MeshInstance3D
	var merged := b.merged[0]
	for s in body.mesh.get_surface_count():
		var material := body.mesh.surface_get_material(s)
		for t in merged.mesh.get_surface_count():
			if merged.mesh.surface_get_material(t) == material:
				assert_eq(merged.get_active_material(t), body.get_active_material(s), material.resource_name)


func test_an_open_leaf_stops_short_of_a_wall_across_its_fold_and_every_other_folds_flat() -> void:
	var play := PlayTuning.load_default()
	var sim := SimTuning.load_default()
	for id: String in ["depot", "woodland", "street"]:
		var map := MapData.load_map(id, play.map_style, sim.rounds.team_size)
		var view := DoorView.build(map, play.map_style, sim.doors.swing_time)
		if view == null:
			continue
		add_child_autofree(view)
		var doors := DoorState.new()
		doors.shut.resize(map.doors.size())
		doors.swing_left.resize(map.doors.size())
		view.refresh(doors)
		var reach: PackedFloat64Array = view.get("_reach")
		for j in map.doors.size() * 2:
			var stopped := id == "depot" and (j == 10 or j == 16)
			if stopped:
				assert_between(reach[j], PI * 0.8, PI - 0.01, "depot door %d's leaf 0 stops short of the wall across it" % (j / 2))
			else:
				assert_eq(reach[j], PI, "%s door %d leaf %d folds flat" % [id, j / 2, j % 2])
			var leaf := view.leaf_at(j)
			for b in map.blocks:
				if b.kind == &"floor" or b.kind == &"ramp":
					continue
				var inside := AABB(b.center - b.size * 0.5, b.size).grow(-0.003)
				for t in 11:
					for s: float in [-0.5, 0.5]:
						var p := leaf * (Vector3(t / 10.0 - 0.5, 0.0, s) if absf(leaf.basis.x.x) + absf(leaf.basis.x.z)
								> absf(leaf.basis.z.x) + absf(leaf.basis.z.z) else Vector3(s, 0.0, t / 10.0 - 0.5))
						assert_false(inside.has_point(p), "%s door %d leaf %d: no part in a %s" % [id, j / 2, j % 2, b.kind])


func test_only_parts_on_the_bodys_skin_fold_and_heads_that_dont_fold_share_one_merged_mesh() -> void:
	var a := FigureBody.new()
	assert_true(a.setup(models, FigureMix.HUMAN, 0, 0, Color.RED, 0.0, config.lod_high))
	add_child_autofree(a)
	var b := FigureBody.new()
	assert_true(b.setup(models, FigureMix.HUMAN, 1, 0, Color.RED, 0.0, config.lod_high))
	add_child_autofree(b)
	assert_ne(a.head, b.head)
	for m in a.merged.size():
		assert_same(a.merged[m].mesh, b.merged[m].mesh, "level %d: one merged mesh for both heads" % a.merged_levels[m])
	for i in a.meshes.size():
		if a.levels[i] >= 0 and not a.meshes[i].visible:
			assert_eq(a.meshes[i].skin, a.merged[0].skin, "%s folded only on the body's skin" % a.meshes[i].name)
	# A part on a skin of its own keeps its own draw.
	var c := FigureBody.new()
	var pack: MeshInstance3D = null
	assert_true(c.setup(models, FigureMix.HUMAN, 2, 0, Color.RED, 0.0, config.lod_high))
	add_child_autofree(c)
	pack = c.skeleton.get_node(^"Kit_Pack") as MeshInstance3D
	pack.skin = pack.skin.duplicate() as Skin
	for mi in c.merged:
		mi.free()
	c.merged.clear()
	c.merged_levels.clear()
	pack.visible = true
	c.call("_merge_levels", models, FigureMix.HUMAN, 0, Color.RED, 0.0, 0, c.merged[0].skin if not c.merged.is_empty()
			else (c.skeleton.get_node(^"Body") as MeshInstance3D).skin)
	assert_true(pack.visible, "the pack, on another skin, draws itself")


func test_through_the_glass_only_the_figures_it_shows_take_its_lines() -> void:
	var figures: Array[FigureView] = []
	for x: float in [0.0, 15.0]:
		var c := Character.new(figures.size() + 1, 1, Vector3(x, 0.0, -40.0), 0.0, ReplicaStats.default_loadout())
		var v := FigureView.new()
		add_child_autofree(v)
		v.setup(c, Color.BLUE, HitConfig.new(), GameTheme.font(800), false, [], 0.0, config)
		v.set_body(models, FigureMix.HUMAN, config.lod_high)
		v.update(c, 1.0)
		figures.append(v)
	var glass := config.zoomed_lines(GraphicsQuality.MeshDetail.HIGH, 6.0)
	var plain := config.zoomed_lines(GraphicsQuality.MeshDetail.HIGH, view.aim_zoom)
	var corner := FigureView.corner_of(view.vertical_fov(6.0), 16.0 / 9.0)
	FigureView.set_glass_lines(figures, Transform3D.IDENTITY, corner, glass, plain, config.glass_cone_radius)
	assert_eq(figures[0].lod_lines(), glass, "the figure in the glass: drawn as near as it looks")
	assert_eq(figures[1].lod_lines(), plain, "the one beside it, in the view round the glass: the view's lines")
	assert_eq(figures[0].body().merged[0].visibility_range_end, glass.x, "its body takes them")
	await get_tree().process_frame

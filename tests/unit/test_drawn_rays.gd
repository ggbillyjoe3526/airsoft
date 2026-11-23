extends GutTest
## DG1 (the owner's playtest of 0.1 Beta 2, 2026-11-23: "ricochet should only happen against surfaces, not empty
## spaces"). BBs and sight meet the props a map draws as they are drawn (DrawnRays): over the tool trolley's top tray in
## Subway's train a BB flies on where its block's box stopped it, and still meets the trolley's trays; a Woodland
## trunk stops a line where its bark is and nowhere else; a leaf card stops a line where its sheet is solid and lets it
## through where it is cut away; bodies and the level ray still meet the boxes; every prop the game draws stands for
## its block, and none it doesn't; the rays allocate nothing and the bodies go with the level.

## A line over the trolley's top tray (1.22 m drawn) and under its box's top (1.7 m), above its floor (m).
const OVER_TRAY := 1.45
## A line through its middle deck's drawers.
const THROUGH_DRAWERS := 0.85
## A stop this near (m) to the drawn face agrees with it.
const AGREE := 0.03
## Lines tested past each tree, and the trees.
const TREE_LINES := 8
const TREES := 40
## Points tested on leaf cards, solid and cut away, and how many of each must answer as the sheet says.
const CARD_POINTS := 40
const CARD_AGREE := 36

var play: PlayTuning = PlayTuning.load_default()
var _subway: MatchRunner = null
var _woodland: MatchRunner = null
var _hit := RayHit.new()


func before_all() -> void:
	_subway = MatchRunner.new(self, "subway")
	_woodland = MatchRunner.new(self, "woodland")


func after_all() -> void:
	for r: MatchRunner in [_subway, _woodland]:
		if r != null:
			r.free_level()


func _carts() -> Array[MapData.Block]:
	var out: Array[MapData.Block] = []
	for b in _subway.map.blocks:
		if b.dress == &"tool_cart":
			out.append(b)
	return out


func test_a_bb_over_the_train_s_tool_trolley_flies_on_where_its_box_stood() -> void:
	var q := _subway.level.query()
	assert_eq(_carts().size(), 2, "Subway's two tool trolleys")
	for b in _carts():
		var foot := b.center.y - b.size.y * 0.5
		var lo := b.center - b.size * 0.5
		var box := AABB(lo, b.size).grow(0.01)
		# along the trolley's length through its middle, clear of the pegboard at its back
		var y := foot + OVER_TRAY
		var a := Vector3(lo.x - 1.0, y, b.center.z)
		var c := Vector3(lo.x + b.size.x + 1.0, y, b.center.z)
		assert_false(q.bb_ray(a, c, _hit) and box.has_point(_hit.position),
				"a BB over %s's top tray flies on (it stopped on the box at %s)" % [b.center, _hit.position])
		assert_false(q.sight_ray(a, c, _hit) and box.has_point(_hit.position), "and the eye sees past")
		assert_true(q.ray(a, c, _hit) and box.has_point(_hit.position), "the level ray (bodies) still meets its box")
		assert_almost_eq(_hit.position.x, lo.x, AGREE, "at the box's face")
		var low := Vector3(a.x, foot + THROUGH_DRAWERS, a.z)
		assert_true(q.bb_ray(low, Vector3(c.x, low.y, c.z), _hit) and box.has_point(_hit.position),
				"a BB through %s's trays and drawers meets the trolley" % b.center)
		assert_eq(_hit.surface, b.surface, "made of its block's stuff")


func test_a_body_walking_into_the_trolley_still_meets_its_box() -> void:
	var b := _carts()[0]
	var mover := _subway.level.mover(_subway.tuning.body)
	var c := Character.new()
	var lo := b.center - b.size * 0.5
	c.position = Vector3(lo.x - 1.0, lo.y + 0.01, b.center.z)
	c.grounded = true
	var moved := mover.move(c, Vector3(2.0, 0.0, 0.0))
	assert_almost_eq(c.position.x + moved.x, lo.x - _subway.tuning.body.radius, 0.05,
			"a body stops at the trolley's box, its radius off")


func test_a_woodland_trunk_stops_a_line_where_its_bark_is_drawn_and_nowhere_else() -> void:
	var m := _woodland.map
	var props := PropDressConfig.new()
	var placed := _placed(m, props)
	var q := _woodland.level.query()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lines := 0
	var wrong: Array[String] = []
	for model: StringName in [&"pine_young", &"pine_grown", &"pine_old", &"birch"]:
		var faces := props.drawn_mesh_of(model).get_faces()
		var p: PropLayout.Placed = placed[model]
		for n in mini(TREES / 4, p.transforms.size()):
			var xf := p.transforms[n * p.transforms.size() / mini(TREES / 4, p.transforms.size())]
			var trunk := xf * props.drawn_mesh_of(model).get_aabb()
			var ground := m.terrain.height_clamped(xf.origin.x, xf.origin.z)
			for k in TREE_LINES:
				# a level line at a body's height past the trunk, as near its axis as its foot's flare reaches
				var y := ground + rng.randf_range(0.4, 1.8)
				var yaw := rng.randf() * TAU
				var way := Vector3(cos(yaw), 0.0, sin(yaw))
				var side := Vector3(-way.z, 0.0, way.x) * rng.randf_range(-1.0, 1.0) * trunk.size.x * 0.5
				var mid := Vector3(xf.origin.x, y, xf.origin.z) + side
				var a := mid - way * 1.0
				var b := mid + way * 1.0
				var drawn := _first(faces, xf, a, b)
				var met := q.bb_ray(a, b, _hit)
				var game := a.distance_to(_hit.position) if met else INF
				lines += 1
				if absf(game - drawn) > AGREE and not (is_inf(game) and is_inf(drawn)):
					wrong.append("%s at %s: game %.2f m, drawn %.2f m" % [model, mid, game, drawn])
	assert_gt(lines, 100)
	assert_lt(wrong.size(), lines / 50, "a BB past a trunk meets its bark as drawn (%d of %d lines differ: %s)" % [
			wrong.size(), lines, wrong.slice(0, 3)])


func test_a_leaf_card_stops_a_line_where_its_sheet_is_solid_and_lets_it_through_where_cut_away() -> void:
	var m := _woodland.map
	var props := PropDressConfig.new()
	var placed := _placed(m, props)
	var sheet := (load(props.foliage_sheet) as Texture2D).get_image()
	if sheet.is_compressed():
		sheet.decompress()
	var q := _woodland.level.query()
	var cut := play.map_style.drawn_rays.leaf_alpha_cut
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var corners := PackedVector3Array()
	var uvs := PackedVector2Array()
	var mesh := props.drawn_mesh_of(&"spruce")
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i: int in arrays[Mesh.ARRAY_INDEX]:
			corners.append(verts[i])
			uvs.append(uv[i])
	var spruces: PropLayout.Placed = placed[&"spruce"]
	var agree := Vector2i.ZERO
	var tried := Vector2i.ZERO
	var guard := 0
	while (tried.x < CARD_POINTS or tried.y < CARD_POINTS) and guard < 20000:
		guard += 1
		var xf := spruces.transforms[rng.randi() % spruces.transforms.size()]
		var t := rng.randi() % (corners.size() / 3) * 3
		if uvs[t].x < LeafTrim.BARK_BELOW:
			continue
		var u := rng.randf()
		var v := rng.randf() * (1.0 - u)
		var local := corners[t] + (corners[t + 1] - corners[t]) * u + (corners[t + 2] - corners[t]) * v
		var uv := uvs[t] + (uvs[t + 1] - uvs[t]) * u + (uvs[t + 2] - uvs[t]) * v
		var solid := sheet.get_pixelv(Vector2i(clampi(int(uv.x * sheet.get_width()), 0, sheet.get_width() - 1),
				clampi(int(uv.y * sheet.get_height()), 0, sheet.get_height() - 1))).a >= cut
		var k := 0 if solid else 1
		if tried[k] >= CARD_POINTS:
			continue
		var at := xf * local
		var normal := (xf.basis * (corners[t + 1] - corners[t]).cross(corners[t + 2] - corners[t])).normalized()
		if not normal.is_finite() or normal.length_squared() < 0.5:
			continue
		tried[k] += 1
		# a short line square through the card at that point
		var met := q.bb_ray(at + normal * 0.01, at - normal * 0.01, _hit)
		var stopped_there := met and _hit.position.distance_to(at) < 0.005
		if stopped_there == solid:
			agree[k] += 1
	assert_eq(tried, Vector2i(CARD_POINTS, CARD_POINTS), "points on the spruces' cards, solid and cut away")
	assert_gte(agree.x, CARD_AGREE, "a line through a card where its sheet is solid stops there (%d of %d)" % [
			agree.x, CARD_POINTS])
	assert_gte(agree.y, CARD_AGREE, "and flies on where it is cut away (%d of %d)" % [agree.y, CARD_POINTS])
	assert_eq(_hit.surface if agree.x > 0 else RayHit.Surface.LEAVES, RayHit.Surface.LEAVES)


func test_every_prop_the_game_draws_stands_for_its_block_and_no_other() -> void:
	for runner: MatchRunner in [_subway, _woodland]:
		var m := runner.map
		var game := play.site_look.props
		if m.station != null:
			game = game.named_only()
		var dress := PropDress.build(m, game)
		var drawn := 0
		var stands := PackedByteArray()
		stands.resize(m.blocks.size())
		for model: StringName in dress.placed():
			var p := dress.placed()[model]
			for i in p.transforms.size():
				var b := m.blocks[p.blocks[i]]
				if game.lay_of(b) != PropDressConfig.Lay.TILE and game.core_of(b) == Vector2.ZERO:
					drawn += 1
					stands[p.blocks[i]] = 1
		dress.free()
		var rays: DrawnRays = runner.level.drawn_rays()
		assert_eq(rays.prop_count(), drawn, "%s: every prop the game draws stands on the rays' bodies" % m.id)
		var differ := 0
		for i in m.blocks.size():
			var set_block := game.lay_of(m.blocks[i]) == PropDressConfig.Lay.SET
			if rays.draws(i) != (stands[i] == 1) and not set_block:
				differ += 1
		assert_eq(differ, 0, "%s: a block's box leaves the rays where its props are drawn, and only there" % m.id)


func test_rays_through_the_woods_allocate_nothing_once_warm() -> void:
	var q := _woodland.level.query()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var from := PackedVector3Array()
	var to := PackedVector3Array()
	for i in 200:
		var a := Vector3(rng.randf_range(-60.0, 60.0), 0.0, rng.randf_range(-60.0, 60.0))
		a.y = _woodland.map.terrain.height_clamped(a.x, a.z) + 1.6
		from.append(a)
		to.append(a + Vector3(rng.randf_range(-40.0, 40.0), rng.randf_range(-2.0, 2.0), rng.randf_range(-40.0, 40.0)))
	for i in 200:
		q.sight_ray(from[i], to[i], _hit)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var leaves := 0
	for i in 200:
		q.bb_ray(from[i], to[i], _hit)
		if q.sight_ray(from[i], to[i], _hit) and _hit.surface == RayHit.Surface.LEAVES:
			leaves += 1
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before, "no object made")
	assert_gt(leaves, 10, "lines through the woods stop in leaves")


func test_the_bodies_go_with_the_rays() -> void:
	# in a world of their own, so only these rays' bodies are there to meet
	var view := SubViewport.new()
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(view)
	var cast := RayCast3D.new()
	cast.enabled = false
	cast.collision_mask = DrawnRays.DRAWN_LAYER
	view.add_child(cast)
	var rays := DrawnRays.build(_subway.map, PropDressConfig.new().named_only(), view.find_world_3d().space,
			DrawnRayConfig.new())
	assert_gt(rays.body_count(), 0)
	await wait_physics_frames(1)
	var b := _carts()[0]
	var low := b.center + Vector3(0.0, THROUGH_DRAWERS - b.size.y * 0.5, 0.0)
	cast.position = low - Vector3(b.size.x * 0.5 + 1.0, 0.0, 0.0)
	cast.target_position = Vector3(b.size.x + 2.0, 0.0, 0.0)
	cast.force_raycast_update()
	assert_true(cast.is_colliding(), "control: the trolley's faces are met")
	rays.free_bodies()
	assert_eq(rays.body_count(), 0, "freed")
	await wait_physics_frames(1)
	cast.force_raycast_update()
	assert_false(cast.is_colliding(), "and gone from the space")


## Each model's props as the built-in look lays them on `m`.
func _placed(m: MapData, props: PropDressConfig) -> Dictionary[StringName, PropLayout.Placed]:
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in PropDress.models_used(m, props):
		if props.mesh_of(model) != null:
			boxes[model] = props.mesh_of(model).get_aabb()
	return PropLayout.layout(m, props, boxes)


## How far along the line from `a` to `b` it first meets `faces` placed at `xf` (m), INF for never.
static func _first(faces: PackedVector3Array, xf: Transform3D, a: Vector3, b: Vector3) -> float:
	var inv := xf.affine_inverse()
	var la := inv * a
	var lb := inv * b
	var best := INF
	for t in range(0, faces.size(), 3):
		var at: Variant = Geometry3D.segment_intersects_triangle(la, lb, faces[t], faces[t + 1], faces[t + 2])
		if at != null:
			best = minf(best, a.distance_to(xf * (at as Vector3)))
	return best

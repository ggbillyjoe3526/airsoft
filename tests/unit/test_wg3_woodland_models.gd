extends GutTest
## Woodland's structures as the game's own models (WG3, Dev 3): the palisade's stakes and rails laid along the fence
## blocks (PropDressConfig's STAKES lay), the watch tower, the North bridge and the Sawmill's shed each one model over
## its blocks (SET), and the huts' roofs fitted to theirs; every one inside its budget, built for the map as it is
## (tools/blender/maps/*.py read data/maps/woodland.json), and never reaching past what stops a BB.

## Each model's triangle budget (/mnt/project-files/art/woodland-model-list.md); the palisade's is a 4 m section's.
const BUDGETS := {&"watch_tower": 6000, &"footbridge": 3000, &"sawmill_shed": 5000, &"hut_roof": 1500,
		&"hut_roof_long": 1500}
const PALISADE_4M := 1000
const SETS: Array[StringName] = [&"watch_tower", &"footbridge", &"sawmill_shed"]
## How far (m) a model may stand off what it fills: rounding in the map file and the build.
const SLACK := 0.02
## Bands a structure's block is cut in to check its parts fill it all the way along.
const BANDS := 3
## The grid of lines tried through a structure's blocks for gaps (m apart, and in from the block's edges).
const GAP_STEP := 0.04
const GAP_INSET := 0.035
const GAP_SLAB := 0.2
const GAP_SHIFT := 0.0007
const GAP_HAIR := 0.0015
## How far (m) a face's back may lie in front of a face turned to the eye: parts touching, rounding in the build.
const GAP_TOUCH := 0.003

var look: SiteLook = null
var map: MapData = null
var boxes: Dictionary[StringName, AABB] = {}


func before_all() -> void:
	var play := PlayTuning.load_default()
	look = play.site_look
	map = MapData.load_map("woodland", play.map_style, SimTuning.new().rounds.team_size)
	for model: StringName in look.props.models:
		var mesh := look.props.mesh_of(model)
		if mesh != null:
			boxes[model] = mesh.get_aabb()


func _tris(model: StringName) -> int:
	var mesh := look.props.mesh_of(model)
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		n += (index.size() if not index.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func _inside(outer: AABB, inner: AABB, slack: float) -> bool:
	return outer.grow(slack).encloses(inner)


func _blocks(dress: StringName) -> Array[MapData.Block]:
	var out: Array[MapData.Block] = []
	for b in map.blocks:
		if b.dress == dress:
			out.append(b)
	return out


func _box(b: MapData.Block) -> AABB:
	return AABB(b.center - b.size * 0.5, b.size)


func test_every_model_loads_inside_its_budget() -> void:
	for model: StringName in BUDGETS:
		assert_true(boxes.has(model), "%s loads" % model)
		var t := _tris(model)
		assert_lte(t, BUDGETS[model], "%s: %d triangles" % [model, t])
		assert_gt(t, BUDGETS[model] * 0.75, "%s uses its budget for detail (%d)" % [model, t])
	var stakes := roundi(4.0 / look.props.stake_pitch[&"palisade"])
	var section := _tris(&"palisade") * stakes + _tris(&"palisade_rail") * 2
	assert_lte(section, PALISADE_4M, "a 4 m palisade section: %d triangles" % section)


func test_the_map_names_each_structure_on_its_blocks() -> void:
	assert_eq(_blocks(&"watch_tower").size(), 12, "the tower's legs, platform, five walls, roof and stair")
	assert_eq(_blocks(&"footbridge").size(), 3, "the North bridge's deck and its two sides")
	assert_eq(_blocks(&"sawmill_shed").size(), 7, "the shed's six posts and its roof")
	assert_eq(_blocks(&"hut_roof").size() + _blocks(&"hut_roof_long").size(), 4, "the four huts' roofs")
	assert_eq(_blocks(&"palisade").size(), 108, "the boundary's and both camps' fence blocks")
	for b in _blocks(&"palisade"):
		assert_eq(b.kind, &"fence")
	var ramps := _blocks(&"watch_tower").filter(func(b: MapData.Block) -> bool: return b.rise != MapData.Rise.NONE)
	assert_eq(ramps.size(), 1, "the tower's stair is its ramp")
	assert_true(look.props.dresses(ramps[0]), "and the tower model draws it")


func test_each_structure_model_is_built_for_the_map_as_it_is() -> void:
	for model in SETS:
		var box := PropDressConfig.set_box(map, model)
		var built: AABB = boxes[model]
		assert_almost_eq(built.size, box.size, Vector3.ONE * SLACK,
				"%s was built for its blocks as they are (rerun tools/blender/maps/%s.py after build_map.py)"
				% [model, model])


func test_each_structure_is_laid_once_over_its_blocks() -> void:
	var placed := PropLayout.layout(map, look.props, boxes)
	for model in SETS:
		assert_true(placed.has(model), "%s laid" % model)
		assert_eq(placed[model].transforms.size(), 1, "%s once" % model)
		var drawn: AABB = placed[model].transforms[0] * boxes[model]
		var box := PropDressConfig.set_box(map, model)
		assert_almost_eq(drawn.position, box.position, Vector3.ONE * SLACK, "%s over its blocks" % model)
		assert_almost_eq(drawn.size, box.size, Vector3.ONE * SLACK)


## Each block of a structure is filled by the model's parts in it, to every face and all the way along: no post
## thinner than its block, no open stair over a solid ramp (a BB stopped on nothing the player sees). A block is cut
## in BANDS up its height (a ramp's: along its slope); each band's parts reach the block's sides (a ramp's: its foot).
## It checks the parts reach the faces, not that they cover them (a board at each face would pass): the pictures do that.
func test_each_block_of_a_structure_is_filled_to_its_faces() -> void:
	var placed := PropLayout.layout(map, look.props, boxes)
	var short: Array[String] = []
	for model in SETS:
		var t: Transform3D = placed[model].transforms[0]
		var mesh := look.props.mesh_of(model)
		var verts := PackedVector3Array()
		for s in mesh.get_surface_count():
			for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				verts.append(t * v)
		for b in _blocks(model):
			var box := _box(b)
			var ramp := b.rise != MapData.Rise.NONE
			var axis := 0 if ramp else 1
			var bands := BANDS if ramp or b.size.y >= 0.5 else 1
			for k in bands:
				var band := box.grow(0.01)
				band.position[axis] = box.position[axis] + box.size[axis] * k / bands - 0.01
				band.size[axis] = box.size[axis] / bands + 0.02
				var got := _extent(verts, band)
				if got.size == Vector3.ZERO:
					short.append("%s %s band %d: nothing" % [model, b.center, k])
					continue
				var sides: Array[int] = [1, 2]
				if not ramp:
					sides = [0, 2]
				for a in sides:
					var low := got.position[a] - box.position[a]
					var high := box.end[a] - got.end[a]
					if a == 1:
						high = 0.0  # a ramp's top is its slope, met by the treads
					if low > SLACK or high > SLACK:
						short.append("%s %s band %d: axis %d short by %.3f / %.3f" % [model, b.center, k, a, low,
								high])
	assert_eq(short, [] as Array[String], "each structure fills its blocks")


## The bounds of the points of `verts` inside `box` (an empty AABB when none).
func _extent(verts: PackedVector3Array, box: AABB) -> AABB:
	var got := AABB()
	var first := true
	for v in verts:
		if box.has_point(v):
			got = AABB(v, Vector3.ZERO) if first else got.expand(v)
			first = false
	return got


## Nothing is seen through a structure where its blocks stop sight, faces drawn one-sided as the game draws them: lines
## through each block every GAP_STEP m, GAP_INSET m in from its faces, along x, y and z and the six diagonals between
## them, each meet the model inside the block, and an eye at either end of the line, looking along it, meets a face turned
## to it before any face's back inside the block (a face's back is not drawn: seeing one is seeing into a hollow, and
## through it), unless that end comes in from under the ground, out of another of the structure's blocks or out of a
## part hugging the block (the last face before it is turned to the eye). A line counts
## open only if lines GAP_HAIR either side of it, both ways across it, are open too: a hairline where two round parts
## touch is not a gap. A ramp is tried along x, y and z under its slope; a slab thinner than GAP_SLAB (a roof, its slope
## its own) only up through it.
func test_nothing_is_seen_through_a_structure_s_blocks() -> void:
	var placed := PropLayout.layout(map, look.props, boxes)
	var gaps: Array[String] = []
	var dirs: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for d: Vector3 in [Vector3(1, 1, 0), Vector3(1, -1, 0), Vector3(0, 1, 1), Vector3(0, 1, -1), Vector3(1, 0, 1),
			Vector3(1, 0, -1)]:
		dirs.append(d.normalized())
	var hairs: Array[Vector2] = [Vector2(GAP_HAIR, 0), Vector2(-GAP_HAIR, 0), Vector2(0, GAP_HAIR), Vector2(0, -GAP_HAIR)]
	for model in SETS:
		var t: Transform3D = placed[model].transforms[0]
		var tris := PackedVector3Array()
		var normals := PackedVector3Array()
		_triangles(look.props.mesh_of(model), t, tris, normals)
		var set_blocks := _blocks(model)
		for b in set_blocks:
			for k in dirs.size():
				var d := dirs[k]
				if b.size.y < GAP_SLAB and d != Vector3.UP:
					continue
				if b.rise != MapData.Rise.NONE and k >= 3:
					continue
				var where := PackedVector3Array()
				var open := _open_lines(tris, normals, b, d, set_blocks, Vector2.ZERO, where)
				if not open.has(1):
					continue
				for hair in hairs:
					var next := _open_lines(tris, normals, b, d, set_blocks, hair, PackedVector3Array())
					for i in open.size():
						open[i] = open[i] & next[i]
				var count := open.count(1)
				if count > 0:
					gaps.append("%s %s: %d lines along %s, one through %s" % [model, b.center, count, d,
							where[open.find(1)]])
	assert_eq(gaps, [] as Array[String], "no gaps through the structures")


## The model's triangles (three points each, placed by `t`) into `tris`, and each one's outward normal into `normals`.
func _triangles(mesh: Mesh, t: Transform3D, tris: PackedVector3Array, normals: PackedVector3Array) -> void:
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var v := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var n := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var count := index.size() if not index.is_empty() else v.size()
		for k in range(0, count, 3):
			var sum := Vector3.ZERO
			for j in 3:
				var i := index[k + j] if not index.is_empty() else k + j
				tris.append(t * v[i])
				sum += n[i]
			# the face's own normal, turned the way its smoothed one is: a face met nearly edge on keeps its side
			var m := tris.size()
			var flat := (tris[m - 2] - tris[m - 3]).cross(tris[m - 1] - tris[m - 3]).normalized()
			var smooth := t.basis * sum
			normals.append(flat if flat.dot(smooth) >= 0.0 else -flat)


## Which lines along `d` through block `b` (a grid GAP_STEP apart across `d`, moved `shift`, each crossing the block
## GAP_INSET in from its faces) are open: they meet nothing inside it, or an eye at an end that can be seen meets a face's
## back inside it before any face turned to it. Each line's middle goes into `where`.
func _open_lines(tris: PackedVector3Array, normals: PackedVector3Array, b: MapData.Block, d: Vector3,
		set_blocks: Array[MapData.Block], shift: Vector2, where: PackedVector3Array) -> PackedByteArray:
	var box := _box(b)
	var inner := box.grow(-GAP_INSET)
	var u := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := d.cross(u)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in 8:
		var corner := inner.get_endpoint(c)
		lo = lo.min(Vector2(corner.dot(u), corner.dot(w)))
		hi = hi.max(Vector2(corner.dot(u), corner.dot(w)))
	var nu := floori((hi.x - lo.x) / GAP_STEP) + 1
	var nw := floori((hi.y - lo.y) / GAP_STEP) + 1
	lo += Vector2(GAP_SHIFT, GAP_SHIFT) + shift  # off the round numbers the models' planes sit on
	# along each line, for an eye at the low end: the nearest face inside the block turned to it, the nearest face's
	# back inside it, and the last face before the block and whether it is turned to the eye (then the line comes into
	# the block out of a part hugging it, not out of the open); the same for an eye at the high end
	var low_prev := PackedFloat32Array()
	var high_prev := PackedFloat32Array()
	var low_prev_front := PackedByteArray()
	var high_prev_front := PackedByteArray()
	var low_front := PackedFloat32Array()
	var low_back := PackedFloat32Array()
	var high_front := PackedFloat32Array()
	var high_back := PackedFloat32Array()
	var inside := PackedByteArray()
	for arr: PackedFloat32Array in [low_front, low_back, high_front, high_back, low_prev, high_prev]:
		arr.resize(nu * nw)
	for arr: PackedByteArray in [inside, low_prev_front, high_prev_front]:
		arr.resize(nu * nw)
	low_prev.fill(-INF)
	high_prev.fill(INF)
	low_front.fill(INF)
	low_back.fill(INF)
	high_front.fill(-INF)
	high_back.fill(-INF)
	var lines: Array[Vector2] = []  # each line's span inside the block, GAP_INSET in (its entry and exit along d)
	var wholes: Array[Vector2] = []  # and inside the whole block
	for i in nu * nw:
		var p := u * (lo.x + (i / nw) * GAP_STEP) + w * (lo.y + (i % nw) * GAP_STEP)
		lines.append(_span(inner, p, d))
		wholes.append(_span(box, p, d))
	var near := box.grow(0.005)
	for k in range(0, tris.size(), 3):
		var a := Vector3(tris[k].dot(u), tris[k].dot(w), tris[k].dot(d))
		var c := Vector3(tris[k + 1].dot(u), tris[k + 1].dot(w), tris[k + 1].dot(d))
		var e := Vector3(tris[k + 2].dot(u), tris[k + 2].dot(w), tris[k + 2].dot(d))
		var den := (c.y - e.y) * (a.x - e.x) + (e.x - c.x) * (a.y - e.y)
		if absf(den) < 1e-9:
			continue
		var facing := normals[k / 3].dot(d)
		var iu0 := maxi(0, ceili((minf(a.x, minf(c.x, e.x)) - lo.x) / GAP_STEP))
		var iu1 := mini(nu - 1, floori((maxf(a.x, maxf(c.x, e.x)) - lo.x) / GAP_STEP))
		var iw0 := maxi(0, ceili((minf(a.y, minf(c.y, e.y)) - lo.y) / GAP_STEP))
		var iw1 := mini(nw - 1, floori((maxf(a.y, maxf(c.y, e.y)) - lo.y) / GAP_STEP))
		for iu in range(iu0, iu1 + 1):
			var pu := lo.x + iu * GAP_STEP
			for iw in range(iw0, iw1 + 1):
				var i := iu * nw + iw
				if lines[i].x >= lines[i].y:
					continue
				var pw := lo.y + iw * GAP_STEP
				var l1 := ((c.y - e.y) * (pu - e.x) + (e.x - c.x) * (pw - e.y)) / den
				var l2 := ((e.y - a.y) * (pu - e.x) + (a.x - e.x) * (pw - e.y)) / den
				var l3 := 1.0 - l1 - l2
				if l1 < -1e-6 or l2 < -1e-6 or l3 < -1e-6:
					continue
				var at := l1 * a.z + l2 * c.z + l3 * e.z
				var hit := u * pu + w * pw + d * at
				var in_block := near.has_point(hit)
				if in_block and b.rise != MapData.Rise.NONE and hit.y > _surface(b, box, hit) + GAP_TOUCH:
					continue  # over a ramp's slope: a stair's rail, say, which the ramp doesn't stop
				if not in_block:
					if at < wholes[i].x and at > low_prev[i]:
						low_prev[i] = at
						low_prev_front[i] = 1 if facing < 0.0 else 0
					elif at > wholes[i].y and at < high_prev[i]:
						high_prev[i] = at
						high_prev_front[i] = 1 if facing > 0.0 else 0
					continue
				inside[i] = 1
				# a face's back on the block's own face is a neighbour's, touching it from outside
				var back_low := at > wholes[i].x + GAP_TOUCH
				var back_high := at < wholes[i].y - GAP_TOUCH
				if facing < 0.0:
					low_front[i] = minf(low_front[i], at)
					if back_high:
						high_back[i] = maxf(high_back[i], at)
				else:
					if back_low:
						low_back[i] = minf(low_back[i], at)
					high_front[i] = maxf(high_front[i], at)
	var open := PackedByteArray()
	open.resize(nu * nw)
	where.resize(nu * nw)
	for i in nu * nw:
		var span := lines[i]
		if span.x >= span.y:
			continue
		var p := u * (lo.x + (i / nw) * GAP_STEP) + w * (lo.y + (i % nw) * GAP_STEP)
		where[i] = p + d * (span.x + span.y) * 0.5
		if b.rise != MapData.Rise.NONE and not _under_slope(b, box, where[i], d):
			continue
		if b.rise != MapData.Rise.NONE and d == Vector3.UP and _surface(b, box, where[i]) - GAP_INSET <= span.x:
			continue  # the ramp's foot: no room under the slope
		# an end of the line that comes in from under the ground or out of another of the structure's blocks is hidden
		var whole := wholes[i]
		var low_ok := (low_prev_front[i] == 1 or _hidden(p + d * whole.x, set_blocks, b)
				or low_front[i] <= low_back[i] + GAP_TOUCH)
		var high_ok := (high_prev_front[i] == 1 or _hidden(p + d * whole.y, set_blocks, b)
				or high_front[i] >= high_back[i] - GAP_TOUCH)
		if not (inside[i] == 1 and low_ok and high_ok):
			open[i] = 1
	return open


## Whether point `at`, where a line comes into block `b`, can't be seen from outside: under the ground, or in another of
## the structure's blocks.
func _hidden(at: Vector3, set_blocks: Array[MapData.Block], b: MapData.Block) -> bool:
	if map.terrain != null and at.y < map.terrain.height_clamped(at.x, at.z) + 0.02:
		return true
	for o in set_blocks:
		if o != b and _box(o).grow(0.01).has_point(at):
			return true
	return false


## The span (entry, exit along `d`) of the line through `p` along `d` inside `box`; entry >= exit when it misses.
func _span(box: AABB, p: Vector3, d: Vector3) -> Vector2:
	var t0 := -INF
	var t1 := INF
	for axis in 3:
		if absf(d[axis]) < 1e-9:
			if p[axis] < box.position[axis] or p[axis] > box.end[axis]:
				return Vector2(1.0, 0.0)
			continue
		var ta := (box.position[axis] - p[axis]) / d[axis]
		var tb := (box.end[axis] - p[axis]) / d[axis]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	return Vector2(t0, t1)


## Whether point `p` (on a line along `d`) is under ramp `b`'s slope, GAP_INSET under it (along y: anywhere over it).
func _under_slope(b: MapData.Block, box: AABB, p: Vector3, d: Vector3) -> bool:
	if d == Vector3.UP:
		return true
	var along := 0 if b.rise == MapData.Rise.POS_X or b.rise == MapData.Rise.NEG_X else 2
	var surface := _surface(b, box, p)
	if absf(d[along]) > 0.5:
		return p.y < box.end.y - GAP_INSET and p.y < surface - GAP_INSET
	return p.y < surface - GAP_INSET


## The height of ramp `b`'s slope over point `p`.
func _surface(b: MapData.Block, box: AABB, p: Vector3) -> float:
	var along := 0 if b.rise == MapData.Rise.POS_X or b.rise == MapData.Rise.NEG_X else 2
	var rising := b.rise == MapData.Rise.POS_X or b.rise == MapData.Rise.POS_Z
	var f := clampf((p[along] - box.position[along]) / box.size[along], 0.0, 1.0)
	return box.position.y + box.size.y * (f if rising else 1.0 - f)


func test_a_window_s_thin_lintel_or_sill_is_a_plywood_header() -> void:
	var cfg := look.props
	var thin := 0
	for b in map.blocks:
		if b.kind == &"plywood" and b.size.y < 0.3 and minf(b.size.x, b.size.z) <= 0.5:
			thin += 1
			assert_eq(b.dress, &"plywood_header", "the plywood board at %s is a header" % b.center)
			assert_true(cfg.dresses(b), "and drawn")
	assert_gt(thin, 0, "the Fort's north window has a thin lintel")
	var module := boxes[&"plywood_header"]
	assert_almost_eq(module.position.y, 0.0, 1e-3, "the header's foot is at its block's foot")
	assert_almost_eq(module.end.y, 0.2, 1e-3, "and it is built at the lintel's 0.2 m")
	var placed := PropLayout.layout(map, cfg, boxes)
	assert_true(placed.has(&"plywood_header"), "the game lays the header's modules")


func test_the_roofs_fill_their_blocks() -> void:
	var placed := PropLayout.layout(map, look.props, boxes)
	for model: StringName in [&"hut_roof", &"hut_roof_long"]:
		var roofs := _blocks(model)
		assert_eq(placed[model].transforms.size(), roofs.size(), "%s: one a roof" % model)
		for t: Transform3D in placed[model].transforms:
			var drawn: AABB = t * boxes[model]
			var hit := roofs.filter(func(b: MapData.Block) -> bool:
				return _box(b).grow(SLACK).encloses(drawn) and drawn.grow(SLACK).encloses(_box(b)))
			assert_eq(hit.size(), 1, "%s fills one roof block exactly (%s)" % [model, drawn])


func test_the_palisade_stands_inside_its_blocks_with_no_gap_between_stakes() -> void:
	var fences := _blocks(&"palisade")
	var placed := PropLayout.layout(map, look.props, boxes)
	var stakes: Array[AABB] = []
	for t: Transform3D in placed[&"palisade"].transforms:
		stakes.append(t * boxes[&"palisade"])
	var rails: Array[AABB] = []
	for t: Transform3D in placed[&"palisade_rail"].transforms:
		rails.append(t * boxes[&"palisade_rail"])
	var outside: Array[String] = []
	var gaps: Array[String] = []
	var rails_seen := 0
	for b in fences:
		var box := _box(b)
		var along := 0 if b.size.x >= b.size.z else 2
		var mine: Array[AABB] = []
		for s in stakes:
			if box.grow(0.001).has_point(s.get_center()):
				mine.append(s)
				if not _inside(box, s, 0.005):
					outside.append("stake at %s past %s" % [s.get_center(), b.center])
		mine.sort_custom(func(a: AABB, c: AABB) -> bool: return a.position[along] < c.position[along])
		var reach := box.position[along]
		for s in mine:
			if s.position[along] > reach + 0.002:
				gaps.append("%s at %.2f" % [b.center, reach])
			reach = maxf(reach, s.end[along])
		if reach < box.end[along] - 0.002:
			gaps.append("%s short of its end" % b.center)
		for r in rails:
			if box.grow(0.001).has_point(r.get_center()):
				rails_seen += 1
				if not _inside(box, r, 0.005):
					outside.append("rail at %s past %s" % [r.get_center(), b.center])
	assert_eq(outside, [] as Array[String], "the stakes and rails stay in their blocks")
	assert_eq(gaps, [] as Array[String], "nothing seen between the stakes of a block that stops sight")
	assert_gte(rails_seen, fences.size() * 2 - 4, "two rails a block (a block too low for one keeps it out)")


func test_a_ramp_named_by_no_structure_keeps_its_box() -> void:
	var ramp := MapData.Block.new()
	ramp.kind = &"ramp"
	ramp.rise = MapData.Rise.NEG_X
	ramp.size = Vector3(4.0, 2.0, 1.2)
	assert_false(look.props.dresses(ramp), "a plain ramp")
	ramp.dress = &"palisade"
	assert_false(look.props.dresses(ramp), "a ramp naming a prop that isn't a structure's")


func test_the_props_are_seeded() -> void:
	var a := PropLayout.layout(map, look.props, boxes)
	var b := PropLayout.layout(map, look.props, boxes)
	for model: StringName in [&"palisade", &"palisade_rail", &"watch_tower"]:
		assert_eq(a[model].transforms, b[model].transforms, "%s the same both times" % model)


func test_the_game_draws_the_stakes_and_their_rails() -> void:
	var dress := PropDress.build(map, look.props)
	assert_not_null(dress, "Woodland is dressed")
	var placed := dress.placed()
	for model: StringName in [&"palisade", &"palisade_rail", &"watch_tower", &"footbridge", &"sawmill_shed",
			&"hut_roof", &"hut_roof_long"]:
		assert_true(placed.has(model) and placed[model].transforms.size() > 0, "%s drawn" % model)
	dress.free()

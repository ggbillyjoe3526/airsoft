extends SceneTree
## BBs and sight against Woodland as drawn (WH1; dev only, never exported). Seeded lines from a standing eye 6 to 40 m
## off to points up a standing body (knee, hip, chest, head) on open ground, kept where they pass a plant: a thicket, a
## tree, a fern or a shrub. Each line is asked twice:
## - the game: does a BB stop on it (WorldQuery.bb_ray, or leaf_stop_depth of counted leaves) and does sight stop on it
##   (sight_ray, or foliage_see_through of leaves beyond BotConfig.close_awareness), and on what;
## - as drawn: does it meet an opaque face of the plants PropDress and BushView draw there (leaf cards cut out of their
##   sheet at the shaders' alpha_cut, read at full detail; bark always), or the ground.
## "Unseen" lines stop in the game where the drawn line is clear (a BB or a Spotted stopped at a body the player sees);
## "through" lines fly on in the game where the drawn plant hides the point. Counted by cause, and, for each body, how
## often Spotted (chest or head in sight) misses a body whose chest or head the player sees. Measured, never asserted.
##   godot --headless --path . -s res://tools/sight_truth.gd -- [area] [bodies] [lines a body]
## `area` is "hut" (the owner's circled stretch west of Hut row, Beta 2 playtest item 5), "all" (every plant), or
## "x0,z0,x1,z1" (a box, m).

const AREAS: Dictionary[String, Rect2] = {"hut": Rect2(10.0, -9.0, 15.0, 21.0)}
const SEED := 23
const BODIES := 120
const PER_BODY := 12
const NEAR := 6.0
const FAR := 40.0
const EYE := 1.6
## Up a standing body as shares of its hit top: knee, hip, chest (aim_height_fraction), head (head_height_fraction).
const PARTS: Array[float] = [0.28, 0.5, 0.7, 0.93]
const PART_NAMES: Array[String] = ["knee", "hip", "chest", "head"]
## A line counts as passing a plant within this many metres of its drawn bounds.
const NEAR_PLANT := 0.6
## A model's faces filed in a grid of this many cells a side of its bounds.
const GRID := 10
const ALPHA_CUT := 0.5
## The ground drawn under a line: sampled every this many metres.
const GROUND_STEP := 0.25


class Model:
	extends RefCounted
	var name: StringName
	var tris: PackedVector3Array
	var uvs: PackedVector2Array
	var sheet: Image
	var box: AABB
	var cell: Vector3
	var cells: Array[PackedInt32Array] = []


class Inst:
	extends RefCounted
	var model: Model
	var xf: Transform3D
	var inv: Transform3D
	var box: AABB


var _tally: Dictionary[String, int] = {}
var _models: Dictionary[StringName, Model] = {}
var _insts: Array[Inst] = []
var _stamp: PackedInt32Array = PackedInt32Array()
var _stamp_n: int = 0
var _hit := RayHit.new()
var _shown: int = 0
var _last: String = ""
var _line: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var area_name := args[0] if args.size() > 0 else "hut"
	var bodies := args[1].to_int() if args.size() > 1 else BODIES
	var per := args[2].to_int() if args.size() > 2 else PER_BODY
	var runner := MatchRunner.new(root, "woodland")
	await physics_frame
	await physics_frame
	var map := runner.map
	var play := PlayTuning.load_default()
	var sim := SimTuning.load_default()
	var bots := BotConfig.new()
	var props := play.site_look.props
	var query := runner.level.query()
	var leaves := query.foliage
	var bal := sim.ballistics
	leaves.count_leaves(bal.leaf_fern_tallest, bal.leaf_fern_shares, bal.leaf_bush_shares)
	_build_drawn(map, props, bal.leaf_fern_tallest)
	if area_name == "profile":
		for name: StringName in _models:
			_profile(_models[name])
		runner.free_level()
		quit()
		return
	if area_name == "trunks":
		for name: StringName in props.tree_feet:
			var crown: StringName = props.tree_crowns.get(name, &"")
			var top := _models[name].box.end.y
			if _models.has(crown):
				top = maxf(top, _models[crown].box.end.y)
			_trunk(_models[name], top)
			_trunk_hold(_models[name], top, props.tree_feet[name])
		runner.free_level()
		quit()
		return
	if OS.has_environment("TRUTH_LINE"):
		var v := OS.get_environment("TRUTH_LINE").split_floats(",")
		var a := Vector3(v[0], v[1], v[2])
		var b := Vector3(v[3], v[4], v[5])
		for inst in _insts:
			if inst.box.intersects_segment(a, b) != null:
				var raw := 0
				var solid := 0
				var la := inst.inv * a
				var lb := inst.inv * b
				for t in inst.model.tris.size() / 3:
					var at: Variant = Geometry3D.segment_intersects_triangle(la, lb, inst.model.tris[t * 3],
							inst.model.tris[t * 3 + 1], inst.model.tris[t * 3 + 2])
					if at != null:
						raw += 1
						if _opaque(inst.model, t, at as Vector3):
							solid += 1
				print("  %s at %s box %s: meets %s; raw %d solid %d of %d tris" % [inst.model.name, inst.xf.origin,
						inst.box, _meet(inst, a, b), raw, solid, inst.model.tris.size() / 3])
		print("  drawn: '%s'" % _drawn_stop(map, a, b))
	var area := _area(area_name, map)
	var top := Hitbox.hit_top(0.0, sim.hits)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var spot_seen := 0
	var spot_miss := 0
	var made := 0
	var guard := 0
	while made < bodies and guard < bodies * 200:
		guard += 1
		var foot := Vector3(rng.randf_range(area.position.x, area.end.x), 0.0,
				rng.randf_range(area.position.y, area.end.y))
		foot.y = map.terrain.height_clamped(foot.x, foot.z)
		if _in_block(map, foot + Vector3.UP * 1.0, 0.35) or leaves.holds(foot + Vector3.UP * 0.5):
			continue
		if not _near_plant(foot, 3.0):
			continue
		made += 1
		var kept := 0
		var tries := 0
		while kept < per and tries < per * 40:
			tries += 1
			var a := rng.randf() * TAU
			var eye := foot + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(NEAR, FAR)
			eye.y = map.terrain.height_clamped(eye.x, eye.z) + EYE
			if _in_block(map, eye, 0.4) or leaves.holds(eye):
				continue
			var near_any := false
			for p in PARTS:
				if _line_near_plant(eye, foot + Vector3.UP * top * p):
					near_any = true
			if not near_any:
				continue
			kept += 1
			var flat := Vector2(foot.x - eye.x, foot.z - eye.z).length()
			var drawn_sees := false
			var game_sees := false
			for k in PARTS.size():
				var point := foot + Vector3.UP * top * PARTS[k]
				var drawn := _drawn_stop(map, eye, point)
				var bb := _game_stop(map, query, eye, point, true, bal.leaf_stop_depth, 0.0)
				var look := _game_stop(map, query, eye, point, false, bots.foliage_see_through,
						flat - bots.close_awareness)
				_add("lines %s" % PART_NAMES[k])
				_judge("bb", PART_NAMES[k], bb, drawn)
				_judge("sight", PART_NAMES[k], look, drawn)
				if k >= 2:
					# what isn't a plant is drawn as its block: the two agree there
					var hard := look != "" and not _plant(look)
					drawn_sees = drawn_sees or (drawn == "" and not hard)
					game_sees = game_sees or look == ""
			if drawn_sees:
				spot_seen += 1
				if not game_sees:
					spot_miss += 1
	var keys := _tally.keys()
	keys.sort()
	print("area %s: %d bodies, %d lines a body" % [area_name, made, per])
	for k: String in keys:
		print("%s: %d" % [k, _tally[k]])
	print("spotted: chest or head drawn in sight %d, game sees neither %d (%.1f %%)" % [spot_seen, spot_miss,
			100.0 * spot_miss / maxi(spot_seen, 1)])
	runner.free_level()
	quit()


func _judge(what: String, part: String, game: String, drawn: String) -> void:
	# what isn't a plant is drawn as its block (walls, crates, logs) or is the ground itself: the two agree there
	if game != "" and not _plant(game):
		return
	if game != "" and drawn == "":
		if OS.has_environment("TRUTH_DEBUG") and what == "bb" and _shown < 12 and game.begins_with(OS.get_environment("TRUTH_DEBUG")):
			_shown += 1
			print("  unseen %s: %s" % [game, _last])
		_add("%s unseen %s by %s" % [what, part, game])
		_add("%s unseen (all parts)" % what)
	elif game == "" and drawn != "":
		if OS.has_environment("TRUTH_THROUGH") and what == "bb" and _shown < 8 and drawn == OS.get_environment("TRUTH_THROUGH"):
			_shown += 1
			print("  through %s: %s" % [drawn, _line])
		_add("%s through %s past %s" % [what, part, drawn])
		_add("%s through (all parts)" % what)


func _plant(game: String) -> bool:
	return game == "leaves" or game.begins_with("thicket") or game.begins_with("tree")


## What stops the line from `a` to `b` in the game, "" for nothing: the level (named by the block it meets) or leaves
## (more than `leaf_most` m of them, counted only where `leafy` > 0 or for a BB).
func _game_stop(map: MapData, query: WorldQuery, a: Vector3, b: Vector3, bb: bool, leaf_most: float,
		leafy: float) -> String:
	_line = "%s,%s,%s,%s,%s,%s" % [a.x, a.y, a.z, b.x, b.y, b.z]
	var hit := query.bb_ray(a, b, _hit) if bb else query.sight_ray(a, b, _hit)
	if hit:
		_last = "%s -> %s at %s" % [a, b, _hit.position]
		return _named(map, _hit.position)
	var depth := query.foliage.depth(a, b, leaf_most + 0.01)
	if (bb and depth >= leaf_most) or (not bb and leafy > 0.0 and depth > leaf_most):
		return "leaves"
	return ""


## The block holding `at` (a hit point), by its kind and model, or "ground".
func _named(map: MapData, at: Vector3) -> String:
	for b in map.blocks:
		if AABB(b.center - b.size * 0.5, b.size).grow(0.03).has_point(at):
			return "%s/%s" % [b.kind, b.dress] if b.dress != "" else String(b.kind)
	return "ground"


## The first drawn plant (or the ground) on the line from `a` to `b`, "" for none.
func _drawn_stop(map: MapData, a: Vector3, b: Vector3) -> String:
	var length := a.distance_to(b)
	var steps := int(length / GROUND_STEP)
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / steps)
		if p.y < map.terrain.height_clamped(p.x, p.z) - 0.02:
			return "ground"
	var best := INF
	var name := ""
	for inst in _insts:
		if inst.box.intersects_segment(a, b) == null:
			continue
		var t := _meet(inst, a, b)
		if t < best:
			best = t
			name = String(inst.model.name)
	return name


## Where along (0 to 1) the line from `a` to `b` first meets an opaque face of `inst`, INF for none.
func _meet(inst: Inst, a: Vector3, b: Vector3) -> float:
	var m := inst.model
	var la := inst.inv * a
	var lb := inst.inv * b
	_stamp_n += 1
	var best := INF
	var seg := lb - la
	var len := seg.length()
	var step := minf(m.cell.x, minf(m.cell.y, m.cell.z)) * 0.5
	var n := int(len / step) + 2
	for s in n + 1:
		var p := la + seg * (float(s) / n)
		var c := _cell_of(m, p)
		if c < 0:
			continue
		for t in m.cells[c]:
			if _stamp[t] == _stamp_n:
				continue
			_stamp[t] = _stamp_n
			var at: Variant = Geometry3D.segment_intersects_triangle(la, lb, m.tris[t * 3], m.tris[t * 3 + 1],
					m.tris[t * 3 + 2])
			if at == null:
				continue
			var f := (at as Vector3).distance_to(la) / maxf(len, 1e-6)
			if f < best and _opaque(m, t, at as Vector3):
				best = f
	return best


## How solid model `m` is drawn by height, its leaf cards cut out of their sheet: in each of 12 bands,
## level lines in seeded directions passing its middle `u` of its half-width off (u 0 to 1 by 0.1), the share (%)
## meeting an opaque face; with the offset where that first falls under a half.
func _profile(m: Model) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var box := m.box
	var mid := box.get_center()
	var half := Vector2(box.size.x, box.size.z) * 0.5
	var inst := Inst.new()
	inst.model = m
	inst.xf = Transform3D.IDENTITY
	inst.inv = Transform3D.IDENTITY
	inst.box = box
	print("%s %s (%d faces): %% of level lines meeting it by offset 0 to 1 of its half-width" % [m.name, box.size,
			m.tris.size() / 3])
	var bands := 12
	for k in bands:
		var line := "  height %.2f:" % ((k + 0.5) / bands)
		var edge := 1.0
		for ui in 11:
			var u := ui * 0.1
			var met := 0
			var tries := 60
			for n in tries:
				var y := box.position.y + (k + rng.randf()) / bands * box.size.y
				var a := rng.randf() * TAU
				var way := Vector3(cos(a), 0.0, sin(a))
				var c := Vector3(mid.x, y, mid.z) + Vector3(-way.z * half.x, 0.0, way.x * half.y) * u
				var reach := maxf(half.x, half.y) * 2.5
				if _meet(inst, c - way * reach, c + way * reach) < INF:
					met += 1
			var share := float(met) / tries
			if share < 0.5 and edge >= 1.0:
				edge = u
			line += " %3.0f" % (share * 100.0)
		print(line + "  (under half from %.1f)" % edge)


## A tree trunk's reach up the bottom of its box (PropLayout.tree_fit stands the box from the model's sunk foot to
## `top`, the crown's top in the model): in bands of a share of the box's height, the offset (share of the trunk's
## foot half-width) where a level line past it first meets its bark less than half the time, in steps of 0.05.
func _trunk(m: Model, top: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var inst := Inst.new()
	inst.model = m
	inst.xf = Transform3D.IDENTITY
	inst.inv = Transform3D.IDENTITY
	inst.box = m.box
	var base := m.box.position.y
	var half := maxf(m.box.size.x, m.box.size.z) * 0.5
	var line := "%s (top %.2f, foot half-width %.3f):" % [m.name, top, half]
	var band := 0.02
	var share := 0.0
	while share < 0.5:
		var edge := 1.0
		for ui in 21:
			var u := ui * 0.05
			var met := 0
			var tries := 48
			for n in tries:
				var y := base + (share + rng.randf() * band) * (top - base)
				var a := rng.randf() * TAU
				var way := Vector3(cos(a), 0.0, sin(a))
				var c := Vector3(0.0, y, 0.0) + Vector3(-way.z, 0.0, way.x) * half * u
				if _meet(inst, c - way * half * 3.0, c + way * half * 3.0) < INF:
					met += 1
			if met * 2 < tries:
				edge = u
				break
		line += " %.2f:%.2f" % [share, edge]
		share += band
		if share > 0.2:
			band = 0.05
	print(line)


## The reach (share of the foot's half-width `half`, PropDressConfig.tree_feet) MapStyle.ROUND_TRUNK's three boxes need, band by band up the trunk
## (shares of `top` over its origin, the ground), to hold every vertex of model `m` in the band: what
## MapStyle.round_tiers is worked out from.
func _trunk_hold(m: Model, top: float, half: float) -> void:
	var bands: Array[float] = [0.0, 0.02, 0.05, 0.08, 0.12, 0.18, 0.25, 0.35, 0.5, 1.01]
	# points over every face (the bole runs straight between its rings of vertices)
	var pts := PackedVector3Array()
	for t in m.tris.size() / 3:
		for i in 7:
			for j in 7 - i:
				var a := i / 6.0
				var b := j / 6.0
				pts.append(m.tris[t * 3] * (1.0 - a - b) + m.tris[t * 3 + 1] * a + m.tris[t * 3 + 2] * b)
	var line := "  holds:"
	for k in bands.size() - 1:
		var need := 0.0
		for v in pts:
			var s := v.y / top
			if (s < bands[k] and k > 0) or s >= bands[k + 1]:
				continue
			var x := absf(v.x) / half
			var z := absf(v.z) / half
			var r := minf(maxf(x, z / 0.55), minf(maxf(x / 0.55, z), maxf(x, z) / 0.883))
			need = maxf(need, r)
		line += " %.2f:%.3f" % [bands[k], need]
	print(line)


func _cell_of(m: Model, p: Vector3) -> int:
	var q := (p - m.box.position) / m.cell
	var i := Vector3i(floori(q.x), floori(q.y), floori(q.z))
	if i.x < 0 or i.y < 0 or i.z < 0 or i.x >= GRID or i.y >= GRID or i.z >= GRID:
		return -1
	return (i.x * GRID + i.y) * GRID + i.z


func _opaque(m: Model, t: int, at: Vector3) -> bool:
	if m.sheet == null or m.uvs[t * 3].x < -1.0:
		return true
	var w := Geometry3D.get_triangle_barycentric_coords(at, m.tris[t * 3], m.tris[t * 3 + 1], m.tris[t * 3 + 2])
	var uv := m.uvs[t * 3] * w.x + m.uvs[t * 3 + 1] * w.y + m.uvs[t * 3 + 2] * w.z
	var px := Vector2i(clampi(int(uv.x * m.sheet.get_width()), 0, m.sheet.get_width() - 1),
			clampi(int(uv.y * m.sheet.get_height()), 0, m.sheet.get_height() - 1))
	return m.sheet.get_pixelv(px).a >= ALPHA_CUT


## Every plant as drawn: PropDress's foliage models (model_barks: trees, crowns, spruces) and BushView's ferns and
## shrubs.
func _build_drawn(map: MapData, props: PropDressConfig, fern_tallest: float) -> void:
	var dress := PropDress.build(map, props)
	var leaf_sheet := Image.load_from_file(ProjectSettings.globalize_path(props.foliage_sheet))
	var placed := dress.placed()
	for name: StringName in placed:
		if not props.model_barks.has(name):
			continue
		var mesh := dress.mesh_of(name)
		if mesh == null:
			continue
		var m := _model(name, mesh, leaf_sheet)
		for t in placed[name].transforms:
			_inst(m, t)
	dress.free()
	var woods := WoodsConfig.new()
	var bush_sheet := Image.load_from_file(ProjectSettings.globalize_path(woods.bush_sheet))
	var f := map.foliage
	var turns := BushView.turns_of(map)
	for kind in 2:
		var path := woods.fern_model if kind == 0 else woods.bush_model
		var mesh := PropDressConfig.load_mesh(path)
		var m := _model(&"fern" if kind == 0 else &"shrub", mesh, bush_sheet)
		for i in f.size():
			if (f.heights[i] <= fern_tallest) == (kind == 0):
				_inst(m, BushView.fitted(f, i, mesh.get_aabb(), turns[i]))
	var most := 0
	for m: Model in _models.values():
		most = maxi(most, m.tris.size() / 3)
	_stamp.resize(most)
	print("drawn plants: %d models, %d placed" % [_models.size(), _insts.size()])


func _model(name: StringName, mesh: Mesh, sheet: Image) -> Model:
	if _models.has(name):
		return _models[name]
	var m := Model.new()
	m.name = name
	m.sheet = sheet
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
		for i in idx:
			m.tris.append(verts[i])
			m.uvs.append((uv as PackedVector2Array)[i] if uv != null else Vector2(-8.0, 0.0))
	m.box = mesh.get_aabb().grow(0.01)
	m.cell = m.box.size / GRID
	m.cells.resize(GRID * GRID * GRID)
	for c in m.cells.size():
		m.cells[c] = PackedInt32Array()
	for t in m.tris.size() / 3:
		var lo := m.tris[t * 3].min(m.tris[t * 3 + 1]).min(m.tris[t * 3 + 2])
		var hi := m.tris[t * 3].max(m.tris[t * 3 + 1]).max(m.tris[t * 3 + 2])
		var a := ((lo - m.box.position) / m.cell).floor()
		var b := ((hi - m.box.position) / m.cell).floor()
		for x in range(clampi(int(a.x), 0, GRID - 1), clampi(int(b.x), 0, GRID - 1) + 1):
			for y in range(clampi(int(a.y), 0, GRID - 1), clampi(int(b.y), 0, GRID - 1) + 1):
				for z in range(clampi(int(a.z), 0, GRID - 1), clampi(int(b.z), 0, GRID - 1) + 1):
					m.cells[(x * GRID + y) * GRID + z].append(t)
	_models[name] = m
	return m


func _inst(m: Model, xf: Transform3D) -> void:
	var i := Inst.new()
	i.model = m
	i.xf = xf
	i.inv = xf.affine_inverse()
	i.box = xf * m.box
	_insts.append(i)


func _area(name: String, map: MapData) -> Rect2:
	if AREAS.has(name):
		return AREAS[name]
	var parts := name.split(",")
	if parts.size() == 4:
		return Rect2(parts[0].to_float(), parts[1].to_float(), parts[2].to_float() - parts[0].to_float(),
				parts[3].to_float() - parts[1].to_float())
	return Rect2(map.terrain.min_x, map.terrain.min_z, map.terrain.cols * map.terrain.cell,
			map.terrain.rows * map.terrain.cell)


func _in_block(map: MapData, at: Vector3, grow: float) -> bool:
	for b in map.blocks:
		if AABB(b.center - b.size * 0.5, b.size).grow(grow).has_point(at):
			return true
	return false


func _near_plant(at: Vector3, reach: float) -> bool:
	for inst in _insts:
		if inst.box.grow(reach).has_point(at):
			return true
	return false


func _line_near_plant(a: Vector3, b: Vector3) -> bool:
	for inst in _insts:
		if inst.box.grow(NEAR_PLANT).intersects_segment(a, b) != null:
			return true
	return false


func _add(k: String) -> void:
	_tally[k] = _tally.get(k, 0) + 1

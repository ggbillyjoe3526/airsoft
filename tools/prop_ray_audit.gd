extends SceneTree
## Every prop on every map, the game's BB path against the model as drawn (DG1; dev only, never exported). For each
## model a map draws (PropDress, as the game lays it), seeded lines pass through its props at random heights and
## nearly level, each kept only where both its ends stand clear of every block. Each line is asked twice:
## - the game: where does a BB's path stop (WorldQuery.ray_past_railings: the level, past the railings' boxes);
## - as drawn: where does it first meet an opaque face of a drawn prop (leaf cards cut out of their sheet at
##   look_foliage's alpha_cut, read at full detail; bark and every other face always), a block drawn as its box, or the
##   ground.
## "Phantom" lines stop in the game short of anything drawn (a BB ricocheting off empty space, a body hidden by
## nothing); "through" lines fly on in the game past a drawn face. Each model's share of its lines either way, and the
## worst models first. Measured, never asserted.
##   godot --headless --path . -s res://tools/prop_ray_audit.gd -- [maps, comma-separated] [lines a model]
## Without arguments: every map, 400 lines a model. TRUTH_SHOW=<model> prints that model's first disagreements.

const SEED := 41
const LINES := 400
## A prop's lines are aimed through at most this many of its props, picked in turn.
const PROPS_A_MODEL := 40
## How far either way past the prop's drawn bounds a line runs (m).
const REACH := 2.5
## The steepest a line climbs or falls (rad).
const PITCH := 0.3
## Two stops this near (m) agree; a game stop up to EARLY short of the drawn one is early (a box a little proud of its
## model), further short a phantom.
const AGREE := 0.05
const EARLY := 0.25
const GRID := 10
const ALPHA_CUT := 0.5
const GROUND_STEP := 0.1


class Model:
	extends RefCounted
	var name: StringName
	var tris: PackedVector3Array
	var uvs: PackedVector2Array
	var leafy: bool = false
	var box: AABB
	var cell: Vector3
	var cells: Array[PackedInt32Array] = []


class Inst:
	extends RefCounted
	var model: Model
	var xf: Transform3D
	var inv: Transform3D
	var box: AABB


var _models: Dictionary[StringName, Model] = {}
var _insts: Array[Inst] = []
var _by_model: Dictionary[StringName, Array] = {}
var _boxes: Array[AABB] = []
var _drawn_boxes: Array[AABB] = []
var _sheet: Image = null
var _stamp: PackedInt32Array = PackedInt32Array()
var _stamp_n: int = 0
var _hit := RayHit.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var maps := (args[0] if args.size() > 0 and not args[0].is_empty() else "depot,woodland,subway,range").split(",")
	var lines := args[1].to_int() if args.size() > 1 else LINES
	var rows: Array[String] = []
	for id: String in maps:
		await _audit(id, lines, rows)
	print("\nworst (phantom share), every map:")
	rows.sort_custom(func(a: String, b: String) -> bool: return a.get_slice("|", 0).to_float() > b.get_slice("|", 0).to_float())
	for r: String in rows.slice(0, 25):
		print("  " + r.get_slice("|", 1))
	quit()


func _audit(id: String, lines: int, rows: Array[String]) -> void:
	_models.clear()
	_insts.clear()
	_by_model.clear()
	_boxes.clear()
	_drawn_boxes.clear()
	var runner := MatchRunner.new(root, id)
	await physics_frame
	var map := runner.map
	var props := PropDressConfig.new()
	if map.station != null:
		props = props.named_only()
	_sheet = (load(props.foliage_sheet) as Texture2D).get_image()
	if _sheet.is_compressed():
		_sheet.decompress()
	var dress := PropDress.build(map, props)
	var placed: Dictionary[StringName, PropLayout.Placed] = dress.placed() if dress != null else {}
	for name: StringName in placed:
		var mesh := dress.mesh_of(name)
		if mesh == null:
			continue
		var m := _model(name, mesh, props.model_barks.has(name))
		for t in placed[name].transforms:
			_inst(m, t)
	if dress != null:
		dress.free()
	for b in map.blocks:
		var box := AABB(b.center - b.size * 0.5, b.size)
		_boxes.append(box)
		# a block drawn as props is drawn by them alone (SiteSurface.hidden), but for a lined one's backing
		if not props.dresses(b) or props.backs(b):
			_drawn_boxes.append(box)
	var most := 0
	for m: Model in _models.values():
		most = maxi(most, m.tris.size() / 3)
	_stamp.resize(most)
	var query := runner.level.query()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var total := Vector3i.ZERO
	var total_early := 0
	print("%s: %d models, %d props" % [id, _models.size(), _insts.size()])
	var names := _by_model.keys()
	names.sort()
	var shown := 0
	for name: StringName in names:
		var insts: Array = _by_model[name]
		var n := Vector3i.ZERO # lines, phantom, through
		var early := 0
		var tries := 0
		while n.x < lines and tries < lines * 30:
			tries += 1
			var inst: Inst = insts[((tries - 1) % mini(insts.size(), PROPS_A_MODEL)) * maxi(1, insts.size() / PROPS_A_MODEL)]
			var p := inst.box.position + inst.box.size * Vector3(rng.randf(), rng.randf(), rng.randf())
			var yaw := rng.randf() * TAU
			var pitch := rng.randf_range(-PITCH, PITCH)
			var way := Vector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch))
			var reach := inst.box.size.length() * 0.5 + REACH
			var a := p - way * reach
			var b := p + way * reach
			if _inside(a) or _inside(b) or _below_ground(map, a) or _below_ground(map, b):
				continue
			n.x += 1
			var length := a.distance_to(b)
			var game := query.ray_past_railings(a, b, _hit)
			var g := _hit.fraction * length if game else INF
			var d := _drawn_stop(map, a, b) * length
			if g < d - EARLY:
				n.y += 1
				if OS.get_environment("TRUTH_SHOW") == String(name) and shown < 10:
					shown += 1
					print("  phantom %s -> %s: game %.2f m, drawn %.2f m" % [a, b, g, d])
			elif g < d - AGREE:
				early += 1
			elif g > d + AGREE:
				n.z += 1
				if OS.get_environment("TRUTH_SHOW") == String(name) and shown < 10:
					shown += 1
					print("  through %s -> %s: game %.2f m, drawn %.2f m" % [a, b, g, d])
		total += n
		total_early += early
		var row := "%-26s %4d props %5d lines: phantom %5.1f %%, early %5.1f %%, through %5.1f %%" % [name,
				insts.size(), n.x, 100.0 * n.y / maxi(n.x, 1), 100.0 * early / maxi(n.x, 1), 100.0 * n.z / maxi(n.x, 1)]
		print("  " + row)
		rows.append("%f|%s %s" % [float(n.y) / maxi(n.x, 1), id, row])
	print("%s all: %d lines, phantom %.1f %%, early %.1f %%, through %.1f %%" % [id, total.x,
			100.0 * total.y / maxi(total.x, 1), 100.0 * total_early / maxi(total.x, 1), 100.0 * total.z / maxi(total.x, 1)])
	runner.free_level()
	runner = null


func _inside(p: Vector3) -> bool:
	for box in _boxes:
		if box.has_point(p):
			return true
	return false


func _below_ground(map: MapData, p: Vector3) -> bool:
	return map.terrain != null and p.y < map.terrain.height_clamped(p.x, p.z) + 0.05


## The first drawn stop on the line from `a` to `b`, as a share of it (INF for none): an opaque face of a drawn prop,
## a block drawn as its box, or the ground.
func _drawn_stop(map: MapData, a: Vector3, b: Vector3) -> float:
	var best := INF
	for box in _drawn_boxes:
		var at: Variant = box.intersects_segment(a, b)
		if at != null:
			best = minf(best, a.distance_to(at as Vector3) / a.distance_to(b))
	for inst in _insts:
		if inst.box.intersects_segment(a, b) == null:
			continue
		best = minf(best, _meet(inst, a, b))
	if map.terrain != null:
		var length := a.distance_to(b)
		var steps := int(length / GROUND_STEP)
		for i in range(1, steps + 1):
			var f := float(i) / steps
			if f >= best:
				break
			var p := a.lerp(b, f)
			if p.y < map.terrain.height_clamped(p.x, p.z):
				best = f
				break
	return best


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
		var c := _cell_of(m, la + seg * (float(s) / n))
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


func _cell_of(m: Model, p: Vector3) -> int:
	var q := (p - m.box.position) / m.cell
	var i := Vector3i(floori(q.x), floori(q.y), floori(q.z))
	if i.x < 0 or i.y < 0 or i.z < 0 or i.x >= GRID or i.y >= GRID or i.z >= GRID:
		return -1
	return (i.x * GRID + i.y) * GRID + i.z


func _opaque(m: Model, t: int, at: Vector3) -> bool:
	if not m.leafy or m.uvs[t * 3].x < -1.0:
		return true
	var w := Geometry3D.get_triangle_barycentric_coords(at, m.tris[t * 3], m.tris[t * 3 + 1], m.tris[t * 3 + 2])
	var uv := m.uvs[t * 3] * w.x + m.uvs[t * 3 + 1] * w.y + m.uvs[t * 3 + 2] * w.z
	var px := Vector2i(clampi(int(uv.x * _sheet.get_width()), 0, _sheet.get_width() - 1),
			clampi(int(uv.y * _sheet.get_height()), 0, _sheet.get_height() - 1))
	return _sheet.get_pixelv(px).a >= ALPHA_CUT


func _model(name: StringName, mesh: Mesh, leafy: bool) -> Model:
	if _models.has(name):
		return _models[name]
	var m := Model.new()
	m.name = name
	m.leafy = leafy
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
		if idx.is_empty():
			idx = PackedInt32Array(range(verts.size()))
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
	if not _by_model.has(m.name):
		_by_model[m.name] = []
	_by_model[m.name].append(i)

class_name StationDetail
extends Node3D
## A station's small fittings (SD2, the owner: "more environmental details"): along each fitted room's walls a
## skirting, a tile dado and a frieze over the posters' band, cable conduit under the ceiling with its clips, wall
## vents in the tall rooms, pipework in the plant rooms (one pipe down a passage); access hatches in the ceilings, clear
## of the lamps; drains along the halls' walls; a service door on each plant room's longest wall. A wall is found where
## a room's side meets a solid block (StationDetailConfig.solid_kinds); a column standing in a room is skirted round.
## One mesh in vertex colours, built once; look only (no collider, no nav cell). Signs and posters are SM5's fixtures.

const OCTAGON := 8

var _material: ShaderMaterial = null
var _mesh: ArrayMesh = null
var _doors: PackedVector3Array = PackedVector3Array()
## SM5's fixtures' spots (signs, posters, clocks, cameras): a vent or a door keeps clear of them.
var _fixtures: PackedVector3Array = PackedVector3Array()
var _fixture_clear: float = 0.0


## The fittings of `map`'s station, or null on a field with no station dress or nothing to fit.
static func build(map: MapData, cfg: StationDetailConfig) -> StationDetail:
	if map == null or cfg == null or map.station == null:
		return null
	var solids := _Solids.new(map, cfg.solid_kinds)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := StationDetail.new()
	d._fixture_clear = cfg.fixture_clear
	for f in map.station.fixtures:
		d._fixtures.append(f.position)
	var pieces := 0
	for z in map.station.zones:
		if not cfg.rooms.has(z.style) or minf(z.box.size.x, z.box.size.z) < cfg.min_room:
			continue
		pieces += d._fit_room(st, map, cfg, solids, z)
	if pieces == 0:
		d.free()
		return null
	d.name = "StationDetail"
	st.generate_tangents()
	d._mesh = st.commit()
	d._material = LookMaterials.vertex_colour(cfg.roughness, 0.0, Color.WHITE, true, cfg.wear)
	var view := MeshInstance3D.new()
	view.mesh = d._mesh
	view.material_override = d._material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.add_child(view)
	return d


## Fits room `z`: its walls' runs and the columns standing in it, its ceiling, its floor. The pieces laid.
func _fit_room(st: SurfaceTool, map: MapData, cfg: StationDetailConfig, solids: _Solids,
		z: StationDressing.Zone) -> int:
	var floor_y := z.box.position.y + cfg.zone_under
	var height := z.box.end.y - floor_y
	# Each fitting goes only where the wall stands at its own height: a parapet over a well is wall at the foot and
	# air above, so it takes a skirting but no frieze.
	var low := _runs(cfg, solids, z, floor_y, cfg.probe_height)
	var laid := low.size()
	var longest: Run = null
	for r in low:
		_strip(st, r, 0.0, cfg.skirting.x, cfg.skirting.y, cfg.skirting_colour)
		_strip(st, r, cfg.dado.x, cfg.dado.y, cfg.dado.z, cfg.band_colour)
		if z.style == &"hall" and r.length() >= cfg.min_run:
			_drains(st, cfg, r)
		if longest == null or r.length() > longest.length():
			longest = r
	if cfg.frieze.x + cfg.frieze.y < height - cfg.conduit_drop - cfg.conduit.y:
		for r in _runs(cfg, solids, z, floor_y, cfg.frieze.x + cfg.frieze.y * 0.5):
			_strip(st, r, cfg.frieze.x, cfg.frieze.y, cfg.frieze.z, cfg.band_colour)
	if height >= cfg.vent_room:
		for r in _runs(cfg, solids, z, floor_y, cfg.vent_bottom + cfg.vent.y * 0.5):
			_vents(st, cfg, r)
	if height >= cfg.conduit_room:
		for r in _runs(cfg, solids, z, floor_y, height - cfg.conduit_drop):
			if r.length() < cfg.min_run:
				continue
			_conduit(st, cfg, r, height)
			if cfg.pipe_rooms.has(z.style):
				for i in cfg.plant_pipes.size():
					_pipe(st, cfg, r, height, cfg.plant_pipes[i], cfg.pipe_colours[i % cfg.pipe_colours.size()])
			elif z.style == &"passage" and (r.out == Vector3.BACK or r.out == Vector3.LEFT):
				_pipe(st, cfg, r, height, cfg.passage_pipe, cfg.pipe_colours[0])
	for o in solids.columns_in(z.box, floor_y, cfg.column_max):
		var top := o.end.y - floor_y
		for r in _column_runs(o, floor_y):
			_strip(st, r, 0.0, cfg.skirting.x, cfg.skirting.y, cfg.skirting_colour)
			if top > cfg.dado.x + cfg.dado.y:
				_strip(st, r, cfg.dado.x, cfg.dado.y, cfg.dado.z, cfg.band_colour)
			if top > cfg.frieze.x + cfg.frieze.y and cfg.frieze.x + cfg.frieze.y < height - cfg.conduit_drop:
				_strip(st, r, cfg.frieze.x, cfg.frieze.y, cfg.frieze.z, cfg.band_colour)
			laid += 1
	if cfg.door_rooms.has(z.style) and minf(z.box.size.x, z.box.size.z) >= cfg.door_room_min and longest != null \
			and longest.length() >= cfg.door.x + 0.6:
		_door(st, cfg, longest)
	_hatches(st, map, cfg, solids, z)
	return laid


## A stretch of wall facing into a room: from `a` to `b` along the floor at the wall's face, `out` the way from the
## room into the wall; `column` a column's face (its bands wrap its corners).
class Run:
	extends RefCounted
	var a: Vector3 = Vector3.ZERO
	var b: Vector3 = Vector3.ZERO
	var out: Vector3 = Vector3.ZERO
	var column: bool = false

	func length() -> float:
		return a.distance_to(b)

	func along() -> Vector3:
		return (b - a).normalized()


## The blocks a room's walls, columns and ceilings are made of, bucketed by x.
class _Solids:
	extends RefCounted
	const COLUMN := 6.0
	var boxes: Array[AABB] = []
	var _cols: Dictionary[int, PackedInt32Array] = {}

	func _init(map: MapData, kinds: Array[StringName]) -> void:
		for b in map.blocks:
			if not kinds.has(b.kind) or b.dress != &"":
				continue
			var box := AABB(b.center - b.size * 0.5, b.size)
			var i := boxes.size()
			boxes.append(box)
			for c in range(floori(box.position.x / COLUMN), floori(box.end.x / COLUMN) + 1):
				if not _cols.has(c):
					_cols[c] = PackedInt32Array()
				_cols[c].append(i)

	func solid(p: Vector3) -> bool:
		var c := floori(p.x / COLUMN)
		if not _cols.has(c):
			return false
		for i in _cols[c]:
			if boxes[i].has_point(p):
				return true
		return false

	## The solid boxes standing on the floor inside room `box` (a column), clear of its sides, none wider than
	## `widest` m (a lift's shaft is no column).
	func columns_in(box: AABB, floor_y: float, widest: float) -> Array[AABB]:
		var out: Array[AABB] = []
		var seen: Dictionary[int, bool] = {}
		for c in range(floori(box.position.x / COLUMN), floori(box.end.x / COLUMN) + 1):
			if not _cols.has(c):
				continue
			for i in _cols[c]:
				var o := boxes[i]
				if seen.has(i):
					continue
				seen[i] = true
				if o.position.x > box.position.x + 0.1 and o.end.x < box.end.x - 0.1 \
						and o.position.z > box.position.z + 0.1 and o.end.z < box.end.z - 0.1 \
						and o.position.y <= floor_y + 0.05 and o.end.y >= floor_y + 1.0 \
						and maxf(o.size.x, o.size.z) <= widest:
					out.append(o)
		return out


## Room `z`'s walls at `over` m over its floor: each side's stretches where a solid stands just beyond it there.
static func _runs(cfg: StationDetailConfig, solids: _Solids, z: StationDressing.Zone, floor_y: float,
		over: float) -> Array[Run]:
	var out: Array[Run] = []
	var lo := z.box.position
	var hi := z.box.end
	var y := floor_y + over
	# each side: its line's start and end on the floor, and the way out of the room through it
	var sides: Array[Array] = [
		[Vector3(lo.x, floor_y, lo.z), Vector3(lo.x, floor_y, hi.z), Vector3.LEFT],
		[Vector3(hi.x, floor_y, lo.z), Vector3(hi.x, floor_y, hi.z), Vector3.RIGHT],
		[Vector3(lo.x, floor_y, lo.z), Vector3(hi.x, floor_y, lo.z), Vector3.FORWARD],
		[Vector3(lo.x, floor_y, hi.z), Vector3(hi.x, floor_y, hi.z), Vector3.BACK],
	]
	for s in sides:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var way: Vector3 = s[2]
		var n := maxi(1, roundi(a.distance_to(b) / cfg.step))
		var start := -1
		for i in n + 1:
			var wall := false
			if i < n:
				var p := a.lerp(b, (float(i) + 0.5) / float(n)) + way * cfg.probe
				p.y = y
				wall = solids.solid(p)
			if wall and start < 0:
				start = i
			elif not wall and start >= 0:
				var r := Run.new()
				r.a = a.lerp(b, float(start) / float(n))
				r.b = a.lerp(b, float(i) / float(n))
				r.out = way
				out.append(r)
				start = -1
	return out


## Column `o`'s four faces standing in room `z`.
static func _column_runs(o: AABB, floor_y: float) -> Array[Run]:
	var lo := Vector3(o.position.x, floor_y, o.position.z)
	var hi := Vector3(o.end.x, floor_y, o.end.z)
	var faces: Array[Array] = [
		[Vector3(lo.x, floor_y, lo.z), Vector3(lo.x, floor_y, hi.z), Vector3.RIGHT],
		[Vector3(hi.x, floor_y, lo.z), Vector3(hi.x, floor_y, hi.z), Vector3.LEFT],
		[Vector3(lo.x, floor_y, lo.z), Vector3(hi.x, floor_y, lo.z), Vector3.BACK],
		[Vector3(lo.x, floor_y, hi.z), Vector3(hi.x, floor_y, hi.z), Vector3.FORWARD],
	]
	var out: Array[Run] = []
	for f in faces:
		var r := Run.new()
		r.a = f[0]
		r.b = f[1]
		r.out = f[2]
		r.column = true
		out.append(r)
	return out


## A band on run `r`'s wall from `bottom` m over the floor, `tall` m high, standing `depth` m off it; on a column
## it wraps the corners.
func _strip(st: SurfaceTool, r: Run, bottom: float, tall: float, depth: float, colour: Color) -> void:
	var grow := r.along() * (depth if r.column else 0.0)
	var a := r.a - grow - r.out * depth + Vector3.UP * bottom
	var b := r.b + grow + Vector3.UP * (bottom + tall)
	_box(st, a, b, colour)


## Conduit along run `r`, under the ceiling, a clip every StationDetailConfig.clip_pitch m.
func _conduit(st: SurfaceTool, cfg: StationDetailConfig, r: Run, height: float) -> void:
	var y := height - cfg.conduit_drop
	var lift := Vector3.UP * y
	_box(st, r.a + lift - r.out * cfg.conduit.x, r.b + lift + Vector3.UP * cfg.conduit.y, cfg.conduit_colour)
	var n := floori(r.length() / cfg.clip_pitch)
	for i in n:
		var at := r.a + r.along() * (cfg.clip_pitch * (float(i) + 0.5)) + lift
		var w := r.along() * 0.02
		_box(st, at - w - r.out * (cfg.conduit.x + 0.008) - Vector3.UP * 0.008,
				at + w + Vector3.UP * (cfg.conduit.y + 0.008), cfg.clip_colour)


## A pipe along run `r`: `spec` its drop under the ceiling, radius and gap off the wall; brackets to the wall.
func _pipe(st: SurfaceTool, cfg: StationDetailConfig, r: Run, height: float, spec: Vector3, colour: Color) -> void:
	var off := spec.z + spec.y
	var centre := Vector3.UP * (height - spec.x) - r.out * off
	_tube(st, r.a + centre, r.b + centre, spec.y, colour)
	var n := floori(r.length() / cfg.bracket_pitch)
	for i in n:
		var at := r.a + r.along() * (cfg.bracket_pitch * (float(i) + 0.5)) + Vector3.UP * (height - spec.x)
		var w := r.along() * 0.015
		# a strap under the pipe on an arm from the wall
		_box(st, at - w - r.out * (off + spec.y * 0.6) - Vector3.UP * (spec.y + 0.012),
				at + w - Vector3.UP * spec.y, cfg.bracket_colour)


## Vents along run `r`, one every StationDetailConfig.vent_pitch m: a frame and its louvres.
func _vents(st: SurfaceTool, cfg: StationDetailConfig, r: Run) -> void:
	var n := floori(r.length() / cfg.vent_pitch)
	if n == 0 and r.length() >= cfg.vent.x + 1.0:
		n = 1
	for i in n:
		var at := r.a + r.along() * (r.length() * (float(i) + 0.5) / float(n)) + Vector3.UP * cfg.vent_bottom
		var half := r.along() * (cfg.vent.x * 0.5)
		if not _clear(at - half, at + half + Vector3.UP * cfg.vent.y):
			continue
		_box(st, at - half - r.out * 0.012, at + half + Vector3.UP * cfg.vent.y, cfg.vent_colour)
		for k in 4:
			var y := cfg.vent.y * (float(k) + 0.6) / 4.6
			_box(st, at - half * 0.9 - r.out * 0.02 + Vector3.UP * y,
					at + half * 0.9 - r.out * 0.012 + Vector3.UP * (y + cfg.vent.y * 0.09), cfg.louvre_colour)


## Drains along a hall's run `r`, on the floor StationDetailConfig.drain_off m out from it.
func _drains(st: SurfaceTool, cfg: StationDetailConfig, r: Run) -> void:
	if r.column:
		return
	var n := floori(r.length() / cfg.drain_pitch)
	for i in n:
		var at := r.a + r.along() * (r.length() * (float(i) + 0.5) / float(n)) - r.out * cfg.drain_off
		var half := Vector3(cfg.drain, 0.0, cfg.drain) * 0.5
		_box(st, at - half, at + half + Vector3.UP * 0.004, cfg.drain_colour)
		for k in 4:
			var s := r.along() * (cfg.drain * (float(k) - 1.5) / 5.0)
			var bar := r.out * (cfg.drain * 0.38)
			_box(st, at + s - bar - r.along() * 0.012 + Vector3.UP * 0.004,
					at + s + bar + r.along() * 0.012 + Vector3.UP * 0.006, cfg.seam_colour)


## A service door at the middle of run `r`: its frame, leaf, kick plate, handle and a blank notice plate.
func _door(st: SurfaceTool, cfg: StationDetailConfig, r: Run) -> void:
	var mid := (r.a + r.b) * 0.5
	var half := r.along() * (cfg.door.x * 0.5)
	if not _clear(mid - half, mid + half + Vector3.UP * cfg.door.y):
		return
	var f := 0.06
	var d := cfg.door.z
	var leaf := cfg.skirting.y + 0.006  # proud of the skirting, which runs on behind the frame
	_box(st, mid - half - r.along() * f - r.out * d, mid - half + Vector3.UP * (cfg.door.y + f), cfg.frame_colour)
	_box(st, mid + half - r.out * d, mid + half + r.along() * f + Vector3.UP * (cfg.door.y + f), cfg.frame_colour)
	_box(st, mid - half - r.out * d + Vector3.UP * cfg.door.y, mid + half + Vector3.UP * (cfg.door.y + f),
			cfg.frame_colour)
	_box(st, mid - half - r.out * leaf, mid + half + Vector3.UP * cfg.door.y, cfg.door_colour)
	_box(st, mid - half * 0.95 - r.out * (leaf + 0.004), mid + half * 0.95 + Vector3.UP * 0.25, cfg.handle_colour)
	var h := mid + half * 0.75 + Vector3.UP * 1.0
	_box(st, h - r.along() * 0.06 - r.out * (d + 0.03), h + r.along() * 0.06 + Vector3.UP * 0.03, cfg.handle_colour)
	var p := mid + Vector3.UP * 1.55
	_box(st, p - half * 0.4 - r.out * (leaf + 0.004), p + half * 0.4 + Vector3.UP * 0.2, cfg.plate_colour)
	_doors.append(mid)


## Access hatches in room `z`'s ceiling: a grid clear of its sides and of every lamp on that ceiling.
func _hatches(st: SurfaceTool, map: MapData, cfg: StationDetailConfig, solids: _Solids,
		z: StationDressing.Zone) -> void:
	var top := z.box.end.y
	var lo := z.box.position
	var hi := z.box.end
	var nx := floori((hi.x - lo.x - 2.0 * cfg.edge_clear) / cfg.hatch_pitch) + 1
	var nz := floori((hi.z - lo.z - 2.0 * cfg.edge_clear) / cfg.hatch_pitch) + 1
	if nx < 1 or nz < 1:
		return
	var s := cfg.hatch * 0.5
	for i in nx:
		for k in nz:
			var x := lerpf(lo.x, hi.x, (float(i) + 0.5) / float(nx))
			var zz := lerpf(lo.z, hi.z, (float(k) + 0.5) / float(nz))
			if not solids.solid(Vector3(x, top + 0.05, zz)) or _near_lamp(map, cfg, x, zz, top) \
					or _blocked_under(solids, x, zz, top - 0.05, s + 0.03):
				continue
			var c := Vector3(x, top, zz)
			_box(st, c - Vector3(s + 0.03, 0.012, s + 0.03), c + Vector3(s + 0.03, 0.0, s + 0.03), cfg.seam_colour)
			_box(st, c - Vector3(s, 0.016, s), c + Vector3(s, -0.004, s), cfg.hatch_colour)


## Whether a solid (a pillar running up through the ceiling) stands at the middle or a corner of a hatch `half` m
## across at (x, z), height `y` just under the ceiling.
static func _blocked_under(solids: _Solids, x: float, z: float, y: float, half: float) -> bool:
	for c: Vector2 in [Vector2.ZERO, Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half),
			Vector2(half, half)]:
		if solids.solid(Vector3(x + c.x, y, z + c.y)):
			return true
	return false


static func _near_lamp(map: MapData, cfg: StationDetailConfig, x: float, z: float, top: float) -> bool:
	for i in map.roof_lamps.size():
		var h := map.roof_lamp_heights[i] if i < map.roof_lamp_heights.size() else map.roof_height
		if absf(h - top) > 0.5:
			continue
		if map.roof_lamps[i].distance_to(Vector2(x, z)) < cfg.lamp_clear:
			return true
	return false


## An axis-aligned box between corners `a` and `b` (either order), in `colour`.
static func _box(st: SurfaceTool, a: Vector3, b: Vector3, colour: Color) -> void:
	var lo := a.min(b)
	var hi := a.max(b)
	st.set_color(colour)
	var c: Array[Vector3] = [
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	]
	_quad(st, c[4], c[5], c[6], c[7], Vector3.BACK)
	_quad(st, c[1], c[0], c[3], c[2], Vector3.FORWARD)
	_quad(st, c[5], c[1], c[2], c[6], Vector3.RIGHT)
	_quad(st, c[0], c[4], c[7], c[3], Vector3.LEFT)
	_quad(st, c[7], c[6], c[2], c[3], Vector3.UP)
	_quad(st, c[0], c[1], c[5], c[4], Vector3.DOWN)


## A level tube of radius `r` from `a` to `b` (along x or z), eight sides, open ends (they meet walls).
static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, r: float, colour: Color) -> void:
	st.set_color(colour)
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP).normalized()
	for i in OCTAGON:
		var t0 := TAU * float(i) / float(OCTAGON)
		var t1 := TAU * float(i + 1) / float(OCTAGON)
		var n0 := side * cos(t0) + Vector3.UP * sin(t0)
		var n1 := side * cos(t1) + Vector3.UP * sin(t1)
		var nm := (n0 + n1).normalized()
		_quad(st, a + n0 * r, b + n0 * r, b + n1 * r, a + n1 * r, nm)


## A quad p0..p3, counter-clockwise seen from its face `n`.
static func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3) -> void:
	var w := (p1 - p0).cross(p2 - p0)
	var flip := w.dot(n) < 0.0
	st.set_normal(n)
	st.set_uv(Vector2.ZERO)
	# Godot's front faces wind clockwise as seen
	var b := p2 if not flip else p1
	var c := p1 if not flip else p2
	st.add_vertex(p0)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(p0)
	st.add_vertex(p3 if not flip else p2)
	st.add_vertex(p2 if not flip else p3)


## Whether the box between corners `a` and `b` (grown by StationDetailConfig.fixture_clear) holds no fixture's spot.
func _clear(a: Vector3, b: Vector3) -> bool:
	var box := AABB(a.min(b), (b - a).abs()).grow(_fixture_clear)
	for p in _fixtures:
		if box.has_point(p):
			return false
	return true


## The service doors laid (their middles on the floor), and the mesh and material drawn.
func doors() -> PackedVector3Array:
	return _doors


func mesh() -> ArrayMesh:
	return _mesh


func materials() -> Array[Material]:
	return [_material] as Array[Material]

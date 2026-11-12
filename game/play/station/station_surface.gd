class_name StationSurface
extends RefCounted
## A station dress's surfaces (MT3, Subway): the level's very block faces (GreyboxFaces, in its order) drawn in the
## CC0 photo sets StationLook gives each face, with the platforms' edge strips and painted words, the track's rails and
## sleepers and the platform tunnels' curved vaults (TB1: drawn in place of their colliders' boxes), as one mesh in one
## material (station_surface.gdshader). MapLevel draws it in place of the greybox's mesh; the colliders,
## the nav, the shadow's shape and the sight lines are the blocks', unchanged: a strip lies `strip_lift` over its floor
## and the track's rails and sleepers are scenery (no collider). Static functions only; build time, never per frame.

const SHADER := preload("res://game/play/station/station_surface.gdshader")
## A face looking into no room grimes from nowhere: its floor this far below.
const NO_FLOOR := -1000.0
## The render layer the station's surface draws on, alone (MapLevel), so the lamps inside a train's cars, unshadowed
## beyond the eye's near lamps, light the cars and whoever stands in them but never the tunnel walls round the train
## through its sides (SM1, RoofView.hide_lamps_in).
const LAYER := 1 << 16
## How far (m) either side of a train box's side the zones that cut its lining are looked for (TB1's vaults stand
## a little over its top; the next room's wall is never further).
const LINING_REACH := 1.0
## How far (m) inside a train box's top and foot the room past its nearer end is looked for: clear of the box's slabs.
const LINING_INSET := 0.5


## The material for `look`: its texture arrays and wear. Null (with an error) when an array is missing, so the level
## falls back to the greybox.
static func material(look: StationLook) -> ShaderMaterial:
	var colour := load(look.colour_array) as TextureLayered if ResourceLoader.exists(look.colour_array) else null
	var surface := load(look.surface_array) as TextureLayered if ResourceLoader.exists(look.surface_array) else null
	if colour == null or surface == null:
		push_error("StationSurface: texture arrays %s, %s missing or not arrays; drawn as greybox"
				% [look.colour_array, look.surface_array])
		return null
	if colour.get_layers() < look.sets.size() or surface.get_layers() < look.sets.size():
		push_error("StationSurface: the texture arrays have %d and %d layers for %d sets; drawn as greybox (rebake with "
				% [colour.get_layers(), surface.get_layers(), look.sets.size()] + "tools/textures/station_textures.gd)")
		return null
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"colour_tex", colour)
	m.set_shader_parameter(&"surface_tex", surface)
	m.set_shader_parameter(&"variation", look.variation)
	m.set_shader_parameter(&"variation_size", look.variation_size)
	m.set_shader_parameter(&"grime_height", look.grime_height)
	m.set_shader_parameter(&"grime_strength", look.grime_strength)
	return m


## `m`'s blocks (as the greybox draws them: no see-through block, no bar railing's box), the ground beyond the walls,
## its station's strips, words, track and vaults, each face in its finish. A block `props` draws as its model (SD1:
## one naming a model, PropDressConfig.named_only) is left out, its model standing in its box; a lined (TILE) or cored
## one keeps its box. A block in a vault's colliders (StationDressing.in_vault) is left out, the vault drawn instead.
static func mesh(m: MapData, style: MapStyle, look: StationLook, props: PropDressConfig = null) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var dress := m.station
	# a train's walls, slabs and car ends are its models' (SM1, TrainView) when they all load
	var trains := _trains_drawn(m, look)
	var faced: Array[AABB] = []
	for b in m.blocks:
		if not faces_drawn(b, m, style, props, trains):
			continue
		faced.append(AABB(b.center - b.size * 0.5, b.size))
		var own := dress.owner_of(b)
		var bottom := b.center.y - b.size.y * 0.5
		for whole in GreyboxFaces.faces_of(b):
			for f in bands(dress, look, whole):
				var zone := zone_faced(dress, look, f)
				var finish := look.finish_of(b, GreyboxFaces.face_normal(f), zone.style if zone != null else &"", own)
				var floor_y := zone.box.position.y if zone != null else bottom
				var round := _train_round(trains, zone)
				if round != null:
					# a wall's face standing flush past a train's box, looking into its cars: the box's lining
					var lined := _round_finish(look, dress, round.box, f)
					finish = lined.finish
					floor_y = lined.floor_y
				add_face(st, look, f, finish, look.tint_of(finish, b), floor_y)
	var top := GreyboxFaces.ground_top(m)
	add_face(st, look, GreyboxFaces.ground_face(style, top), look.outside, look.tint_of(look.outside, null), NO_FLOOR)
	for s in dress.strips:
		var y := s.y + look.strip_lift
		var a := s.area
		var quad := PackedVector3Array([Vector3(a.position.x, y, a.position.y), Vector3(a.position.x, y, a.end.y),
				Vector3(a.end.x, y, a.end.y), Vector3(a.end.x, y, a.position.y)])
		add_face(st, look, quad, s.finish, look.tint_of(s.finish, null), NO_FLOOR)
	for w in dress.words:
		PlatformWords.add(st, look, w)
	for t in dress.trims:
		var tint := look.tint_of(t.finish, null)
		for f in GreyboxFaces.box_faces(t.box.position, t.box.end):
			add_face(st, look, f, t.finish, tint, NO_FLOOR)
	for t in dress.tracks:
		_add_track(st, look, t)
	for t in trains:
		for l in lining(look, dress, t.box, faced):
			add_face(st, look, l.face(), l.finish, look.tint_of(l.finish, null), l.floor_y)
	for v in dress.vaults:
		add_vault(st, look, v)
	st.generate_tangents()
	return st.commit()


## The trains on `m` whose walls, slabs and car ends are their models' (SM1, TrainView): all, when the models load.
static func _trains_drawn(m: MapData, look: StationLook) -> Array[TrainDressing]:
	var trains: Array[TrainDressing] = []
	if look.trains != null and look.trains.loads():
		trains = m.trains
	return trains


## Whether `m`'s block `b` is drawn as its faces (mesh): not see-through, not a bar railing's box, not a model `props`
## draws, not in a vault's colliders and not held by one of `trains`.
static func faces_drawn(b: MapData.Block, m: MapData, style: MapStyle, props: PropDressConfig,
		trains: Array[TrainDressing]) -> bool:
	if style.is_clear(b.kind) or (style.is_railing(b.kind) and b.rise == MapData.Rise.NONE):
		return false
	if props != null and props.dresses(b) and props.lay_of(b) != PropDressConfig.Lay.TILE \
			and props.core_of(b) == Vector2.ZERO:
		return false
	if not m.station.vaults.is_empty() and m.station.in_vault(AABB(b.center - b.size * 0.5, b.size)):
		return false
	return not held(trains, b)


## The boxes of `m`'s blocks drawn as their faces (mesh, `faces_drawn`).
static func faced_boxes(m: MapData, style: MapStyle, look: StationLook, props: PropDressConfig = null) -> Array[AABB]:
	var trains := _trains_drawn(m, look)
	var out: Array[AABB] = []
	for b in m.blocks:
		if faces_drawn(b, m, style, props, trains):
			out.append(AABB(b.center - b.size * 0.5, b.size))
	return out


## Train box `box`'s lining (SM1): where its long sides, its top or its foot border no room (the ground round a
## running tunnel hugging the train, the trackside wall, under the bed), that side drawn facing into the box in the
## finish of the tunnel round it, so the round car seen past its ends' corners stands in its tunnel, not over a hole.
## The ends are left open (a train's track goes on beyond them). Each side is cut where a room (`dress`'s zones)
## starts or stops along it, and a cut is drawn only where no room lies just past it and no block of `faced` (the
## blocks drawn as their faces, `faced_boxes`) stands flush past it, its own face drawn there already.
static func lining(look: StationLook, dress: StationDressing, box: AABB, faced: Array[AABB] = []) -> Array[Lining]:
	var out: Array[Lining] = []
	for side: Vector3i in [Vector3i(2, 0, 1), Vector3i(2, 1, 1), Vector3i(1, 1, 2), Vector3i(1, 0, 2)]:
		var axis := side.x
		var out_dir := 1.0 if side.y == 1 else -1.0
		var at := box.end[axis] if side.y == 1 else box.position[axis]
		var other := side.z
		var flush := _flush(faced, box, axis, at, out_dir)
		var us := _cuts(dress, flush, box, axis, at, 0)
		var vs := _cuts(dress, flush, box, axis, at, other)
		for j in vs.size() - 1:
			var run: Lining = null
			for i in us.size() - 1:
				var mid := box.get_center()
				mid.x = (us[i] + us[i + 1]) * 0.5
				mid[other] = (vs[j] + vs[j + 1]) * 0.5
				mid[axis] = at + out_dir * look.probe
				if dress.zone_at(mid) != null or flush.any(func(f: AABB) -> bool: return f.has_point(mid)):
					run = null
					continue
				var past := _past_end(look, dress, box, mid)
				var zone := _tunnel_over(look, dress, box, axis, at, out_dir, mid)
				var finish := _lining_finish(look, zone if zone != null else past, axis, out_dir)
				var floor_y := past.box.position.y if past != null else NO_FLOOR
				if run != null and run.finish == finish and is_equal_approx(run.floor_y, floor_y):
					run.to = us[i + 1]
				else:
					run = Lining.new()
					run.finish = finish
					run.floor_y = floor_y
					run.from = us[i]
					run.to = us[i + 1]
					run.axis = axis
					run.at = at
					run.inward = -out_dir
					run.other = other
					run.lo = vs[j]
					run.hi = vs[j + 1]
					out.append(run)
	return _merged(out)


## Stretches `rows` with each one that the next row up carries on (the same span along x, in the same plane and finish)
## grown to take that one in.
static func _merged(rows: Array[Lining]) -> Array[Lining]:
	var out: Array[Lining] = []
	for r in rows:
		var below: Lining = null
		for o in out:
			if o.axis == r.axis and o.at == r.at and o.finish == r.finish and o.floor_y == r.floor_y \
					and is_equal_approx(o.from, r.from) and is_equal_approx(o.to, r.to) and is_equal_approx(o.hi, r.lo):
				below = o
				break
		if below != null:
			below.hi = r.hi
		else:
			out.append(r)
	return out


## One drawn stretch of a train box's lining: along x from `from` to `to`, across `other` (y on a side, z on the top
## or the foot) from `lo` to `hi`, in the plane `axis` = `at`, facing `inward` along `axis`.
class Lining:
	extends RefCounted
	var finish: StringName = &""
	var floor_y: float = 0.0
	var from: float = 0.0
	var to: float = 0.0
	var axis: int = 2
	var at: float = 0.0
	var inward: float = 1.0
	var other: int = 1
	var lo: float = 0.0
	var hi: float = 0.0

	## The stretch as a quad, anticlockwise seen from inside the box (add_face's front).
	func face() -> PackedVector3Array:
		var f := PackedVector3Array()
		for c: Vector2 in [Vector2(from, lo), Vector2(to, lo), Vector2(to, hi), Vector2(from, hi)]:
			var p := Vector3.ZERO
			p.x = c.x
			p[other] = c.y
			p[axis] = at
			f.append(p)
		var want := Vector3.ZERO
		want[axis] = inward
		if GreyboxFaces.face_normal(f).dot(want) < 0.0:
			f.reverse()
		return f


## The boxes of `faced` standing flush past box `box`'s side in the plane `axis` = `at` (on its `out_dir` side), their
## faces in it.
static func _flush(faced: Array[AABB], box: AABB, axis: int, at: float, out_dir: float) -> Array[AABB]:
	var out: Array[AABB] = []
	var reach := box.grow(0.01)
	for f in faced:
		var near := f.position[axis] if out_dir > 0.0 else f.end[axis]
		if absf(near - at) < 0.002 and f.intersects(reach):
			out.append(f)
	return out


## Where box `box`'s side in the plane `axis` = `at` is cut along `along`: its own ends and every zone's edge between
## them, of the zones within LINING_REACH of that side, and every edge of a `flush` block's face.
static func _cuts(dress: StationDressing, flush: Array[AABB], box: AABB, axis: int, at: float,
		along: int) -> PackedFloat32Array:
	var lo := box.position[along]
	var hi := box.end[along]
	var near := box.grow(0.05)
	near.position[axis] = at - LINING_REACH
	near.size[axis] = LINING_REACH * 2.0
	var out := PackedFloat32Array([lo, hi])
	for z in dress.zones:
		if not z.box.intersects(near):
			continue
		for v: float in [z.box.position[along], z.box.end[along]]:
			if v > lo + 0.001 and v < hi - 0.001 and not out.has(v):
				out.append(v)
	for f in flush:
		for v: float in [f.position[along], f.end[along]]:
			if v > lo + 0.001 and v < hi - 0.001 and not out.has(v):
				out.append(v)
	out.sort()
	return out


## The train of `trains` whose box holds zone `zone` (its cars' room), or null.
static func _train_round(trains: Array[TrainDressing], zone: StationDressing.Zone) -> TrainDressing:
	if zone == null:
		return null
	for t in trains:
		if t.box.grow(0.01).encloses(zone.box):
			return t
	return null


## The finish and grime floor of face `f`, standing in the side of train box `box` and looking into it, as the box's
## lining has them there (`lining`): a block's face the lining leaves to it (flush past the box) matches the lining.
static func _round_finish(look: StationLook, dress: StationDressing, box: AABB, f: PackedVector3Array) -> Lining:
	var n := GreyboxFaces.face_normal(f)
	var axis := 0
	for k in 3:
		if absf(n[k]) > absf(n[axis]):
			axis = k
	var out_dir := -signf(n[axis])
	var mid := _middle(f)
	var past := _past_end(look, dress, box, mid)
	var over := _tunnel_over(look, dress, box, axis, mid[axis], out_dir, mid) if axis != 0 else null
	var out := Lining.new()
	out.finish = _lining_finish(look, over if over != null else past, axis, out_dir)
	out.floor_y = past.box.position.y if past != null else NO_FLOOR
	return out


## The platform tunnel over box `box` at the side of a lining stretch at `mid` (just past the side): the room over the
## box there (a platform tunnel's vault over the train), or null where the box is buried (a running tunnel).
static func _tunnel_over(look: StationLook, dress: StationDressing, box: AABB, axis: int, at: float, out_dir: float,
		mid: Vector3) -> StationDressing.Zone:
	var over := mid
	over.y = box.end.y + look.probe
	if axis == 2:
		over.z = at - out_dir * look.probe
	return dress.zone_at(over)


## The room past box `box`'s end nearer `mid` (the track or the running tunnel the train stands in), or null.
static func _past_end(look: StationLook, dress: StationDressing, box: AABB, mid: Vector3) -> StationDressing.Zone:
	var past := mid
	past.x = box.end.x + look.probe if mid.x > box.get_center().x else box.position.x - look.probe
	past.y = clampf(mid.y, box.position.y + LINING_INSET, box.end.y - LINING_INSET)
	past.z = clampf(mid.z, box.position.z + look.probe, box.end.z - look.probe)
	return dress.zone_at(past)


## A lining stretch's finish: the tunnel's walls on a side, its ceiling over the top, its floor at the foot (none:
## the vaults' finish).
static func _lining_finish(look: StationLook, zone: StationDressing.Zone, axis: int, out_dir: float) -> StringName:
	var style := zone.style if zone != null else &""
	if axis == 1:
		var table: Dictionary[StringName, StringName] = look.style_ceilings if out_dir > 0.0 else look.style_floors
		return table.get(style, look.vault_finish)
	return look.style_walls.get(style, look.vault_finish)


## Whether one of `trains` holds block `b` (TrainDressing.holds), its models drawing it.
static func held(trains: Array[TrainDressing], b: MapData.Block) -> bool:
	for t in trains:
		if t.holds(b):
			return true
	return false


## Appends face `f` (a convex polygon, anticlockwise seen from outside) in `finish`, tinted `tint` (sRGB), its room's
## floor at `floor_y` (where a wall's foot grime starts).
static func add_face(st: SurfaceTool, look: StationLook, f: PackedVector3Array, finish: StringName, tint: Color,
		floor_y: float) -> void:
	var n := GreyboxFaces.face_normal(f)
	var pbr := look.pbr_of(finish)
	st.set_normal(n)
	st.set_color(tint.srgb_to_linear())
	st.set_custom(0, Color(float(look.layer_of(finish)), pbr.y, pbr.x, floor_y))
	var size := look.scale_of(finish)
	for i in range(1, f.size() - 1):
		for p: Vector3 in [f[0], f[i + 1], f[i]]:
			st.set_uv(plane_uv(p, n) / size)
			st.add_vertex(p)


## Appends vault `v`: its arc in `vault_steps` strips along its length, each vertex's normal pointing at the arc's
## middle (smooth), the texture running along x and round the arc; and its two ends, each the shape between the arc
## and its springing, `vault_proud` m in front of the shell's end behind it.
static func add_vault(st: SurfaceTool, look: StationLook, v: StationDressing.TunnelVault) -> void:
	var steps := maxi(look.vault_steps, 2)
	var half := v.half_angle()
	var c := v.circle()
	var x0 := v.area.position.x
	var x1 := v.area.end.x
	var finish := look.vault_finish
	var tint := look.tint_of(finish, null)
	var pbr := look.pbr_of(finish)
	var size := look.scale_of(finish)
	st.set_color(tint.srgb_to_linear())
	st.set_custom(0, Color(float(look.layer_of(finish)), pbr.y, pbr.x, NO_FLOOR))
	for k in steps:
		var a := -half + 2.0 * half * float(k) / float(steps)
		var b := -half + 2.0 * half * float(k + 1) / float(steps)
		var pa := v.point(a)
		var pb := v.point(b)
		var na := Vector3(0.0, -cos(a), -sin(a))
		var nb := Vector3(0.0, -cos(b), -sin(b))
		var sa := c.z * a
		var sb := c.z * b
		# The quad faces up (GreyboxFaces.face_normal), so its triangles are add_face's order reversed: drawn facing
		# down into the tunnel.
		var quad: Array[Vector3] = [Vector3(x0, pa.y, pa.x), Vector3(x0, pb.y, pb.x), Vector3(x1, pb.y, pb.x),
				Vector3(x1, pa.y, pa.x)]
		var normals: Array[Vector3] = [na, nb, nb, na]
		var uvs: Array[Vector2] = [Vector2(x0, sa), Vector2(x0, sb), Vector2(x1, sb), Vector2(x1, sa)]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(normals[i])
			st.set_uv(uvs[i] / size)
			st.add_vertex(quad[i])
	_add_ribs(st, look, v)
	for end: float in [x0 + look.vault_proud, x1 - look.vault_proud]:
		var cap := PackedVector3Array()
		for k in steps + 1:
			var p := v.point(-half + 2.0 * half * float(k) / float(steps))
			cap.append(Vector3(end, p.y, p.x))
		# Facing into the tunnel: +x at its west end, -x at its east.
		if (GreyboxFaces.face_normal(cap).x > 0.0) != (end < v.area.get_center().x):
			cap.reverse()
		add_face(st, look, cap, finish, tint, NO_FLOOR)


## Vault `v`'s ribs: a band `vault_rib_width` m wide round the arc every `vault_rib_every` m along it, standing
## `vault_rib_depth` m under it (the tunnel's lining rings), its underside and both sides drawn.
static func _add_ribs(st: SurfaceTool, look: StationLook, v: StationDressing.TunnelVault) -> void:
	if look.vault_rib_every <= 0.0 or look.vault_rib_width <= 0.0 or look.vault_rib_depth <= 0.0:
		return
	var steps := maxi(look.vault_steps, 2)
	var half := v.half_angle()
	var c := v.circle()
	var inner := c.z - look.vault_rib_depth
	var finish := look.vault_rib_finish
	var tint := look.tint_of(finish, null)
	var length := v.area.size.x
	var count := floori((length - look.vault_rib_width) / look.vault_rib_every)
	var first := v.area.position.x + (length - float(count) * look.vault_rib_every) * 0.5
	for n in count + 1:
		var xa := first + float(n) * look.vault_rib_every - look.vault_rib_width * 0.5
		var xb := xa + look.vault_rib_width
		for k in steps:
			var a := -half + 2.0 * half * float(k) / float(steps)
			var b := -half + 2.0 * half * float(k + 1) / float(steps)
			var ia := Vector2(c.x + inner * sin(a), c.y + inner * cos(a))
			var ib := Vector2(c.x + inner * sin(b), c.y + inner * cos(b))
			var oa := v.point(a)
			var ob := v.point(b)
			# its underside, facing the tunnel's middle (each face anticlockwise seen from the side it faces)
			_add_facing(st, look, [Vector3(xa, ia.y, ia.x), Vector3(xa, ib.y, ib.x), Vector3(xb, ib.y, ib.x),
					Vector3(xb, ia.y, ia.x)], Vector3(0.0, -cos((a + b) * 0.5), -sin((a + b) * 0.5)), finish, tint)
			for side: float in [xa, xb]:
				_add_facing(st, look, [Vector3(side, oa.y, oa.x), Vector3(side, ob.y, ob.x), Vector3(side, ib.y, ib.x),
						Vector3(side, ia.y, ia.x)], Vector3(signf(side - (xa + xb) * 0.5), 0.0, 0.0), finish, tint)


## Appends quad `q` in `finish` facing `toward` (its corners' order turned round when they face away).
static func _add_facing(st: SurfaceTool, look: StationLook, q: Array[Vector3], toward: Vector3, finish: StringName,
		tint: Color) -> void:
	var f := PackedVector3Array(q)
	if GreyboxFaces.face_normal(f).dot(toward) < 0.0:
		f.reverse()
	add_face(st, look, f, finish, tint, NO_FLOOR)


## Point `p`'s place (m) on the plane of a face facing `n`: a floor or ceiling's x and z, a wall's along and up (up the
## texture's up, each wall read as from the room it faces).
static func plane_uv(p: Vector3, n: Vector3) -> Vector2:
	var a := n.abs()
	if a.y >= a.x and a.y >= a.z:
		return Vector2(p.x, p.z)
	if a.x >= a.z:
		return Vector2(-p.z if n.x > 0.0 else p.z, -p.y)
	return Vector2(p.x if n.z > 0.0 else -p.x, -p.y)


## Face `f` cut where the rooms it faces change, one band a room: a wall's upright rectangle spanning storeys (a lift
## shaft's) is cut at each room's floor and ceiling it passes; any other face is itself.
static func bands(dress: StationDressing, look: StationLook, f: PackedVector3Array) -> Array[PackedVector3Array]:
	var n := GreyboxFaces.face_normal(f)
	var box := AABB(f[0], Vector3.ZERO)
	for p in f:
		box = box.expand(p)
	if f.size() != 4 or absf(n.y) > 0.01 or not _upright(f):
		return [f]
	var cuts := dress.levels_across(AABB(box.position + n * look.probe, box.size))
	if cuts.is_empty():
		return [f]
	var out: Array[PackedVector3Array] = []
	var lo := box.position.y
	cuts.append(box.end.y)
	for y in cuts:
		var band := PackedVector3Array()
		for p in f:
			band.append(Vector3(p.x, lo if p.y < box.get_center().y else y, p.z))
		out.append(band)
		lo = y
	return out


## Whether quad `f`'s corners stand at two heights only, the bottom pair and the top pair (an upright rectangle).
static func _upright(f: PackedVector3Array) -> bool:
	var lo := minf(minf(f[0].y, f[1].y), minf(f[2].y, f[3].y))
	var hi := maxf(maxf(f[0].y, f[1].y), maxf(f[2].y, f[3].y))
	for p in f:
		if absf(p.y - lo) > 0.001 and absf(p.y - hi) > 0.001:
			return false
	return hi - lo > 0.001


## The zone face `f` looks into (its middle `probe` m out along its normal), or null when it faces no room.
static func zone_faced(dress: StationDressing, look: StationLook, f: PackedVector3Array) -> StationDressing.Zone:
	return dress.zone_at(_middle(f) + GreyboxFaces.face_normal(f) * look.probe)


## The finish block `b`'s face `f` (or one of its `bands`) is drawn in on map `m` (its station dress).
static func finish_of_face(m: MapData, look: StationLook, b: MapData.Block, f: PackedVector3Array) -> StringName:
	var zone := zone_faced(m.station, look, f)
	return look.finish_of(b, GreyboxFaces.face_normal(f), zone.style if zone != null else &"", m.station.owner_of(b))


static func _middle(f: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for p in f:
		sum += p
	return sum / float(f.size())


## A stretch of track: two rails end to end on the ballast (on sleepers every `sleeper_pitch` m if the look has them).
static func _add_track(st: SurfaceTool, look: StationLook, t: StationDressing.Track) -> void:
	var along := t.to - t.from
	var length := along.length()
	if length <= 0.0:
		return
	var x := Vector3(along.x, 0.0, along.y) / length
	var frame := Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), Vector3(t.from.x, t.y, t.from.y))
	var base := 0.0
	if look.sleepers:
		var sl := look.sleeper_size
		base = sl.y
		var count := maxi(1, floori(length / look.sleeper_pitch))
		var start := (length - float(count - 1) * look.sleeper_pitch) * 0.5
		for i in count:
			var at := start + float(i) * look.sleeper_pitch
			_add_box(st, look, frame, Vector3(at - sl.z * 0.5, 0.0, -sl.x * 0.5),
					Vector3(at + sl.z * 0.5, sl.y, sl.x * 0.5), &"sleeper")
	var r := look.rail_size
	for side: float in [-0.5, 0.5]:
		var z := side * look.gauge
		_add_box(st, look, frame, Vector3(0.0, base, z - r.x * 0.5), Vector3(length, base + r.y, z + r.x * 0.5), &"rail")


static func _add_box(st: SurfaceTool, look: StationLook, frame: Transform3D, lo: Vector3, hi: Vector3,
		finish: StringName) -> void:
	var tint := look.tint_of(finish, null)
	for f in GreyboxFaces.box_faces(lo, hi):
		# the underside lies on the ballast, seen by no one
		if GreyboxFaces.face_normal(f).y < -0.5:
			continue
		add_face(st, look, frame * f, finish, tint, NO_FLOOR)

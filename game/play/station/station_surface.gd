class_name StationSurface
extends RefCounted
## A station dress's surfaces (MT3, Subway): the level's very block faces (GreyboxFaces, in its order) drawn in the
## CC0 photo sets StationLook gives each face, with the platforms' edge strips and the track's rails and sleepers, as
## one mesh in one material (station_surface.gdshader). MapLevel draws it in place of the greybox's mesh; the colliders,
## the nav, the shadow's shape and the sight lines are the blocks', unchanged: a strip lies `strip_lift` over its floor
## and the track's rails and sleepers are scenery (no collider). Static functions only; build time, never per frame.

const SHADER := preload("res://game/play/station/station_surface.gdshader")
## A face looking into no room grimes from nowhere: its floor this far below.
const NO_FLOOR := -1000.0


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
## its station's strips and its track, each face in its finish. A block `props` draws as its model (SD1: one naming a
## model, PropDressConfig.named_only) is left out, its model standing in its box; a lined (TILE) or cored one keeps
## its box.
static func mesh(m: MapData, style: MapStyle, look: StationLook, props: PropDressConfig = null) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var dress := m.station
	for b in m.blocks:
		if style.is_clear(b.kind) or (style.is_railing(b.kind) and b.rise == MapData.Rise.NONE):
			continue
		if props != null and props.dresses(b) and props.lay_of(b) != PropDressConfig.Lay.TILE \
				and props.core_of(b) == Vector2.ZERO:
			continue
		var own := dress.owner_of(b)
		var bottom := b.center.y - b.size.y * 0.5
		for whole in GreyboxFaces.faces_of(b):
			for f in bands(dress, look, whole):
				var zone := zone_faced(dress, look, f)
				var finish := look.finish_of(b, GreyboxFaces.face_normal(f), zone.style if zone != null else &"", own)
				var floor_y := zone.box.position.y if zone != null else bottom
				add_face(st, look, f, finish, look.tint_of(finish, b), floor_y)
	var top := GreyboxFaces.ground_top(m)
	add_face(st, look, GreyboxFaces.ground_face(style, top), look.outside, look.tint_of(look.outside, null), NO_FLOOR)
	for s in dress.strips:
		var y := s.y + look.strip_lift
		var a := s.area
		var quad := PackedVector3Array([Vector3(a.position.x, y, a.position.y), Vector3(a.position.x, y, a.end.y),
				Vector3(a.end.x, y, a.end.y), Vector3(a.end.x, y, a.position.y)])
		add_face(st, look, quad, s.finish, look.tint_of(s.finish, null), NO_FLOOR)
	for t in dress.tracks:
		_add_track(st, look, t)
	st.generate_tangents()
	return st.commit()


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


## A stretch of track: sleepers every `sleeper_pitch` m on the ballast and two rails along them, end to end.
static func _add_track(st: SurfaceTool, look: StationLook, t: StationDressing.Track) -> void:
	var along := t.to - t.from
	var length := along.length()
	if length <= 0.0:
		return
	var x := Vector3(along.x, 0.0, along.y) / length
	var frame := Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), Vector3(t.from.x, t.y, t.from.y))
	var sl := look.sleeper_size
	var count := maxi(1, floori(length / look.sleeper_pitch))
	var start := (length - float(count - 1) * look.sleeper_pitch) * 0.5
	for i in count:
		var at := start + float(i) * look.sleeper_pitch
		_add_box(st, look, frame, Vector3(at - sl.z * 0.5, 0.0, -sl.x * 0.5), Vector3(at + sl.z * 0.5, sl.y, sl.x * 0.5),
				&"sleeper")
	var r := look.rail_size
	for side: float in [-0.5, 0.5]:
		var z := side * look.gauge
		_add_box(st, look, frame, Vector3(0.0, sl.y, z - r.x * 0.5), Vector3(length, sl.y + r.y, z + r.x * 0.5), &"rail")


static func _add_box(st: SurfaceTool, look: StationLook, frame: Transform3D, lo: Vector3, hi: Vector3,
		finish: StringName) -> void:
	var tint := look.tint_of(finish, null)
	for f in GreyboxFaces.box_faces(lo, hi):
		# the underside lies on the ballast, seen by no one
		if GreyboxFaces.face_normal(f).y < -0.5:
			continue
		add_face(st, look, frame * f, finish, tint, NO_FLOOR)

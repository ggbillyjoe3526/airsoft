class_name SiteDress
extends Node3D
## A site-dressed map's details (DD1, Depot's temporary dress until the owner's models): what stands a little proud of
## the blocks MapLevel draws in the site's material (a container's corner posts, rails and lock bars, a crate's
## battens, a plywood sheet's timber cap, the perimeter wall's coping, the skip's rim), the watch tower's camouflage net
## and flag, the map's shade sails (SiteDressing), all as one mesh in the same material; sandbags laid bag by bag in
## each stack round its own box, drawn smaller under them (SiteSurface.core_of; one MultiMesh); the CC0 props in place
## of some kinds' boxes (PropDress, DR2); and each zone's name stencilled on its wall.
## Scenery only: no collider, no nav cell; every detail stays within `proud` (a bag `bag_bulge`) of its block's box.
## `dress_sky` gives the day its cumulus and haze.

const SKY_SHADER := preload("res://game/play/site/site_sky.gdshader")
## The stencils' font weight and size (px, the glyphs' raster; a stencil is scaled to its height).
const STENCIL_WEIGHT := 800
const STENCIL_PIXELS := 128
## A sandbag's mesh: a sphere this coarse, scaled to the bag.
const BAG_SEGMENTS := 8
const BAG_RINGS := 4
## A bag's jitter: its turn (rad) and shade either way.
const BAG_TURN := 0.04
const BAG_SHADE := 0.08

var _details: MeshInstance3D = null
var _bags: MultiMeshInstance3D = null
var _props: PropDress = null
var _stencils: Array[Label3D] = []


## The dress of `map` in `look`, its details in `material` (MapLevel.site_material); null for a map naming no site
## dress. Add it to the tree beside the level.
static func build(map: MapData, look: SiteLook, material: ShaderMaterial) -> SiteDress:
	if map.site == null or look == null or material == null:
		return null
	var dress := SiteDress.new()
	dress.name = "SiteDress"
	dress._build(map, look, material)
	return dress


## The day's sky over a site-dressed map: the gradient and soft cumulus (site_sky.gdshader) in `look`'s colours, and
## a depth haze so the skyline sits back. Leave the night's sky as it is.
static func dress_sky(lighting: FieldLighting, look: SiteLook) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SKY_SHADER
	mat.set_shader_parameter(&"top", look.sky_top)
	mat.set_shader_parameter(&"horizon", look.sky_horizon)
	mat.set_shader_parameter(&"below", look.sky_below)
	mat.set_shader_parameter(&"cloud_lit", look.cloud_lit)
	mat.set_shader_parameter(&"cloud_shade", look.cloud_shade)
	mat.set_shader_parameter(&"cover", look.cloud_cover)
	mat.set_shader_parameter(&"softness", look.cloud_softness)
	mat.set_shader_parameter(&"cloud_scale", look.cloud_scale)
	mat.set_shader_parameter(&"fbm_tex", SiteSurface.fbm_texture())
	var env := lighting.environment
	env.sky.sky_material = mat
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = look.haze_colour
	env.fog_density = look.haze_density
	env.fog_depth_begin = look.haze_from
	env.fog_depth_end = look.haze_to
	env.fog_sky_affect = 0.0


## The details' mesh, the bags (null without sandbags) and the stencils, for the tests and the budget census.
func details() -> MeshInstance3D:
	return _details


func bags() -> MultiMeshInstance3D:
	return _bags


func stencils() -> Array[Label3D]:
	return _stencils


## The CC0 props (DR2), or null on a map with none.
func props() -> PropDress:
	return _props


## The materials the dress draws in, for the shader prewarm (the bags' come into view only near).
func materials() -> Array[Material]:
	var out: Array[Material] = [_details.material_override]
	if _bags != null:
		out.append(_bags.material_override)
	if _props != null:
		out.append_array(_props.materials())
	return out


func _build(map: MapData, look: SiteLook, material: ShaderMaterial) -> void:
	var st := SiteSurface.begin()
	for b in map.blocks:
		if b.rise != MapData.Rise.NONE:
			continue
		match look.finish_of(b):
			&"container":
				_container(st, look, b)
			&"crate":
				_crate(st, look, b)
			&"plywood":
				_cap(st, look, b, look.cap, &"timber")
			&"wall_outer":
				_cap(st, look, b, look.coping, &"coping")
			&"skip":
				_skip(st, look, b)
	for p in map.skyline:
		if p.kind == &"watchTower":
			_tower(st, look, p)
	for s in map.site.sails:
		_sail(st, look, s)
	_details = MeshInstance3D.new()
	_details.name = "Details"
	_details.mesh = st.commit()
	_details.material_override = material
	add_child(_details)
	_lay_bags(map, look)
	_props = PropDress.build(map, look.props)
	if _props != null:
		add_child(_props)
	var font := GameTheme.font(STENCIL_WEIGHT)
	for s in map.site.stencils:
		_stencil(look, s, font, stencil_paint(map, look, s))


## A container's frame, unit by unit and tier by tier: four corner posts, the rails along its long sides and, at its
## far end, four lock bars, in its unit's paint a shade darker.
func _container(st: SurfaceTool, look: SiteLook, b: MapData.Block) -> void:
	var along_x := b.size.x >= b.size.z
	var split := look.container_split_of(b)
	var length := b.size.x if along_x else b.size.z
	var unit := length / float(split.x)
	var tier := b.size.y / float(split.y)
	var foot := b.center.y - b.size.y * 0.5
	var p := look.proud
	for t in split.y:
		for u in split.x:
			var c := b.center
			c.y = foot + tier * (float(t) + 0.5)
			var offset := -length * 0.5 + unit * (float(u) + 0.5)
			var size := Vector3(unit, tier, b.size.z) if along_x else Vector3(b.size.x, tier, unit)
			if along_x:
				c.x += offset
			else:
				c.z += offset
			var h := size * 0.5
			var paint := look.container_colour(b.piece, u, t).srgb_to_linear() * look.frame_shade
			var flags := SiteSurface.FLAG_TINT
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var at := c + Vector3((h.x + p - look.post * 0.5) * sx, 0.0, (h.z + p - look.post * 0.5) * sz)
					SiteSurface.add_box(st, look, at, Vector3(look.post, size.y, look.post), &"frame", flags, paint)
			for sy: float in [-1.0, 1.0]:
				for side: float in [-1.0, 1.0]:
					var y := (h.y + p - look.rail * 0.5) * sy
					if along_x:
						SiteSurface.add_box(st, look, c + Vector3(0.0, y, (h.z + p - look.rail * 0.5) * side),
								Vector3(size.x - look.post * 2.0, look.rail, look.rail), &"frame", flags, paint)
					else:
						SiteSurface.add_box(st, look, c + Vector3((h.x + p - look.rail * 0.5) * side, y, 0.0),
								Vector3(look.rail, look.rail, size.z - look.post * 2.0), &"frame", flags, paint)
			if u == split.x - 1:
				_lock_bars(st, look, c, size, along_x)


## Four lock bars down a container's door end (its +x or +z end).
func _lock_bars(st: SurfaceTool, look: SiteLook, c: Vector3, size: Vector3, along_x: bool) -> void:
	var h := size * 0.5
	var bar := look.lock_bar
	var out := h.x + look.proud - bar * 0.5 if along_x else h.z + look.proud - bar * 0.5
	var across := size.z if along_x else size.x
	for i in 4:
		var a := -across * 0.5 + across * (0.2 + 0.2 * float(i))
		var at := c + (Vector3(out, 0.0, a) if along_x else Vector3(a, 0.0, out))
		SiteSurface.add_box(st, look, at, Vector3(bar, size.y - look.rail * 2.0, bar), &"steel", 0)


## A crate's battens along its twelve edges.
func _crate(st: SurfaceTool, look: SiteLook, b: MapData.Block) -> void:
	var s := b.size
	var t := look.batten
	var e := s * 0.5 + Vector3.ONE * (look.proud - t * 0.5)
	for a: float in [-1.0, 1.0]:
		for c: float in [-1.0, 1.0]:
			SiteSurface.add_box(st, look, b.center + Vector3(0.0, e.y * a, e.z * c), Vector3(s.x - t * 2.0, t, t),
					&"timber", 0)
			SiteSurface.add_box(st, look, b.center + Vector3(e.x * a, 0.0, e.z * c), Vector3(t, s.y + look.proud * 2.0, t),
					&"timber", 0)
			SiteSurface.add_box(st, look, b.center + Vector3(e.x * a, e.y * c, 0.0), Vector3(t, t, s.z - t * 2.0),
					&"timber", 0)


## A cap `thick` m deep along a block's top, `proud` over each side and its top.
func _cap(st: SurfaceTool, look: SiteLook, b: MapData.Block, thick: float, finish: StringName) -> void:
	var top := b.center.y + b.size.y * 0.5
	var size := Vector3(b.size.x + look.proud * 2.0, thick, b.size.z + look.proud * 2.0)
	SiteSurface.add_box(st, look, Vector3(b.center.x, top + look.proud - thick * 0.5, b.center.z), size, finish, 0)


## The skip's rim: a rail round its top in its paint a shade darker.
func _skip(st: SurfaceTool, look: SiteLook, b: MapData.Block) -> void:
	var paint := (look.paints[&"skip"] as Color).srgb_to_linear() * look.frame_shade
	var r := look.rail
	var e := b.size * 0.5 + Vector3.ONE * (look.proud - r * 0.5)
	for side: float in [-1.0, 1.0]:
		SiteSurface.add_box(st, look, b.center + Vector3(0.0, e.y, e.z * side), Vector3(b.size.x, r, r), &"frame",
				SiteSurface.FLAG_TINT, paint)
		SiteSurface.add_box(st, look, b.center + Vector3(e.x * side, e.y, 0.0), Vector3(r, r, b.size.z - r * 2.0),
				&"frame", SiteSurface.FLAG_TINT, paint)


## The watch tower (SkylinePiece, out of reach): camouflage netting over its roof with a skirt round it, and a flag in
## site colours on a pole.
func _tower(st: SurfaceTool, look: SiteLook, p: SkylinePiece) -> void:
	var c := Vector3(p.at.x, p.height, p.at.y)
	var roof := Vector3(p.width + look.net_overhang * 2.0, look.proud * 8.0, p.depth + look.net_overhang * 2.0)
	SiteSurface.add_box(st, look, c + Vector3(0.0, roof.y * 0.5, 0.0), roof, &"net", 0)
	var drop := c.y - look.net_skirt * 0.5
	for side: float in [-1.0, 1.0]:
		SiteSurface.add_box(st, look, Vector3(c.x, drop, c.z + roof.z * 0.5 * side),
				Vector3(roof.x, look.net_skirt, look.proud * 2.0), &"net", 0)
		SiteSurface.add_box(st, look, Vector3(c.x + roof.x * 0.5 * side, drop, c.z),
				Vector3(look.proud * 2.0, look.net_skirt, roof.z), &"net", 0)
	var pole := c + Vector3(p.width * 0.4, roof.y, 0.0)
	var thick := look.sail_post * 0.75
	SiteSurface.add_box(st, look, pole + Vector3(0.0, look.flag_pole * 0.5, 0.0),
			Vector3(thick, look.flag_pole, thick), &"steel", 0)
	var flag := pole + Vector3(look.flag_size.x * 0.5 + thick * 0.5, look.flag_pole - look.flag_size.y * 0.5, 0.0)
	SiteSurface.add_box(st, look, flag, Vector3(look.flag_size.x, look.flag_size.y, look.proud * 2.0), &"flag", 0)


## A shade sail: the cloth both ways up, and a post under each corner that has one.
func _sail(st: SurfaceTool, look: SiteLook, s: SiteDressing.Sail) -> void:
	var a := s.corners[0]
	var b := s.corners[1]
	var c := s.corners[2]
	var lo := a.min(b).min(c)
	var hi := a.max(b).max(c)
	var cu := SiteSurface.customs(look, (lo + hi) * 0.5, (hi - lo) * 0.5, &"sail", SiteSurface.FLAG_NO_BEVEL)
	st.set_color(Color.WHITE)
	st.set_custom(0, cu[0])
	st.set_custom(1, cu[1])
	SiteSurface.add_face(st, PackedVector3Array([a, b, c]))
	SiteSurface.add_face(st, PackedVector3Array([a, c, b]))
	if s.post <= 0.0:
		return
	for p in s.corners:
		SiteSurface.add_box(st, look, p - Vector3(0.0, s.post * 0.5, 0.0),
				Vector3(look.sail_post, s.post, look.sail_post), &"steel", 0)


## Every sandbag of `map`'s stacks, a unit sphere's transform each (its shade into `shades`): laid in courses, alternate
## courses half a bag along, each bag bulging `bag_bulge` out of its slot. The same bags every time (the map's seed).
static func bag_layout(map: MapData, look: SiteLook, shades: PackedFloat32Array) -> Array[Transform3D]:
	var placed: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = map.dressing_seed
	for b in map.blocks:
		if look.finish_of(b) == &"sandbags" and b.rise == MapData.Rise.NONE:
			_stack(look, b, rng, placed, shades)
	return placed


## The bags (bag_layout) as one MultiMesh for the map, drawn while it is within `bags_until` m, casting no shadow
## (the stack's greybox box casts it, MapLevel).
func _lay_bags(map: MapData, look: SiteLook) -> void:
	var shades := PackedFloat32Array()
	var placed := bag_layout(map, look, shades)
	if placed.is_empty():
		return
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = BAG_SEGMENTS
	sphere.rings = BAG_RINGS
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sphere
	mm.instance_count = placed.size()
	for i in placed.size():
		mm.set_instance_transform(i, placed[i])
		mm.set_instance_color(i, Color(shades[i], shades[i], shades[i]))
	var mat := LookMaterials.vertex_colour((look.finishes_pbr[&"sandbags"] as Vector2).x, 0.0, look.paints[&"sandbags"])
	_bags = MultiMeshInstance3D.new()
	_bags.name = "Sandbags"
	_bags.multimesh = mm
	_bags.material_override = mat
	_bags.visibility_range_end = look.bags_until
	_bags.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bags)


static func _stack(look: SiteLook, b: MapData.Block, rng: RandomNumberGenerator, placed: Array[Transform3D],
		shades: PackedFloat32Array) -> void:
	var along_x := b.size.x >= b.size.z
	var length := b.size.x if along_x else b.size.z
	var depth := b.size.z if along_x else b.size.x
	var courses := maxi(1, floori(b.size.y / look.bag_course))
	var per_row := maxi(1, roundi(length / look.bag_size.x))
	var rows := maxi(1, roundi(depth / look.bag_size.y))
	var course := b.size.y / float(courses)
	var slot := length / float(per_row)
	var row := depth / float(rows)
	var foot := b.center - Vector3(0.0, b.size.y * 0.5, 0.0)
	var bulge := look.bag_bulge
	var turn := Basis.IDENTITY if along_x else Basis(Vector3.UP, PI * 0.5)
	for k in courses:
		# A staggered course: half bags at its ends, whole ones between.
		var edges := PackedFloat32Array([0.0])
		var step := 0.5 if k % 2 == 1 and per_row > 1 else 1.0
		var at := step
		while at < float(per_row) - 0.01:
			edges.append(at)
			at += 1.0
		edges.append(float(per_row))
		for r in rows:
			for e in edges.size() - 1:
				var from := edges[e] * slot
				var to := edges[e + 1] * slot
				var size := Vector3(to - from + bulge * 2.0, course + bulge * 2.0, row + bulge * 2.0)
				var local := Vector3(-length * 0.5 + (from + to) * 0.5, course * (float(k) + 0.5),
						-depth * 0.5 + row * (float(r) + 0.5))
				var basis := Basis(Vector3.UP, rng.randf_range(-BAG_TURN, BAG_TURN)) * Basis.from_scale(size)
				placed.append(Transform3D(turn * basis, foot + turn * local))
				shades.append(1.0 + rng.randf_range(-BAG_SHADE, BAG_SHADE))


## The paint stencil `s` is drawn in: charcoal, or light on a dark wall (the block just behind it).
static func stencil_paint(map: MapData, look: SiteLook, s: SiteDressing.Stencil) -> Color:
	var behind := s.at - Basis(Vector3.UP, s.yaw) * Vector3(0.0, 0.0, look.stencil_off)
	for b in map.blocks:
		if AABB(b.center - b.size * 0.5, b.size).grow(look.stencil_off * 0.5).has_point(behind):
			var paint: Color = look.paints.get(look.finish_of(b), look.paints[&"default"])
			return look.stencil_light if paint.get_luminance() < look.stencil_light_below else look.stencil_paint
	return look.stencil_paint


## A zone's name stencilled on its wall in `paint`, `stencil_off` m off it.
func _stencil(look: SiteLook, s: SiteDressing.Stencil, font: Font, paint: Color) -> void:
	var l := Label3D.new()
	l.name = "Stencil_%s" % s.area.validate_node_name()
	l.text = s.area.to_upper()
	l.font = font
	l.font_size = STENCIL_PIXELS
	l.pixel_size = s.height / float(STENCIL_PIXELS)
	l.modulate = paint
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.rotation.y = s.yaw
	l.position = s.at + Basis(Vector3.UP, s.yaw) * Vector3(0.0, 0.0, look.stencil_off)
	add_child(l)
	_stencils.append(l)

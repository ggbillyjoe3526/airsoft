class_name MapLevel
extends Node3D
## A map in the world (the browser game's render/field/mapMeshes.ts and physics/physicsWorld.ts, greybox for now): the
## blocks and the ground beyond the walls drawn as one vertex-coloured mesh in the shared light, any sloping ground in
## tiles of about TERRAIN_TILE m a side in the same material (each culled on its own, in the view and in every shadow
## cascade; WL4), and the blocks and the sloping ground's very triangles (a trimesh) as Jolt static colliders, one body
## per surface so a ray knows what it met. It hands the simulation its two views of the level:
## `query()` (WorldQuery: BB rays, what is underfoot) and `mover()` (CharacterMover), the only code that asks Jolt
## (docs/ARCHITECTURE.md › Contracts 4). Add it to the tree, then call `build`.
##
## Baked light (DP2, Settings › Graphics › Baked light): with it on, a map naming a bake (BakedLight) is drawn as the same
## faces cut into tiles (GreyboxFaces.tile), each vertex's colour darkened by the sky it can't see and warmed by the sun's bounce.
## Switching it rebuilds the mesh alone; a map with no bake draws as without it. A bake is checked against the day sun it
## was baked under, whatever preset plays; at night it draws its sky share alone (no sun to bounce; WL3).
##
## Site dress (DD1): a map naming one (`dressing.site`) built with a SiteLook draws the very same faces, baked or not,
## in the site's one material (SiteSurface) instead of the greybox's: each vertex tells the shader its box and finish,
## its colour the bake's light alone. Colliders, the nav and the shadow caster are the greybox's, unchanged.

## The physics layer the level's colliders are on, and the one the movers' bodies are on (nothing collides with them).
const WORLD_LAYER := 1
const CHARACTER_LAYER := 2
## The ground probe's disc (JoltMover): this thick (m).
const PROBE_THICKNESS := 0.02
## What a warning about a bake tells you to do.
const REBAKE := "rebake with tools/bake_light.gd"
## Sloping ground is drawn in tiles of whole ground squares at most this many metres a side (WL4).
const TERRAIN_TILE := 32.0
## An indoor field's ceiling collider's thickness (m), over the roof's height (DR1).
const CEILING_THICKNESS := 0.2
## A dressed block's core (core_box) is inset at most this share of the box's width a side, and a side counts as
## touched by another cored box within this many metres of it (WR3).
const CORE_SHARE := 0.2
const CORE_TOUCH := 0.05
## The see-through blocks' roughness (_glass_mesh): glass, near mirror-smooth.
const GLASS_ROUGHNESS := 0.1


var map: MapData = null
var _style: MapStyle = null
var _light: BakeConfig = null
var _lighting: LightingConfig = null
var _night: bool = false
var _material: ShaderMaterial = null
var _mesh: MeshInstance3D = null
## The site dress's look and its material (DD1); null for a greybox map.
var _site: SiteLook = null
## The props a block may name (MapData.Block.dress, WR3), whatever the map's site: such a block's box is drawn inset
## behind them, or not at all.
var _props: PropDressConfig = null
var _site_material: ShaderMaterial = null
## Sloping ground's tiles, under one node; empty on a map without it.
var _tiles: Array[MeshInstance3D] = []
## Whether the mesh drawn is the baked one; the map's bake, loaded when first drawn (`_bake_looked`).
var _baked: bool = false
var _bake: BakedLight = null
var _bake_looked: bool = false
var _bodies: Array[StaticBody3D] = []
var _cast: RayCast3D = null
var _query: JoltQuery = null
## The movers' kinematic bodies and shapes, made on the physics server and freed with the level.
var _rids: Array[RID] = []
var _mover_body: RID
## The mover's crouched body (BodyConfig.crouch_height tall, CT1).
var _low_mover_body: RID
var _probe_body: RID


## Builds `m`'s greybox and colliders with `style`, for characters shaped as `body`, its baked light (off until
## `set_baked_light`) drawn with `light` and checked against the sun in `lighting` (null: the built-in ones), the
## preset bakes are made under (the day's), not the one playing; `night` draws it with its sky share alone; `site` dresses
## a map that names a site dress (null: greybox). Call once, inside the tree.
func build(m: MapData, style: MapStyle, body: BodyConfig, light: BakeConfig = null,
		lighting: LightingConfig = null, night: bool = false, site: SiteLook = null) -> void:
	assert(is_inside_tree(), "MapLevel.build needs the level in the tree (its physics space)")
	map = m
	_style = style
	_light = light if light != null else BakeConfig.new()
	_lighting = lighting if lighting != null else LightingConfig.new()
	_night = night
	name = "Map_%s" % m.id
	_material = _greybox_material(style)
	_props = site.props if site != null else null
	if m.site != null and site != null:
		_site = site
		_site_material = SiteSurface.material(site, m)
	_mesh = _make_mesh()
	add_child(_mesh)
	var glass := _glass_mesh(m, style)
	if glass != null:
		var gi := MeshInstance3D.new()
		gi.name = "Glass"
		gi.mesh = glass
		gi.material_override = LookMaterials.clear_colour(GLASS_ROUGHNESS)
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(gi)
	if m.terrain != null:
		_add_ground_tiles(m.terrain)
	for s in RayHit.Surface.size():
		var sb := StaticBody3D.new()
		sb.name = "Colliders_%s" % RayHit.Surface.keys()[s]
		sb.collision_layer = WORLD_LAYER
		sb.collision_mask = 0
		add_child(sb)
		_bodies.append(sb)
	for b in m.blocks:
		var shape := CollisionShape3D.new()
		shape.position = b.center
		if b.rise == MapData.Rise.NONE:
			var box := BoxShape3D.new()
			box.size = b.size
			shape.shape = box
		else:
			var wedge := ConvexPolygonShape3D.new()
			wedge.points = GreyboxFaces.wedge_points(b, Vector3.ZERO)
			shape.shape = wedge
		_bodies[b.surface].add_child(shape)
	if m.terrain != null:
		_add_terrain_shapes(m.terrain)
	if m.roof_height > 0.0:
		_add_ceiling(m)
	_cast = RayCast3D.new()
	_cast.name = "LevelRay"
	_cast.top_level = true
	_cast.enabled = false
	_cast.collision_mask = WORLD_LAYER
	add_child(_cast)
	var surface_rids: Array[RID] = []
	for sb in _bodies:
		surface_rids.append(sb.get_rid())
	_query = JoltQuery.new(_cast, surface_rids, body)
	# Bushes are no collider: only leaves the simulation counts along a line (WL5).
	_query.foliage = m.foliage
	# What each box is, for the rules that ask (the noisy props, NP1); a ramp's wedge never makes a noise.
	for b in m.blocks:
		if b.rise == MapData.Rise.NONE:
			_query.add_block(b.kind, b.center, b.size, b.surface)
	_add_doors(m)
	_make_mover_bodies(body)


## Draws the map's baked light, or not (Settings › Graphics › Baked light), rebuilding the greybox mesh alone and only
## when what is drawn changes. A map with no bake, or a bake that doesn't fit its mesh, draws as without it.
func set_baked_light(on: bool) -> void:
	assert(map != null, "MapLevel.set_baked_light needs `build` first")
	var draw := on and _bake_or_null() != null
	if draw == _baked:
		return
	_baked = draw
	var old := _mesh
	remove_child(old)
	old.queue_free()
	_mesh = _make_mesh()
	add_child(_mesh)


## Whether the baked light is drawn.
func baked_light_drawn() -> bool:
	return _baked


## The site dress's material, which SiteDress draws its details in too; null for a greybox map.
func site_material() -> ShaderMaterial:
	return _site_material


## Draws the site dress as Mesh detail step `detail` (GraphicsQuality.MeshDetail) asks: on Low without the photo
## textures' relief and the finer marks (SiteSurface). Nothing on a greybox map.
func set_detail(detail: GraphicsQuality.MeshDetail) -> void:
	if _site_material != null:
		_site_material.set_shader_parameter(&"low", detail == GraphicsQuality.MeshDetail.LOW)


## Sloping ground's tiles (WL4), row by row; empty on a map without sloping ground.
func ground_tiles() -> Array[MeshInstance3D]:
	return _tiles


## The level as the simulation's WorldQuery.
func query() -> JoltQuery:
	return _query


## The level as the simulation's CharacterMover (a new one each call, sharing the level's bodies).
func mover(body: BodyConfig) -> JoltMover:
	return JoltMover.new(_mover_body, _low_mover_body, _probe_body, body)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for rid in _rids:
			PhysicsServer3D.free_rid(rid)
		_rids.clear()


## An indoor field's roof as BBs meet it (DR1): steel sheeting over the blocks' whole footprint at the roof's height,
## so a lob never leaves the hall. Drawn by RoofView, never by the greybox; no block, so the bake, the nav grid and the
## minimap never see it.
func _add_ceiling(m: MapData) -> void:
	var area := m.footprint()
	if not area.has_area():
		return
	var shape := CollisionShape3D.new()
	shape.name = "Ceiling"
	var box := BoxShape3D.new()
	box.size = Vector3(area.size.x, CEILING_THICKNESS, area.size.y)
	shape.shape = box
	var middle := area.get_center()
	shape.position = Vector3(middle.x, m.roof_height + CEILING_THICKNESS * 0.5, middle.y)
	_bodies[RayHit.Surface.METAL].add_child(shape)


## The hinged doors' leaves (DO1), each a wooden box on a static body of its own (so a switch rebuilds one shape, not
## the wood body's), solid while shut: the query switches them (JoltQuery.set_door_shut). Drawn by DoorView, never by
## the greybox or the bake.
func _add_doors(m: MapData) -> void:
	for i in m.doors.size():
		var d := m.doors[i]
		var sb := StaticBody3D.new()
		sb.name = "Door%d" % i
		sb.collision_layer = WORLD_LAYER
		sb.collision_mask = 0
		add_child(sb)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = d.size
		shape.shape = box
		shape.position = d.center
		shape.disabled = not d.shut
		sb.add_child(shape)
		_query.add_door(d.center, d.size, d.shut)
		_query.set_door_shape(i, shape, sb.get_rid())


## Sloping ground drawn in tiles under one node, each in the greybox's material, casting shadows: built once, the
## baked light's switch leaves them be (no bake covers sloping ground).
func _add_ground_tiles(t: TerrainGrid) -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	add_child(ground)
	var meshes := GreyboxFaces.terrain_tiles(t, _style, TERRAIN_TILE)
	for i in meshes.size():
		var mi := MeshInstance3D.new()
		mi.name = "Tile%d" % i
		mi.mesh = meshes[i]
		mi.material_override = _material
		ground.add_child(mi)
		_tiles.append(mi)


## The sloping ground's triangles as one trimesh per ground surface, each on that surface's body.
func _add_terrain_shapes(t: TerrainGrid) -> void:
	var faces := t.surface_faces(_bodies.size())
	for s in faces.size():
		if faces[s].is_empty():
			continue
		var trimesh := ConcavePolygonShape3D.new()
		trimesh.set_faces(faces[s])
		var shape := CollisionShape3D.new()
		shape.name = "Terrain"
		shape.shape = trimesh
		_bodies[s].add_child(shape)


func _make_mover_bodies(body: BodyConfig) -> void:
	var space := get_world_3d().space
	var cylinder := PhysicsServer3D.cylinder_shape_create()
	PhysicsServer3D.shape_set_data(cylinder, {"radius": body.radius, "height": body.height})
	var low := PhysicsServer3D.cylinder_shape_create()
	PhysicsServer3D.shape_set_data(low, {"radius": body.radius, "height": body.crouch_height})
	var disc := PhysicsServer3D.cylinder_shape_create()
	PhysicsServer3D.shape_set_data(disc, {"radius": body.radius, "height": PROBE_THICKNESS})
	_mover_body = _kinematic(space, cylinder)
	_low_mover_body = _kinematic(space, low)
	_probe_body = _kinematic(space, disc)
	# Bodies first: a shape is freed after the bodies holding it.
	_rids.append(_mover_body)
	_rids.append(_low_mover_body)
	_rids.append(_probe_body)
	_rids.append(cylinder)
	_rids.append(low)
	_rids.append(disc)


func _kinematic(space: RID, shape: RID) -> RID:
	var rid := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_KINEMATIC)
	PhysicsServer3D.body_add_shape(rid, shape)
	PhysicsServer3D.body_set_collision_layer(rid, CHARACTER_LAYER)
	PhysicsServer3D.body_set_collision_mask(rid, WORLD_LAYER)
	PhysicsServer3D.body_set_space(rid, space)
	return rid


## The greybox: the untiled mesh, or with the bake the tiled one, which casts no shadow, and the untiled one under it
## casting the shadows alone, so the sun's shadow passes draw as many triangles as without the bake. A site-dressed map
## draws either in the site's material; its shadow caster stays the greybox's.
func _make_mesh() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Greybox" if _site == null else "Site"
	mi.material_override = _material if _site == null else _site_material
	var baked := _baked_mesh() if _baked else null
	if baked == null:
		_baked = false
		mi.mesh = _greybox_mesh(map, _style, null, _props) if _site == null else _site_mesh(map, _style, _site)
		return mi
	mi.mesh = baked
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var caster := MeshInstance3D.new()
	caster.name = "ShadowCaster"
	caster.mesh = _greybox_mesh(map, _style, _site)
	caster.material_override = _material
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	mi.add_child(caster)
	return mi


## The map's bake, looked for once: null (with one warning) when it is missing or broken, was baked from other blocks,
## colours, sun or bake settings (its hash), or covers another number of tiles, checked before any tile is made.
func _bake_or_null() -> BakedLight:
	if _bake_looked:
		return _bake
	_bake_looked = true
	_bake = BakedLight.load_for(map)
	if _bake == null:
		return null
	if _bake.source_hash != BakedLight.hash_of(map, _style, _lighting, _light):
		push_warning("MapLevel: %s's baked light was baked from other blocks or settings; drawn without it (%s)"
				% [map.id, REBAKE])
		_bake = null
	elif _bake.vertex_count != GreyboxFaces.tile_count(map, _light.cell, _light.ground_y):
		push_warning("MapLevel: %s's baked light has %d vertices for %d; drawn without it (%s)"
				% [map.id, _bake.vertex_count, GreyboxFaces.tile_count(map, _light.cell, _light.ground_y), REBAKE])
		_bake = null
	return _bake


## Every block and the ground beyond the walls as one mesh in one material: vertex colours carry each block's colour,
## so the blocks are a single draw call (sloping ground is its tiles').
## With `site`, as the baked site's shadow caster: a block drawn as props alone (DR2) is left out, its props cast its
## shadow. With `props`, a block drawn as props (WR3) is left out, or drawn as its core behind its props (core_box: a
## thicket's), its props casting their own shadows; a lined (TILE) block keeps its box.
static func _greybox_mesh(m: MapData, style: MapStyle, site: SiteLook = null,
		props: PropDressConfig = null) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cored: Array[MapData.Block] = []
	if props != null:
		for b in m.blocks:
			if props.core_of(b) != Vector2.ZERO:
				cored.append(b)
	for b in m.blocks:
		if site != null and SiteSurface.hidden(site, b):
			continue
		if style.is_clear(b.kind):
			continue
		var core := Transform3D.IDENTITY
		if props != null and props.dresses(b) and props.lay_of(b) != PropDressConfig.Lay.TILE:
			var inset := props.core_of(b)
			if inset == Vector2.ZERO:
				continue
			core = core_box(b, inset, cored)
		st.set_color(style.block_colour(b))
		for f in GreyboxFaces.faces_of(b):
			_add_face(st, core * f)
	st.set_color(style.ground_colour)
	_add_face(st, GreyboxFaces.ground_face(style, GreyboxFaces.ground_top(m)))
	return st.commit()


## The see-through blocks (MapStyle.clear_kinds: The Street's glass, ST1) as one mesh, each in its colour at its kind's
## opacity; null on a map with none. They stay out of the greybox (a bake still draws them solid: no baked map has
## glass).
static func _glass_mesh(m: MapData, style: MapStyle) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for b in m.blocks:
		if not style.is_clear(b.kind):
			continue
		any = true
		var c := style.block_colour(b)
		c.a = style.clear_kinds[b.kind]
		st.set_color(c)
		for f in GreyboxFaces.faces_of(b):
			_add_face(st, f)
	return st.commit() if any else null


## The transform that draws block `b`'s box as its core (PropDressConfig.model_cores): its top cut down to `inset.y` of
## its height, each side drawn `inset.x` m in (at most CORE_SHARE of the box's width) unless one of `cored` (the
## cored blocks) touches that side, where the core runs to the face so touching thickets leave no gap between them.
static func core_box(b: MapData.Block, inset: Vector2, cored: Array[MapData.Block]) -> Transform3D:
	var lo := b.center - b.size * 0.5
	var hi := b.center + b.size * 0.5
	var to_lo := lo
	var to_hi := Vector3(hi.x, lo.y + b.size.y * inset.y, hi.z)
	for axis: int in [0, 2]:
		var step := minf(inset.x, b.size[axis] * CORE_SHARE)
		if not _touched(b, axis, -1.0, cored):
			to_lo[axis] += step
		if not _touched(b, axis, 1.0, cored):
			to_hi[axis] -= step
	var basis := Basis.from_scale((to_hi - to_lo).max(Vector3.ZERO) / b.size)
	return Transform3D(basis, to_lo - basis * lo)


## Whether another of `cored` meets block `b`'s side on `axis` towards `side` (+1 or -1) anywhere along it.
static func _touched(b: MapData.Block, axis: int, side: float, cored: Array[MapData.Block]) -> bool:
	var lo := b.center - b.size * 0.5
	var size := b.size
	lo[axis] += b.size[axis] if side > 0.0 else -CORE_TOUCH
	size[axis] = CORE_TOUCH
	var slab := AABB(lo, size)
	for o in cored:
		if o != b and AABB(o.center - o.size * 0.5, o.size).intersects(slab):
			return true
	return false


## The greybox's faces for the site's material: white, each vertex carrying its block's box and finish
## (SiteSurface.block_customs), and the ground beyond the walls as the site's ground.
static func _site_mesh(m: MapData, style: MapStyle, site: SiteLook) -> ArrayMesh:
	var st := SiteSurface.begin()
	st.set_color(Color.WHITE)
	for b in m.blocks:
		var c := SiteSurface.block_customs(site, b)
		st.set_custom(0, c[0])
		st.set_custom(1, c[1])
		var core := SiteSurface.core_of(site, b, m)
		for f in GreyboxFaces.faces_of(b):
			_add_face(st, core * f)
	var top := GreyboxFaces.ground_top(m)
	var g := SiteSurface.ground_customs(site, top)
	st.set_custom(0, g[0])
	st.set_custom(1, g[1])
	_add_face(st, GreyboxFaces.ground_face(style, top))
	return st.commit()


## The same faces cut into tiles, each vertex's colour lit by the bake (`_bake_or_null` has checked it fits), and the
## ground unlit. On a site-dressed map the colour is the light alone (linear, for the site's material) and each vertex
## carries its block's box and finish.
func _baked_mesh() -> ArrayMesh:
	var t := GreyboxFaces.tile(map, _light.cell, _light.ground_y)
	var n := t.positions.size()
	assert(n == _bake.vertex_count, "tile_count and tile agree")
	var colours := PackedColorArray()
	colours.resize(n)
	var block_linear: Array[Color] = []
	for b in map.blocks:
		block_linear.append(_style.block_colour(b).srgb_to_linear() if _site == null else Color.WHITE)
	var dark := _light.sky_share / BakedLight.FULL
	var warm := 0.0 if _night else _light.bounce_gain / BakedLight.FULL
	var sky := _bake.sky
	var bounce := _bake.bounce
	for v in n:
		var c := block_linear[t.blocks[v]]
		var lit := 1.0 - _light.sky_share + dark * sky[v]
		var k := v * 3
		var lin := Color(c.r * (lit + warm * bounce[k]), c.g * (lit + warm * bounce[k + 1]),
				c.b * (lit + warm * bounce[k + 2]))
		colours[v] = lin.linear_to_srgb() if _site == null else lin
	for p in GreyboxFaces.ground_face(_style, GreyboxFaces.ground_top(map)):
		t.positions.append(p)
		t.normals.append(Vector3.UP)
		colours.append(_style.ground_colour if _site == null else Color.WHITE)
	for i: int in [0, 2, 1, 0, 3, 2]:
		t.indices.append(n + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = t.positions
	arrays[Mesh.ARRAY_NORMAL] = t.normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = t.indices
	var format := 0
	if _site != null:
		_site_customs(t.blocks, n, arrays)
		_site_cores(t)
		format = SiteSurface.CUSTOM_FORMAT
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
	return mesh


## The baked tiles where SiteSurface.core_of draws them (a sandbag stack's own box inside its bags).
func _site_cores(t: GreyboxFaces.Tiles) -> void:
	for i in map.blocks.size():
		var core := SiteSurface.core_of(_site, map.blocks[i], map)
		if core == Transform3D.IDENTITY:
			continue
		for v in t.blocks.size():
			if t.blocks[v] == i:
				t.positions[v] = core * t.positions[v]


## The baked tiles' custom channels: each of the `n` tile vertices its block's (`blocks`), then the ground's four.
func _site_customs(blocks: PackedInt32Array, n: int, arrays: Array) -> void:
	var per_block: Array[Array] = []
	for b in map.blocks:
		per_block.append(SiteSurface.block_customs(_site, b))
	per_block.append(SiteSurface.ground_customs(_site, GreyboxFaces.ground_top(map)))
	var ground := per_block.size() - 1
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	c0.resize((n + 4) * 4)
	c1.resize((n + 4) * 4)
	for v in n + 4:
		var c: Array = per_block[blocks[v] if v < n else ground]
		var a: Color = c[0]
		var h: Color = c[1]
		var k := v * 4
		c0[k] = a.r
		c0[k + 1] = a.g
		c0[k + 2] = a.b
		c0[k + 3] = a.a
		c1[k] = h.r
		c1[k + 1] = h.g
		c1[k + 2] = h.b
		c1[k + 3] = h.a
	arrays[Mesh.ARRAY_CUSTOM0] = c0
	arrays[Mesh.ARRAY_CUSTOM1] = c1


## The greybox's one material: its vertex colours (sRGB) in the shared light (docs/ART.md › A map in the look), clean,
## with no grid or texture.
static func _greybox_material(style: MapStyle) -> ShaderMaterial:
	return LookMaterials.vertex_colour(style.roughness, 0.0, Color.WHITE, true)


## A convex face given anticlockwise as seen from outside, its normal worked out from its winding.
static func _add_face(st: SurfaceTool, pts: PackedVector3Array) -> void:
	var p0 := pts[0]
	st.set_normal(GreyboxFaces.face_normal(pts))
	for i in range(1, pts.size() - 1):
		st.add_vertex(p0)
		st.add_vertex(pts[i + 1])
		st.add_vertex(pts[i])


class_name DrawnRays
extends RefCounted
## BBs and sight meet the props a map draws as they are drawn (DG1, the owner's playtest of 0.1 Beta 2, 2026-11-23:
## "ricochet should only happen against surfaces, not empty spaces"). Each prop PropLayout lays where the game draws
## it (PropDress) stands as its model's own faces, on bodies of their own on DRAWN_LAYER: a trolley's trays and the
## open air over them, a bench's slats, a trunk as round as it is drawn, a crown's limbs. A model's leaf cards
## (PropDressConfig.model_barks, cut down as drawn, LeafTrim) stand on LEAF_LAYER, and JoltQuery reads each card's
## cut-out from the leaf sheet where a ray meets it (`opaque`), so a line threads the gaps between needles and leaves
## as the eye does. The blocks such props stand in for (`drawn`) move to BOX_LAYER: still what bodies, the level ray
## (what is underfoot, vaults, leans, bombs, magazines) and, off the physics, the nav grid, the bots' cover, the noisy
## props, the bake and the minimap meet. A lined block (TILE: its backing box is drawn) or a cored one keeps its box for
## every ray. Built once a level; the bodies are the physics server's (no node), freed by `free_bodies`.

## MapLevel's physics layers: a dressed block's box (bodies and the level ray), the drawn props' faces and their leaf
## cards (BBs and sight).
const BOX_LAYER := 4
const DRAWN_LAYER := 8
const LEAF_LAYER := 16
## A body's key (`_add`): a square's column and row each under this either side of the field's middle, and a surface's
## and a layer's value each under KEY_SLOTS.
const KEY_CELLS := 2048
const KEY_SLOTS := 32
## A prop's axes are square to one another within this (the cosine between them): a geometric tolerance.
const SQUARE := 1e-4


## One model's ray shapes, shared by every prop of it.
class Shapes:
	extends RefCounted
	## Its solid faces (all but its leaf cards); null when it has none.
	var solid: ConcavePolygonShape3D = null
	## Its leaf cards; null when it has none. Each card's three corners in its model's frame and on the leaf sheet,
	## in the shape's face order (the face index a ray reports).
	var leaves: ConcavePolygonShape3D = null
	var leaf_corners: PackedVector3Array = PackedVector3Array()
	var leaf_uvs: PackedVector2Array = PackedVector2Array()


## A leaf body's shapes, by shape index: whose cards each is and the inverse of where it stands.
class LeafBody:
	extends RefCounted
	var shapes: Array[Shapes] = []
	var inverses: Array[Transform3D] = []


## By block index: 1 where the block's props stand in for its box to BBs and sight.
var drawn: PackedByteArray = PackedByteArray()
## Every body made, and each one's RayHit.Surface (a leaf body's LEAVES).
var surfaces: Dictionary[RID, int] = {}
var _cfg: DrawnRayConfig = null
var _props: int = 0
var _shapes: Dictionary[StringName, Shapes] = {}
var _leaf_bodies: Dictionary[RID, LeafBody] = {}
## The shapes made for one prop alone (a sheared one's, `_placed`), held while their bodies are.
var _own_shapes: Array[ConcavePolygonShape3D] = []
## The leaf sheet's alpha (FORMAT_LA8), read where a ray meets a card; null on a map with no leaf cards.
var _sheet: Image = null
var _sheet_size: Vector2i = Vector2i.ZERO
## While the bodies are made (`begin` to the last `build_step`): the map, its dress and the space, the props as laid by
## model, the models in turn and the model and prop being made, each open body by its key and how many shapes it holds.
var _map: MapData = null
var _dress: PropDressConfig = null
var _space: RID = RID()
var _laid: Dictionary[StringName, PropLayout.Placed] = {}
var _models: Array[StringName] = []
var _model_at: int = 0
var _prop_at: int = 0
var _open: Dictionary[int, RID] = {}
var _counts: Dictionary[int, int] = {}


## The drawn props of `map` as `props` lays them (the game's look: a station's named props only, as PlaySession draws
## them), their bodies in `space`, with `cfg`, built whole. A model that won't load leaves its blocks as boxes.
static func build(map: MapData, props: PropDressConfig, space: RID, cfg: DrawnRayConfig) -> DrawnRays:
	var rays := DrawnRays.begin(map, props, space, cfg)
	rays.build_some(0)
	return rays


## As `build`, the props laid but no body made yet: `build_step` makes them a few props a call (MapLevel's staged
## build, one a loading-screen frame), the same rays either way.
static func begin(map: MapData, props: PropDressConfig, space: RID, cfg: DrawnRayConfig) -> DrawnRays:
	var rays := DrawnRays.new()
	rays._cfg = cfg
	rays._map = map
	rays._dress = props
	rays._space = space
	rays.drawn.resize(map.blocks.size())
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in PropDress.models_used(map, props):
		var mesh := props.mesh_of(model)
		if mesh != null:
			boxes[model] = mesh.get_aabb()
	rays._laid = PropLayout.layout(map, props, boxes)
	rays._models.assign(rays._laid.keys())
	return rays


## Makes the props' bodies, a step (`build_step`) at a time, until the clock passes `until_usec` (0: to the end);
## whether they are all made (and in their space).
func build_some(until_usec: int) -> bool:
	while not done():
		build_step()
		if until_usec > 0 and Time.get_ticks_usec() >= until_usec:
			break
	return done()


## Whether every body is made (`build`, or `build_step` until it says so).
func done() -> bool:
	return _map == null


## One step of the build `begin` started: the model being made's shapes, else its next DrawnRayConfig.props_a_step
## props, or, past the last model, the sets and the bodies' space; whether every body is made.
func build_step() -> bool:
	if done():
		return true
	if _model_at >= _models.size():
		_finish()
		return true
	var model := _models[_model_at]
	if not _shapes.has(model):
		# a model's shapes are a step of their own
		_shapes_of(model, _dress)
		return false
	var shapes := _shapes_of(model, _dress)
	var p := _laid[model]
	var end := p.transforms.size() if shapes.solid == null and shapes.leaves == null \
			else mini(_prop_at + _cfg.props_a_step, p.transforms.size())
	for i in range(_prop_at, end):
		if shapes.solid == null and shapes.leaves == null:
			break
		var bi := p.blocks[i]
		var b := _map.blocks[bi]
		if not _stands_in(b, _dress):
			continue
		drawn[bi] = 1
		_props += 1
		var xf := p.transforms[i]
		# Jolt places a shape by a turn and a scale along its own axes: a prop bent to its joint (LINED, a log
		# tunnel's sections) has its faces moved where they are drawn instead, a shape of its own.
		var sheared := _sheared(xf.basis)
		var placed_at := Transform3D.IDENTITY if sheared else xf
		if shapes.solid != null:
			_add(xf.origin, placed_at, _placed(shapes.solid, xf, sheared), DRAWN_LAYER, b.surface)
		if shapes.leaves != null:
			var body := _add(xf.origin, placed_at, _placed(shapes.leaves, xf, sheared), LEAF_LAYER,
					RayHit.Surface.LEAVES)
			var lb: LeafBody = _leaf_bodies[body]
			lb.shapes.append(shapes)
			lb.inverses.append(xf.affine_inverse())
	_prop_at = end
	if _prop_at >= p.transforms.size():
		_prop_at = 0
		_model_at += 1
	return false


## A structure laid once over its set of blocks (SET) stands in for every block of the set; the bodies go into their
## space, and what the build held goes.
func _finish() -> void:
	for bi in _map.blocks.size():
		var b := _map.blocks[bi]
		if drawn[bi] == 0 and _dress.lay_of(b) == PropDressConfig.Lay.SET and _dress.dresses(b) \
				and _laid.has(_dress.model_of(b)) and _has_faces(_dress.model_of(b)):
			drawn[bi] = 1
	for body: RID in surfaces:
		PhysicsServer3D.body_set_space(body, _space)
	_drop_build()


## What the build held goes: the build is done (a step after it does nothing).
func _drop_build() -> void:
	_map = null
	_dress = null
	_laid.clear()
	_models.clear()
	_open.clear()
	_counts.clear()


## Whether `basis` is more than a turn and a scale along its own axes (its axes not square to one another).
static func _sheared(basis: Basis) -> bool:
	var x := basis.x.normalized()
	var y := basis.y.normalized()
	var z := basis.z.normalized()
	return absf(x.dot(y)) > SQUARE or absf(y.dot(z)) > SQUARE or absf(x.dot(z)) > SQUARE


## Whether block `b`'s props, once laid, stand in for its box: it is drawn as props alone (no backing box, no core).
static func _stands_in(b: MapData.Block, props: PropDressConfig) -> bool:
	return props.dresses(b) and props.lay_of(b) != PropDressConfig.Lay.TILE and props.core_of(b) == Vector2.ZERO


## The tuning it was built with.
func config() -> DrawnRayConfig:
	return _cfg


## Whether block `index`'s props stand in for its box to BBs and sight.
func draws(index: int) -> bool:
	return index >= 0 and index < drawn.size() and drawn[index] == 1


## Whether `model`'s shapes were made with faces to stand in for its blocks.
func _has_faces(model: StringName) -> bool:
	var s: Shapes = _shapes.get(model, null)
	return s != null and (s.solid != null or s.leaves != null)


## Whether `body` is one of the props' leaf bodies.
func is_leaf(body: RID) -> bool:
	return _leaf_bodies.has(body)


## How many props stand on the bodies.
func prop_count() -> int:
	return _props


## How many bodies the props stand on.
func body_count() -> int:
	return surfaces.size()


## Whether the leaf card a ray met at `at` (face `face` of shape `shape` on leaf body `body`) is solid there: its
## sheet's alpha at least DrawnRayConfig.leaf_alpha_cut. A card whose face isn't told (-1) counts as solid. Allocates
## nothing.
func opaque(body: RID, shape: int, face: int, at: Vector3) -> bool:
	var lb: LeafBody = _leaf_bodies.get(body, null)
	if lb == null or face < 0 or shape < 0 or shape >= lb.shapes.size() or _sheet == null:
		return true
	var s := lb.shapes[shape]
	var k := face * 3
	if k + 2 >= s.leaf_corners.size():
		return true
	var local := lb.inverses[shape] * at
	var w := Geometry3D.get_triangle_barycentric_coords(local, s.leaf_corners[k], s.leaf_corners[k + 1],
			s.leaf_corners[k + 2])
	var uv := s.leaf_uvs[k] * w.x + s.leaf_uvs[k + 1] * w.y + s.leaf_uvs[k + 2] * w.z
	var x := clampi(int(uv.x * _sheet_size.x), 0, _sheet_size.x - 1)
	var y := clampi(int(uv.y * _sheet_size.y), 0, _sheet_size.y - 1)
	return _sheet.get_pixel(x, y).a >= _cfg.leaf_alpha_cut


## Frees every body (before the shapes they hold go) and ends a build still under way.
func free_bodies() -> void:
	for body: RID in surfaces:
		PhysicsServer3D.free_rid(body)
	surfaces.clear()
	_leaf_bodies.clear()
	_own_shapes.clear()
	_drop_build()


## `shape` as a prop placed at `xf` stands: itself (placed at `xf`), or, `sheared`, its faces moved to where they are
## drawn, a shape of its own (placed where it is), kept as long as the rays are.
func _placed(shape: ConcavePolygonShape3D, xf: Transform3D, sheared: bool) -> ConcavePolygonShape3D:
	if not sheared:
		return shape
	var own := _shape(xf * shape.get_faces())
	_own_shapes.append(own)
	return own


## A body on `layer` for `surface` in the chunk under `at` with room for one more shape, `shape` added to it at `xf`;
## the body.
func _add(at: Vector3, xf: Transform3D, shape: Shape3D, layer: int, surface: int) -> RID:
	var cell := Vector2i(floori(at.x / _cfg.chunk), floori(at.z / _cfg.chunk))
	# a key a layer, a surface and a square
	var key := (((cell.x + KEY_CELLS) * 2 * KEY_CELLS + cell.y + KEY_CELLS) * KEY_SLOTS + surface) * KEY_SLOTS + layer
	var body: RID = _open.get(key, RID())
	if not body.is_valid() or _counts[key] >= _cfg.most_a_body:
		body = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_collision_layer(body, layer)
		PhysicsServer3D.body_set_collision_mask(body, 0)
		surfaces[body] = surface
		if layer == LEAF_LAYER:
			_leaf_bodies[body] = LeafBody.new()
		_open[key] = body
		_counts[key] = 0
	PhysicsServer3D.body_add_shape(body, shape.get_rid(), xf)
	_counts[key] += 1
	return body


## Model `model`'s ray shapes, made once a level: its drawn mesh's faces, a model_barks model's leaf cards (UV x 0 or
## more, LeafTrim.BARK_BELOW) apart from its solid ones.
func _shapes_of(model: StringName, props: PropDressConfig) -> Shapes:
	if _shapes.has(model):
		return _shapes[model]
	var s := Shapes.new()
	_shapes[model] = s
	var mesh := props.drawn_mesh_of(model)
	if mesh == null:
		return s
	if not props.model_barks.has(model):
		var faces := mesh.get_faces()
		if not faces.is_empty():
			s.solid = _shape(faces)
		return s
	var solid := PackedVector3Array()
	_load_sheet(props)
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var has_uvs := arrays[Mesh.ARRAY_TEX_UV] != null
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if has_uvs else PackedVector2Array()
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := index.size() if not index.is_empty() else verts.size()
		for k in range(0, count - 2, 3):
			var a := index[k] if not index.is_empty() else k
			var b := index[k + 1] if not index.is_empty() else k + 1
			var c := index[k + 2] if not index.is_empty() else k + 2
			var leaf := has_uvs and uvs[a].x >= LeafTrim.BARK_BELOW
			if leaf:
				_append_card(s, verts[a], verts[b], verts[c], uvs[a], uvs[b], uvs[c])
			else:
				solid.append(verts[a])
				solid.append(verts[b])
				solid.append(verts[c])
	if not solid.is_empty():
		s.solid = _shape(solid)
	if not s.leaf_corners.is_empty():
		s.leaves = _shape(s.leaf_corners)
	return s


## Leaf card `p0 p1 p2` (on the sheet at `u0 u1 u2`) into `s`'s cards, whole: `opaque` reads its sheet where a ray
## meets it (cut into pieces, a piece the sheet's samples missed would let a line through drawn leaves).
static func _append_card(s: Shapes, p0: Vector3, p1: Vector3, p2: Vector3, u0: Vector2, u1: Vector2,
		u2: Vector2) -> void:
	s.leaf_corners.append(p0)
	s.leaf_corners.append(p1)
	s.leaf_corners.append(p2)
	s.leaf_uvs.append(u0)
	s.leaf_uvs.append(u1)
	s.leaf_uvs.append(u2)


## A shape of `faces` met from either side (a model's open faces, a card's back: a ray meets what the eye sees, its
## back faces drawn or not).
static func _shape(faces: PackedVector3Array) -> ConcavePolygonShape3D:
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	return shape


## The leaf sheet's alpha, read once a level from its texture.
func _load_sheet(props: PropDressConfig) -> void:
	if _sheet != null:
		return
	var tex := load(props.foliage_sheet) as Texture2D if ResourceLoader.exists(props.foliage_sheet) else null
	var img := tex.get_image() if tex != null else null
	if img == null:
		push_warning("DrawnRays: the leaf sheet \"%s\" won't read; its cards stop every ray" % props.foliage_sheet)
		return
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_LA8)
	_sheet = img
	_sheet_size = img.get_size()


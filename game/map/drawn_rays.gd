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
## What became of a piece of a leaf card being cut (DrawnRays._piece).
const NONE := 0
const PART := 1
const WHOLE := 2
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
## The card being cut (`_add_card`): its solid samples, its first corner and two edges, in the model and on the sheet.
var _solid: PackedByteArray = PackedByteArray()
var _card_p: Array[Vector3] = []
var _card_u: Array[Vector2] = []


## The drawn props of `map` as `props` lays them (the game's look: a station's named props only, as PlaySession draws
## them), their bodies in `space`, with `cfg`. A model that won't load leaves its blocks as boxes.
static func build(map: MapData, props: PropDressConfig, space: RID, cfg: DrawnRayConfig) -> DrawnRays:
	var rays := DrawnRays.new()
	rays._cfg = cfg
	rays.drawn.resize(map.blocks.size())
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in PropDress.models_used(map, props):
		var mesh := props.mesh_of(model)
		if mesh != null:
			boxes[model] = mesh.get_aabb()
	var placed := PropLayout.layout(map, props, boxes)
	var open: Dictionary[int, RID] = {}
	var counts: Dictionary[int, int] = {}
	for model: StringName in placed:
		var shapes := rays._shapes_of(model, props)
		if shapes.solid == null and shapes.leaves == null:
			continue
		var p := placed[model]
		for i in p.transforms.size():
			var bi := p.blocks[i]
			var b := map.blocks[bi]
			if not _stands_in(b, props):
				continue
			rays.drawn[bi] = 1
			rays._props += 1
			var xf := p.transforms[i]
			# Jolt places a shape by a turn and a scale along its own axes: a prop bent to its joint (LINED, a log
			# tunnel's sections) has its faces moved where they are drawn instead, a shape of its own.
			var sheared := _sheared(xf.basis)
			var placed_at := Transform3D.IDENTITY if sheared else xf
			if shapes.solid != null:
				rays._add(open, counts, xf.origin, placed_at, rays._placed(shapes.solid, xf, sheared), DRAWN_LAYER,
						b.surface)
			if shapes.leaves != null:
				var body := rays._add(open, counts, xf.origin, placed_at, rays._placed(shapes.leaves, xf, sheared),
						LEAF_LAYER, RayHit.Surface.LEAVES)
				var lb: LeafBody = rays._leaf_bodies[body]
				lb.shapes.append(shapes)
				lb.inverses.append(xf.affine_inverse())
	# A structure laid once over its set of blocks (SET) stands in for every block of the set.
	for bi in map.blocks.size():
		var b := map.blocks[bi]
		if rays.drawn[bi] == 0 and props.lay_of(b) == PropDressConfig.Lay.SET and props.dresses(b) \
				and placed.has(props.model_of(b)) and rays._shapes.has(props.model_of(b)):
			rays.drawn[bi] = 1
	for body: RID in rays.surfaces:
		PhysicsServer3D.body_set_space(body, space)
	return rays


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
	return index < drawn.size() and drawn[index] == 1


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


## Frees every body (before the shapes they hold go).
func free_bodies() -> void:
	for body: RID in surfaces:
		PhysicsServer3D.free_rid(body)
	surfaces.clear()
	_leaf_bodies.clear()
	_own_shapes.clear()


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
func _add(open: Dictionary[int, RID], counts: Dictionary[int, int], at: Vector3, xf: Transform3D, shape: Shape3D,
		layer: int, surface: int) -> RID:
	var cell := Vector2i(floori(at.x / _cfg.chunk), floori(at.z / _cfg.chunk))
	# a key a layer, a surface and a square (each square's column and row under 2^12 either side)
	var key := (((cell.x + 2048) * 4096 + cell.y + 2048) * 32 + surface) * 32 + layer
	var body: RID = open.get(key, RID())
	if not body.is_valid() or counts[key] >= _cfg.most_a_body:
		body = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_collision_layer(body, layer)
		PhysicsServer3D.body_set_collision_mask(body, 0)
		surfaces[body] = surface
		if layer == LEAF_LAYER:
			_leaf_bodies[body] = LeafBody.new()
		open[key] = body
		counts[key] = 0
	PhysicsServer3D.body_add_shape(body, shape.get_rid(), xf)
	counts[key] += 1
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
		var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := index.size() if not index.is_empty() else verts.size()
		for k in range(0, count - 2, 3):
			var a := index[k] if not index.is_empty() else k
			var b := index[k + 1] if not index.is_empty() else k + 1
			var c := index[k + 2] if not index.is_empty() else k + 2
			var leaf := uvs != null and (uvs as PackedVector2Array)[a].x >= LeafTrim.BARK_BELOW
			if leaf:
				_add_card(s, verts[a], verts[b], verts[c], (uvs as PackedVector2Array)[a],
						(uvs as PackedVector2Array)[b], (uvs as PackedVector2Array)[c])
			else:
				solid.append(verts[a])
				solid.append(verts[b])
				solid.append(verts[c])
	if not solid.is_empty():
		s.solid = _shape(solid)
	if not s.leaf_corners.is_empty():
		s.leaves = _shape(s.leaf_corners)
	return s


## Leaf card `p0 p1 p2` (on the sheet at `u0 u1 u2`) into `s`'s cards, halved along its edges DrawnRayConfig.leaf_halvings
## times (each time into four), leaving out the pieces the sheet is cut away all over (solid at none of their corners,
## their edges' middles or their middle, read on a grid twice as fine as the smallest pieces), so fewer rays meet a card
## only to pass its cut-away parts; four kept pieces of one go back in as their whole. The card whole when the sheet
## won't read.
func _add_card(s: Shapes, p0: Vector3, p1: Vector3, p2: Vector3, u0: Vector2, u1: Vector2, u2: Vector2) -> void:
	var levels := _cfg.leaf_halvings
	if _sheet == null or levels <= 0:
		_append_card(s, p0, p1, p2, u0, u1, u2)
		return
	# the solid samples on the fine grid (row i, column j, i + j <= fine), each at barycentric (i, j) / fine
	var fine := 2 << levels
	var row := fine + 1
	_solid.resize(row * row)
	for i in row:
		for j in row - i:
			_solid[i * row + j] = 1 if _solid_at(u0 + (u1 - u0) * (float(i) / fine) + (u2 - u0) * (float(j) / fine)) \
					else 0
	_card_p = [p0, p1 - p0, p2 - p0]
	_card_u = [u0, u1 - u0, u2 - u0]
	if _piece(s, 0, 0, 0, 1) == WHOLE:
		_append_card(s, p0, p1, p2, u0, u1, u2)


## The piece of the card being cut (`_add_card`) halved `level` times, its right angle at (`i`, `j`) of that level's grid
## and its legs `d` (1 pointing up, -1 down): WHOLE when it is kept whole (left to the caller to add), PART when some of
## it was added, NONE when it is left out.
func _piece(s: Shapes, level: int, i: int, j: int, d: int) -> int:
	if level == _cfg.leaf_halvings:
		# on the fine grid, twice as fine, its legs are two long
		return WHOLE if _piece_solid(i * 2, j * 2, d, 2 << level, _card_u[0], _card_u[0] + _card_u[1],
				_card_u[0] + _card_u[2]) else NONE
	# its four halves: three pointing its way at its corners, the middle one the other way
	var kids: Array[Vector3i] = [Vector3i(2 * i, 2 * j, d), Vector3i(2 * i + d, 2 * j, d), Vector3i(2 * i, 2 * j + d, d),
			Vector3i(2 * i + d, 2 * j + d, -d)]
	var got: Array[int] = []
	var whole := 0
	for k in kids:
		var r := _piece(s, level + 1, k.x, k.y, k.z)
		got.append(r)
		whole += 1 if r == WHOLE else 0
	if whole == 4:
		return WHOLE
	var any := false
	for n in 4:
		if got[n] == WHOLE:
			_append_piece(s, level + 1, kids[n])
		any = any or got[n] != NONE
	return PART if any else NONE


## The piece at `at` (right angle and legs, as _piece) of the grid halved `level` times, added to `s`'s cards.
func _append_piece(s: Shapes, level: int, at: Vector3i) -> void:
	var size := float(1 << level)
	var a := Vector2(at.x, at.y) / size
	var b := Vector2(at.x + at.z, at.y) / size
	var c := Vector2(at.x, at.y + at.z) / size
	var p0: Vector3 = _card_p[0]
	var e1: Vector3 = _card_p[1]
	var e2: Vector3 = _card_p[2]
	var u0: Vector2 = _card_u[0]
	var f1: Vector2 = _card_u[1]
	var f2: Vector2 = _card_u[2]
	_append_card(s, p0 + e1 * a.x + e2 * a.y, p0 + e1 * b.x + e2 * b.y, p0 + e1 * c.x + e2 * c.y,
			u0 + f1 * a.x + f2 * a.y, u0 + f1 * b.x + f2 * b.y, u0 + f1 * c.x + f2 * c.y)


## Whether the piece with its right angle at fine grid point (`i`, `j`), its legs `d` (1 up, -1 down) of the coarse
## grid along each axis, is solid at any of its corners and edges' middles (fine grid points) or its middle.
func _piece_solid(i: int, j: int, d: int, fine: int, u0: Vector2, u1: Vector2, u2: Vector2) -> bool:
	var row := fine + 1
	for q: Vector2i in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		if _solid[(i + q.x * d) * row + j + q.y * d] == 1:
			return true
	var mid := Vector2(i + d * 2.0 / 3.0, j + d * 2.0 / 3.0) / fine
	return _solid_at(u0 + (u1 - u0) * mid.x + (u2 - u0) * mid.y)


## Whether the sheet is solid at `uv`.
func _solid_at(uv: Vector2) -> bool:
	var x := clampi(int(uv.x * _sheet_size.x), 0, _sheet_size.x - 1)
	var y := clampi(int(uv.y * _sheet_size.y), 0, _sheet_size.y - 1)
	return _sheet.get_pixel(x, y).a >= _cfg.leaf_alpha_cut


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


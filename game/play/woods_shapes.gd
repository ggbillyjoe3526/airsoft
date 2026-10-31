class_name WoodsShapes
extends RefCounted
## A wood's placeholders as plain geometry (WL4; the browser game's render/dressing/woodsDressing.ts, fireflies.ts and
## the node renderer's grass and forest stand-ins): where each crown, forest tree, grass tuft, puddle, leaf drift,
## fallen piece, patch of moss, firefly and mote goes, as meshes and instance lists WoodsView draws. Seeded by the
## map's dressing seed, so a map dresses the same every build. Look only: it reads the map and makes nothing the
## simulation sees. Static functions only.

const TREE := &"tree"
const LOG := &"log"
const HILL := &"hill"
## Each part draws its own numbers from the seed, so one part's count never moves another's.
const SALT_CROWNS := 101
const SALT_FOREST := 202
const SALT_TUFTS := 303
const SALT_PUDDLES := 404
const SALT_FLOOR := 505
const SALT_AIR := 606
## The puddle mesh's surfaces, by name.
const WATER := "water"
const MUD := "mud"
## A block whose bottom is this close over the ground under its middle, or under it, stands on the ground (m).
const STANDING := 0.25
## No rectangles (a ground square no foot overlaps).
const NONE: Array[Rect2] = []
## A night-air instance's kind, in its custom data's x.
const FIREFLY := 0.0
const MOTE := 1.0


## Copies of one mesh as plain data, each with its transform and, where given, its colour (sRGB) and custom data:
## what a MultiMesh is filled from (the headless renderer keeps none of a MultiMesh's own, so tests read this).
class Placed:
	extends RefCounted
	var mesh: Mesh = null
	var xforms: Array[Transform3D] = []
	var colours: PackedColorArray = PackedColorArray()
	var custom: PackedColorArray = PackedColorArray()

	func size() -> int:
		return xforms.size()

	## A MultiMesh of them.
	func multimesh() -> MultiMesh:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = not colours.is_empty()
		mm.use_custom_data = not custom.is_empty()
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
			if mm.use_colors:
				mm.set_instance_color(i, colours[i])
			if mm.use_custom_data:
				mm.set_instance_custom_data(i, custom[i])
		return mm


## A unit cone: radius 1 round the origin at its base, its tip 1 m up, `sides` flat faces, its base closed when
## `capped` (a crown seen from under it).
static func cone(sides: int, capped: bool) -> ArrayMesh:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var tip := Vector3.UP
	for i in sides:
		var a := Vector3(cos(TAU * i / sides), 0.0, sin(TAU * i / sides))
		var b := Vector3(cos(TAU * (i + 1) / sides), 0.0, sin(TAU * (i + 1) / sides))
		_tri(pos, nor, a, tip, b)
		if capped:
			_tri(pos, nor, Vector3.ZERO, a, b)
	return _mesh(pos, nor, PackedColorArray())


## Every tree's crown (blocks of kind tree), sRGB instance colours.
static func crowns(map: MapData, cfg: WoodsConfig) -> Placed:
	var rng := _rng(map, SALT_CROWNS)
	var xforms: Array[Transform3D] = []
	var colours := PackedColorArray()
	for b in map.blocks:
		if b.kind != TREE:
			continue
		var foot := _ground_at(map, b.center.x, b.center.z, b.center.y - b.size.y * 0.5)
		var top := b.center.y + b.size.y * 0.5
		var base := foot + maxf(cfg.crown_clear, cfg.crown_from * (top - foot))
		var h := top + cfg.crown_over - base
		if h <= 0.0:
			continue
		var r := h * cfg.crown_width
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, h, r))
		xforms.append(Transform3D(basis, Vector3(b.center.x, base, b.center.z)))
		var c := cfg.crown_colours[rng.randi() % cfg.crown_colours.size()]
		colours.append(_shade(c, 1.0 + rng.randf_range(-cfg.crown_jitter, cfg.crown_jitter)))
	return _instances(cone(cfg.crown_sides, true), xforms, colours, PackedColorArray())


## The wood beyond the fence: `map.forest_trees` cones in a seeded order (a share of them is a fair sample), faded
## toward `horizon` (sRGB) a share of the way the skyline is (`sky`).
static func forest(map: MapData, cfg: WoodsConfig, sky: SkylineConfig, horizon: Color) -> Placed:
	if map.forest_trees <= 0:
		return null
	var rng := _rng(map, SALT_FOREST)
	var field := field_rect(map)
	var middle := map.middle()
	var hills: Array[SkylinePiece] = []
	for p in map.skyline:
		if p.kind == HILL:
			hills.append(p)
	var ground := GreyboxFaces.ground_top(map)
	var near: Dictionary[Vector2i, PackedVector2Array] = {}
	var xforms: Array[Transform3D] = []
	var colours := PackedColorArray()
	var far := horizon.srgb_to_linear()
	var tries := map.forest_trees * cfg.forest_tries
	while xforms.size() < map.forest_trees and tries > 0:
		tries -= 1
		var at := middle + Vector2.from_angle(rng.randf() * TAU) * cfg.forest_reach * sqrt(rng.randf())
		if outside_by(field, at) < cfg.forest_fence or _crowded(near, at, cfg.forest_apart):
			continue
		var cell := Vector2i((at / cfg.forest_apart).floor())
		var list: PackedVector2Array = near.get(cell, PackedVector2Array())
		list.append(at)
		near[cell] = list
		var y := ground
		for hill in hills:
			y = maxf(y, hill_top(hill, at, sky.hill_rings))
		var h := rng.randf_range(cfg.forest_height.x, cfg.forest_height.y)
		var r := h * cfg.forest_width
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, h, r))
		xforms.append(Transform3D(basis, Vector3(at.x, y - cfg.forest_sink, at.y)))
		var own := cfg.forest_colours[rng.randi() % cfg.forest_colours.size()].srgb_to_linear()
		var fade := clampf((at.distance_to(middle) - sky.fade_from) / sky.fade_span, 0.0, 1.0) * sky.fade_most \
				* cfg.forest_fade
		colours.append(own.lerp(far, fade).linear_to_srgb())
	return _instances(cone(cfg.forest_sides, false), xforms, colours, PackedColorArray())


## The ground the field stands on (x, z): its sloping ground's, or its blocks' footprint.
static func field_rect(map: MapData) -> Rect2:
	if map.terrain != null:
		var t := map.terrain
		return Rect2(t.min_x, t.min_z, t.max_x() - t.min_x, t.max_z() - t.min_z)
	var middle := map.middle()
	var r := Rect2(middle, Vector2.ZERO)
	for b in map.blocks:
		r = r.expand(Vector2(b.center.x - b.size.x * 0.5, b.center.z - b.size.z * 0.5))
		r = r.expand(Vector2(b.center.x + b.size.x * 0.5, b.center.z + b.size.z * 0.5))
	return r


## How far `at` lies outside `r` (m, the farther axis; 0 or less inside).
static func outside_by(r: Rect2, at: Vector2) -> float:
	return maxf(maxf(r.position.x - at.x, at.x - r.end.x), maxf(r.position.y - at.y, at.y - r.end.y))


## The top of hill `p`'s rings (SkylineShapes builds it in `rings` rings) over `at`, or -INF off it.
static func hill_top(p: SkylinePiece, at: Vector2, rings: int) -> float:
	var e := Vector2((at.x - p.at.x) / (p.width * 0.5), (at.y - p.at.y) / (p.depth * 0.5)).length()
	if e >= 1.0:
		return -INF
	var k := mini(floori((1.0 - e) * rings), rings - 1)
	var r0 := 1.0 - float(k) / rings
	var r1 := 1.0 - float(k + 1) / rings
	var y0 := p.height * cos(r0 * PI * 0.5)
	var y1 := p.height * cos(r1 * PI * 0.5)
	return lerpf(y0, y1, (r0 - e) / (r0 - r1))


## A grass tuft `height` m tall: `tuft_blades` blades round a clump, each a triangle facing each way (the back one
## its own face, so both light alike), every normal straight up so a blade lights as the ground does, its UV's v 0 at
## the foot and 1 at the tip (the shader shades it from root to tip).
static func tuft(cfg: WoodsConfig, height: float) -> ArrayMesh:
	var pos := PackedVector3Array()
	var uv := PackedVector2Array()
	for i in cfg.tuft_blades:
		var a := TAU * (i + cfg.tuft_stagger * (i % 2)) / cfg.tuft_blades
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-out.z, 0.0, out.x) * cfg.tuft_width * 0.5
		var foot := out * cfg.tuft_spread * 0.5
		var tip := foot + out * cfg.tuft_lean * height + Vector3.UP * height
		pos.append_array([foot - side, tip, foot + side, foot + side, tip, foot - side])
		uv.append_array([Vector2(0.0, 0.0), Vector2(0.5, 1.0), Vector2(1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.5, 1.0),
				Vector2(0.0, 0.0)])
	var nor := PackedVector3Array()
	nor.resize(pos.size())
	nor.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The grass tufts at the densest step's density, one list a `tile` m square of the field (row by row; an empty tile
## has none), each in a seeded order so any share of a list is a fair sample; sRGB instance colours. Empty on a map
## with no grass height or no sloping ground.
static func tufts(map: MapData, cfg: WoodsConfig, style: MapStyle) -> Array[Placed]:
	var out: Array[Placed] = []
	var t := map.terrain
	if t == null or map.grass_height <= 0.0:
		return out
	var rng := _rng(map, SALT_TUFTS)
	var density := cfg.tuft_density[cfg.tuft_density.size() - 1] if not cfg.tuft_density.is_empty() else 0.0
	var per_square := density * t.ground_cell * t.ground_cell
	var feet := _by_square(t, _feet(map, cfg.tuft_margin))
	var pools: Array[Rect2] = []
	for p in map.puddles:
		pools.append(Rect2(p.at - p.size * 0.5, p.size).grow(cfg.tuft_margin))
	var wet := _by_square(t, pools)
	var grass := style.terrain_colour(RayHit.Surface.GRASS)
	var cols := ceili((t.max_x() - t.min_x) / cfg.tile)
	var rows := ceili((t.max_z() - t.min_z) / cfg.tile)
	var per_tile: Array[Array] = []
	per_tile.resize(cols * rows)
	for i in per_tile.size():
		per_tile[i] = []
	for j in t.ground_rows:
		for i in t.ground_cols:
			if t.surfaces[j * t.ground_cols + i] != RayHit.Surface.GRASS:
				continue
			var n := floori(per_square + rng.randf())
			for k in n:
				var x := t.min_x + (i + rng.randf()) * t.ground_cell
				var z := t.min_z + (j + rng.randf()) * t.ground_cell
				var s := rng.randf_range(cfg.tuft_height.x, cfg.tuft_height.y)
				var yaw := rng.randf() * TAU
				var shade := 1.0 + rng.randf_range(-cfg.tuft_jitter, cfg.tuft_jitter)
				var key := j * t.ground_cols + i
				if _in_any(feet.get(key, NONE), Vector2(x, z)) or wet.has(key) and on_puddle(map, Vector2(x, z),
						cfg.tuft_margin):
					continue
				var tile := mini(floori((z - t.min_z) / cfg.tile), rows - 1) * cols \
						+ mini(floori((x - t.min_x) / cfg.tile), cols - 1)
				per_tile[tile].append([Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s),
						Vector3(x, t.height_at(x, z), z)), _shade(grass, shade)])
	var mesh := tuft(cfg, map.grass_height)
	for list: Array in per_tile:
		_shuffle(list, rng)
		var xforms: Array[Transform3D] = []
		var colours := PackedColorArray()
		for item: Array in list:
			xforms.append(item[0])
			colours.append(item[1])
		out.append(_instances(mesh, xforms, colours, PackedColorArray()))
	return out


## Whether `at` lies on a puddle (its outline's box grown by `margin` m).
static func on_puddle(map: MapData, at: Vector2, margin: float) -> bool:
	for p in map.puddles:
		var e := Vector2((at.x - p.at.x) / (p.size.x * 0.5 + margin), (at.y - p.at.y) / (p.size.y * 0.5 + margin))
		if e.length_squared() <= 1.0:
			return true
	return false


## Every puddle and patch of mud as one mesh over the sloping ground's own squares, vertex colours (sRGB) with their
## see-through share in alpha: the water a surface named WATER, the mud one named MUD (each only when there is some);
## null on a map with none or no sloping ground.
static func puddles(map: MapData, cfg: WoodsConfig) -> ArrayMesh:
	var t := map.terrain
	if t == null or map.puddles.is_empty():
		return null
	var rng := _rng(map, SALT_PUDDLES)
	var parts: Array[Array] = [[PackedVector3Array(), PackedVector3Array(), PackedColorArray()],
			[PackedVector3Array(), PackedVector3Array(), PackedColorArray()]]
	var gc := t.ground_cell
	var cuts := maxi(1, cfg.puddle_cuts)
	var step := gc / cuts
	for p in map.puddles:
		var phases := Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		var pos: PackedVector3Array = parts[int(p.mud)][0]
		var nor: PackedVector3Array = parts[int(p.mud)][1]
		var col: PackedColorArray = parts[int(p.mud)][2]
		var half := p.size * 0.5
		var i0 := maxi(floori((p.at.x - half.x - t.min_x) / gc), 0)
		var i1 := mini(ceili((p.at.x + half.x - t.min_x) / gc), t.ground_cols)
		var j0 := maxi(floori((p.at.y - half.y - t.min_z) / gc), 0)
		var j1 := mini(ceili((p.at.y + half.y - t.min_z) / gc), t.ground_rows)
		for j in range(j0 * cuts, j1 * cuts):
			for i in range(i0 * cuts, i1 * cuts):
				var x0 := t.min_x + i * step
				var z0 := t.min_z + j * step
				var corners: Array[Vector2] = [Vector2(x0, z0), Vector2(x0 + step, z0), Vector2(x0, z0 + step),
						Vector2(x0 + step, z0 + step)]
				var tints: Array[Color] = []
				var seen := false
				for c in corners:
					var tint := _puddle_tint(p, cfg, c, phases)
					seen = seen or tint.a > 0.0
					tints.append(tint)
				if not seen:
					continue
				var v: Array[Vector3] = []
				for c in corners:
					v.append(Vector3(c.x, t.height_at(c.x, c.y) + cfg.puddle_lift, c.y))
				# split a to d, as the ground's squares are, facing up
				_tri_coloured(pos, nor, col, v[0], v[3], v[1], tints[0], tints[3], tints[1])
				_tri_coloured(pos, nor, col, v[0], v[2], v[3], tints[0], tints[2], tints[3])
		parts[int(p.mud)] = [pos, nor, col]
	var mesh := ArrayMesh.new()
	for k in parts.size():
		var part: Array = parts[k]
		if (part[0] as PackedVector3Array).is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = part[0]
		arrays[Mesh.ARRAY_NORMAL] = part[1]
		arrays[Mesh.ARRAY_COLOR] = part[2]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(mesh.get_surface_count() - 1, MUD if k == 1 else WATER)
	return mesh if mesh.get_surface_count() > 0 else null


## The leaf drifts, fallen wood and moss as one vertex-coloured mesh (sRGB); null when the map has none of them.
static func floor_mesh(map: MapData, cfg: WoodsConfig) -> ArrayMesh:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	var rng := _rng(map, SALT_FLOOR)
	var standing := _standing(map)
	if map.terrain != null and map.leaf_drifts > 0.0:
		_leaves(map, cfg, standing, rng, pos, nor, col)
	if map.terrain != null and map.fallen > 0.0:
		_fallen(map, cfg, standing, rng, pos, nor, col)
	if map.moss_share > 0.0:
		_moss(map, cfg, standing, rng, pos, nor, col)
	if pos.is_empty():
		return null
	return _mesh(pos, nor, col)


## The fireflies (`map.fireflies`) and, with a tint, the motes (WoodsConfig.mote_count) as one list in a seeded order
## (a share of it is a fair sample of both). Each instance's custom data: x its kind (FIREFLY, MOTE), y its phase
## (0 to 1), z a firefly's pulse period (s), w its size (m). A firefly stands where it hangs; a mote's origin is its
## place in the box round the eye (0 to WoodsConfig.mote_box). Null with neither.
static func night_air(map: MapData, cfg: WoodsConfig) -> Placed:
	var motes := cfg.mote_count if map.has_motes else 0
	if map.fireflies + motes <= 0:
		return null
	var rng := _rng(map, SALT_AIR)
	var anchors: Array[Rect2] = []
	for b in _standing(map):
		if b.kind == LOG:
			anchors.append(_footprint(b, 0.0))
	for p in map.puddles:
		if not p.mud:
			anchors.append(Rect2(p.at - p.size * 0.5, p.size))
	if anchors.is_empty():
		anchors.append(field_rect(map))
	var items: Array = []
	for i in map.fireflies:
		var a := anchors[rng.randi() % anchors.size()]
		var reach := rng.randf_range(cfg.firefly_near, cfg.firefly_reach)
		var dir := Vector2.from_angle(rng.randf() * TAU)
		# out past the anchor's edge that way, then up to `firefly_reach` further
		var edge := absf(dir.x) * a.size.x * 0.5 + absf(dir.y) * a.size.y * 0.5
		var at := a.get_center() + dir * (edge + reach)
		var y := _ground_at(map, at.x, at.y, 0.0) + rng.randf_range(cfg.firefly_height.x, cfg.firefly_height.y)
		items.append([Vector3(at.x, y, at.y), Color(FIREFLY, rng.randf(), rng.randf_range(cfg.firefly_period.x,
				cfg.firefly_period.y), cfg.firefly_size)])
	for i in motes:
		var at := Vector3(rng.randf(), rng.randf(), rng.randf()) * cfg.mote_box
		items.append([at, Color(MOTE, rng.randf(), 0.0, cfg.mote_size * rng.randf_range(cfg.mote_least, 1.0))])
	_shuffle(items, rng)
	var xforms: Array[Transform3D] = []
	var custom := PackedColorArray()
	for item: Array in items:
		xforms.append(Transform3D(Basis.IDENTITY, item[0]))
		custom.append(item[1])
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	return _instances(quad, xforms, PackedColorArray(), custom)


# --- the floor's parts ---

static func _leaves(map: MapData, cfg: WoodsConfig, standing: Array[MapData.Block], rng: RandomNumberGenerator,
		pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray) -> void:
	var t := map.terrain
	var cols := ceili((t.max_x() - t.min_x) / cfg.leaf_cell)
	var rows := ceili((t.max_z() - t.min_z) / cfg.leaf_cell)
	# each square's nearest foot within leaf_near of its middle (its footprint, and how far)
	var nearest: Dictionary[int, Rect2] = {}
	var how_far: Dictionary[int, float] = {}
	for b in standing:
		var foot := _footprint(b, 0.0)
		var grown := foot.grow(cfg.leaf_near)
		for j in range(maxi(floori((grown.position.y - t.min_z) / cfg.leaf_cell), 0),
				mini(ceili((grown.end.y - t.min_z) / cfg.leaf_cell), rows)):
			for i in range(maxi(floori((grown.position.x - t.min_x) / cfg.leaf_cell), 0),
					mini(ceili((grown.end.x - t.min_x) / cfg.leaf_cell), cols)):
				var middle := Vector2(t.min_x + (i + 0.5) * cfg.leaf_cell, t.min_z + (j + 0.5) * cfg.leaf_cell)
				var d := _to_rect(foot, middle).length()
				var key := j * cols + i
				if d <= cfg.leaf_near and d < how_far.get(key, INF):
					how_far[key] = d
					nearest[key] = foot
	var keys := nearest.keys()
	keys.sort()
	for key: int in keys:
		if rng.randf() >= map.leaf_drifts:
			continue
		var middle := Vector2(t.min_x + (key % cols + 0.5) * cfg.leaf_cell, t.min_z + (key / cols + 0.5) * cfg.leaf_cell)
		var foot: Rect2 = nearest[key]
		var toward := _to_rect(foot, middle)
		var spot := middle - toward + (toward.normalized() if toward != Vector2.ZERO else Vector2.RIGHT) \
				* cfg.leaf_radius * cfg.leaf_out
		var n := rng.randi_range(cfg.leaf_count.x, cfg.leaf_count.y)
		for k in n:
			var at := spot + Vector2.from_angle(rng.randf() * TAU) * cfg.leaf_radius * sqrt(rng.randf())
			var length := rng.randf_range(cfg.leaf_size.x, cfg.leaf_size.y)
			var along := Vector2.from_angle(rng.randf() * TAU) * length * 0.5
			var across := Vector2(-along.y, along.x) * 0.5
			var colour := cfg.leaf_colours[rng.randi() % cfg.leaf_colours.size()]
			if on_puddle(map, at, 0.0) or is_nan(t.height_at(at.x, at.y)):
				continue
			var q: Array[Vector3] = []
			for c: Vector2 in [at - along - across, at - along + across, at + along + across, at + along - across]:
				q.append(Vector3(c.x, t.height_clamped(c.x, c.y) + cfg.leaf_lift, c.y))
			_quad(pos, nor, col, q, colour)


static func _fallen(map: MapData, cfg: WoodsConfig, standing: Array[MapData.Block], rng: RandomNumberGenerator,
		pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray) -> void:
	var t := map.terrain
	var total := cfg.fallen_weights.x + cfg.fallen_weights.y + cfg.fallen_weights.z
	var spots := PackedVector2Array()
	for e in map.ends:
		for s: SpawnPoint in e.spawns + e.dead_zone:
			spots.append(Vector2(s.position.x, s.position.z))
	for p in map.poles:
		spots.append(Vector2(p.x, p.z))
	for b in standing:
		if b.size.y < cfg.fallen_min_height:
			continue
		for side in 4:
			var normal := Vector2(1.0 if side == 0 else -1.0 if side == 1 else 0.0,
					1.0 if side == 2 else -1.0 if side == 3 else 0.0)
			var along := Vector2(absf(normal.y), absf(normal.x))
			var length := b.size.x if normal.x == 0.0 else b.size.z
			var out_by := (b.size.x if normal.x != 0.0 else b.size.z) * 0.5
			var room := length - 2.0 * cfg.fallen_corner
			if room <= 0.0:
				continue
			var slots := maxi(1, floori(room / cfg.fallen_step))
			for k in slots:
				var take := rng.randf()
				var kind := rng.randf() * total
				var piece := 0 if kind < cfg.fallen_weights.x else 1 if kind < cfg.fallen_weights.x \
						+ cfg.fallen_weights.y else 2
				var size := cfg.fallen_sizes[piece]
				var reach := minf(size.x, room / slots)
				var shift := (float(k) + 0.5) * room / slots - room * 0.5
				var middle := Vector2(b.center.x, b.center.z) + normal * (out_by + size.y * 0.5) + along * shift
				if take >= map.fallen or is_nan(t.height_at(middle.x, middle.y)) or on_puddle(map, middle, cfg.fallen_puddle) \
						or _near_lane(map, middle, cfg.fallen_lane) or _near_spot(spots, middle, cfg.fallen_spot):
					continue
				var bark := cfg.bark[rng.randi() % cfg.bark.size()]
				var yaw := rng.randf_range(-cfg.fallen_turn, cfg.fallen_turn)
				var dir := along.rotated(yaw)
				match piece:
					0:
						_log_piece(t, cfg, middle, dir, reach, size.z, bark, bark, pos, nor, col)
					1:
						for s in cfg.twigs:
							var twig := dir.rotated(rng.randf_range(-cfg.twig_turn, cfg.twig_turn))
							var at := middle + Vector2(-dir.y, dir.x) * rng.randf_range(-0.5, 0.5) * size.y
							_log_piece(t, cfg, at, twig, reach * rng.randf_range(cfg.twig_least, 1.0), size.z, bark, bark, pos,
									nor, col)
					2:
						_log_piece(t, cfg, middle, dir, reach, size.z, bark, cfg.grain, pos, nor, col)


static func _moss(map: MapData, cfg: WoodsConfig, standing: Array[MapData.Block], rng: RandomNumberGenerator,
		pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray) -> void:
	for b in standing:
		if b.kind != LOG or rng.randf() >= map.moss_share:
			continue
		var lo := b.center - b.size * 0.5
		var hi := b.center + b.size * 0.5
		_box(pos, nor, col, Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y + cfg.moss_proud, hi.z), map.moss)
		_box(pos, nor, col, Vector3(lo.x, hi.y - b.size.y * cfg.moss_band, lo.z - cfg.moss_proud),
				Vector3(hi.x, hi.y, lo.z), map.moss)


## A round piece of wood lying on the ground from `middle` along `dir`, `length` m long and `thick` m across, its
## ends in `ends`.
static func _log_piece(t: TerrainGrid, cfg: WoodsConfig, middle: Vector2, dir: Vector2, length: float, thick: float,
		bark: Color, ends: Color, pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray) -> void:
	var r := thick * 0.5
	var a2 := middle - dir * length * 0.5
	var b2 := middle + dir * length * 0.5
	var a := Vector3(a2.x, t.height_clamped(a2.x, a2.y) + r - cfg.fallen_sink, a2.y)
	var b := Vector3(b2.x, t.height_clamped(b2.x, b2.y) + r - cfg.fallen_sink, b2.y)
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP).normalized()
	var up := side.cross(axis).normalized()
	var ring_a: Array[Vector3] = []
	var ring_b: Array[Vector3] = []
	for i in cfg.fallen_sides:
		var ang := TAU * i / cfg.fallen_sides
		var off := (side * cos(ang) + up * sin(ang)) * r
		ring_a.append(a + off)
		ring_b.append(b + off)
	var n := cfg.fallen_sides
	for i in n:
		var j := (i + 1) % n
		_quad(pos, nor, col, [ring_a[i], ring_b[i], ring_b[j], ring_a[j]] as Array[Vector3], bark)
	for i in range(1, n - 1):
		_tri_coloured(pos, nor, col, ring_a[0], ring_a[i], ring_a[i + 1], ends, ends, ends)
		_tri_coloured(pos, nor, col, ring_b[0], ring_b[i + 1], ring_b[i], ends, ends, ends)


# --- helpers ---

## The blocks standing on the ground (not a ramp, their bottom within STANDING of the ground under their middle).
static func _standing(map: MapData) -> Array[MapData.Block]:
	var out: Array[MapData.Block] = []
	for b in map.blocks:
		if b.rise != MapData.Rise.NONE:
			continue
		var bottom := b.center.y - b.size.y * 0.5
		if bottom <= _ground_at(map, b.center.x, b.center.z, bottom) + STANDING:
			out.append(b)
	return out


## Every standing block's footprint grown by `margin`.
static func _feet(map: MapData, margin: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for b in _standing(map):
		out.append(_footprint(b, margin))
	return out


## `rects` by the ground squares (row by row) each overlaps, so a point need only be tested against its own square's.
static func _by_square(t: TerrainGrid, rects: Array[Rect2]) -> Dictionary[int, Array]:
	var out: Dictionary[int, Array] = {}
	for r in rects:
		var i0 := maxi(floori((r.position.x - t.min_x) / t.ground_cell), 0)
		var i1 := mini(floori((r.end.x - t.min_x) / t.ground_cell), t.ground_cols - 1)
		var j0 := maxi(floori((r.position.y - t.min_z) / t.ground_cell), 0)
		var j1 := mini(floori((r.end.y - t.min_z) / t.ground_cell), t.ground_rows - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var key := j * t.ground_cols + i
				if not out.has(key):
					var list: Array[Rect2] = []
					out[key] = list
				out[key].append(r)
	return out


static func _footprint(b: MapData.Block, margin: float) -> Rect2:
	return Rect2(b.center.x - b.size.x * 0.5, b.center.z - b.size.z * 0.5, b.size.x, b.size.z).grow(margin)


static func _in_any(rects: Array[Rect2], at: Vector2) -> bool:
	for r in rects:
		if r.has_point(at):
			return true
	return false


## From the nearest point of `r` to `at` (zero inside it).
static func _to_rect(r: Rect2, at: Vector2) -> Vector2:
	return at - at.clamp(r.position, r.end)


static func _near_lane(map: MapData, at: Vector2, clear: float) -> bool:
	for lane in map.lanes:
		for i in lane.size() - 1:
			var a := Vector2(lane[i].x, lane[i].z)
			var b := Vector2(lane[i + 1].x, lane[i + 1].z)
			if Geometry2D.get_closest_point_to_segment(at, a, b).distance_to(at) < clear:
				return true
	return false


static func _near_spot(spots: PackedVector2Array, at: Vector2, clear: float) -> bool:
	for s in spots:
		if s.distance_to(at) < clear:
			return true
	return false


static func _crowded(near: Dictionary[Vector2i, PackedVector2Array], at: Vector2, apart: float) -> bool:
	var cell := Vector2i((at / apart).floor())
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for q: Vector2 in near.get(cell + Vector2i(dx, dz), PackedVector2Array()):
				if q.distance_to(at) < apart:
					return true
	return false


## The ground under (x, z): sloping ground's, or `otherwise` off it or without it.
static func _ground_at(map: MapData, x: float, z: float, otherwise: float) -> float:
	if map.terrain == null:
		return otherwise
	var h := map.terrain.height_at(x, z)
	return otherwise if is_nan(h) else h


## A puddle's colour and see-through share at `at` (alpha 0 outside its wobbled outline).
static func _puddle_tint(p: MapData.Puddle, cfg: WoodsConfig, at: Vector2, phases: Vector3) -> Color:
	var d := Vector2((at.x - p.at.x) / (p.size.x * 0.5), (at.y - p.at.y) / (p.size.y * 0.5))
	var ang := d.angle()
	var wave := (sin(ang * 2.0 + phases.x) + 0.6 * sin(ang * 3.0 + phases.y) + 0.4 * sin(ang * 5.0 + phases.z)) / 2.0
	var outline := 1.0 - cfg.puddle_wobble * (0.5 + 0.5 * clampf(wave, -1.0, 1.0))
	var e := d.length() / outline
	if e >= 1.0:
		return Color(0, 0, 0, 0)
	var core := cfg.mud if p.mud else cfg.water
	var core_a := cfg.mud_alpha if p.mud else cfg.water_alpha
	var edge := cfg.mud_wet if p.mud else cfg.wet
	var edge_a := cfg.mud_wet_alpha if p.mud else cfg.wet_alpha
	if e <= cfg.puddle_core:
		return Color(core.r, core.g, core.b, core_a)
	# from the middle's colour and share through the wet margin's to nothing at the outline, with no step
	var s := (e - cfg.puddle_core) / (1.0 - cfg.puddle_core)
	var c := core.lerp(edge, s)
	return Color(c.r, c.g, c.b, lerpf(core_a, edge_a, s) * (1.0 - s * s))


static func _shade(c: Color, k: float) -> Color:
	return Color(clampf(c.r * k, 0.0, 1.0), clampf(c.g * k, 0.0, 1.0), clampf(c.b * k, 0.0, 1.0))


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = list[i]
		list[i] = list[j]
		list[j] = swap


static func _rng(map: MapData, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(map.dressing_seed, salt))
	return rng


static func _instances(mesh: Mesh, xforms: Array[Transform3D], colours: PackedColorArray,
		custom: PackedColorArray) -> Placed:
	var p := Placed.new()
	p.mesh = mesh
	p.xforms = xforms
	p.colours = colours
	p.custom = custom
	return p


static func _mesh(pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nor
	if not col.is_empty():
		arrays[Mesh.ARRAY_COLOR] = col
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## One flat triangle given anticlockwise seen from its front (Godot's front faces wind clockwise, so it is stored
## the other way round).
static func _tri(pos: PackedVector3Array, nor: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	pos.append_array([a, c, b])
	nor.append_array([n, n, n])


static func _tri_coloured(pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray, a: Vector3,
		b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	_tri(pos, nor, a, b, c)
	col.append_array([ca, cc, cb])


## A flat quad, its corners anticlockwise seen from its front.
static func _quad(pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray, q: Array[Vector3],
		colour: Color) -> void:
	_tri_coloured(pos, nor, col, q[0], q[1], q[2], colour, colour, colour)
	_tri_coloured(pos, nor, col, q[0], q[2], q[3], colour, colour, colour)


## An axis-aligned box's six faces, outward.
static func _box(pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray, lo: Vector3, hi: Vector3,
		colour: Color) -> void:
	for f in GreyboxFaces.faces_of(_block(lo, hi)):
		_quad(pos, nor, col, [f[0], f[1], f[2], f[3]] as Array[Vector3], colour)


static func _block(lo: Vector3, hi: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.center = (lo + hi) * 0.5
	b.size = hi - lo
	return b

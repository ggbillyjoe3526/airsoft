class_name PropLayout
extends RefCounted
## Where a site's CC0 props stand (DR2): for every block of a kind PropDressConfig dresses, each model's transform
## inside the block's box, laid as the kind says (a row, a cluster on a pallet, or one model fitted to the box). Pure
## and seeded (the map's dressing seed); no node. A prop never reaches past its block's box, so what you see is what
## stops a BB and a body.

## How far (m) past a face TILE looks for a block that hides it.
const FACE_SLAB := 0.04


## One model's instances: a transform and a shade (1 is the model's own colours) each.
class Placed:
	extends RefCounted
	var transforms: Array[Transform3D] = []
	var shades: PackedFloat32Array = PackedFloat32Array()

	func add(t: Transform3D, shade: float) -> void:
		transforms.append(t)
		shades.append(shade)


## The props of `map`: each model's Placed, by model name. `boxes` is each model's own bounds (its mesh's AABB);
## a kind whose model has none is left as its box (and warned once by PropDress, which loads them).
static func layout(map: MapData, cfg: PropDressConfig, boxes: Dictionary[StringName, AABB]) -> Dictionary[StringName, Placed]:
	var out: Dictionary[StringName, Placed] = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = map.dressing_seed
	var middle := field_middle(map)
	for b in map.blocks:
		if not cfg.dresses(b) or b.rise != MapData.Rise.NONE:
			continue
		var model := cfg.model_of(b)
		if not boxes.has(model):
			continue
		var foot := b.center - Vector3(0.0, b.size.y * 0.5, 0.0)
		match cfg.lay_of(b):
			PropDressConfig.Lay.ROW:
				_row(_placed(out, model), boxes[model], foot, b.size, cfg, rng)
			PropDressConfig.Lay.CLUSTER:
				var lift := 0.0
				if boxes.has(cfg.pallet) and cfg.pallet_height < b.size.y:
					lift = cfg.pallet_height
					_placed(out, cfg.pallet).add(fit(boxes[cfg.pallet], foot, Vector3(b.size.x, lift, b.size.z), 0.0),
							1.0)
				_cluster(_placed(out, model), boxes[model], foot + Vector3(0.0, lift, 0.0),
						Vector3(b.size.x, b.size.y - lift, b.size.z), cfg, rng)
			PropDressConfig.Lay.TILE:
				_tile(_placed(out, model), boxes[model], b, foot, cfg, map)
			PropDressConfig.Lay.GRID:
				_grid(_placed(out, model), boxes[model], foot, b.size, cfg.grid_cells.get(model, b.size), cfg, rng)
			_:
				_placed(out, model).add(_fit_facing(boxes[model], b, foot, middle), 1.0)
	return out


## The transform that stretches a model of bounds `model` to `size` (in the model's own axes, before its turn),
## turned `yaw` about up, the middle of its foot at `foot`.
static func fit(model: AABB, foot: Vector3, size: Vector3, yaw: float) -> Transform3D:
	var scale := Vector3(size.x / maxf(model.size.x, 1e-6), size.y / maxf(model.size.y, 1e-6),
			size.z / maxf(model.size.z, 1e-6))
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(scale)
	var base := model.position + Vector3(model.size.x * 0.5, 0.0, model.size.z * 0.5)
	return Transform3D(basis, foot - basis * base)


## The middle of the field on the ground: halfway between the teams' spawns.
static func field_middle(map: MapData) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for end in map.ends:
		for s in end.spawns:
			sum += s.position
			n += 1
	return Vector3(sum.x, 0.0, sum.z) / maxf(n, 1.0)


static func _placed(out: Dictionary[StringName, Placed], model: StringName) -> Placed:
	if not out.has(model):
		out[model] = Placed.new()
	return out[model]


## Round props upright along the box's long side, each as wide as the short side (or its share of the long one).
static func _row(p: Placed, model: AABB, foot: Vector3, size: Vector3, cfg: PropDressConfig,
		rng: RandomNumberGenerator) -> void:
	var along_x := size.x >= size.z
	var long := size.x if along_x else size.z
	var short := size.z if along_x else size.x
	var n := maxi(1, roundi(long / maxf(short, 1e-6)))
	var cell := long / n
	var d := minf(cell, short)
	for i in n:
		var step := (i + 0.5) * cell - long * 0.5
		var at := foot + (Vector3(step, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, step))
		p.add(fit(model, at, Vector3(d, size.y, d), _quarter_turn(rng)), _shade(cfg, rng))


## Round props upright in a grid of cells about `cluster_cell` across, filling the box.
static func _cluster(p: Placed, model: AABB, foot: Vector3, size: Vector3, cfg: PropDressConfig,
		rng: RandomNumberGenerator) -> void:
	var nx := maxi(1, roundi(size.x / cfg.cluster_cell))
	var nz := maxi(1, roundi(size.z / cfg.cluster_cell))
	var cx := size.x / nx
	var cz := size.z / nz
	var d := minf(cx, cz)
	for i in nx:
		for j in nz:
			var at := foot + Vector3((i + 0.5) * cx - size.x * 0.5, 0.0, (j + 0.5) * cz - size.z * 0.5)
			p.add(fit(model, at, Vector3(d, size.y, d), _quarter_turn(rng)), _shade(cfg, rng))


## The box filled with the model in cells about `cell` m across (x along the box's long side, y up, 0 for one layer,
## z across), stacked from the foot, each stretched to its cell, the model's z across the box; a quarter turn either
## way at random where that keeps it so (a round model, a square one), so a stack never reads as one model repeated.
static func _grid(p: Placed, model: AABB, foot: Vector3, size: Vector3, cell: Vector3, cfg: PropDressConfig,
		rng: RandomNumberGenerator) -> void:
	var along_x := size.x >= size.z
	var long := size.x if along_x else size.z
	var across := size.z if along_x else size.x
	var n := Vector3i(maxi(1, roundi(long / maxf(cell.x, 1e-6))),
			1 if cell.y <= 0.0 else maxi(1, roundi(size.y / cell.y)), maxi(1, roundi(across / maxf(cell.z, 1e-6))))
	var step := Vector3(long / n.x, size.y / n.y, across / n.z)
	# The model's z across the box: unturned on a box long in x, a quarter turn (its z to world x) on one long in z.
	var yaw := 0.0 if along_x else PI * 0.5
	var square := absf(model.size.x - model.size.z) < 0.05 * maxf(model.size.x, model.size.z)
	for i in n.x:
		for k in n.z:
			var u := (i + 0.5) * step.x - long * 0.5
			var v := (k + 0.5) * step.z - across * 0.5
			var at := foot + (Vector3(u, 0.0, v) if along_x else Vector3(v, 0.0, u))
			for j in n.y:
				var turn := yaw + (_quarter_turn(rng) if square else PI * float(rng.randi_range(0, 1)))
				p.add(fit(model, at + Vector3(0.0, j * step.y, 0.0), _turned(step, turn - yaw), turn),
						_shade(cfg, rng))


## A cell's size in the model's own axes once it is turned `turn` more than its first lay: x and z swap a quarter turn
## round.
static func _turned(size: Vector3, turn: float) -> Vector3:
	return Vector3(size.z, size.y, size.x) if absi(roundi(turn / (PI * 0.5))) % 2 == 1 else size


## One model fitted to the whole box, its long side along the box's and its front (the model's +z) facing the field's
## middle: across the box for a model long in x (a sofa), along it for one long in z.
static func _fit_facing(model: AABB, b: MapData.Block, foot: Vector3, middle: Vector3) -> Transform3D:
	var long := maxf(b.size.x, b.size.z)
	var short := minf(b.size.x, b.size.z)
	var model_long_x := model.size.x >= model.size.z
	var size := Vector3(long, b.size.y, short) if model_long_x else Vector3(short, b.size.y, long)
	# the model's front lands on world z for yaw 0 or PI, on world x for a quarter turn (+x at PI / 2)
	var front_on_z := (b.size.x >= b.size.z) == model_long_x
	var to := middle - b.center
	var yaw: float
	if front_on_z:
		yaw = 0.0 if to.z >= 0.0 else PI
	else:
		yaw = PI * 0.5 if to.x >= 0.0 else -PI * 0.5
	return fit(model, foot, size, yaw)


## Block `b`'s TILE rows: each face's row depth (m, PropDressConfig.tile_depths), 0 on a face with none, too short
## or wholly against another block (face_hidden). `low` holds the faces towards -x and -z, `high` those towards +x and
## +z (y unused). The rows along x run the whole face; those along z run between them, to the corner where a row along
## x is missing; SiteSurface draws the backing half a row inside each lined face and flush with the rest, so the box's
## footprint is all props or backing.
class Lining:
	var low: Vector3 = Vector3.ZERO
	var high: Vector3 = Vector3.ZERO


static func lining(map: MapData, cfg: PropDressConfig, b: MapData.Block) -> Lining:
	var rows := cfg.tile_depths(b)
	var line := Lining.new()
	for side: float in [-1.0, 1.0]:
		var d := Vector3(rows.y if rows.y > 0.0 and not face_hidden(map, b, Vector3(side, 0.0, 0.0)) else 0.0, 0.0,
				rows.x if rows.x > 0.0 and not face_hidden(map, b, Vector3(0.0, 0.0, side)) else 0.0)
		if side < 0.0:
			line.low = d
		else:
			line.high = d
	return line


## The box's lined faces (`lining`) filled with rows of the model as tall as the box, each row facing out and holding
## as many models as fit at their own width (each stretched a little to fill the row).
static func _tile(p: Placed, model: AABB, b: MapData.Block, foot: Vector3, cfg: PropDressConfig, map: MapData) -> void:
	var line := lining(map, cfg, b)
	var k := b.size.y / maxf(model.size.y, 1e-6)
	var wide := maxf(model.size.x, model.size.z) * k
	var model_long_x := model.size.x >= model.size.z
	var h := b.size * 0.5
	var z_mid := (line.low.z - line.high.z) * 0.5
	var z_length := b.size.z - line.low.z - line.high.z
	for side: float in [-1.0, 1.0]:
		var d := line.low if side < 0.0 else line.high
		if d.z > 0.0:
			_tile_row(p, model, foot + Vector3(0.0, 0.0, side * (h.z - d.z * 0.5)), b.size.x, d.z, b.size.y,
					true, side, wide, model_long_x)
		if d.x > 0.0:
			_tile_row(p, model, foot + Vector3(side * (h.x - d.x * 0.5), 0.0, z_mid), z_length, d.x, b.size.y,
					false, side, wide, model_long_x)


## Whether block `b`'s face towards `out` (a unit axis) is wholly against another block: a thin slab just outside
## it lies inside one other box, so nobody sees it and it needs no props.
static func face_hidden(map: MapData, b: MapData.Block, out: Vector3) -> bool:
	var lo := b.center - b.size * 0.5
	var size := b.size
	var axis := 0 if out.x != 0.0 else 2
	if out[axis] > 0.0:
		lo[axis] += b.size[axis]
	else:
		lo[axis] -= FACE_SLAB
	size[axis] = FACE_SLAB
	var slab := AABB(lo, size).grow(-FACE_SLAB * 0.25)
	for o in map.blocks:
		if o != b and o.rise == MapData.Rise.NONE and AABB(o.center - o.size * 0.5, o.size).encloses(slab):
			return true
	return false


## One row of TILE: `length` long along x (or z), `depth` deep, its middle's foot at `at`, facing `side` (+1 or -1)
## across it.
static func _tile_row(p: Placed, model: AABB, at: Vector3, length: float, depth: float, height: float,
		along_x: bool, side: float, wide: float, model_long_x: bool) -> void:
	var n := maxi(1, roundi(length / wide))
	var cell := length / n
	var size := Vector3(cell, height, depth) if model_long_x else Vector3(depth, height, cell)
	# the model's long side runs along the row; a model long in x faces out with its front (+z)
	var yaw: float
	if along_x == model_long_x:
		yaw = 0.0 if side > 0.0 else PI
	else:
		yaw = PI * 0.5 if side > 0.0 else -PI * 0.5
	for i in n:
		var step := (i + 0.5) * cell - length * 0.5
		p.add(fit(model, at + (Vector3(step, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, step)), size, yaw), 1.0)


## A round prop's turn: a random quarter, so the model's own bounds (and so the box) still hold it.
static func _quarter_turn(rng: RandomNumberGenerator) -> float:
	return rng.randi_range(0, 3) * PI * 0.5


static func _shade(cfg: PropDressConfig, rng: RandomNumberGenerator) -> float:
	return 1.0 + rng.randf_range(-cfg.shade_jitter, cfg.shade_jitter)

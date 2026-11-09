class_name PropLayout
extends RefCounted
## Where a site's CC0 props stand (DR2): for every block of a kind PropDressConfig dresses, each model's transform
## inside the block's box, laid as the kind says (a row, a cluster on a pallet, or one model fitted to the box). Pure
## and seeded (the map's dressing seed); no node. A prop never reaches past its block's box, so what you see is what
## stops a BB and a body.

## How far (m) past a face TILE looks for a block that hides it.
const FACE_SLAB := 0.04


## One model's instances: a transform, a shade (1 is the model's own colours) and a paint (a linear multiplier, white
## for the model's own colours; a container's unit paint, DM1) each.
class Placed:
	extends RefCounted
	var transforms: Array[Transform3D] = []
	var shades: PackedFloat32Array = PackedFloat32Array()
	var paints: PackedColorArray = PackedColorArray()

	func add(t: Transform3D, shade: float, paint: Color = Color.WHITE) -> void:
		transforms.append(t)
		shades.append(shade)
		paints.append(paint)


## The props of `map`: each model's Placed, by model name. `boxes` is each model's own bounds (its mesh's AABB);
## a kind whose model has none is left as its box (and warned once by PropDress, which loads them). `paint`, when
## valid, gives each block's paint (block -> linear Color, SiteLook.prop_paint) to its UNIT props.
static func layout(map: MapData, cfg: PropDressConfig, boxes: Dictionary[StringName, AABB],
		paint: Callable = Callable()) -> Dictionary[StringName, Placed]:
	var out: Dictionary[StringName, Placed] = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = map.dressing_seed
	var middle := field_middle(map)
	var features_laid := 0
	var turns := Turns.new(out, boxes, map.dressing_seed)
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
				_tile(turns, cfg.variants_of(model), b, foot, cfg, map)
			PropDressConfig.Lay.GRID:
				_grid(out, _variants(model, boxes, cfg), boxes, foot, b.size, cfg.grid_cells.get(model, b.size), cfg,
						rng, model)
			PropDressConfig.Lay.UNIT:
				var tint := Color.WHITE
				if paint.is_valid():
					tint = paint.call(_first_joined(b, map, cfg))
				_placed(out, model).add(_unit(boxes[model], b, foot, map, middle, cfg), 1.0, tint)
			PropDressConfig.Lay.RUN:
				_run(_placed(out, model), boxes[model], foot, b.size, cfg.run_lengths.get(model, maxf(b.size.x, b.size.z)),
						cfg, rng)
			PropDressConfig.Lay.BAY:
				features_laid = _bays(out, model, boxes, b, map, cfg, middle, features_laid)
			PropDressConfig.Lay.GROUND:
				_ground(out, model, boxes, b, map, cfg, rng)
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


## Round props upright in a grid of cells about `cluster_cell` across, filling the box's height, each `cluster_fill` of
## its cell wide (RK1: a drum stack keeps a real drum's shape, a hand's width between them).
static func _cluster(p: Placed, model: AABB, foot: Vector3, size: Vector3, cfg: PropDressConfig,
		rng: RandomNumberGenerator) -> void:
	var nx := maxi(1, roundi(size.x / cfg.cluster_cell))
	var nz := maxi(1, roundi(size.z / cfg.cluster_cell))
	var cx := size.x / nx
	var cz := size.z / nz
	var d := minf(cx, cz) * cfg.cluster_fill
	for i in nx:
		for j in nz:
			var at := foot + Vector3((i + 0.5) * cx - size.x * 0.5, 0.0, (j + 0.5) * cz - size.z * 0.5)
			p.add(fit(model, at, Vector3(d, size.y, d), _quarter_turn(rng)), _shade(cfg, rng))


## The box filled with the model in cells about `cell` m across (x along the box's long side, y up, 0 for one layer,
## z across), stacked from the foot, each stretched to its cell, the model's z across the box; a quarter turn either
## way at random where that keeps it so (a round model, a square one), else a half turn, so a stack never reads as
## one model repeated; never turned for a model (`model_name`) in PropDressConfig.grid_unturned. Each cell takes one of
## `picks` at random (the model and its variants).
static func _grid(out: Dictionary[StringName, Placed], picks: Array[StringName], boxes: Dictionary[StringName, AABB],
		foot: Vector3, size: Vector3, cell: Vector3, cfg: PropDressConfig, rng: RandomNumberGenerator,
		model_name: StringName = &"") -> void:
	var model := boxes[picks[0]]
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
				if cfg.grid_unturned.has(model_name):
					turn = yaw
				var pick := picks[0] if picks.size() == 1 else picks[rng.randi_range(0, picks.size() - 1)]
				# a stack of variant sections keeps one shade along it, so its joins don't show as steps; the shade is
				# still drawn, so every model's random stream stays as it was
				var shade := _shade(cfg, rng)
				if picks.size() > 1:
					shade = 1.0
				_placed(out, pick).add(fit(boxes[pick], at + Vector3(0.0, j * step.y, 0.0), _turned(step, turn - yaw),
						turn), shade)


## `model` and its GRID variants (PropDressConfig.variants) that have bounds in `boxes`, `model` first.
static func _variants(model: StringName, boxes: Dictionary[StringName, AABB],
		cfg: PropDressConfig) -> Array[StringName]:
	var out: Array[StringName] = []
	for v in cfg.variants_of(model):
		if v == model or boxes.has(v):
			out.append(v)
	return out


## A wall's modules end to end along the box's long side, `length` m each (PropDressConfig.run_stretch: stretched a
## little, or a cut one at the high end), each as tall and as thick as the box, its x along the wall, turned end for
## end at random so a long wall never reads as one module repeated.
static func _run(p: Placed, model: AABB, foot: Vector3, size: Vector3, length: float, cfg: PropDressConfig,
		rng: RandomNumberGenerator) -> void:
	var along_x := size.x >= size.z
	var long := size.x if along_x else size.z
	var across := size.z if along_x else size.x
	var pitch := maxf(length, 1e-6)
	# Whole modules at the pitch, stretched to take up what is left when that is at most a tenth of them (or a sliver
	# under run_min_cut of a module, never laid alone); otherwise a cut module (a sheet cut down) at the high end.
	var n := floori(long / pitch + 1e-6)
	var rest := long - n * pitch
	var widths := PackedFloat32Array()
	if n == 0:
		widths.append(long)
	elif rest <= cfg.run_stretch * n * pitch or rest < cfg.run_min_cut * pitch:
		for i in n:
			widths.append(long / n)
	else:
		for i in n:
			widths.append(pitch)
		widths.append(rest)
	var yaw := 0.0 if along_x else PI * 0.5
	var u := -long * 0.5
	for w in widths:
		var at := foot + (Vector3(u + w * 0.5, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, u + w * 0.5))
		p.add(fit(model, at, Vector3(w, size.y, across), yaw + PI * float(rng.randi_range(0, 1))), _shade(cfg, rng))
		u += w


## One model fitted to block `b`'s box, its x along the box's long side, or, on a box near square (its long side under
## PropDressConfig.unit_square times its short), along the axis a block of its kind touches one of its ends on (a cut
## length between two units lies along their row: a row of units side by side never turns one across); its +x end turned away from a
## block of its kind against one of those ends (PropDressConfig.unit_reach), else away from the field's middle: a
## container's doors at the free end of each unit, never into the port cut between two.
static func _unit(model: AABB, b: MapData.Block, foot: Vector3, map: MapData, middle: Vector3,
		cfg: PropDressConfig) -> Transform3D:
	var ends := Vector2(_end_touches(b, 0, map, cfg), _end_touches(b, 2, map, cfg)) # x, z: -1 low end, +1 high end
	var touched := Vector2(_touch_count(b, 0, map, cfg), _touch_count(b, 2, map, cfg))
	var along_x := b.size.x >= b.size.z
	if maxf(b.size.x, b.size.z) < cfg.unit_square * minf(b.size.x, b.size.z):
		if touched.x > 0.0 and touched.y == 0.0:
			along_x = true
		elif touched.y > 0.0 and touched.x == 0.0:
			along_x = false
	var axis := 0 if along_x else 2
	var side := 2 if along_x else 0
	var end := -(ends.x if along_x else ends.y) # the doors away from the touching blocks
	if end == 0.0:
		end = 1.0 if b.center[axis] >= middle[axis] else -1.0
	# The model's +x to world +x unturned, -x a half turn; to world -z a quarter turn, +z three quarters.
	var yaw := (0.0 if end > 0.0 else PI) if along_x else (PI * 0.5 if end < 0.0 else -PI * 0.5)
	return fit(model, foot, Vector3(b.size[axis], b.size.y, b.size[side]), yaw)


## The blocks of `b`'s kind against its ends along `axis` (0 x, 2 z), overlapping it across and up: the high end's
## count less the low end's (so +1: a block at its high end only).
static func _end_touches(b: MapData.Block, axis: int, map: MapData, cfg: PropDressConfig) -> float:
	var sum := 0.0
	for o in _against(b, axis, map, cfg):
		sum += 1.0 if o.center[axis] > b.center[axis] else -1.0
	return sum


static func _touch_count(b: MapData.Block, axis: int, map: MapData, cfg: PropDressConfig) -> float:
	return float(_against(b, axis, map, cfg).size())


## The blocks of `b`'s kind whose faces meet one of `b`'s end faces along `axis` (within PropDressConfig.unit_reach),
## overlapping it on the other two axes.
static func _against(b: MapData.Block, axis: int, map: MapData, cfg: PropDressConfig) -> Array[MapData.Block]:
	var out: Array[MapData.Block] = []
	var lo := b.center - b.size * 0.5
	var hi := b.center + b.size * 0.5
	var other := 2 if axis == 0 else 0
	for o in map.blocks:
		if o == b or o.kind != b.kind:
			continue
		var olo := o.center - o.size * 0.5
		var ohi := o.center + o.size * 0.5
		if olo[other] >= hi[other] or ohi[other] <= lo[other] or olo.y >= hi.y or ohi.y <= lo.y:
			continue
		if absf(olo[axis] - hi[axis]) <= cfg.unit_reach or absf(ohi[axis] - lo[axis]) <= cfg.unit_reach:
			out.append(o)
	return out


## The first block (in file order) of the blocks of `b`'s kind joined to it by touching (within
## PropDressConfig.unit_reach on every side): one cut container's units, ports and roof are painted as one.
static func _first_joined(b: MapData.Block, map: MapData, cfg: PropDressConfig) -> MapData.Block:
	var group: Array[MapData.Block] = [b]
	var i := 0
	while i < group.size():
		var g := group[i]
		var glo := g.center - g.size * 0.5 - Vector3.ONE * cfg.unit_reach
		var ghi := g.center + g.size * 0.5 + Vector3.ONE * cfg.unit_reach
		for o in map.blocks:
			if o.kind != b.kind or group.has(o):
				continue
			var olo := o.center - o.size * 0.5
			var ohi := o.center + o.size * 0.5
			if olo.x <= ghi.x and ohi.x >= glo.x and olo.y <= ghi.y and ohi.y >= glo.y and olo.z <= ghi.z \
					and ohi.z >= glo.z:
				group.append(o)
		i += 1
	var first := b
	for g in group:
		if map.blocks.find(g) < map.blocks.find(first):
			first = g
	return first


## Block `b` (a wall) lined with `model` in cells on the world's grid (bay_cells), each stretched to its cell and
## facing the field's `middle`, a feature bay (PropDressConfig.bay_features, taken in turn from `laid`, the count laid
## on the walls before this one) in some whole cells with their fronts clear (bay_open), never two side by side. Returns
## the features laid so far.
static func _bays(out: Dictionary[StringName, Placed], model: StringName, boxes: Dictionary[StringName, AABB],
		b: MapData.Block, map: MapData, cfg: PropDressConfig, middle: Vector3, laid: int) -> int:
	var along_x := b.size.x >= b.size.z
	var across := b.size.z if along_x else b.size.x
	var to := middle - b.center
	var yaw: float
	if along_x:
		yaw = 0.0 if to.z >= 0.0 else PI
	else:
		yaw = PI * 0.5 if to.x >= 0.0 else -PI * 0.5
	var features: PackedStringArray = cfg.bay_features.get(model, PackedStringArray())
	var pitch: float = cfg.bay_pitch.get(model, maxf(b.size.x, b.size.z))
	var on_wall := 0
	var last := -2
	var edges := bay_cells(b, pitch, cfg.bay_anchor.get(model, Vector2.ZERO))
	for i in edges.size() - 1:
		var length := edges[i + 1] - edges[i]
		var mid := (edges[i] + edges[i + 1]) * 0.5
		var at := Vector3(mid, b.center.y - b.size.y * 0.5, b.center.z) if along_x \
				else Vector3(b.center.x, b.center.y - b.size.y * 0.5, mid)
		var use := model
		if not features.is_empty() and on_wall < cfg.bay_feature_most and i > last + 1 \
				and absf(length - pitch) < 0.01 and bay_open(map, b, cfg, edges[i], edges[i + 1], yaw):
			var feature := StringName(features[laid % features.size()])
			if boxes.has(feature):
				use = feature
				laid += 1
				on_wall += 1
				last = i
		_placed(out, use).add(fit(boxes[use], at, Vector3(length, b.size.y, across), yaw), 1.0)
	return laid


## Wall block `b`'s cell edges along its long side for bays `pitch` m apart on the world's grid: its two ends and
## every grid line (anchor.x plus whole pitches along x for a wall long in x, anchor.y along z for one long in z)
## at least half a pitch inside them.
static func bay_cells(b: MapData.Block, pitch: float, anchor: Vector2) -> PackedFloat32Array:
	var along_x := b.size.x >= b.size.z
	var lo := (b.center.x - b.size.x * 0.5) if along_x else (b.center.z - b.size.z * 0.5)
	var hi := (b.center.x + b.size.x * 0.5) if along_x else (b.center.z + b.size.z * 0.5)
	var origin := anchor.x if along_x else anchor.y
	var edges := PackedFloat32Array([lo])
	var line := origin + ceilf((lo + pitch * 0.5 - origin) / pitch) * pitch
	while line <= hi - pitch * 0.5 + 1e-4:
		edges.append(line)
		line += pitch
	edges.append(hi)
	return edges


## Whether the face of wall `b` turned to `yaw` has no other block within PropDressConfig.bay_clear m of it between
## `from` and `to` along it, below bay_clear_height (the floor aside): room for a door or a shutter.
static func bay_open(map: MapData, b: MapData.Block, cfg: PropDressConfig, from: float, to: float, yaw: float) -> bool:
	var front := Basis(Vector3.UP, yaw) * Vector3.BACK
	var along_x := b.size.x >= b.size.z
	var face := b.center + Vector3(front.x * b.size.x, 0.0, front.z * b.size.z) * 0.5
	var lo := Vector3(from, 0.1, minf(face.z, face.z + front.z * cfg.bay_clear)) if along_x \
			else Vector3(minf(face.x, face.x + front.x * cfg.bay_clear), 0.1, from)
	var hi := Vector3(to, cfg.bay_clear_height, maxf(face.z, face.z + front.z * cfg.bay_clear)) if along_x \
			else Vector3(maxf(face.x, face.x + front.x * cfg.bay_clear), cfg.bay_clear_height, to)
	var strip := AABB(lo, hi - lo)
	for other in map.blocks:
		if other == b:
			continue
		if AABB(other.center - other.size * 0.5, other.size).intersects(strip):
			return false
	return true


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
static func _tile(turns: Turns, names: Array[StringName], b: MapData.Block, foot: Vector3, cfg: PropDressConfig,
		map: MapData) -> void:
	var line := lining(map, cfg, b)
	var model := turns.boxes[names[0]]
	var row := Row.new(turns, names)
	var k := b.size.y / maxf(model.size.y, 1e-6)
	var wide := maxf(model.size.x, model.size.z) * k
	var model_long_x := model.size.x >= model.size.z
	var h := b.size * 0.5
	var z_mid := (line.low.z - line.high.z) * 0.5
	var z_length := b.size.z - line.low.z - line.high.z
	for side: float in [-1.0, 1.0]:
		var d := line.low if side < 0.0 else line.high
		if d.z > 0.0:
			_tile_row(row, foot + Vector3(0.0, 0.0, side * (h.z - d.z * 0.5)), b.size.x, d.z, b.size.y,
					true, side, wide, model_long_x)
		if d.x > 0.0:
			_tile_row(row, foot + Vector3(side * (h.x - d.x * 0.5), 0.0, z_mid), z_length, d.x, b.size.y,
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
static func _tile_row(row: Row, at: Vector3, length: float, depth: float, height: float,
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
		var foot := at + (Vector3(step, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, step))
		# in line with its neighbours by its front face: rows of different depths on abutting blocks still meet
		var bay := row.turns.next(row.names, foot + Vector3(sin(yaw), 0.0, cos(yaw)) * depth * 0.5, yaw, cell)
		_placed(row.turns.out, bay).add(fit(row.turns.boxes[bay], foot, size, yaw), 1.0)


## Block `b`'s prop `model` stood on the ground at its middle (GROUND, WG2): the model's y = 0 on the terrain there (the
## box's bottom on a map with none), its top the box's top, its long side (x) along the box's, stretched to the box's
## length and width, a half turn either way at random; its buried part (under y = 0) kept inside the box by raising
## its ground line if it must. Under it, where the ground in the box falls further than PropDressConfig.bank_from below
## that line, the earth bank fills the box from its bottom to just over the line, so the box is never empty air.
static func _ground(out: Dictionary[StringName, Placed], model: StringName, boxes: Dictionary[StringName, AABB],
		b: MapData.Block, map: MapData, cfg: PropDressConfig, rng: RandomNumberGenerator) -> void:
	var box := boxes[model]
	var bottom := b.center.y - b.size.y * 0.5
	var top := b.center.y + b.size.y * 0.5
	var line := clampf(ground_at(map, b.center.x, b.center.z, bottom), bottom, top - cfg.ground_least)
	var tall := maxf(box.end.y, 1e-6)
	var under := minf(box.position.y, 0.0) / tall  # the buried share of the model's height, negative
	# the lowest the ground line may sit and keep the buried part in the box: line + under * (top - line) >= bottom
	line = maxf(line, (bottom - under * top) / (1.0 - under))
	var along_x := b.size.x >= b.size.z
	var long := b.size.x if along_x else b.size.z
	var across := b.size.z if along_x else b.size.x
	var yaw := (0.0 if along_x else PI * 0.5) + PI * float(rng.randi_range(0, 1))
	var scale := Vector3(long / maxf(box.size.x, 1e-6), (top - line) / tall, across / maxf(box.size.z, 1e-6))
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(scale)
	var pivot := Vector3(box.position.x + box.size.x * 0.5, 0.0, box.position.z + box.size.z * 0.5)
	_placed(out, model).add(Transform3D(basis, Vector3(b.center.x, line, b.center.z) - basis * pivot), _shade(cfg, rng))
	if not boxes.has(cfg.ground_bank) or line - lowest_ground(map, b, bottom) <= cfg.bank_from:
		return
	var bank_top := minf(line + cfg.bank_tuck, top)
	var size := Vector3(long * cfg.bank_length, bank_top - bottom, across * cfg.bank_share)
	_placed(out, cfg.ground_bank).add(fit(boxes[cfg.ground_bank], Vector3(b.center.x, bottom, b.center.z),
			size, 0.0 if along_x else PI * 0.5), 1.0)


## The terrain's height at (x, z), or `fallback` off it or on a map with none.
static func ground_at(map: MapData, x: float, z: float, fallback: float) -> float:
	if map.terrain == null:
		return fallback
	var h := map.terrain.height_at(x, z)
	return fallback if is_nan(h) else h


## The lowest ground under block `b`'s footprint (its corners, the middles of its sides and its middle), no lower than
## `bottom`.
static func lowest_ground(map: MapData, b: MapData.Block, bottom: float) -> float:
	var low := INF
	for i in 3:
		for j in 3:
			var x := b.center.x + (i - 1) * b.size.x * 0.5
			var z := b.center.z + (j - 1) * b.size.z * 0.5
			low = minf(low, ground_at(map, x, z, INF))
	return bottom if is_inf(low) else maxf(low, bottom)


## A round prop's turn: a random quarter, so the model's own bounds (and so the box) still hold it.
static func _quarter_turn(rng: RandomNumberGenerator) -> float:
	return rng.randi_range(0, 3) * PI * 0.5


static func _shade(cfg: PropDressConfig, rng: RandomNumberGenerator) -> float:
	return 1.0 + rng.randf_range(-cfg.shade_jitter, cfg.shade_jitter)


## One TILE block's lining: the shared turns and the models it takes turns with.
class Row:
	var turns: Turns
	var names: Array[StringName]

	func _init(shared: Turns, models: Array[StringName]) -> void:
		turns = shared
		names = []
		for n in models:
			if shared.boxes.has(n):
				names.append(n)


## Where every TILE lining's bays went, so each place takes a random one of its models that neither neighbour in line
## (facing the same way, a bay to either side, whichever block laid it) already is: a rack wall never shows one bay
## twice side by side. Seeded by the map, so a layout is the same each time.
class Turns:
	var out: Dictionary[StringName, Placed]
	var boxes: Dictionary[StringName, AABB]
	var rng := RandomNumberGenerator.new()
	var feet: PackedVector3Array = []
	var yaws: PackedFloat32Array = []
	var laid: Array[StringName] = []

	func _init(placed: Dictionary[StringName, Placed], bounds: Dictionary[StringName, AABB], seed_from: int) -> void:
		out = placed
		boxes = bounds
		rng.seed = hash([seed_from, "bays"])

	## A bay for the place whose front face's middle is `face`, `width` wide, turned `yaw`.
	func next(names: Array[StringName], face: Vector3, yaw: float, width: float) -> StringName:
		var free := names.duplicate()
		var along := Vector3(cos(yaw), 0.0, -sin(yaw))
		for i in feet.size():
			var gap := feet[i] - face
			if absf(angle_difference(yaws[i], yaw)) < 0.01 and absf(gap.y) < 0.01 \
					and absf(gap.dot(along)) < width * 1.6 and gap.length_squared() - gap.dot(along) ** 2 < 0.01:
				free.erase(laid[i])
		if free.is_empty():
			free = names.duplicate()
		var pick: StringName = free[rng.randi_range(0, free.size() - 1)]
		feet.append(face)
		yaws.append(yaw)
		laid.append(pick)
		return pick

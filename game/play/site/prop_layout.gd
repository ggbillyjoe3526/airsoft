class_name PropLayout
extends RefCounted
## Where a site's CC0 props stand (DR2): for every block of a kind PropDressConfig dresses, each model's transform
## inside the block's box, laid as the kind says (a row, a cluster on a pallet, or one model fitted to the box). Pure
## and seeded (the map's dressing seed); no node. A prop never reaches past its block's box, so what you see is what
## stops a BB and a body.

## How far (m) past a face TILE looks for a block that hides it.
const FACE_SLAB := 0.04
## The trees' own seeded stream (their turns and shades, WT1), apart from the other props' so theirs stay as they were.
const TREE_SALT := 0x7EE5


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
	var trees := RandomNumberGenerator.new()
	trees.seed = map.dressing_seed ^ TREE_SALT
	var middle := field_middle(map)
	var features_laid := 0
	var turns := Turns.new(out, boxes, map.dressing_seed)
	var sets_laid: Dictionary[StringName, bool] = {}
	for b in map.blocks:
		if not cfg.dresses(b):
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
				_grid(_placed(out, model), boxes[model], foot, b.size, cfg.grid_cells.get(model, b.size), cfg, rng, model)
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
			PropDressConfig.Lay.STAKES:
				_stakes(out, model, boxes, b, foot, cfg, middle, rng)
			PropDressConfig.Lay.SET:
				if not sets_laid.has(model):
					sets_laid[model] = true
					var box := PropDressConfig.set_box(map, model)
					_placed(out, model).add(fit(boxes[model], box.get_center() - Vector3(0.0, box.size.y * 0.5, 0.0),
							box.size, 0.0), 1.0)
			PropDressConfig.Lay.TREE:
				if cfg.tree_feet.has(model):
					var crown: StringName = cfg.tree_crowns.get(model, &"")
					var has_crown := boxes.has(crown)
					var top := maxf(boxes[model].end.y, boxes[crown].end.y if has_crown else 0.0)
					var shade := _shade(cfg, trees)
					var t := tree_fit(boxes[model], b, ground_under(map, b), cfg.tree_feet[model], _quarter_turn(trees),
							top)
					_placed(out, model).add(t, shade)
					if has_crown:
						_placed(out, crown).add(crown_fit(t), shade)
			PropDressConfig.Lay.SIDE:
				_placed(out, model).add(joint_bend(b, map, true) * _side(boxes[model], b, map, cfg, middle), 1.0)
			PropDressConfig.Lay.LINED:
				_lined(out, model, boxes, b, foot, cfg, joint_bend(b, map, false), map)
			_:
				var t := _fit_facing(boxes[model], b, foot, middle)
				if cfg.grounded.has(model):
					t = grounded(t, boxes[model], b, map)
				_placed(out, model).add(t, 1.0)
	return out


## The transform that stretches a model of bounds `model` to `size` (in the model's own axes, before its turn),
## turned `yaw` about up, the middle of its foot at `foot`.
static func fit(model: AABB, foot: Vector3, size: Vector3, yaw: float) -> Transform3D:
	var scale := Vector3(size.x / maxf(model.size.x, 1e-6), size.y / maxf(model.size.y, 1e-6),
			size.z / maxf(model.size.z, 1e-6))
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(scale)
	var base := model.position + Vector3(model.size.x * 0.5, 0.0, model.size.z * 0.5)
	return Transform3D(basis, foot - basis * base)


## The transform that stands a tree of bounds `model` in block `b` (PropDressConfig.Lay.TREE): its origin on the
## ground `ground` under the box's middle (raised as little as keeps its sunk foot inside the box), its trunk's foot
## (`foot` m round its origin) stretched to the box's half-width (the box's shorter side, a tree's box being square)
## and the tree's top (`height` m in the model, its crown's included; the model's own top without it) to the box's
## top, turned `yaw` about up
## (a quarter turn: the trunk's foot reaches its radius along its axes, so the box and its round steps still hold it).
static func tree_fit(model: AABB, b: MapData.Block, ground: float, foot: float, yaw: float, height: float = -1.0) \
		-> Transform3D:
	var tall := maxf(height if height > 0.0 else model.end.y, 1e-6)
	var top := b.center.y + b.size.y * 0.5
	var across := minf(b.size.x, b.size.z) * 0.5 / maxf(foot, 1e-6)
	var up := (top - ground) / tall
	# the trunk's cut end, under the ground, stays inside the box: on a steep foot the tree stands a little higher
	var stand := maxf(ground, b.center.y - b.size.y * 0.5 - model.position.y * up)
	up = (top - stand) / tall
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(across, up, across))
	return Transform3D(basis, Vector3(b.center.x, stand, b.center.z))


## A tree's crown over its trunk stood by `trunk` (tree_fit): the same origin and turn, scaled evenly by the trunk's
## height scale, so the crown keeps its modelled shape whatever its box's width.
static func crown_fit(trunk: Transform3D) -> Transform3D:
	var up := trunk.basis.y.length()
	var turn := trunk.basis.orthonormalized()
	return Transform3D(turn * Basis.from_scale(Vector3.ONE * up), trunk.origin)


## The ground under block `b`'s middle: sloping ground's, kept inside the box, or its foot without it.
static func ground_under(map: MapData, b: MapData.Block) -> float:
	var foot := b.center.y - b.size.y * 0.5
	if map.terrain == null:
		return foot
	var h := map.terrain.height_at(b.center.x, b.center.z)
	return foot if is_nan(h) else clampf(h, foot, b.center.y + b.size.y * 0.5)


## The middle of the field on the ground: halfway between the teams' spawns.
static func field_middle(map: MapData) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for end in map.ends:
		for s in end.spawns:
			sum += s.position
			n += 1
	return Vector3(sum.x, 0.0, sum.z) / maxf(n, 1.0)


## A palisade (STAKES, WG3): stakes side by side along the box's long side, whole ones stretched to fill it at about
## PropDressConfig.stake_pitch each, as thick as the box less the rails, each a little under the box's top and turned
## a quarter at random; the rails along the face towards the field's middle, two high, the box's length each.
static func _stakes(out: Dictionary[StringName, Placed], model: StringName, boxes: Dictionary[StringName, AABB],
		b: MapData.Block, foot: Vector3, cfg: PropDressConfig, middle: Vector3, rng: RandomNumberGenerator) -> void:
	var along_x := b.size.x >= b.size.z
	var long := b.size.x if along_x else b.size.z
	var depth := b.size.z if along_x else b.size.x
	var front := signf((middle - b.center).z if along_x else (middle - b.center).x)
	if front == 0.0:
		front = 1.0
	var rail: StringName = cfg.stake_rails.get(model, &"")
	var rail_depth := 0.0
	if rail != &"" and boxes.has(rail):
		rail_depth = minf(boxes[rail].size.z, depth * 0.4)
	var n := maxi(1, roundi(long / maxf(cfg.stake_pitch.get(model, long), 1e-6)))
	var cell := long / n
	# Each stake overlaps the next a little (stake_thick), the end ones kept inside the block. A block too thin for a
	# round stake takes flattened ones, its long way along the block, so nothing is seen between them still.
	# Each stake's share of the length varies by up to stake_vary either way, so the logs are of mixed sizes.
	var cells := PackedFloat32Array()
	cells.resize(n)
	var sum := 0.0
	for i in n:
		cells[i] = 1.0 + rng.randf_range(-cfg.stake_vary, cfg.stake_vary)
		sum += cells[i]
	var turn := 0.0 if along_x else PI * 0.5
	var room := depth - rail_depth
	var p := _placed(out, model)
	var start := -long * 0.5
	for i in n:
		var share := long * cells[i] / sum
		var wide := minf(share * cfg.stake_thick, long)
		var thick := minf(wide, room)
		var flat := thick < wide - 1e-4
		var step := clampf(start + share * 0.5, (wide - long) * 0.5, (long - wide) * 0.5)
		start += share
		var back := (depth * 0.5 - rail_depth - thick * 0.5) * front
		var at := foot + (Vector3(step, 0.0, back) if along_x else Vector3(back, 0.0, step))
		var tall := b.size.y - rng.randf_range(0.0, minf(cfg.stake_drop, b.size.y * 0.1))
		var yaw := turn + rng.randi_range(0, 1) * PI if flat else rng.randi_range(0, 3) * PI * 0.5
		p.add(fit(boxes[model], at, Vector3(wide, tall, thick) if flat else Vector3(thick, tall, thick), yaw),
				_shade(cfg, rng))
	if rail_depth <= 0.0:
		return
	var r := _placed(out, rail)
	var face := (depth * 0.5 - rail_depth * 0.5) * front
	var rail_h := boxes[rail].size.y
	for lift: float in [cfg.stake_rail_heights.x, b.size.y - cfg.stake_rail_heights.y - rail_h]:
		if lift < 0.0 or lift + rail_h > b.size.y:
			continue
		var at := foot + (Vector3(0.0, lift, face) if along_x else Vector3(face, lift, 0.0))
		r.add(fit(boxes[rail], at, Vector3(long, rail_h, rail_depth), turn), _shade(cfg, rng))


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
## one model repeated; never turned for a model (`model_name`) in PropDressConfig.grid_unturned.
static func _grid(p: Placed, model: AABB, foot: Vector3, size: Vector3, cell: Vector3, cfg: PropDressConfig,
		rng: RandomNumberGenerator, model_name: StringName = &"") -> void:
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
				p.add(fit(model, at + Vector3(0.0, j * step.y, 0.0), _turned(step, turn - yaw), turn),
						_shade(cfg, rng))


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


## FIT's transform `t` of a model of bounds `model` in block `b`, stood on the ground under the box's middle instead
## (PropDressConfig.grounded): the model's y = 0 on the ground, its top the box's; `t` itself where the ground isn't
## known, lies outside the box's height, or the model's skirt (under its y = 0) would reach under the box's foot.
static func grounded(t: Transform3D, model: AABB, b: MapData.Block, map: MapData) -> Transform3D:
	if map.terrain == null or model.end.y <= 0.0:
		return t
	var foot := b.center.y - b.size.y * 0.5
	var top := b.center.y + b.size.y * 0.5
	var ground := map.terrain.height_at(b.center.x, b.center.z)
	if is_nan(ground) or ground <= foot or ground >= top:
		return t
	var sy := (top - ground) / model.end.y
	if ground + model.position.y * sy < foot - 1e-4:
		return t
	var out := t
	out.basis.y = Vector3(0.0, sy, 0.0)
	out.origin.y = ground
	return out


## SIDE: a tunnel wall's model on block `b`, its long side (the model's z) along the box's, its inner face (the
## model's -x) toward the wall across the tunnel (with none found, toward the field's middle); stretched across and
## along, but at its own height with its top at the box's top (the ceiling), so every section's profile is the same and
## neighbours meet flush (its foot is under the floor, in the ground).
static func _side(model: AABB, b: MapData.Block, map: MapData, cfg: PropDressConfig, middle: Vector3) -> Transform3D:
	var along_x := b.size.x >= b.size.z
	var inward := _toward_pair(b, map, cfg, along_x)
	if inward == 0.0:
		var to := middle - b.center
		inward = 1.0 if (to.z if along_x else to.x) >= 0.0 else -1.0
	# a quarter turn takes the model's -x to world +z; a half turn to world +x
	var yaw: float
	if along_x:
		yaw = PI * 0.5 if inward > 0.0 else -PI * 0.5
	else:
		yaw = PI if inward > 0.0 else 0.0
	var size := Vector3(minf(b.size.x, b.size.z), model.size.y, maxf(b.size.x, b.size.z))
	return fit(model, Vector3(b.center.x, b.center.y + b.size.y * 0.5 - model.size.y, b.center.z), size, yaw)


## The shear that bends a tunnel section's model (SIDE and LINED lays) to meet its neighbours halfway at each joint: a
## tunnel's 1 m sections step with its floor (and its roofs' tops with the mound), so each one's level (its block's top
## with `top`, else its bottom: a wall's top and a roof's foot are the ceiling, a roof's top its cap's) is tilted along
## the tunnel from the middle of the step behind it to the middle of the step ahead (its own level at a mouth).
## Neighbours are blocks named alike, end to end with it along x or z; none leaves it unbent.
static func joint_bend(b: MapData.Block, map: MapData, top: bool) -> Transform3D:
	var level := _ceiling(b, top)
	for axis: int in [0, 2]:
		var other := 2 - axis
		var back := level
		var ahead := level
		var found := false
		for c in map.blocks:
			if c == b or c.dress != b.dress:
				continue
			var d := c.center - b.center
			if absf(d[other]) > 1e-3 or absf(absf(d[axis]) - (b.size[axis] + c.size[axis]) * 0.5) > 1e-3:
				continue
			found = true
			if d[axis] < 0.0:
				back = (level + _ceiling(c, top)) * 0.5
			else:
				ahead = (level + _ceiling(c, top)) * 0.5
		if found:
			var k := (ahead - back) / b.size[axis]
			var basis := Basis.IDENTITY
			if axis == 0:
				basis.x = Vector3(1.0, k, 0.0)
			else:
				basis.z = Vector3(0.0, k, 1.0)
			return Transform3D(basis, Vector3(0.0, (back + ahead) * 0.5 - level - k * b.center[axis], 0.0))
	return Transform3D.IDENTITY


static func _ceiling(b: MapData.Block, top: bool) -> float:
	return b.center.y + b.size.y * (0.5 if top else -0.5)


## Which way across block `b` (+1 or -1 along world z for a box long in x, else along world x) the nearest block named
## alike lies, a side wall's partner across the tunnel: within PropDressConfig.side_reach m and level with it along
## the box (their middles under half its length apart); 0 for none.
static func _toward_pair(b: MapData.Block, map: MapData, cfg: PropDressConfig, along_x: bool) -> float:
	var half := maxf(b.size.x, b.size.z) * 0.5
	var best := INF
	var side := 0.0
	for c in map.blocks:
		if c == b or c.dress != b.dress:
			continue
		var d := c.center - b.center
		var along := d.x if along_x else d.z
		var across := d.z if along_x else d.x
		if absf(along) < half and absf(across) > 1e-3 and absf(across) <= cfg.side_reach and absf(across) < best:
			best = absf(across)
			side = signf(across)
	return side


## LINED: the model on block `b`'s foot at its own height (or the box's, if lower) and width, its long side along the
## box's, stretched along, bent by `bend` (joint_bend by the box's foot). At the end of a run of sections, the mouth
## model (PropDressConfig.lined_mouths) instead, its -z end to the open side. Elsewhere, where more than lined_min_cap m
## of the box is left over it, its cap (lined_caps) stretched over the rest of the box from lined_cap_from m over its
## foot, bent by the boxes' tops, so a tunnel's caps run on as one slope.
static func _lined(out: Dictionary[StringName, Placed], model: StringName, boxes: Dictionary[StringName, AABB],
		b: MapData.Block, foot: Vector3, cfg: PropDressConfig, bend: Transform3D, map: MapData) -> void:
	var mouth: StringName = cfg.lined_mouths.get(model, &"")
	var open := _open_end(b, map)
	if mouth != &"" and boxes.has(mouth) and open != Vector3.ZERO:
		var m := boxes[mouth]
		var along := b.size.z if absf(open.z) > 0.0 else b.size.x
		# a quarter turn takes the model's -z to world -x, a half turn to +z
		var yaw := 0.0
		if open.z > 0.0:
			yaw = PI
		elif open.x < 0.0:
			yaw = PI * 0.5
		elif open.x > 0.0:
			yaw = -PI * 0.5
		_placed(out, mouth).add(bend * fit(m, foot, Vector3(m.size.x, minf(m.size.y, b.size.y), along), yaw), 1.0)
		return
	var own := boxes[model]
	var height := minf(own.size.y, b.size.y)
	_placed(out, model).add(bend * _fit_long(own, b, foot, height, false), 1.0)
	var cap: StringName = cfg.lined_caps.get(model, &"")
	if cap == &"" or not boxes.has(cap) or b.size.y - height <= cfg.lined_min_cap:
		return
	var from := minf(cfg.lined_cap_from, height)
	_placed(out, cap).add(joint_bend(b, map, true) * _fit_long(boxes[cap], b, foot + Vector3(0.0, from, 0.0),
			b.size.y - from), 1.0)


## The open end of block `b` at the end of a run of blocks named alike (end to end with it along x or z, as joint_bend
## finds them): the world direction (a unit along x or z) with no neighbour, ZERO for a block with a neighbour at both
## ends or none.
static func _open_end(b: MapData.Block, map: MapData) -> Vector3:
	for axis: int in [0, 2]:
		var other := 2 - axis
		var back := false
		var ahead := false
		for c in map.blocks:
			if c == b or c.dress != b.dress:
				continue
			var d := c.center - b.center
			if absf(d[other]) > 1e-3 or absf(absf(d[axis]) - (b.size[axis] + c.size[axis]) * 0.5) > 1e-3:
				continue
			if d[axis] < 0.0:
				back = true
			else:
				ahead = true
		if back != ahead:
			var dir := Vector3.ZERO
			dir[axis] = -1.0 if ahead else 1.0
			return dir
	return Vector3.ZERO


## One model stretched over block `b`'s footprint, `height` m high from `foot`, its long side along the box's (at the
## model's own length with `stretch_long` off: a tunnel's shell, whose earth reaches past the box's sides).
static func _fit_long(model: AABB, b: MapData.Block, foot: Vector3, height: float,
		stretch_long: bool = true) -> Transform3D:
	var long := maxf(b.size.x, b.size.z) if stretch_long else maxf(model.size.x, model.size.z)
	var short := minf(b.size.x, b.size.z)
	var model_long_x := model.size.x >= model.size.z
	var size := Vector3(long, height, short) if model_long_x else Vector3(short, height, long)
	var yaw := 0.0 if (b.size.x >= b.size.z) == model_long_x else PI * 0.5
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

class_name RoundSteps
extends RefCounted
## The stepped boxes a round prop's block stands as for BBs and bodies (BP7): a tree's trunk, Depot's drums and
## barrels (MapStyle.round_steps), each prop where PropLayout lays it, so a BB grazing past a trunk or a drum flies on
## where the square block's corner stopped it. MapLevel makes them its colliders; the block itself (its box) is still
## what the nav grid, the bots' cover, the noisy props, the bake and the minimap take. Where the props stand is
## PropDressConfig's (the one source PropLayout lays them by): its model, lay, cluster cell and pallet. Pure: no node,
## and no model is loaded.


## Block `b`'s stepped boxes into `out` (cleared first); none when its model is not round, it is laid other than FIT,
## ROW, CLUSTER or TREE, or it is a ramp. `props` is how the props are laid (the site look's); `middle` is the field's
## middle (PropLayout.field_middle), which a fitted prop's front faces.
static func boxes(b: MapData.Block, style: MapStyle, props: PropDressConfig, middle: Vector3,
		out: Array[AABB]) -> void:
	out.clear()
	if b.rise != MapData.Rise.NONE:
		return
	var model := props.model_of(b)
	if not style.round_steps.has(model) or not props.models.has(model):
		return
	var steps: PackedVector2Array = style.round_steps[model]
	var low := b.center - b.size * 0.5
	var foot := 0.0
	var cell := minf(b.size.x, b.size.z)
	match props.lay_of(b):
		PropDressConfig.Lay.FIT:
			_fitted(b, steps, middle, out)
			return
		PropDressConfig.Lay.CLUSTER:
			cell = props.cluster_cell
			if props.models.has(props.pallet) and props.pallet_height < b.size.y:
				foot = props.pallet_height
				out.append(AABB(low, Vector3(b.size.x, foot, b.size.z)))
		PropDressConfig.Lay.ROW, PropDressConfig.Lay.TREE:
			pass # a tree is one round trunk filling its square box: a row of one
		_:
			return
	# As PropLayout's CLUSTER and ROW lay them: a grid of cells, a prop as wide as its cell's shorter side in each.
	var nx := maxi(1, roundi(b.size.x / cell))
	var nz := maxi(1, roundi(b.size.z / cell))
	var cx := b.size.x / nx
	var cz := b.size.z / nz
	var half := minf(cx, cz) * 0.5
	var y0 := low.y + foot
	var height := b.size.y - foot
	if height <= 0.0:
		return
	for i in nx:
		for j in nz:
			var at := Vector2(low.x + (i + 0.5) * cx, low.z + (j + 0.5) * cz)
			for k in range(0, steps.size() - 1, 2):
				var lo := at + steps[k] * half
				var hi := at + steps[k + 1] * half
				out.append(AABB(Vector3(lo.x, y0, lo.y), Vector3(hi.x - lo.x, height, hi.y - lo.y)))


## One prop fitted to the whole block (PropLayout's FIT): its u along the block's long side, its front (+v) across it
## towards `middle`, as _fit_facing turns it (half a turn when the middle is behind; on a block long in z a quarter
## turn, so u runs to -z).
static func _fitted(b: MapData.Block, steps: PackedVector2Array, middle: Vector3, out: Array[AABB]) -> void:
	var long_x := b.size.x >= b.size.z
	var half := b.size * 0.5
	var side := 1.0
	if long_x:
		side = 1.0 if middle.z - b.center.z >= 0.0 else -1.0
	else:
		side = 1.0 if middle.x - b.center.x >= 0.0 else -1.0
	for k in range(0, steps.size() - 1, 2):
		var a := _placed(steps[k], long_x, side, half)
		var c := _placed(steps[k + 1], long_x, side, half)
		var lo := Vector3(minf(a.x, c.x), -half.y, minf(a.y, c.y))
		var hi := Vector3(maxf(a.x, c.x), half.y, maxf(a.y, c.y))
		out.append(AABB(b.center + lo, hi - lo))


## A point of the prop's frame (u, v) as (x, z) off the block's centre.
static func _placed(p: Vector2, long_x: bool, side: float, half: Vector3) -> Vector2:
	if long_x:
		return Vector2(side * p.x * half.x, side * p.y * half.z)
	return Vector2(side * p.y * half.x, -side * p.x * half.z)

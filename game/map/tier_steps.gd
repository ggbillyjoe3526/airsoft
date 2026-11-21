class_name TierSteps
extends RefCounted
## The tiers a tapering GRID prop's block stands as for BBs, sight and bodies (TV1, MapStyle.tier_steps): Woodland's
## thickets, rows of spruces that narrow as they rise, met as boxes stacked up the block that draw in, tier by tier, to
## where the drawn spruces' boughs reach, so a BB or a sight line past a body seen beside a thicket flies on where the
## square box stopped it (the owner's playtest of 0.1 Beta 2, item 3). A side another tiered block touches keeps the
## box's face up its whole height, so touching rows leave no slot between them. MapLevel makes them its colliders, as
## RoundSteps' boxes; the block itself (its box) is still what the nav grid, the bots' cover, the noisy props, the bake
## and the minimap take. How each prop is drawn is PropLayout's (PropLayout.grid_drawn). Pure: no node, and no model
## is loaded.

## Each tier's three boxes' reach as shares of its own (along, across): MapStyle.ROUND_TRUNK's, a round prop's
## square cut at its corners.
const CORNERS: Array[Vector2] = [Vector2(1.0, 0.55), Vector2(0.55, 1.0), Vector2(0.883, 0.883)]
## A side counts as touched by another tiered block within this many metres of it (MapLevel.CORE_TOUCH's rule).
const TOUCH := 0.05


## Whether `b` stands as tiers: a GRID block, no ramp, its model one MapStyle.tier_steps lists and `props` lays.
static func tiered(b: MapData.Block, style: MapStyle, props: PropDressConfig) -> bool:
	if b.rise != MapData.Rise.NONE or props.lay_of(b) != PropDressConfig.Lay.GRID:
		return false
	var model := props.model_of(b)
	return style.tier_steps.has(model) and props.models.has(model)


## The blocks of `m` that stand as tiers (tiered), for boxes' touch test.
static func tiered_blocks(m: MapData, style: MapStyle, props: PropDressConfig) -> Array[MapData.Block]:
	var out: Array[MapData.Block] = []
	for b in m.blocks:
		if tiered(b, style, props):
			out.append(b)
	return out


## Block `b`'s tiers into `out` (cleared first): none when it isn't tiered or another of `others` (the tiered blocks:
## tiered_blocks) covers every side, where its box is what stops. Each tier spans its share of the box's height and
## reaches, round the props PropLayout stands in the box (PropLayout.grid_spots), its share of a prop's drawn
## half-width past the outermost of them; on a side another of `others` covers it runs out to the box's face, and
## where one touches only part of a side a filler runs the box's face out over that part, all the way up.
static func boxes(b: MapData.Block, style: MapStyle, props: PropDressConfig, others: Array[MapData.Block],
		out: Array[AABB]) -> void:
	out.clear()
	if not tiered(b, style, props):
		return
	var lo := b.center - b.size * 0.5
	var hi := b.center + b.size * 0.5
	# each side's touched stretches along it (x for a z side, z for an x side): -x, +x, -z, +z
	var touches: Array[PackedVector2Array] = []
	var whole: Array[bool] = []
	for axis: int in [0, 2]:
		for side: float in [-1.0, 1.0]:
			var spans := _touches(b, axis, side, others)
			touches.append(spans)
			var along := 2 - axis
			whole.append(_covers(spans, lo[along], hi[along]))
	if not whole.has(false):
		return
	var model := props.model_of(b)
	var cell: Vector3 = props.grid_cells.get(model, b.size)
	var spread: Vector2 = props.grid_spread.get(model, Vector2.ONE)
	var half := PropLayout.grid_drawn(b.size, cell, spread) * 0.5
	var spots := PropLayout.grid_spots(b.center - Vector3(0.0, b.size.y * 0.5, 0.0), b.size, cell, spread,
			props.grid_scatter.get(model, 0.0))
	var u := Vector2(INF, -INF)
	var v := Vector2(INF, -INF)
	for s in spots:
		u = Vector2(minf(u.x, s.x), maxf(u.y, s.x))
		v = Vector2(minf(v.x, s.y), maxf(v.y, s.y))
	var tiers: PackedVector2Array = style.tier_steps[model]
	# the innermost faces of the tiers, where a filler reaches in to
	var inner_lo := Vector3(lo)
	var inner_hi := Vector3(hi)
	for k in tiers.size():
		var from := clampf(tiers[k].x, 0.0, 1.0)
		var to := clampf(tiers[k + 1].x, 0.0, 1.0) if k + 1 < tiers.size() else 1.0
		if to <= from:
			continue
		var reach := clampf(tiers[k].y, 0.0, 1.0)
		# three boxes a tier, as RoundSteps' round props: the props' round ends cut at the square's corners
		for corner in CORNERS:
			var box := _tier_box(b, Vector4(u.x, u.y, v.x, v.y), half * reach * corner, from, to, whole)
			inner_lo = Vector3(maxf(inner_lo.x, box.position.x), 0.0, maxf(inner_lo.z, box.position.z))
			inner_hi = Vector3(minf(inner_hi.x, box.end.x), 0.0, minf(inner_hi.z, box.end.z))
			out.append(box)
	# fillers over the touched stretches of a side touched only in part, from its face in to the innermost tier
	for i in 4:
		if whole[i] or touches[i].is_empty():
			continue
		var axis := 0 if i < 2 else 2
		var along := 2 - axis
		for span in touches[i]:
			var f_lo := Vector3(lo)
			var f_hi := Vector3(hi)
			f_lo[along] = span.x
			f_hi[along] = span.y
			if i % 2 == 0:
				f_hi[axis] = inner_lo[axis]
			else:
				f_lo[axis] = inner_hi[axis]
			if f_hi[axis] > f_lo[axis] and f_hi[along] > f_lo[along]:
				out.append(AABB(f_lo, f_hi - f_lo))


## One box of block `b`'s tier from `from` to `to` (shares of its height): out `reach` m (along, across) past the
## props' outermost spots `spots` (along from x to y, across from z to w, off its foot), never past the box; on a side
## `whole` marks covered (-x, +x, -z, +z) out to the face.
static func _tier_box(b: MapData.Block, spots: Vector4, reach: Vector2, from: float, to: float,
		whole: Array[bool]) -> AABB:
	var lo := b.center - b.size * 0.5
	var hi := b.center + b.size * 0.5
	var long := maxf(b.size.x, b.size.z) * 0.5
	var across := minf(b.size.x, b.size.z) * 0.5
	var a := Vector2(maxf(spots.x - reach.x, -long), maxf(spots.z - reach.y, -across))
	var c := Vector2(minf(spots.y + reach.x, long), minf(spots.w + reach.y, across))
	var along_x := b.size.x >= b.size.z
	var t_lo := Vector3(b.center.x + (a.x if along_x else a.y), lo.y + b.size.y * from,
			b.center.z + (a.y if along_x else a.x))
	var t_hi := Vector3(b.center.x + (c.x if along_x else c.y), lo.y + b.size.y * to,
			b.center.z + (c.y if along_x else c.x))
	if whole[0]:
		t_lo.x = lo.x
	if whole[1]:
		t_hi.x = hi.x
	if whole[2]:
		t_lo.z = lo.z
	if whole[3]:
		t_hi.z = hi.z
	return AABB(t_lo, (t_hi - t_lo).max(Vector3.ZERO))


## The stretches (from, to) along block `b`'s side on `axis` (0 x, 2 z) towards `side` (+1 or -1) that another of
## `others` meets within TOUCH of it, each clipped to the side.
static func _touches(b: MapData.Block, axis: int, side: float, others: Array[MapData.Block]) -> PackedVector2Array:
	var out := PackedVector2Array()
	var slab := _slab(b, axis, side, TOUCH)
	var along := 2 - axis
	for o in others:
		var box := AABB(o.center - o.size * 0.5, o.size)
		if o != b and box.intersects(slab):
			out.append(Vector2(maxf(box.position[along], slab.position[along]),
					minf(box.end[along], slab.end[along])))
	return out


## Whether `spans` together cover from `from` to `to` (within TOUCH).
static func _covers(spans: PackedVector2Array, from: float, to: float) -> bool:
	var reached := from
	var moved := true
	while moved and reached < to - TOUCH:
		moved = false
		for s in spans:
			if s.x <= reached + TOUCH and s.y > reached:
				reached = s.y
				moved = true
	return reached >= to - TOUCH


## The thin box `reach` m deep just outside block `b`'s side on `axis` towards `side`.
static func _slab(b: MapData.Block, axis: int, side: float, reach: float) -> AABB:
	var lo := b.center - b.size * 0.5
	var size := b.size
	lo[axis] += b.size[axis] if side > 0.0 else -reach
	size[axis] = reach
	return AABB(lo, size)


## Whether another of `others` meets block `b`'s side on `axis` (0 x, 2 z) towards `side` (+1 or -1) anywhere along it,
## within `reach` m of it.
static func touched(b: MapData.Block, axis: int, side: float, others: Array[MapData.Block], reach: float) -> bool:
	var slab := _slab(b, axis, side, reach)
	for o in others:
		if o != b and AABB(o.center - o.size * 0.5, o.size).intersects(slab):
			return true
	return false

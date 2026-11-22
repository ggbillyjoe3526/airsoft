class_name TierSteps
extends RefCounted
## The tiers a tapering GRID prop's block stands as for BBs, sight and bodies (TV1, MapStyle.tier_steps): Woodland's
## thickets, rows of spruces that narrow as they rise, met as boxes stacked up the block that draw in, tier by tier, to
## where the drawn spruces' boughs reach, so a BB or a sight line past a body seen beside a thicket flies on where the
## square box stopped it (the owner's playtest of 0.1 Beta 2, item 3), each prop's tiers its own where the gap to its
## neighbour opens (HD1, item 5). A block other rows close on every side is met as its box. MapLevel makes them its
## colliders, as RoundSteps' boxes; the block itself (its box) is still what the nav grid, the bots' cover, the noisy
## props, the bake and the minimap take. How each prop is drawn is PropLayout's (PropLayout.grid_drawn). Pure: no
## node, and no model is loaded.

## Each tier's three boxes' reach as shares of its own (along, across): MapStyle.ROUND_TRUNK's, a round prop's
## square cut at its corners.
const CORNERS: Array[Vector2] = [Vector2(1.0, 0.55), Vector2(0.55, 1.0), Vector2(0.883, 0.883)]
## A side counts as touched by another tiered block within this many metres of it (MapLevel.CORE_TOUCH's rule).
const TOUCH := 0.05
## Two neighbours' boxes in a tier run on as one where they meet within this many metres (HD1).
const MEET := 0.01
## A tier reaching under this share of a prop's half-width stands as one square box a prop (SQUARE), not three (HD1).
const SQUARE_UNDER := 0.5
const SQUARE: Array[Vector2] = [Vector2(0.883, 0.883)]

## boxes' props' rectangles in one tier, reused.
static var _rects: Array[Rect2] = []


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
## reaches, round each prop PropLayout stands in the box (PropLayout.grid_spots), its share of the prop's drawn
## half-width, neighbours that meet running on as one box (HD1: where the tier draws in past the gap between two, a
## line flies through it). Touching rows meet where their props as drawn meet: a slot between them shows in the drawn
## boughs too (HD1; TV1 ran a touched side's tiers out to its face, stopping lines that met no bough).
static func boxes(b: MapData.Block, style: MapStyle, props: PropDressConfig, others: Array[MapData.Block],
		out: Array[AABB]) -> void:
	out.clear()
	if not tiered(b, style, props):
		return
	var lo := b.center - b.size * 0.5
	var hi := b.center + b.size * 0.5
	# a block other rows close on every side is met as its box (nothing sees past its props there)
	var shut := true
	for axis: int in [0, 2]:
		for side: float in [-1.0, 1.0]:
			var along := 2 - axis
			shut = shut and _covers(_touches(b, axis, side, others), lo[along], hi[along])
	if shut:
		return
	var model := props.model_of(b)
	var cell: Vector3 = props.grid_cells.get(model, b.size)
	var spread: Vector2 = props.grid_spread.get(model, Vector2.ONE)
	var half := PropLayout.grid_drawn(b.size, cell, spread) * 0.5
	var spots := PropLayout.grid_spots(b.center - Vector3(0.0, b.size.y * 0.5, 0.0), b.size, cell, spread,
			props.grid_scatter.get(model, 0.0))
	var tiers: PackedVector2Array = style.tier_steps[model]
	var n := PropLayout.grid_count(b.size, cell)
	var along_x := b.size.x >= b.size.z
	var long := maxf(b.size.x, b.size.z) * 0.5
	var across := minf(b.size.x, b.size.z) * 0.5
	for k in tiers.size():
		var from := clampf(tiers[k].x, 0.0, 1.0)
		var to := clampf(tiers[k + 1].x, 0.0, 1.0) if k + 1 < tiers.size() else 1.0
		if to <= from:
			continue
		var reach := clampf(tiers[k].y, 0.0, 1.0)
		# three boxes a prop a tier, as RoundSteps' round props: its round ends cut at the square's corners; the
		# boxes of neighbours that meet run on as one (their bounds), and where a tier draws in past the gap between
		# two (HD1: the upper tiers, and props scattered apart) each stands alone, so a line through the gap flies on
		# as it does past the drawn props
		if reach <= 0.0:
			continue
		# a narrow tier (under SQUARE_UNDER) stands as one square a prop, its corners' middle box: the cut corners
		# matter little that close in, and Woodland's thickets hold nearly three thousand spruces
		var corners: Array[Vector2] = CORNERS if reach >= SQUARE_UNDER else SQUARE
		for corner in corners:
			var r := half * reach * corner
			_rects.clear()
			for row in n.z:
				for i in n.x:
					var sp := spots[i * n.z + row]
					var a := Vector2(maxf(sp.x - r.x, -long), maxf(sp.y - r.y, -across))
					var c := Vector2(minf(sp.x + r.x, long), minf(sp.y + r.y, across))
					_rects.append(Rect2(a, (c - a).max(Vector2.ZERO)))
			_merge(_rects)
			for run in _rects:
				out.append(_tier_box(b, run, from, to, along_x))


## `rects` with every two that meet (within MEET) run on as their bounds, until no two meet.
static func _merge(rects: Array[Rect2]) -> void:
	var merged := true
	while merged:
		merged = false
		var i := 0
		while i < rects.size():
			var j := i + 1
			while j < rects.size():
				if rects[i].grow(MEET).intersects(rects[j]):
					rects[i] = rects[i].merge(rects[j])
					rects.remove_at(j)
					merged = true
				else:
					j += 1
			i += 1


## Block `b`'s box from `from` to `to` (shares of its height) over `run`: (along, across) off its middle, along its
## long side (x when `along_x`).
static func _tier_box(b: MapData.Block, run: Rect2, from: float, to: float, along_x: bool) -> AABB:
	var lo_y := b.center.y - b.size.y * 0.5
	var t_lo := Vector3(b.center.x + (run.position.x if along_x else run.position.y), lo_y + b.size.y * from,
			b.center.z + (run.position.y if along_x else run.position.x))
	var t_hi := Vector3(b.center.x + (run.end.x if along_x else run.end.y), lo_y + b.size.y * to,
			b.center.z + (run.end.y if along_x else run.end.x))
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

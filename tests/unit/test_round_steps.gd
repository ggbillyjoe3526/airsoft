extends GutTest
## BP7: a round prop's block (a tree's trunk on Woodland and The Street, Depot's drums and barrels) stands as stepped
## boxes for BBs and bodies (RoundSteps, MapStyle.round_steps): every drawn prop lies inside its block's steps, the
## steps cut the square's empty corners, a BB grazing a drum's or a trunk's open corner flies on while one at its
## middle stops, a prop turned a random quarter has steps that hold it turned, every step's side hugs a prop (so steps
## laid wider than the props fail), a level built without a site look steps as the game's, and the nav grid and the
## bots' cover still take the block's box.

const ROUND_MAPS: Array[String] = ["woodland", "depot", "street"]
## A step may reach this far (m) past a prop's vertex and still hold it (the steps' figures are rounded outwards).
const SLACK := 2e-3
## Each side of a step lies within this share of the step's width of a vertex of the props it holds (the hug; the
## three steps share their inner corner's figure, so one side of a pair can stand a little off, about 0.1).
const HUG := 0.12

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _map(id: String) -> MapData:
	var m := MapData.load_map(id, play.map_style, tuning.rounds.team_size)
	assert_true(m.ok(), "%s loads: %s" % [id, m.problems])
	return m


func _steps(m: MapData, b: MapData.Block) -> Array[AABB]:
	var out: Array[AABB] = []
	RoundSteps.boxes(b, play.map_style, play.site_look.props, PropLayout.field_middle(m), out)
	return out


static func _inside(boxes: Array[AABB], p: Vector3) -> bool:
	for box in boxes:
		if box.grow(SLACK).has_point(p):
			return true
	return false


## The props PropDress lays in `m`'s round blocks: each block's index to its props' vertices (world), the props
## standing in no round block under -1.
func _laid(m: MapData) -> Dictionary[int, PackedVector3Array]:
	var out: Dictionary[int, PackedVector3Array] = {}
	var round_blocks: Array[int] = []
	for i in m.blocks.size():
		if not _steps(m, m.blocks[i]).is_empty():
			round_blocks.append(i)
	var dress := PropDress.build(m, play.site_look.props)
	assert_not_null(dress, "%s is dressed" % m.id)
	if dress == null:
		return out
	add_child_autofree(dress)
	var placed := dress.placed()
	for model: StringName in [&"trunk", &"drum", &"barrel", &"pallet"]:
		if not placed.has(model):
			continue
		var mesh := dress.mesh_of(model)
		var verts := PackedVector3Array()
		for s in mesh.get_surface_count():
			verts.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
		var middle := mesh.get_aabb().get_center()
		for t: Transform3D in placed[model].transforms:
			var at := -1
			for i in round_blocks:
				var b := m.blocks[i]
				if AABB(b.center - b.size * 0.5, b.size).grow(1e-3).has_point(t * middle):
					at = i
					break
			if not out.has(at):
				out[at] = PackedVector3Array()
			for v in verts:
				out[at].append(t * v)
	return out


func test_every_round_prop_lies_inside_its_block_s_steps() -> void:
	for id in ROUND_MAPS:
		var m := _map(id)
		var laid := _laid(m)
		assert_false(laid.has(-1), "%s: every trunk, drum, barrel and pallet stands in a round block" % id)
		var outside := 0
		for i: int in laid:
			if i < 0:
				continue
			var steps := _steps(m, m.blocks[i])
			for v in laid[i]:
				if not _inside(steps, v):
					outside += 1
		assert_eq(outside, 0, "%s: every trunk, drum, barrel and pallet vertex inside its block's steps" % id)
		assert_gt(laid.size(), 10, "%s: its round props were checked" % id)


func test_every_step_s_sides_hug_the_props_it_holds() -> void:
	for id in ROUND_MAPS:
		var m := _map(id)
		var laid := _laid(m)
		var worst := 0.0
		var worst_at := ""
		var wide: Array[String] = []
		for i: int in laid:
			if i < 0:
				continue
			var b := m.blocks[i]
			var steps := _steps(m, b)
			# The steps' outline (above a pallet) reaches no further than the props' own, on every side.
			var outline := AABB()
			var first := true
			for s in steps:
				if s.size.y >= b.size.y * 0.5:
					outline = s if first else outline.merge(s)
					first = false
			var reach := AABB()
			first = true
			for v in laid[i]:
				if v.y > outline.position.y + SLACK:
					reach = AABB(v, Vector3.ZERO) if first else reach.expand(v)
					first = false
			for axis: int in [0, 2]:
				if absf(outline.position[axis] - reach.position[axis]) > SLACK \
						or absf(outline.end[axis] - reach.end[axis]) > SLACK:
					wide.append("a %s at %s" % [b.kind, b.center])
					break
			for s in steps:
				# Each of the step's four sides: how far in from it the nearest vertex along its span is, as a share
				# of the step's width across that side.
				for side in 4:
					var axis := 0 if side < 2 else 2
					var across := 2 - axis
					var plane := s.position[axis] if side % 2 == 0 else s.end[axis]
					var gap := INF
					for v in laid[i]:
						if v[across] >= s.position[across] - SLACK and v[across] <= s.end[across] + SLACK \
								and v.y >= s.position.y - SLACK and v.y <= s.end.y + SLACK:
							gap = minf(gap, absf(v[axis] - plane))
					var share := gap / maxf(s.size[axis], 1e-6)
					if share > worst:
						worst = share
						worst_at = "a %s at %s, side %d, %.3f m" % [b.kind, b.center, side, gap]
		assert_lt(worst, HUG, "%s: every step's side hugs a prop (worst %.3f of its width: %s)" % [id, worst, worst_at])
		assert_eq(wide.size(), 0, "%s: no steps reach wider than their props (%s)" % [id, ", ".join(wide.slice(0, 3))])


func test_a_level_without_a_site_look_steps_as_the_game_s() -> void:
	var built_in := PropDressConfig.new()
	for id in ROUND_MAPS:
		var m := _map(id)
		var middle := PropLayout.field_middle(m)
		var differ := 0
		var stepped := 0
		var plain: Array[AABB] = []
		for b in m.blocks:
			var game := _steps(m, b)
			RoundSteps.boxes(b, play.map_style, built_in, middle, plain)
			stepped += 1 if not game.is_empty() else 0
			differ += 0 if game == plain else 1
		assert_eq(differ, 0, "%s: MatchRunner's level (no site look) steps every round prop as the game's" % id)
		assert_gt(stepped, 0, "%s steps its round props" % id)


func test_the_steps_cut_the_square_s_empty_corners_and_stay_inside_it() -> void:
	for id in ROUND_MAPS:
		var m := _map(id)
		var counted := 0
		var clusters := 0
		for b in m.blocks:
			var steps := _steps(m, b)
			if steps.is_empty():
				continue
			counted += 1
			var box := AABB(b.center - b.size * 0.5, b.size).grow(1e-4)
			for s in steps:
				assert_true(box.encloses(s), "%s: a %s's step stays inside its block's box" % [id, b.kind])
			# Each corner of the block's footprint, at half height, a hand's breadth in: open.
			for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				var p := b.center + Vector3(corner.x * b.size.x * 0.49, 0.0, corner.y * b.size.z * 0.49)
				if b.kind != &"tree":
					assert_false(_inside(steps, p), "%s: a %s's corner is open" % [id, b.kind])
			# Halfway out to a corner: inside a prop (a cluster's, a row's first) whatever the kind.
			var held := b.center + Vector3(b.size.x * 0.25, 0.0, b.size.z * 0.25)
			assert_true(_inside(steps, held), "%s: a %s's prop is solid" % [id, b.kind])
			# A cluster's props stand apart (RK1: cluster_fill), so its core is solid: no line along the gaps between
			# them (PropLayout's grid lines, across the whole block) gets through at mid-height.
			var props := play.site_look.props
			if props.lay_of(b) == PropDressConfig.Lay.CLUSTER:
				var nx := maxi(1, roundi(b.size.x / props.cluster_cell))
				var nz := maxi(1, roundi(b.size.z / props.cluster_cell))
				var lo := b.center - b.size * 0.5
				var y := b.center.y + b.size.y * 0.1
				for i in range(1, nx):
					var x := lo.x + b.size.x * i / nx
					assert_true(_crosses(steps, Vector3(x, y, lo.z - 0.1), Vector3(x, y, lo.z + b.size.z + 0.1)),
							"%s: a line between a %s cluster's props is stopped" % [id, b.kind])
				for j in range(1, nz):
					var z := lo.z + b.size.z * j / nz
					assert_true(_crosses(steps, Vector3(lo.x - 0.1, y, z), Vector3(lo.x + b.size.x + 0.1, y, z)),
							"%s: a line between a %s cluster's props is stopped" % [id, b.kind])
				clusters += 1
		assert_gt(clusters if id == "depot" else 1, 0, "%s: its drum clusters were checked" % id)
		assert_gt(counted, 0, "%s has round props" % id)


func test_a_trunk_s_front_corners_are_open_and_its_rooted_back_ones_solid() -> void:
	var m := _map("woodland")
	var middle := PropLayout.field_middle(m)
	var trees := 0
	for b in m.blocks:
		if b.kind != &"tree" or b.size.x < 1.0:
			continue
		trees += 1
		var steps := _steps(m, b)
		var front := 1.0 if middle.z >= b.center.z else -1.0
		var open := b.center + Vector3(b.size.x * 0.45, 0.0, front * b.size.z * 0.45)
		var rooted := b.center + Vector3(b.size.x * 0.4, 0.0, -front * b.size.z * 0.4)
		assert_false(_inside(steps, open), "a trunk's front corner (away from its roots) is open")
		assert_true(_inside(steps, rooted), "a trunk's back corner (its roots) is solid")
		if trees >= 20:
			break
	assert_gt(trees, 0)


func test_a_quarter_turned_kind_s_steps_hold_it_turned() -> void:
	var props := play.site_look.props
	var turned_kinds := 0
	for kind: StringName in props.kind_props:
		var model: StringName = props.kind_props[kind]
		var lay: PropDressConfig.Lay = props.kind_lays.get(kind, PropDressConfig.Lay.FIT)
		if not play.map_style.round_steps.has(model) or lay == PropDressConfig.Lay.FIT:
			continue
		turned_kinds += 1
		var steps: PackedVector2Array = play.map_style.round_steps[model]
		for k in range(0, steps.size() - 1, 2):
			var turned := Rect2(Vector2(-steps[k + 1].y, steps[k].x), Vector2.ZERO).expand(
					Vector2(-steps[k].y, steps[k + 1].x))
			var found := false
			for j in range(0, steps.size() - 1, 2):
				var r := Rect2(steps[j], Vector2.ZERO).expand(steps[j + 1])
				found = found or (r.position.is_equal_approx(turned.position) and r.end.is_equal_approx(turned.end))
			assert_true(found, "%s's step %d turned a quarter is one of its steps" % [kind, k / 2])
	assert_eq(turned_kinds, 2, "the drums and the barrels are laid in cells")


func test_a_bb_grazing_a_drum_s_corner_flies_on_and_one_at_its_middle_stops() -> void:
	var m := _map("depot")
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body)
	var drum: MapData.Block = null
	for b in m.blocks:
		if b.kind == &"drum":
			drum = b
			break
	assert_not_null(drum)
	if drum == null:
		return
	var hit := RayHit.new()
	var half := drum.size * 0.5
	var y := drum.center.y + 0.3
	# Across the box's +x +z corner, 4 cm in from it along the diagonal: the old box stopped it.
	var corner := Vector3(drum.center.x + half.x, y, drum.center.z + half.z)
	var graze_from := corner + Vector3(0.3, 0.0, -0.3) + Vector3(-0.03, 0.0, -0.03)
	var graze_to := corner + Vector3(-0.3, 0.0, 0.3) + Vector3(-0.03, 0.0, -0.03)
	var old_box := AABB(drum.center - half, drum.size)
	assert_true(old_box.intersects_segment(graze_from, graze_to) != null, "the line crosses the old box's corner")
	assert_false(level.query().ray(graze_from, graze_to, hit), "a BB grazing the drums' open corner flies on")
	# Along a row of drums' middles (a cell's centre in z).
	var row_z := drum.center.z + half.z * 0.5
	var mid_from := Vector3(drum.center.x + half.x + 0.5, y, row_z)
	assert_true(level.query().ray(mid_from, Vector3(drum.center.x, y, row_z), hit), "a BB at a drum's middle stops")
	# RK1: the stacks stand `cluster_fill` of their cells, a hand's width in from the box's face
	assert_between(hit.position.x, drum.center.x + half.x - 0.1, drum.center.x + half.x - 0.01, "on the drums' face")


func test_the_nav_grid_and_the_blocks_still_take_the_box() -> void:
	var m := _map("depot")
	var drums := 0
	for b in m.blocks:
		if b.kind == &"drum" or b.kind == &"barrel":
			drums += 1
	assert_eq(drums, 22, "Depot's drum and barrel blocks are still one block each")
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	for b in m.blocks:
		if b.kind != &"drum":
			continue
		var corner := b.center + Vector3(b.size.x * 0.49, -b.size.y * 0.5, b.size.z * 0.49)
		assert_false(nav.is_walkable_at(corner), "a drum block's corner is no walkable node")


func _crosses(steps: Array[AABB], from: Vector3, to: Vector3) -> bool:
	for s in steps:
		if s.intersects_segment(from, to) != null:
			return true
	return false

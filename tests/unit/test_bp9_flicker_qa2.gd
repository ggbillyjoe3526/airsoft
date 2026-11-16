extends GutTest
## BP9 part 2 QA: two wall sections side by side leave no way through their join. A section's end face may lie a hair
## inside the cell (the fix sinks it under the panel's end), so what closes the join is every face across the wall,
## above or below it reaching the section's ends, to the float, at every height.

var play: PlayTuning = PlayTuning.load_default()

## How far (m) a section built to its cell may differ from it to be tested here (as in test_bp9_flicker).
const CELL_BUILT := 0.01
## The sections that stand in a row, each meeting the next at its end.
const SECTIONS: Array[StringName] = [&"range_wall", &"range_backstop", &"sandbags"]
## A face whose normal points this much along the length is an end face, not one that bounds it.
const END_FACING := 0.5
## Heights tested along the section, and the margin kept from its top (m).
const HEIGHT_STEPS := 60
const TOP_MARGIN := 0.004
## How far (m) a bounding face's reach may fall short of the mesh's own: the float.
const REACH_SLACK := 1e-6


func test_a_section_built_to_its_cell_is_closed_at_both_ends_at_every_height() -> void:
	var cfg := play.site_look.props
	var tested := 0
	for model: StringName in SECTIONS:
		var mesh := cfg.mesh_of(model)
		if mesh == null:
			continue
		var box := mesh.get_aabb()
		var cell: Vector3 = cfg.grid_cells[model]
		if absf(box.size.x - cell.x) > CELL_BUILT:
			continue
		tested += 1
		var reach := _per_height_shortfall(mesh)
		assert_lt(reach, REACH_SLACK, "%s: a face bounding the ends falls %.5f m short of the section's end" % [model, reach])
	assert_eq(tested, SECTIONS.size(), "the Range's wall and backstop and the sandbags are built to their cells")


## The most any height's bounding faces fall short of the mesh's x ends (m); 0 when every height reaches both.
func _per_height_shortfall(mesh: Mesh) -> float:
	var box := mesh.get_aabb()
	var worst := 0.0
	for h in HEIGHT_STEPS:
		var y := lerpf(box.position.y + 0.05, box.end.y - TOP_MARGIN, float(h) / (HEIGHT_STEPS - 1))
		var lo := INF
		var hi := -INF
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for t in index.size() / 3:
				var a := verts[index[t * 3]]
				var b := verts[index[t * 3 + 1]]
				var c := verts[index[t * 3 + 2]]
				var n := (b - a).cross(c - a)
				if n.length() < 1e-12 or absf(n.normalized().x) > END_FACING:
					continue
				if y < minf(a.y, minf(b.y, c.y)) or y > maxf(a.y, maxf(b.y, c.y)):
					continue
				lo = minf(lo, minf(a.x, minf(b.x, c.x)))
				hi = maxf(hi, maxf(a.x, maxf(b.x, c.x)))
		if lo < INF:
			worst = maxf(worst, maxf(lo - box.position.x, box.end.x - hi))
	return worst

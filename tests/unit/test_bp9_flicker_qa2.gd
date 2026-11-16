extends GutTest
## BP9 part 2 QA: a wall section's cap reaches the section's ends, so two sections side by side leave no slit
## between their caps (sinking a cap's end face under the lip of its top leaves a slit seen straight along the wall).

var play: PlayTuning = PlayTuning.load_default()

## How far a band's reach along the length may fall short of the mesh's own (m).
const REACH_SLACK := 1e-5
## The share of the section's height, from its top, that makes the cap.
const CAP_BAND := 0.005
## A face whose normal points this much along the length closes the section's end.
const END_FACING := 0.99


func _reach_of_top_band(mesh: Mesh) -> Vector2:
	var box := mesh.get_aabb()
	var floor_y := box.end.y - box.size.y * CAP_BAND
	var lo := INF
	var hi := -INF
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			# Only the faces that close the cap along its length, not its top or sides running out to the same x.
			if verts[i].y >= floor_y and absf(normals[i].x) > END_FACING:
				lo = minf(lo, verts[i].x)
				hi = maxf(hi, verts[i].x)
	return Vector2(lo, hi)


func test_the_ranges_wall_cap_reaches_both_ends_of_its_section() -> void:
	var mesh := play.site_look.props.mesh_of(&"range_wall")
	assert_not_null(mesh, "the Range's wall section loads")
	var box := mesh.get_aabb()
	var reach := _reach_of_top_band(mesh)
	assert_almost_eq(reach.x, box.position.x, REACH_SLACK, "the cap's left end is the section's")
	assert_almost_eq(reach.y, box.end.x, REACH_SLACK, "the cap's right end is the section's")

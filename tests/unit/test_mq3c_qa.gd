extends GutTest
## MQ3C QA: the face's UVs keep clear of their cell's edge (mip levels would blend a neighbour look in), every look's
## whole cell stays inside the map.

const HEADS: Array[String] = ["Head_HighCut", "Head_FullCut", "Head_Cap", "Head_Boonie"]
const LEVELS: Array[String] = ["", "_LOD1", "_LOD2"]
const MAP := Vector2(2048.0, 1024.0)
const CELL := Vector2(1024.0, 512.0)
## A face UV is at least this many map pixels from its cell's edge (4 px: the 3rd mip level's texel is 8 px wide).
const EDGE_PX_AT_LEAST := 4.0

var config: FigureConfig = null
var models: FigureModels = null


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()


func test_face_uvs_keep_clear_of_the_cell_edge_for_every_look() -> void:
	var root := models.scene(0).instantiate()
	add_child_autofree(root)
	for head in HEADS:
		for level in LEVELS:
			var mi := root.find_child(head + level, true, false) as MeshInstance3D
			assert_not_null(mi, head + level)
			if mi == null:
				continue
			var mesh := mi.mesh
			for s in mesh.get_surface_count():
				var m := mesh.surface_get_material(s)
				if m == null or not m.resource_name.begins_with("Face"):
					continue
				var uv := mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV] as PackedVector2Array
				for look in config.face_offsets.size():
					var shift := config.face_offsets[look] * MAP
					var origin := Vector2(0.0, 512.0) + shift
					var lo := Vector2(INF, INF)
					var hi := Vector2(-INF, -INF)
					for p in uv:
						var q := p * MAP + shift
						lo = lo.min(q)
						hi = hi.max(q)
					var name := "%s%s look %d" % [head, level, look]
					assert_gte(lo.x - origin.x, EDGE_PX_AT_LEAST, name + " left")
					assert_gte(lo.y - origin.y, EDGE_PX_AT_LEAST, name + " top")
					assert_gte(origin.x + CELL.x - hi.x, EDGE_PX_AT_LEAST, name + " right")
					assert_gte(origin.y + CELL.y - hi.y, EDGE_PX_AT_LEAST, name + " bottom")

extends GutTest
## Dev 3 map models (FS1): every map model is solid from outside. The owner saw the sky through the water tower
## (2026-11-09): its drum and roof were built inside out, so the game culled them as holes. Rays from all round and
## above (the ground hides a model's underside) must first meet a front face, a face turned toward them: by its winding,
## as the game culls (Godot's front faces wind clockwise, so (c - a) x (b - a) is a face's outside).

## Rays a model: elevation steps (from level to steeply above) by azimuth steps, each at seeded points in its box.
const ELEVATIONS := 5
const AZIMUTHS := 12
const AIMS := 3
## The share of rays whose first face is turned away that a model may have: thin single-sided trim seen edge-on.
const BACK_MOST := 0.02
const SEED := 20261109


func test_every_skyline_model_and_the_flagpole_are_solid_from_outside() -> void:
	var play := PlayTuning.load_default()
	var paths: Array[String] = [play.flag.pole_model]
	for kind: StringName in play.skyline.models:
		paths.append(play.skyline.models[kind])
	for kind: StringName in play.skyline.variants:
		for path: String in play.skyline.variants[kind]:
			paths.append(path)
	for path in paths:
		var mesh := PropDressConfig.load_mesh(path)
		assert_not_null(mesh, "%s loads" % path)
		if mesh == null:
			continue
		var share := back_share(mesh)
		assert_lt(share, BACK_MOST, "%s: %.1f%% of rays from outside meet a face turned away (sky through it)"
				% [path.get_file(), share * 100.0])



## RM1: the practice range's props and every part of its targets and boards (the targets' files hold a mesh a part).
func test_the_ranges_models_are_solid_from_outside() -> void:
	var files: Array[String] = ["props/range_wall", "props/range_backstop", "props/sandbags", "props/site_toilet",
		"props/water_tote", "props/generator", "range/steel_target", "range/figure_target", "range/distance_board"]
	for file in files:
		var packed := load("res://assets/models/%s.glb" % file) as PackedScene
		assert_not_null(packed, "%s loads" % file)
		if packed == null:
			continue
		var scene := packed.instantiate()
		var stack: Array[Node] = [scene]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is MeshInstance3D:
				var share := back_share((n as MeshInstance3D).mesh)
				assert_lt(share, BACK_MOST, "%s %s: %.1f%% of rays from outside meet a face turned away"
						% [file, n.name, share * 100.0])
		scene.free()

## The share of rays from outside `mesh` (all round, level to steeply above) whose first face is turned away.
static func back_share(mesh: Mesh) -> float:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var box := mesh.get_aabb()
	var reach := box.size.length() * 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var rays := 0
	var back := 0
	for e in ELEVATIONS:
		var up := deg_to_rad(70.0 * e / (ELEVATIONS - 1))
		for a in AZIMUTHS:
			var turn := TAU * (a + 0.5 * (e % 2)) / AZIMUTHS
			var from := box.get_center() + Vector3(cos(up) * cos(turn), sin(up), cos(up) * sin(turn)) * reach
			for k in AIMS:
				var aim := box.position + box.size * Vector3(rng.randf(), rng.randf(), rng.randf())
				var dir := (aim - from).normalized()
				var nearest := INF
				var facing := 0.0
				for t in range(0, index.size() - 2, 3):
					var hit: Variant = Geometry3D.ray_intersects_triangle(from, dir, verts[index[t]], verts[index[t + 1]],
							verts[index[t + 2]])
					if hit == null:
						continue
					var d := from.distance_to(hit as Vector3)
					if d < nearest:
						nearest = d
						var v0 := verts[index[t]]
						facing = (verts[index[t + 2]] - v0).cross(verts[index[t + 1]] - v0).dot(dir)
				if nearest < INF:
					rays += 1
					if facing > 0.0:
						back += 1
	return float(back) / maxf(rays, 1.0)

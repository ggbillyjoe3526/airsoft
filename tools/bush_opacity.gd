extends SceneTree
## The bushes' leaves against their models (LF1; dev only, never exported): 3,000 seeded lines from 15 m off at eye
## height to points in and just past a fern and a shrub as BushView draws them (WoodsConfig's models, Woodland's sizes),
## each "hidden" when it meets a triangle of the drawn plant; then, for counted ellipsoids of shares of the drawn radius
## and height (from a share of the height up), the lines whose counted leaves stop a BB (leaf_stop_depth) that meet no
## drawn leaf ("unseen" cover) and the lines that meet a leaf yet get through ("through"). Measured, never asserted:
## what BallisticsConfig's leaf shares were picked from.
##   godot --headless --path . -s res://tools/bush_opacity.gd

## Woodland's fern and shrub sizes: [kind, radius, height].
const KINDS := [["fern", 1.0, 1.2], ["bush", 1.3, 1.7]]
## The lines: how many, from how far (m) and how high (m), seeded.
const LINES := 3000
const FROM := 15.0
const EYE := 1.6
const SEED := 7
## The leaf sheet's cover a leaf card is drawn from (look_foliage.gdshader's `alpha_cut`).
const ALPHA_CUT := 0.5


func _initialize() -> void:
	var woods := WoodsConfig.new()
	var stop := SimTuning.load_default().ballistics.leaf_stop_depth
	# WQ1: the leaves are cards on the leaf sheet, so a line meets a leaf only where the sheet is drawn
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(woods.bush_sheet))
	for k: Array in KINDS:
		var path: String = woods.fern_model if k[0] == "fern" else woods.bush_model
		var mesh := PropDressConfig.load_mesh(path)
		var r: float = k[1]
		var h: float = k[2]
		var box := mesh.get_aabb()
		var drawn_f := Foliage.new()
		drawn_f.add(Vector3.ZERO, r, h)
		var tris := PackedVector3Array()
		var uvs := PackedVector2Array()
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
			var xf := BushView.fitted(drawn_f, 0, box, 0.0)
			for i in idx:
				tris.append(xf * verts[i])
				uvs.append((uv as PackedVector2Array)[i] if uv != null else Vector2(-8.0, 0.0))
		# segments: shooter 15 m off at 1.6 m, to a point in or just behind the bush
		var segs: Array[PackedVector3Array] = []
		var hidden := PackedByteArray()
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED
		for n in LINES:
			var a := rng.randf() * TAU
			var from := Vector3(cos(a), 0.0, sin(a)) * FROM + Vector3.UP * EYE
			var p := Vector3(rng.randf_range(-1.2, 1.2) * r, rng.randf_range(0.3, 1.7), rng.randf_range(-1.2, 1.2) * r)
			var dir := (p - from).normalized()
			var len := from.distance_to(p)
			var hit := false
			for t in range(0, tris.size(), 3):
				var at: Variant = Geometry3D.segment_intersects_triangle(from, p, tris[t], tris[t + 1], tris[t + 2])
				if at != null and _opaque(sheet, tris, uvs, t, at as Vector3):
					hit = true
					break
			segs.append(PackedVector3Array([from, p]))
			hidden.append(1 if hit else 0)
		var any := 0
		for i in hidden.size():
			if hidden[i] == 1:
				any += 1
		print("%s: %d triangles; %d of %d lines drawn hidden" % [k[0], tris.size() / 3, any, hidden.size()])
		for sr: float in [0.6, 0.7, 0.8, 0.9]:
			for lo: float in [0.0, 0.1, 0.2, 0.25]:
				var line := "  r %.1f from %.2f:" % [sr, lo]
				for hi: float in [0.8, 0.9, 1.0]:
					var f := Foliage.new()
					f.add(Vector3(0.0, h * lo, 0.0), r * sr, h * (hi - lo))
					var invisible := 0
					var through := 0
					for i in segs.size():
						var stops := f.depth(segs[i][0], segs[i][1]) >= stop
						if stops and hidden[i] == 0:
							invisible += 1
						elif not stops and hidden[i] == 1:
							through += 1
					line += "  to %.1f: unseen %4.1f%% through %4.1f%%" % [hi, 100.0 * invisible / segs.size(),
							100.0 * through / segs.size()]
				print(line)
	quit()


## Whether the drawn plant is solid where a line meets triangle `t` at `at` (WQ1): bark (UV x under -1) always; a leaf
## card where the leaf sheet's cover reaches the shaders' cut (look_foliage's alpha_cut).
func _opaque(sheet: Image, tris: PackedVector3Array, uvs: PackedVector2Array, t: int, at: Vector3) -> bool:
	if sheet == null or uvs[t].x < -1.0:
		return true
	var w := Geometry3D.get_triangle_barycentric_coords(at, tris[t], tris[t + 1], tris[t + 2])
	var uv := uvs[t] * w.x + uvs[t + 1] * w.y + uvs[t + 2] * w.z
	var px := Vector2i(clampi(int(uv.x * sheet.get_width()), 0, sheet.get_width() - 1),
			clampi(int(uv.y * sheet.get_height()), 0, sheet.get_height() - 1))
	return sheet.get_pixelv(px).a >= ALPHA_CUT

extends SceneTree
## Bakes each map's light (DP2) into BakeConfig.DIR, for every map in data/maps/ that names a `bakedLight.file`, or only
## the ids given after `--`. Headless, no GPU, so it runs in a cloud session or CI:
##   godot --headless --path . -s res://tools/bake_light.gd [-- depot range]
## Run it after changing a map's blocks, its style's colours or the sun (tests/unit/test_baked_light.gd fails a stale
## bake). A dev tool: never exported (export_presets.cfg leaves tools/ out).
##
## For each vertex of the map's tiled mesh (GreyboxFaces.tile) it casts BakeConfig.rays over its face's half of the sky,
## cosine-weighted, against the level's faces (a TriangleMesh: the engine's own ray tree, no physics frame needed).
## A ray that meets nothing within `reach`, or meets the open ground where the ground sees the sky straight up, counts as
## sky; a ray that meets a face the sun reaches brings back that face's colour times the sun's slant on it: the sun's
## one bounce. In a dim room (`bakedLight.dim`) both are that room's share of what they would be. A vertex hidden
## inside an abutting block takes its face's nearest open vertex's light (`fill_hidden`). The same blocks give the same
## bytes.

## The golden angle (radians): each ray turns this far round the normal from the last, so any number of rays spread
## evenly.
const GOLDEN_ANGLE := 2.399963229728653


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only := OS.get_cmdline_user_args()
	var tuning := PlayTuning.load_default()
	var failed := false
	for file in DirAccess.get_files_at(MapData.DIR):
		if file.get_extension() != "json":
			continue
		var id := file.get_basename()
		if not only.is_empty() and not only.has(id):
			continue
		var m := MapData.load_map(id, tuning.map_style, 1)
		if m.baked_light_file.is_empty():
			continue
		if not m.ok():
			push_error("bake_light: %s refused: %s" % [id, "; ".join(m.problems)])
			failed = true
			continue
		var started := Time.get_ticks_msec()
		var sun := LightingConfig.for_map(tuning.lighting, null, m, LightingConfig.DAY)
		var bake := bake_map(m, tuning.map_style, sun, tuning.baked_light)
		var path := BakeConfig.path_for(m.baked_light_file)
		DirAccess.make_dir_recursive_absolute(BakeConfig.DIR)
		var err := save(bake, path)
		if err != OK:
			push_error("bake_light: can't write %s (%s)" % [path, error_string(err)])
			failed = true
			continue
		print("bake_light: %s: %d vertices in %.1f s, %s, %d bytes" % [id, bake.vertex_count,
				(Time.get_ticks_msec() - started) / 1000.0, path, FileAccess.get_file_as_bytes(path).size()])
	quit(1 if failed else 0)


## Writes `bake` to `path`, compressed.
static func save(bake: BakedLight, path: String) -> Error:
	return ResourceSaver.save(bake, path, ResourceSaver.FLAG_COMPRESS)


## `m`'s baked light: for each vertex of its tiled mesh, the sky it sees and the sun's bounce reaching it.
static func bake_map(m: MapData, style: MapStyle, lighting: LightingConfig, cfg: BakeConfig) -> BakedLight:
	var t := GreyboxFaces.tile(m, cfg.cell, cfg.ground_y)
	var faces := PackedVector3Array()
	var face_normals := PackedVector3Array()
	var face_albedo := PackedColorArray()
	for b in m.blocks:
		var albedo := style.block_colour(b).srgb_to_linear()
		for f in GreyboxFaces.faces_of(b):
			_add_triangles(f, albedo, faces, face_normals, face_albedo)
	_add_triangles(GreyboxFaces.ground_face(style), style.ground_colour.srgb_to_linear(), faces, face_normals, face_albedo)
	var world := TriangleMesh.new()
	world.create_from_faces(faces)
	var sun := Basis.from_euler(Vector3(deg_to_rad(-lighting.sun_elevation), deg_to_rad(lighting.sun_heading), 0.0)).z
	var sun_colour := lighting.sun_colour.srgb_to_linear()
	var local := _hemisphere(cfg.rays)
	var n := t.positions.size()
	var bake := BakedLight.new()
	bake.vertex_count = n
	bake.source_hash = BakedLight.hash_of(m, style, lighting, cfg)
	bake.sky.resize(n)
	bake.bounce.resize(n * 3)
	var dirs := PackedVector3Array()
	var dirs_for := Vector3.ZERO
	for v in n:
		var normal := t.normals[v]
		if normal != dirs_for:
			dirs = _turned(local, normal)
			dirs_for = normal
		var from := t.positions[v] + normal * cfg.lift
		var open := 0
		var light := Color(0.0, 0.0, 0.0)
		for d in dirs:
			var hit := world.intersect_segment(from, from + d * cfg.reach)
			if hit.is_empty():
				open += 1
				continue
			var at: Vector3 = hit["position"]
			var face: int = hit["face_index"]
			var hn := face_normals[face]
			if hn.dot(d) >= 0.0:
				continue # a face's back: the vertex is inside a block, in the dark
			var lifted := at + hn * cfg.lift
			if at.y <= cfg.ground_y and hn.y > 0.5 \
					and world.intersect_segment(lifted, lifted + Vector3.UP * cfg.reach).is_empty():
				open += 1
			var slant := hn.dot(sun)
			if slant > 0.0 and world.intersect_segment(lifted, lifted + sun * cfg.sun_reach).is_empty():
				light += face_albedo[face] * slant
		# a dim room (MapData.baked_dim_boxes: Depot's Lounge) sees less sky and less of the sun's bounce
		var dim := m.baked_light_at(Vector2(t.positions[v].x, t.positions[v].z))
		bake.sky[v] = _byte(dim * float(open) / dirs.size())
		var k := v * 3
		var share := dim / dirs.size()
		bake.bounce[k] = _byte(light.r * share * sun_colour.r)
		bake.bounce[k + 1] = _byte(light.g * share * sun_colour.g)
		bake.bounce[k + 2] = _byte(light.b * share * sun_colour.b)
	fill_hidden(bake, t, m, cfg.lift)
	return bake


## Each vertex whose rays start inside another block (a face's part hidden where a block abuts it) takes the light of
## the nearest vertex on its face that is not (DP2's row: a hidden vertex's dark spread up to a cell over the face in
## sight, a soft shade at every joint); a face hidden whole keeps its own. Grid steps over each face (Tiles.grids),
## breadth first from the vertices in the open.
static func fill_hidden(bake: BakedLight, t: GreyboxFaces.Tiles, m: MapData, lift: float) -> void:
	var lo := PackedVector3Array()
	var hi := PackedVector3Array()
	for b in m.blocks:
		lo.append(b.center - b.size * 0.5)
		hi.append(b.center + b.size * 0.5)
	var queue := PackedInt32Array()
	var hidden := PackedByteArray()
	for g in range(0, t.grids.size(), 3):
		var first := t.grids[g]
		var cols := t.grids[g + 1]
		var count := cols * t.grids[g + 2]
		var own := t.blocks[first]
		var face := AABB(t.positions[first], Vector3.ZERO)
		face = face.expand(t.positions[first + count - 1]).expand(t.positions[first + cols - 1])
		face = face.expand(t.positions[first + count - cols]).grow(lift * 2.0)
		var near: Array[int] = []
		for i in m.blocks.size():
			if i != own and m.blocks[i].rise == MapData.Rise.NONE and AABB(lo[i], hi[i] - lo[i]).intersects(face):
				near.append(i)
		if near.is_empty():
			continue
		hidden.resize(count)
		hidden.fill(0)
		queue.clear()
		var any := false
		for k in count:
			var p := t.positions[first + k] + t.normals[first + k] * lift
			for i in near:
				if p.x > lo[i].x and p.x < hi[i].x and p.y > lo[i].y and p.y < hi[i].y and p.z > lo[i].z \
						and p.z < hi[i].z:
					hidden[k] = 1
					any = true
					break
			if hidden[k] == 0:
				queue.append(k)
		if not any or queue.is_empty():
			continue
		var at := 0
		while at < queue.size():
			var k := queue[at]
			at += 1
			var row := k / cols
			var col := k % cols
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c := col + step.x
				var r := row + step.y
				if c < 0 or c >= cols or r < 0 or r >= t.grids[g + 2]:
					continue
				var n := r * cols + c
				if hidden[n] != 1:
					continue
				hidden[n] = 2
				var from := first + k
				var to := first + n
				bake.sky[to] = bake.sky[from]
				for ch in 3:
					bake.bounce[to * 3 + ch] = bake.bounce[from * 3 + ch]
				queue.append(n)


## Face `f` (a convex polygon, anticlockwise from outside) as triangles, each with its outward normal and colour.
static func _add_triangles(f: PackedVector3Array, albedo: Color, faces: PackedVector3Array,
		normals: PackedVector3Array, colours: PackedColorArray) -> void:
	var n := GreyboxFaces.face_normal(f)
	for i in range(1, f.size() - 1):
		faces.append(f[0])
		faces.append(f[i])
		faces.append(f[i + 1])
		normals.append(n)
		colours.append(albedo)


## `count` directions round +Z, cosine-weighted: a spiral over the unit disc lifted onto the half sphere.
static func _hemisphere(count: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in count:
		var r := sqrt((k + 0.5) / count)
		var turn := k * GOLDEN_ANGLE
		out.append(Vector3(r * cos(turn), r * sin(turn), sqrt(maxf(0.0, 1.0 - r * r))))
	return out


## `local` (round +Z) turned to stand round `normal`.
static func _turned(local: PackedVector3Array, normal: Vector3) -> PackedVector3Array:
	var side := (Vector3.RIGHT if absf(normal.y) > 0.9 else Vector3.UP).cross(normal).normalized()
	var up := normal.cross(side)
	var out := PackedVector3Array()
	for d in local:
		out.append(side * d.x + up * d.y + normal * d.z)
	return out


## `value` (0 to 1) as a byte, 0 to BakedLight.FULL.
static func _byte(value: float) -> int:
	return clampi(roundi(value * BakedLight.FULL), 0, int(BakedLight.FULL))

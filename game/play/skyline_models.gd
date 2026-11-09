class_name SkylineModels
extends RefCounted
## The skyline's buildings drawn from models (Dev 3 map models; SkylineConfig.models): where each piece of a kind with
## a model stands its model, stretched to fill the piece's box exactly (a silo row, one a drum), its front toward the
## field as its greybox's (a shed's doors, a crane's jib, a mast's lamps, a tower's stairs); and the model's triangles
## added to the skyline's one mesh, its BODY faces in the piece's colour, faded toward the horizon as the greybox is.
## Plain data built once a match: SkylineView draws it, SkylineSight never reads it (sight stays the greybox's).

## A model's vertex colour alpha (tools/blender/maps/vertex_paint.py): under BODY_BELOW the piece's own colour times
## the vertex's shade, under FIXED_FROM a lamp's glass (glowing at night), from it the colour as it is.
const BODY_BELOW := 0.25
const FIXED_FROM := 0.75


## One model stood in the world: `mesh` placed by `at` (its determinant negative where the frame is mirrored), its
## BODY faces in `body` (sRGB).
class Placed:
	extends RefCounted
	var mesh: Mesh = null
	var at: Transform3D = Transform3D.IDENTITY
	var body: Color = Color.WHITE


## The models `p` stands, the field's middle at `middle`; none when its kind has no model (it keeps its greybox).
static func placed_of(p: SkylinePiece, cfg: SkylineConfig, middle: Vector2) -> Array[Placed]:
	var out: Array[Placed] = []
	if p.kind == &"treeline":
		return _band(p, cfg)
	var mesh := cfg.model_of(p.kind)
	if mesh == null:
		return out
	var toward := SkylineShapes.toward_of(p, middle)
	var body := body_of(p, cfg)
	if p.kind == &"silo":
		var r := SkylineShapes.silo_radius(p)
		var along := Vector3(1.0, 0.0, 0.0) if p.width >= p.depth else Vector3(0.0, 0.0, 1.0)
		for c in SkylineShapes.silo_drums(p, cfg):
			out.append(_fit(mesh, c, along, along.cross(Vector3.UP), Vector3(r * 2.0, p.height, r * 2.0), false, body))
		return out
	var foot := Vector3(p.at.x, 0.0, p.at.y)
	var long := Vector3(1.0, 0.0, 0.0) if p.width >= p.depth else Vector3(0.0, 0.0, 1.0)
	var x_axis := long
	var z_axis := long.cross(Vector3.UP)
	var height := p.height
	match p.kind:
		&"mast":
			# free-turned: the head across the line to the field, the lamps toward it (a mirror frame, harmless)
			z_axis = Vector3(toward.x, 0.0, toward.y)
			x_axis = Vector3(-toward.y, 0.0, toward.x)
			return [_fit(mesh, foot, x_axis, z_axis, Vector3(p.width, height, p.depth), false, body)]
		&"shed":
			var face := SkylineShapes.facing(toward)
			var f := Vector3(face.x, 0.0, face.y)
			var across := Vector3(long.z, 0.0, long.x)
			if absf(f.dot(long)) > 0.5:
				x_axis = f # the gable end with the shutter faces the field
				z_axis = across
			else:
				x_axis = long
				z_axis = f # the long side with the windows and door faces it
			height += minf(p.width, p.depth) * cfg.roof_rise
		&"crane":
			var ahead := signf(toward.x if long.x != 0.0 else toward.y)
			x_axis = long * (ahead if ahead != 0.0 else 1.0)
			z_axis = x_axis.cross(Vector3.UP)
		&"watchTower", &"waterTower":
			var face := SkylineShapes.facing(toward)
			z_axis = Vector3(face.x, 0.0, face.y)
			x_axis = Vector3.UP.cross(z_axis)
	var size := Vector3(_extent(x_axis, p), height, _extent(z_axis, p))
	return [_fit(best_of(cfg.models_of(p.kind), size), foot, x_axis, z_axis, size, p.kind in cfg.keep_depth, body)]


## Of `meshes`, the one whose box stretches most evenly to `size` (the least stretch_of), so a shed's doors and windows
## keep their size; the first when they tie.
static func best_of(meshes: Array[Mesh], size: Vector3) -> Mesh:
	var best: Mesh = meshes[0]
	var least := INF
	for mesh in meshes:
		var spread := stretch_of(mesh, size)
		if spread < least - 1e-6:
			least = spread
			best = mesh
	return best


## How unevenly `mesh`'s box stretches to `size`: the largest scale over the smallest (1 is even).
static func stretch_of(mesh: Mesh, size: Vector3) -> float:
	var scale := size / mesh.get_aabb().size.max(Vector3.ONE * 1e-3)
	return maxf(scale.x, maxf(scale.y, scale.z)) / maxf(minf(scale.x, minf(scale.y, scale.z)), 1e-6)


## The colour `p`'s BODY faces take: the map file's, else its kind's.
static func body_of(p: SkylinePiece, cfg: SkylineConfig) -> Color:
	match p.kind:
		&"shed":
			return p.colour_or(cfg.shed_colour)
		&"crane":
			return p.colour_or(cfg.crane_colour)
		&"mast":
			return p.colour_or(cfg.mast_colour)
		&"fuselage":
			return p.colour_or(cfg.fuselage_colour)
		&"silo":
			return p.colour_or(cfg.silo_colour)
		&"watchTower":
			return p.colour_or(cfg.watch_colour)
		&"waterTower":
			return p.colour_or(cfg.tank_colour)
	return p.colour


## Adds `placed`'s triangles to the arrays: each corner moved into the world, its normal turned with it, its colour the
## model's (BODY's the piece's times its shade) faded toward `far` (linear) by its distance from `middle`, written sRGB.
## With `lamps_apart`, the lamps' glass goes to `lamp_pos`, `lamp_nor` and `lamp_col` instead.
static func add(placed: Placed, cfg: SkylineConfig, far: Color, middle: Vector2, lamps_apart: bool,
		pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray, lamp_pos: PackedVector3Array,
		lamp_nor: PackedVector3Array, lamp_col: PackedColorArray) -> void:
	var arrays := placed.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if index.is_empty():
		index.resize(verts.size())
		for i in verts.size():
			index[i] = i
	var turn := placed.at.basis.inverse().transposed()
	var flip := placed.at.basis.determinant() < 0.0
	var body := placed.body.srgb_to_linear()
	var order := PackedInt32Array([0, 2, 1]) if flip else PackedInt32Array([0, 1, 2])
	for t in range(0, index.size() - 2, 3):
		var lamp := lamps_apart and _is_lamp(colours[index[t]].a)
		var to_pos := lamp_pos if lamp else pos
		var to_nor := lamp_nor if lamp else nor
		var to_col := lamp_col if lamp else col
		for k in order:
			var v := index[t + k]
			var q := placed.at * verts[v]
			to_pos.append(q)
			to_nor.append((turn * normals[v]).normalized())
			var c := colours[v]
			var own := Color(body.r * c.r, body.g * c.g, body.b * c.b) if c.a < BODY_BELOW else Color(c.r, c.g, c.b)
			var d := Vector2(q.x, q.z).distance_to(middle)
			var fade := clampf((d - cfg.fade_from) / cfg.fade_span, 0.0, 1.0) * cfg.fade_most
			to_col.append(own.lerp(far, fade).linear_to_srgb())


## The model stood at `foot` (its base's middle) with its own x along `x_axis` and z along `z_axis`, its box stretched
## to `size` (along its x, up, along its z); with `keep_depth`, its depth scaled as its length and height are instead
## (never past `size`).
static func _fit(mesh: Mesh, foot: Vector3, x_axis: Vector3, z_axis: Vector3, size: Vector3, keep_depth: bool,
		body: Color) -> Placed:
	var box := mesh.get_aabb()
	var own := box.size.max(Vector3.ONE * 1e-3)
	var scale := size / own
	if keep_depth:
		scale.z = minf(scale.z, sqrt(scale.x * scale.y))
	var anchor := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var placed := Placed.new()
	placed.mesh = mesh
	placed.at = Transform3D(Basis(x_axis * scale.x, Vector3.UP * scale.y, z_axis * scale.z), foot) \
			* Transform3D(Basis.IDENTITY, -anchor)
	placed.body = body
	return placed


## A treeline's band (SkylineConfig.treeline_model): along each run of its points, whole sections end to end, each
## stretched to an even share of the run, as deep as the piece and as tall as it from `treeline_sink` m under the
## ground (as the cones are sunk, so none floats on lower ground), every other one mirrored, each a seeded one of
## `treeline_colours` (the same every build). None without the model: the cones stand.
static func _band(p: SkylinePiece, cfg: SkylineConfig) -> Array[Placed]:
	var out: Array[Placed] = []
	var mesh := cfg.treeline_mesh()
	if mesh == null:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p.points)
	var depth := p.depth if p.depth > 0.0 else cfg.treeline_section.y
	var up := (p.height + cfg.treeline_sink) / maxf(mesh.get_aabb().end.y, 1e-3)
	var flip := 1.0
	for i in p.points.size() - 1:
		var a := p.points[i]
		var b := p.points[i + 1]
		var run := b - a
		var n := maxi(1, roundi(run.length() / cfg.treeline_section.x))
		var along := Vector3(run.x, 0.0, run.y).normalized()
		var across := along.cross(Vector3.UP)
		var long := run.length() / n / cfg.treeline_section.x
		for k in n:
			var at := a.lerp(b, (k + 0.5) / n)
			var one := Placed.new()
			one.mesh = mesh
			one.at = Transform3D(Basis(along * long * flip, Vector3.UP * up, across * depth / cfg.treeline_section.y),
					Vector3(at.x, -cfg.treeline_sink, at.y))
			one.body = p.colour_or(cfg.treeline_colours[rng.randi() % cfg.treeline_colours.size()])
			out.append(one)
			flip = -flip
	return out


## How far `p` reaches along the level axis `axis` (+-x or +-z), m.
static func _extent(axis: Vector3, p: SkylinePiece) -> float:
	return absf(axis.x) * p.width + absf(axis.z) * p.depth


static func _is_lamp(alpha: float) -> bool:
	return alpha >= BODY_BELOW and alpha < FIXED_FROM

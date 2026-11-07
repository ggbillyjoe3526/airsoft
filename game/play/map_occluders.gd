class_name MapOccluders
extends OccluderInstance3D
## The map's tall solid blocks as one occluder for the renderer's occlusion culling (Settings › Graphics › Occlusion
## culling, BP7): each block of MapStyle.occluder_kinds that is no ramp, names no prop and is tall and long enough, as
## its box inset from every face, all in one ArrayOccluder3D. With the row on, the root viewport leaves out every
## instance they hide from the eye (a bot's figure and its replicas behind a wall, the props behind it); with it off,
## the occluder is never rasterised and costs nothing. Built once a match; look only, nothing the simulation reads.

## A box's eight corners (bits x, y, z: 0 low, 1 high) and its twelve triangles, two a face, each face's turned
## outward.
const CORNERS := 8
const TRIANGLES: Array[int] = [
	0, 1, 3, 0, 3, 2, # -x
	4, 6, 7, 4, 7, 5, # +x
	0, 4, 5, 0, 5, 1, # -y
	2, 3, 7, 2, 7, 6, # +y
	0, 2, 6, 0, 6, 4, # -z
	1, 5, 7, 1, 7, 3, # +z
]

## The boxes it holds, for tests and the frame-cost check.
var boxes: int = 0


## `map`'s occluder by `style`'s rules, or null when no block is one.
static func build(map: MapData, style: MapStyle) -> MapOccluders:
	var points := PackedVector3Array()
	var indices := PackedInt32Array()
	var n := 0
	for b in map.blocks:
		if not is_occluder(b, style):
			continue
		var half := b.size * 0.5 - Vector3.ONE * style.occluder_inset
		var first := points.size()
		for c in CORNERS:
			points.append(b.center + Vector3(half.x if c & 4 else -half.x, half.y if c & 2 else -half.y,
					half.z if c & 1 else -half.z))
		for i in TRIANGLES:
			indices.append(first + i)
		n += 1
	if n == 0:
		return null
	var shape := ArrayOccluder3D.new()
	shape.set_arrays(points, indices)
	var view := MapOccluders.new()
	view.name = "Occluders"
	view.occluder = shape
	view.boxes = n
	return view


## Whether block `b` hides what is behind it from the renderer, by `style`'s rules.
static func is_occluder(b: MapData.Block, style: MapStyle) -> bool:
	if b.rise != MapData.Rise.NONE or not b.dress.is_empty() or not style.occluder_kinds.has(b.kind):
		return false
	var inset := style.occluder_inset * 2.0
	return b.size.y >= style.occluder_height and maxf(b.size.x, b.size.z) >= style.occluder_length \
			and minf(b.size.x, b.size.z) > inset

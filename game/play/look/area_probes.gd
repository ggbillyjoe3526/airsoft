class_name AreaProbes
extends Node3D
## A map's reflection probes (docs/ART.md › Light; Graphics › Reflections): one over the whole field, then one per
## named area (MapData.areas) of at least LookConfig.probe_area m², the largest first, up to probe_most in all. Each is
## box-projected over its area from eye height and captured once at the start (UPDATE_ONCE), so a shiny surface
## reflects the hall it stands in, not the sky; on a roofed field they are interiors and reach the roof. On sloping
## ground (MapData.terrain) each box stands on the ground under it, from its lowest corner to `height` over its
## highest, and captures from eye height over the ground at its middle, never from inside a hill (BP2) nor a prop (BP9:
## from the nearest spot with LookConfig.probe_clearance m of room round it where a block stands there); each of its
## views reaches at least `probe_reach` m, so none stops in the hill or the trees close round it (GL1). Nothing per
## frame. FieldLighting shows or hides them all with the Reflections row. A map built in storeys (MT1: Subway) has no
## one floor for a probe over the whole field, so it has none: each area holding its own band of feet heights is an
## interior from its band's floor to its top, captured from eye height over that floor, never from inside a slab. An
## interior probe (a roofed field's, a storey's) gives reflections alone, no ambient light, while the field's ambient
## fills the hall (BP9). A probe's ambient is its own picture of its hall, darker than the field's ambient in every
## picture taken indoors, and it fades in over `probe_margin` from each face of its box: Depot's Lounge drew its
## lockers lit at the foot and fading to black above, and in a box one storey tall the probe's light peaked at chest
## height and drew a dark band along every wall of Subway. The field's ambient lights a hall evenly. Under the scene's
## bounce light (`set_bounce`: Ultra) there is no such ambient: the probe's own is light the shade would not have, so
## an interior keeps it there (without it Depot's Lounge drew its lockers' tops and top shelves black on Ultra). A
## probe open to the sky always keeps its ambient.

## The visual layer the probes sit on, which a scope's glass camera (OpticGlass) leaves out: while that second camera
## saw them, the field's own reflections broke up into patches on the floor round a scope at the hip (BP8, seen in
## tools/render_replica_view.gd's pictures). It sets only which cameras see a probe, not what it captures or lights.
const LAYER := 1 << 18

## The interior probes, and whether the scene's bounce light is on (`set_bounce`).
var _interiors: Array[ReflectionProbe] = []
var _bounce: bool = false


## The interior probes' ambient light: on while the scene's bounce light is the hall's fill (`bounce`: Global
## illumination Scene), off while the field's ambient is. Only a change is set; never per frame.
func set_bounce(bounce: bool) -> void:
	if bounce == _bounce:
		return
	_bounce = bounce
	var mode := ReflectionProbe.AMBIENT_ENVIRONMENT if bounce else ReflectionProbe.AMBIENT_DISABLED
	for probe in _interiors:
		probe.ambient_mode = mode


## The probes for `map` in `look`, or null for a map with no blocks.
static func build(map: MapData, look: LookConfig) -> AreaProbes:
	var whole := map.footprint()
	if whole.size == Vector2.ZERO:
		return null
	var probes := AreaProbes.new()
	probes.name = "ReflectionProbes"
	# hidden until the Reflections row shows them, so Low never captures them at all
	probes.visible = false
	var height := map.roof_height if map.roof_height > 0.0 else look.probe_height
	var interior := map.roof_height > 0.0
	var solids := solids_of(map)
	if map.storeys.is_empty():
		probes._add(whole, height, interior, look, "Field", map.terrain, solids)
	for a in probed_areas(map, look):
		if probes.get_child_count() >= look.probe_most:
			break
		probes._add(_plan(a), height, interior, look, "Area", map.terrain, solids, Vector2(a.floor_from, a.floor_to))
	return probes


## Every block's box on `map`: the walls, props and slabs no probe captures from inside.
static func solids_of(map: MapData) -> Array[AABB]:
	var out: Array[AABB] = []
	for b in map.blocks:
		out.append(AABB(b.center - b.size * 0.5, b.size))
	return out


## Where a probe over `box` captures from: eye height (LookConfig.probe_eye) over the ground at its middle (`floor_y`
## with no `terrain`), or, where a block stands within `look.probe_clearance` m of that, the nearest spot in the box
## with that much room round it, on rings that far apart outward from the middle (BP9), standing on ground within
## `span` (the probe's floor and top) so the box still reaches down to it. The middle when no spot in the box is clear.
static func capture_spot(box: Rect2, span: Vector2, look: LookConfig, terrain: TerrainGrid, floor_y: float,
		solids: Array[AABB]) -> Vector3:
	var room := look.probe_clearance
	var plan := box.grow(room)
	var near: Array[AABB] = []
	for s in solids:
		if plan.intersects(Rect2(s.position.x, s.position.z, s.size.x, s.size.z)):
			near.append(s.grow(room))
	var middle := box.get_center()
	var at_middle := Vector3(middle.x, _under(middle, terrain, floor_y) + look.probe_eye, middle.y)
	if room <= 0.0 or _clear(at_middle, near):
		return at_middle
	var rings := ceili(maxf(box.size.x, box.size.y) * 0.5 / room)
	for r in range(1, rings + 1):
		var best := at_middle
		var best_d := INF
		for k in range(-r, r + 1):
			for step: Vector2 in [Vector2(k, -r), Vector2(k, r), Vector2(-r, k), Vector2(r, k)]:
				var d := step.length_squared()
				var spot := middle + step * room
				if d >= best_d or not box.has_point(spot):
					continue
				var ground := _under(spot, terrain, floor_y)
				var eye := Vector3(spot.x, ground + look.probe_eye, spot.y)
				if ground >= span.x and eye.y < span.y and _clear(eye, near):
					best = eye
					best_d = d
		if best_d < INF:
			return best
	return at_middle


## The ground under `spot`: the terrain's, or `floor_y` with none.
static func _under(spot: Vector2, terrain: TerrainGrid, floor_y: float) -> float:
	return _ground(terrain, spot) if terrain != null else floor_y


static func _clear(eye: Vector3, near: Array[AABB]) -> bool:
	for s in near:
		if s.has_point(eye):
			return false
	return true


## The ground's height under `box` (x, z) on `terrain`: x the lowest and y the highest of its corners and middle, z at
## its middle; all 0 with no terrain, and a point off the terrain counts as 0 (flat ground at the field's level).
static func ground_under(box: Rect2, terrain: TerrainGrid) -> Vector3:
	if terrain == null:
		return Vector3.ZERO
	var middle := box.get_center()
	var at_middle := _ground(terrain, middle)
	var lo := at_middle
	var hi := at_middle
	for corner: Vector2 in [box.position, box.position + Vector2(box.size.x, 0.0), box.end,
			box.position + Vector2(0.0, box.size.y)]:
		var h := _ground(terrain, corner)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	return Vector3(lo, hi, at_middle)


static func _ground(terrain: TerrainGrid, at: Vector2) -> float:
	var h := terrain.height_at(at.x, at.y)
	return 0.0 if is_nan(h) else h


## The named areas' boxes (x, z) a probe goes in: those of `look.probe_area` m² or more, the largest first.
static func boxes(map: MapData, look: LookConfig) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for a in probed_areas(map, look):
		out.append(_plan(a))
	return out


## The named areas a probe goes in: those of `look.probe_area` m² or more on the plan, the largest first.
static func probed_areas(map: MapData, look: LookConfig) -> Array[MapAreas.Area]:
	var out: Array[MapAreas.Area] = []
	for a in map.areas:
		if _plan(a).get_area() >= look.probe_area:
			out.append(a)
	out.sort_custom(func(p: MapAreas.Area, q: MapAreas.Area) -> bool:
		return _plan(p).get_area() > _plan(q).get_area())
	return out


static func _plan(a: MapAreas.Area) -> Rect2:
	return Rect2(a.x0, a.z0, a.x1 - a.x0, a.z1 - a.z0).abs()


## A probe over `box`, capturing from `capture_spot` clear of `solids`; with a finite `band` (an area's feet heights,
## x from and y to) it spans that band, from its floor up to its top (`height` over its floor without one), and is an
## interior. An interior gives reflections alone until `set_bounce` says the scene's bounce light is on.
func _add(box: Rect2, height: float, interior: bool, look: LookConfig, kind: String, terrain: TerrainGrid,
		solids: Array[AABB], band: Vector2 = Vector2(-INF, INF)) -> void:
	var probe := ReflectionProbe.new()
	probe.name = "%s%d" % [kind, get_child_count()]
	var middle := box.get_center()
	var ground := ground_under(box, terrain)
	var tall := ground.y - ground.x + height
	if is_finite(band.x):
		var top := band.y if is_finite(band.y) else band.x + height
		ground = Vector3(band.x, band.x, band.x)
		tall = maxf(top - band.x, look.probe_eye * 2.0)
		interior = true
		terrain = null
	var centre_y := ground.x + tall * 0.5
	probe.position = Vector3(middle.x, centre_y, middle.y)
	probe.size = Vector3(box.size.x + look.probe_margin * 2.0, tall, box.size.y + look.probe_margin * 2.0)
	var eye := capture_spot(box, Vector2(ground.x, ground.x + tall), look, terrain, ground.z, solids)
	probe.origin_offset = eye - probe.position
	probe.max_distance = look.probe_reach
	probe.box_projection = true
	probe.interior = interior
	if interior:
		probe.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT if _bounce else ReflectionProbe.AMBIENT_DISABLED
		_interiors.append(probe)
	probe.blend_distance = look.probe_margin
	probe.intensity = look.probe_intensity
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.layers = LAYER
	add_child(probe)

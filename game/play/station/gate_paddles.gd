class_name GatePaddles
extends Node3D
## A station's ticket gates' paddle doors (SM3, the owner: a paddle each side of a lane, one person wide): every two
## gates standing a lane apart (GatePaddlesConfig.gate_model's blocks, side by side across their facing) get a paddle
## each on the lane's side, hinged at the gate's middle, shut across the lane. While anyone stands near the lane's
## middle its two paddles swing a quarter turn open towards the gates' facing over GatePaddlesConfig.swing_time, and
## shut again once nobody does. One MultiMesh in the props' vertex-coloured material, in the baked light near each
## post while a bake is drawn (`relight`). Look only: no collider, no nav cell, never read by the simulation; the lane
## is the open space between two boxes. Built once; a frame allocates nothing.

## A paddle takes the baked light this far (m) over its post's foot: its blade's middle.
const LIGHT_LIFT := 0.9

var _cfg: GatePaddlesConfig = null
var _view: MultiMeshInstance3D = null
var _material: ShaderMaterial = null
## Per paddle: its post (world, on the floor), its blade's stretch along +x, its turn shut and open (rad about up, its
## +x across the lane or along the gate), its lane's middle and how open it is drawn (0 shut .. 1 open).
var _posts: PackedVector3Array = PackedVector3Array()
var _stretch: PackedFloat32Array = PackedFloat32Array()
var _shut_turn: PackedFloat32Array = PackedFloat32Array()
var _open_turn: PackedFloat32Array = PackedFloat32Array()
var _lanes: PackedVector3Array = PackedVector3Array()
var _open: PackedFloat32Array = PackedFloat32Array()
## Each paddle's transform as drawn.
var _drawn: Array[Transform3D] = []


## The paddles of `map`'s ticket gates, or null when it has no two gates a lane apart or the paddle won't load.
static func build(map: MapData, cfg: GatePaddlesConfig) -> GatePaddles:
	if map == null or cfg == null:
		return null
	var gates: Array[MapData.Block] = []
	for b in map.blocks:
		if b.dress == cfg.gate_model and b.facing != &"":
			gates.append(b)
	if gates.size() < 2:
		return null
	var mesh := PropDressConfig.load_mesh(cfg.paddle_path)
	if mesh == null:
		push_warning("GatePaddles: the paddle %s won't load; the gates stand open" % cfg.paddle_path)
		return null
	var reach_x := maxf(mesh.get_aabb().end.x, 1e-3)
	var g := GatePaddles.new()
	g.name = "GatePaddles"
	g._cfg = cfg
	for a in gates:
		for b in gates:
			g._pair(a, b, reach_x, map.blocks)
	if g._posts.is_empty():
		g.free()
		return null
	g._open.resize(g._posts.size())
	g._open.fill(0.0)
	g._drawn.resize(g._posts.size())
	g._material = LookMaterials.vertex_colour(cfg.roughness, 0.0, Color.WHITE, false, cfg.wear)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = g._posts.size()
	g._view = MultiMeshInstance3D.new()
	g._view.multimesh = mm
	g._view.material_override = g._material
	g.add_child(g._view)
	for i in g._posts.size():
		mm.set_instance_color(i, Color.WHITE)
		g._place(i)
	return g


## Gate `a`'s paddle into the lane between it and gate `b`, when `b` stands a lane away on one side of it across their
## facing with nothing of `blocks` standing in the lane (each pair is met twice, `a` and `b` swapped: one paddle each).
func _pair(a: MapData.Block, b: MapData.Block, reach_x: float, blocks: Array[MapData.Block]) -> void:
	if a == b or a.facing != b.facing:
		return
	var along_x := a.facing == &"+x" or a.facing == &"-x"
	var across := Vector3(0.0, 0.0, 1.0) if along_x else Vector3(1.0, 0.0, 0.0)
	var along := Vector3(1.0, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, 1.0)
	var gap_to := (b.center - a.center).dot(across)
	var half := (a.size.dot(across) + b.size.dot(across)) * 0.5
	var lane := absf(gap_to) - half
	if lane <= 0.0 or lane > _cfg.max_lane or absf((b.center - a.center).dot(along)) > 0.5 * a.size.dot(along) \
			or absf(b.center.y - a.center.y) > 0.5 * a.size.y:
		return
	var side := signf(gap_to)
	var foot := a.center - Vector3(0.0, a.size.y * 0.5, 0.0)
	# the lane's space, a little inside its sides: a column or a wall standing in it makes it no lane
	var middle := a.center + across * side * (a.size.dot(across) + lane) * 0.5
	var space := AABB(middle, Vector3.ZERO).grow(0.01).expand(middle + along * a.size.dot(along) * 0.45) \
			.expand(middle - along * a.size.dot(along) * 0.45).expand(middle + across * lane * 0.45) \
			.expand(middle - across * lane * 0.45)
	for o in blocks:
		if o != a and o != b and AABB(o.center - o.size * 0.5, o.size).intersects(space):
			return
	var post := foot + across * side * (a.size.dot(across) * 0.5 + _cfg.post_off)
	var blade := lane * 0.5 - _cfg.post_off - _cfg.middle_gap * 0.5
	var into := across * side
	var way_in := Basis(Vector3.UP, PropLayout.facing_yaw(a.facing)) * Vector3.BACK # the gate's front, its +z
	_posts.append(post)
	_stretch.append(blade / reach_x)
	_shut_turn.append(_turn_of(into))
	_open_turn.append(_turn_of(way_in))
	_lanes.append(foot + into * (a.size.dot(across) * 0.5 + lane * 0.5))


## The turn about up that points a model's +x along `dir` (level).
static func _turn_of(dir: Vector3) -> float:
	return atan2(-dir.z, dir.x)


## Swings each lane's paddles open while one of `characters` stands near its middle, shut while none does, over
## `delta` seconds.
func refresh(characters: Array[Character], delta: float) -> void:
	var step := delta / maxf(_cfg.swing_time, 1e-3)
	for i in _posts.size():
		var want := 1.0 if _someone_near(_lanes[i], characters) else 0.0
		var now := move_toward(_open[i], want, step)
		if now != _open[i]:
			_open[i] = now
			_place(i)


func _someone_near(lane: Vector3, characters: Array[Character]) -> bool:
	var r2 := _cfg.reach * _cfg.reach
	for c in characters:
		var d := c.position - lane
		if absf(d.y) <= _cfg.reach_height and d.x * d.x + d.z * d.z <= r2:
			return true
	return false


func _place(i: int) -> void:
	var t := smoothstep(0.0, 1.0, _open[i])
	var turn := lerp_angle(_shut_turn[i], _open_turn[i], t)
	var basis := Basis(Vector3.UP, turn) * Basis.from_scale(Vector3(_stretch[i], 1.0, 1.0))
	_drawn[i] = Transform3D(basis, _posts[i])
	_view.multimesh.set_instance_transform(i, _drawn[i])


## Draws each paddle in the baked light near its post, or in the shared light alone with `lights` null.
func relight(lights: BakedLightNear) -> void:
	for i in _posts.size():
		var l := lights.at(_posts[i] + Vector3(0.0, LIGHT_LIFT, 0.0)) if lights != null else Color.WHITE
		_view.multimesh.set_instance_color(i, Color(l.r, l.g, l.b))


## The paddles' count, and how open paddle `i` is drawn (0 shut .. 1 open) and where (its transform).
func count() -> int:
	return _posts.size()


func open_of(i: int) -> float:
	return _open[i]


func paddle_at(i: int) -> Transform3D:
	return _drawn[i]


## Paddle `i`'s lane's middle (on its floor).
func lane_of(i: int) -> Vector3:
	return _lanes[i]


## The material drawn, to warm its shader before play.
func materials() -> Array[Material]:
	return [_material] as Array[Material]

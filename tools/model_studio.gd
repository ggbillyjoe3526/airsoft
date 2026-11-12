extends SceneTree
## Studio pictures of a replica, a part or any other model file, for review against photos (MQ1): the model alone on a
## plain grey ground, painted as the game paints it (ReplicaPaint), lit as the menus' pictures are (a sun, the
## ambient colour and the studio the metal reflects, StudioSky) with a fill, flat on (no perspective) from the view each shot names. Each shot is saved as `<folder>/<name>.png`.
## Needs a display, so under xvfb:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . -s res://tools/model_studio.gd \
##       -- <folder> <name>|<res path>|<node or ->|<paint or ->|<yaw>,<pitch>[|<x>,<y>,<z>,<span m>][|<parts>] ...
## `node` draws one top-level node of the file alone (a part of a parts file); `paint` is a ReplicaSchemes paint, `-`
## the replica's own colours, a name ending in `!` the Realistic colours' version, and one ending in `~` the flat paint
## a figure's copy wears (no surfaces, no wear). `yaw` 0 looks at the model's
## right side (the muzzle to the picture's right... of a replica whose bore runs along -Z), 180 its left; `pitch` looks
## down. The optional box centres the picture on a point of the model (m) and shows `span` metres across. `parts`
## (`optic=000025+laser=000005`, pool keys by slot) fits parts to a replica as a match does. Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
const MARGIN := 1.08
const CAMERA_DISTANCE := 2.0
const GROUND := Color(0.20, 0.205, 0.215)
const AMBIENT := Color("c8d4ea")
const SUN_ANGLE := Vector2(-48.0, 38.0)
const SUN_ENERGY := 0.95
const FILL_ANGLE := Vector2(-18.0, -130.0)
const FILL_ENERGY := 0.25
const AMBIENT_ENERGY := 0.45
const HIDDEN_SUFFIX := "_Figure"
const HIDDEN_PREFIX := "Figure"
const REALISTIC_MARK := "!"
const FLAT_MARK := "~"
const OWN_MARK := "-"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("model_studio: name a folder and at least one shot after --")
		quit(1)
		return
	var out := args[0].trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(out)
	var port := SubViewport.new()
	port.size = SIZE
	port.msaa_3d = Viewport.MSAA_4X
	port.own_world_3d = true
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(port)
	port.add_child(_environment())
	port.add_child(_light(SUN_ANGLE, SUN_ENERGY, true))
	port.add_child(_light(FILL_ANGLE, FILL_ENERGY, false))
	var failed := 0
	for n in range(1, args.size()):
		failed += await _shot(port, args[n].split("|"), out)
	port.queue_free()
	quit(1 if failed > 0 else 0)


func _shot(port: SubViewport, f: PackedStringArray, out: String) -> int:
	if f.size() < 5:
		push_error("model_studio: a shot is name|file|node|paint|yaw,pitch[|x,y,z,span][|parts]: %s" % "|".join(f))
		return 1
	var scene := load(f[1]) as PackedScene
	if scene == null:
		push_error("model_studio: no model at %s" % f[1])
		return 1
	var model := scene.instantiate() as Node3D
	var stage := Node3D.new()
	port.add_child(stage)
	if f[2] != "-":
		var part := model.get_node_or_null(f[2]) as Node3D
		if part == null:
			push_error("model_studio: no %s in %s" % [f[2], f[1]])
			model.free()
			stage.free()
			return 1
		model.remove_child(part)
		model.free()
		model = part
		model.transform = Transform3D.IDENTITY
	stage.add_child(model)
	for node: Node in model.find_children("*", "Node3D", true, false):
		var hide := String(node.name).ends_with(HIDDEN_SUFFIX) or String(node.name).begins_with(HIDDEN_PREFIX)
		if hide:
			(node as Node3D).visible = false
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null:
		anim.stop()
	if f.size() > 6 and f[6] != "" and f[6] != "-":
		var parts: Dictionary = {}
		for pair: String in f[6].split("+"):
			var kv := pair.split("=")
			parts[StringName(kv[0])] = StringName(kv[1])
		ReplicaParts.fit(model, StringName(f[1].get_file().get_basename()), parts)
	var paint := f[3]
	var flat := paint.ends_with(FLAT_MARK)
	paint = paint.trim_suffix(FLAT_MARK)
	var realistic := paint.ends_with(REALISTIC_MARK)
	paint = paint.trim_suffix(REALISTIC_MARK)
	ReplicaPaint.apply(model, ReplicaSchemes.OWN if paint == OWN_MARK else StringName(paint), realistic, not flat)
	var angles := f[4].split_floats(",")
	var box := _bounds(model)
	var centre := box.get_center()
	var span := 0.0
	if f.size() > 5 and f[5] != "" and f[5] != "-":
		var at := f[5].split_floats(",")
		centre = Vector3(at[0], at[1], at[2])
		span = at[3]
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 40.0
	var grey := StandardMaterial3D.new()
	grey.albedo_color = GROUND
	grey.roughness = 0.95
	plane.material = grey
	ground.mesh = plane
	ground.position = Vector3(centre.x, box.position.y - 0.0005, centre.z)
	stage.add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	var basis := Basis.from_euler(Vector3(deg_to_rad(-angles[1]), deg_to_rad(angles[0] + 90.0), 0.0))
	camera.global_transform = Transform3D(basis, centre + basis.z * CAMERA_DISTANCE)
	camera.near = 0.05
	camera.far = CAMERA_DISTANCE * 3.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = span if span > 0.0 else _fit(box, camera) * MARGIN
	camera.make_current()
	for i in 4:
		await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out, f[0]]
	print("[model_studio] %s" % path)
	var bad := 1 if port.get_texture().get_image().save_png(path) != OK else 0
	stage.free()
	await process_frame
	return bad


## The width (m) a flat camera needs to show all of `box` in SIZE's shape.
func _fit(box: AABB, camera: Camera3D) -> float:
	var inv := camera.global_transform.affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var p := inv * box.get_endpoint(i)
		lo = lo.min(Vector2(p.x, p.y))
		hi = hi.max(Vector2(p.x, p.y))
	var need := hi - lo
	return maxf(need.x, need.y * SIZE.x / SIZE.y)


## The box round every mesh shown under `model`, in the stage's space.
func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.append(model)
	for node: Node in meshes:
		var m := node as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = GROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = AMBIENT_ENERGY
	StudioSky.light(env)
	var node := WorldEnvironment.new()
	node.environment = env
	return node


func _light(angle: Vector2, energy: float, shadows: bool) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(angle.x), deg_to_rad(angle.y), 0.0)
	light.light_energy = energy
	light.shadow_enabled = shadows
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = CAMERA_DISTANCE * 2.0
	light.shadow_bias = 0.03
	light.shadow_normal_bias = 1.0
	light.shadow_blur = 1.5
	return light

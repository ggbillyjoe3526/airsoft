extends GutTest
## BP7, figures and models: the contact shadow on a ramp and off a ledge (row 81), the bolt hand clear of the optics
## (row 18), the zoomed detail only for the figures a scope's glass shows (row 68), and a thrown magazine landing on the
## floor below a ledge (row 99).

var cfg: EffectsConfig = null


## A level that is one slope through the origin, rising `rise` m a metre along x (a ramp), its rays counted.
class SlopeWorld:
	extends WorldQuery
	var rise: float = 0.0
	var rays: int = 0

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		rays += 1
		var n := Vector3(-rise, 1.0, 0.0).normalized()
		var a := n.dot(from)
		var b := n.dot(to)
		if a < 0.0 or b > 0.0:
			return false
		hit.fraction = a / (a - b)
		hit.position = from.lerp(to, hit.fraction)
		hit.normal = n
		hit.surface = RayHit.Surface.CONCRETE
		return true


## A level that is a ledge: the floor at 0 up to x = `edge`, `drop` m lower past it; its rays counted.
class LedgeWorld:
	extends WorldQuery
	var edge: float = 1.0
	var drop: float = 2.0
	var rays: int = 0

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		rays += 1
		var floor_y := 0.0 if from.x < edge else -drop
		if from.y < floor_y or to.y > floor_y:
			return false
		hit.fraction = (from.y - floor_y) / (from.y - to.y) if from.y > to.y else 0.0
		hit.position = from.lerp(to, hit.fraction)
		hit.normal = Vector3.UP
		hit.surface = RayHit.Surface.CONCRETE
		return true


func before_all() -> void:
	cfg = EffectsConfig.new()


func _figure(c: Character, world: WorldQuery) -> FigureView:
	var f := FigureView.new()
	add_child_autofree(f)
	f.setup(c, Color.RED, HitConfig.new(), null)
	f.set_world(world, BodyConfig.new())
	f.add_contact_shadow(FigureView.contact_mesh(cfg), cfg)
	f.set_contact_shadow(true)
	return f


func test_the_contact_shadow_lies_on_a_ramp_tilted_to_it_one_ray_a_tick() -> void:
	var world := SlopeWorld.new()
	world.rise = 0.3
	var c := Character.new(3, 0, Vector3(2.0, 0.6, 0.0), 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	var f := _figure(c, world)
	f.on_tick(c)
	assert_eq(world.rays, 1, "one ray a tick")
	for frame in 3:
		f.update(c, 1.0, 1.0 / 60.0)
	assert_eq(world.rays, 1, "none a frame")
	var disc := f.contact_shadow()
	var normal := Vector3(-0.3, 1.0, 0.0).normalized()
	assert_almost_eq(disc.global_basis.y.normalized().dot(normal), 1.0, 1e-4, "tilted to the ramp")
	# The disc's rim stays on the slope on both sides: its uphill edge does not sink into it.
	for side: float in [-1.0, 1.0]:
		var rim := disc.global_transform * Vector3(side, 0.0, 0.0)
		assert_almost_eq(rim.y - 0.3 * rim.x, cfg.contact_lift / normal.y, 1e-3, "the rim at x %.1f on the ramp" % side)
	assert_eq(f.contact_fade(), 1.0)
	# Between ticks the feet move up the ramp: the disc keeps to it.
	c.prev_position = c.position
	c.position = Vector3(2.4, 0.72, 0.0)
	f.update(c, 0.5, 1.0 / 60.0)
	assert_almost_eq(disc.global_position.y - 0.3 * disc.global_position.x, cfg.contact_lift / normal.y, 1e-3,
			"on the ramp between ticks")


func test_off_a_ledge_the_shadow_lies_on_the_floor_below_and_fades_with_the_drop() -> void:
	# Standing on a ledge's top (y 0, up to x 1), then stepped over its 1 m drop and falling: main kept the disc at
	# the ledge's top, under the feet, so it went (transparency 1) until they landed.
	var world := LedgeWorld.new()
	world.drop = 1.0
	var c := Character.new(3, 0, Vector3(0.5, 0.0, 0.0), 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	var f := _figure(c, world)
	f.on_tick(c)
	f.update(c, 1.0)
	var disc := f.contact_shadow()
	assert_almost_eq(disc.global_position.y, cfg.contact_lift, 1e-4, "on the ledge's top")
	assert_eq(f.contact_fade(), 1.0)
	c.grounded = false
	c.prev_position = Vector3(1.3, -0.4, 0.0)
	c.position = c.prev_position
	f.on_tick(c)
	f.update(c, 1.0)
	assert_almost_eq(disc.global_position.y, -1.0 + cfg.contact_lift, 1e-4, "on the floor below the ledge")
	assert_almost_eq(1.0 - f.contact_fade(), 0.6 / cfg.contact_fade_height, 1e-3, "fading with the 0.6 m over it")
	assert_almost_eq(disc.global_basis.y.normalized(), Vector3.UP, Vector3.ONE * 1e-4, "flat on a flat floor")


func test_no_ray_while_the_disc_or_the_figure_is_hidden() -> void:
	var world := SlopeWorld.new()
	var c := Character.new(3, 0, Vector3(1.0, 0.0, 0.0), 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	var f := _figure(c, world)
	f.set_contact_shadow(false)
	f.on_tick(c)
	assert_eq(world.rays, 0, "the disc hidden (the sun's shadows on)")
	f.set_contact_shadow(true)
	f.visible = false
	f.on_tick(c)
	assert_eq(world.rays, 0, "the figure hidden")


## Row 18, a guard on the shipped arms.glb (it passes on main too: the build's new check, tools/blender/arms/cycle.py,
## found no key into an optic, so the clip didn't change): a rebuilt arms clip that brings the right hand's joints
## (the hand's and each finger's, not its skin) into the box of an optic the Sniper Rifle can fit fails here.
func test_the_hand_working_the_bolt_clears_every_fitted_optic() -> void:
	for optic: StringName in [&"scope2x", &"scopeVar", &"redDot"]:
		var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(&"sniper")]
		var parts: Array[Dictionary] = [{&"optic": optic}]
		var hands := ReplicaView.new()
		add_child_autofree(hands)
		hands.setup(ViewModelConfig.new(), loadout, BoxWorld.new(), [], false, parts)
		hands._show(0)
		var held: ReplicaView.Held = hands._held[0]
		var fitted := held.fit.optic
		assert_not_null(fitted, "%s fitted" % optic)
		if fitted == null:
			continue
		var model := hands._arms._model
		var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var box := _box_of(fitted)
		var bones: Array[int] = []
		for b in skeleton.get_bone_count():
			var bone := skeleton.get_bone_name(b)
			if bone.ends_with("_R") and (bone.begins_with("Hand") or bone.begins_with("Index")
					or bone.begins_with("Middle") or bone.begins_with("Ring") or bone.begins_with("Pinky")
					or bone.begins_with("Thumb")):
				bones.append(b)
		assert_gt(bones.size(), 10, "the right hand's bones")
		anim.play(&"sniper_Fire")
		var length := anim.get_animation(&"sniper_Fire").length
		var worst := INF
		var t := 0.0
		while t <= length:
			anim.seek(t, true)
			skeleton.force_update_all_bone_transforms()
			for b in bones:
				var at := skeleton.global_transform * skeleton.get_bone_global_pose(b).origin
				worst = minf(worst, _outside(box, at))
			t += 1.0 / 60.0
		assert_gt(worst, 0.0, "%s: the hand's joints stay out of its box (nearest %.1f mm)" % [optic, worst * 1000.0])


## Row 68: through a scope only the figures in its glass's cone take the zoomed lines; the rest keep the eye's own, and
## a figure stepping into the cone takes them. Without a glass (a red dot zooming the whole view) every figure does.
func test_only_the_figures_the_glass_shows_take_the_zoomed_detail() -> void:
	var figures_cfg := FigureConfig.new()
	var port := SubViewport.new()
	port.size = Vector2i(256, 256)
	port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(port)
	var glass := Camera3D.new()
	glass.keep_aspect = Camera3D.KEEP_HEIGHT
	port.add_child(glass)
	glass.fov = 4.0
	glass.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.6, 0.0))
	var figures: Array[FigureView] = []
	for at: Vector3 in [Vector3(0.0, 0.0, -60.0), Vector3(25.0, 0.0, -60.0), Vector3(0.0, 0.0, 30.0)]:
		var c := Character.new(figures.size() + 2, 1, at, 0.0, ReplicaStats.default_loadout())
		var f := FigureView.new()
		add_child_autofree(f)
		f.setup(c, Color.BLUE, HitConfig.new(), null)
		f.global_position = at
		figures.append(f)
	var plain := Vector2(20.0, 40.0)
	var zoomed := plain * 6.0
	FigureView.fit_zoomed_lines(figures, glass, zoomed, plain, figures_cfg)
	assert_eq(figures[0].lod_lines(), zoomed, "the figure in the glass")
	assert_eq(figures[1].lod_lines(), plain, "a figure off to the side, hidden by the optic's disc")
	assert_eq(figures[2].lod_lines(), plain, "a figure behind")
	figures[1].global_position = Vector3(1.0, 0.0, -60.0)
	FigureView.fit_zoomed_lines(figures, glass, zoomed, plain, figures_cfg)
	assert_eq(figures[1].lod_lines(), zoomed, "stepping into the glass")
	FigureView.fit_zoomed_lines(figures, null, zoomed, plain, figures_cfg)
	for f in figures:
		assert_eq(f.lod_lines(), zoomed, "no glass: the whole view zoomed")


## Row 99: a magazine thrown off a ledge comes to rest on the floor below it, one ray a throw; one thrown short of the
## edge, or under a table, lands at the feet's height, and without a world every throw lands at the feet as before.
func test_a_magazine_thrown_off_a_ledge_lands_on_the_floor_below() -> void:
	var model := (load("res://assets/models/replicas/aeg.glb") as PackedScene).instantiate()
	var mag := model.find_child(FigureConfig.new().magazine_node, true, false) as MeshInstance3D
	var source := MeshInstance3D.new()
	source.mesh = mag.mesh
	model.free()
	autofree(source)
	var world := LedgeWorld.new()
	# A table's top 0.75 m over the floor past x 1 (a ledge rising): the ray starts under it, so the magazine lands on
	# the floor at the feet's height, not on the top in mid-air.
	var table := LedgeWorld.new()
	table.drop = -0.75
	var cases: Array[Array] = [[Vector3(2.0, 0.0, 0.0), world, -2.0], [Vector3(0.1, 0.0, 0.0), world, 0.0],
			[Vector3(2.0, 0.0, 0.0), table, 0.0], [Vector3(2.0, 0.0, 0.0), null, 0.0]]
	for case in cases:
		var t := ThrownMagazines.new()
		t.setup(2)
		add_child_autofree(t)
		if case[1] != null:
			t.set_world(case[1], FigureConfig.new().thrown_drop, FigureConfig.new().thrown_land_above)
		var query := case[1] as LedgeWorld
		var rays := query.rays if query != null else 0
		assert_true(t.throw(source, Transform3D(Basis.IDENTITY, Vector3(0.6, 1.2, 0.0)), case[0], Vector3(-6.0, -5.2, -0.9),
				0.0, 9.81, 5.0))
		if query != null:
			assert_eq(query.rays - rays, 1, "one ray a throw")
		for i in 180:
			t.update(1.0 / 60.0)
		assert_true(t.landed_at(0), "landed")
		var m := t.thrown_at(0)
		var low := INF
		for i in 8:
			low = minf(low, (m.transform * m.get_aabb().get_endpoint(i)).y)
		assert_almost_eq(low, case[2], 1e-3, "thrown at %s: rests at %.1f m" % [case[0], case[2]])


## Row 68: a figure at the glass's edge keeps the zoomed lines until it is zoom_view_margin past it, and one not zoomed
## takes them only inside the edge, so detail doesn't flip frame to frame as the scope sways.
func test_the_glass_cone_holds_a_figure_at_its_edge() -> void:
	var figures_cfg := FigureConfig.new()
	var port := SubViewport.new()
	port.size = Vector2i(256, 256)
	port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(port)
	var glass := Camera3D.new()
	glass.keep_aspect = Camera3D.KEEP_HEIGHT
	port.add_child(glass)
	glass.fov = 4.0
	glass.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, figures_cfg.zoom_view_height, 0.0))
	var c := Character.new(2, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var f := FigureView.new()
	add_child_autofree(f)
	f.setup(c, Color.BLUE, HitConfig.new(), null)
	var figures: Array[FigureView] = [f]
	var plain := Vector2(20.0, 40.0)
	var zoomed := plain * 6.0
	# The cone's edge at 60 m is 60 tan(corner) off the axis; the ball touches it at that plus its radius.
	var corner := FigureView.view_corner(glass)
	var edge := 60.0 * corner.y / corner.x + figures_cfg.zoom_view_radius
	f.global_position = Vector3(edge - 0.3, 0.0, -60.0)
	FigureView.fit_zoomed_lines(figures, glass, zoomed, plain, figures_cfg)
	assert_eq(f.lod_lines(), zoomed, "just inside the edge")
	f.global_position = Vector3(edge + 0.3, 0.0, -60.0)
	FigureView.fit_zoomed_lines(figures, glass, zoomed, plain, figures_cfg)
	assert_eq(f.lod_lines(), zoomed, "just past the edge, within the margin: kept")
	f.global_position = Vector3(edge + figures_cfg.zoom_view_margin + 0.3, 0.0, -60.0)
	FigureView.fit_zoomed_lines(figures, glass, zoomed, plain, figures_cfg)
	assert_eq(f.lod_lines(), plain, "past the margin: dropped")
	f.global_position = Vector3(edge + 0.3, 0.0, -60.0)
	FigureView.fit_zoomed_lines(figures, glass, zoomed, plain, figures_cfg)
	assert_eq(f.lod_lines(), plain, "back within the margin but past the edge: not taken again yet")


## Row 68: the lines of the figures outside the glass follow the view's target zoom, the same all through a raise, not
## the eased view_zoom (which would set every figure's lines every frame of the 0.2 s raise).
func test_the_view_zoom_target_holds_through_a_raise() -> void:
	var view := ViewConfig.new()
	var sniper := ReplicaStats.load_replica(&"sniper")
	var aeg := ReplicaStats.load_replica(&"aeg")
	for r: ReplicaConfig in [sniper, aeg]:
		var full := FirstPersonView.target_view_zoom(r, view, 1.0)
		assert_eq(FirstPersonView.target_view_zoom(r, view, 0.0), 1.0, "%s lowered" % r.id)
		for aim: float in [0.05, 0.3, 0.7]:
			assert_eq(FirstPersonView.target_view_zoom(r, view, aim), full, "%s at %.2f raised" % [r.id, aim])
		assert_eq(full, maxf(FirstPersonView.aimed_zoom(r, view), 1.0))


## Row 101: the belt holster's skin is weighted as the rigid pistol in it is carried (FigureConfig.holster_follow of the
## right thigh, the rest the hips), all over its foot too, so the two move as one and crouched no speck of the pistol
## shows through the foot (gear.py, BP7; before, its foot took up to 0.35 of the thigh).
func test_the_holster_moves_as_the_pistol_in_it() -> void:
	var follow := FigureConfig.new().holster_follow
	var model := (load("res://assets/models/characters/human.glb") as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	var seat := model.find_child(FigureConfig.new().holster_node, true, false) as Node3D
	var kit := model.find_child("Kit", true, false) as MeshInstance3D
	assert_not_null(seat, "the holster's seat")
	assert_not_null(kit, "the gear's mesh")
	if seat == null or kit == null:
		return
	var skin := kit.skin
	var at := seat.global_position
	var near := 0
	var most := 0.0
	for surface in kit.mesh.get_surface_count():
		var arrays := kit.mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(verts.size(), 1)
		for i in verts.size():
			# The holster's body: under its mouth, within its length, by the hip.
			var p := kit.global_transform * verts[i]
			if p.y > at.y + 0.02 or p.y < at.y - 0.2 or Vector2(p.x - at.x, p.z - at.z).length() > 0.07:
				continue
			near += 1
			for k in per:
				var w := weights[i * per + k]
				if w > 0.0 and skin.get_bind_name(bones[i * per + k]) == &"Thigh_R":
					most = maxf(most, w)
	assert_gt(near, 50, "the holster's points found")
	assert_almost_eq(most, follow, 0.02, "its foot takes the pistol's share of the thigh, no more")


## Row 69 (owner, 2026-11-07: "Glow"): at night a bot's figure carries the weapon torch on each replica it lights,
## its LED glowing as the hands' does. Up close it costs 2 draws a rifle (the lens and the LED; its rubber shares the
## replica's) and 3 a pistol (no rubber of its own), none beyond the far line; the holster draws the replica without
## it, and the beam leaves its lens.
func test_a_bot_figure_carries_its_glowing_night_torch() -> void:
	var torch := Torch.Light.new()
	torch.key = &"weaponTorch"
	var cfg := FigureConfig.new()
	var models := FigureModels.new(cfg)
	models.load_kinds()
	for id: StringName in [&"aeg", &"pistol"]:
		var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(id)]
		var counts: Array[int] = []
		var glows: Array[bool] = []
		var fars: Array[int] = []
		for lit: bool in [false, true]:
			var c := Character.new(4, 1, Vector3.ZERO, 0.0, loadout)
			var lights: Array[Torch.Light] = [torch if lit else null]
			var parts := FigureView.with_lights([] as Array[Dictionary], lights, 1)
			assert_eq(parts[0].has(Pool.LIGHT_SLOT), lit)
			var f := FigureView.new()
			add_child_autofree(f)
			f.setup(c, Color.BLUE, HitConfig.new(), null, false, parts)
			f.set_body(models, FigureMix.HUMAN, cfg.lod_high)
			var held := f._replicas[0]
			assert_not_null(held, "%s held" % id)
			if held == null:
				return
			counts.append(held.mesh.get_surface_count())
			fars.append(f._fars[0].mesh.get_surface_count() if f._fars[0] != null else 0)
			glows.append(_glows(held.mesh))
			assert_eq(f.has_lens(0), lit, "%s: a lens only with the torch" % id)
			if lit:
				# The lens on the rail, ahead of the replica's middle, not on the barrel 0.3 m behind the muzzle.
				var lens := f._lenses[0]
				assert_lt(lens.z, held.get_aabb().get_center().z, "%s: the lens forward" % id)
				assert_almost_eq(f.lens_position(0), held.global_transform * lens, Vector3.ONE * 1e-5)
				# In the holster the replica is drawn without its torch, and with it again in the hand.
				f._body.hands.in_holster = 0
				f._fit_torches()
				assert_eq(held.mesh.get_surface_count(), counts[0], "%s: holstered, no torch" % id)
				assert_false(_glows(held.mesh), "%s: holstered, no glow" % id)
				f._body.hands.in_holster = -1
				f._fit_torches()
				assert_eq(held.mesh.get_surface_count(), counts[1], "%s: in the hand, the torch again" % id)
		gut.p("%s figure held replica draws: %d without the torch, %d with it (far version %d, %d)" % [id, counts[0],
				counts[1], fars[0], fars[1]])
		# The AEG Rifle's own Rubber takes the torch's; the pistol has none, so its torch's rubber is a third draw.
		assert_eq(counts[1] - counts[0], 2 if id == &"aeg" else 3, "%s: the lens and the LED (and rubber)" % id)
		assert_eq(fars[1], fars[0], "%s: no more draws beyond the far line" % id)
		assert_true(glows[1] and not glows[0], "%s: its LED glows" % id)
	var kept: Array[Dictionary] = [{&"optic": &"redDot"}]
	var lit_parts := FigureView.with_lights(kept, [torch] as Array[Torch.Light], 2)
	assert_false(kept[0].has(Pool.LIGHT_SLOT), "the kit's own parts are left alone")
	assert_eq(lit_parts[0], {&"optic": &"redDot", Pool.LIGHT_SLOT: &"weaponTorch"})
	assert_eq(lit_parts[1], {}, "a replica with no light")


static func _glows(mesh: Mesh) -> bool:
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i) as BaseMaterial3D
		if m != null and m.emission_enabled:
			return true
	return false


## Row 17 (owner, 2026-11-07): working the Sniper Rifle's bolt at the hip cants the replica toward the eye (a roll by
## ViewModelConfig bolt_roll at the bolt clip's middle), and none with the sight fully up.
func test_working_the_bolt_at_the_hip_cants_the_rifle_and_aimed_it_does_not() -> void:
	var view := ViewModelConfig.new()
	var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(&"sniper")]
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(view, loadout, BoxWorld.new())
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
	c.grounded = true
	var eye := Vector3(0.0, 1.6, 0.0)
	var rolls: Array[float] = []
	for aim: float in [0.0, 1.0]:
		for i in 3:
			hands.update(c, 0.0, 0.0, eye, Vector3.FORWARD, 1.0 / 60.0, aim)
		var held: ReplicaView.Held = hands._held[0]
		var still := held.root.rotation.z
		hands.on_shot()
		held.anim.seek(held.anim.get_animation(&"Fire").length * 0.5, true)
		hands.update(c, 0.0, 0.0, eye, Vector3.FORWARD, 1.0 / 60.0, aim)
		rolls.append(held.root.rotation.z - still)
		held.anim.stop()
		hands._arms.follow(held.anim, 10.0)
		hands._arms.follow(held.anim, 1.0 / 60.0)
	assert_gt(rolls[0], 0.5 * view.bolt_roll * sin(PI * 0.25), "at the hip, mid-cycle: canted toward the eye")
	assert_almost_eq(rolls[1], 0.0, 1e-3, "aimed: no cant")


## Row 55 (owner, 2026-11-07): through a shot's hold a figure firing at a wall still lifts its replica a little, never
## past FigureConfig.raise_fire_most (before BP7 the hold kept it level: none).
func test_firing_at_cover_lifts_the_replica_a_little_through_the_hold() -> void:
	var cfg := FigureConfig.new()
	var models := FigureModels.new(cfg)
	models.load_kinds()
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	var world := BoxWorld.new(BodyConfig.new())
	world.add_box(Vector3(0.0, 1.5, -0.6), Vector3(4.0, 3.0, 0.2))
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, HitConfig.new(), null)
	v.set_body(models, FigureMix.HUMAN, cfg.lod_high)
	v.set_world(world, BodyConfig.new())
	var most := 0.0
	for i in 40:
		v.on_shot()
		v.update(c, 1.0)
		v.animate(c, 1.0, 1.0 / 60.0, Vector3(0.0, 1.6, 5.0))
		most = maxf(most, v._pose.raise_target)
	assert_gt(most, 0.0, "lifted near the wall while firing")
	assert_lte(most, cfg.raise_fire_most + 1e-6, "never past raise_fire_most while a shot holds it")


## Row 15 (owner, 2026-11-07): with the arm up, the hit call and the walk off turn the left collarbone (Shoulder_L) a
## further 14 degrees about the figure's forward (gait/call.py SHRUG), so the raised shoulder's skin folds less by the
## helmet. Measured from Idle's key at each clip's middle: on main (5004551) HitCall held it 11.9 degrees off and WalkOff
## 12.0 (this test fails there); now 18.3 and 18.1, about 14 past main's call pose, on both kinds.
func test_the_hit_call_turns_the_left_collarbone() -> void:
	for path: String in ["res://assets/models/characters/human.glb", "res://assets/models/characters/robot.glb"]:
		var model := (load(path) as PackedScene).instantiate()
		var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var bone_path := NodePath("%s:Shoulder_L" % anim.get_node(anim.root_node).get_path_to(skeleton))
		var idle_clip := anim.get_animation(&"Idle")
		var idle_track := idle_clip.find_track(bone_path, Animation.TYPE_ROTATION_3D)
		var idle := skeleton.get_bone_rest(skeleton.find_bone(&"Shoulder_L")).basis.get_rotation_quaternion()
		if idle_track >= 0:
			idle = idle_clip.rotation_track_interpolate(idle_track, 0.0)
		for clip_name: StringName in [&"HitCall", &"WalkOff"]:
			var clip := anim.get_animation(clip_name)
			var track := clip.find_track(bone_path, Animation.TYPE_ROTATION_3D)
			assert_gt(track, -1, "%s: %s keys Shoulder_L" % [path, clip_name])
			if track < 0:
				continue
			var held := clip.rotation_track_interpolate(track, clip.length * 0.5)
			var turn := rad_to_deg((idle.inverse() * held).get_angle())
			gut.p("%s: %s holds Shoulder_L %.1f deg from Idle at its middle" % [path, clip_name, turn])
			assert_almost_eq(turn, 18.3, 1.0, "%s: %s's collarbone 14 degrees past main's 12.0" % [path, clip_name])
		model.free()


## The world box round every mesh at and under `node`.
static func _box_of(node: Node3D) -> AABB:
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	var box := AABB()
	for i in meshes.size():
		var mi := meshes[i] as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if i == 0 else box.merge(b)
	return box


## How far `p` is outside `box` (m; negative inside, by its depth to the nearest face).
static func _outside(box: AABB, p: Vector3) -> float:
	var lo := box.position - p
	var hi := p - box.end
	var out := Vector3(maxf(lo.x, hi.x), maxf(lo.y, hi.y), maxf(lo.z, hi.z))
	if out.x > 0.0 or out.y > 0.0 or out.z > 0.0:
		return Vector3(maxf(out.x, 0.0), maxf(out.y, 0.0), maxf(out.z, 0.0)).length()
	return maxf(out.x, maxf(out.y, out.z))

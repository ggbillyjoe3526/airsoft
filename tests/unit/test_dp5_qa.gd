extends GutTest
## DP5, hunted for what the worker's own tests leave open: a contact shadow switched on without a figure update (the
## graphics change from the pause menu, the tree paused), a figure dropping off a ledge, each replica's muzzle kept
## beside its own replica, and the pools allocating nothing after build.

var cfg: EffectsConfig = null


func before_each() -> void:
	cfg = EffectsConfig.new()


func _figure(at: Vector3) -> Array:
	var c := Character.new(3, 0, at, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	var f := FigureView.new()
	add_child_autofree(f)
	f.setup(c, Color.RED, HitConfig.new(), null)
	f.add_contact_shadow(FigureView.contact_mesh(cfg), cfg)
	return [c, f]


func test_a_shadow_switched_on_without_an_update_is_under_the_feet() -> void:
	var made := _figure(Vector3(4.0, 0.5, 6.0))
	var c: Character = made[0]
	var f: FigureView = made[1]
	f.update(c, 1.0)
	f.set_contact_shadow(true)
	# The tree is paused with the pause menu's settings open: no _process, so no update before the next draw.
	var disc := f.contact_shadow()
	var away := Vector2(disc.global_position.x - 4.0, disc.global_position.z - 6.0).length()
	assert_lt(away, 0.1, "not left at the world's origin until the figure next updates")


func test_a_shadow_does_not_float_above_feet_that_drop_below_the_floor_they_stood_on() -> void:
	var made := _figure(Vector3(0.0, 1.2, 0.0))
	var c: Character = made[0]
	var f: FigureView = made[1]
	f.set_contact_shadow(true)
	f.update(c, 1.0)
	c.grounded = false
	c.prev_position = Vector3(0.0, 0.6, 0.0)
	c.position = c.prev_position
	f.update(c, 1.0)
	var disc := f.contact_shadow()
	assert_true(disc.global_position.y <= 0.6 + cfg.contact_lift + 1e-3 or f.contact_fade() < 0.01,
			"walking off a crate: no disc hangs at the crate's top above the falling feet")


func test_each_replicas_muzzle_is_read_from_its_own_model() -> void:
	var made := _figure(Vector3.ZERO)
	var c: Character = made[0]
	var f: FigureView = made[1]
	assert_eq(f._muzzles.size(), c.armament.replicas.size(), "one muzzle a replica, in slot order")
	var pistol := c.armament.replicas.find_custom(func(r: ReplicaConfig) -> bool: return r.id == &"pistol")
	assert_gte(pistol, 0)
	assert_almost_eq(f._muzzles[pistol], Vector3(0.0, 0.0119, -0.1006), Vector3.ONE * 1e-3,
			"the pistol's own (GS2: 1.7 mm proud, 48 % down)")
	for i in f._muzzles.size():
		if i != pistol:
			assert_ne(f._muzzles[i], f._muzzles[pistol], "slot %d is not the pistol's muzzle" % i)


func test_the_pools_allocate_nothing_after_build() -> void:
	var g := GasPuffs.new()
	add_child_autofree(g)
	g.setup(cfg)
	var k := KickedDust.new()
	add_child_autofree(k)
	k.setup(cfg, Color.WHITE, 1.0)
	var eye := Vector3(0.0, 1.6, 0.0)
	for i in 50:
		g.shot(Vector3(0.0, 1.5, -1.0), eye, Vector3.FORWARD, eye)
		k.footfall(GameEvent.Footstep.LAND, Vector3(0.0, 0.0, -3.0), eye)
		g.update(0.02, eye)
		k.update(0.02, eye)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 500:
		g.shot(Vector3(0.0, 1.5, -1.0), eye, Vector3.FORWARD, eye)
		k.footfall(GameEvent.Footstep.SPRINT, Vector3(0.0, 0.0, -3.0), eye)
		g.update(0.02, eye)
		k.update(0.02, eye)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects, "no object a shot or a footfall")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)
	assert_lte(g.live(), cfg.gas_pool)
	assert_lte(k.live(), cfg.kick_pool)


func test_switching_wind_dust_off_mid_flight_hides_the_pool_and_on_again_is_clean() -> void:
	var k := KickedDust.new()
	add_child_autofree(k)
	k.setup(cfg, Color.WHITE, 1.0)
	k.footfall(GameEvent.Footstep.LAND, Vector3(0.0, 0.0, -2.0), Vector3.ZERO)
	k.update(0.05, Vector3.ZERO)
	assert_true(k.visible)
	k.set_on(false)
	assert_false(k.visible, "no draw call")
	assert_eq(k.live(), 0)
	k.set_on(true)
	k.update(0.5, Vector3.ZERO)
	assert_eq(k.live(), 0, "the old dust did not come back")
	assert_false(k.visible)

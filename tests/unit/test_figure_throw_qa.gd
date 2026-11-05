extends GutTest
## GT1 QA: the throw's edge cases on the figure (a rebuilt body, far stride, hidden then shown, readied then thrown,
## wiring order, leaks).

const EYE := Vector3(0.0, 1.6, 3.0)
const FRAME := 1.0 / 60.0

var config: FigureConfig = null
var models: FigureModels = null
var hits: HitConfig = null
var grenades: GrenadeConfig = null
var meshes: Array[Mesh] = []


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()
	hits = HitConfig.new()
	grenades = GrenadeConfig.new()
	for kind in 3:
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.12 + 0.01 * kind, 0.06)
		meshes.append(box)


func _character() -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	c.armament.put_down()
	return c


func _view(c: Character, bombs_first: bool = false) -> FigureView:
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null)
	if bombs_first:
		v.set_bombs(meshes, grenades)
	v.set_body(models, FigureMix.HUMAN, config.lod_high)
	if not bombs_first:
		v.set_bombs(meshes, grenades)
	return v


func _frames(v: FigureView, c: Character, n: int, eye: Vector3 = EYE) -> void:
	for i in n:
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, eye)
	await wait_process_frames(1)


func _windup(c: Character, share: float) -> void:
	c.grenades.stop()
	c.grenades.throwing = Grenade.Kind.SMOKE
	c.grenades.windup_left = grenades.windup * (1.0 - share)
	c.grenades.recover_left = grenades.recover


func test_bombs_given_before_the_body_still_draw_the_bomb() -> void:
	var c := _character()
	_windup(c, 0.5)
	var v := _view(c, true)
	await _frames(v, c, 5)
	assert_true(v.body().hands.bomb().visible)


func test_a_rebuilt_body_keeps_drawing_the_throw() -> void:
	var c := _character()
	_windup(c, 0.5)
	var v := _view(c)
	await _frames(v, c, 5)
	v.set_body(models, FigureMix.ROBOT, config.lod_high)
	await _frames(v, c, 5)
	assert_not_null(v.body().hands.bomb(), "the new body has its bomb node")
	assert_true(v.body().hands.bomb().visible, "and shows it mid-throw")


func test_a_hit_mid_windup_puts_the_bomb_away() -> void:
	var c := _character()
	_windup(c, 0.5)
	var v := _view(c)
	await _frames(v, c, 5)
	c.grenades.stop()
	c.status = Character.Status.CALLING
	await _frames(v, c, 3)
	assert_false(v.body().hands.bomb().visible)
	# Even if the hand state were left (stop is Grenades.step's job), a character out of play shows none.
	_windup(c, 0.5)
	await _frames(v, c, 3)
	assert_false(v.body().hands.bomb().visible)


func test_a_far_figure_still_ends_up_with_the_bomb_shown_then_gone() -> void:
	var c := _character()
	_windup(c, 0.5)
	var v := _view(c)
	var far := Vector3(0.0, 1.6, 200.0)
	await _frames(v, c, 1, far)
	await _frames(v, c, 8, far)
	assert_true(v.body().hands.bomb().visible, "far: the bomb in the hand")
	c.grenades.stop()
	await _frames(v, c, config.far_stride + 1, far)
	assert_false(v.body().hands.bomb().visible, "far: gone a stride after the throw")


func test_hidden_then_shown_mid_throw_shows_the_bomb() -> void:
	var c := _character()
	var v := _view(c)
	await _frames(v, c, 3)
	v.visible = false
	v.animate(c, 1.0, FRAME, EYE)
	_windup(c, 0.5)
	v.visible = true
	await _frames(v, c, 2)
	assert_true(v.body().hands.bomb().visible)


func test_a_readied_bomb_then_a_throw_keeps_one_bomb_of_that_kind() -> void:
	var c := _character()
	c.grenades.readied = Grenade.Kind.FLASH
	var v := _view(c)
	await _frames(v, c, 5)
	assert_eq(v.body().hands.bomb().mesh, meshes[Grenade.Kind.FLASH])
	c.grenades.readied = Grenade.Kind.NONE
	c.grenades.throwing = Grenade.Kind.FLASH
	c.grenades.windup_left = grenades.windup
	await _frames(v, c, 2)
	assert_eq(v.body().hands.bomb().mesh, meshes[Grenade.Kind.FLASH])
	assert_true(v.body().hands.bomb().visible)


func test_set_bombs_again_mid_throw_does_not_strand_a_shown_bomb() -> void:
	var c := _character()
	_windup(c, 0.5)
	var v := _view(c)
	await _frames(v, c, 3)
	v.set_bombs(meshes, grenades)
	c.grenades.stop()
	await _frames(v, c, 3)
	assert_false(v.body().hands.bomb().visible, "no bomb once the throw is over")


func test_throws_and_rebuilds_leave_no_nodes_behind() -> void:
	var c := _character()
	var v := _view(c)
	await _frames(v, c, 3)
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 4:
		_windup(c, 0.5)
		await _frames(v, c, 3)
		v.set_body(models, i % 2, config.lod_high)
		await _frames(v, c, 3)
	await wait_process_frames(2)
	var after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	assert_lte(after, before + 2.0, "a rebuilt body frees the old one with its bomb")


func _pose_reading() -> FigurePose:
	var p := FigurePose.new(config)
	p.grenades = grenades
	return p


func _hand(readied: int, throwing: int, released: bool = false) -> Grenades.Hand:
	var h := Grenades.Hand.new()
	h.readied = readied
	h.throwing = throwing
	h.released = released
	h.windup_left = grenades.windup * 0.5
	h.recover_left = grenades.recover * 0.5
	return h


func test_throw_from_hand_lasts_only_for_that_throw() -> void:
	var p := _pose_reading()
	var h := _hand(Grenade.Kind.SMOKE, Grenade.Kind.NONE)
	p.read_throw(h, true)
	assert_true(p.bomb_held)
	assert_false(p.throw_from_hand)
	h.readied = Grenade.Kind.NONE
	h.throwing = Grenade.Kind.SMOKE
	p.read_throw(h, true)
	assert_true(p.throw_from_hand, "begun from the hand")
	h.released = true
	p.read_throw(h, true)
	assert_true(p.throw_from_hand, "through the recovery too")
	h.throwing = Grenade.Kind.NONE
	p.read_throw(h, true)
	assert_false(p.throw_from_hand, "cleared when the throw ends")
	# A later throw with nothing held first: from weight 0.
	h.throwing = Grenade.Kind.SMOKE
	h.released = false
	p.read_throw(h, true)
	assert_false(p.throw_from_hand)
	assert_eq(FigureThrow.weight(0.0, false, config, p.throw_from_hand), 0.0)


func test_readied_thrown_readied_again_flags_each_throw_correctly() -> void:
	var p := _pose_reading()
	var h := _hand(Grenade.Kind.FLASH, Grenade.Kind.NONE)
	p.read_throw(h, true)
	h.readied = Grenade.Kind.NONE
	h.throwing = Grenade.Kind.FLASH
	p.read_throw(h, true)
	assert_true(p.throw_from_hand)
	h.throwing = Grenade.Kind.NONE
	h.readied = Grenade.Kind.FLASH
	p.read_throw(h, true)
	assert_true(p.bomb_held)
	assert_false(p.throw_from_hand)
	h.readied = Grenade.Kind.NONE
	h.throwing = Grenade.Kind.FLASH
	h.released = false
	p.read_throw(h, true)
	assert_true(p.throw_from_hand, "the second held throw is from the hand again")


func test_a_hit_or_leaving_play_clears_throw_from_hand() -> void:
	var p := _pose_reading()
	var h := _hand(Grenade.Kind.SMOKE, Grenade.Kind.NONE)
	p.read_throw(h, true)
	h.readied = Grenade.Kind.NONE
	h.throwing = Grenade.Kind.SMOKE
	p.read_throw(h, true)
	assert_true(p.throw_from_hand)
	p.read_throw(h, false)
	assert_false(p.throw_from_hand)
	p.read_throw(h, true)
	assert_false(p.throw_from_hand, "the hit throw doesn't resume as from hand")
	p.read_throw(null, true)
	assert_false(p.throw_from_hand)


func test_throw_config_edge_values_give_finite_keys() -> void:
	var edges: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0001, 0.0001, 0.9999),
			Vector3(0.5, 1.0, 1.0)]
	# x: throw_pin_until, y: throw_over_at, z: throw_cock
	for e: Vector3 in edges:
		var c := FigureConfig.new()
		c.throw_pin_until = e.x
		c.throw_over_at = e.y
		c.throw_cock = e.z
		for i in 41:
			var share := i / 20.0
			for held: bool in [false, true]:
				for key: Vector3 in [FigureThrow.right_key(share, held, c), FigureThrow.left_key(share, c),
						FigureThrow.right_pole(share, held, c)]:
					assert_true(is_finite(key.x) and is_finite(key.y) and is_finite(key.z),
							"edge %s share %.2f finite" % [e, share])
			var w := FigureThrow.weight(share, false, c, true)
			assert_true(w >= 0.0 and w <= 1.0)


func test_pin_until_zero_has_the_left_hand_leave_the_pin_at_once() -> void:
	var c := FigureConfig.new()
	c.throw_pin_until = 0.0
	assert_eq(FigureThrow.left_key(0.0, c), c.throw_pin)
	assert_ne(FigureThrow.left_key(0.1, c), c.throw_pin)
	assert_lt(FigureThrow.left_key(c.throw_cock, c).distance_to(c.throw_point), 0.0001)


func test_right_key_is_continuous_across_the_over_key_and_the_release() -> void:
	var prev := FigureThrow.right_key(config.throw_cock, false, config)
	for i in 101:
		var share := config.throw_cock + (1.0 - config.throw_cock) * i / 100.0
		var k := FigureThrow.right_key(share, false, config)
		assert_lt(k.distance_to(prev), 0.06, "no jump at share %.2f" % share)
		prev = k
	assert_eq(FigureThrow.right_key(1.0, false, config), config.throw_release)

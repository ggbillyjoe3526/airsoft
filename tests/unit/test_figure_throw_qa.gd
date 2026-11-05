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

extends GutTest
## LF1 QA: the counted leaves are set once per world however many simulations are made on it, and a world with no
## bushes still builds a simulation.

var tuning: SimTuning = SimTuning.load_default()


func _world() -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 60.0)
	w.add_bush(Vector3.ZERO, 1.0, 1.2)
	return w


func _make(w: BoxWorld) -> Simulation:
	return Simulation.new(tuning, w, w.mover(), [] as Array[MapEnd], -10.0)


func test_two_simulations_on_one_world_do_not_compound_the_shares() -> void:
	var w := _world()
	_make(w)
	var once := w.foliage.depth(Vector3(-5.0, 0.5, 0.0), Vector3(5.0, 0.5, 0.0))
	_make(w)
	var twice := w.foliage.depth(Vector3(-5.0, 0.5, 0.0), Vector3(5.0, 0.5, 0.0))
	assert_gt(once, 0.0, "the leaves still count")
	assert_almost_eq(twice, once, 1e-5, "a second simulation counts the same leaves")
	assert_lt(once, 2.0, "less than the drawn width")


func test_a_world_with_no_bushes_makes_a_simulation() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 60.0)
	assert_not_null(_make(w))
	assert_eq(w.foliage.depth(Vector3(-5.0, 1.0, 0.0), Vector3(5.0, 1.0, 0.0)), 0.0)

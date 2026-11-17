extends GutTest
## LF1 (owner's playtest 2026-11-17: hits on a bot in Woodland's ferns didn't land, Spotted missed it): the leaves the
## simulation counts along a line (BBs, sight, Spotted) fill a smaller ellipsoid than the bush's drawn reach, on the
## same foot (Foliage.count_leaves, BallisticsConfig's leaf shares); walking through it and drawing it keep the whole
## size. The Simulation counts them so for the match.

const FERN_R := 1.0
const FERN_H := 1.2
const BUSH_R := 1.3
const BUSH_H := 1.7

var tuning: SimTuning = SimTuning.load_default()


func _bushes() -> Foliage:
	var f := Foliage.new()
	f.add(Vector3.ZERO, FERN_R, FERN_H)
	f.add(Vector3(20.0, 0.0, 0.0), BUSH_R, BUSH_H)
	return f


func _count(f: Foliage) -> void:
	var b := tuning.ballistics
	f.count_leaves(b.leaf_fern_tallest, b.leaf_fern_shares, b.leaf_bush_shares)


## The leaves crossed by a level line along x at height `y`, `off` m to the side of the bush at `x`.
func _across(f: Foliage, x: float, y: float, off: float = 0.0) -> float:
	return f.depth(Vector3(x - 5.0, y, off), Vector3(x + 5.0, y, off))


func test_drawn_sizes_count_whole_until_counted() -> void:
	var f := _bushes()
	assert_almost_eq(_across(f, 0.0, FERN_H * 0.5), 2.0 * FERN_R, 1e-4, "uncounted: the whole drawn width")


func test_a_fern_counts_its_shares_on_its_foot() -> void:
	var f := _bushes()
	_count(f)
	var s := tuning.ballistics.leaf_fern_shares
	var mid := FERN_H * s.y * 0.5
	assert_almost_eq(_across(f, 0.0, mid), 2.0 * FERN_R * s.x, 1e-4, "its counted width at its middle")
	assert_eq(_across(f, 0.0, FERN_H * s.y + 0.02), 0.0, "nothing over its counted top")
	assert_eq(_across(f, 0.0, mid, FERN_R * s.x + 0.02), 0.0, "nothing past its counted side")


func test_a_shrub_counts_the_bush_shares() -> void:
	var f := _bushes()
	_count(f)
	var s := tuning.ballistics.leaf_bush_shares
	assert_gt(BUSH_H, tuning.ballistics.leaf_fern_tallest, "taller than a fern")
	assert_almost_eq(_across(f, 20.0, BUSH_H * s.y * 0.5), 2.0 * BUSH_R * s.x, 1e-4)


func test_counting_again_starts_from_the_drawn_sizes() -> void:
	var f := _bushes()
	_count(f)
	_count(f)
	var s := tuning.ballistics.leaf_fern_shares
	assert_almost_eq(_across(f, 0.0, FERN_H * s.y * 0.5), 2.0 * FERN_R * s.x, 1e-4, "shares never compound")
	f.count_leaves(tuning.ballistics.leaf_fern_tallest, Vector2.ONE, Vector2.ONE)
	assert_almost_eq(_across(f, 0.0, FERN_H * 0.5), 2.0 * FERN_R, 1e-4, "whole shares: the drawn size again")


func test_first_leaves_meets_the_counted_edge() -> void:
	var f := _bushes()
	_count(f)
	var s := tuning.ballistics.leaf_fern_shares
	var out := Foliage.Crossing.new()
	assert_true(f.first_leaves(Vector3(-5.0, FERN_H * s.y * 0.5, 0.0), Vector3.RIGHT, 10.0, out))
	assert_almost_eq(out.enter, 5.0 - FERN_R * s.x, 1e-4, "a BB meets leaves at the counted edge, not the drawn one")


func test_walking_through_keeps_the_drawn_size() -> void:
	var f := _bushes()
	_count(f)
	assert_true(f.holds(Vector3(FERN_R * 0.9, FERN_H * 0.5, 0.0)), "in the drawn fern: pushing through leaves")
	assert_eq(f.radii[0], FERN_R, "drawn radius kept for BushView")
	assert_almost_eq(f.heights[0], FERN_H, 1e-6, "drawn height kept for BushView")


func test_the_fern_split_is_the_look_s() -> void:
	assert_eq(tuning.ballistics.leaf_fern_tallest, WoodsConfig.new().fern_tallest,
			"the ferns the simulation counts are the ones drawn as ferns")


func test_shares_never_count_more_than_drawn() -> void:
	for s: Vector2 in [tuning.ballistics.leaf_fern_shares, tuning.ballistics.leaf_bush_shares]:
		assert_true(s.x > 0.0 and s.x <= 1.0 and s.y > 0.0 and s.y <= 1.0, "%s within the drawn plant" % s)


## The playtest's case: someone crouched in the middle of a fern, seen from 15 m. Before LF1 the whole drawn fern hid
## their chest (a BB stopped short of it, Spotted found nobody); now it shows through the fronds and a BB gets to it.
func test_the_simulation_counts_the_leaves_and_a_chest_in_a_fern_shows() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 60.0)
	w.add_bush(Vector3.ZERO, FERN_R, FERN_H)
	var chest := Vector3(0.0, Hitbox.hit_top(1.0, tuning.hits) * BotConfig.new().aim_height_fraction, 0.0)
	var eye := Vector3(-15.0, 1.6, 0.0)
	var stop := tuning.ballistics.leaf_stop_depth
	assert_gt(w.foliage.depth(eye, chest), stop, "drawn sizes: the chest hidden")
	var sim := Simulation.new(tuning, w, w.mover(), [] as Array[MapEnd], -10.0)
	assert_not_null(sim)
	assert_lt(w.foliage.depth(eye, chest), stop, "counted leaves: the chest shows and a BB reaches it")

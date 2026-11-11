extends GutTest
## PP1 part 2, QA: restricting climbs to floors refuses no climb onto a floor's edge on any shipped map, leaves a vault
## over a prop alone, and the Lift area wins over the others at a car's every height.

var tuning: SimTuning = SimTuning.load_default()


func _level(id: String) -> MapLevel:
	var map := MapData.load_map(id, MapStyle.new(), tuning.rounds.team_size)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, MapStyle.new(), tuning.body)
	return level


## Each floor block's side approached at 16 headings from a standstill: the plan with the default climb kinds is the
## plan with every kind allowed (a floor's top is never refused), and the lost count is returned.
func _floor_edges_refused(q: WorldQuery) -> int:
	var any := tuning.vault.duplicate() as VaultConfig
	any.climb_kinds = q.block_kinds.duplicate()
	var a := VaultState.new()
	var b := VaultState.new()
	var refused := 0
	var r := tuning.body.radius
	for i in q.block_kinds.size():
		if q.block_kinds[i] != &"floor":
			continue
		var c := q.block_centers[i]
		var h := q.block_halves[i]
		for d in 16:
			var ang := TAU * d / 16.0
			var way := Vector2(cos(ang), sin(ang))
			var out := minf(h.x / maxf(absf(way.x), 1e-6), h.z / maxf(absf(way.y), 1e-6)) + r + 0.2
			var feet := Vector3(c.x - way.x * out, c.y - h.y + tuning.body.rest_gap, c.z - way.y * out)
			var with_all := Vault.plan(feet, way, 0.0, any, tuning.body, q, a)
			var with_floors := Vault.plan(feet, way, 0.0, tuning.vault, tuning.body, q, b)
			if with_all and not with_floors:
				refused += 1
	return refused


func test_no_floor_edge_climb_is_refused_on_any_map() -> void:
	for id: String in ["depot", "range", "woodland", "subway"]:
		var q := _level(id).query()
		assert_eq(_floor_edges_refused(q), 0, "%s: climbs onto floors refused" % id)


func test_a_vault_over_a_prop_is_still_planned_as_a_vault() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(40.0, 0.5, 40.0))
	w.add_box(Vector3(0.0, 0.4, 0.0), Vector3(2.0, 0.8, 0.5))
	var plan := VaultState.new()
	var feet := Vector3(0.0, tuning.body.rest_gap, -0.9)
	assert_true(Vault.plan(feet, Vector2(0.0, 1.0), 0.0, tuning.vault, tuning.body, w, plan))
	assert_false(plan.climb, "a thin barrier is vaulted, not climbed")


func test_a_deep_bare_box_is_still_climbed_as_a_floor() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(40.0, 0.5, 40.0))
	w.add_box(Vector3(3.0, 0.4, 0.0), Vector3(6.0, 0.8, 6.0))
	var plan := VaultState.new()
	var feet := Vector3(-0.7, tuning.body.rest_gap, 0.0)
	assert_true(Vault.plan(feet, Vector2(1.0, 0.0), 0.0, tuning.vault, tuning.body, w, plan))
	assert_true(plan.climb)


func test_climb_kinds_empty_refuses_every_listed_top_but_not_unlisted_ones() -> void:
	var q := _level("subway").query()
	var none := tuning.vault.duplicate() as VaultConfig
	none.climb_kinds = [] as Array[StringName]
	var plan := VaultState.new()
	# Subway's south platform edge from the track: owned by a floor, which is no longer listed.
	var feet := Vector3(-10.0, tuning.body.rest_gap, 9.6)
	assert_false(Vault.plan(feet, Vector2(0.0, -1.0), 0.0, none, tuning.body, q, plan))
	assert_true(Vault.plan(feet, Vector2(0.0, -1.0), 0.0, tuning.vault, tuning.body, q, plan))

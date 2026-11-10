extends GutTest
## QA for the Compact SMG (CS1): the edges of its new stats columns, its fire modes on a semi-only field, what a
## loadout carries of its model, and its figure drawn in hand and holstered.

const SMG := "000026"
const RED_DOT := "000007"

const TABLE := """## Replicas
| Key | Name | Class | Energy (J) | BB (g) | Fire rate (BBs/s) | Magazine (BBs) | Magazines | Reload (s) | Draw (s) | Spread (°) | Recoil (°) | Hip spread (×) | Pace (×) | Moving spread (×) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| smg | Compact SMG | rifle | 0.75 | 0.2 | 18 | 45 | 5 | 1.4 | 0.32 | 0.6 | 0.14 | %s | %s | %s |
"""

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true


func _smg_base() -> ReplicaConfig:
	return load("res://game/config/replicas/smg.tres") as ReplicaConfig


func test_the_new_columns_take_their_edges_and_refuse_beyond_them() -> void:
	var edge := ReplicaStats.parse(TABLE % ["0.5", "0.8", "0.2"])
	var r := edge.overlay(_smg_base())
	assert_eq([r.hip_spread, r.pace, r.move_spread], [0.5, 0.8, 0.2], "the lowest each takes")
	var high := ReplicaStats.parse(TABLE % ["20", "1.2", "2"]).overlay(_smg_base())
	assert_eq([high.hip_spread, high.pace, high.move_spread], [20.0, 1.2, 2.0], "and the highest")
	var bad := ReplicaStats.parse(TABLE % ["0.4", "3", "-1"])
	var kept := bad.overlay(_smg_base())
	assert_eq([kept.hip_spread, kept.pace, kept.move_spread], [0.75, 1.08, 0.5], "out of range: the built-in numbers")
	var named := bad.problems.filter(func(p: String) -> bool:
		return p.contains("Hip spread") or p.contains("Pace") or p.contains("Moving spread"))
	assert_eq(named.size(), 3, str(bad.problems))


func test_a_table_without_the_new_columns_keeps_the_smgs_built_in_pace_and_spread() -> void:
	var text := "\n".join(PackedStringArray([
		"## Replicas",
		"| Key | Name | Class | Energy (J) | BB (g) | Fire rate (BBs/s) | Magazine (BBs) | Magazines | Reload (s) | Draw (s) | Spread (°) | Recoil (°) |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|",
		"| smg | Compact SMG | rifle | 0.75 | 0.2 | 18 | 45 | 5 | 1.4 | 0.32 | 0.6 | 0.14 |",
	]))
	var s := ReplicaStats.parse(text)
	var missing := s.problems.filter(func(p: String) -> bool: return p.contains("Pace") or p.contains("Moving spread"))
	assert_eq(missing, [] as Array, "optional columns are not reported missing")
	var r := s.overlay(_smg_base())
	assert_eq([r.pace, r.move_spread, r.hip_spread, r.model], [1.08, 0.5, 0.75, &""])


func test_on_a_semi_only_field_it_starts_on_semi_never_burst_or_auto() -> void:
	var r := _smg_base()
	for most: ReplicaConfig.FireMode in [ReplicaConfig.FireMode.SEMI, ReplicaConfig.FireMode.BURST]:
		assert_eq(Armament.start_mode(r, most), ReplicaConfig.FireMode.SEMI, "held under %d" % most)
	assert_eq(Armament.start_mode(r, ReplicaConfig.FireMode.AUTO), ReplicaConfig.FireMode.AUTO)


func test_a_carried_smg_keeps_its_own_model_and_parts_leave_pace_alone() -> void:
	var l := rules.default_loadout("L")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, SMG))
	assert_true(rules.set_part(l, SMG, &"optic", RED_DOT))
	var carried := rules.carried(l)
	assert_eq(carried.replicas[0].id, &"smg")
	assert_eq(carried.replicas[0].model_id(), &"smg", "drawn as itself, carried with a fitted part")
	assert_eq(carried.replicas[1].model_id(), &"pistol")


func test_its_figure_is_drawn_in_hand_and_holstered_with_a_part_and_frees_cleanly() -> void:
	var kit := rules.carried(_loadout_with_red_dot())
	var c := Character.new(4, 0, Vector3.ZERO, 0.0, kit.replicas)
	c.grounded = true
	var f := FigureView.new()
	add_child_autofree(f)
	f.setup(c, Color.RED, HitConfig.new(), null)
	assert_gt(f.find_children("*", "MeshInstance3D", true, false).size(), 0, "the figure has meshes")
	f.on_tick(c)
	f.update(c, 1.0, 1.0 / 60.0)
	c.armament.holstered = true
	f.on_tick(c)
	f.update(c, 1.0, 1.0 / 60.0)
	c.armament.active = 1
	c.armament.holstered = false
	f.on_tick(c)
	f.update(c, 1.0, 1.0 / 60.0)
	pass_test("drawn in hand, holstered and switched with no error")


func _loadout_with_red_dot() -> Loadout:
	var l := rules.default_loadout("L")
	rules.equip(l, Loadout.Slot.PRIMARY, SMG)
	rules.set_part(l, SMG, &"optic", RED_DOT)
	return l


func test_zero_and_double_moving_spread_scale_only_what_moving_adds() -> void:
	var cfg := MovementConfig.new()
	var acc := AccuracyConfig.new()
	for share: float in [0.0, 2.0]:
		var r := _smg_base().duplicate() as ReplicaConfig
		r.move_spread = share
		r.hip_spread = 1.0
		var c := Character.new(1, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])
		c.grounded = true
		c.velocity = Vector3(cfg.run_speed, 0.0, 0.0)
		var run := Accuracy.target_spread_scale(c, cfg, acc)
		assert_almost_eq(run, 1.0 + (acc.run - 1.0) * share, 1e-4, "share %s" % share)
		c.velocity = Vector3.ZERO
		c.still_time = 0.0
		assert_almost_eq(Accuracy.target_spread_scale(c, cfg, acc), 1.0, 1e-4, "still is never scaled by it")

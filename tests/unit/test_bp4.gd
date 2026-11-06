extends GutTest
## BP4, the full bug pass before 0.1 Dev 2: in-match fixes. Working a flag's rope needs your feet on the pole's floor:
## inside the radius flat but on a roof or a floor above it, the rope doesn't move (as OvertimeFlag's touch).


func _attacker(at: Vector3) -> Character:
	var loadout: Array[ReplicaConfig] = []
	return Character.new(0, 0, at, 0.0, loadout)


func _flag(at: Vector3) -> FlagState:
	var f := FlagState.new()
	f.reset(at)
	return f


func test_the_rope_is_worked_from_the_pole_s_floor_only() -> void:
	var cfg := FlagConfig.new()
	var pole := Vector3(49.0, -0.04, 38.5)
	var flag := _flag(pole)
	assert_true(Flag.at_pole(_attacker(pole + Vector3(1.2, 0.0, 0.0)), flag, cfg), "beside it")
	assert_true(Flag.at_pole(_attacker(pole + Vector3(0.5, 0.3, 0.0)), flag, cfg), "on a step or a slope by it")
	assert_false(Flag.at_pole(_attacker(pole + Vector3(1.5, 3.1, 0.0)), flag, cfg), "on a roof beside it")
	assert_false(Flag.at_pole(_attacker(pole + Vector3(0.0, -3.0, 0.0)), flag, cfg), "on the floor below")
	assert_false(Flag.at_pole(_attacker(pole + Vector3(cfg.radius + 0.1, 0.0, 0.0)), flag, cfg), "too far")


extends GutTest
## QA for BP3: edges of the bolt press window and the per-slot cooldowns.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)
const PISTOL := "000001"
const SNIPER := "000021"

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true


func _both() -> Character:
	var loadout: Array[ReplicaConfig] = [rules.config(rules.pool.item(SNIPER)), rules.config(rules.pool.item(PISTOL))]
	return Character.new(1, 0, Vector3.ZERO, 0.0, loadout)


## Shots by slot: fires the rifle on tick 0, clicks again on `click_tick` (inside the bolt window), switches to the
## pistol on `switch_tick`, and never presses the trigger again.
func _run(click_tick: int, switch_tick: int, ticks: int) -> Array[int]:
	var c := _both()
	var cmd := PlayerCommand.new()
	var pool := BBPool.new(8)
	var events := SimEvents.new()
	var tuning := SimTuning.new()
	var slots: Array[int] = []
	for tick in ticks:
		cmd.fire = tick == 0 or tick == click_tick
		cmd.switch_to = 1 if tick == switch_tick else -1
		events.clear()
		var before := c.armament.active
		Armament.step(c, cmd, EYE, 1.0, true, pool, Seeds.stream(3), events, tuning, DT)
		for k in events.count:
			if events.items[k].kind == GameEvent.Kind.SHOT:
				slots.append(c.armament.active if before == c.armament.active else -9)
	return slots


func test_a_bolt_click_kept_for_the_cycle_never_fires_the_pistol_switched_to() -> void:
	# Click at 0.8 s (kept ~0.45 s + the 0.15 buffer), switch to the pistol one tick later: no trigger press for it.
	var slots := _run(48, 49, 150)
	var pistol_shots := 0
	for s in slots:
		if s == 1:
			pistol_shots += 1
	assert_eq(pistol_shots, 0, "the pistol fires only on a press made after switching to it")


func test_control_with_the_window_off_the_pistol_stays_quiet() -> void:
	var c := _both()
	var cmd := PlayerCommand.new()
	var tuning := SimTuning.new()
	tuning.replica_rules.bolt_press_window = 0.0
	var pool := BBPool.new(8)
	var events := SimEvents.new()
	var pistol_shots := 0
	for tick in 150:
		cmd.fire = tick == 0 or tick == 48
		cmd.switch_to = 1 if tick == 49 else -1
		events.clear()
		Armament.step(c, cmd, EYE, 1.0, true, pool, Seeds.stream(3), events, tuning, DT)
		for k in events.count:
			if events.items[k].kind == GameEvent.Kind.SHOT and c.armament.active == 1:
				pistol_shots += 1
	assert_eq(pistol_shots, 0)

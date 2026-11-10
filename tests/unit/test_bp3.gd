extends GutTest
## Fixes from the bug pass after the Sniper Rifle (BP3): each a failure the pass found, held here so it stays fixed.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)
const PISTOL := "000001"
const SNIPER := "000021"
const M140 := "000023"

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true


## The tick of each SHOT over `ticks` ticks, pulling the trigger every other tick, after switching to `slot` on the
## first (-1: no switch).
func _shots(c: Character, ticks: int, slot: int, tuning: SimTuning) -> Array[int]:
	var cmd := PlayerCommand.new()
	var pool := BBPool.new(8)
	var events := SimEvents.new()
	var out: Array[int] = []
	for tick in ticks:
		cmd.switch_to = slot if tick == 0 else -1
		cmd.fire = tick % 2 == 1
		events.clear()
		Armament.step(c, cmd, EYE, 1.0, true, pool, Seeds.stream(3), events, tuning, DT)
		for k in events.count:
			if events.items[k].kind == GameEvent.Kind.SHOT:
				out.append(tick)
	return out


func _sniper_and_pistol() -> Character:
	var loadout: Array[ReplicaConfig] = [rules.config(rules.pool.item(SNIPER)), rules.config(rules.pool.item(PISTOL))]
	return Character.new(1, 0, Vector3.ZERO, 0.0, loadout)


func test_the_rifles_bolt_never_holds_up_the_pistol_switched_to() -> void:
	var c := _sniper_and_pistol()
	var tuning := SimTuning.new()
	assert_eq(_shots(c, 2, -1, tuning).size(), 1, "the rifle fires")
	var shots := _shots(c, 60, 1, tuning)
	assert_false(shots.is_empty(), "the pistol fires")
	var draw := c.armament.replicas[1].draw_time
	assert_lt(shots[0] * DT, draw + 4.0 * DT, "as soon as it is up, not after the rifle's 1.25 s cycle")


func test_switching_away_and_back_never_skips_the_bolt() -> void:
	var c := _sniper_and_pistol()
	var tuning := SimTuning.new()
	_shots(c, 2, -1, tuning)
	# Away to the pistol for 6 ticks, then straight back: the rifle's cycle kept running on the sling, no faster.
	_shots(c, 6, 1, tuning)
	var back := _shots(c, 120, 0, tuning)
	assert_false(back.is_empty(), "the rifle fires again")
	var since_shot := (2 + 6 + back[0]) * DT
	assert_gte(since_shot, 1.0 / 0.8 - 2.0 * DT, "no sooner than its 1.25 s cycle after the last shot")


## Ticks from the first shot to the second, clicking once on the first tick and once `click_at` s later.
func _second_shot_after(click_at: float) -> int:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [rules.config(rules.pool.item(SNIPER))] as Array[ReplicaConfig])
	var cmd := PlayerCommand.new()
	var pool := BBPool.new(8)
	var events := SimEvents.new()
	var tuning := SimTuning.new()
	var shots: Array[int] = []
	var click := roundi(click_at / DT)
	for tick in 150:
		cmd.fire = tick == 0 or tick == click
		events.clear()
		Armament.step(c, cmd, EYE, 1.0, true, pool, Seeds.stream(3), events, tuning, DT)
		for k in events.count:
			if events.items[k].kind == GameEvent.Kind.SHOT:
				shots.append(tick)
	return shots[1] - shots[0] if shots.size() > 1 else -1


func test_a_click_once_the_bolt_looks_home_fires_as_the_cycle_ends() -> void:
	var cycle := roundi(1.0 / 0.8 / DT)
	var after := _second_shot_after(0.8)
	assert_almost_eq(after, cycle, 2, "the click at 0.8 s (handle home at 0.71) fires at 1.25 s, not lost")


func test_a_double_click_never_fires_twice() -> void:
	assert_eq(_second_shot_after(0.2), -1, "a click early in the cycle lapses as any press does")


func test_a_bomb_in_hand_is_no_holster_to_follow() -> void:
	var giver := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	assert_false(BotHolster.put_away(giver))
	giver.grenades.readied = Grenade.Kind.FLASH
	giver.grenades.ready_was_holstered = false
	giver.armament.put_down()
	assert_true(giver.armament.holstered, "the replica is put down for the bomb")
	assert_false(BotHolster.put_away(giver), "but not away: followers keep theirs up")
	giver.grenades.ready_was_holstered = true
	assert_true(BotHolster.put_away(giver), "holstered before the bomb: away")


func test_with_dev_content_off_the_empty_level_9_is_never_marked_next() -> void:
	var pool := Pool.read_file()
	# The M140 went public with the rifle (owner, 2026-11-05); tagged dev again here, level 9 holds only dev content (LV15).
	pool.item(M140).access = &"dev"
	var table := LevelTable.read_file(pool)
	var at_8 := 0
	for l in table.levels:
		if l.number == 8:
			at_8 = l.total
	var facts := ArmoryFacts.new(table, pool, at_8, false, false)
	assert_eq(facts.level, 8)
	var nine: ArmoryFacts.Row = null
	for r in facts.rows:
		if r.number == 9:
			nine = r
	assert_true(nine.items.is_empty(), "level 9 holds only the M140 Spring, dev here")
	assert_eq(nine.state, ArmoryFacts.State.LOCKED, "not the next card")
	assert_eq(facts.next_row().number, 10, "the next card is the one the header names")


func test_a_spring_rifle_s_rate_reads_as_it_is() -> void:
	assert_eq(LoadoutPerformance.rate_text(0.8), "0.8")
	assert_eq(LoadoutPerformance.rate_text(0.8 / 1.05), "0.76", "the M140's slower cycling shows")
	assert_eq(LoadoutPerformance.rate_text(13.0), "13")
	assert_eq(LoadoutPerformance.rate_text(14.95), "15", "a LiPo AEG reads whole")


func test_a_click_kept_for_the_rifle_never_fires_the_pistol_switched_to() -> void:
	var c := _sniper_and_pistol()
	var tuning := SimTuning.new()
	_shots(c, 2, -1, tuning)
	# A click 0.6 s into the cycle (inside the bolt's window), then straight to the pistol: no shot without a new click.
	var cmd := PlayerCommand.new()
	var pool := BBPool.new(8)
	var events := SimEvents.new()
	var fired := 0
	for tick in 90:
		cmd.fire = tick == 36
		cmd.switch_to = 1 if tick == 37 else -1
		events.clear()
		Armament.step(c, cmd, EYE, 1.0, true, pool, Seeds.stream(3), events, tuning, DT)
		for k in events.count:
			if events.items[k].kind == GameEvent.Kind.SHOT:
				fired += 1
	assert_eq(fired, 0)

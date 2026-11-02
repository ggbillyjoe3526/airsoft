extends GutTest
## NA1: bots on a field with a start mode (BotFireMode). They keep to it, and may go full auto only down a long sight
## line at someone in open space (owner, 2026-11-02: "It's an option; it doesn't mean they have to"), decided once per
## target; back to the start mode when the shot isn't open any more or the target is gone. Elsewhere the selector is
## never touched. The real Depot's open field picks out its most open floor, not all of it.

const SEMI := ReplicaConfig.FireMode.SEMI
const BURST := ReplicaConfig.FireMode.BURST
const AUTO := ReplicaConfig.FireMode.AUTO
const EYE := Vector3(0.0, 1.6, 0.0)
## Down -Z, the way the bot aims.
const AIM := Vector3(0.0, 0.0, -1.0)
## The test grid: 1 m cells, 100 by 100 from (-50, -50).
const SIZE := 100

var config: BotConfig = BotConfig.load_default()
var w: BotWorld
var b: Bot
var foe: Character


func before_each() -> void:
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	foe = Character.new(1, 1, Vector3(0.0, 0.0, -40.0), 0.0, loadout)
	# As a bot kit carries it: full auto out of the box (BotKits.kit_of).
	var aeg := me.armament.replicas[0].duplicate() as ReplicaConfig
	aeg.default_fire_mode = AUTO
	me.armament.replicas[0] = aeg
	w = BotWorld.new()
	w.tuning = SimTuning.load_default()
	w.cfg = config
	w.query = BoxWorld.new()
	w.characters = [me, foe]
	w.nav = _grid(0)
	w.start_mode = SEMI
	me.armament.reset_fire_modes(w.start_mode)
	b = Bot.new(me, 1, config.skill_for(&"normal"), 2)
	b.target_visible = true


## A grid with every cell `open` (cells) of open floor round it.
func _grid(open: int) -> NavGrid:
	var g := NavGrid.new()
	g.cell = 1.0
	g.cols = SIZE
	g.rows = SIZE
	g.min_x = -SIZE * 0.5
	g.min_z = -SIZE * 0.5
	g.open.resize(SIZE * SIZE)
	g.open.fill(open)
	return g


func _open_ground() -> void:
	w.nav = _grid(ceili(config.auto_open_min) + 1)


## The bot's selector over `ticks` ticks of BotFireMode.select and the armament, `target` its target.
func _select(target: Character, ticks: int = 3) -> ReplicaConfig.FireMode:
	var events := SimEvents.new()
	for i in ticks:
		var cmd := PlayerCommand.new()
		BotFireMode.select(b, w, target, cmd)
		Armament.step(b.character, cmd, EYE, 1.0, false, BBPool.new(1), Seeds.stream(1), events, w.tuning, 1.0 / 60.0)
	return b.character.armament.fire_mode()


func test_the_shot_is_open_only_down_a_long_line_at_someone_in_the_open() -> void:
	assert_false(BotFireMode.open_shot(w, EYE, AIM, foe.position), "long line, cramped floor")
	_open_ground()
	assert_true(BotFireMode.open_shot(w, EYE, AIM, foe.position), "long line, open floor")
	(w.query as BoxWorld).add_box(Vector3(0.0, 1.5, -config.auto_line_min * 0.5), Vector3(4.0, 3.0, 1.0))
	assert_false(BotFireMode.open_shot(w, EYE, AIM, foe.position), "a wall within the line: not a long one")


func test_an_open_shot_is_an_option_some_bots_take_and_some_don_t() -> void:
	_open_ground()
	var took := 0
	var tries := 40
	for s in tries:
		b = Bot.new(b.character, s + 1, config.skill_for(&"normal"), 2)
		b.target_visible = true
		BotFireMode.on_burst(b, w, foe, EYE, AIM)
		took += 1 if b.auto_for == foe.id else 0
	assert_between(took, 1, tries - 1, "%d of %d went full auto" % [took, tries])


func test_full_auto_once_taken_is_switched_to_and_dropped_when_the_target_goes() -> void:
	_open_ground()
	b.auto_for = foe.id
	b.auto_open = true
	b.auto_rolled_for = foe.id
	assert_eq(_select(foe), AUTO, "semi to burst to auto, a press a tick")
	b.target_visible = false
	assert_eq(_select(foe), SEMI, "target gone: back on the start mode")
	# Kept for that target (BP3): seen again in the open, it goes back to full auto without a new roll.
	assert_eq(b.auto_for, foe.id)
	b.target_visible = true
	BotFireMode.on_burst(b, w, foe, EYE, AIM)
	assert_eq(_select(foe, 4), AUTO, "seen again in the open: full auto again")


func test_a_shot_no_longer_open_goes_back_to_the_start_mode_and_isn_t_rolled_again() -> void:
	_open_ground()
	b.auto_for = foe.id
	b.auto_open = true
	b.auto_rolled_for = foe.id
	w.nav = _grid(0)
	BotFireMode.on_burst(b, w, foe, EYE, AIM)
	assert_eq(b.auto_for, -1)
	assert_eq(_select(foe), SEMI)
	_open_ground()
	BotFireMode.on_burst(b, w, foe, EYE, AIM)
	assert_eq(b.auto_for, -1, "decided once per target")


func test_no_press_through_a_vault_so_the_selector_settles_after_it() -> void:
	_open_ground()
	b.auto_for = foe.id
	b.auto_open = true
	b.auto_rolled_for = foe.id
	var cmd := PlayerCommand.new()
	b.character.vault.active = true
	BotFireMode.select(b, w, foe, cmd)
	assert_false(cmd.cycle_fire_mode, "vaulting: a press would only be kept")
	b.character.vault.active = false
	b.character.vault.held_fire_modes = 1
	BotFireMode.select(b, w, foe, cmd)
	assert_false(cmd.cycle_fire_mode, "a kept press still to play")
	b.character.vault.held_fire_modes = 0
	assert_eq(_select(foe), AUTO, "then it presses its way to auto")


func test_a_long_line_is_level_whatever_the_aim_s_pitch() -> void:
	var q := w.query as BoxWorld
	q.add_box(Vector3(0.0, -0.5, 0.0), Vector3(SIZE, 1.0, SIZE)) # a floor
	var down := Vector3(0.0, -0.15, -1.0).normalized() # at someone crouched 10 m off
	assert_true(BotFireMode.long_line(w, EYE, down), "the floor ahead doesn't end the line")
	assert_false(BotFireMode.long_line(w, EYE, Vector3.DOWN), "straight down has no heading")


## Pulls over a second of a bot on semi pulling whenever it may (`wants` every other tick, as BotCombat taps).
func _pulls_in_a_second() -> int:
	var pulls := 0
	for i in 60:
		w.time = i / 60.0
		pulls += 1 if BotFireMode.pull(b, w, i % 2 == 0) else 0
	return pulls


func test_on_semi_indoors_a_bot_taps_at_a_player_s_pace_not_the_replica_s_full_rate() -> void:
	var taps := _pulls_in_a_second()
	assert_eq(taps, ceili(1.0 / config.semi_tap_gap), "%d pulls a second" % taps)
	assert_lt(taps, roundi(b.character.armament.replicas[0].fire_rate), "slower than its full auto")
	w.start_mode = AUTO
	b.next_tap = -INF
	assert_eq(_pulls_in_a_second(), 30, "elsewhere every fresh pull, as before")


func test_a_cramped_shot_never_goes_auto() -> void:
	for s in 40:
		b = Bot.new(b.character, s + 1, config.skill_for(&"normal"), 2)
		b.target_visible = true
		BotFireMode.on_burst(b, w, foe, EYE, AIM)
		assert_eq(b.auto_for, -1)
	assert_eq(_select(foe), SEMI)


func test_without_a_start_mode_the_selector_is_never_touched() -> void:
	w.start_mode = AUTO
	_open_ground()
	b.character.armament.modes[0] = BURST
	BotFireMode.on_burst(b, w, foe, EYE, AIM)
	assert_eq(b.auto_for, -1)
	assert_eq(_select(foe), BURST)


func test_a_replica_without_full_auto_is_left_alone() -> void:
	_open_ground()
	b.character.armament.active = 1 # the GBB Pistol: semi only
	BotFireMode.on_burst(b, w, foe, EYE, AIM)
	assert_eq(b.auto_for, -1)
	assert_eq(_select(foe), SEMI)


func test_depot_s_open_field_is_its_most_open_floor_not_all_of_it() -> void:
	var t := SimTuning.load_default()
	var map := MapData.load_map("depot", MapStyle.new(), t.rounds.team_size)
	var g := NavGrid.build(map, t.nav, t.body)
	var walkable := 0
	var open := 0
	for c in g.cols * g.rows:
		var k := g.cell_start[c]
		if g.cell_start[c + 1] == k or g.walkable[k] == 0:
			continue
		walkable += 1
		open += 1 if g.open[c] * g.cell >= config.auto_open_min else 0
	var share := float(open) / walkable
	assert_between(share, 0.05, 0.25, "%.0f %% of Depot's floor counts as open" % (share * 100.0))



func test_a_target_seen_again_out_of_the_open_gets_no_full_auto_mid_burst() -> void:
	_open_ground()
	b.auto_for = foe.id
	b.auto_rolled_for = foe.id
	b.auto_open = true
	b.burst_left = 1.0
	assert_eq(_select(foe), AUTO)
	b.target_visible = false
	assert_eq(_select(foe), SEMI, "out of sight: the start mode, and the burst ends")
	assert_eq(b.burst_left, 0.0)
	# Back in sight in a doorway (no open ground), before a new burst has judged the shot: still semi (BP3).
	w.nav = _grid(0)
	b.target_visible = true
	assert_eq(_select(foe), SEMI, "full auto waits for a burst that finds the target in the open")

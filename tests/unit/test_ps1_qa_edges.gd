extends GutTest
## QA edges for PS1 (personalities in Attack / Defend and Plant The Bomb): a team that can't be pushed, a table that is
## wrong in ways other than a bad cell, the raiser and the fetcher kept through the margin, and the draws a pick makes.

var file: BotsFile = BotsFile.read_file()
var loadout: Array[ReplicaConfig] = ReplicaStats.default_loadout()


func _bare(team: int, at: Array[Vector3]) -> BotWorld:
	var w := BotWorld.new()
	w.cfg = BotConfig.new()
	w.tuning = SimTuning.new()
	w.mode = RoundState.Mode.ATTACK_DEFEND
	w.attackers = 0
	for i in at.size():
		var c := Character.new(i, team, at[i], 0.0, loadout)
		w.characters.append(c)
		w.bots.append(Bot.new(c, 7 + i, BotSkill.new(), at.size()))
	return w


func _members(kinds: Array[StringName]) -> RoundPlanner:
	var p := RoundPlanner.new(1)
	for k in kinds:
		var b := Bot.new(Character.new(0, 1, Vector3.ZERO, 0.0, loadout), 1, BotSkill.new(), kinds.size())
		b.style = file.style(k)
		p._members.append(b)
	return p


func test_a_team_of_anchors_has_nobody_to_push() -> void:
	var p := _members([&"anchor", &"anchor", &"anchor"] as Array[StringName])
	for d in 3:
		assert_eq(p._pushed_member(d), -1, "draw %d: no post is pushed" % d)


func test_an_empty_team_and_a_neutral_team_keep_the_drawn_pusher() -> void:
	assert_eq(_members([] as Array[StringName])._pushed_member(0), -1, "no members, no pusher, no crash")
	var p := _members([&"flanker", &"careful", &"flanker"] as Array[StringName])
	for d in 3:
		assert_eq(p._pushed_member(d), d, "neutral styles: the variety stream's pick, as on main")


func test_a_table_naming_an_unknown_personality_or_missing_a_column_is_reported_not_fatal() -> void:
	var text := FileAccess.get_file_as_string(BotsFile.PATH)
	var ghost := BotsFile.parse(text.replace(_row(text, "| Careful | – |"), "| Ghost | deep | 1 | 1 | 0.5 | 0.5 |"))
	assert_gt(ghost.problems.size(), 0, "Ghost is not in the Personalities table")
	assert_eq(ghost.style(&"careful").carry_scale, 1.0, "the left-out personality keeps neutral")
	var missing := BotsFile.parse(text.replace("| Forward spawn, Plant the Bomb (chance) |", "| Spawn |"))
	assert_gt(missing.problems.size(), 0, "a missing column is reported")
	assert_eq(missing.style(&"rusher").post, BotsFile.Post.SAME, "and none of the table is used")
	assert_false(missing.style(&"rusher").has_spawn_chance)
	var low := BotsFile.parse(text.replace("| Rusher | forward | 0.7 |", "| Rusher | forward | 0 |"))
	assert_eq(low.style(&"rusher").retake_scale, 1.0, "a scale of 0 is below the least (0.1): reported, neutral")
	assert_gt(low.problems.size(), 0)


func test_the_raiser_has_no_personality_lean_and_keeps_its_margin() -> void:
	var pole := Vector3(10.0, 0.0, 0.0)
	var w := _bare(0, [pole - Vector3(5.0, 0, 0), pole - Vector3(9.0, 0, 0)] as Array[Vector3])
	w.flags[0].position = pole
	for b in w.bots:
		b.lane_done = true
	w.bots[0].style = file.style(&"rusher")
	w.bots[1].style = file.style(&"flanker")
	w.cfg.raiser_switch_margin = 3.0
	w.bots[0].raiser = true
	for i in 5:
		BotFlag.pick_raiser(w)
		assert_true(w.bots[0].raiser and not w.bots[1].raiser, "pick %d: no swap inside the margin" % i)
	w.bots[1].character.position = pole - Vector3(3.5, 0, 0)
	BotFlag.pick_raiser(w)
	assert_true(w.bots[0].raiser, "3.5 m is not nearer than the kept rusher's 5 m - 3: no lean on the rope (PS1)")
	w.bots[1].character.position = pole - Vector3(1.5, 0, 0)
	BotFlag.pick_raiser(w)
	assert_true(w.bots[1].raiser, "1.5 m beats 5 m - 3: the rope is handed on by distance alone")


func test_the_kept_fetcher_is_held_and_a_flanker_rival_far_enough_ahead_takes_over() -> void:
	var bomb := Vector3(-20.0, 0.0, 0.0)
	var w := _bare(0, [bomb + Vector3(3.0, 0, 0), bomb + Vector3(8.0, 0, 0)] as Array[Vector3])
	w.mode = RoundState.Mode.PLANT_THE_BOMB
	w.plant = PlantState.new()
	w.plant.status = PlantState.Status.DOWN
	w.plant.position = bomb
	w.cfg.raiser_switch_margin = 2.0
	w.bots[0].style = file.style(&"rusher")
	w.bots[1].style = file.style(&"flanker")
	w.bots[0].fetcher = true
	BotPlant._pick_fetcher(w)
	var after_first := w.bots[0].fetcher
	for i in 4:
		BotPlant._pick_fetcher(w)
		assert_eq(w.bots[0].fetcher, after_first, "the pick is stable tick to tick (no flapping)")
		assert_ne(w.bots[0].fetcher, w.bots[1].fetcher, "exactly one fetcher")


func test_a_pick_draws_the_same_from_its_stream_whatever_chance_it_has() -> void:
	var w := _bare(0, [Vector3.ZERO] as Array[Vector3])
	var end := MapEnd.new()
	var f := ForwardSpawn.new()
	f.spots.append(SpawnPoint.new(Vector3(-10.0, 0.0, 0.0), 0.0))
	f.centre = Vector3(-10.0, 0.0, 0.0)
	end.forward.append(f)
	w.ends = [end] as Array[MapEnd]
	w.cfg.forward_spawn_chance = 0.5
	var b := w.bots[0]
	b.character.end = 0
	var mine := BotsFile.Style.new()
	mine.has_spawn_chance = true
	mine.spawn_chance = 0.0
	b.style = mine
	BotRespawn.pick(b, w)
	var with_style := b.rng.randf()
	b.reset(-1, 0, 0.0, w.cfg)
	var twin := Bot.new(Character.new(0, 0, Vector3.ZERO, 0.0, loadout), 7, BotSkill.new(), 1)
	twin.character.end = 0
	w.cfg.forward_spawn_chance = 0.0
	twin.style = BotsFile.neutral()
	BotRespawn.pick(twin, w)
	assert_eq(twin.rng.randf(), with_style, "one randf either way: a style changes the odds, not the stream")


func test_a_bad_cell_in_one_spawn_column_leaves_the_other_column_read() -> void:
	var text := FileAccess.get_file_as_string(BotsFile.PATH)
	var row := _row(text, "| Rusher | forward |")
	var cells := row.split("|")
	var bomb_at := -1
	var ad_at := -1
	var table := BotsFile.parse(text)
	assert_gt(table.style(&"rusher").bomb_spawn_chance, 0.0, "the shipped row has both chances")
	for i in cells.size():
		if cells[i].strip_edges() == String.num(table.style(&"rusher").bomb_spawn_chance):
			bomb_at = i
		if cells[i].strip_edges() == String.num(table.style(&"rusher").spawn_chance):
			ad_at = i
	assert_gt(bomb_at, -1)
	assert_gt(ad_at, -1)
	var bad_bomb := cells.duplicate()
	bad_bomb[bomb_at] = " 1.5 "
	var a := BotsFile.parse(text.replace(row, "|".join(bad_bomb)))
	assert_eq(a.problems.size(), 1, "one bad cell, one problem: %s" % [a.problems])
	assert_true(a.style(&"rusher").has_spawn_chance, "the Attack / Defend chance is still read")
	assert_false(a.style(&"rusher").has_bomb_spawn_chance, "the bad one keeps the game's")
	var bad_ad := cells.duplicate()
	bad_ad[ad_at] = " often "
	var b := BotsFile.parse(text.replace(row, "|".join(bad_ad)))
	assert_eq(b.problems.size(), 1)
	assert_false(b.style(&"rusher").has_spawn_chance)
	assert_true(b.style(&"rusher").has_bomb_spawn_chance, "the Plant The Bomb chance is still read")


## The whole line of the bots.md table row that starts with `start`.
func _row(text: String, start: String) -> String:
	var at := text.find(start)
	assert_gt(at, -1, "the row %s is in bots.md" % start)
	return text.substr(at, text.find("\n", at) - at)

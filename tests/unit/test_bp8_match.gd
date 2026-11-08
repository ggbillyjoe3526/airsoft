extends GutTest
## BP8 match fixes (William's 0.1 Dev 2 playtest notes): two grenade slots, each any bomb (2); the flag's raise and hold
## times (16); Attack / Defend the default mode (20); still camera after the round (22); SIMULATE a skipped round (24);
## bushes slow you and rustle louder (25).

const LOADOUTS := "user://test_bp8_match_loadouts.save"
const SETTINGS := "user://test_bp8_match_settings.save"

var tuning: SimTuning = SimTuning.load_default()


func before_each() -> void:
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)


func after_each() -> void:
	await wait_process_frames(2)
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)


func _kinds(picks: Array[Grenade.Kind]) -> Array:
	return Array(picks)


# --- 2: grenade slots ---


func test_a_loadout_has_two_grenade_slots_each_a_smoke_or_a_flash_the_same_twice_allowed() -> void:
	var rules := LoadoutRules.standard()
	var l := rules.default_loadout("Test")
	assert_eq(rules.bombs.slots, 2)
	assert_eq(_kinds(rules.bombs_of(l)), [Grenade.Kind.SMOKE, Grenade.Kind.FLASH], "the default pick: one of each")
	assert_true(rules.set_bomb(l, 1, Grenade.Kind.SMOKE))
	assert_eq(_kinds(rules.bombs_of(l)), [Grenade.Kind.SMOKE, Grenade.Kind.SMOKE], "two smokes")
	assert_false(rules.set_bomb(l, 1, Grenade.Kind.SMOKE), "already so")
	assert_true(rules.set_bomb(l, 0, Grenade.Kind.FLASH))
	assert_true(rules.set_bomb(l, 1, Grenade.Kind.FLASH))
	assert_eq(_kinds(rules.carried(l).bombs), [Grenade.Kind.FLASH, Grenade.Kind.FLASH], "the kit carries two flashes")
	assert_false(rules.set_bomb(l, 2, Grenade.Kind.SMOKE), "no third slot")
	assert_false(rules.set_bomb(l, 0, Grenade.Kind.NONE), "a slot holds a bomb")


func test_the_pick_is_saved_and_an_old_save_carries_one_of_each() -> void:
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	saved.rules.set_bomb(saved.carried(), 0, Grenade.Kind.FLASH)
	assert_true(saved.save(LOADOUTS))
	var back := SavedLoadouts.new(LoadoutRules.standard())
	back.load_file(LOADOUTS)
	assert_eq(_kinds(back.rules.bombs_of(back.carried())), [Grenade.Kind.FLASH, Grenade.Kind.FLASH])
	assert_eq(_kinds(back.carried().copy("x").bombs), [Grenade.Kind.FLASH, Grenade.Kind.FLASH], "a copy keeps them")
	var old := SavedLoadouts.new(LoadoutRules.standard())
	var problems := old.from_dict({"slots": [{"name": "Old", "equipped": ["000002", "000001"]}]})
	assert_eq(problems, [] as Array[String], "a save from before grenade slots reads cleanly")
	assert_eq(_kinds(old.rules.bombs_of(old.carried())), [Grenade.Kind.SMOKE, Grenade.Kind.FLASH])
	problems = old.from_dict({"slots": [{"name": "Bad", "equipped": ["000002", "000001"], "bombs": ["smoke", "frag"]}]})
	assert_eq(problems.size(), 1, "a bomb this build doesn't know is listed")
	assert_eq(_kinds(old.rules.bombs_of(old.carried())), [Grenade.Kind.SMOKE, Grenade.Kind.FLASH], "the default pick")


func test_the_hand_carries_its_picks_and_a_match_start_hands_them_out() -> void:
	var hand := Grenades.Hand.new()
	hand.carry_picked(tuning.grenades)
	assert_eq([hand.smoke, hand.flash], [1, 1], "no pick: one of each")
	hand.picks = [Grenade.Kind.SMOKE, Grenade.Kind.SMOKE] as Array[Grenade.Kind]
	hand.carry_picked(tuning.grenades)
	assert_eq([hand.smoke, hand.flash], [2, 0])
	hand.smoke = 0
	hand.refill()
	assert_eq(hand.smoke, 2, "a respawn refills the pick")
	hand.picks = [Grenade.Kind.FLASH, Grenade.Kind.FLASH, Grenade.Kind.FLASH] as Array[Grenade.Kind]
	hand.carry_picked(tuning.grenades)
	assert_eq([hand.smoke, hand.flash], [1, 1], "more than two slots won't do: the default pick")
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-10.0 if e == 0 else 10.0, 0.0, 0.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-15.0 if e == 0 else 15.0, 0.0, 0.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(3, tuning)
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grenades.picks = [Grenade.Kind.FLASH, Grenade.Kind.FLASH] as Array[Grenade.Kind]
	s.characters.append(c)
	s.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	sim.start_match(s)
	assert_eq([c.grenades.smoke, c.grenades.flash], [0, 2])
	assert_eq([s.characters[1].grenades.smoke, s.characters[1].grenades.flash], [1, 1])


func test_bot_kits_list_their_grenades() -> void:
	var kits := BotKits.shared()
	assert_eq(kits.problems, [] as Array[String])
	var rules := LoadoutRules.standard()
	var seen := {}
	for plan in kits.kits:
		assert_eq(plan.bombs.size(), 2, "%s lists two bombs" % plan.kit_name)
		seen[_kinds(BotKits.kit_of(plan, rules).bombs)] = true
	assert_true(seen.has([Grenade.Kind.FLASH, Grenade.Kind.FLASH]), "some kits carry two flashes")
	assert_true(seen.has([Grenade.Kind.SMOKE, Grenade.Kind.SMOKE]), "some two smokes")
	var pool := Pool.shared()
	var head := "| Kit | Primary | Primary parts | Secondary | Secondary parts | Grenades | Easy | Normal | Hard |\n"
	head += "|---|---|---|---|---|---|---|---|---|\n"
	var bad := BotKits.parse(head + "| X | AEG Rifle | | | | Smoke, Frag | 1 | 1 | 1 |\n", pool)
	assert_eq(bad.kits.size(), 0)
	assert_string_contains(bad.problems[0], "Frag")


func test_the_loadout_page_picks_each_slot() -> void:
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	var page := LoadoutPage.new(saved, Settings.new())
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	var gear := page.gear()
	assert_eq(gear.grenade_pick(0).selected(), 0, "slot 1: smoke")
	assert_eq(gear.grenade_pick(1).selected(), 1, "slot 2: flash")
	gear.grenade_pick(0).button(1).pressed.emit()
	assert_eq(_kinds(saved.rules.bombs_of(saved.carried())), [Grenade.Kind.FLASH, Grenade.Kind.FLASH])
	var slot1 := gear.find_child("GrenadeSlot1", true, false)
	var bomb := slot1.find_child("Bomb", true, false) as Label
	assert_eq(bomb.text, "FLASH", "the tile shows its bomb")
	assert_eq((slot1.find_children("*", "GrenadeGlyph", true, false)[0] as GrenadeGlyph).kind, Grenade.Kind.FLASH)

extends GutTest
## The saved loadouts (LO1; the browser game's pool/savedLoadouts.test.ts): five named loadouts, the current one
## carried and edited, and their own versioned store through SaveFile.

const PATH := "user://test_loadouts.save"
const AEG := "000002"
const PISTOL := "000001"
const LIPO := "000015"

var saved: SavedLoadouts


func before_each() -> void:
	SaveFile.remove(PATH)
	saved = SavedLoadouts.new(LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new()))


func after_each() -> void:
	SaveFile.remove(PATH)


func names() -> Array:
	return saved.slots.map(func(l: Loadout) -> String: return l.name)


func test_a_new_player_has_one_default_loadout() -> void:
	assert_eq(names(), ["Loadout 1"])
	assert_eq(saved.current, 0)
	assert_eq(saved.carried().equipped, PackedStringArray([AEG, PISTOL]))


func test_create_copies_the_carried_loadout_and_carries_the_copy() -> void:
	saved.rules.set_power(saved.carried(), AEG, LIPO)
	watch_signals(saved)
	assert_eq(saved.create(), 1)
	assert_signal_emitted(saved, "changed")
	assert_eq(names(), ["Loadout 1", "Loadout 2"])
	assert_eq(saved.current, 1)
	assert_eq(saved.rules.tune_of(saved.carried(), AEG).power_id, LIPO)
	saved.rules.set_bb_weight(saved.carried(), AEG, 0.3)
	assert_almost_eq(saved.rules.tune_of(saved.slots[0], AEG).bb_weight, 0.25, 1e-9, "a copy, not the same setup")


func test_there_are_never_more_than_five() -> void:
	for i in 4:
		saved.create()
	assert_eq(saved.slots.size(), SavedLoadouts.MAX_SLOTS)
	assert_eq(saved.create(), -1)
	assert_eq(saved.duplicate_slot(0), -1)


func test_rename_trims_and_cuts_and_refuses_an_empty_name() -> void:
	assert_true(saved.rename(0, "  CQB Rush  "))
	assert_eq(saved.carried().name, "CQB Rush")
	assert_true(saved.rename(0, "A name far longer than twenty characters"))
	assert_eq(saved.carried().name.length(), SavedLoadouts.NAME_MAX)
	assert_false(saved.rename(0, "   "))


func test_duplicate_leaves_the_carried_one_and_names_the_copy_freshly() -> void:
	saved.create()
	saved.use(0)
	assert_eq(saved.duplicate_slot(1), 2)
	assert_eq(saved.current, 0)
	assert_eq(names(), ["Loadout 1", "Loadout 2", "Loadout 3"])


func test_replace_copies_the_carried_one_over_another_keeping_its_name() -> void:
	saved.create()
	saved.rename(1, "Long lanes")
	saved.use(0)
	saved.rules.set_power(saved.carried(), AEG, LIPO)
	assert_true(saved.replace(1))
	assert_eq(saved.slots[1].name, "Long lanes")
	assert_eq(saved.rules.tune_of(saved.slots[1], AEG).power_id, LIPO)
	assert_false(saved.replace(0), "not over itself")


## BP7 (row 89): the last Replace can be undone until any other change.
func test_the_last_replace_is_undone_until_another_change() -> void:
	saved.create()
	saved.rename(1, "Long lanes")
	var before := saved.slots[1].to_dict()
	saved.use(0)
	saved.rules.set_power(saved.carried(), AEG, LIPO)
	assert_eq(saved.undo_index(), -1, "nothing to undo yet")
	assert_false(saved.undo_replace())
	assert_true(saved.replace(1))
	assert_eq(saved.undo_index(), 1)
	assert_true(saved.undo_replace())
	assert_eq(saved.slots[1].to_dict(), before, "back as it was")
	assert_eq(saved.undo_index(), -1, "once")
	assert_false(saved.undo_replace())
	for change: Callable in [func() -> void: saved.use(1), func() -> void: saved.rename(0, "Short"),
			func() -> void: saved.mark_changed(), func() -> void: saved.create()]:
		saved.use(0)
		assert_true(saved.replace(1))
		change.call()
		assert_eq(saved.undo_index(), -1, "another change forgets it")
		assert_false(saved.undo_replace())


func test_remove_never_takes_the_last_and_keeps_the_carried_one() -> void:
	assert_false(saved.remove(0))
	saved.create()
	saved.create()
	saved.rename(1, "Middle")
	saved.use(2)
	assert_true(saved.remove(0))
	assert_eq(saved.current, 1, "still the same loadout")
	assert_eq(names(), ["Middle", "Loadout 3"])
	assert_true(saved.remove(1))
	assert_eq(saved.current, 0)


func test_saves_and_reads_back_with_unknown_fields_kept() -> void:
	saved.create()
	saved.rename(1, "Pistols")
	saved.rules.equip(saved.carried(), Loadout.Slot.PRIMARY, PISTOL)
	saved.rules.set_bb_weight(saved.carried(), PISTOL, 0.23)
	var data := saved.to_dict()
	data["from_a_later_build"] = {"x": "kept"}
	assert_true(SaveFile.write(PATH, SavedLoadouts.KIND, SavedLoadouts.VERSION, data))
	var back := SavedLoadouts.new(saved.rules)
	back.load_file(PATH)
	assert_eq(back.load_message, "")
	assert_eq(back.slots.map(func(l: Loadout) -> String: return l.name), ["Loadout 1", "Pistols"])
	assert_eq(back.current, 1)
	assert_eq(back.carried().equipped, PackedStringArray([PISTOL, AEG]))
	assert_almost_eq(back.rules.tune_of(back.carried(), PISTOL).bb_weight, 0.23, 1e-9)
	assert_eq(back.to_dict()["from_a_later_build"], {"x": "kept"})


func test_a_saved_value_that_wont_do_keeps_its_default() -> void:
	var problems := saved.from_dict({"current": 7, "slots": [
		{"name": 5, "equipped": ["000002"], "tunes": {"000002": {"bb_weight": "heavy", "paint": "pink"}}},
		"not a loadout",
	]})
	assert_eq(saved.slots.size(), 1)
	assert_eq(saved.current, 0)
	assert_eq(saved.carried().name, "Loadout 1")
	assert_eq(saved.carried().equipped, PackedStringArray([AEG, PISTOL]))
	var t := saved.rules.tune_of(saved.carried(), AEG)
	assert_almost_eq(t.bb_weight, 0.25, 1e-9)
	assert_eq(t.paint, &"cobalt")
	assert_gt(problems.size(), 1)


func test_a_newer_file_is_refused_and_a_damaged_one_set_aside() -> void:
	assert_true(SaveFile.write(PATH, SavedLoadouts.KIND, SavedLoadouts.VERSION + 1, saved.to_dict()))
	saved.create()
	saved.load_file(PATH)
	assert_ne(saved.load_message, "")
	SaveFile.remove(PATH)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("not a save")
	f.close()
	saved.load_file(PATH)
	assert_ne(saved.load_message, "")
	assert_false(FileAccess.file_exists(PATH), "moved aside")
	for name: String in DirAccess.get_files_at("user://"):
		if name.begins_with("test_loadouts.save.corrupt"):
			DirAccess.remove_absolute("user://" + name)

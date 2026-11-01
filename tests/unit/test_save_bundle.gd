extends GutTest
## SaveBundle (SV1): the four stores read as one, a missing store absent, a damaged one absent and named, the summary
## through fresh stores, a newer version refused, and every SaveFile kind under game/ in the bundle or on the machine
## list. Each test gets its own empty folder; the player's own save is never read.

const ROOT := "user://test-save-bundle"
## Kind constants under game/: `const KIND := "x"`, `const UNDO_KIND := "x"`.
const KIND_PATTERN := "const\\s+\\w*KIND\\s*:?=\\s*\"([^\"]+)\""

var dir := ""
var _n := 0


func before_each() -> void:
	_n += 1
	dir = "%s/%d" % [ROOT, _n]
	_wipe(dir)
	DirAccess.make_dir_recursive_absolute(dir)


func after_all() -> void:
	_wipe(ROOT)


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d: String in DirAccess.get_directories_at(path):
		_wipe(path.path_join(d))
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _paths() -> Array[String]:
	var out: Array[String] = []
	for path: String in SaveBundle.PATHS:
		out.append(dir.path_join(path.get_file()))
	return out


## The four stores as the game writes them: XP 1500, two loadouts, a win and two losses.
func _write_real_save() -> void:
	var p := _paths()
	assert_true(Settings.new().save(p[0]))
	var loadouts := SavedLoadouts.new(LoadoutRules.standard())
	loadouts.create()
	assert_true(loadouts.save(p[1]))
	var progress := Progress.new(LevelTable.shared())
	progress.add_xp(1500)
	assert_true(progress.save(p[2]))
	var records := Records.new()
	records.results["normal.elimination"] = PackedInt32Array([1, 2])
	assert_true(records.save(p[3]))


func test_reads_the_four_stores_as_one() -> void:
	_write_real_save()
	var b := SaveBundle.read(_paths())
	assert_eq(b.stores.keys(), ["settings", "loadouts", "progress", "records"])
	for kind: String in SaveBundle.KINDS:
		# Records are at version 2 since the bots' levels moved up a name (TL1), settings at 3 since the ambience's
		# default moved (AU1); the rest at 1.
		var want := 2 if kind == "records" else (3 if kind == "settings" else 1)
		assert_eq(b.stores[kind]["version"], want, kind)
		assert_true(b.stores[kind]["data"] is Dictionary, kind)
	assert_eq(b.version, Version.current())
	assert_gt(b.saved_at, 0)
	assert_eq(b.damaged.size(), 0)
	var d := b.to_dict()
	assert_eq(d.keys(), ["saved_at", "version", "stores"])


func test_a_missing_store_is_absent_and_a_damaged_one_named() -> void:
	_write_real_save()
	var p := _paths()
	SaveFile.remove(p[3])
	var f := FileAccess.open(p[2], FileAccess.WRITE)
	f.store_string("ASAVE progress 1 beef\n{}")
	f.close()
	SaveFile.remove(p[2] + ".bak")
	var b := SaveBundle.read(p)
	assert_false(b.stores.has("records"))
	assert_false(b.stores.has("progress"))
	assert_eq(b.damaged, PackedStringArray(["progress"]))
	assert_true(b.stores.has("settings"))


func test_an_empty_folder_is_an_empty_save() -> void:
	var b := SaveBundle.read(_paths())
	assert_true(b.is_empty())
	assert_eq(b.saved_at, 0)


func test_summary_reads_fresh_stores_never_the_shared_ones() -> void:
	_write_real_save()
	var shared_progress: Progress = Progress._shared
	var shared_records: Records = Records._shared
	var shared_loadouts: SavedLoadouts = SavedLoadouts._shared
	var s := SaveBundle.read(_paths()).summary()
	assert_eq(s.xp, 1500)
	assert_eq(s.level, LevelTable.shared().level_of(1500))
	assert_eq(s.unlocked, LevelTable.shared().unlocks_up_to(s.level).size())
	assert_eq(s.matches, 3)
	assert_eq(s.loadouts, 2)
	assert_eq(s.version, Version.current())
	assert_gt(s.saved_at, 0)
	assert_same(Progress._shared, shared_progress, "the shared progress untouched")
	assert_same(Records._shared, shared_records)
	assert_same(SavedLoadouts._shared, shared_loadouts)


func test_an_empty_save_summarises_as_a_new_player() -> void:
	var s := SaveBundle.new().summary()
	assert_eq(s.xp, 0)
	assert_eq(s.matches, 0)
	assert_eq(s.loadouts, 1, "a missing loadouts file is one default loadout")


func test_to_dict_and_back_is_the_same_save() -> void:
	_write_real_save()
	var b := SaveBundle.read(_paths())
	var back := SaveBundle.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())))
	assert_true(back.same_as(b))
	assert_eq(back.saved_at, b.saved_at)
	assert_eq(back.version, b.version)
	back.stores["records"]["data"]["streak"] = 5
	assert_false(back.same_as(b))


func test_from_dict_leaves_out_what_does_not_fit() -> void:
	var b := SaveBundle.from_dict({"stores": {"settings": {"version": 1.5, "data": {}}, "loadouts": {"version": 1,
			"data": []}, "nonsense": {"version": 1, "data": {}}, "records": {"version": 1, "data": {}}}})
	assert_eq(b.stores.keys(), ["records"])
	assert_true(SaveBundle.from_dict({"stores": "x"}).is_empty())


func test_a_newer_store_is_refused_with_its_version() -> void:
	var b := SaveBundle.new()
	b.version = Version.current()
	b.stores["records"] = {"version": 1, "data": {}}
	assert_eq(b.refusal(), "")
	b.stores["progress"] = {"version": Progress.VERSION + 1, "data": {}}
	assert_string_contains(b.refusal(), "progress is version %d" % (Progress.VERSION + 1))


func test_a_newer_builds_save_is_refused_with_its_version() -> void:
	var b := SaveBundle.new()
	b.version = "99.0"
	assert_string_contains(b.refusal(), "taken by 99.0")
	b.version = "0.0 Dev 1"
	assert_eq(b.refusal(), "", "an older build's save is fine")


func test_every_save_kind_is_in_the_bundle_or_the_machine_list() -> void:
	var kinds := _kinds_under("res://game")
	assert_gt(kinds.size(), 4, "found the kinds")
	for kind: String in kinds:
		assert_true(SaveBundle.KINDS.has(kind) or SaveBundle.MACHINE_KINDS.has(kind),
				"%s is in the bundle or on the machine list" % kind)
	for kind: String in SaveBundle.KINDS:
		assert_false(SaveBundle.MACHINE_KINDS.has(kind), kind)


func _kinds_under(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var pattern := RegEx.create_from_string(KIND_PATTERN)
	for d: String in DirAccess.get_directories_at(path):
		out.append_array(_kinds_under(path.path_join(d)))
	for f: String in DirAccess.get_files_at(path):
		if f.get_extension() != "gd":
			continue
		for m: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(path.path_join(f))):
			out.append(m.get_string(1))
	return out

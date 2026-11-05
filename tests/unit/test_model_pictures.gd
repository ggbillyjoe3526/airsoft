extends GutTest
## MP1: every model the menus or the HUD can show has its picture there, drawn from the model file itself, so a new or
## rebuilt model shows the moment it is merged. A model folder this test does not know fails it until someone decides
## where its models are shown.

const MODEL_ROOT := "res://assets/models/"
## The folders whose models have pictures in the UI.
const PICTURED: Array[String] = ["replicas", "replicaParts", "powerSources", "grenades"]
## The folders whose models show live only in a match (figures, map props). The props are also in the fields' pictures
## (assets/maps/*.jpg, tools/eye_pictures.gd): re-render those after a prop changes (docs/ASSETS.md).
const MATCH_ONLY: Array[String] = ["characters", "props"]

var pool: Pool


func before_all() -> void:
	pool = Pool.read_file()


func _glbs(folder: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(MODEL_ROOT + folder):
		return out
	for f in DirAccess.get_files_at(MODEL_ROOT + folder):
		if f.get_extension() == "glb":
			out.append(f.get_basename())
	return out


func _pictures() -> ReplicaPictures:
	var pictures := ReplicaPictures.new()
	pictures.replica_side = ReplicaPictures.PART_LONG_SIDE
	add_child_autofree(pictures)
	return pictures


func test_every_model_folder_is_pictured_or_shown_only_in_a_match() -> void:
	for folder in DirAccess.get_directories_at(MODEL_ROOT):
		if _glbs(folder).is_empty():
			continue
		assert_true(folder in PICTURED or folder in MATCH_ONLY,
				"assets/models/%s: show its models in the UI, or list it as match-only here" % folder)


func test_every_replica_model_is_a_pool_replica() -> void:
	var keys: Array[String] = []
	for r in pool.replicas:
		keys.append(String(r.key))
	for f in _glbs("replicas"):
		assert_has(keys, f, "replicas/%s.glb has a replica in pool.md, so it is pictured" % f)
	for f in _glbs("replicaParts"):
		assert_has(keys, f, "replicaParts/%s.glb belongs to a replica" % f)


func test_every_power_model_is_the_picture_of_a_power_source() -> void:
	var used: Array[String] = []
	for id: String in PowerModels.PICTURES:
		used.append(String(PowerModels.file(id)))
	for f in _glbs("powerSources"):
		assert_has(used, f, "powerSources/%s.glb is some power source's picture (PowerModels)" % f)


func test_every_grenade_model_is_a_bomb_kind() -> void:
	assert_eq(ReplicaPictures.GRENADE_FILES.size(), Grenade.Kind.size(), "a file name for every kind")
	for f in _glbs("grenades"):
		assert_has(ReplicaPictures.GRENADE_FILES, StringName(f), "grenades/%s.glb is a bomb's (GRENADE_FILES)" % f)


func test_every_replica_power_source_and_part_has_its_model_picture() -> void:
	var items := ItemPictures.new(pool, _pictures())
	var count := 0
	for list: Array[Pool.Item] in [pool.replicas, pool.powers, pool.parts]:
		for it in list:
			assert_not_null(items.texture(it), "%s has a picture from its model" % it.display_name)
			count += 1
	assert_gt(count, 0)


func test_a_bomb_icon_shows_its_model_when_there_is_one_and_the_flat_can_until_then() -> void:
	for kind: int in [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]:
		var icon := GrenadeGlyph.new(kind, 44.0)
		assert_false(icon.shows_model(), "nothing is drawn before the icon is in the tree")
		add_child_autofree(icon)
		var has_model := not ReplicaPictures.grenade_path(kind).is_empty()
		assert_eq(icon.shows_model(), has_model, "kind %d" % kind)
		assert_eq(icon.find_child("Pictures", false, false) != null, has_model, "a viewport only for a model")


func test_no_bomb_kind_has_a_model_name_for_none() -> void:
	assert_eq(ReplicaPictures.grenade_path(Grenade.Kind.NONE), "")


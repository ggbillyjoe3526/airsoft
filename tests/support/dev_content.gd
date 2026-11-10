class_name DevContent
extends RefCounted
## The shipped tables with one map or item tagged dev, for the tests of what dev content does (listed only with Dev
## content, off the records) on a known one: Woodland and its Weapon Torch (public since 2026-10-29), whatever the
## shipped tables tag dev (Subway, MT1). Each `use_` puts its table in the shared one's place and returns what was there; `restore_`
## puts that back. Test-only (tests/ never ships).


## Makes the shipped map catalogue with `map_id` tagged dev the shared one; returns the one it replaced (null when none
## was read yet).
static func use_map(map_id: String = "woodland") -> MapCatalog:
	var was := MapCatalog._shared
	var cat := MapCatalog.read_file()
	assert(cat.find(map_id) != null, "data/maps.md lists %s" % map_id)
	cat.find(map_id).tag = &"dev"
	MapCatalog._shared = cat
	return was


## Puts back the map catalogue `use_map()` replaced.
static func restore_map(was: MapCatalog) -> void:
	MapCatalog._shared = was


## Makes the shipped pool with item `item_id` tagged dev the shared one; returns the one it replaced (null when none
## was read yet).
static func use_item(item_id: String) -> Pool:
	var was := Pool._shared
	var pool := Pool.read_file()
	assert(pool.item(item_id) != null, "data/pool.md lists %s" % item_id)
	pool.item(item_id).access = &"dev"
	Pool._shared = pool
	return was


## Puts back the pool `use_item()` replaced.
static func restore_item(was: Pool) -> void:
	Pool._shared = was

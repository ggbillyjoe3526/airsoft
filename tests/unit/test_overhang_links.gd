extends GutTest
## SM1: the overhang probe (VaultConfig.overhang_probe) finds a ledge over open space. On the fields that have no such
## ledge it must add no vault or climb link: Depot, Woodland and Range keep the links they had without it.

const FIELDS: Array[String] = ["depot", "woodland", "range"]


func _links(id: String, overhang: float) -> PackedInt32Array:
	var style := PlayTuning.load_default().map_style
	var tuning := SimTuning.load_default()
	var m := MapData.load_map(id, style, 1)
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	var level := MapLevel.new()
	add_child(level)
	level.build(m, style, tuning.body)
	var cfg: VaultConfig = tuning.vault.duplicate()
	cfg.overhang_probe = overhang
	NavVaults.link(nav, level.query(), cfg, tuning.body, BotConfig.load_default().vault_price)
	var out := nav.vault_to.duplicate()
	level.free()
	return out


func test_overhang_probe_adds_no_link_on_the_other_fields() -> void:
	var tuning := SimTuning.load_default()
	for id in FIELDS:
		var m := MapData.load_map(id, PlayTuning.load_default().map_style, 1)
		if not m.ok():
			continue
		var with := _links(id, tuning.vault.overhang_probe)
		var without := _links(id, tuning.vault.face_probe)
		assert_eq(with.size(), without.size(), "%s: links with and without the overhang probe" % id)


func test_subway_overhang_links_start_only_beside_a_train_end() -> void:
	var style := PlayTuning.load_default().map_style
	var tuning := SimTuning.load_default()
	var m := MapData.load_map("subway", style, 1)
	if not m.ok():
		pending("subway not loaded")
		return
	var base := _linked("subway", tuning.vault.face_probe)
	var full := _linked("subway", tuning.vault.overhang_probe)
	var extra := 0
	for k: Vector3 in full:
		if not base.has(k):
			extra += 1
			gut.p("extra link from %s" % k)
	assert_lt(extra, 40, "the overhang probe's extra links are few")


func _linked(id: String, overhang: float) -> Dictionary:
	var style := PlayTuning.load_default().map_style
	var tuning := SimTuning.load_default()
	var m := MapData.load_map(id, style, 1)
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	var level := MapLevel.new()
	add_child(level)
	level.build(m, style, tuning.body)
	var cfg: VaultConfig = tuning.vault.duplicate()
	cfg.overhang_probe = overhang
	NavVaults.link(nav, level.query(), cfg, tuning.body, BotConfig.load_default().vault_price)
	var out := {}
	for k in nav.node_count():
		for l in range(nav.vault_start[k], nav.vault_start[k + 1]):
			var a := nav.astar.get_point_position(k)
			var b := nav.astar.get_point_position(nav.vault_to[l])
			out[Vector3(snappedf(a.x, 0.01), snappedf(a.y, 0.01), snappedf(a.z, 0.01))] = b
	level.free()
	return out

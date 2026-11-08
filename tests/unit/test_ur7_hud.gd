extends GutTest
## UR7: the HUD as UI concept B v2 `hud.png`: the weapon rail, the compact replica panel (BP8), and the score bar and the feed on rounded plates.

var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func _panel(c: Character) -> ReplicaPanel:
	var p := ReplicaPanel.new()
	add_child_autofree(p)
	p.setup(HudConfig.new())
	p.refresh(c.armament, c.grenades)
	return p


func _rail(c: Character) -> WeaponRail:
	var r := WeaponRail.new()
	add_child_autofree(r)
	var paints: Array[StringName] = []
	for i in c.armament.replicas.size():
		paints.append(&"cobalt")
	r.setup(c.armament.replicas, paints)
	r.refresh(c.armament, c.grenades)
	return r


func test_the_rail_has_a_row_per_replica_and_per_bomb_with_its_key() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	c.grenades.carry(1, 1)
	var r := _rail(c)
	assert_eq(r.rows(), c.armament.replicas.size() + 2)
	assert_eq(WeaponRail.key_text(&"slot_1"), "1")
	assert_eq(WeaponRail.key_text(&"throw_flash"), "5")
	assert_eq(WeaponRail.key_text(&"no_such_action"), KeyNames.NO_KEY)


func test_the_replica_in_hand_is_lit_and_a_swap_moves_the_light() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var r := _rail(c)
	assert_eq(r.lit(), c.armament.active)
	c.armament.active = 1
	r.refresh(c.armament, c.grenades)
	assert_eq(r.lit(), 1)
	c.armament.holstered = true
	r.refresh(c.armament, c.grenades)
	assert_eq(r.lit(), -1, "nothing is lit while holstered")


func test_a_bomb_in_hand_is_lit_and_one_with_none_left_is_dim() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	c.grenades.carry(1, 1)
	var r := _rail(c)
	var slots := c.armament.replicas.size()
	c.grenades.readied = Grenade.Kind.SMOKE
	r.refresh(c.armament, c.grenades)
	assert_eq(r.lit(), slots)
	c.grenades.readied = Grenade.Kind.NONE
	c.grenades.spend(Grenade.Kind.FLASH)
	r.refresh(c.armament, c.grenades)
	assert_lt(r._glyphs[1][0].self_modulate.a, r._glyphs[0][0].self_modulate.a, "the spent bomb is the dimmer")


func test_the_panel_no_longer_names_the_replica_or_shows_bombs() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var p := _panel(c)
	assert_null(p.find_child("ReplicaName", true, false))
	assert_null(p.find_child("Bombs", true, false))


func test_the_score_bar_draws_rounded_team_blocks_inside_its_plate() -> void:
	var bar := HudScore.new()
	add_child_autofree(bar)
	bar.setup(TeamConfig.new(), 5)
	for side in 2:
		var block: PackedVector2Array = bar._blocks[side]
		var top := INF
		var bottom := -INF
		for p: Vector2 in block:
			top = minf(top, p.y)
			bottom = maxf(bottom, p.y)
		assert_almost_eq(top, HudStyle.BLOCK_INSET, 0.01, "inset from the plate's top")
		assert_almost_eq(bottom, HudStyle.SCORE_HEIGHT - HudStyle.BLOCK_INSET, 0.01)
		assert_gt(block.size(), 4, "rounded corners")
	assert_eq(bar._plate.corner_radius_top_left, roundi(HudStyle.SCORE_RADIUS))


func test_rounded_rect_stays_inside_its_rect() -> void:
	var r := Rect2(10.0, 20.0, 64.0, 40.0)
	var pts := HudStyle.rounded_rect(r, 8.0)
	assert_eq(pts.size(), (HudStyle.CORNER_STEPS + 1) * 4)
	for p: Vector2 in pts:
		assert_true(r.grow(0.001).has_point(p), "%s inside" % p)
	assert_almost_eq(HudStyle.rounded_rect(r, 100.0)[0].y, r.position.y, 0.001, "the radius is held to half the side")


func test_a_feed_row_is_a_rounded_pill() -> void:
	var row := HudFeedRow.new()
	add_child_autofree(row)
	assert_eq(row._plate.corner_radius_top_left, HudFeedRow.RADIUS)
	assert_eq(row._frame.corner_radius_top_left, HudFeedRow.RADIUS)
	assert_false(row._frame.draw_center, "your lines' frame is an outline")


func test_the_magazine_boxes_sit_at_the_panel_s_left_edge() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var p := _panel(c)
	await wait_process_frames(2)
	var gauges := p.gauges()
	var row := gauges.get_global_rect()
	assert_almost_eq(row.size.x, gauges.row_width(gauges._count), 0.5, "as wide as its boxes")
	var frame := p.find_child("Frame", true, false) as Control
	assert_almost_eq(row.position.x, frame.get_global_rect().position.x + ReplicaPanel.PAD.x, 1.0, "at the panel's left edge")


func test_readying_a_bomb_does_not_move_the_panel() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	c.grenades.carry(1, 1)
	var p := _panel(c)
	await wait_process_frames(2)
	var tall := p.get_combined_minimum_size().y
	c.grenades.readied = Grenade.Kind.SMOKE
	p.refresh(c.armament, c.grenades)
	await wait_process_frames(2)
	p._status.visible = false
	assert_almost_eq(p.get_combined_minimum_size().y, tall, 0.5, "the same height with a bomb in hand")

extends GutTest
## UR7: the HUD as UI concept B v2 `hud.png`: the bombs as icons with the one in hand larger on a chip, the replica's
## name by its fire modes, and the score bar and the feed on rounded plates.

var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func _panel(c: Character) -> ReplicaPanel:
	var p := ReplicaPanel.new()
	add_child_autofree(p)
	p.setup(HudConfig.new())
	p.refresh(c.armament, c.grenades)
	return p


func test_each_bomb_is_an_icon_and_the_one_in_hand_is_larger_on_a_chip() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	c.grenades.carry(1, 1)
	var p := _panel(c)
	var smoke := p.bomb_icon(Grenade.Kind.SMOKE)
	var flash := p.bomb_icon(Grenade.Kind.FLASH)
	assert_eq(smoke.kind, Grenade.Kind.SMOKE)
	assert_eq(flash.kind, Grenade.Kind.FLASH)
	assert_eq(smoke.custom_minimum_size.x, ReplicaPanel.BOMB_ICON)
	c.grenades.readied = Grenade.Kind.SMOKE
	p.refresh(c.armament, c.grenades)
	assert_eq(smoke.custom_minimum_size.x, ReplicaPanel.BOMB_ICON_HELD, "the bomb in hand is larger")
	assert_eq(flash.custom_minimum_size.x, ReplicaPanel.BOMB_ICON)
	var chip := smoke.get_parent().get_parent() as PanelContainer
	assert_eq(chip.get_theme_stylebox("panel"), p._chip_held, "on a chip")
	c.grenades.readied = Grenade.Kind.NONE
	p.refresh(c.armament, c.grenades)
	assert_eq(smoke.custom_minimum_size.x, ReplicaPanel.BOMB_ICON, "back to size once put away")
	assert_eq(chip.get_theme_stylebox("panel"), p._chip_clear)


func test_a_bomb_with_none_left_is_dimmed() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	c.grenades.carry(1, 1)
	var p := _panel(c)
	c.grenades.spend(Grenade.Kind.FLASH)
	p.refresh(c.armament, c.grenades)
	assert_lt(p.bomb_icon(Grenade.Kind.FLASH).modulate.a, 1.0)
	assert_eq(p.bomb_icon(Grenade.Kind.SMOKE).modulate.a, 1.0)


func test_the_panel_names_the_replica_by_its_fire_modes() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var p := _panel(c)
	var label := p.find_child("ReplicaName", true, false) as Label
	assert_eq(label.text, c.armament.replica().display_name.to_upper())
	c.armament.active = 1 - c.armament.active
	p.refresh(c.armament, c.grenades)
	assert_eq(label.text, c.armament.replica().display_name.to_upper(), "follows a swap")


func test_the_bombs_sit_above_the_count() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	c.grenades.carry(1, 1)
	var p := _panel(c)
	await wait_process_frames(2)
	var bombs := p.find_child("Bombs", true, false) as Control
	assert_lt(bombs.get_global_rect().end.y, p._mag.get_global_rect().position.y + 1.0)


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


func test_the_magazine_boxes_sit_at_the_right_under_the_count() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var p := _panel(c)
	await wait_process_frames(2)
	var gauges := p.gauges()
	var row := gauges.get_global_rect()
	assert_almost_eq(row.size.x, gauges.row_width(gauges._count), 0.5, "as wide as its boxes")
	assert_almost_eq(row.end.x, p._spare.get_global_rect().end.x, 1.0, "right edge under the count's")


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

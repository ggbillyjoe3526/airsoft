extends GutTest
## UR7 QA: the replica panel's bombs and name, the score bar's rounded plate and blocks, and the feed's pills, at the
## edges: one fire mode, a long name, the counter off, no bombs, the HUD opacity and size, gauge patterns on either
## side and High contrast colours.

var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func _character(name_in: String = "", modes: Array[ReplicaConfig.FireMode] = []) -> Character:
	var replicas: Array[ReplicaConfig] = []
	for r in loadout:
		replicas.append(r.duplicate() as ReplicaConfig)
	if name_in != "":
		replicas[0].display_name = name_in
	if not modes.is_empty():
		replicas[0].fire_modes = modes
		replicas[0].default_fire_mode = modes[0]
	return Character.new(0, 0, Vector3.ZERO, 0.0, replicas)


func _panel(c: Character) -> ReplicaPanel:
	var p := ReplicaPanel.new()
	add_child_autofree(p)
	p.setup(HudConfig.new())
	p.refresh(c.armament, c.grenades)
	return p


func _bar(first: int = 0, teams: TeamConfig = null, count: int = 5) -> HudScore:
	var bar := HudScore.new()
	add_child_autofree(bar)
	bar.setup(teams if teams != null else TeamConfig.new(), count, first)
	return bar


func _inside(poly: PackedVector2Array, p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, poly) or Geometry2D.is_point_in_polygon(p + Vector2(0.01, 0.0), poly) \
			or Geometry2D.is_point_in_polygon(p - Vector2(0.01, 0.0), poly)


func test_a_one_mode_replica_shows_one_chip_and_its_name() -> void:
	var one: Array[ReplicaConfig.FireMode] = [ReplicaConfig.FireMode.SEMI]
	var c := _character("Plinker", one)
	var p := _panel(c)
	await wait_process_frames(2)
	var visible_chips := 0
	for chip in p._chips:
		if chip.visible:
			visible_chips += 1
	assert_eq(visible_chips, 1)
	var label := p.find_child("ReplicaName", true, false) as Label
	assert_eq(label.text, "PLINKER")
	assert_gt(label.size.x, 60.0, "with one chip the name has room")


func test_a_long_name_is_clipped_and_never_widens_the_panel() -> void:
	var all: Array[ReplicaConfig.FireMode] = [ReplicaConfig.FireMode.SEMI, ReplicaConfig.FireMode.BURST,
			ReplicaConfig.FireMode.AUTO]
	var c := _character("Extraordinarily Long Replica Display Name Mk Twelve", all)
	c.grenades.carry(12, 12)
	c.grenades.readied = Grenade.Kind.SMOKE
	var p := _panel(c)
	await wait_process_frames(3)
	var frame := p.find_child("ReplicaName", true, false).get_parent().get_parent().get_parent() as Control
	assert_almost_eq(frame.size.x, ReplicaPanel.WIDTH, 0.5, "held at its width with 3 chips, a long name, 2-digit bombs")
	assert_lte(p.size.x, ReplicaPanel.WIDTH + 0.5)
	var label := p.find_child("ReplicaName", true, false) as Label
	assert_true(label.clip_text)
	assert_gt(label.size.x, 0.0, "some of the name still shows")
	for chip in p._chips:
		assert_gte(chip.get_global_rect().end.x, 0.0)
		assert_lte(chip.get_global_rect().end.x, frame.get_global_rect().end.x + 0.5, "chips stay inside the panel")


func test_the_counter_off_keeps_the_bombs_the_name_and_the_chips() -> void:
	var c := _character()
	c.grenades.carry(2, 1)
	var p := _panel(c)
	p.set_counted(false)
	p.refresh(c.armament, c.grenades)
	await wait_process_frames(2)
	assert_false(p.counted())
	assert_true((p.find_child("Bombs", true, false) as Control).is_visible_in_tree(), "bombs are not BB counts")
	assert_true((p.find_child("ReplicaName", true, false) as Control).is_visible_in_tree())
	assert_eq(p.bomb_texts()[Grenade.Kind.SMOKE], "SMOKE 2")


func test_zero_bombs_carried_dims_both_and_shows_zeroes() -> void:
	var c := _character()
	c.grenades.carry(0, 0)
	var p := _panel(c)
	assert_eq(p._bombs[Grenade.Kind.SMOKE].text, "0")
	assert_eq(p._bombs[Grenade.Kind.FLASH].text, "0")
	assert_lt(p.bomb_icon(Grenade.Kind.SMOKE).modulate.a, 1.0)
	assert_lt(p.bomb_icon(Grenade.Kind.FLASH).modulate.a, 1.0)


func test_a_refilled_bomb_lights_again() -> void:
	var c := _character()
	c.grenades.carry(1, 1)
	var p := _panel(c)
	c.grenades.spend(Grenade.Kind.SMOKE)
	p.refresh(c.armament, c.grenades)
	assert_lt(p.bomb_icon(Grenade.Kind.SMOKE).modulate.a, 1.0)
	c.grenades.refill()
	p.refresh(c.armament, c.grenades)
	assert_eq(p.bomb_icon(Grenade.Kind.SMOKE).modulate.a, 1.0, "a respawn brings the bomb back to full")


func test_the_last_bomb_in_hand_stays_large_on_its_chip_and_dims_once_thrown() -> void:
	var c := _character()
	c.grenades.carry(1, 1)
	c.grenades.readied = Grenade.Kind.FLASH
	var p := _panel(c)
	c.grenades.spend(Grenade.Kind.FLASH)
	p.refresh(c.armament, c.grenades)
	assert_eq(p.bomb_icon(Grenade.Kind.FLASH).custom_minimum_size.x, ReplicaPanel.BOMB_ICON_HELD)
	assert_lt(p.bomb_icon(Grenade.Kind.FLASH).modulate.a, 1.0)
	c.grenades.readied = Grenade.Kind.NONE
	p.refresh(c.armament, c.grenades)
	assert_eq(p.bomb_icon(Grenade.Kind.FLASH).custom_minimum_size.x, ReplicaPanel.BOMB_ICON)


func test_the_panel_without_a_hand_shows_no_stale_counts() -> void:
	var c := _character()
	var p := ReplicaPanel.new()
	add_child_autofree(p)
	p.setup(HudConfig.new())
	p.refresh(c.armament)
	for text: String in p.bomb_texts():
		assert_eq(text, "", "no hand, no bomb words")


func test_the_score_plate_takes_the_panel_opacity() -> void:
	var bar := _bar()
	HudStyle.restyle(bar, 0.4)
	await wait_process_frames(2)
	assert_almost_eq(bar._plate.bg_color.a, HudStyle.BACKING_SIDE * 0.4, 0.001)
	HudStyle.restyle(bar, 1.0)
	await wait_process_frames(2)
	assert_almost_eq(bar._plate.bg_color.a, HudStyle.BACKING_SIDE, 0.001)


func test_a_feed_pill_takes_the_panel_opacity() -> void:
	var row := HudFeedRow.new()
	add_child_autofree(row)
	var who := HudFeedRow.Who.new()
	who.text = "Owl"
	row.show_line(who, who, Color.RED, Color.BLUE, true)
	HudStyle.restyle(row, 0.3)
	await wait_process_frames(2)
	assert_almost_eq(row._plate.bg_color.a, HudStyle.BACKING_CLOCK * 0.3, 0.001)
	assert_true(row._frame.draw_center == false)


func test_a_scaled_score_bar_keeps_its_plate_the_size_of_the_bar() -> void:
	var bar := _bar()
	bar.scale = Vector2.ONE * 1.5
	assert_eq(bar.custom_minimum_size.y, HudStyle.SCORE_HEIGHT)
	for side in 2:
		var rect := Rect2()
		var first := true
		for p: Vector2 in bar._blocks[side]:
			rect = Rect2(p, Vector2.ZERO) if first else rect.expand(p)
			first = false
		assert_true(Rect2(Vector2.ZERO, bar.custom_minimum_size).encloses(rect), "block %d inside the plate" % side)


func test_blocks_sit_inside_the_plate_for_any_pip_count_and_either_end() -> void:
	for count: int in [1, 3, 7, 12]:
		for first in 2:
			var bar := _bar(first, null, count)
			var plate := Rect2(Vector2.ZERO, bar.custom_minimum_size)
			for side in 2:
				for p: Vector2 in bar._blocks[side]:
					assert_true(plate.grow(0.001).has_point(p), "count %d first %d side %d" % [count, first, side])
			assert_ne(bar.block_x(0), bar.block_x(1))


func test_the_stripes_stay_inside_the_rounded_block_on_either_side() -> void:
	for first in 2:
		var bar := _bar(first)
		bar.set_patterned(true)
		bar.set_score(3, 3)
		var block: PackedVector2Array = bar._blocks[HudStyle.STRIPED_TEAM]
		var lines: PackedVector2Array = bar._block_stripes.lines
		assert_gt(lines.size(), 4, "first %d: the block has stripes" % first)
		for p: Vector2 in lines:
			assert_true(_inside(block, p), "first %d: %s inside the rounded block" % [first, p])


func test_the_unstriped_team_s_block_has_no_stripes_and_the_pips_follow_the_beta_side() -> void:
	var bar := _bar(1)
	bar.set_patterned(true)
	assert_true(bar.striped(1))
	assert_false(bar.striped(0))
	bar.set_patterned(false)
	assert_false(bar.striped(1))
	assert_eq(bar._score_labels[HudStyle.STRIPED_TEAM].get_theme_constant("outline_size"), 0, "edge taken off")


func test_the_stripes_are_not_rebuilt_by_a_draw() -> void:
	var bar := _bar()
	bar.set_patterned(true)
	var builds: int = bar._block_stripes.builds
	await wait_process_frames(3)
	bar.set_score(1, 2)
	await wait_process_frames(2)
	assert_eq(bar._block_stripes.builds, builds)


func test_high_contrast_colours_keep_the_number_legible_on_the_rounded_blocks() -> void:
	var hc := TeamColours.resolve(TeamColours.Set.HIGH_CONTRAST, false).hud
	for first in 2:
		var bar := _bar(first, hc)
		bar.set_patterned(true)
		for side in 2:
			var label: Label = bar._score_labels[side]
			assert_eq(label.get_theme_color("font_color"), HudStyle.ink_on(hc.colours[side]))
		await wait_process_frames(2)
		assert_eq(bar._teams, hc)


func test_the_ref_shape_of_a_tiny_or_zero_rect_does_not_break_the_outline() -> void:
	var zero := HudStyle.rounded_rect(Rect2(5.0, 5.0, 0.0, 0.0), 8.0)
	for p: Vector2 in zero:
		assert_false(is_nan(p.x) or is_nan(p.y))
	var thin := HudStyle.rounded_rect(Rect2(0.0, 0.0, 40.0, 3.0), 8.0)
	for p: Vector2 in thin:
		assert_true(Rect2(0.0, 0.0, 40.0, 3.0).grow(0.001).has_point(p))


func test_the_attack_defend_tags_rest_on_their_blocks() -> void:
	var bar := _bar()
	bar.set_sides(0)
	for side in 2:
		var tag: Label = bar._tags[side]
		assert_almost_eq(tag.position.x, bar.block_x(side), 0.001)
		assert_almost_eq(tag.position.y + tag.size.y, HudStyle.BLOCK_INSET, 0.01, "the tag rests on its block's top edge")

extends GutTest
## UR7 QA: the replica panel, the score bar's rounded plate and blocks, and the feed's pills, at the
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


func test_a_one_mode_replica_shows_one_chip() -> void:
	var one: Array[ReplicaConfig.FireMode] = [ReplicaConfig.FireMode.SEMI]
	var c := _character("Plinker", one)
	var p := _panel(c)
	await wait_process_frames(2)
	var visible_chips := 0
	for chip in p._chips:
		if chip.visible:
			visible_chips += 1
	assert_eq(visible_chips, 1)
	assert_null(p.find_child("ReplicaName", true, false), "the name is the rail's business now (BP8): none in the panel")


func test_the_panel_holds_its_width_with_three_chips_and_big_counts() -> void:
	var all: Array[ReplicaConfig.FireMode] = [ReplicaConfig.FireMode.SEMI, ReplicaConfig.FireMode.BURST,
			ReplicaConfig.FireMode.AUTO]
	var c := _character("Extraordinarily Long Replica Display Name Mk Twelve", all)
	c.grenades.carry(12, 12)
	c.grenades.readied = Grenade.Kind.SMOKE
	var p := _panel(c)
	await wait_process_frames(3)
	var frame := _frame_of(p)
	assert_almost_eq(frame.size.x, ReplicaPanel.WIDTH, 0.5, "held at its width with 3 chips")
	assert_lte(p.size.x, ReplicaPanel.WIDTH + 0.5)
	for chip in p._chips:
		assert_gte(chip.get_global_rect().end.x, 0.0)
		assert_lte(chip.get_global_rect().end.x, frame.get_global_rect().end.x + 0.5, "chips stay inside the panel")


func test_the_counter_off_keeps_the_chips() -> void:
	var c := _character()
	var p := _panel(c)
	p.set_counted(false)
	p.refresh(c.armament, c.grenades)
	await wait_process_frames(2)
	assert_false(p.counted())
	var shown := 0
	for chip in p._chips:
		if chip.is_visible_in_tree():
			shown += 1
	assert_eq(shown, c.armament.replica().fire_modes.size(), "a chip for each fire mode the replica offers")
	assert_false(p._counts.visible, "and the counts are the part that went")


func test_the_fire_chips_sit_beside_a_few_boxes_and_under_many() -> void:
	var few := _panel(_mags_character(2))
	await wait_process_frames(3)
	var box_row := few.gauges().get_global_rect()
	for chip in few._chips:
		if chip.visible:
			assert_eq(chip.get_parent(), few._foot, "beside the boxes")
			assert_gte(chip.get_global_rect().position.x, box_row.end.x, "to their right")
	var many := _panel(_mags_character(6))
	await wait_process_frames(3)
	var boxes := many.gauges().get_global_rect()
	var frame := _frame_of(many).get_global_rect()
	for chip in many._chips:
		if chip.visible:
			assert_eq(chip.get_parent(), many._chip_row, "in a row of their own")
			assert_gte(chip.get_global_rect().position.y, boxes.end.y, "under the boxes")
			assert_lte(chip.get_global_rect().end.x, frame.end.x + 0.5, "inside the panel")
	assert_almost_eq(frame.size.x, ReplicaPanel.WIDTH, 0.5)


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


## UR8 QA: the magazine boxes at the panel's left edge, at the edges.
func _mags_character(mags: int, name_in: String = "") -> Character:
	var replicas: Array[ReplicaConfig] = []
	for r in loadout:
		replicas.append(r.duplicate() as ReplicaConfig)
	replicas[0].mags = mags
	if name_in != "":
		replicas[0].display_name = name_in
	return Character.new(0, 0, Vector3.ZERO, 0.0, replicas)


func _frame_of(p: ReplicaPanel) -> Control:
	return p.find_child("Frame", false, false) as Control


func test_ur8_the_boxes_stay_at_the_left_edge_with_the_ammo_counter_off() -> void:
	var p := _panel(_mags_character(4))
	p.set_counted(false)
	await wait_process_frames(3)
	var gauges := p.gauges()
	assert_almost_eq(gauges.get_global_rect().position.x, _frame_of(p).get_global_rect().position.x + ReplicaPanel.PAD.x, 1.0)
	assert_almost_eq(gauges.size.x, gauges.row_width(4), 0.5, "the counts' row going away does not stretch the boxes")
	assert_true(gauges.get_global_rect().position.x < _frame_of(p).get_global_rect().get_center().x)


func test_ur8_a_replica_swap_with_another_magazine_count_resizes_the_row_from_the_left() -> void:
	var replicas: Array[ReplicaConfig] = []
	for r in loadout:
		replicas.append(r.duplicate() as ReplicaConfig)
	replicas[0].mags = 2
	replicas[1].mags = 7
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, replicas)
	var p := _panel(c)
	await wait_process_frames(3)
	var gauges := p.gauges()
	var left := gauges.get_global_rect().position.x
	assert_almost_eq(gauges.size.x, gauges.row_width(2), 0.5)
	c.armament.active = 1
	p.refresh(c.armament, c.grenades)
	await wait_process_frames(3)
	assert_almost_eq(gauges.size.x, gauges.row_width(7), 0.5, "wider for seven boxes")
	assert_almost_eq(gauges.get_global_rect().position.x, left, 0.5, "the left edge does not move")
	c.armament.active = 0
	p.refresh(c.armament, c.grenades)
	await wait_process_frames(3)
	assert_almost_eq(gauges.size.x, gauges.row_width(2), 0.5, "and back, not left wide")
	assert_almost_eq(_frame_of(p).size.x, ReplicaPanel.WIDTH, 0.5)


func test_ur8_up_to_six_magazines_fit_inside_the_panel() -> void:
	# the data caps a replica at 6 magazines; the chips drop under the boxes once they would not fit beside them
	for n: int in [1, 2, 3, 6]:
		var p := _panel(_mags_character(n))
		await wait_process_frames(3)
		var frame := _frame_of(p).get_global_rect()
		var row := p.gauges().get_global_rect()
		assert_gte(row.position.x, frame.position.x + ReplicaPanel.PAD.x - 0.5, "%d mags: inside the left padding" % n)
		assert_lte(row.end.x, frame.end.x - ReplicaPanel.PAD.z + 0.5, "%d mags: inside the right padding" % n)
		assert_almost_eq(frame.size.x, ReplicaPanel.WIDTH, 0.5, "%d mags: panel keeps its width" % n)


func test_ur8_many_magazines_never_draw_outside_the_panel() -> void:
	# 10 or more boxes need over 150 px: the panel widens (as before UR8) rather than draw them outside; the data caps at 6
	var p := _panel(_mags_character(14))
	await wait_process_frames(3)
	var frame := _frame_of(p).get_global_rect()
	var row := p.gauges().get_global_rect()
	assert_lte(row.end.x, frame.end.x + 0.5, "the row ends inside the panel: %s in %s" % [row, frame])
	assert_gte(row.position.x, frame.position.x - 0.5, "and starts inside it")


func test_ur8_no_replicas_leaves_the_row_empty_and_at_the_left() -> void:
	var empty: Array[ReplicaConfig] = []
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, empty)
	var p := ReplicaPanel.new()
	add_child_autofree(p)
	p.setup(HudConfig.new())
	p.gauges().refresh(c.armament)
	await wait_process_frames(2)
	assert_eq(p.gauges().size.x, 0.0)
	assert_eq(p.gauges().custom_minimum_size.x, 0.0)
	assert_false(is_nan(p.gauges().get_global_rect().position.x))


func test_ur8_a_hud_at_150_percent_keeps_the_boxes_inside_the_scaled_panel() -> void:
	var holder := Control.new()
	holder.size = Vector2(1920.0, 1080.0)
	add_child_autofree(holder)
	Hud.scale_root(holder, 1.5)
	var p := ReplicaPanel.new()
	holder.add_child(p)
	p.setup(HudConfig.new())
	var c := _mags_character(6)
	p.refresh(c.armament, c.grenades)
	await wait_process_frames(3)
	var frame := _frame_of(p).get_global_rect()
	var row := p.gauges().get_global_rect()
	assert_almost_eq(row.position.x, frame.position.x + ReplicaPanel.PAD.x * 1.5, 1.0, "at the panel's left padding")
	assert_gte(row.position.x, frame.position.x - 0.5)
	assert_lte(row.end.x, frame.end.x + 0.5)
	assert_almost_eq(row.size.x, p.gauges().row_width(6) * 1.5, 1.0, "scaled with the HUD")

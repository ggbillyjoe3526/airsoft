extends GutTest
## QA hunt for AR1: the page's staleness against the Dev content switch, what opening and leaving leaves behind, and the
## card's edges.

var pool: Pool
var table: LevelTable
var settings: Settings


func before_all() -> void:
	pool = Pool.read_file()
	table = LevelTable.read_file(pool)


func before_each() -> void:
	settings = Settings.new()


func _progress(xp: int) -> Progress:
	var p := Progress.new(table)
	p.from_dict({"xp": xp})
	p.grant_reached()
	return p


func test_turning_dev_content_on_makes_an_open_page_stale() -> void:
	var page := ArmoryPage.new(settings, _progress(100), Records.new(), pool)
	add_child_autofree(page)
	assert_false(page.stale())
	settings.dev.dev_content = true
	assert_true(page.stale(), "dev items would now be listed; the page should be built again")


func test_opening_and_leaving_the_armory_leaves_no_nodes_behind() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), settings)
	add_child_autofree(menus)
	menus.show_armory()
	menus.show_match()
	await wait_process_frames(3)
	var before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 4:
		menus.show_armory()
		menus.show_armory()
		await wait_process_frames(2)
		menus.show_match()
		await wait_process_frames(3)
	assert_null(menus.armory_page())
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), before)


func test_a_card_freed_leaves_no_nodes_behind() -> void:
	var p := _progress(0)
	var o := MatchXp.Outcome.new()
	o.won = true
	o.rounds_won = 5
	o.hits = 9
	o.difficulty = &"normal"
	var before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 3:
		var s := PlayerTally.Settled.new()
		s.earned = MatchXp.earned(table, o)
		s.level_up = p.add_xp(s.earned.total)
		var card := XpCard.new(s, p, pool)
		add_child(card)
		await wait_process_frames(2)
		card.queue_free()
		await wait_process_frames(3)
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), before)


func test_a_card_with_levelling_off_and_no_earned_does_not_crash() -> void:
	var s := PlayerTally.Settled.new()
	s.why_none = "XP_NONE_DEV"
	var card := XpCard.new(s, _progress(0), pool)
	add_child_autofree(card)
	assert_gt(card.find_children("*", "Label", true, false).size(), 0)


func test_a_page_at_a_small_and_a_huge_window_lays_out() -> void:
	var host := Control.new()
	add_child_autofree(host)
	var page := ArmoryPage.new(settings, _progress(1500), Records.new(), pool)
	host.add_child(page)
	for size: Vector2 in [Vector2(640, 360), Vector2(3840, 2160)]:
		host.size = size
		await wait_process_frames(2)
		assert_eq(page.size, size)
		assert_gt(page.track().size.x, 0.0)

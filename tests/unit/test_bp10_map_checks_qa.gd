extends GutTest
## The Match page's kept map checks (BP10): each field's refused/pole result is read once per size and style, equals
## MatchOptions.map_check, and a second page lists the same without reading again.


func _page(dev_content: bool) -> MatchPage:
	var settings := Settings.new()
	settings.dev.dev_content = dev_content
	var picks := MatchPicks.new()
	var page := MatchPage.new(picks, settings)
	add_child_autofree(page)
	return page


func _bits(id: String, style: MapStyle, size: int) -> int:
	var m := MatchOptions.map_check(id, style, size)
	return (MatchPage.CHECK_REFUSED if not m.problems.is_empty() else 0) | (MatchPage.CHECK_POLE if m.has_pole else 0)


func test_the_kept_check_equals_map_check_for_every_field_at_its_sizes() -> void:
	var style := PlayTuning.load_default().map_style
	var catalog := MapCatalog.shared()
	for e: MapCatalog.Entry in catalog.listed(true):
		var sizes: Array[int] = [MatchOptions.team_size(e, null), MatchOptions.check_size(e, 2), MatchOptions.check_size(e, 8)]
		for size: int in sizes:
			assert_eq(MatchPage._check(e.id, style, size), _bits(e.id, style, size), "%s at %d" % [e.id, size])


func test_a_missing_map_stays_refused() -> void:
	var style := PlayTuning.load_default().map_style
	assert_eq(MatchPage._check("ghost", style, 5) & MatchPage.CHECK_REFUSED, MatchPage.CHECK_REFUSED)
	assert_eq(MatchPage._check("ghost", style, 5) & MatchPage.CHECK_REFUSED, MatchPage.CHECK_REFUSED, "second ask")


func test_another_size_or_style_gets_its_own_entry() -> void:
	var style := PlayTuning.load_default().map_style
	var other := MapStyle.new()
	var before := MatchPage._checks.size()
	MatchPage._check("depot", style, 3)
	MatchPage._check("depot", style, 4)
	MatchPage._check("depot", other, 3)
	assert_gte(MatchPage._checks.size(), before + 2, "size and style key apart (the first may already be kept)")
	var n := MatchPage._checks.size()
	MatchPage._check("depot", other, 3)
	assert_eq(MatchPage._checks.size(), n, "asking again adds nothing")


func test_a_second_page_adds_no_entries_and_lists_the_same() -> void:
	var first := _page(true)
	var n := MatchPage._checks.size()
	var second := _page(true)
	assert_eq(MatchPage._checks.size(), n)
	assert_eq(second.map_ids(), first.map_ids())
	for id in first.map_ids():
		assert_eq(second.is_unloadable(id), first.is_unloadable(id), id)
		assert_eq(second.map_card(id).disabled, first.map_card(id).disabled, id)
	assert_eq(second.says_needs_pole("attack_defend"), first.says_needs_pole("attack_defend"))


func test_the_page_greys_and_marks_poles_as_map_check_says() -> void:
	var page := _page(true)
	var style := PlayTuning.load_default().map_style
	for id in page.map_ids():
		var e := MapCatalog.shared().find(id)
		var m := MatchOptions.map_check(id, style, MatchOptions.team_size(e, null))
		assert_eq(page.is_unloadable(id), not m.problems.is_empty(), id)
		assert_eq(page.map_card(id).disabled, not m.problems.is_empty(), id)


func test_the_pole_tag_follows_the_kept_pole_bit() -> void:
	var page := _page(false)
	var depot := MapCatalog.shared().find("depot")
	assert_true(MatchPage._check("depot", PlayTuning.load_default().map_style, MatchOptions.team_size(depot, null)) \
			& MatchPage.CHECK_POLE != 0)
	assert_false(page.says_needs_pole("attack_defend"), "Depot has a pole")


func test_a_later_page_after_a_cached_ghost_still_greys_it() -> void:
	var page := _page(true)
	page._catalog = MapCatalog.parse(FileAccess.get_file_as_string(MapCatalog.PATH).replace(
			"| range | Range |", "| ghost | Ghost | field | public | 5 | 5 | 6 | No file yet. |\n| range | Range |"))
	page._offered = PackedStringArray()
	page._list_maps()
	assert_true(page.is_unloadable("ghost"))
	page._offered = PackedStringArray()
	page._list_maps()
	assert_true(page.is_unloadable("ghost"), "from the kept check")

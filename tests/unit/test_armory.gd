extends GutTest
## The Armory and the XP at the end of a match (AR1; concepts step11-armory): what the page lists at a level, with levelling
## off and at the cap, the load messages, the pictures drawn from the items' own models, the page freed when the tab is
## left, and the end-of-match XP lines, the level-up card and the match that gave none.

const SILENCER := "000018"
const RED_DOT := "000007"
const CYBER := "000019"

var pool: Pool
var table: LevelTable
var settings: Settings


func before_all() -> void:
	pool = Pool.read_file()
	table = LevelTable.read_file(pool)


func before_each() -> void:
	settings = Settings.new()


func after_each() -> void:
	# pages a menu freed are let go at the end of a frame
	await wait_process_frames(2)


func _progress(xp: int) -> Progress:
	var p := Progress.new(table)
	p.from_dict({"xp": xp})
	p.grant_reached()
	return p


func _page(xp: int, off: bool = false, progress: Progress = null, records: Records = null) -> ArmoryPage:
	settings.dev.disable_levelling = off
	var page := ArmoryPage.new(settings, progress if progress != null else _progress(xp),
			records if records != null else Records.new(), pool)
	add_child_autofree(page)
	return page


func _words(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for l in root.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func _item(id: String) -> Pool.Item:
	return pool.item(id)


# --- what it lists ---

func test_the_armory_tab_is_on_and_opens_the_page_it_frees_when_left() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), settings)
	add_child_autofree(menus)
	assert_false(menus.top_bar().tab_button(TopBar.Tab.ARMORY).disabled)
	assert_eq(TopBar.LATER_TABS.size(), 0)
	assert_null(menus.armory_page(), "built when asked for")
	menus.show_armory()
	var page := menus.armory_page()
	assert_not_null(page)
	assert_eq(menus.top_bar().current(), TopBar.Tab.ARMORY)
	assert_eq(menus.page_tab(), TopBar.Tab.ARMORY)
	assert_false(menus.match_page().visible)
	var pictures := page.pictures()
	menus.show_match()
	await wait_process_frames(2)
	assert_null(menus.armory_page())
	assert_false(is_instance_valid(page), "the page is freed")
	assert_false(is_instance_valid(pictures), "and the pictures it drew")
	assert_true(menus.match_page().visible)


func test_level_3_lists_ten_of_twenty_with_the_silencer_next() -> void:
	var page := _page(920)
	var facts := page.facts()
	assert_eq(facts.level, 3)
	assert_eq([facts.unlocked_count, facts.item_count], [10, 20], "the Weapon Torch is listed: public since 2026-10-29")
	assert_eq(facts.next_row().number, 4)
	assert_eq(facts.next_row().items[0].id, SILENCER)
	var states: Array[ArmoryFacts.State] = []
	for r in facts.rows:
		states.append(r.state)
	assert_eq(states.slice(0, 5), [ArmoryFacts.State.UNLOCKED, ArmoryFacts.State.UNLOCKED,
			ArmoryFacts.State.UNLOCKED, ArmoryFacts.State.UNLOCKED, ArmoryFacts.State.NEXT] as Array[ArmoryFacts.State])
	assert_eq(states[5], ArmoryFacts.State.LOCKED)
	assert_eq(states.size(), 11)
	var words := _words(page.summary())
	for w: String in ["LEVEL ", "3", "of 10", "120 / 500 XP", "380 XP to level 4", "920", "10 / 20", "NEXT UNLOCK · LEVEL 4",
			"Silencer", "HOW XP IS EARNED", "100 XP", "100 more", "20", "10"]:
		assert_true(words.has(w), w)
	# the multipliers in one row, the rest its tooltip (UI1)
	assert_true(words.has("Difficulty"))
	assert_true(words.has("Easy ×0.5 · Normal ×1 · Hard ×1.5"))
	var difficulty := page.summary().find_child("Difficulty", true, false) as Control
	assert_eq(difficulty.tooltip_text, "Then times the difficulty: Easy ×0.5 · Normal ×1 · Hard ×1.5. A first-to-5 win on Normal gives about 250 XP. Practice, and matches with Dev settings, give none.")
	var track := _words(page.track())
	for w: String in ["LEVELS", "STARTING KIT", "LEVEL 1", "100 XP · UNLOCKED", "1,300 XP · NEXT", "1,900 XP · LOCKED",
			"6,500 XP · LOCKED", "Red Dot", "Cyber Pistol", "REPLICA", "POWER", "MUZZLE"]:
		assert_true(track.has(w), w)
	assert_almost_eq(page.summary().bar().fraction(), 120.0 / 500.0, 0.001)


func test_level_1_and_a_new_player_list_the_start_and_the_first_unlock() -> void:
	var page := _page(100)
	assert_eq(page.facts().level, 1)
	assert_eq(page.facts().next_row().number, 2)
	assert_true(_words(page.summary()).has("NEXT UNLOCK · LEVEL 2"))
	assert_eq(page.track().row(0).find_children("Item_*", "PanelContainer", true, false).size(), 5,
			"the starting kit: two replicas, two power sources and the Weapon Torch")
	var fresh := _page(0)
	assert_eq(fresh.facts().next_row().number, 1)
	assert_true(_words(fresh.summary()).has("0 / 100 XP"))


func test_at_the_cap_it_says_xp_stops_counting_and_nothing_is_next() -> void:
	var page := _page(6500)
	var facts := page.facts()
	assert_eq(facts.level, 10)
	assert_null(facts.next_row())
	assert_eq(facts.unlocked_count, 20)
	var words := _words(page.summary())
	assert_true(words.has("Top level reached"))
	assert_true(words.has("XP counts again when the level cap goes up."))
	assert_true(words.has("Nothing left"))
	assert_eq(page.summary().bar().fraction(), 1.0)
	assert_eq(page.track().row(10).find_children("Item_*", "PanelContainer", true, false).size(), 1)


func test_with_levelling_off_everything_is_unlocked() -> void:
	var page := _page(920, true)
	var facts := page.facts()
	assert_true(facts.levelling_off)
	assert_eq([facts.unlocked_count, facts.item_count], [20, 20])
	assert_null(facts.next_row())
	for r in facts.rows:
		assert_eq(r.state, ArmoryFacts.State.UNLOCKED)
	var words := _words(page.summary())
	assert_true(words.has("ALL UNLOCKED"))
	assert_null(page.summary().bar(), "no level bar while levelling is off")
	assert_false(_words(page.track()).has("1,900 XP · LOCKED"))
	assert_true(_words(page.track()).has("1,900 XP · UNLOCKED"))


func test_dev_items_are_listed_only_with_dev_content_and_waiting_ones_never() -> void:
	var tiny := Pool.parse("""### Replicas

| ID | Name | Key | Tags | Access |
|---|---|---|---|---|
| 000001 | GBB Pistol | pistol | pistol, gas | public |
| 000099 | Dev Pistol | pistol | pistol | dev |
""")
	var levels := LevelTable.parse("""| Level | XP | Unlocks |
|---|---|---|
| 0 | 0 | GBB Pistol, Dev Pistol |
""", tiny)
	assert_eq(ArmoryFacts.new(levels, tiny, 0, false, false).item_count, 1)
	assert_eq(ArmoryFacts.new(levels, tiny, 0, false, true).item_count, 2)


# --- pictures ---

func test_every_item_has_its_own_model_picture_and_a_blurb() -> void:
	var page := _page(6500)
	await wait_process_frames(2)
	var shown := 0
	for r in page.facts().rows:
		for it in r.items:
			var chip := page.track().row(r.number).find_child("Item_%s" % it.id, true, false) as Control
			assert_not_null(chip, it.display_name)
			var pic := chip.find_child("Picture", true, false) as TextureRect
			assert_not_null(pic.texture, "%s has a picture" % it.display_name)
			var blurb := ArmoryFacts.blurb(it)
			assert_ne(blurb, "", it.display_name)
			assert_false(blurb.begins_with("PART_BLURB") or blurb.begins_with("ARMORY_BLURB"), it.display_name)
			shown += 1
	assert_eq(shown, 20)


func test_every_power_source_has_a_model_entry_and_a_gas_bottle_takes_its_own_label() -> void:
	for pw in pool.powers:
		assert_true(PowerModels.has(pw.id), "%s needs a PowerModels entry" % pw.display_name)
		assert_true(ResourceLoader.exists("%s%s.glb" % [ReplicaPictures.POWER_DIR, PowerModels.file(pw.id)]))
	assert_ne(PowerModels.label("000004"), PowerModels.label("000008"))
	assert_eq(PowerModels.tip("000004"), 0.0, "the bottle stands")
	assert_gt(PowerModels.tip("000003"), 0.0, "a battery is tipped up")
	assert_eq(PowerModels.file("999999"), &"")
	var pictures := ReplicaPictures.new()
	add_child_autofree(pictures)
	assert_not_null(pictures.power_texture(PowerModels.file("000004"), PowerModels.label("000004")))
	assert_null(pictures.power_texture(&"noSuchFile", Color.WHITE))


func test_a_power_picture_leaves_the_files_shared_label_material_alone() -> void:
	var pictures := ReplicaPictures.new()
	add_child_autofree(pictures)
	pictures.power_texture(PowerModels.file("000004"), PowerModels.label("000004"))
	pictures.power_texture(PowerModels.file("000008"), PowerModels.label("000008"))
	var scene := load("%s%s.glb" % [ReplicaPictures.POWER_DIR, PowerModels.file("000004")]) as PackedScene
	var model := scene.instantiate() as Node3D
	var untouched := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i) as BaseMaterial3D
			if mat != null and mat.resource_name == ReplicaPictures.LABEL_MATERIAL:
				untouched = untouched and mat.albedo_color != PowerModels.label("000008") \
						and mat.albedo_color != PowerModels.label("000004")
	model.free()
	assert_true(untouched, "each picture paints its own copy")


func test_the_next_unlock_has_its_picture() -> void:
	var page := _page(920)
	await wait_process_frames(2)
	var pic := page.summary().find_child("NextPicture", true, false) as TextureRect
	assert_not_null(pic.texture)


# --- load messages and staleness ---

func test_a_progress_or_records_file_that_could_not_be_used_is_said() -> void:
	var clean := _page(0)
	assert_eq(clean.notice_text(), "")
	var p := _progress(0)
	p.load_message = "Your level couldn't be read."
	var r := Records.new()
	r.load_message = "Your records couldn't be read."
	var both := _page(0, false, p, r)
	assert_true(both.notice_text().contains("Your level couldn't be read."))
	assert_true(both.notice_text().contains("Your records couldn't be read."))
	var only_records := _page(0, false, null, r)
	assert_eq(only_records.notice_text(), "Your records couldn't be read.")


func test_the_real_damaged_messages_show() -> void:
	var p := _progress(0)
	p.load_message = TranslationServer.translate("PROGRESS_DAMAGED")
	assert_true(_page(0, false, p).notice_text().begins_with("Your level couldn't be read"))


func test_the_page_notices_a_changed_level_or_levelling() -> void:
	var p := _progress(100)
	var page := _page(0, false, p)
	assert_false(page.stale())
	p.add_xp(300)
	assert_true(page.stale())
	var other := _page(100)
	settings.dev.disable_levelling = true
	assert_true(other.stale())


func test_a_changed_level_builds_the_open_page_again() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), settings)
	add_child_autofree(menus)
	menus.show_armory()
	var first := menus.armory_page()
	menus.show_level()
	assert_eq(menus.armory_page(), first, "nothing changed: the same page")
	settings.dev.disable_levelling = true
	menus.show_level()
	assert_ne(menus.armory_page(), first)
	assert_true(menus.armory_page().facts().levelling_off)
	menus.show_loadout()
	assert_null(menus.armory_page(), "the Loadout tab frees it")
	settings.dev.disable_levelling = false


# --- small words ---

func test_numbers_read_as_the_concept_has_them() -> void:
	assert_eq(ArmoryFacts.grouped(0), "0")
	assert_eq(ArmoryFacts.grouped(999), "999")
	assert_eq(ArmoryFacts.grouped(1300), "1,300")
	assert_eq(ArmoryFacts.grouped(1234567), "1,234,567")
	assert_eq(ArmoryFacts.multiplier_text(1.0), "1")
	assert_eq(ArmoryFacts.multiplier_text(0.5), "0.5")
	assert_eq(ArmoryFacts.multiplier_text(2.0), "2")
	assert_eq(ArmoryFacts.capitalised("bots hear you"), "Bots hear you")
	assert_eq(ArmoryFacts.capitalised(""), "")


# --- the end of a match ---

func _settled(xp_before: int, won: bool = true, rounds: int = 5, hits: int = 4, difficulty: StringName = &"normal",
		progress: Progress = null) -> PlayerTally.Settled:
	var p := progress if progress != null else _progress(xp_before)
	var o := MatchXp.Outcome.new()
	o.won = won
	o.rounds_won = rounds
	o.hits = hits
	o.difficulty = difficulty
	var s := PlayerTally.Settled.new()
	s.earned = MatchXp.earned(table, o)
	s.level_up = p.add_xp(s.earned.total)
	return s


func _card(s: PlayerTally.Settled, p: Progress) -> XpCard:
	var card := XpCard.new(s, p, pool)
	add_child_autofree(card)
	return card


func test_the_xp_card_shows_each_line_the_total_and_the_level_up() -> void:
	var p := _progress(1000)
	var card := _card(_settled(0, true, 5, 4, &"normal", p), p)
	await wait_process_frames(2)
	var words := _words(card)
	for w: String in ["Match played", "Match won", "Rounds won · 5 × 20", "Hits · 4 × 10", "Normal bots", "× 1", "XP EARNED", "+340",
			"LEVEL 4!", "Unlocked: Silencer", "40 / 600 XP", "560 XP to level 5"]:
		assert_true(words.has(w), w)
	assert_eq(words.count("100"), 3, "match played, match won and the rounds")
	assert_true(words.has("40"))
	var up := card.find_child("LevelUp", true, false)
	assert_not_null(up)
	var pic := up.find_children("*", "TextureRect", true, false)[0] as TextureRect
	assert_not_null(pic.texture, "the unlocked item's own model")
	assert_not_null(card.pictures())


func test_no_level_up_card_without_a_new_level() -> void:
	var p := _progress(150)
	var card := _card(_settled(0, false, 1, 0, &"normal", p), p)
	var words := _words(card)
	assert_true(words.has("Match played"))
	assert_false(words.has("Match won"), "a lost match gives no win line")
	assert_false(words.has("Hits"), "no hits, no line")
	assert_null(card.find_child("LevelUp", true, false))
	assert_null(card.pictures(), "no picture viewports without a level up")
	assert_true(words.has("+120"), "the match played and the round")
	assert_true(words.has("170 / 300 XP"), "270 XP: 170 into level 1")


func test_the_difficulty_multiplier_is_a_line() -> void:
	var p := _progress(0)
	var card := _card(_settled(0, true, 5, 4, &"hard", p), p)
	var words := _words(card)
	assert_true(words.has("Hard bots"))
	assert_true(words.has("× 1.5"))
	assert_true(words.has("+510"))


func test_a_level_up_over_two_levels_names_everything_it_unlocked() -> void:
	var p := _progress(1200)
	var s := _settled(0, true, 5, 40, &"normal", p)
	assert_eq(s.level_up.to, 5, "1,900 XP reaches level 5")
	var card := _card(s, p)
	await wait_process_frames(2)
	var words := _words(card)
	assert_true(words.has("LEVEL 5!"))
	assert_true(words.has("Unlocked: Silencer, Red Gas, Tight-Bore Barrel"))
	assert_eq(card.find_child("LevelUp", true, false).find_children("*", "TextureRect", true, false).size(), 3)


func test_a_match_that_gave_none_says_why() -> void:
	var s := PlayerTally.Settled.new()
	s.why_none = "XP_NONE_DEV"
	var card := _card(s, _progress(0))
	var words := _words(card)
	assert_eq(words, PackedStringArray(["No XP: Dev settings or dev content were used in this match."]))
	assert_null(card.find_child("LevelUp", true, false))


func test_at_the_cap_the_card_says_xp_stops_counting() -> void:
	var p := _progress(6500)
	var card := _card(_settled(0, true, 5, 4, &"normal", p), p)
	var words := _words(card)
	assert_true(words.has("Top level reached"))
	assert_false(words.has("LEVEL 10!"))


func test_an_uneven_share_says_just_the_count() -> void:
	var odd := LevelTable.read_file(pool)
	odd.earn[&"round_won"] = 7
	var o := MatchXp.Outcome.new()
	o.rounds_won = 3
	o.wins_needed = 2
	o.hits = 2
	var s := PlayerTally.Settled.new()
	s.earned = MatchXp.earned(odd, o)
	assert_eq(s.earned.lines[1].xp, 8, "7 x 3 x 0.4")
	var p := Progress.new(odd)
	s.level_up = p.add_xp(s.earned.total)
	var words := _words(_card(s, p))
	assert_true(words.has("Rounds won · 3"), "8 XP over 3 rounds is no whole share")
	assert_true(words.has("Hits · 2 × 10"))


func test_the_hud_shows_the_card_under_the_banner_until_the_next_match() -> void:
	var session := PlaySession.new()
	add_child_autofree(session)
	await wait_physics_frames(2)
	var hud := session._hud
	var p := _progress(1000)
	var s := _settled(0, true, 5, 4, &"normal", p)
	hud.show_xp(s, p)
	var card := hud.xp_card()
	assert_not_null(card)
	assert_eq(card.get_parent(), hud)
	hud._show_banner("ALPHA WIN THE MATCH", "A NEW MATCH STARTS SHORTLY")
	for i in 5:
		hud.update(session.state, 1.0, 10.0)
	assert_true(hud._banner.visible, "the win banner stays up as long as the card")
	# a second show frees the first
	hud.show_xp(s, p)
	await wait_process_frames(2)
	assert_false(is_instance_valid(card))
	var st := session.state
	st.events.clear()
	st.events.add(GameEvent.Kind.ROUND_START).value = 1
	hud.on_tick(st)
	assert_null(hud.xp_card(), "gone when a new match starts")
	hud.update(session.state, 1.0, 10.0)
	assert_false(hud._banner.visible, "and the banner times out as it did")
	st.events.clear()

extends GutTest
## LV15 QA: the cap went from 10 to 15; saves from before keep their level and unlocks, and no level is empty.

const PATH := "user://test_lv15_qa.save"
const CYBER := "000019"

var table: LevelTable
var pool: Pool


func before_all() -> void:
	pool = Pool.read_file()
	table = LevelTable.read_file(pool)


func after_each() -> void:
	SaveFile.remove(PATH)


func test_cap_is_fifteen_with_the_new_totals() -> void:
	assert_eq(table.cap(), 15)
	assert_eq(table.levels[10].total, 6500, "levels 1 to 10 keep their XP")
	assert_eq(table.levels[15].total, 14500)


func test_every_level_gives_a_public_item() -> void:
	for lv in range(1, table.cap() + 1):
		var public_count := 0
		for id in table.levels[lv].unlocks:
			var it := pool.item(id)
			if it != null and not it.is_dev():
				public_count += 1
		assert_gt(public_count, 0, "level %d gives nothing with Dev content off" % lv)


func test_old_cap_save_stays_level_ten_keeps_unlocks_and_xp_continues() -> void:
	var old := Progress.new(table)
	old.xp = 6500
	old.unlocked = table.unlocks_up_to(10)
	old.unlocked.append(CYBER) # the old cap gave the Cyber Pistol at 10
	assert_true(old.save(PATH))
	var p := Progress.new(table)
	p.load_file(PATH)
	assert_eq(p.level(), 10, "6,500 XP is still level 10")
	assert_true(p.unlocked.has(CYBER), "the Cyber Pistol is kept")
	assert_true(p.has(CYBER))
	var up := p.add_xp(1400)
	assert_eq(p.xp, 7900)
	assert_eq(p.level(), 11)
	assert_eq(up.to, 11)
	assert_true(p.unlocked.has(CYBER))


func test_xp_stops_at_the_new_cap() -> void:
	var p := Progress.new(table)
	p.add_xp(1000000)
	assert_eq(p.xp, 14500)
	assert_eq(p.level(), 15)
	assert_true(p.unlocked.has(CYBER))
	assert_true(p.standing().at_cap())

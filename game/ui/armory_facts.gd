class_name ArmoryFacts
extends RefCounted
## What the Armory shows, worked out from the levels, the pool and the player's XP (no nodes): every level's items and
## whether each level is unlocked, the next one or locked, how many items are unlocked, and the words for an item. With
## levelling off every level is unlocked. Items still being built (Access `dev`)
## are listed only with Dev content on; any waiting for their feature (Pool.waiting) never are.

enum State { UNLOCKED, NEXT, LOCKED }


## One row of the track: the starting kit (number 0) or a level, the XP total that reaches it and its items.
class Row:
	extends RefCounted
	var number: int = 0
	var total: int = 0
	var state: State = State.LOCKED
	var items: Array[Pool.Item] = []


var table: LevelTable = null
var pool: Pool = null
var xp: int = 0
var levelling_off: bool = false
var level: int = 0
var rows: Array[Row] = []
## Items listed, and how many of them are unlocked.
var item_count: int = 0
var unlocked_count: int = 0


func _init(table_in: LevelTable, pool_in: Pool, xp_in: int, off: bool, dev_content: bool) -> void:
	table = table_in
	pool = pool_in
	xp = xp_in
	levelling_off = off
	level = table.level_of(xp)
	for l in table.levels:
		var row := Row.new()
		row.number = l.number
		row.total = l.total
		for id in l.unlocks:
			var it := pool.item(id)
			if it != null and (dev_content or not it.is_dev()):
				row.items.append(it)
		if off or l.number <= level:
			row.state = State.UNLOCKED
		elif not row.items.is_empty() and next_row() == null:
			# The next level with something to show (BP3: level 7 holds only a dev spring, so with Dev content off
			# its empty card was marked next while the header named level 8).
			row.state = State.NEXT
		item_count += row.items.size()
		if row.state == State.UNLOCKED:
			unlocked_count += row.items.size()
		rows.append(row)


func standing() -> LevelTable.Standing:
	return table.standing(xp)


## The first level not unlocked that has something to show, or null at the cap and with levelling off.
func next_row() -> Row:
	for row in rows:
		if row.state == State.NEXT:
			return row
	return null


## "1,300": thousands set apart.
static func grouped(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return "-" + out if n < 0 else out


## The word under an item's name: REPLICA, POWER or its part slot (OPTIC, GRIP …).
static func kind_label(item: Pool.Item) -> String:
	var key := "REPLICA" if item.kind == Pool.Kind.REPLICA else ("POWER" if item.kind == Pool.Kind.POWER
			else String(item.slot).to_upper())
	return TranslationServer.translate("ARMORY_KIND_" + key)


## One line on what an item does, for the next unlock: a part's own blurb, else its kind's.
static func blurb(item: Pool.Item) -> String:
	match item.kind:
		Pool.Kind.PART:
			return capitalised(TranslationServer.translate("PART_BLURB_" + String(item.key).to_upper()))
		Pool.Kind.POWER:
			return TranslationServer.translate("ARMORY_BLURB_POWER_" + String(item.type).to_upper())
	return TranslationServer.translate("ARMORY_BLURB_REPLICA_" + String(item.key).to_upper())


## `words` with its first letter in capitals (a part's blurb may be the end of a sentence Customise starts).
static func capitalised(words: String) -> String:
	return words.substr(0, 1).to_upper() + words.substr(1)


## A multiplier without a pointless ".0": "1", "0.5", "1.5".
static func multiplier_text(m: float) -> String:
	return str(roundi(m)) if is_equal_approx(m, roundf(m)) else String.num(m)

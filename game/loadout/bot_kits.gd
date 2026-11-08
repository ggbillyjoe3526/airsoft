class_name BotKits
extends RefCounted
## What the bots carry, on both teams (B4) (the browser game's pool/botKit.ts): data/bot-kits.md's kits read against the pool,
## and each opposing bot's pick by its difficulty's weights, seeded by the match's seed and the bot's id so a seed
## replays the same kits. A kit is built as the player's loadout is (LoadoutRules.carried), from rules that follow no
## progress: what the player has unlocked never changes a bot's kit. Never throws: a row it can't read is left out and
## listed in `problems`, each "bot-kits.md:line: …".

const PATH := "res://data/bot-kits.md"
const FILE_NAME := "bot-kits.md"
## Where the bot personalities a kit's Suits may name are listed (their table's first column).
const BOTS_PATH := "res://data/bots.md"
const PERSONALITY_COLUMN := "Personality"
const KIT_COLUMN := "Kit"
const SUITS_COLUMN := "Suits"
## The bombs a kit carries (BP8), a slot each, by Loadout.BOMB_NAMES; optional, empty: the default pick.
const GRENADES_COLUMN := "Grenades"
## Each replica column, primary first, and its parts column.
const REPLICA_COLUMNS: PackedStringArray = ["Primary", "Secondary"]
const PARTS_COLUMNS: PackedStringArray = ["Primary parts", "Secondary parts"]
## Every bot, on both teams, loads its BBs the default way (the browser's BOT_GLOW_BBS): glowing on night fields only.
## Bots don't use the Loadout, so this is the rule, not a kit's pick.
const GLOW_BBS := Loadout.Glow.NIGHT
## Each difficulty (MatchOptions.BOT_LEVELS) and its weight column.
const WEIGHT_COLUMNS: Dictionary[StringName, String] = {
	&"easy": "Easy", &"normal": "Normal", &"hard": "Hard",
}


## One replica of a kit and what is fitted to it (parts and a power source), by pool ID.
class Slot:
	extends RefCounted
	var replica: String = ""
	var parts: PackedStringArray = PackedStringArray()


## A kit: its name, its replicas (the primary, then the sidearm if it has one), the personalities it suits (lower case;
## a bot of one leans towards it) and each difficulty's weight.
class Plan:
	extends RefCounted
	var kit_name: String = ""
	var slots: Array[Slot] = []
	var suits: PackedStringArray = PackedStringArray()
	var weights: Dictionary[StringName, float] = {}
	## The bomb in each grenade slot (empty: the default pick, GrenadeConfig.default_picks).
	var bombs: Array[Grenade.Kind] = []

	## Every pool ID it holds: its replicas and what is fitted to them.
	func items() -> PackedStringArray:
		var out := PackedStringArray()
		for s in slots:
			out.append(s.replica)
			out.append_array(s.parts)
		return out


## The kits the file could read, in its order.
var kits: Array[Plan] = []
var problems: Array[String] = []

static var _shared: BotKits = null


## The kits as shipped, read once against the shared pool.
static func shared() -> BotKits:
	if _shared == null:
		_shared = read_file(Pool.shared())
		for p in _shared.problems:
			push_warning("bot kits: %s" % p)
	return _shared


static func read_file(pool: Pool, path: String = PATH) -> BotKits:
	if not FileAccess.file_exists(path):
		var none := BotKits.new()
		none.problems.append("%s can't be read: every bot carries its replicas as they come" % path)
		return none
	return parse(FileAccess.get_file_as_string(path), pool, personalities())


## The bot personalities bots.md lists, lower case; empty if it can't be read (then Suits takes any name).
static func personalities(path: String = BOTS_PATH) -> PackedStringArray:
	var out := PackedStringArray()
	if not FileAccess.file_exists(path):
		return out
	for t in DataTable.read_all(FileAccess.get_file_as_string(path), path.get_file()):
		if not t.headers.is_empty() and t.headers[0] == PERSONALITY_COLUMN:
			for row in t.rows:
				var lower := row.cell(PERSONALITY_COLUMN).to_lower()
				if lower != "" and not out.has(lower):
					out.append(lower)
	return out


## The kits in bot-kits.md's `text`, read against `pool` (all of it: dev gear is left to `pick`) and the personalities
## `known` (a Suits name it doesn't list is a problem; empty: any name).
static func parse(text: String, pool: Pool, known: PackedStringArray = PackedStringArray()) -> BotKits:
	var b := BotKits.new()
	var tables := DataTable.read_all(text, FILE_NAME)
	var t: DataTable = null
	for table in tables:
		if t == null and not table.headers.is_empty() and table.headers[0] == KIT_COLUMN:
			t = table
	if t == null:
		b.problems.append("%s: no table with a Kit column: every bot carries its replicas as they come" % FILE_NAME)
		return b
	b.problems.append_array(t.problems)
	for column in _columns():
		if not t.has_column(column):
			b.problems.append("%s: the Kit table has no \"%s\" column: every bot carries its replicas as they come"
					% [t.where(t.line), column])
			return b
	for row in t.rows:
		var problem := b._read_row(row, pool, known)
		if problem != "":
			b.problems.append("%s: %s" % [t.where(row.line), problem])
	return b


## The kit a bot at `difficulty` carries, drawn by the weights from `seed_value` (Seeds.kit_seed) among the kits whose
## every item `rules` offers (dev gear only with its Dev content on), leaning towards those that suit its `personality`
## by `lean` (weights); null (the replicas as they come) when none is weighted above 0.
func pick(difficulty: StringName, rules: LoadoutRules, seed_value: int, personality: StringName = &"",
		lean: float = 1.0) -> Plan:
	var candidates: Array[Plan] = []
	for k in kits:
		if k.weights.get(difficulty, 0.0) > 0.0 and offers(rules, k):
			candidates.append(k)
	var w := weights(candidates, difficulty, personality, lean)
	var total := 0.0
	for x in w:
		total += x
	if total <= 0.0:
		return null
	var left := Seeds.stream(seed_value).randf() * total
	for i in candidates.size():
		left -= w[i]
		if left < 0.0:
			return candidates[i]
	return candidates[candidates.size() - 1]


## The weights a bot at `difficulty` with `personality` (&"": none) picks `candidates` by. A kit whose Suits names it
## weighs `lean` times its weight against the other kits with Suits, and those kits together keep the weight the table
## gives them, so a kit with no Suits (the Factory) keeps its chance: the level decides how often a bot carries gear, its
## personality which. Without a personality, or one no kit suits, the table's weights as they are.
static func weights(candidates: Array[Plan], difficulty: StringName, personality: StringName, lean: float) \
		-> PackedFloat64Array:
	var out := PackedFloat64Array()
	var total := 0.0
	var leaned := 0.0
	for k in candidates:
		var x: float = k.weights.get(difficulty, 0.0)
		out.append(x)
		if not k.suits.is_empty():
			total += x
			leaned += x * (lean if k.suits.has(String(personality)) else 1.0)
	if personality == &"" or leaned == total or leaned <= 0.0:
		return out
	var scale := total / leaned
	for i in candidates.size():
		var k := candidates[i]
		if not k.suits.is_empty():
			out[i] *= (lean if k.suits.has(String(personality)) else 1.0) * scale
	return out


## Whether `rules` offers everything `plan` holds: each replica playable and each item public, or dev with Dev content.
static func offers(rules: LoadoutRules, plan: Plan) -> bool:
	for s in plan.slots:
		if not rules.is_offered(s.replica):
			return false
	for id in plan.items():
		var it := rules.pool.item(id)
		if it == null or (it.is_dev() and not rules.dev_content):
			return false
	return true


## What a bot carrying `plan` plays with, built by `rules` as a loadout is (its parts' and power source's numbers worked
## in), with only the kit's replicas, each on full auto where it has it: bots never touch the selector. Its bombs are the
## kit's Grenades as the slots allow them (LoadoutRules.bombs_of: the default pick where they won't do).
static func kit_of(plan: Plan, rules: LoadoutRules) -> Kit:
	var l := rules.default_loadout(plan.kit_name)
	l.bombs = plan.bombs.duplicate()
	for i in plan.slots.size():
		var s := plan.slots[i]
		rules.equip(l, i as Loadout.Slot, s.replica)
		for id in s.parts:
			var it := rules.pool.item(id)
			if it.kind == Pool.Kind.POWER:
				rules.set_power(l, s.replica, id)
			else:
				rules.set_part(l, s.replica, it.slot, id)
	var kit := rules.carried(l)
	if plan.slots.size() < kit.size():
		kit.replicas.resize(plan.slots.size())
		kit.bb_weights.resize(plan.slots.size())
		kit.paints.resize(plan.slots.size())
		kit.parts.resize(plan.slots.size())
		kit.lights.resize(plan.slots.size())
		kit.glow_bbs.resize(plan.slots.size())
		kit.capped.resize(plan.slots.size())
	for r in kit.replicas:
		if r.fire_modes.has(ReplicaConfig.FireMode.AUTO):
			r.default_fire_mode = ReplicaConfig.FireMode.AUTO
	return kit


## The light every bot carries on a field played at night (the browser's botLight, M33h): the first light `rules` offers
## (a dev torch only with Dev content on) with a Lights row in stats.md, or null. By rule, at every difficulty and on
## both teams, never part of a kit (a kit naming one is refused).
static func night_light(rules: LoadoutRules) -> Pool.Item:
	for pt in rules.pool.parts:
		if pt.slot == Pool.LIGHT_SLOT and (rules.dev_content or not pt.is_dev()) and rules.stats.parts.has(pt.slot,
				pt.key):
			return pt
	return null


## The lights a bot carrying `replicas` has at night: `light` (night_light) on each replica it fits by the pool's tags,
## none on a replica the pool doesn't list. A match build's step, never a tick's.
static func lights_for(replicas: Array[ReplicaConfig], rules: LoadoutRules, light: Pool.Item) -> Array[Torch.Light]:
	var out: Array[Torch.Light] = []
	for r in replicas:
		var item := rules.pool.replica_by_key(r.id)
		var fits := light != null and item != null and rules.pool.fits(light, item)
		out.append(Torch.Light.of(light.key, rules.stats.parts.part(light.slot, light.key)) if fits else null)
	return out


## Reads one row into `kits`; what is wrong with it otherwise ("" when it was read).
func _read_row(row: DataTable.Row, pool: Pool, known: PackedStringArray) -> String:
	var kit_name := row.cell(KIT_COLUMN)
	if kit_name == "":
		return "no Kit name"
	for k in kits:
		if k.kit_name.to_lower() == kit_name.to_lower():
			return "kit \"%s\" is listed twice" % kit_name
	var plan := Plan.new()
	plan.kit_name = kit_name
	for i in REPLICA_COLUMNS.size():
		var replica_cell := row.cell(REPLICA_COLUMNS[i])
		var parts_cell := row.cell(PARTS_COLUMNS[i])
		if replica_cell == "":
			if parts_cell != "":
				return "%s but no %s" % [PARTS_COLUMNS[i], REPLICA_COLUMNS[i]]
			continue
		var slot := Slot.new()
		var problem := _read_slot(slot, pool, REPLICA_COLUMNS[i], replica_cell, parts_cell)
		if problem != "":
			return problem
		plan.slots.append(slot)
	if row.cell(REPLICA_COLUMNS[0]) == "":
		return "no Primary"
	if plan.slots.size() > 1 and plan.slots[0].replica == plan.slots[1].replica:
		return "the %s is both the Primary and the Secondary" % pool.item(plan.slots[0].replica).display_name
	for suit in DataTable.names(row.cell(SUITS_COLUMN)):
		var lower := suit.to_lower()
		if not known.is_empty() and not known.has(lower):
			return "Suits \"%s\" isn't a bot personality (bots.md: %s)" % [suit, ", ".join(known)]
		if not plan.suits.has(lower):
			plan.suits.append(lower)
	for bomb in DataTable.names(row.cell(GRENADES_COLUMN)):
		var k := Loadout.BOMB_NAMES.find(bomb.to_lower())
		if k != Grenade.Kind.SMOKE and k != Grenade.Kind.FLASH:
			return "Grenades \"%s\" isn't Smoke or Flash" % bomb
		plan.bombs.append(k as Grenade.Kind)
	for difficulty: StringName in WEIGHT_COLUMNS:
		var raw := row.cell(WEIGHT_COLUMNS[difficulty])
		var w := 0.0 if raw == "" else DataTable.parse_number(raw)
		if is_nan(w) or w < 0.0 or is_inf(w):
			return "%s weight \"%s\" isn't a number of 0 or more" % [WEIGHT_COLUMNS[difficulty], raw]
		plan.weights[difficulty] = w
	kits.append(plan)
	return ""


## A replica cell and its parts cell into `slot`; what is wrong with them otherwise ("").
static func _read_slot(slot: Slot, pool: Pool, column: String, replica_cell: String, parts_cell: String) -> String:
	var replica := pool.named(replica_cell)
	if replica == null:
		return "%s \"%s\" isn't a Name or ID in pool.md" % [column, replica_cell]
	if replica.kind != Pool.Kind.REPLICA or pool.waiting.has(replica):
		return "%s \"%s\" isn't a replica" % [column, replica_cell]
	slot.replica = replica.id
	var used: Dictionary[StringName, String] = {}
	for part_name in DataTable.names(parts_cell):
		var part := pool.named(part_name)
		if part == null:
			return "%s part \"%s\" isn't a Name or ID in pool.md" % [column, part_name]
		if part.kind == Pool.Kind.PART and part.slot == Pool.LIGHT_SLOT:
			return "%s part \"%s\": weapon torches are fitted by rule on night fields" % [column, part_name]
		if part.kind == Pool.Kind.REPLICA:
			return "%s part \"%s\" isn't a part or a power source" % [column, part_name]
		if not pool.fits(part, replica):
			return "%s part \"%s\" doesn't fit the %s" % [column, part.display_name, replica.display_name]
		var part_slot := part.slot if part.kind == Pool.Kind.PART else &"power"
		if used.has(part_slot):
			return "%s parts \"%s\" and \"%s\" both take the %s slot" % [column, used[part_slot], part.display_name,
					part_slot]
		used[part_slot] = part.display_name
		slot.parts.append(part.id)
	return ""


static func _columns() -> PackedStringArray:
	var out := PackedStringArray([KIT_COLUMN])
	out.append_array(REPLICA_COLUMNS)
	out.append_array(PARTS_COLUMNS)
	for difficulty: StringName in WEIGHT_COLUMNS:
		out.append(WEIGHT_COLUMNS[difficulty])
	return out

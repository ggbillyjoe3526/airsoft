class_name MatchOptions
extends RefCounted
## What the Match page offers, as plain rules the page only draws (tests read them without a screen): the modes and
## which of them a map hosts, the rules as chips read from the round tuning, which maps can't load yet, and the words
## on the loading screen and the summary line.

const MODE_ELIMINATION := "elimination"
const MODE_ATTACK_DEFEND := "attack_defend"
const MODE_PLANT_THE_BOMB := "plant_the_bomb"
const MODE_PRACTICE := "practice"
## The mode picked first, and taken first wherever the picked one can't be played there (BP8, owner: Attack / Defend);
## a map without a pole falls back to the first of MODES it hosts.
const DEFAULT_MODE := MODE_ATTACK_DEFEND
## Every mode, in the order the cards show them, top to bottom (owner, 2026-11-10: Attack / Defend first, then
## Elimination, then Practice; PB1, owner 2026-11-12: Plant The Bomb third, before Practice).
const MODES: PackedStringArray = ["attack_defend", "elimination", "plant_the_bomb", "practice"]
## The modes that are built; the others show greyed with a LATER tag.
const BUILT_MODES: PackedStringArray = ["attack_defend", "elimination", "plant_the_bomb", "practice"]
## The tag a mode card carries on a map that doesn't host it (a translation key): Elimination, Attack / Defend and
## Plant The Bomb say FIELDS ONLY on the range. Every map hosts Practice.
const FIELDS_ONLY_KEY := "MENU_FIELDS_ONLY"
## The modes that need a map with a flagpole (MapData.has_pole): Plant The Bomb's sites default to the poles.
const POLE_MODES: PackedStringArray = ["attack_defend", "plant_the_bomb"]
## The words of a mode: its name and its line (translation keys).
const MODE_NAME: Dictionary[String, String] = {
	"elimination": "MODE_ELIMINATION", "attack_defend": "MODE_ATTACK_DEFEND", "plant_the_bomb": "MODE_PLANT_THE_BOMB",
	"practice": "MODE_PRACTICE",
}
const MODE_BLURB: Dictionary[String, String] = {
	"elimination": "MODE_ELIMINATION_BLURB", "attack_defend": "MODE_ATTACK_DEFEND_BLURB",
	"plant_the_bomb": "MODE_PLANT_THE_BOMB_BLURB", "practice": "MODE_PRACTICE_BLURB",
}
## The modes a map of each kind hosts (data/maps.md's Kind): every field hosts Elimination, Attack / Defend (only with a
## flagpole), Plant The Bomb (likewise) and Practice (M94: targets where the other team would play), the range Practice
## alone. Values are plain Arrays: Godot 4.7.2 keeps a const Dictionary[K, PackedStringArray]'s values as Arrays and can
## crash reading one by a variable key (GraphicsTable's pattern).
const KIND_MODES: Dictionary[StringName, Array] = {
	&"field": ["attack_defend", "elimination", "plant_the_bomb", "practice"],
	&"range": ["practice"],
}
## The rule sets (concepts `rules-skirmish.png`, `rules-custom.png`): Skirmish plays the round tuning as it is, Custom
## the settings' CustomRules.
const RULES_SKIRMISH := "skirmish"
const RULES_CUSTOM := "custom"
const RULE_SETS: PackedStringArray = [RULES_SKIRMISH, RULES_CUSTOM]
## The words of a rule set: its name and its blurb (translation keys).
const RULES_NAME: Dictionary[String, String] = {RULES_SKIRMISH: "RULES_SKIRMISH", RULES_CUSTOM: "RULES_CUSTOM"}
const RULES_BLURB: Dictionary[String, String] = {
	RULES_SKIRMISH: "RULES_SKIRMISH_BLURB", RULES_CUSTOM: "RULES_CUSTOM_BLURB",
}
## The bots' levels, in the order shown (three since 2026-10-25: each moved up a name and Pro became Hard, DECISIONS).
const BOT_LEVELS: PackedStringArray = ["easy", "normal", "hard"]
## The level a new player starts on.
const DEFAULT_LEVEL := "normal"
## Against this level the scoreboard and the summary give a Pro tip, and What got you on Auto shows (the browser game's
## Pro bots).
const TIPS_LEVEL := &"hard"
const TEAM_KEYS: PackedStringArray = ["TEAM_ALPHA", "TEAM_BETA"]


## The modes `map` hosts, in the order the cards show them; none for a map the catalogue doesn't know.
static func modes_offered(map: MapCatalog.Entry) -> PackedStringArray:
	var out := PackedStringArray()
	if map == null:
		return out
	var hosted: Array = KIND_MODES.get(map.kind, [])
	for mode in MODES:
		if hosted.has(mode):
			out.append(mode)
	return out


## Whether `mode` can be picked on `map`: built, hosted by that map, and for a pole mode the map has a flagpole
## (`has_pole`).
static func mode_pickable(mode: String, map: MapCatalog.Entry, has_pole: bool) -> bool:
	return BUILT_MODES.has(mode) and modes_offered(map).has(mode) and (has_pole or not POLE_MODES.has(mode))

## The words on a mode card that the picked `map` doesn't host: FIELDS ONLY on the range's Elimination, Attack / Defend
## and Plant The Bomb; "" for a mode the map hosts (or no map).
static func only_tag_key(mode: String, map: MapCatalog.Entry) -> String:
	if map == null or modes_offered(map).has(mode):
		return ""
	return FIELDS_ONLY_KEY


## Whether `mode` is held back on `map` only for want of a flagpole: the card says so.
static func needs_pole(mode: String, map: MapCatalog.Entry, has_pole: bool) -> bool:
	return not has_pole and POLE_MODES.has(mode) and BUILT_MODES.has(mode) and modes_offered(map).has(mode)


## The team size a map is checked for: the range plays a team of one (you alone, PlaySession.practice_tuning), a field the
## match's.
static func check_size(map: MapCatalog.Entry, team_size: int) -> int:
	return 1 if map != null and map.kind == &"range" else team_size


## Players a side in a match on `map`: the Custom switches' size (`custom`, null under Skirmish) where the map offers
## it, else the map's standard (data/maps.md); the range plays you alone (check_size). A map the catalogue doesn't know
## (null) plays Custom's size, or the round tuning's.
static func team_size(map: MapCatalog.Entry, custom: CustomRules) -> int:
	var picked := custom.team_size if custom != null else 0
	if map == null:
		return picked if picked > 0 else SimTuning.load_default().rounds.team_size
	return check_size(map, map.team_size_for(picked))


## The round tuning a match on `map` plays: `base` with the Custom switches in force (`custom`, null under Skirmish), the
## team size the map gives (team_size), under Skirmish the map's round length (data/maps.md Round, WR2) and, under
## either, the map's flag raise time (data/maps.md Raise, MB3). A copy wherever it differs from `base`, which is never
## written (the loaded tuning is shared).
static func match_tuning(base: SimTuning, map: MapCatalog.Entry, custom: CustomRules) -> SimTuning:
	var t := base if custom == null else custom.applied_to(base)
	var size := team_size(map, custom)
	var length := round_time(map, custom, t.rounds.round_time)
	var raise := raise_time(map, t.flag.raise_time)
	if t.rounds.team_size != size or t.rounds.round_time != length:
		if t == base:
			t = base.duplicate() as SimTuning
		if t.rounds == base.rounds:
			t.rounds = base.rounds.duplicate() as RoundConfig
		t.rounds.team_size = size
		t.rounds.round_time = length
	if t.flag.raise_time != raise:
		if t == base:
			t = base.duplicate() as SimTuning
		if t.flag == base.flag:
			t.flag = base.flag.duplicate() as FlagConfig
		t.flag.raise_time = raise
	return t


## The round's length (s) on `map`: Custom's own switch (`custom`; `played` is it once applied), else the map's
## (data/maps.md Round), else `played`, the round tuning's.
static func round_time(map: MapCatalog.Entry, custom: CustomRules, played: float) -> float:
	if custom != null or map == null or map.round_time <= 0.0:
		return played
	return map.round_time


## The seconds a flag takes to raise on `map`: the map's own (data/maps.md Raise), else `played`, the flag tuning's.
static func raise_time(map: MapCatalog.Entry, played: float) -> float:
	if map == null or map.raise_time <= 0.0:
		return played
	return map.raise_time


## The seconds a flag takes to raise on `map` in `mode` where that is not the game's `base` (a field's own, data/maps.md
## Raise): what the Match page says before a match (the HUD's raise bar fills at it). 0 where it is the game's, the
## mode has no flag, or the map has no pole time of its own.
static func field_raise(mode: String, map: MapCatalog.Entry, base: float) -> float:
	if mode != MODE_ATTACK_DEFEND or map == null or map.raise_time <= 0.0 or is_equal_approx(map.raise_time, base):
		return 0.0
	return map.raise_time


## `map_id` loaded as the Match page lists it: its problems (empty when it can be played) and whether it has a pole.
static func map_check(map_id: String, style: MapStyle, team_size: int) -> MapData:
	return MapData.load_map(map_id, style, team_size)


## Why `map_id` can't be played now (MapData's problems), empty when it loads.
static func map_problems(map_id: String, style: MapStyle, team_size: int) -> Array[String]:
	return map_check(map_id, style, team_size).problems


## The rules as chips, each a (label, value) pair; the first has no label. Read from the round tuning and the hit rules.
static func rule_chips(rounds: RoundConfig, hits: HitConfig) -> Array[PackedStringArray]:
	var ricochets := "RULE_RICOCHETS_YES" if hits.ricochets_count else "RULE_RICOCHETS_NO"
	var out: Array[PackedStringArray] = []
	out.append(PackedStringArray(["", size_text(rounds.team_size)]))
	out.append(PackedStringArray([_tr("RULE_FIRST_TO"), str(rounds.wins_needed)]))
	out.append(PackedStringArray([_tr("RULE_ROUNDS"), clock_text(rounds.round_time)]))
	out.append(PackedStringArray([_tr("RULE_SWAP"), str(rounds.half_time_after)]))
	out.append(PackedStringArray([_tr("RULE_RICOCHETS"), _tr(ricochets)]))
	out.append(PackedStringArray([_tr("RULE_FRIENDLY_FIRE"), _tr(switch_key(hits.friendly_fire))]))
	return out


## A chip as one line of text.
static func chip_text(chip: PackedStringArray) -> String:
	return chip[1] if chip[0].is_empty() else "%s %s" % [chip[0], chip[1]]


## "3 v 3".
static func size_text(team_size: int) -> String:
	return _tr("RULE_SIZE") % [team_size, team_size]


## "9": `seconds` as the fewest digits ("7.5" for a half).
static func seconds_text(seconds: float) -> String:
	return String.num(seconds, 1).trim_suffix(".0")


## "2:30": `seconds` as minutes and seconds, a part-second counted whole.
static func clock_text(seconds: float) -> String:
	var clock := ceili(seconds)
	return "%d:%02d" % [clock / 60, clock % 60]


## "3v3": a Custom team size's button.
static func size_short(team_size: int) -> String:
	return _tr("RULE_SIZE_SHORT") % [team_size, team_size]


## The key of a switch's word: On or Off.
static func switch_key(on: bool) -> String:
	return "RULE_ON" if on else "RULE_OFF"


## What Skirmish says under its name: the match as the round tuning and the hit rules play it.
static func skirmish_blurb(rounds: RoundConfig, hits: HitConfig) -> String:
	return _tr(RULES_BLURB[RULES_SKIRMISH]) % [size_short(rounds.team_size), rounds.wins_needed,
			clock_text(rounds.round_time), _tr(switch_key(hits.friendly_fire)).to_lower()]


## What Custom says under its name, with its XP cap in bold and `lit` (bbcode): `cap` is the Custom multiplier.
static func custom_blurb(cap: float, lit: Color) -> String:
	var cap_text := _tr("RULE_XP_CAP") % ArmoryFacts.multiplier_text(cap)
	return _tr(RULES_BLURB[RULES_CUSTOM]) % ("[color=#%s][b]%s[/b][/color]" % [lit.to_html(false), cap_text])


## The line under a Custom row's buttons for the choice `value` (a team size, rounds to win, or a switch's 0 or 1): the
## browser game's blurb of that choice. `row` is "TEAM", "WINS", "FRIENDLY_FIRE" or "RICOCHETS".
static func choice_blurb(row: String, value: int) -> String:
	var words := _tr("RULE_%s_BLURB_%d" % [row, value])
	return words % value if words.contains("%d") else words


## The loading screen's kicker: "ELIMINATION · 3 V 3 · YOU'RE ALPHA"; practice has no teams: "PRACTICE · NO BOTS, NO SCORE".
static func kicker(mode: String, team_size: int, team: int) -> String:
	if mode == MODE_PRACTICE:
		return (_tr("LOAD_KICKER_PRACTICE") % _tr(MODE_NAME[mode])).to_upper()
	return (_tr("LOAD_KICKER") % [_tr(MODE_NAME[mode]), team_size, team_size, _tr(TEAM_KEYS[team])]).to_upper()


## The summary line's tail after the map's name: "Elimination · Alpha · Normal bots", or in Attack / Defend "Attack /
## Defend · Alpha attacks first · Normal bots", or in Practice "Practice · No bots, no score"; it names the teammates' level when it differs from the opponents'
## (`mates`, "" for none), and with Custom rules (`custom`) it ends " · Custom 2v2": the size played, `team_size` (0:
## Custom's own).
static func summary_rest(mode: String, team: int, bots: String, custom: CustomRules = null,
		mates: String = "", team_size: int = 0) -> String:
	if mode == MODE_PRACTICE:
		return _tr("MENU_SUMMARY_PRACTICE") % _tr(MODE_NAME[mode])
	var side := _tr(TEAM_KEYS[team])
	if POLE_MODES.has(mode):
		side = _tr("MENU_ATTACKS_FIRST_SHORT") % side
	var rest := _tr("MENU_SUMMARY_REST") % [_tr(MODE_NAME[mode]), side, _tr("BOT_" + bots.to_upper())]
	if not mates.is_empty() and mates != bots:
		rest += _tr("MENU_SUMMARY_MATES") % _tr("BOT_" + mates.to_upper())
	if custom != null:
		rest += _tr("MENU_SUMMARY_CUSTOM") % size_short(team_size if team_size > 0 else custom.team_size)
	return rest


## Your teammates' level as played: the one picked, or the opponents' as it follows.
static func teammates_level(opponents: String, picked: String) -> String:
	return picked if not picked.is_empty() else opponents


## The Opponents row's line for `level` (the browser game's DIFFICULTIES blurb).
static func opponents_blurb(level: String) -> String:
	return _tr("BOT_%s_BLURB" % level.to_upper())


## The Teammates row's line for `level` (the browser game's TEAMMATE_DIFFICULTIES blurb).
static func teammates_blurb(level: String) -> String:
	return _tr("BOT_%s_MATES" % level.to_upper())


## "XP ×1.5": the match's XP multiplier.
static func xp_note(xp: float) -> String:
	return _tr("BOT_XP") % ArmoryFacts.multiplier_text(xp)


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)

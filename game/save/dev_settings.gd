class_name DevSettings
extends RefCounted
## The Dev tab's switches (the browser game's config/dev.ts), saved with the settings. They apply whenever they are set:
## the tab is always there and every switch starts off (owner, 2026-10-29; before, a Dev settings box). Game speed,
## bottomless magazines, ghost, bots hold fire, bots run low on BBs, spectate any bot, bot intentions and Disable
## levelling keep a match out of the records and give it no XP (DevCheats); Dev content lists maps tagged dev and keeps
## a match on one out too; Retro pixels changes only the look, and Robots (the hidden Easter egg, owner 2026-10-24) only
## who is drawn as a robot from the next match (FigureMix; everyone is human while it is off). Disable levelling unlocks
## every item to carry; your own level and unlocks stay as they are and come back when it is off. Pretend slow frames
## counts every frame of a live round slow for the automatic graphics step-down (FrameWatch), to check it on a fast
## machine; it changes nothing else. Retro pixels' block size and shades are its sliders' (BP6). Time of day plays every
## map from the next match by Day or Night whatever it offers (the browser's M90; LightingConfig.PRESETS), or as the map
## and the Match page pick (""); forcing one keeps the match out of the records, as the browser's cheat did
## (DevCheats.watching: it changes only what you see). Lasers (LZ1, an Easter egg) makes every replica on the field fire
## lasers, instant hits with a beam, instead of BBs, at once; a cheat, so the match is kept out of the records.
## Skin-only arms (BP8, the owner's playtest note 11) shows your first-person arms as bare hands instead of gloved, live;
## only the look. A saved key no switch reads any more (Rigged figures, gone with FI7) is passed over.

const SPEED_STEP := 0.25

var dev_content: bool = false
var disable_levelling: bool = false
var game_speed: float = 1.0
var bottomless: bool = false
var ghost: bool = false
var bots_hold_fire: bool = false
var bots_run_low: bool = false
var spectate_bots: bool = false
var bot_intent: bool = false
var retro_pixels: bool = false
## Retro pixels' block size (screen pixels) and shades a channel (RetroPixels' ends).
var retro_pixel_size: int = RetroPixels.PIXEL_SIZE
var retro_shades: int = RetroPixels.SHADES
var robots: bool = false
var lasers: bool = false
var pretend_slow_frames: bool = false
var skin_arms: bool = false
## A preset id (LightingConfig.PRESETS), or &"" for the map's own.
var time_of_day: StringName = &""


## The cheats among them, as the simulation takes them.
func cheats() -> DevCheats:
	var c := DevCheats.new()
	c.game_speed = game_speed
	c.bottomless = bottomless
	c.ghost = ghost
	c.bots_hold_fire = bots_hold_fire
	c.bots_run_low = bots_run_low
	c.watching = spectate_bots or bot_intent or not time_of_day.is_empty()
	c.levelling_off = disable_levelling
	c.lasers = lasers
	return c


func to_dict() -> Dictionary:
	return {
		"dev_content": dev_content, "disable_levelling": disable_levelling, "game_speed": game_speed,
		"bottomless": bottomless, "ghost": ghost,
		"bots_hold_fire": bots_hold_fire, "bots_run_low": bots_run_low, "spectate_bots": spectate_bots, "bot_intent": bot_intent,
		"retro_pixels": retro_pixels, "retro_pixel_size": retro_pixel_size, "retro_shades": retro_shades, "robots": robots, "pretend_slow_frames": pretend_slow_frames,
		"lasers": lasers,
		"skin_arms": skin_arms, "time_of_day": String(time_of_day),
	}


## Saved values over the defaults, each checked on its own; game speed must be on its 25 % steps.
func from_dict(data: Dictionary) -> void:
	dev_content = _flag(data, "dev_content")
	disable_levelling = _flag(data, "disable_levelling")
	var speed: Variant = data.get("game_speed")
	game_speed = 1.0
	if (speed is float or speed is int) and float(speed) >= DevCheats.SPEED_MIN and float(speed) <= DevCheats.SPEED_MAX:
		game_speed = snappedf(float(speed), SPEED_STEP)
	bottomless = _flag(data, "bottomless")
	ghost = _flag(data, "ghost")
	bots_hold_fire = _flag(data, "bots_hold_fire")
	bots_run_low = _flag(data, "bots_run_low")
	spectate_bots = _flag(data, "spectate_bots")
	bot_intent = _flag(data, "bot_intent")
	retro_pixels = _flag(data, "retro_pixels")
	retro_pixel_size = _whole(data, "retro_pixel_size", RetroPixels.PIXEL_SIZE, RetroPixels.PIXEL_SIZE_MIN,
			RetroPixels.PIXEL_SIZE_MAX)
	retro_shades = _whole(data, "retro_shades", RetroPixels.SHADES, RetroPixels.SHADES_MIN, RetroPixels.SHADES_MAX)
	robots = _flag(data, "robots")
	lasers = _flag(data, "lasers")
	pretend_slow_frames = _flag(data, "pretend_slow_frames")
	skin_arms = _flag(data, "skin_arms")
	var time: Variant = data.get("time_of_day")
	time_of_day = StringName(time) if time is String and LightingConfig.PRESETS.has(StringName(time)) else &""


## A saved whole number from `lo` to `hi`, else `fallback`.
static func _whole(data: Dictionary, key: String, fallback: int, lo: int, hi: int) -> int:
	var v: Variant = data.get(key)
	if not (v is int or v is float) or float(v) < lo or float(v) > hi:
		return fallback
	return roundi(float(v))


static func _flag(data: Dictionary, key: String) -> bool:
	var v: Variant = data.get(key)
	return v if v is bool else false

class_name HudPrefs
extends RefCounted
## The HUD tab's choices (concept `hud-options.png`; the browser game's settings/hudPrefs.ts), saved with the settings
## under "hud": the crosshair (shape, colour, size, thickness, gap, opacity, dynamic or static spread, outline), the hit
## marker (on or off, colour, size), the ammo counter, where the hit feed sits and whether its lines fade or stay, your
## team's callouts in it (on or off; a file from before them loads on), the ping markers (on or off, PN2; a file from
## before them loads on), the magazine hand-off's line and glyphs (on or off, MH3; a file from before them loads on), the
## navy panels' opacity, how the minimap turns and how close it shows the field (MC1; a file from before it loads 100 %),
## and the HUD's size. The crosshair's colours leave out blue and orange,
## the teams'. Each value saved is checked on its own and falls back to its default.

enum Shape { CROSS, CROSS_DOT, CIRCLE, DOT }
enum FeedCorner { TOP_RIGHT, BOTTOM_LEFT }
enum FeedLines { FADE, KEEP }
## The minimap's turn: the field turns so the way you look is up, or north (the map's -z) stays up and your arrow turns.
enum MinimapTurn { ROTATING, FIXED }

## The crosshair's and the hit marker's colours (the browser game's CROSSHAIR_COLORS): white, green, yellow, cyan, pink,
## red.
const COLOURS: Array[Color] = [Color("f5f7fa"), Color("5cff6e"), Color("ffe94a"), Color("4af2ff"), Color("ff6ee6"),
		Color("ff3b30")]
## Slider ranges: the crosshair's size, thickness and gap (px at 1080p), its opacity, the hit marker's size (1 = as
## built) and the panels' opacity (the browser game's CROSSHAIR_RANGES, HIT_MARKER_RANGES and HUD_OPACITY).
const SIZE_RANGE := Vector2(2.0, 16.0)
const THICKNESS_RANGE := Vector2(1.0, 4.0)
const GAP_RANGE := Vector2(0.0, 12.0)
const OPACITY_RANGE := Vector2(0.2, 1.0)
const MARKER_SIZE_RANGE := Vector2(0.5, 2.5)
const PANEL_OPACITY_RANGE := Vector2(0.5, 1.0)
## The minimap's zoom (MC1, owner 2026-11-01): 1 shows MinimapConfig.view_radius from its middle to its edge, 2 half
## that (closer), 0.5 twice it; in steps of MINIMAP_ZOOM_STEP.
const MINIMAP_ZOOM_RANGE := Vector2(0.5, 2.0)
const MINIMAP_ZOOM_STEP := 0.1
## How far past a range's single-precision end a saved number may sit and still count (_number).
const RANGE_SLACK := 1e-6
## Lines the hit feed keeps for the whole match when its lines stay (the browser game's HIT_FEED.keptLines).
const KEPT_LINES := 10

var shape: Shape = Shape.CROSS
var colour: int = 0
var size: float = 7.0
var thickness: float = 2.0
var gap: float = 4.0
var opacity: float = 1.0
var dynamic: bool = true
var outline: bool = false
var marker: bool = true
var marker_colour: int = 0
var marker_size: float = 1.0
var ammo_counter: bool = true
var feed_corner: FeedCorner = FeedCorner.TOP_RIGHT
var feed_lines: FeedLines = FeedLines.FADE
## Your teammates' callouts in the feed and their radio clicks, and the other team's close by (CO2).
var callouts: bool = true
## Your team's ping markers over the field and on the minimap (PN2); off, pings and their answers go on unmarked.
var ping_markers: bool = true
## The magazine hand-off's line under the crosshair and its glyphs by the chevrons (MH3); off, the hand-off goes on
## unshown (the screen reader still reads its notices).
var mag_hand_off: bool = true
var panel_opacity: float = 1.0
var minimap_turn: MinimapTurn = MinimapTurn.ROTATING
var minimap_zoom: float = 1.0
## The whole HUD's scale but the crosshair's (AccessibilityConfig.HUD_SIZE_RANGE, 1 = as drawn), on top of the window's
## own growth.
var hud_size: float = AccessibilityConfig.HUD_SIZE_DEFAULT


func cross_colour() -> Color:
	return Color(COLOURS[colour], opacity)


func marker_tint() -> Color:
	return COLOURS[marker_colour]


func to_dict() -> Dictionary:
	return {
		"shape": int(shape), "colour": colour, "size": size, "thickness": thickness, "gap": gap, "opacity": opacity,
		"dynamic": dynamic, "outline": outline, "marker": marker, "marker_colour": marker_colour,
		"marker_size": marker_size, "ammo_counter": ammo_counter, "feed_corner": int(feed_corner),
		"feed_lines": int(feed_lines), "callouts": callouts, "ping_markers": ping_markers,
		"mag_hand_off": mag_hand_off, "panel_opacity": panel_opacity, "minimap_turn": int(minimap_turn),
		"minimap_zoom": minimap_zoom, "hud_size": hud_size,
	}


## Takes saved values over the defaults, each checked on its own.
func from_dict(data: Dictionary) -> void:
	var d := HudPrefs.new()
	shape = _pick(data, "shape", d.shape, Shape.size()) as Shape
	colour = _pick(data, "colour", d.colour, COLOURS.size())
	size = _number(data, "size", d.size, SIZE_RANGE)
	thickness = _number(data, "thickness", d.thickness, THICKNESS_RANGE)
	gap = _number(data, "gap", d.gap, GAP_RANGE)
	opacity = _number(data, "opacity", d.opacity, OPACITY_RANGE)
	dynamic = _flag(data, "dynamic", d.dynamic)
	outline = _flag(data, "outline", d.outline)
	marker = _flag(data, "marker", d.marker)
	marker_colour = _pick(data, "marker_colour", d.marker_colour, COLOURS.size())
	marker_size = _number(data, "marker_size", d.marker_size, MARKER_SIZE_RANGE)
	ammo_counter = _flag(data, "ammo_counter", d.ammo_counter)
	feed_corner = _pick(data, "feed_corner", d.feed_corner, FeedCorner.size()) as FeedCorner
	feed_lines = _pick(data, "feed_lines", d.feed_lines, FeedLines.size()) as FeedLines
	callouts = _flag(data, "callouts", d.callouts)
	ping_markers = _flag(data, "ping_markers", d.ping_markers)
	mag_hand_off = _flag(data, "mag_hand_off", d.mag_hand_off)
	panel_opacity = _number(data, "panel_opacity", d.panel_opacity, PANEL_OPACITY_RANGE)
	minimap_turn = _pick(data, "minimap_turn", d.minimap_turn, MinimapTurn.size()) as MinimapTurn
	minimap_zoom = snappedf(_number(data, "minimap_zoom", d.minimap_zoom, MINIMAP_ZOOM_RANGE), MINIMAP_ZOOM_STEP)
	# Between the slider's steps reads as the nearest step.
	hud_size = snappedf(_number(data, "hud_size", d.hud_size, AccessibilityConfig.HUD_SIZE_RANGE),
			AccessibilityConfig.HUD_SIZE_STEP)


## A whole number in [0, count) at `key`, else `fallback`.
static func _pick(data: Dictionary, key: String, fallback: int, count: int) -> int:
	var v: Variant = data.get(key)
	if not (v is int or v is float) or float(v) != floorf(float(v)) or float(v) < 0.0 or float(v) >= count:
		return fallback
	return int(v)


## A number within `bounds` at `key`, else `fallback`. Vector2 holds single precision (0.8 is 0.800000012), so a saved
## end of a range is let in by RANGE_SLACK and clamped (QA).
static func _number(data: Dictionary, key: String, fallback: float, bounds: Vector2) -> float:
	var v: Variant = data.get(key)
	if not (v is int or v is float) or is_nan(float(v)):
		return fallback
	var f := float(v)
	if f < bounds.x - RANGE_SLACK or f > bounds.y + RANGE_SLACK:
		return fallback
	return clampf(f, bounds.x, bounds.y)


static func _flag(data: Dictionary, key: String, fallback: bool) -> bool:
	var v: Variant = data.get(key)
	return v if v is bool else fallback

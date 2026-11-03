class_name HudPreview
extends Control
## The HUD tab's preview (concept `hud-options.png`): a stretch of plywood wall and a container, the crosshair twice
## (once with the hit marker round it, once opened as if moving), a hit feed line in its corner and the replica panel,
## all drawn from the tab's choices (HudPrefs) by the same parts the HUD uses, at the panels' opacity, the feed line in
## the saved team colours (show_teams). The feed line and the panel grow with the HUD size, the crosshairs keep theirs;
## at any size but 100 % a tag names it and dashed outlines show the two parts at 100 % (concept
## `settings-hud-size.png`). show_prefs() follows a change.

## Tall enough that the panel with its bomb row fits whole at 150 % (BP3; 180 cut the row from about 115 %), short
## enough that the tab needs no scrolling at 1080p.
const HEIGHT := 236.0
## The feed line and the replica panel are drawn this much smaller, so they fit the shorter preview and leave the
## Minimap row room in the tab (concept `settings-minimap.png`).
const PART_SCALE := 0.8
## Where the two crosshairs sit across the preview, and how much wider the moving one opens than standing still (px;
## the browser game's CROSSHAIR_PREVIEW_SPREAD).
const HIT_AT := 0.27
const MOVING_AT := 0.47
const MOVING_SPREAD := 10.0
## The backdrop: sky, the wall's top (share of the height), its planks and the container from this share across.
const SKY := Color("a9bccd")
const WALL := Color("b8893a")
const PLANK := Color("9a6f2c")
const PLANK_WIDTH := 96.0
const WALL_TOP := 0.26
const CONTAINER := Color("1d6b66")
const RIB := Color("175954")
const RIB_GAP := 22.0
const CONTAINER_FROM := 0.64
const CONTAINER_TOP := 0.12
## How far under the crosshairs their chips sit, and the feed's and panel's margins (px).
const CHIP_DROP := 34.0
const EDGE := 10.0
## The dashed outlines of the parts at 100 %: their line, dash and the gap between the panel's and its tag (px).
const GHOST_LINE := 2.0
const GHOST_DASH := 6.0
const GHOST_TAG_GAP := 8.0
const GHOST_TAG_SIZE := 10
const GHOST_TAG_BACKING := 0.8
const GHOST_TAG_PAD := Vector2i(6, 2)
## The sample magazine: BBs loaded, and one spare emptied so Ammo counter Off shows a hollow box.
const LOADED := 27
## Each bomb the preview's panel shows carried.
const PREVIEW_BOMBS := 1

var _prefs: HudPrefs = null
var _cfg := HudConfig.new()
var _feed: HudFeedRow = null
var _panel: ReplicaPanel = null
var _armament: Armament = null
var _hit_chip: Label = null
var _moving_chip: Label = null
## "HUD SIZE 125%" over the preview, the dashed outlines at 100 % and their tag (hidden at 100 %).
var _size_tag: MenuTag = null
var _ghosts: Ghosts = null
var _ghost_tag: Label = null


func _init() -> void:
	name = "HudPreview"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, HEIGHT)
	var tag := MenuTag.make(HudStyle.caps("SETTINGS_PREVIEW"), GameTheme.ACCENT_INK, GameTheme.ACCENT, GameTheme.ACCENT)
	tag.position = Vector2(EDGE, EDGE)
	add_child(tag)
	_hit_chip = _chip("SETTINGS_PREVIEW_HIT")
	_moving_chip = _chip("SETTINGS_PREVIEW_MOVING")
	_feed = HudFeedRow.new()
	_armament = Armament.create(ReplicaStats.default_loadout())
	if not _armament.replicas.is_empty():
		var ammo := _armament.ammo[0]
		ammo.mag = mini(LOADED, ammo.mag)
		if not ammo.pouch.is_empty():
			ammo.pouch[ammo.pouch.size() - 1] = 0
	_panel = ReplicaPanel.new()
	_panel.setup(_cfg)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, EDGE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.scale = Vector2.ONE * PART_SCALE
	_panel.pivot_offset_ratio = Vector2.ONE
	_feed.scale = Vector2.ONE * PART_SCALE
	add_child(_panel)
	# The feed line over the panel: at a large HUD size they meet in the short preview, and the line reads whole.
	add_child(_feed)
	if not _armament.replicas.is_empty():
		# One of each bomb, as a round starts: the bomb row shows its counts (BP3: blank, at full strength).
		var hand := Grenades.Hand.new()
		hand.smoke = PREVIEW_BOMBS
		hand.flash = PREVIEW_BOMBS
		_panel.refresh(_armament, hand)
	_ghosts = Ghosts.new()
	_ghosts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ghosts)
	_ghost_tag = HudStyle.label(self, GHOST_TAG_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER,
			HudStyle.SPACING_AIM)
	_ghost_tag.text = HudStyle.caps("SETTINGS_PREVIEW_DASHED")
	_ghost_tag.add_theme_stylebox_override("normal", HudStyle.panel_box(GHOST_TAG_BACKING, GHOST_TAG_PAD.x,
			GHOST_TAG_PAD.y))
	_size_tag = MenuTag.make("", GameTheme.ACCENT_INK, GameTheme.ACCENT, GameTheme.ACCENT)
	_size_tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, EDGE)
	_size_tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_size_tag)
	# The outlines follow the parts as they take their size.
	_feed.resized.connect(_place_chips)
	_panel.resized.connect(_place_chips)


## Draws the feed line in `teams`' colours (the saved colour set's HUD part): you on Alpha hitting a Beta player.
func show_teams(teams: TeamConfig) -> void:
	var you := HudFeedRow.Who.new()
	you.set_to(tr("HUD_YOU"), GameTheme.TEXT, false, true)
	var them := HudFeedRow.Who.new()
	them.set_to(tr("SETTINGS_PREVIEW_NAME"), teams.colours[1].lightened(HudFeed.NAME_LIGHTEN), false, false)
	_feed.show_line(you, them, teams.colours[0], teams.colours[0], true)


## Shows `prefs` as they are now.
func show_prefs(prefs: HudPrefs) -> void:
	_prefs = prefs
	_panel.set_counted(prefs.ammo_counter)
	var right := prefs.feed_corner == HudPrefs.FeedCorner.TOP_RIGHT
	_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT if right else Control.PRESET_BOTTOM_LEFT,
			Control.PRESET_MODE_MINSIZE, EDGE)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	_feed.grow_vertical = Control.GROW_DIRECTION_END if right else Control.GROW_DIRECTION_BEGIN
	_feed.pivot_offset_ratio = Vector2(1.0, 0.0) if right else Vector2(0.0, 1.0)
	# The feed line and the panel at the HUD size, as in play; the crosshairs keep their own.
	var grown := PART_SCALE * prefs.hud_size
	_feed.scale = Vector2.ONE * grown
	_panel.scale = Vector2.ONE * grown
	var resized := not is_equal_approx(prefs.hud_size, 1.0)
	_size_tag.set_text((tr("SETTINGS_PREVIEW_HUD_SIZE") % roundi(prefs.hud_size * 100.0)).to_upper())
	_size_tag.visible = resized
	_ghosts.visible = resized
	_ghost_tag.visible = resized
	HudStyle.restyle(self, prefs.panel_opacity)
	_place_chips()


func feed_row() -> HudFeedRow:
	return _feed


## The "HUD SIZE n%" tag and the dashed outlines of the parts at 100 %: for tests.
func size_tag() -> MenuTag:
	return _size_tag


func ghosts() -> Control:
	return _ghosts


## Where the feed line and the panel sit at 100 % (the dashed outlines), in the preview's px.
func ghost_rects() -> Array[Rect2]:
	return [_at_100(_feed), _at_100(_panel)]


func panel() -> ReplicaPanel:
	return _panel


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_chips()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0.0, 0.0, w, h), SKY)
	var wall_top := h * WALL_TOP
	draw_rect(Rect2(0.0, wall_top, w * CONTAINER_FROM, h - wall_top), WALL)
	var x := PLANK_WIDTH
	while x < w * CONTAINER_FROM:
		draw_line(Vector2(x, wall_top), Vector2(x, h), PLANK, 2.0)
		x += PLANK_WIDTH
	var box_left := w * CONTAINER_FROM
	draw_rect(Rect2(box_left, h * CONTAINER_TOP, w - box_left, h), CONTAINER)
	x = box_left + RIB_GAP
	while x < w:
		draw_line(Vector2(x, h * CONTAINER_TOP), Vector2(x, h), RIB, 3.0)
		x += RIB_GAP
	if _prefs == null:
		return
	var hit_at := Vector2(w * HIT_AT, h * 0.5)
	var still := CrosshairDraw.gap(_prefs, 0.0)
	CrosshairDraw.cross(self, hit_at, _prefs, still)
	if _prefs.marker:
		CrosshairDraw.marker(self, hit_at, _prefs, still, _cfg.marker_size, _cfg.marker_width, 1.0)
	var moving_at := Vector2(w * MOVING_AT, h * 0.5)
	CrosshairDraw.cross(self, moving_at, _prefs, CrosshairDraw.gap(_prefs, _prefs.gap + MOVING_SPREAD))


func _chip(key: String) -> Label:
	var l := HudStyle.label(self, HudStyle.CHIP_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER,
			HudStyle.SPACING_AIM)
	l.text = HudStyle.caps(key)
	l.add_theme_stylebox_override("normal", HudStyle.panel_box(HudStyle.BACKING_PANEL, 8, 2))
	return l


func _place_chips() -> void:
	_place_chip(_hit_chip, HIT_AT)
	_place_chip(_moving_chip, MOVING_AT)
	if _ghosts == null:
		return
	_ghosts.rects = ghost_rects()
	_ghosts.queue_redraw()
	# "DASHED: 100%" beside the panel's outline, along its bottom.
	var panel := _ghosts.rects[1]
	_ghost_tag.reset_size()
	_ghost_tag.position = Vector2(panel.position.x - GHOST_TAG_GAP - _ghost_tag.size.x, panel.end.y - _ghost_tag.size.y)


## `part`'s rectangle at the preview's own part size (100 % HUD size), about its pivot (the corner it is anchored to).
static func _at_100(part: Control) -> Rect2:
	var whole := part.size * PART_SCALE
	var corner := part.position + part.size * part.pivot_offset_ratio
	return Rect2(corner - whole * part.pivot_offset_ratio, whole)


## `chip` centred under the crosshair `across` the preview.
func _place_chip(chip: Label, across: float) -> void:
	chip.reset_size()
	chip.position = Vector2(size.x * across - chip.size.x * 0.5, size.y * 0.5 + CHIP_DROP)


## The dashed outlines of the parts at 100 %, over them.
class Ghosts:
	extends Control

	var rects: Array[Rect2] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for r in rects:
			var top_right := Vector2(r.end.x, r.position.y)
			var bottom_left := Vector2(r.position.x, r.end.y)
			draw_dashed_line(r.position, top_right, GameTheme.TEXT, GHOST_LINE, GHOST_DASH)
			draw_dashed_line(top_right, r.end, GameTheme.TEXT, GHOST_LINE, GHOST_DASH)
			draw_dashed_line(r.end, bottom_left, GameTheme.TEXT, GHOST_LINE, GHOST_DASH)
			draw_dashed_line(bottom_left, r.position, GameTheme.TEXT, GHOST_LINE, GHOST_DASH)

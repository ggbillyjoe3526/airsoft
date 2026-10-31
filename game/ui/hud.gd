class_name Hud
extends Control
## The heads-up display (the browser game's ui/hud.ts) in the menus' look (HudStyle): the crosshair sized from the
## replica's real spread, the hit marker when your BB knocks someone out, the replica panel (ReplicaPanel: count, spare,
## fire modes, a box per magazine, reloading, the hop-up dial while you turn it), the score bar and "First to N"
## (HudScore), the round's banners (HudBanner), a ricochet that only ticks you, the big "HIT!" when you're hit, and
## under the match's WON / LOST stamp its summary (MatchSummary) round the XP the match gave (XpCard), up until the next
## match starts, and whose eyes you watch through once you are out (or with the Dev settings' Spectate any bot) at the
## bottom. In Attack / Defend (concepts `hud-attack.png`, `hud-defend.png`, `round-end.png`): the ATK / DEF tags and the
## overtime clock on the score bar, the flag gauge under it (HudFlagGauge), the warning while the other team's flag goes
## up, the marker over the pole with its distance, and the rounds' own banners. In Elimination's overtime (concept
## `overtime-flag.png`): the banner OVERTIME · TOUCH THE FLAG, the clock's OT and the flag's time left, the marker over
## the flag with its chequered glyph (`use_overtime_flag`) and FLAG TOUCHED on a round won there. On the practice range (`setup_range`,
## concepts `step16-range/`): no score bar, rounds or hit feed; the last BB's readout bottom left (HudRangeReadout) and
## the timed challenge's bar, ready line and banners (HudRangeChallenge). Under the crosshair, when a bush's leaves stop
## your own BB close in front of you, the line saying so (`leaves_notice_shown`). Under the score bar, for a few seconds
## after a round's end, the automatic graphics step-down's line (concept `graphics-step-down.png`,
## `show_graphics_step`). With Settings › Accessibility's sound cues on, the ring of markers round the crosshair for the
## sounds heard (HudSoundCues). The HUD tab's HUD size scales every part about its anchor but the crosshair, the hit
## marker and the cue ring (`set_hud_size`); Reduced motion holds the flag warning steady (`set_motion`). Your team's
## callouts share the hit feed, each with its speaker and words, gone at a round's start, while Settings › HUD ›
## Callouts is on (`on_calls`). Screen reader messages read the hit feed, the calls, your hit and the rounds' turns
## through a live region that is never drawn (HudAnnounce, `set_read_out`). Your team's pings show as markers over the
## field (HudPingMarkers, `place_pings`) and on the minimap while Settings › HUD › Ping markers is on (PN2). Text is
## only rebuilt when what it shows changes. No hints teaching the controls (owner, 2026-10-16), but for the reload prompt
## under the crosshair while reloads are manual (HudReloadPrompt; owner, 2026-10-29).

const MARGIN := 32.0
## The replica panel's lane, bottom right: as wide as its hop-up note, as tall as its notes and panel.
const PANEL_LANE := Vector2(340.0, 230.0)
const TOP_WIDTH := 800.0
## The hit call's and banners' stack: this wide, centred, hanging this far under the score bar's column (so the step-down
## line, the flag gauge or a large HUD size push it down and it never covers the score bar), the HIT! call and its walk-off
## line first and a banner under them. Without a score bar (the range) it starts MARGIN down.
const MIDDLE_WIDTH := 1500.0
const MIDDLE_GAP := 12.0
## The finished match's XP (XpCard) and the round's table hang this far under the stack.
const XP_GAP := 28.0
## The match summary's row (its panels either side of the XP card) keeps this far from the screen's sides (px): at a
## HUD size too large for the width the row is held smaller (MatchSummary.set_fit). At 100 % on 1920 it fits as built.
const SUMMARY_EDGE := 16.0
## The least share the cards under the stack are held to when the height left is short (never invisible).
const CARDS_FIT_FLOOR := 0.25
## "What got you" on the left, its top-left corner (px): under the minimap's caption when there is a minimap (the
## range has none: CARD_TOP).
const CARD_LEFT := 32.0
const CARD_TOP := 250.0
const SKIP_KEY_PAD := Vector2i(10, 4)
const SKIP_GAP := 14
const SKIP_SIZE := 18
const SKIP_KEY_SIZE := 14
## The scoreboard's top edge, under the score.
const BOARD_TOP := 160.0
## The flag warning's plate margins and the gap between its flag and its words.
const WARNING_PAD := Vector2i(36, 10)
const WARNING_GAP := 18
## The graphics step-down's line: its plate's margins (the left one inside the yellow edge), the gap between its parts,
## the kicker's, the line's and the hint's type, and the plate's opacity.
const STEP_PAD := Vector4i(14, 10, 18, 10)
const STEP_GAP := 14
const STEP_KICKER_SIZE := 12
const STEP_KICKER_SPACING := 0.14
const STEP_SIZE := 19
const STEP_HINT_SIZE := 16
const STEP_BACKING := 0.88
## The least HUD size drawn, so a broken value never divides by nothing (the settings keep it within 0.8–1.5).
const HUD_SIZE_FLOOR := 0.1

## What Use would do to the door in your reach (DO1), for the prompt under the crosshair.
enum DoorPrompt { NONE, OPEN, SHUT }

var _cfg: HudConfig = null
var _teams: TeamConfig = null
var _view: ViewConfig = null
var _player: Character = null
var _rounds: RoundConfig = null
var _sim: SimTuning = null

var _replica: ReplicaPanel = null
var _score: HudScore = null
var _banner: HudBanner = null
var _hit_label: Label = null
var _hit_sub: Label = null
## The hit call and banner stack (`_seat_middle`), the empty slot that keeps a banner where it is as the hit call ends,
## and the height of that slot, and whether it is held (the hit call and a banner have shown together).
var _middle: VBoxContainer = null
var _hit_hold: Control = null
var _hit_held: bool = false
var _vault_prompt: Label = null
## "U to open the door" or "to shut", while a door is in your reach (DO1).
var _door_prompt: Label = null
var _vault_left: float = 0.0
var _door_want: DoorPrompt = DoorPrompt.NONE
var _leaves_notice: Label = null
## The reload prompt under them (RL2), and whether reloads are manual: the player's command says so each tick (the play
## scene copies PlayerCommand.manual_reload here), so the prompt follows the rule the simulation used.
var _reload_prompt: HudReloadPrompt = null
var manual_reload: bool = false
var _leaves_left: float = 0.0
var _xp: XpCard = null
var _watching: Label = null
var _watching_name: String = ""
var _gauge: HudFlagGauge = null
var _warning: PanelContainer = null
var _warning_flag: HudFlagGlyph = null
var _flag_marker: HudFlagMarker = null
var _order_wheel: HudOrderWheel = null
var _hold_marker: HudHoldMarker = null
var _hold_slots := HudHoldMarker.Slots.new()
var _minimap: HudMinimap = null
## The full-screen map (FM1) over the minimap's drawing, with it.
var _field_map: HudFieldMap = null
## Your team's ping markers (PN2), and where the ones pinned at a side go.
var _pings: HudPingMarkers = null
var _ping_stack := HudPingMarkers.Stack.new()
## The sound cue ring round the crosshair (AC4), and whether Settings › Accessibility has it on.
var _sound_cues: HudSoundCues = null
var _cues_on: bool = false
var _hits := HitFeed.new()
var _feed: HudFeed = null
## The callouts read (on_calls): the log, and the serial read up to.
var _call_log: CalloutLog = null
var _call_serial: int = 0
var _announce: HudAnnounce = null
var _team_markers: HudTeamMarkers = null
## The magazine hand-off's line under the crosshair (MH3; null on the range).
var _mag_line: HudMagLine = null
var _no_marks := PackedByteArray()
var _round_result: HudRoundResult = null
var _summary: MatchSummary = null
## Practice: the last BB's readout and the timed challenge's display (null in a match).
var _readout: HudRangeReadout = null
var _challenge: HudRangeChallenge = null
## The score bar's column and the bottom line (whom you watch, the skip hint), hidden with the replica panel and the
## feed under the summary.
var _top: VBoxContainer = null
var _bottom: VBoxContainer = null
## "DEPOT · HARD BOTS": the end of the match stamp's line.
var _match_tail := ""
var _board: HudScoreboard = null
var _board_wanted: bool = false
var _what_got_you: WhatGotYouCard = null
var _skip_hint: PanelContainer = null
var _skip_key: Label = null
## The graphics step-down's line, its words and its seconds left.
var _step_line: PanelContainer = null
var _step_words: Label = null
var _step_left: float = 0.0
var _names := PackedStringArray()
var _stats: MatchStats = null
var _pulse: float = 0.0

var _marker_left: float = 0.0
var _banner_left: float = 0.0
var _hop_left: float = 0.0
var _gap: float = 0.0
var _show_cross: bool = true
## The slot the hop-up readout is about.
var _hop_slot: int = -1
## The HUD tab's choices (apply_prefs).
var _prefs := HudPrefs.new()
## The panel opacity the HUD's parts show (HudStyle.restyle).
var _opacity: float = 1.0
## The HUD's size (HudPrefs.hud_size, 1 = as drawn), and how much of the flag warning's pulse shows (Reduced motion).
var _hud_size: float = 1.0
var _pulse_share: float = 1.0


func setup(cfg: HudConfig, teams: TeamConfig, view: ViewConfig, sim: SimTuning, player: Character) -> void:
	_cfg = cfg
	_teams = teams
	_view = view
	_player = player
	_rounds = sim.rounds
	_sim = sim
	name = "Hud"
	theme = GameTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Teammate markers under everything else (setup_field fills them), the hit feed in its corner.
	_team_markers = HudTeamMarkers.new()
	add_child(_team_markers)
	_hits.setup(cfg.feed_lines, cfg.feed_line_time, cfg.feed_fade_time)
	_feed = HudFeed.new()
	_feed.setup(maxi(cfg.feed_lines, HudPrefs.KEPT_LINES), cfg.feed_gap, teams)
	add_child(_feed)
	set_feed_corner(HudFeed.Place.TOP_RIGHT)
	# The replica panel, bottom right.
	_replica = ReplicaPanel.new()
	_place(_replica, Vector4(1.0, 1.0, 1.0, 1.0), Rect2(-MARGIN - PANEL_LANE.x, -MARGIN - PANEL_LANE.y, PANEL_LANE.x,
			PANEL_LANE.y))
	_replica.setup(cfg)
	add_child(_replica)
	# The score bar and "First to N", top centre.
	var top := VBoxContainer.new()
	_top = top
	_place(top, Vector4(0.5, 0.0, 0.5, 0.0), Rect2(-TOP_WIDTH * 0.5, HudStyle.SCORE_TOP, TOP_WIDTH, 0.0))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", roundi(HudStyle.AIM_GAP))
	add_child(top)
	_score = HudScore.new()
	_score.setup(teams, _rounds.wins_needed, player.team)
	_score.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(_score)
	_build_step_line(top)
	_gauge = HudFlagGauge.new()
	_gauge.setup(roundi(1.0 / sim.flag.rope_step), _score.custom_minimum_size.x)
	_gauge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_gauge.visible = false
	top.add_child(_gauge)
	var aim := HudStyle.label(top, HudStyle.AIM_SIZE, 700, Color(GameTheme.TEXT, 0.8), HORIZONTAL_ALIGNMENT_CENTER,
			HudStyle.SPACING_AIM)
	aim.text = HudStyle.first_to(_rounds.wins_needed)
	aim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	aim.add_theme_stylebox_override("normal", HudStyle.panel_box(HudStyle.BACKING_AIM, 12, 4))
	# The warning: the attackers' flag and "THEIR FLAG IS GOING UP!" on a plate with a yellow top rule.
	_warning = PanelContainer.new()
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var warn_box := HudStyle.panel_box(HudStyle.BACKING_BANNER, WARNING_PAD.x, WARNING_PAD.y)
	warn_box.border_color = GameTheme.YELLOW
	warn_box.border_width_top = roundi(HudStyle.BANNER_RULE)
	_warning.add_theme_stylebox_override("panel", warn_box)
	_warning.visible = false
	top.add_child(_warning)
	var warn_row := HBoxContainer.new()
	warn_row.add_theme_constant_override("separation", WARNING_GAP)
	warn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning.add_child(warn_row)
	_warning_flag = HudFlagGlyph.new(HudStyle.WARNING_GLYPH, GameTheme.YELLOW)
	_warning_flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	warn_row.add_child(_warning_flag)
	var warn_text := HudStyle.label(warn_row, HudStyle.WARNING_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER,
			HudStyle.SPACING_BANNER)
	warn_text.text = HudStyle.caps("HUD_FLAG_GOING_UP")
	# The marker over the pole, placed each frame (place_flag_marker).
	_flag_marker = HudFlagMarker.new()
	add_child(_flag_marker)
	_flag_marker.setup(_cfg)
	# The ping markers, one per teammate made in setup_field, placed each frame (place_pings).
	_pings = HudPingMarkers.new()
	add_child(_pings)
	# Banners and the hit call, centre.
	var middle := VBoxContainer.new()
	_middle = middle
	_place(middle, Vector4(0.5, 0.0, 0.5, 0.0), Rect2(-MIDDLE_WIDTH * 0.5, MARGIN, MIDDLE_WIDTH, 0.0))
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(middle)
	_hit_hold = Control.new()
	_hit_hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_hold.visible = false
	middle.add_child(_hit_hold)
	# The vault prompt, the door's, the leaves' line and the reload prompt, just under the crosshair.
	var prompt := VBoxContainer.new()
	_place(prompt, Vector4(0.5, 0.5, 0.5, 0.5), Rect2(-TOP_WIDTH * 0.5, cfg.vault_prompt_drop, TOP_WIDTH, 0.0))
	add_child(prompt)
	_vault_prompt = HudStyle.label(prompt, GameTheme.SMALL_SIZE, 700, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_vault_prompt.text = tr("HUD_VAULT") % KeyNames.of_action(&"jump")
	_vault_prompt.add_theme_constant_override("outline_size", 6)
	_vault_prompt.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	_vault_prompt.visible = false
	_door_prompt = HudStyle.label(prompt, GameTheme.SMALL_SIZE, 700, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_door_prompt.add_theme_constant_override("outline_size", 6)
	_door_prompt.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	_door_prompt.visible = false
	_leaves_notice = HudStyle.label(prompt, GameTheme.SMALL_SIZE, 700, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_leaves_notice.text = tr("HUD_LEAVES_IN_THE_WAY")
	_leaves_notice.add_theme_constant_override("outline_size", 6)
	_leaves_notice.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	_leaves_notice.visible = false
	_reload_prompt = HudReloadPrompt.new()
	prompt.add_child(_reload_prompt)
	_hit_label = HudStyle.label(middle, GameTheme.HUGE_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_hit_label.text = tr("HUD_YOU_ARE_HIT")
	_hit_sub = HudStyle.label(middle, GameTheme.BODY_SIZE, 600, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_hit_sub.text = tr("HUD_WALK_OFF")
	for l: Label in [_hit_label, _hit_sub]:
		l.add_theme_constant_override("outline_size", 8)
		l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	_banner = HudBanner.new()
	_banner.setup()
	middle.add_child(_banner)
	# The round's table, under the stamp where the match's XP goes.
	_round_result = HudRoundResult.new()
	_place(_round_result, Vector4(0.5, 0.5, 0.5, 0.5), Rect2())
	_round_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_round_result)
	_round_result.setup(cfg, teams, sim.rounds, teams.colours[player.team])
	_round_result.pivot_offset_ratio = Vector2(0.5, 0.0) # held smaller about its top middle (_fit_round_result)
	# The match's summary, its panels either side of the XP card and level with it.
	_summary = MatchSummary.new()
	add_child(_summary)
	_summary.setup(teams, teams.colours[player.team], 0.0)
	# The scoreboard while Tab is held, over everything in the middle.
	_board = HudScoreboard.new()
	_place(_board, Vector4(0.5, 0.0, 0.5, 0.0), Rect2(0.0, BOARD_TOP, 0.0, 0.0))
	_board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_board)
	_board.setup(cfg, teams, teams.colours[player.team], sim.flag.max_overtime)
	# Whose eyes you watch through, bottom centre.
	var bottom := VBoxContainer.new()
	_bottom = bottom
	_place(bottom, Vector4(0.5, 1.0, 0.5, 1.0), Rect2(-TOP_WIDTH * 0.5, -MARGIN, TOP_WIDTH, 0.0))
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bottom)
	_watching = HudStyle.label(bottom, HudStyle.AIM_SIZE, 700, Color(GameTheme.TEXT, 0.8), HORIZONTAL_ALIGNMENT_CENTER,
			HudStyle.SPACING_AIM)
	_watching.uppercase = true
	_watching.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_watching.add_theme_stylebox_override("normal", HudStyle.panel_box(HudStyle.BACKING_AIM, 12, 4))
	_watching.visible = false
	_build_skip_hint(bottom)
	# Screen reader messages: never drawn, so anywhere will do.
	_announce = HudAnnounce.new()
	add_child(_announce)
	_announce.setup(teams, player, _rounds.half_time_after)
	# The stack follows the score bar's column; the cards under it follow the stack and the screen's height.
	top.resized.connect(_seat_middle)
	middle.sort_children.connect(_hang_cards)
	resized.connect(_hang_cards)
	_seat_middle()


## Makes this the practice range's HUD: no score bar, rounds or hit feed, and the readout and the timed challenge in
## their place, for `range_cfg`'s walls and run and the player's BBs.
## Practice's readout and challenge display; `on_field` on a field (M94): distances from where you stand, and a BB lost
## only below `kill_y` flew out.
func setup_range(range_cfg: RangeConfig, on_field: bool = false, kill_y: float = 0.0) -> void:
	# The readout sits at the bottom of a lane, MARGIN in from the corner, so it grows up and keeps its foot as it changes.
	var lane := VBoxContainer.new()
	lane.name = "RangeLane"
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.alignment = BoxContainer.ALIGNMENT_END
	_place(lane, Vector4(0.0, 1.0, 0.0, 1.0), Rect2(MARGIN, -MARGIN, 0.0, 0.0))
	lane.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(lane)
	_readout = HudRangeReadout.new()
	lane.add_child(_readout)
	_readout.setup(range_cfg, _player.id, on_field, kill_y)
	_seat_middle()
	_challenge = HudRangeChallenge.new()
	add_child(_challenge)
	_challenge.setup(range_cfg, _player.id)
	_top.visible = false
	_feed.visible = false


func range_readout() -> HudRangeReadout:
	return _readout


func range_challenge() -> HudRangeChallenge:
	return _challenge


## The field the teammate markers check their line of sight against (`query`), the bodies' heights, the names by
## character id for the feed and the round's table ("" for you), everyone playing, and the match's numbers.
func setup_field(query: WorldQuery, body: BodyConfig, names: PackedStringArray, characters: Array[Character],
		stats: MatchStats) -> void:
	_team_markers.setup(_cfg, body, query, characters, _player)
	_pings.setup(_cfg, _sim.pings.lifetime, characters, _player, _teams.colours[_player.team],
			_teams.colours[1 - _player.team])
	_pings.hud_size = _hud_size
	HudStyle.restyle(_pings, _opacity)
	_feed.set_names(names)
	_round_result.set_names(names)
	_summary.set_names(names)
	_announce.set_names(names)
	if _mag_line != null:
		_mag_line.set_names(names)
	_names = names
	_stats = stats


## The magazine hand-off's line under the crosshair and the glyphs by the chevrons (MH3), checking a toss with `share`
## (the simulation's rules) among `characters` characters. Once in match setup; not on the range.
func setup_mag_line(share: MagShare, characters: int) -> void:
	_mag_line = HudMagLine.new()
	add_child(_mag_line)
	_mag_line.setup(_cfg, share, _player, characters, _teams.colours[_player.team], _announce.announcer())
	_place(_mag_line, Vector4(0.5, _cfg.mag_line_at, 0.5, _cfg.mag_line_at), Rect2())
	_mag_line.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mag_line.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mag_line.set_names(_names)
	_mag_line.enabled = _prefs.mag_hand_off
	_mag_line.counted = _prefs.ammo_counter
	_mag_line.set_opacity(_opacity)


func mag_line() -> HudMagLine:
	return _mag_line


## The minimap top left (HudMinimap) for `map`, its field drawn now: call it once in match setup, behind the loading
## screen. `heard` is what your side heard of the other team, `map_name` goes in its caption. Not for the range.
func setup_minimap(map: MapData, cfg: MinimapConfig, heard: MinimapHearing, map_name: String, characters: int) -> void:
	_minimap = HudMinimap.new()
	add_child(_minimap)
	move_child(_minimap, _team_markers.get_index() + 1)
	move_child(_flag_marker, _minimap.get_index()) # the map is drawn over the marker, never the other way round
	move_child(_pings, _minimap.get_index())
	_minimap.setup(cfg, _teams, map, heard, map_name, characters, _cfg.minimap_margin)
	HudStyle.restyle(_minimap, _opacity)
	# Over the rest of the HUD while its key is held (the order wheel never opens with it).
	_field_map = HudFieldMap.new()
	add_child(_field_map)
	_field_map.setup(cfg, _minimap, map, map_name, characters, _sim.pings.lifetime, _cfg.ping_fade)


## Follows the character `watched` (whose eyes the view is through) on the minimap, looking `yaw`, `fraction` of the way
## through the tick, with your Hold here at `hold` while `holding`, and the pings of their team up in `book` (null:
## none) while Settings › HUD › Ping markers is on. Allocates nothing.
func update_minimap(state: GameState, watched: Character, yaw: float, fraction: float, holding: bool,
		hold: Vector3, book: Pings = null) -> void:
	if _minimap == null:
		return
	_minimap.follow(state, watched, yaw, fraction, _prefs.minimap_turn, holding, hold)
	if book != null and _prefs.ping_markers:
		_minimap.add_pings(book, watched.team, state.time, _sim.pings.lifetime, _cfg.ping_fade)


func minimap() -> HudMinimap:
	return _minimap


## The full-screen map (FM1) while `pointer` is open, as update_minimap's arguments say, with its pointer drawn while
## `pointing` (you can ping); never over the scoreboard or the match's summary. Frames `pointer` on it. Allocates
## nothing.
func update_field_map(state: GameState, watched: Character, yaw: float, fraction: float, holding: bool,
		hold: Vector3, book: Pings, pointer: MapPointer, pointing: bool) -> void:
	if _field_map == null:
		return
	var pings := book if _prefs.ping_markers else null
	_field_map.update(state, watched, yaw, fraction, holding, hold, pings, pointer, pointing,
			_board_wanted or _summary.visible)


func field_map() -> HudFieldMap:
	return _field_map


## The sound cue ring (HudSoundCues) for `cues`, on the ring `cfg` sets, over the teammate markers and under the rest;
## hidden until set_sound_cues turns it on. Call once in match setup.
func setup_sound_cues(cues: SoundCues, cfg: AccessibilityConfig) -> void:
	_sound_cues = HudSoundCues.new()
	_sound_cues.setup(cues, cfg)
	_sound_cues.visible = false
	add_child(_sound_cues)
	move_child(_sound_cues, _team_markers.get_index() + 1)
	_keep_own_size(_sound_cues)


## Settings › Accessibility's sound cues: on or off, the markers' size (1 = as built) and colour (an index into
## HudPrefs.COLOURS). Call again after a change.
func set_sound_cues(on: bool, marker_scale: float, colour: int) -> void:
	_cues_on = on
	if _sound_cues == null:
		return
	_sound_cues.visible = on and not _summary.visible
	_sound_cues.set_style(marker_scale, HudPrefs.COLOURS[clampi(colour, 0, HudPrefs.COLOURS.size() - 1)])


## Turns the cue ring with the character `watched` (whose eyes the view is through), looking `yaw`, `fraction` of the
## way through the tick. Allocates nothing.
func place_sound_cues(watched: Character, yaw: float, fraction: float) -> void:
	if _sound_cues != null:
		_sound_cues.follow(watched.prev_position.lerp(watched.position, fraction), yaw)


func sound_cues() -> HudSoundCues:
	return _sound_cues


## What the scoreboard's heading says: the map's name and the line after it, and whether its Pro tips show (opponents
## at Hard, MatchOptions.TIPS_LEVEL).
func set_board_match(map_name: String, sub: String, tips: bool) -> void:
	_board.set_match(_names, map_name, sub, tips)


## The end of the match stamp's line ("DEPOT · HARD BOTS").
func set_match_tail(tail: String) -> void:
	_match_tail = tail.to_upper()


## The match `state` just finished: its summary, as the HUD's match numbers stand (What got you when `show_hits`, the
## Pro tip `tip`, "" for none). It shows once the last round's table makes way.
func open_summary(state: GameState, show_hits: bool, tip: String) -> void:
	_summary.open(state, _stats, _player, show_hits, tip)


## You were hit in round `number` (`facts`, by `shooter_name` in their team's `colour`, the bot's `note`), for the
## summary's What got you.
func add_hit_on_you(number: int, facts: HitFacts, shooter_name: String, colour: Color, note: String) -> void:
	_summary.add_hit(number, facts, shooter_name, colour, note)


func summary() -> MatchSummary:
	return _summary


## Whether the summary is on screen (a click then starts the next match).
func summary_up() -> bool:
	return _summary.visible


## Whether the scoreboard's key is held. Let go, it hides at once (the pause menu opening).
func show_board(held: bool) -> void:
	_board_wanted = held
	if not held:
		_board.visible = false


func board() -> HudScoreboard:
	return _board


## Takes the HUD tab's choices `prefs` (kept, so the crosshair and marker follow later changes too; call again after
## one): the feed's corner and whether its lines fade or stay, the callouts in it, the ammo counter, and the panels'
## opacity. Callouts switched off take their lines out of the feed at once.
func apply_prefs(prefs: HudPrefs) -> void:
	_prefs = prefs
	var right := prefs.feed_corner == HudPrefs.FeedCorner.TOP_RIGHT
	var where := HudFeed.Place.TOP_RIGHT if right else HudFeed.Place.BOTTOM_LEFT
	if where != _feed.corner:
		set_feed_corner(where)
	var stay := prefs.feed_lines == HudPrefs.FeedLines.KEEP
	if stay != _hits.stay:
		_hits.setup(HudPrefs.KEPT_LINES if stay else _cfg.feed_lines, _cfg.feed_line_time, _cfg.feed_fade_time)
		_hits.stay = stay
	if not prefs.callouts:
		_hits.drop_calls()
	_replica.set_counted(prefs.ammo_counter)
	if not is_equal_approx(prefs.panel_opacity, _opacity):
		_opacity = prefs.panel_opacity
		HudStyle.restyle(self, _opacity)
	if _mag_line != null:
		_mag_line.enabled = prefs.mag_hand_off
		_mag_line.counted = prefs.ammo_counter
		_mag_line.set_opacity(_opacity)
	set_hud_size(prefs.hud_size)


## Scales the HUD by `hud_size` (1 = as drawn at 1080p; HudPrefs.hud_size) about the screen's top left, its root as large
## as the screen over the scale, so each part keeps its anchor and its edge and grows from it. The crosshair, the hit
## marker and the sound cue ring keep their own size; the markers over the field are placed where the view sees them.
func set_hud_size(hud_size: float) -> void:
	var s := maxf(hud_size, HUD_SIZE_FLOOR)
	_hud_size = s
	scale_root(self, s)
	if _sound_cues != null:
		_keep_own_size(_sound_cues)
	_team_markers.hud_size = s
	_flag_marker.hud_size = s
	_pings.hud_size = s
	if _hold_marker != null:
		_hold_marker.hud_size = s
	queue_redraw()


func hud_size() -> float:
	return _hud_size


## How much of the flag warning's pulse shows (MotionScale.hud_pulse: none holds it steady at full). Call again after a
## change.
func set_motion(motion: MotionScale) -> void:
	_pulse_share = clampf(motion.hud_pulse, 0.0, 1.0)
	_pings.pops = motion.hud_pulse > 0.0


## Scales `root` (a full-screen Control) by `by` about the top left, keeping it as large as its parent over the scale:
## what is anchored inside it keeps its anchor and its edge and grows from it.
static func scale_root(root: Control, by: float) -> void:
	root.scale = Vector2.ONE * by
	root.set_anchor_and_offset(SIDE_LEFT, 0.0, 0.0)
	root.set_anchor_and_offset(SIDE_TOP, 0.0, 0.0)
	root.set_anchor_and_offset(SIDE_RIGHT, 1.0 / by, 0.0)
	root.set_anchor_and_offset(SIDE_BOTTOM, 1.0 / by, 0.0)


## Holds the summary's panels and the XP card at the share of their size that fits the screen's width and what is left of
## its height under the stack (1 when they fit as built), so a large HUD size or a tall stack never pushes them off.
func _fit_summary() -> void:
	var fit := minf(1.0, (size.x - SUMMARY_EDGE * 2.0) / _summary.row_width())
	var tallest := _summary.column_height()
	if _xp != null:
		tallest = maxf(tallest, _xp.get_combined_minimum_size().y)
	fit = minf(fit, _height_fit(tallest))
	_summary.set_fit(fit)
	if _xp != null:
		_xp.scale = Vector2.ONE * fit


## Holds the round's table and its hint at the share of their size that fits what is left of the height under the stack.
func _fit_round_result() -> void:
	var fit := _height_fit(_round_result.get_combined_minimum_size().y)
	if not is_equal_approx(_round_result.scale.x, fit):
		_round_result.scale = Vector2.ONE * fit


## The share (CARDS_FIT_FLOOR..1) of `height` (px) that fits between the cards' top, XP_GAP under the stack's foot, and
## the screen's bottom edge less SUMMARY_EDGE.
func _height_fit(height: float) -> float:
	var room := size.y - SUMMARY_EDGE - (_middle.position.y + _middle.size.y + XP_GAP)
	return clampf(room / maxf(height, 1.0), CARDS_FIT_FLOOR, 1.0)


## `c` (a full-screen child) undoes the HUD's size: as large as the screen and drawn at 1.
func _keep_own_size(c: Control) -> void:
	scale_root(c, 1.0 / _hud_size)


func prefs() -> HudPrefs:
	return _prefs


## Settings › Accessibility's gauge patterns on or off (Settings.gauge_patterns; call again after a change): Beta's
## score pips, block and flag fill striped, and a low magazine striped as well as yellow.
func set_patterns(on: bool) -> void:
	_score.set_patterned(on)
	_gauge.set_patterned(on)
	_replica.set_patterned(on)


## Settings › Accessibility's Screen reader messages on or off (Settings.read_out; call again after a change).
func set_read_out(on: bool) -> void:
	_announce.set_on(on)


func announce() -> HudAnnounce:
	return _announce


## The hit feed's lines: for tests.
func hit_lines() -> HitFeed:
	return _hits


## The hit feed's corner: top right (newest on top) or bottom left (newest at the bottom).
func set_feed_corner(where: HudFeed.Place) -> void:
	_feed.set_corner(where)
	var m := _cfg.feed_margin
	if where == HudFeed.Place.TOP_RIGHT:
		_place(_feed, Vector4(1.0, 0.0, 1.0, 0.0), Rect2(-m.x, m.y, 0.0, 0.0))
		_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_feed.grow_vertical = Control.GROW_DIRECTION_END
	else:
		_place(_feed, Vector4(0.0, 1.0, 0.0, 1.0), Rect2(m.x, -m.y, 0.0, 0.0))
		_feed.grow_horizontal = Control.GROW_DIRECTION_END
		_feed.grow_vertical = Control.GROW_DIRECTION_BEGIN


## Places the teammate markers as `camera` sees them (HudTeamMarkers), `watched` being whose eyes it is.
## With Settings › HUD › Mag hand-off on, a teammate asking you for a magazine or bringing you one has its glyph.
func place_team_markers(camera: Camera3D, characters: Array[Character], watched: Character, fraction: float) -> void:
	var mags := _mag_line.marks if _mag_line != null and _prefs.mag_hand_off else _no_marks
	_team_markers.place(camera, characters, watched, _teams.colours[_player.team], fraction, not _board.visible, mags)


func feed() -> HudFeed:
	return _feed


func team_markers() -> HudTeamMarkers:
	return _team_markers


func round_result() -> HudRoundResult:
	return _round_result


## Whether the match's last round table still holds back the results (the XP card and the next match wait for it).
func holds_results() -> bool:
	return _round_result.holds_results()


## The reload prompt (RL2), and whether it shows.
func reload_prompt() -> HudReloadPrompt:
	return _reload_prompt


func reload_prompt_shown() -> bool:
	return _reload_prompt.visible


## Whether "Leaves in the way · step clear to shoot" shows.
func leaves_notice_shown() -> bool:
	return _leaves_notice.visible


## Whether a Jump press would vault this tick: the prompt shows, and stays up vault_prompt_hold after.
func set_vault_ready(ready: bool) -> void:
	if ready:
		if _vault_left <= 0.0:
			# the key is whatever Jump is bound to now
			_vault_prompt.text = tr("HUD_VAULT") % KeyNames.of_action(&"jump")
		_vault_left = _cfg.vault_prompt_hold


## The door in your reach this tick (DO1): DoorPrompt.NONE hides the prompt; OPEN and SHUT say what Use would do, with
## Use's key as it is bound when the prompt changes (called each tick: the text is built only then, as the vault
## prompt's). Shown only while you are in play.
func set_door_prompt(what: DoorPrompt) -> void:
	if what == _door_want:
		return
	_door_want = what
	if what != DoorPrompt.NONE:
		var key := KeyNames.of_action(&"use_door")
		_door_prompt.text = tr("HUD_DOOR_OPEN" if what == DoorPrompt.OPEN else "HUD_DOOR_SHUT") % key


## Whether the door prompt shows.
func door_prompt_shown() -> bool:
	return _door_prompt.visible


## Shows "What got you" for `facts` (the hit on you just called): the shooter's name in their team's colour and the
## bot's personality `note` ("" for none). It stays until the next round starts.
func show_what_got_you(facts: HitFacts, shooter_name: String, colour: Color, note: String) -> void:
	hide_what_got_you()
	_what_got_you = WhatGotYouCard.new(facts, shooter_name, colour, note)
	var top := _minimap.under_top() if _minimap != null else CARD_TOP
	_place(_what_got_you, Vector4(0.0, 0.0, 0.0, 0.0), Rect2(CARD_LEFT, top, WhatGotYouCard.WIDTH, 0.0))
	add_child(_what_got_you)
	_what_got_you.visible = not _board.visible
	HudStyle.restyle(_what_got_you, _opacity)


func hide_what_got_you() -> void:
	if _what_got_you != null:
		_what_got_you.queue_free()
		_what_got_you = null


func what_got_you() -> WhatGotYouCard:
	return _what_got_you


## Whether "SPACE Hold to skip the round" shows (you are out and the round plays on); the key is Jump's as bound now.
func set_skip_hint(show: bool) -> void:
	if show == _skip_hint.visible:
		return
	_skip_hint.visible = show
	if show:
		_skip_key.text = KeyNames.of_action(&"jump").to_upper()


func skip_hint_shown() -> bool:
	return _skip_hint.visible


## Whose eyes the view is from: a bot's name, or "" for your own (or a bot with no name). The line shows only then.
func set_watching(bot_name: String) -> void:
	if bot_name == _watching_name:
		return
	_watching_name = bot_name
	_watching.visible = bot_name != ""
	if _watching.visible:
		_watching.text = tr("HUD_WATCHING") % bot_name


## The tick's events: your hits, the round's turns, the magazine hand-off's line (`mag_from_wheel`: your last Need a
## Mag was picked on the order wheel, so its refusal shows there).
func on_tick(state: GameState, mag_from_wheel: bool = false) -> void:
	if _mag_line != null:
		_mag_line.on_tick(state, mag_from_wheel)
	if _readout != null:
		_readout.on_tick(state)
		_challenge.on_tick(state)
	var events := state.events
	for i in events.count:
		var e := events.items[i]
		match e.kind:
			GameEvent.Kind.CHARACTER_HIT:
				if e.actor == _player.id and e.target != _player.id:
					_marker_left = _cfg.marker_time
				if e.actor >= 0:
					# The line you were hit in stays up until the round ends.
					_hits.add(e.actor, e.target, state.time, e.target == _player.id)
			GameEvent.Kind.RICOCHET_TICK:
				# Never over a round's own banner.
				if e.target == _player.id and not _banner.visible:
					_show_banner("", HudStyle.caps("HUD_RICOCHET"))
					_banner_left = _cfg.ricochet_time
			GameEvent.Kind.HOP_UP:
				if e.actor == _player.id:
					_show_hop_up(e.value / 100.0)
			GameEvent.Kind.BB_IMPACT:
				if e.actor == _player.id and e.target < 0 and e.value == BBStep.IN_LEAVES \
						and e.position.distance_to(Lean.eye(_player, _sim.body, _sim.hits)) <= _cfg.leaves_notice_near:
					_leaves_left = _cfg.leaves_notice_time
			GameEvent.Kind.ROUND_START:
				_round_result.close()
				hide_what_got_you()
				_hits.release_kept()
				_hits.drop_calls() # last round's calls are about last round
				if e.value == 1:
					hide_xp()
					_summary.close()
					if state.round_state.draws == 0:
						_hits.clear()
						_summary.clear_hits()
				var rs := state.round_state
				if rs.practice:
					continue
				if rs.mode == RoundState.Mode.ATTACK_DEFEND:
					var attacking := _player.team == rs.attackers
					_show_banner(HudStyle.side_round_title(e.value, attacking),
							HudStyle.side_round_sub(e.value, _rounds.half_time_after, attacking))
				else:
					_show_banner(HudStyle.round_title(e.value), HudStyle.round_sub(e.value, _rounds.half_time_after))
			GameEvent.Kind.OVERTIME:
				_show_banner(HudStyle.caps("HUD_OVERTIME"), HudStyle.caps("HUD_TOUCH_FLAG"))
				_banner_left = _cfg.overtime_banner_time
			GameEvent.Kind.ROUND_OVER:
				_round_over(state.round_state, e, state.time)
			GameEvent.Kind.MATCH_OVER:
				_round_result.match_over()
				_show_banner(HudStyle.round_stamp(e.value, _player.team), _match_stamp_sub(state.round_state.score),
						_teams.colours[e.value] if e.value >= 0 else Color.TRANSPARENT)
	_announce.on_tick(state)


## Your team's calls said in `said` (CalloutLog) since the last look: each a line in the feed with the hits' time and
## fade, and with Screen reader messages on and the feed showing a polite message ("Brick: Two, Crate yard!"). The
## other team's words never show. While Settings › HUD › Callouts is off they are passed over, never shown late.
## Allocates nothing but the message's text.
func on_calls(said: CalloutLog, state: GameState) -> void:
	if said != _call_log or _call_serial > said.total:
		_call_log = said
		_call_serial = said.oldest()
	var from := maxi(_call_serial, said.oldest())
	_call_serial = said.total
	if not _prefs.callouts:
		return
	var speakers := state.characters
	for serial in range(from, said.total):
		var call := said.entry(serial)
		if call.team != _player.team or call.speaker_id < 0 or call.speaker_id >= speakers.size():
			continue
		_hits.add_call(call.speaker_id, call.line, call.time)
		# The newest line, so read whenever the feed is up to show it.
		if _feed.newest_shows():
			_announce.announcer().add_call(speakers[call.speaker_id], call.line)


## The finished match's XP under the banner (`settled`, at the bots' `difficulty`, `progress` as it stands now), until the
## next match starts.
func show_xp(settled: PlayerTally.Settled, difficulty: StringName, progress: Progress) -> void:
	hide_xp()
	_xp = XpCard.new(settled, difficulty, progress, Pool.shared())
	_place(_xp, Vector4(0.5, 0.5, 0.5, 0.5), Rect2(-XpCard.WIDTH * 0.5, 0.0, XpCard.WIDTH, 0.0))
	_xp.pivot_offset_ratio = Vector2(0.5, 0.0) # held smaller about its top middle with the summary (_fit_summary)
	add_child(_xp)
	_hang_cards()
	HudStyle.restyle(_xp, _opacity)
	_xp.visible = not _round_result.holds_results()


func hide_xp() -> void:
	if _xp != null:
		_xp.queue_free()
		_xp = null


func xp_card() -> XpCard:
	return _xp


## Refreshes from `state` and the eye's zoom, `delta` seconds since the last frame.
func update(state: GameState, zoom: float, delta: float) -> void:
	var c := _player
	var a := c.armament
	var in_play := Elimination.is_in_play(c)
	_marker_left = maxf(0.0, _marker_left - delta)
	if _hop_left > 0.0:
		_hop_left -= delta
		if _hop_left <= 0.0:
			_replica.hide_hop()
	_vault_left = maxf(0.0, _vault_left - delta)
	if _step_left > 0.0:
		_step_left -= delta
		_step_line.visible = _step_left > 0.0
	_vault_prompt.visible = _vault_left > 0.0 and in_play
	_door_prompt.visible = _door_want != DoorPrompt.NONE and in_play and not _vault_prompt.visible
	_leaves_left = maxf(0.0, _leaves_left - delta)
	_leaves_notice.visible = _leaves_left > 0.0 and in_play
	_reload_prompt.show_when(manual_reload and in_play and state.round_state.is_live() and a.reload_due())
	# The round's stamp stays up as long as the table under it, the match's banner as long as the XP.
	if _stats != null:
		_round_result.update(state, _stats, _player)
		_board.update(state, _stats, _player, _board_wanted)
	if _xp != null:
		_xp.visible = not _round_result.holds_results()
	var summary_was_up := _summary.visible
	_summary.visible = _summary.is_open() and not _round_result.holds_results()
	if _summary.visible != summary_was_up:
		_seat_middle()
	if _summary.visible or _xp != null:
		_fit_summary()
	if _round_result.visible:
		_fit_round_result()
	if _minimap != null:
		_minimap.visible = not _summary.visible
	if _sound_cues != null:
		_sound_cues.visible = _cues_on and not _summary.visible
	_replica.visible = not _summary.visible
	_bottom.visible = not _summary.visible
	_top.visible = not _summary.visible and _readout == null
	_feed.visible = not _summary.visible and _readout == null
	if _summary.visible and _what_got_you != null:
		hide_what_got_you()
	elif _what_got_you != null:
		_what_got_you.visible = not _board.visible # the card and the Tab scoreboard share the left: Tab wins
	if _banner_left > 0.0 and _xp == null and not _summary.is_open() and not _round_result.is_open():
		_banner_left -= delta
		if _banner_left <= 0.0:
			_banner.visible = false
	var hit_call := not in_play and c.status != Character.Status.OUT
	_hit_label.visible = hit_call
	_hit_sub.visible = hit_call
	# A banner up with the hit call keeps its place as the call ends: an empty slot as tall as the call stays above it
	# (measured once, as the slot is first held; `_show_banner` drops it for a banner shown with no call up).
	if hit_call and _banner.visible and not _hit_held:
		_hit_held = true
		_hit_hold.custom_minimum_size.y = _hit_label.get_combined_minimum_size().y + _hit_sub.get_combined_minimum_size().y \
				+ _middle.get_theme_constant("separation")
	elif not _banner.visible:
		_hit_held = false
	_hit_hold.visible = _hit_held and not hit_call
	# The crosshair's gap is the spread a shot really has now (two standard deviations), on this screen at this zoom.
	_show_cross = in_play and c.aim_raise < 0.5 and not a.replicas.is_empty() and not a.holstered
	if _show_cross:
		var spread := deg_to_rad(a.replica().spread_deg * c.spread_scale) * 2.0
		var half_fov := deg_to_rad(_view.vertical_fov(zoom)) * 0.5
		# On the screen, not the HUD's scaled root: the crosshair keeps its own size.
		_gap = CrosshairDraw.gap(_prefs, tan(spread) / tan(half_fov) * size.y * _hud_size * 0.5)
	if not a.replicas.is_empty():
		_replica.refresh(a, c.grenades)
		if a.active != _hop_slot and _hop_left > 0.0:
			_hop_left = 0.0
			_replica.hide_hop()
	var rs := state.round_state
	var flag_mode := rs.mode == RoundState.Mode.ATTACK_DEFEND
	var overtime := HudStyle.overtime_clock(rs, _sim.flag.max_overtime)
	if overtime >= 0:
		_score.set_clock(overtime, true)
	else:
		_score.set_clock(ceili(rs.clock))
	_score.set_score(rs.score[0], rs.score[1])
	_score.set_round(rs.number)
	_score.set_sides(rs.attackers if flag_mode else -1)
	_gauge.visible = flag_mode
	if flag_mode and rs.attackers >= 0:
		_gauge.set_flag(rs.flag.progress, _teams.colours[rs.attackers], rs.attackers == HudStyle.STRIPED_TEAM)
	_update_warning(rs, delta)
	if _readout != null:
		_readout.visible = state.challenge.phase == RangeChallenge.Phase.OFF
		_challenge.update(state, delta)
	_announce.advance(delta)
	_hits.prune(state.time)
	_feed.fit(_feed_room())
	_feed.refresh(_hits, state.time, state.characters, _player)
	queue_redraw()


## The flag marker is over Elimination's overtime flag this match (its chequered glyph and height): call once, after
## setup, on a map with a spot for it.
func use_overtime_flag() -> void:
	_flag_marker.use_overtime()


## Places the marker over the pole at `pole` as seen by `camera` (HudFlagMarker); hidden outside Attack / Defend
## (`show` false). In Elimination (use_overtime_flag) `pole` is the overtime flag's foot, shown while it stands.
func place_flag_marker(camera: Camera3D, pole: Vector3, show: bool) -> void:
	_flag_marker.place(camera, pole, show, size, pin_point(), pin_right_top(), _left_stack_floor())


## Where the first marker pinned to the screen's left edge sits (its plate's top left): under the minimap and its
## caption, and under What got you while it is up. Further ones go the minimap's pin_step_down under each other.
func pin_point() -> Vector2:
	if _minimap == null:
		return Vector2(CARD_LEFT, CARD_TOP)
	var card := _what_got_you
	return _minimap.pin(card.offset_top + card.size.y if card != null and card.visible else 0.0)


## The height a bottom-left feed may have under What got you (px; negative for no limit): its newest lines that fit
## below the card with feed_card_gap clear.
func _feed_room() -> float:
	var card := _what_got_you
	if _feed.corner != HudFeed.Place.BOTTOM_LEFT or card == null or not card.visible:
		return -1.0
	return maxf(0.0, size.y - _cfg.feed_margin.y - (card.offset_top + card.size.y + _cfg.feed_card_gap))


## How low a plate pinned in the left stack may reach (px): feed_card_gap above the bottom-left feed's top, or the
## screen's bottom when the feed is elsewhere. Past it the plate pins on the right instead.
func _left_stack_floor() -> float:
	if _feed.corner != HudFeed.Place.BOTTOM_LEFT:
		return size.y
	var lines := _feed.lines_height()
	if lines <= 0.0:
		return size.y
	return size.y - _cfg.feed_margin.y - lines - _cfg.feed_card_gap


## The top of a plate pinned to the screen's right edge: under the hit feed when that is in the top right, else the
## top margin.
func pin_right_top() -> float:
	var top := _cfg.feed_margin.y
	if _feed.corner != HudFeed.Place.TOP_RIGHT:
		return top
	var rows := _feed.get_combined_minimum_size().y
	return top + rows + _cfg.feed_gap if rows > 0.0 else top


## The marker's words ("FLAG · 24 m"), or "" while it is hidden: for tests.
func flag_marker_text() -> String:
	return _flag_marker.text()


## Whether the flag marker shows (over the flag or pinned to a side).
func flag_marker_shown() -> bool:
	return _flag_marker.visible


## Squad orders (SO4): Hold here's marker, and over it the order wheel round the crosshair. `controls` has the wheel's
## orders, keys and reach. The wheel builds itself when it first opens, so a session that never gives an order (the
## range) pays nothing.
func setup_orders(controls: ControlsConfig) -> void:
	var colour := _teams.colours[_player.team]
	_hold_marker = HudHoldMarker.new()
	add_child(_hold_marker)
	_hold_marker.setup(_cfg, colour)
	_hold_marker.hud_size = _hud_size
	_order_wheel = HudOrderWheel.new()
	_place(_order_wheel, Vector4(0.5, 0.5, 0.5, 0.5), Rect2(0.0, 0.0, 0.0, 0.0))
	add_child(_order_wheel)
	_order_wheel.setup(_cfg, controls, colour)
	HudStyle.restyle(_order_wheel, _opacity)
	HudStyle.restyle(_hold_marker, _opacity)


## Shows the wheel as `wheel` (the pointer PlayerInput moves) has it, with the order `in_force` and the last order
## given (`outcome`, for its notice), `delta` seconds on. Nothing is drawn while it is closed. Need a Mag reads Toss a
## Mag while a toss is in reach, a refusal of it picked on the wheel shows in the middle, and the hand-off's line hides
## while the wheel is open (and under the scoreboard or the match's summary).
func update_orders(wheel: OrderWheelPointer, in_force: SquadOrder.Kind, outcome: SquadOrders.Outcome,
		delta: float) -> void:
	if _mag_line != null:
		var told := _mag_line.take_wheel_notice()
		if not told.is_empty():
			_order_wheel.tell(told)
		_order_wheel.set_mag_toss(_mag_line.toss_ready())
	_order_wheel.update(wheel, in_force, outcome, _player.id, delta)
	if _mag_line != null:
		_mag_line.update(wheel.open, _summary.visible or _board.visible)


## Places Hold here's marker over `spot` (the middle of the spots held) as seen by `camera`, hidden when `show` is false;
## held at the edge clear of the flag marker. `going`: Go there's (FM1), your teammates still on their way.
func place_hold_marker(camera: Camera3D, spot: Vector3, show: bool, going: bool = false) -> void:
	_hold_marker.set_going(going)
	var slots := _hold_slots
	slots.left = pin_point()
	slots.right_top = pin_right_top()
	slots.floor_y = _left_stack_floor()
	slots.step = _minimap.step_down() if _minimap != null else 0.0
	slots.flag_side = _flag_marker.pinned_side()
	slots.flag = _flag_marker.occupied()
	slots.panel = _minimap.panel_rect() if _minimap != null else Rect2()
	_hold_marker.place(camera, spot, show, size, slots.flag, slots)


## Places your team's pings up in `book` at `now` (s of match time) as `camera` sees them (HudPingMarkers): pinned at a
## side under the flag's and Hold here's plates there. Hidden when `show` is false (you watch someone else), with
## Settings › HUD › Ping markers off, the scoreboard up or the match's summary. Call after the flag and Hold here's
## markers are placed. Allocates nothing.
func place_pings(camera: Camera3D, book: Pings, now: float, show: bool) -> void:
	var on := show and _prefs.ping_markers and not _board.visible and not _summary.visible
	if not on:
		_pings.hide_all()
		return
	var stack := _ping_stack
	var gap := _cfg.ping_stack_gap
	stack.left = pin_point()
	stack.floor_y = _left_stack_floor()
	stack.right_top = pin_right_top()
	stack.right_x = stack.left.x
	var flag := _flag_marker.occupied()
	var side := _flag_marker.pinned_side()
	if side < 0:
		stack.left.y = maxf(stack.left.y, flag.end.y + gap)
	elif side > 0:
		stack.right_top = maxf(stack.right_top, flag.end.y + gap)
	if _hold_marker != null and _hold_marker.visible:
		var hold := _hold_marker.get_rect()
		if _hold_marker.pin == HudHoldMarker.Pin.LEFT and hold.position.x < size.x * 0.5:
			stack.left.y = maxf(stack.left.y, hold.end.y + gap)
		elif _hold_marker.pin == HudHoldMarker.Pin.LEFT or _hold_marker.pin == HudHoldMarker.Pin.RIGHT:
			stack.right_top = maxf(stack.right_top, hold.end.y + gap)
	_pings.place(camera, book, now, true, size, stack)


## Hides the ping markers at once (the pause menu opening).
func hide_pings() -> void:
	_pings.hide_all()


func ping_markers() -> HudPingMarkers:
	return _pings


## Puts the wheel away (the pause menu opening).
func close_order_wheel() -> void:
	_order_wheel.dismiss()


func order_wheel() -> HudOrderWheel:
	return _order_wheel


func hold_marker() -> HudHoldMarker:
	return _hold_marker


## Whether the "Their flag is going up!" warning shows: for tests.
func flag_warning_shown() -> bool:
	return _warning.visible


## The round banner's words ("" while it is hidden): for tests.
func banner_text() -> String:
	return "%s / %s" % [_banner.big_text(), _banner.sub_text()] if _banner.visible else ""


func flag_gauge() -> HudFlagGauge:
	return _gauge


func score() -> HudScore:
	return _score


## The warning pulses while the other team raises its flag and you aren't at the rope pulling it down; with Reduced
## motion it holds steady at full.
func _update_warning(rs: RoundState, delta: float) -> void:
	var c := _player
	var at_rope := Flag.at_pole(c, rs.flag, _sim.flag)
	var show := rs.mode == RoundState.Mode.ATTACK_DEFEND and rs.is_live() and rs.attackers >= 0 \
			and c.team != rs.attackers and rs.flag.status == FlagState.Status.RAISING and not at_rope
	_warning.visible = show
	if show:
		_warning_flag.colour = _teams.colours[rs.attackers]
		_pulse += delta
		var dip := (1.0 - HudStyle.WARNING_PULSE_LOW) * _pulse_share
		_warning.modulate.a = 1.0 - dip * (0.5 - 0.5 * cos(_pulse * TAU * _cfg.flag_warning_pulse))
	else:
		_pulse = 0.0


func _draw() -> void:
	var centre := size * 0.5
	# The crosshair and the hit marker keep their own size whatever the HUD's: drawn about the middle at 1 / HUD size.
	draw_set_transform(centre * (1.0 - 1.0 / _hud_size), 0.0, Vector2.ONE / _hud_size)
	if _show_cross:
		CrosshairDraw.cross(self, centre, _prefs, _gap)
	if _marker_left > 0.0 and _prefs.marker:
		CrosshairDraw.marker(self, centre, _prefs, _gap, _cfg.marker_size, _cfg.marker_width,
				_marker_left / _cfg.marker_time)


## The hop-up readout for the replica in hand with its dial at `dial`: the setting and how far a level shot stays flat.
## Flies one BB (Ballistics.hop_up_reach), so only on a turn, never per frame.
func _show_hop_up(dial: float) -> void:
	var a := _player.armament
	var reach := Ballistics.hop_up_reach(a.replica(), dial, _sim, 1.0 / Engine.physics_ticks_per_second, _cfg.hop_band,
			_cfg.hop_range, a.bb_weights[a.active])
	var metres := roundi(reach.on_target_to)
	var flat := tr("HUD_METRES_PLUS") % metres if reach.on_target_to >= _cfg.hop_range else tr("HUD_METRES") % metres
	# Over-hopped, the BB leaves the band climbing, not dropping: say so, or a stronger dial would read as a worse one.
	var key := "HUD_HOP_UP_HIGH" if reach.peak_rise > _cfg.hop_band else "HUD_HOP_UP"
	_replica.show_hop(tr(key) % [roundi(dial * 100.0), flat])
	_hop_left = _cfg.hop_show_time
	_hop_slot = a.active


## A round ended (`e`, ROUND_OVER): the stamp from your side (WON, LOST or DRAW, in the winners' colour) over the round
## and how it was won, and the round's table under it soon after.
func _round_over(rs: RoundState, e: GameEvent, state_time: float) -> void:
	var reason := e.value2 as GameEvent.RoundEnd
	var by_flag := HudStyle.ended_by_flag(rs.mode, reason)
	var key := _teams.names[e.value] if e.value >= 0 else ""
	_show_banner(HudStyle.round_stamp(e.value, _player.team),
			HudStyle.round_stamp_sub(rs.number, e.value, key, by_flag, reason),
			_teams.colours[e.value] if e.value >= 0 else Color.TRANSPARENT)
	# With the overtime played: Attack / Defend's at the rope, or Elimination's at the flag (its time less what is left).
	var played := _rounds.round_time - rs.clock + (rs.overtime if is_finite(rs.overtime) else 0.0)
	if rs.overtime_flag.up:
		played += _sim.overtime.time - rs.overtime_flag.left
	_round_result.round_over(rs.number, roundi(played), state_time)


## "THE MATCH · ALPHA 5 – 3 BETA · DEPOT · HARD BOTS": your team first.
func _match_stamp_sub(score: PackedInt32Array) -> String:
	var you := _player.team
	var line := tr("SUM_STAMP_SUB") % [tr(_teams.names[you]), score[you], score[1 - you], tr(_teams.names[1 - you])]
	return (line + " · " + _match_tail if _match_tail != "" else line).to_upper()


func _show_banner(text: String, sub: String, colour: Color = Color.TRANSPARENT) -> void:
	_banner.show_text(text, sub, colour)
	_banner_left = _cfg.banner_time
	if _hit_held and not _hit_label.visible:
		_hit_held = false
		_hit_hold.visible = false


## The automatic graphics step-down's line under the score bar for `seconds`: "GRAPHICS  Set to `preset_name` to keep
## the game smooth  Settings › Graphics to pick your own".
func show_graphics_step(preset_name: String, seconds: float) -> void:
	_step_words.text = tr("HUD_GRAPHICS_STEPPED") % preset_name
	_step_left = seconds
	_step_line.visible = seconds > 0.0


## The graphics step-down's line, while it shows (tests).
func graphics_step_line() -> PanelContainer:
	return _step_line if _step_line.visible else null


## The step-down's plate: a yellow edge on the left, the kicker, the line and the hint in a row; hidden until shown.
func _build_step_line(parent: Control) -> void:
	_step_line = PanelContainer.new()
	_step_line.name = "GraphicsStep"
	_step_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_step_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := HudStyle.panel_box(STEP_BACKING, STEP_PAD.z, STEP_PAD.y)
	box.content_margin_left = STEP_PAD.x
	box.content_margin_bottom = STEP_PAD.w
	box.border_color = GameTheme.YELLOW
	box.border_width_left = roundi(HudStyle.BANNER_RULE)
	_step_line.add_theme_stylebox_override("panel", box)
	_step_line.visible = false
	parent.add_child(_step_line)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", STEP_GAP)
	_step_line.add_child(row)
	var kicker := HudStyle.label(row, STEP_KICKER_SIZE, 800, GameTheme.YELLOW, HORIZONTAL_ALIGNMENT_LEFT,
			STEP_KICKER_SPACING)
	kicker.text = tr("HUD_GRAPHICS_KICKER").to_upper()
	kicker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_step_words = HudStyle.label(row, STEP_SIZE, 700, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_step_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hint := HudStyle.label(row, STEP_HINT_SIZE, 600, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	hint.text = tr("HUD_GRAPHICS_PICK_OWN")
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## "SPACE Hold to skip the round" under the watching line: the key in a chip, the words beside it, a yellow edge.
func _build_skip_hint(parent: Control) -> void:
	_skip_hint = PanelContainer.new()
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := HudStyle.panel_box(HudStyle.BACKING_CLOCK, 12, 8)
	box.border_color = GameTheme.YELLOW
	box.border_width_left = roundi(HudStyle.BANNER_RULE)
	_skip_hint.add_theme_stylebox_override("panel", box)
	_skip_hint.visible = false
	parent.add_child(_skip_hint)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", SKIP_GAP)
	_skip_hint.add_child(row)
	_skip_key = HudStyle.label(row, SKIP_KEY_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.SPACING_AIM)
	var chip := GameTheme.box(GameTheme.CARD_HI, GameTheme.LINE, SKIP_KEY_PAD.x, SKIP_KEY_PAD.y)
	_skip_key.add_theme_stylebox_override("normal", chip)
	var words := HudStyle.label(row, SKIP_SIZE, 700, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	words.text = tr("HUD_SKIP_HOLD")
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Seats the hit call and banner stack under the score bar's column (`_top`: the bar, "First to N" and whatever shows
## under them), or MARGIN from the top where there is no bar (the range, and while the match summary hides it). Runs when
## that column's size changes or the summary opens or closes.
func _seat_middle() -> void:
	var edge := MARGIN
	if _readout == null and not _summary.visible:
		edge = _top.position.y + _top.size.y + MIDDLE_GAP
	_middle.offset_top = edge
	_middle.offset_bottom = edge
	_hang_cards()


## Hangs the finished match's XP, the round's table and the match summary XP_GAP under the stack's foot (they are
## anchored at the screen's middle, so offsets from it) and fits them to the height left. Runs when the stack's place or
## layout or the screen's size changes.
func _hang_cards() -> void:
	var y := _middle.position.y + _middle.size.y + XP_GAP - size.y * 0.5
	_round_result.offset_top = y
	_round_result.offset_bottom = y
	if _xp != null:
		_xp.offset_top = y
		_xp.offset_bottom = y
	_summary.set_top(y)
	if _summary.visible or _xp != null:
		_fit_summary()
	if _round_result.visible:
		_fit_round_result()


## Anchors `c` at `anchors` (left, top, right, bottom shares of the screen) with `rect` as offsets from them.
static func _place(c: Control, anchors: Vector4, rect: Rect2) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = rect.position.x
	c.offset_top = rect.position.y
	c.offset_right = rect.end.x
	c.offset_bottom = rect.end.y

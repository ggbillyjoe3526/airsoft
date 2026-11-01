extends GutTest
## The full-screen map's detail (FM2): the field fills the screen beside a key, under a header saying what your side
## must do; the flags' letters (Attack / Defend) or the overtime spot (Elimination), each end's start in its team's
## colour (swapped at half time) and the dead zones, the doors, and the named areas' words laid out with none over
## another, on Depot, Woodland and The Street. The shared field drawing tints ground by what it is, greens hedges and
## thickets, and shades sloping ground's relief. A frame allocates nothing.

const TOLERANCE := 1.5 / 255.0

var cfg: MinimapConfig = null
var teams: TeamConfig = null
var state: GameState = null
var heard: MinimapHearing = null
var you: Character = null
var mate: Character = null
var enemy: Character = null
var pointer: MapPointer = null
var maps: Dictionary[String, MapData] = {}


func before_all() -> void:
	for id: String in ["depot", "woodland", "street"]:
		maps[id] = MapData.load_map(id, MapStyle.new(), 2)


func after_all() -> void:
	maps.clear()


func before_each() -> void:
	cfg = MinimapConfig.new()
	teams = TeamConfig.new()
	state = GameState.new(5)
	var kit: Array[ReplicaConfig] = [ReplicaConfig.new()]
	you = Character.new(0, 0, Vector3(-10.0, 0.0, 1.5), 0.0, kit)
	mate = Character.new(1, 0, Vector3(-3.5, 0.0, -3.5), 0.0, kit)
	enemy = Character.new(2, 1, Vector3(3.0, 0.0, -4.0), 0.0, kit)
	enemy.end = 1
	for c: Character in [you, mate, enemy]:
		state.characters.append(c)
		c.prev_position = c.position
	heard = MinimapHearing.new(cfg)
	heard.on_tick(state, you)
	pointer = MapPointer.new()


func _field_map(map: MapData) -> HudFieldMap:
	var root := Control.new()
	root.size = Vector2(1920.0, 1080.0)
	add_child_autofree(root)
	var mm := HudMinimap.new()
	root.add_child(mm)
	mm.setup(cfg, teams, map, heard, map.display_name, state.characters.size(), Vector2(32.0, 26.0))
	var fm := HudFieldMap.new()
	root.add_child(fm)
	fm.setup(cfg, mm, map, map.display_name, state.characters.size(), 8.0, 2.0)
	return fm


func _show(fm: HudFieldMap) -> void:
	if not pointer.open:
		pointer.start()
	fm.update(state, you, 0.0, 1.0, false, Vector3.ZERO, null, pointer, true, false)


func _attack_defend(attackers: int) -> void:
	var rs := state.round_state
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	rs.attackers = attackers


# --- the screen ---

func test_every_map_fits_beside_the_key_under_the_header() -> void:
	for id: String in maps:
		var fm := _field_map(maps[id])
		_show(fm)
		var v := fm.view()
		assert_true(fm.visible, id)
		assert_almost_eq(v.position.y, cfg.map_margin + cfg.map_header, 0.5, "%s: under the header" % id)
		assert_lt(v.position.x + v.size.x, 1920.0 - cfg.map_margin - cfg.map_key_width, "%s: left of the key" % id)
		var span := v.field_size() * v.px_per_m()
		assert_lt(span.x, v.size.x + 0.5, id)
		assert_lt(span.y, v.size.y + 0.5, id)
		assert_true(span.x > v.size.x * 0.9 or span.y > v.size.y * 0.9, "%s: as big as the room allows" % id)
		assert_eq(pointer.half, v.size * 0.5, "%s: the pointer roams the whole room" % id)


func test_the_header_names_the_map_the_round_and_what_your_side_must_do() -> void:
	var fm := _field_map(maps["depot"])
	_attack_defend(0)
	_show(fm)
	assert_eq(fm.title_text(), "Depot")
	assert_eq(fm.sub_text(), "Round 1  ·  Attack / Defend")
	assert_eq(fm.goal_text(), "You attack: raise the flag at A / B")
	_attack_defend(1)
	_show(fm)
	assert_eq(fm.goal_text(), "You defend: hold A / B until time runs out", "the goal follows the side")
	state.round_state.mode = RoundState.Mode.ELIMINATION
	state.round_state.attackers = -1
	state.round_state.number = 2
	_show(fm)
	assert_eq(fm.sub_text(), "Round 2  ·  Elimination")
	assert_eq(fm.goal_text(), "Knock out the other team")
	state.round_state.overtime_flag.up = true
	_show(fm)
	assert_eq(fm.goal_text(), "Overtime: raise the flag or knock them out")


func test_flags_show_in_attack_defend_and_the_overtime_spot_in_elimination() -> void:
	var fm := _field_map(maps["woodland"])
	_attack_defend(0)
	_show(fm)
	var ov := fm.overlay()
	assert_true(ov._flags_on)
	assert_false(ov._overtime_on)
	assert_eq(ov._flags_px.size(), 2, "A and B")
	var a := fm.view().size * 0.5 + fm.view().panel_of(Vector2(maps["woodland"].poles[0].x, maps["woodland"].poles[0].z))
	assert_almost_eq(ov._flags_px[0].distance_to(a), 0.0, 0.01, "A over its pole")
	state.round_state.mode = RoundState.Mode.ELIMINATION
	state.round_state.attackers = -1
	_show(fm)
	assert_false(ov._flags_on)
	assert_true(ov._overtime_on, "where the overtime flag will rise")


func test_each_start_takes_the_colour_of_the_team_starting_there_and_swaps_at_half_time() -> void:
	var fm := _field_map(maps["depot"])
	_show(fm)
	var ov := fm.overlay()
	assert_eq(ov._end_colours[0], teams.colours[0])
	assert_eq(ov._end_colours[1], teams.colours[1])
	assert_eq(ov._end_words[0], "ALPHA START")
	you.end = 1
	mate.end = 1
	enemy.end = 0
	state.round_state.number = 7
	_show(fm)
	assert_eq(ov._end_colours[0], teams.colours[1], "swapped ends")
	assert_eq(ov._end_words[1], "ALPHA START")


func test_the_marks_come_from_the_map() -> void:
	for id: String in maps:
		var map := maps[id]
		var m := FieldMapMarks.of(map, cfg.map_start_pad)
		assert_eq(m.flags.size(), map.poles.size(), id)
		assert_eq(m.doors.size(), map.doors.size() * 2, "%s: a line across each door" % id)
		assert_eq(m.starts.size(), 2, id)
		for e in 2:
			for s in map.ends[e].spawns:
				assert_true(m.starts[e].has_point(Vector2(s.position.x, s.position.z)), "%s: start round its spawns" % id)
			for s in map.ends[e].dead_zone:
				assert_true(m.dead_zones[e].has_point(Vector2(s.position.x, s.position.z)), "%s: dead zone" % id)
		for i in m.doors.size() / 2:
			var d := map.doors[i]
			assert_almost_eq(m.doors[i * 2].distance_to(m.doors[i * 2 + 1]), maxf(d.size.x, d.size.z), 1e-4,
					"%s: across the doorway" % id)


# --- the words ---

func test_words_never_cover_each_other_on_any_map() -> void:
	for id: String in maps:
		var fm := _field_map(maps[id])
		_attack_defend(0)
		_show(fm)
		var ov := fm.overlay()
		var boxes: Array[Rect2] = []
		for i in ov._word_boxes.size():
			if ov.word_box(i).has_area():
				boxes.append(ov.word_box(i))
				assert_true(ov._field_px.encloses(ov.word_box(i)), "%s: on the field" % id)
		assert_gt(boxes.size(), 10, "%s: names its places" % id)
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				assert_false(boxes[i].intersects(boxes[j]), "%s: one over another" % id)


func test_lay_out_moves_a_word_off_another_and_leaves_out_one_with_no_room() -> void:
	var bounds := Rect2(0.0, 0.0, 400.0, 400.0)
	var wants: Array[Rect2] = [Rect2(100.0, 100.0, 80.0, 14.0), Rect2(110.0, 104.0, 60.0, 14.0)]
	var none: Array[Rect2] = []
	var got := FieldMapMarks.lay_out(wants, none, bounds, Vector2(2.0, 2.0))
	assert_eq(got[0], wants[0], "the first keeps its place")
	assert_true(got[1].has_area())
	assert_false(got[1].grow(2.0).intersects(got[0]), "the second moved off it, a gap between")
	var walled: Array[Rect2] = [Rect2(0.0, 0.0, 400.0, 400.0)]
	got = FieldMapMarks.lay_out(wants, walled, bounds, Vector2(2.0, 2.0))
	assert_false(got[0].has_area(), "no room anywhere: left out")
	var edge: Array[Rect2] = [Rect2(380.0, 390.0, 60.0, 14.0)]
	got = FieldMapMarks.lay_out(edge, none, bounds, Vector2(2.0, 2.0))
	assert_true(bounds.encloses(got[0]), "slid inside")


func test_the_biggest_areas_win_room_first() -> void:
	var words := FieldMapMarks.areas_of(maps["street"].areas)
	for i in range(1, words.size()):
		assert_true(words[i - 1].total >= words[i].total)


# --- the drawing ---

func _floor(surface: RayHit.Surface, x: float, colour: Color = Color(0, 0, 0, 0)) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = &"floor"
	b.center = Vector3(x, -0.25, 0.0)
	b.size = Vector3(4.0, 0.5, 4.0)
	b.surface = surface
	b.colour = colour
	return b


func _pixel(f: MinimapField, x: float, z: float) -> Color:
	var p := f.pixel_of(x, z)
	return f.layers[0].get_pixel(int(p.x), int(p.y))


## Sloping ground's picture at the world's (x, z) (FM2: drawn under the layers, which leave it clear).
func _ground(f: MinimapField, x: float, z: float) -> Color:
	var share := (f.pixel_of(x, z) - f.ground_rect.position) / f.ground_rect.size
	var p := Vector2i(share * Vector2(f.ground.get_size()))
	return f.ground.get_pixelv(p)


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= TOLERANCE and absf(a.g - b.g) <= TOLERANCE and absf(a.b - b.b) <= TOLERANCE


func test_ground_is_tinted_by_what_it_is_and_greenery_is_green() -> void:
	var m := MapData.new()
	m.blocks.append(_floor(RayHit.Surface.CONCRETE, 0.0))
	m.blocks.append(_floor(RayHit.Surface.GRASS, 4.0))
	m.blocks.append(_floor(RayHit.Surface.CONCRETE, 8.0, Color("8aa860")))
	var hedge := MapData.Block.new()
	hedge.kind = &"hedge"
	hedge.center = Vector3(0.0, 1.0, 0.0)
	hedge.size = Vector3(1.0, 2.0, 1.0)
	m.blocks.append(hedge)
	var f := MinimapField.build(m, cfg)
	assert_true(_near(_pixel(f, -1.5, 1.5), cfg.ground_colour), "concrete keeps the plain ground")
	assert_true(_near(_pixel(f, 4.0, 1.5), cfg.ground_colour.lerp(cfg.grass_tint, cfg.ground_tint_share)), "grass")
	assert_true(_near(_pixel(f, 8.0, 1.5), cfg.ground_colour.lerp(Color("8aa860"), cfg.ground_tint_share)),
			"a floor's own colour wins")
	assert_true(_near(_pixel(f, 0.0, 0.0), cfg.green_tall_colour), "a tall hedge is green, not a wall's white")


func test_sloping_ground_facing_the_north_west_light_is_lighter() -> void:
	var lit := MapData.new()
	lit.terrain = TerrainGrid.create(-10.0, -10.0, 1.0, 20, 20, func(x: float, _z: float) -> float: return x * 0.3)
	var shade := MapData.new()
	shade.terrain = TerrainGrid.create(-10.0, -10.0, 1.0, 20, 20, func(x: float, _z: float) -> float: return -x * 0.3)
	var lit_field := MinimapField.build(lit, cfg)
	assert_eq(_pixel(lit_field, 0.0, 0.0).a, 0.0, "the layer leaves sloping ground clear for its picture")
	var a := _ground(lit_field, 0.0, 0.0)
	var b := _ground(MinimapField.build(shade, cfg), 0.0, 0.0)
	assert_gt(a.get_luminance(), b.get_luminance(), "facing the light, at the same share of the height")
	var high := _ground(lit_field, 8.0, 0.0)
	assert_gt(high.get_luminance(), a.get_luminance(), "higher ground lighter")


# --- the pointer and the frame ---

func test_the_pointer_keeps_to_a_panel_that_isnt_square() -> void:
	var p := MapPointer.new()
	p.frame_rect(Vector2.ZERO, 2.0, Vector2(300.0, 100.0), 0.0, Vector2.ZERO)
	p.start()
	p.move(Vector2(1000.0, 1000.0))
	assert_eq(p.at, Vector2(300.0, 100.0))
	assert_true(p.framed())


func test_a_frame_of_the_open_map_allocates_nothing_on_the_street() -> void:
	var fm := _field_map(maps["street"])
	_attack_defend(0)
	for i in 5:
		_show(fm)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 100:
		pointer.move(Vector2(1.0, 0.5))
		_show(fm)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)

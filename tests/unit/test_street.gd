extends GutTest
## The Street (ST1; tools/street/build_map.py from the owner's concept 3): its file loads with the House's three doors
## and a light under every street lamp, every colour it paints is the look's palette, the House's glass stops a BB
## while the open half of its front window lets one through, the glass is drawn see-through, and its railings and
## sills stand too high to vault or jump. A block's own colour (MapData.Block.colour) wins over its kind's, and one
## the file can't read is a problem.

const STREET := "street"

var play: PlayTuning = null
var tuning: SimTuning = null
var map: MapData = null


func before_all() -> void:
	play = PlayTuning.load_default()
	tuning = SimTuning.load_default()
	map = MapData.load_map(STREET, play.map_style, 5)


func after_all() -> void:
	map = null


func test_it_loads_with_the_houses_doors_and_a_light_under_every_lamp() -> void:
	assert_true(map.ok(), "The Street loads: %s" % [map.problems])
	assert_eq(map.warnings, [] as Array[String], "and warns of nothing")
	var shut: Array[bool] = []
	for d in map.doors:
		shut.append(d.shut)
	assert_eq(shut, [true, false, true] as Array[bool], "the back door shut, the hall door open, the front door shut")
	var lamps := 0
	for b in map.blocks:
		if b.kind == &"lamp":
			lamps += 1
	assert_eq(map.lights.size(), lamps, "a pool of light under every lamp")
	assert_lte(map.lights.size(), LightPools.MAX_POOLS, "and every one lit")
	assert_eq(map.lighting_presets, [LightingConfig.DAY, LightingConfig.NIGHT] as Array[StringName], "day or night")


func test_every_colour_it_paints_is_the_palettes() -> void:
	var look := play.look
	var off: PackedStringArray = []
	for b in map.blocks:
		if b.colour.a == 0.0:
			off.append("%s has no colour of its own" % FieldChecks.where(b))
			continue
		var named := false
		for n: StringName in look.palette:
			if look.palette[n].is_equal_approx(b.colour):
				named = true
				break
		if not named:
			off.append("%s is #%s" % [FieldChecks.where(b), b.colour.to_html(false)])
	assert_eq(off, PackedStringArray(), "every block of The Street is painted a palette colour")


func test_the_glass_stops_a_bb_and_the_open_half_of_the_front_window_does_not() -> void:
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, play.map_style, tuning.body)
	var hit := RayHit.new()
	# The front window, from the front garden into the kitchen at chest height: its open half (z -5.0 to -3.2) ...
	assert_false(level.query().ray(Vector3(-19.0, 1.5, -4.1), Vector3(-24.0, 1.5, -4.1), hit), "the open half")
	# ... and its glass half (z -3.2 to -1.4), which stops the BB in the wall's middle.
	assert_true(level.query().ray(Vector3(-19.0, 1.5, -2.3), Vector3(-24.0, 1.5, -2.3), hit), "the glass half")
	assert_almost_eq(hit.position.x, -21.97, 0.05, "on the glass")
	# The back window is all glass.
	assert_true(level.query().ray(Vector3(-34.0, 1.5, -3.0), Vector3(-29.0, 1.5, -3.0), hit), "the back window")
	var glass := level.get_node_or_null(^"Glass") as MeshInstance3D
	assert_not_null(glass, "the glass drawn as a mesh of its own")
	if glass != null:
		var mat := glass.material_override as ShaderMaterial
		assert_eq(mat.shader, LookMaterials.CLEAR_SHADER, "see-through, in the shared light")
		assert_eq(glass.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "casting no shadow")


func test_railings_and_window_sills_are_too_high_to_vault_or_jump() -> void:
	var vault := tuning.vault.max_height
	var move := tuning.movement
	var jump := move.jump_speed * move.jump_speed / (2.0 * move.gravity)
	var low: PackedStringArray = []
	for b in map.blocks:
		var top := b.center.y + b.size.y * 0.5
		if b.kind == &"railing" and (top <= vault or top <= jump):
			low.append(FieldChecks.where(b))
	assert_eq(low, PackedStringArray(), "every railing over a vault (%s m) and a jump (%s m)" % [vault, jump])
	# a window's sill: the wall block under each glass pane and the open half's
	var sill := 0
	for b in map.blocks:
		if b.kind == &"wall" and b.center.y < 1.0 and b.size.y < 1.5:
			sill += 1
			assert_gt(b.size.y, maxf(vault, jump), "the sill at %s" % FieldChecks.where(b))
	assert_eq(sill, 3, "the back window's sill and the front window's two")


func test_a_blocks_own_colour_wins_and_one_it_cant_read_is_a_problem() -> void:
	var style := play.map_style
	var text := '{"blocks": [{"kind": "crate", "center": {"x": 0, "y": 0.5, "z": 0}, "size": {"x": 1, "y": 1, "z": 1}, ' \
			+ '"colour": 7755946}, {"kind": "crate", "center": {"x": 3, "y": 0.5, "z": 0}, "size": {"x": 1, "y": 1, ' \
			+ '"z": 1}}, {"kind": "floor", "center": {"x": 0, "y": -0.5, "z": 0}, "size": {"x": 9, "y": 1, "z": 9}}]}'
	var m := MapData.parse(text, style, 1)
	assert_eq(style.block_colour(m.blocks[0]).to_html(false), "7658aa", "its own colour, the palette's violet")
	assert_eq(style.block_colour(m.blocks[1]), style.colour_of(&"crate", 0), "else its kind's")
	var bad := MapData.parse(text.replace("7755946", "\"violet\""), style, 1)
	assert_true(bad.problems.has("block 0's colour violet is not 0xRRGGBB"), "a colour not a number: %s" % [
			bad.problems])

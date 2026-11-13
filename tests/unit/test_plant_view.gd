extends GutTest
## Plant The Bomb as drawn and heard (PB1): the prop where the state has it and its lamp, each site's ring and letter,
## and the prop's sounds from SimAudio, the keys and the kit cut the tick the work stops.

const SITE_A := Vector3(20.0, 0.0, -10.0)
const SITE_B := Vector3(20.0, 0.0, 10.0)
const START := Vector3(-20.0, 0.0, 0.0)

var cfg := PlantViewConfig.new()
var teams := TeamConfig.new()
var ps: PlantState
var view: PlantView


func before_each() -> void:
	ps = PlantState.new()
	ps.set_sites(PackedVector3Array([SITE_A, SITE_B]), PackedFloat32Array([0.0, 6.0]), 4.5)
	ps.start = START
	ps.reset()
	view = PlantView.new()
	add_child_autofree(view)
	view.setup(cfg, teams, ps)


func test_each_site_has_its_ring_and_letter_where_the_state_has_it() -> void:
	assert_eq(view.letter(0).text, "A")
	assert_eq(view.letter(1).text, "B")
	assert_eq((view.letter(1).get_parent() as Node3D).position, SITE_B)
	assert_almost_eq(view.letter(0).position.y, cfg.letter_rise, 0.001)
	assert_almost_eq(view.ring_colour(0).a, cfg.ring_alpha, 0.001)


func test_a_low_ceiling_keeps_the_letters_under_it() -> void:
	var low := PlantView.new()
	add_child_autofree(low)
	low.setup(cfg, teams, ps, 1.9)
	assert_almost_eq(low.letter(0).position.y, 1.9, 0.001)


func test_the_prop_lies_at_the_start_and_winks_while_it_waits() -> void:
	view.refresh(ps, 0, null, 1.0, false, 0.01)
	assert_eq(view.prop().position, START)
	assert_true(view.prop().visible)
	assert_eq(view.lamp_colour(), cfg.lamp_waiting, "on at the start of its period")
	view.refresh(ps, 0, null, 1.0, false, cfg.lamp_wait_on + 0.05)
	assert_eq(view.lamp_colour(), cfg.lamp_off, "then off for the rest of it")


func test_carried_it_hangs_at_the_carriers_hip_and_is_hidden_on_the_one_you_watch() -> void:
	var carrier := Character.new(3, 0, Vector3(4.0, 0.0, 2.0), 0.0, [ReplicaConfig.new()] as Array[ReplicaConfig])
	carrier.prev_position = carrier.position
	ps.status = PlantState.Status.CARRIED
	ps.carrier = carrier.id
	view.refresh(ps, 0, carrier, 1.0, false, 0.01)
	assert_true(view.prop().visible)
	assert_almost_eq(view.prop().position.y, cfg.carry_at.y, 0.001)
	assert_almost_eq(Vector2(view.prop().position.x - 4.0, view.prop().position.z - 2.0).length(),
			Vector2(cfg.carry_at.x, cfg.carry_at.z).length(), 0.001)
	assert_eq(view.lamp_colour(), cfg.lamp_off)
	view.refresh(ps, 0, carrier, 1.0, true, 0.01)
	assert_false(view.prop().visible, "through the carrier's own eyes it is not drawn")
	ps.planter = carrier.id
	ps.planting = 0.3
	ps.facing = 0.4
	ps.set_at = carrier.position + Vector3(0.0, 0.0, -0.5)
	view.refresh(ps, 0, carrier, 1.0, true, 0.01)
	assert_true(view.prop().visible, "set down to be keyed in, it shows in the carrier's own view too")
	assert_eq(view.prop().position, ps.set_at, "on the ground in front of them, where it will stand armed (PB3)")
	assert_almost_eq(view.prop().rotation.y, 0.4, 1e-6, "its front to them")
	ps.planter = -1
	ps.planting = 0.0
	ps.status = PlantState.Status.DOWN
	ps.position = Vector3(5.0, 0.0, 5.0)
	view.refresh(ps, 0, null, 1.0, true, 0.01)
	assert_true(view.prop().visible, "dropped, it shows again where it fell")
	assert_eq(view.prop().position, ps.position)


func test_the_ring_takes_the_attackers_colour_while_keyed_and_armed_and_the_defenders_while_made_safe() -> void:
	ps.status = PlantState.Status.CARRIED
	ps.site = 1
	ps.planter = 2
	view.refresh(ps, 1, null, 1.0, false, 0.01)
	assert_eq(view.ring_colour(1), Color(teams.colours[1], cfg.ring_alpha))
	assert_eq(view.ring_colour(0), Color(cfg.ring_idle, cfg.ring_alpha), "the other site stays idle")
	ps.status = PlantState.Status.PLANTED
	ps.planter = -1
	view.refresh(ps, 1, null, 1.0, false, 0.01)
	assert_eq(view.ring_colour(1), Color(teams.colours[1], cfg.ring_alpha))
	ps.defuser = 7
	view.refresh(ps, 1, null, 1.0, false, 0.01)
	assert_eq(view.ring_colour(1), Color(teams.colours[0], cfg.ring_alpha))


func test_armed_the_lamp_flashes_on_each_beep_and_ends_green_or_red() -> void:
	ps.status = PlantState.Status.PLANTED
	ps.site = 0
	ps.position = SITE_A
	view.refresh(ps, 0, null, 1.0, false, 0.01)
	assert_eq(view.lamp_colour(), cfg.lamp_off)
	view.on_cue(Plant.Cue.BEEP, SITE_A, null)
	view.refresh(ps, 0, null, 1.0, false, 0.01)
	assert_eq(view.lamp_colour(), cfg.lamp_armed)
	view.refresh(ps, 0, null, 1.0, false, cfg.lamp_flash + 0.01)
	assert_eq(view.lamp_colour(), cfg.lamp_off)
	ps.status = PlantState.Status.DEFUSED
	view.refresh(ps, 0, null, 1.0, false, 0.01)
	assert_eq(view.lamp_colour(), cfg.lamp_safe)
	ps.status = PlantState.Status.GONE_OFF
	view.refresh(ps, 0, null, 1.0, false, 0.01)
	assert_eq(view.lamp_colour(), cfg.lamp_armed)


func test_going_off_it_pops_dust_and_hurts_nobody() -> void:
	var puffs := PuffView.new()
	add_child_autofree(puffs)
	puffs.setup(EffectsConfig.new())
	view.on_cue(Plant.Cue.WENT_OFF, SITE_A, puffs)
	assert_eq(puffs._next, cfg.pop_puffs, "its puffs were thrown")
	for i in cfg.pop_puffs:
		assert_lt(Vector2(puffs._at[i].x - SITE_A.x, puffs._at[i].z - SITE_A.z).length(), cfg.pop_radius + 0.001)
		assert_between(puffs._at[i].y, 0.0, cfg.pop_height)


func test_every_cue_with_a_sound_has_its_file_and_the_work_cues_are_as_long_as_the_work() -> void:
	assert_eq(SimAudio.PLANT_CUES.size(), Plant.Cue.size())
	var plant := PlantConfig.new()
	for i in SimAudio.PLANT_CUES.size():
		var cue := SimAudio.PLANT_CUES[i]
		var silent := i == Plant.Cue.ARMING_STOPPED or i == Plant.Cue.DEFUSING_STOPPED
		assert_eq(cue == &"", silent, "cue %d" % i)
		if cue == &"":
			continue
		var path := "%s%s_1.wav" % [SoundConfig.CUE_DIR, cue]
		assert_true(ResourceLoader.exists(path), path)
	var keys: AudioStream = load("%splant_arming_1.wav" % SoundConfig.CUE_DIR)
	var kit: AudioStream = load("%splant_defusing_1.wav" % SoundConfig.CUE_DIR)
	var beep: AudioStream = load("%splant_beep_1.wav" % SoundConfig.CUE_DIR)
	assert_almost_eq(keys.get_length(), plant.plant_time, 0.05)
	assert_almost_eq(kit.get_length(), plant.defuse_time, 0.05)
	assert_lt(beep.get_length(), plant.beep_fast, "a beep ends before the next at the fuse's fastest")


func test_the_keys_carry_as_far_as_a_defender_bot_hears_them() -> void:
	assert_eq(SoundConfig.new().plant_work_reach, BotConfig.new().plant_heard)


func test_the_keys_play_from_the_bomb_and_are_cut_when_the_hands_come_off() -> void:
	var body := BodyConfig.new()
	var state := GameState.new(1)
	var you := Character.new(0, 1, Vector3(18.0, 0.0, -10.0), 0.0, [ReplicaConfig.new()] as Array[ReplicaConfig])
	state.characters.append(you)
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [&"electric"] as Array[StringName], body, BoxWorld.new(body), null)
	var keys: Array = audio._streams[&"plant_arming"]
	_cue(state, Plant.Cue.ARMING)
	audio.on_tick(state, you.id, you)
	assert_eq(_playing(audio, keys), 1, "heard from 2 m")
	state.events.clear()
	_cue(state, Plant.Cue.BEEP)
	audio.on_tick(state, you.id, you)
	assert_eq(_playing(audio, keys), 1, "a beep leaves the keys playing")
	state.events.clear()
	_cue(state, Plant.Cue.ARMING_STOPPED)
	audio.on_tick(state, you.id, you)
	assert_eq(_playing(audio, keys), 0)
	# Out of earshot, nothing plays.
	you.position = SITE_A + Vector3(SoundConfig.new().plant_work_reach + 5.0, 0.0, 0.0)
	state.events.clear()
	_cue(state, Plant.Cue.ARMING)
	audio.on_tick(state, you.id, you)
	assert_eq(_playing(audio, keys), 0)


func test_a_round_ending_cuts_the_kit() -> void:
	var body := BodyConfig.new()
	var state := GameState.new(1)
	var you := Character.new(0, 1, SITE_A, 0.0, [ReplicaConfig.new()] as Array[ReplicaConfig])
	state.characters.append(you)
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [&"electric"] as Array[StringName], body, BoxWorld.new(body), null)
	var kit: Array = audio._streams[&"plant_defusing"]
	_cue(state, Plant.Cue.DEFUSING)
	audio.on_tick(state, you.id, you)
	assert_eq(_playing(audio, kit), 1)
	state.events.clear()
	state.events.add(GameEvent.Kind.ROUND_OVER)
	audio.on_tick(state, you.id, you)
	assert_eq(_playing(audio, kit), 0)


func _cue(state: GameState, cue: Plant.Cue) -> void:
	var e := state.events.add(GameEvent.Kind.PLANT)
	e.actor = 5
	e.position = SITE_A
	e.value = cue


func _playing(audio: SimAudio, streams: Array) -> int:
	var n := 0
	for v in audio._field:
		if v.playing and streams.has(v.stream):
			n += 1
	return n

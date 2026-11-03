extends GutTest
## QA hunt for AU2: the slide lock through the real armament (last BB only, once, not on a dry click, a reload or a
## magazine swap, not for the Cyber Pistol or a spring) and every surface a map file can name.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)

var body := BodyConfig.new()
var state: GameState
var you: Character
var shooter: Character
var audio: SimAudio
var pool_bb := BBPool.new(8)
var tuning := SimTuning.new()


func _setup(power: StringName, sound: StringName, mag: int, spares: int) -> void:
	state = GameState.new(1)
	you = Character.new(0, 0, Vector3.ZERO, 0.0, [ReplicaConfig.new()] as Array[ReplicaConfig])
	state.characters.append(you)
	var r := ReplicaConfig.new()
	r.power = power
	r.sound = sound
	r.fire_modes = [ReplicaConfig.FireMode.SEMI] as Array[ReplicaConfig.FireMode]
	shooter = Character.new(1, 1, Vector3(0.0, 0.0, -6.0), 0.0, [r] as Array[ReplicaConfig])
	shooter.armament.ammo[0].mag = mag
	for i in shooter.armament.ammo[0].pouch.size():
		shooter.armament.ammo[0].pouch[i] = spares if i == 0 else 0
	state.characters.append(shooter)
	audio = SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [&"gas", &"electric", &"cyber", &"spring"] as Array[StringName], body,
			BoxWorld.new(body), null)


## Holds the trigger as taps (fire on every other tick) for `ticks`, returning the slide locks heard.
func _run(ticks: int, tap := true) -> int:
	var locks := 0
	var cmd := PlayerCommand.new()
	for t in ticks:
		cmd.fire = (t % 2 == 0) if tap else true
		state.events.clear()
		state.time += DT
		Armament.step(shooter, cmd, EYE, 1.0, true, pool_bb, Seeds.stream(3), state.events, tuning, DT)
		audio.on_tick(state, you.id, you)
		for v in audio._field:
			if v.playing and (audio._streams.get(&"slideLock_gas", []) as Array).has(v.stream):
				locks += 1
				v.stop()
	return locks


func test_a_gas_pistol_emptied_through_the_armament_locks_once_on_its_last_bb_only() -> void:
	_setup(&"gas", &"", 3, 0)
	var locks := _run(240)
	assert_eq(shooter.armament.ammo[0].mag, 0)
	assert_eq(locks, 1, "three shots, one lock, then dry clicks do not lock again")


func test_a_reload_after_the_last_shot_does_not_lock_again() -> void:
	_setup(&"gas", &"", 1, 2)
	var locks := _run(400)
	assert_eq(locks, 1, "the one shot locks; the auto reload's magazine seating does not")


func test_the_cyber_pistol_and_a_spring_never_lock() -> void:
	for pair: Array in [[&"battery", &"cyber"], [&"spring", &""], [&"battery", &"electric"]]:
		_setup(pair[0], pair[1], 2, 0)
		assert_eq(_run(240), 0, "%s" % [pair])


func test_a_dry_click_on_an_empty_gas_pistol_does_not_lock() -> void:
	_setup(&"gas", &"", 0, 0)
	assert_eq(_run(120), 0)


func test_every_surface_a_map_file_can_name_has_a_cue_a_puff_and_a_step() -> void:
	var puffs := PlayTuning.load_default().effects.puff_colours
	for key: String in MapData.SURFACES:
		var s: int = MapData.SURFACES[key]
		assert_lt(s, puffs.size(), key)
		assert_lt(s, SimAudio.SURFACE_NAMES.size(), key)
		assert_lt(s, SimAudio.IMPACT_NAMES.size(), key)
		assert_gte(RicochetConfig.new().restitution(s as RayHit.Surface), 0.0, key)
	assert_eq(MapData.SURFACES.size(), RayHit.Surface.size() - 1, "every surface but NONE is nameable")

extends GutTest
## BP1 QA: the magazine hand-off's walk-up never parks a bot where it can't toss (game/ai/bot_mag_share.gd,
## game/sim/mag_share.gd), and the first entry of a cmdline file reads cleanly (game/core/process_check.gd).

const DT := 1.0 / 60.0
const YOU := 0
## A slab across z in SLAB_NEAR..SLAB_FAR (m) up to a height (the hand-off's level between two characters).
const SLAB_NEAR := -0.6
const SLAB_FAR := -0.4
## A beam or window frame's thickness (m).
const BAND := 0.15
const CMDLINE := "user://bp1_qa_cmdline"

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()


## A level of one slab across z = -0.5, from `bottom` up to `height` m (a wall, waist cover, a beam or window frame).
class Slab:
	extends WorldQuery
	var height: float = 1.0
	var bottom: float = 0.0

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		if maxf(from.z, to.z) < SLAB_NEAR or minf(from.z, to.z) > SLAB_FAR:
			return false
		var dz := to.z - from.z
		var t0 := 0.0
		var t1 := 1.0
		if absf(dz) > 1e-9:
			t0 = clampf((SLAB_NEAR - from.z) / dz, 0.0, 1.0)
			t1 = clampf((SLAB_FAR - from.z) / dz, 0.0, 1.0)
		var y0 := lerpf(from.y, to.y, t0)
		var y1 := lerpf(from.y, to.y, t1)
		if minf(y0, y1) > height or maxf(y0, y1) < bottom:
			return false
		hit.fraction = minf(t0, t1)
		return true


## Bot (id 1, team 0) and character 0 (you) `apart` m apart in z, the slab between them (id 1 at z = 0).
func _world(slab: Slab, apart: float) -> BotWorld:
	var loadout := ReplicaStats.default_loadout()
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = config
	w.query = slab
	w.mag_share = MagShare.new(tuning, slab)
	for i in 2:
		var c := Character.new(i, 0, Vector3.ZERO, 0.0 if i == 1 else PI, loadout)
		c.respawn()
		c.position = Vector3(0.0, 0.0, 0.0 if i == 1 else -apart)
		w.characters.append(c)
	w.bots = [Bot.new(w.characters[1], 1, config.skill, 2)] as Array[Bot]
	return w


static func _empty(c: Character) -> void:
	c.armament.ammo[0].pouch.fill(0)


func _cases() -> Array[Vector4]:
	# slab height, giver crouch, receiver crouch, lean of the giver
	var cases: Array[Vector4] = []
	for h: float in [0.3, 0.7, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7]:
		for gc: float in [0.0, 1.0]:
			for rc: float in [0.0, 1.0]:
				for lean: float in [-1.0, 0.0, 1.0]:
					cases.append(Vector4(h, gc, rc, lean))
	return cases


func test_a_bot_bringing_one_either_walks_or_tosses_behind_any_cover_and_stances() -> void:
	assert_eq(_parked_givers(false), [] as Array[Vector4], "stood still without tossing behind cover from the floor up")


func test_a_bot_bringing_one_either_walks_or_tosses_behind_any_beam_and_stances() -> void:
	assert_eq(_parked_givers(true), [] as Array[Vector4], "stood still without tossing behind a beam (apart, height, crouches)")


func _parked_givers(banded: bool) -> Array[Vector4]:
	var parked: Array[Vector4] = []
	for apart: float in [0.8, 3.0, 5.9, 6.1]:
		for k in _cases():
			var slab := Slab.new()
			slab.height = k.x
			slab.bottom = maxf(k.x - BAND, 0.0) if banded else 0.0
			var w := _world(slab, apart)
			var giver := w.characters[1]
			var asker := w.characters[YOU]
			giver.crouch_amount = k.y
			asker.crouch_amount = k.z
			giver.lean = k.w
			_empty(asker)
			asker.mag.asked = giver.id
			var b := w.bots[0]
			b.mag_for = asker
			var cmd := PlayerCommand.new()
			var walking := BotMagShare.move(b, w, cmd, DT) or b.route_state == Bot.RouteState.WANTED
			if not walking and not cmd.mag_hand_off:
				parked.append(Vector4(apart, k.x, k.y, k.z))
	return parked


func test_a_bot_waiting_on_your_toss_walks_up_unless_you_can_toss_it_behind_any_cover() -> void:
	assert_eq(_parked_askers(false), [] as Array[Vector4], "waited where you can't toss, cover from the floor up")


func test_a_bot_waiting_on_your_toss_walks_up_unless_you_can_toss_it_behind_any_beam() -> void:
	assert_eq(_parked_askers(true), [] as Array[Vector4], "waited where you can't toss, behind a beam")


func _parked_askers(banded: bool) -> Array[Vector4]:
	var parked: Array[Vector4] = []
	var pick := MagShare.SparePick.new()
	for apart: float in [0.8, 3.0, 5.9]:
		for k in _cases():
			var slab := Slab.new()
			slab.height = k.x
			slab.bottom = maxf(k.x - BAND, 0.0) if banded else 0.0
			var w := _world(slab, apart)
			var bot := w.characters[1]
			var you := w.characters[YOU]
			you.crouch_amount = k.y
			bot.crouch_amount = k.z
			you.lean = k.w
			_empty(bot)
			bot.mag.asked = you.id
			var walking := BotMagShare.move(w.bots[0], w, PlayerCommand.new(), DT)
			if not walking and w.bots[0].route_state != Bot.RouteState.WANTED \
					and not w.mag_share.can_toss_to(you, bot, pick):
				parked.append(Vector4(apart, k.x, k.y, k.z))
	return parked


func test_a_crouched_catcher_behind_low_cover_blocks_the_toss_and_a_standing_one_doesnt() -> void:
	var slab := Slab.new()
	slab.height = 1.4
	var w := _world(slab, 2.0)
	var giver := w.characters[1]
	var asker := w.characters[YOU]
	_empty(asker)
	var pick := MagShare.SparePick.new()
	assert_true(w.mag_share.can_toss_to(giver, asker, pick), "standing, the chest is over the cover")
	asker.crouch_amount = 1.0
	assert_false(w.mag_share.can_toss_to(giver, asker, pick), "crouched, it is under the line's reach")
	assert_false(w.mag_share.toss_line_clear(giver, asker))
	giver.position = Vector3(0.0, 0.0, -0.3)
	# BP7: the check is the arc from the hand (0.3 m under the eyes), the path the toss flies, not a line from the eyes.
	assert_false(w.mag_share.toss_line_clear(giver, asker), "right up to 1.4 m cover the hand is under its top")
	slab.height = 1.2
	assert_true(w.mag_share.toss_line_clear(giver, asker), "right up to cover under the hand, the arc passes over it")


func test_a_blocked_line_that_clears_as_the_catcher_moves_tosses_the_next_tick() -> void:
	var slab := Slab.new()
	slab.height = 1.7
	var w := _world(slab, 3.0)
	var giver := w.characters[1]
	var asker := w.characters[YOU]
	_empty(asker)
	asker.mag.asked = giver.id
	var b := w.bots[0]
	b.mag_for = asker
	var cmd := PlayerCommand.new()
	BotMagShare.move(b, w, cmd, DT)
	assert_eq(b.route_state, Bot.RouteState.WANTED, "walks while the cover is full height")
	assert_false(cmd.mag_hand_off)
	slab.height = 0.2
	BotMagShare.move(b, w, cmd, DT)
	assert_true(cmd.mag_hand_off, "once the line is clear it presses without walking further")


func test_a_job_ends_when_the_catcher_is_out_mid_walk() -> void:
	var slab := Slab.new()
	slab.height = 1.7
	var w := _world(slab, 3.0)
	var asker := w.characters[YOU]
	_empty(asker)
	asker.mag.asked = w.characters[1].id
	var b := w.bots[0]
	b.mag_for = asker
	BotMagShare.move(b, w, PlayerCommand.new(), DT)
	asker.status = Character.Status.OUT
	BotMagShare.update(w, true)
	assert_null(b.mag_for, "the bot lets the job go")


func _write(bytes: PackedByteArray) -> void:
	var f := FileAccess.open(CMDLINE, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func test_the_first_argument_reads_clean_of_an_empty_a_nul_only_and_a_very_long_cmdline() -> void:
	_write(PackedByteArray())
	assert_eq(ProcessCheck._first_arg(CMDLINE), "", "an empty file")
	var zeros := PackedByteArray()
	zeros.resize(64)
	_write(zeros)
	assert_eq(ProcessCheck._first_arg(CMDLINE), "", "nothing but NULs")
	var long_arg := PackedByteArray()
	long_arg.resize(10000)
	long_arg.fill(0x61)
	_write(long_arg)
	assert_eq(ProcessCheck._first_arg(CMDLINE).length(), 4096, "an argument past the buffer is cut at it")
	var long_then_nul := PackedByteArray()
	long_then_nul.resize(5000)
	long_then_nul.fill(0x61)
	long_then_nul[100] = 0
	_write(long_then_nul)
	assert_eq(ProcessCheck._first_arg(CMDLINE).length(), 100)
	assert_eq(ProcessCheck._first_arg("user://bp1_qa_no_such_file"), "", "a missing file (no /proc, as on Windows)")
	DirAccess.remove_absolute(CMDLINE)


func test_the_first_argument_keeps_a_multibyte_name_before_the_nul() -> void:
	_write("Airsoft é".to_utf8_buffer() + PackedByteArray([0]) + "x".to_utf8_buffer())
	assert_eq(ProcessCheck._first_arg(CMDLINE), "Airsoft é")
	DirAccess.remove_absolute(CMDLINE)

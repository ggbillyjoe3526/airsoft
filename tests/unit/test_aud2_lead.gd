extends GutTest
## The second audit's fixes that fall between its groups (AUD2): Subway's steel lockers sound as Depot's do, and the
## bugs its own hunt found in the pass's changes.

## The longest a staged load is waited for (ms): its nav grid is built on a worker thread.
const LOAD_WAIT_MSEC := 90000

var tuning: SimTuning = SimTuning.new()


# --- Noticed with KNOWN_ISSUES 27: Subway's lockers are cabinets, which knock as hollow plastic ---


func test_subways_steel_lockers_clank_as_depots_do() -> void:
	var map := MapData.load_map("subway", MapStyle.new(), tuning.rounds.team_size)
	var lockers := 0
	var clanking := 0
	for b in map.blocks:
		if b.dress == &"locker":
			lockers += 1
			assert_eq(b.noise, &"clank", "a steel locker names the steel props' sound")
		if b.noise != &"":
			clanking += 1
	assert_eq(lockers, 9, "the five banks of lockers, in the boxes the generator cuts them to")
	assert_eq(clanking, lockers, "nothing else on Subway names a sound of its own")
	var level := MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body)
	var q := level.query()
	var props := PropNoise.new(tuning.noise, q)
	var heard := 0
	for i in props.count():
		if q.block_noises[props.block[i]] == &"":
			continue
		heard += 1
		assert_eq(q.block_kinds[props.block[i]], &"cabinet", "still a cabinet to the rest of the game")
		assert_eq(props.sound[i], NoiseConfig.Sound.CLANK)
		assert_eq(props.knock_reach[i], tuning.noise.knock_reach_of(NoiseConfig.Sound.CLANK))
	assert_eq(heard, lockers, "every one is a noisy prop")
	level.free()


# --- The bug hunt over the second audit's own changes ---


## A giver busy bringing one passes on only the asks someone else can take: before, its TURN_DOWN ended every other
## ask standing with it, so an asker with nobody else in reach was refused NOBODY because a second asker could go
## elsewhere, where the rule is that such an ask waits its turn.
func test_a_busy_giver_passes_on_only_the_asks_someone_else_can_take() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	var s := GameState.new(1, tuning)
	# 0 alone far west (only the giver in reach), 1 the giver, 2 a second asker with 3 free beyond it, 4 the one
	# the giver is bringing a magazine.
	var at: Array[Vector3] = [Vector3(-28.0, 0.0, 0.0), Vector3.ZERO, Vector3(10.0, 0.0, 0.0),
			Vector3(22.0, 0.0, 0.0), Vector3(4.0, 0.0, 6.0)]
	for i in at.size():
		s.characters.append(Character.new(i, 0, at[i], 0.0, ReplicaStats.default_loadout()))
	var share := MagShare.new(tuning, w)
	var alone := s.characters[0]
	var giver := s.characters[1]
	var second := s.characters[2]
	var served := s.characters[4]
	for c: Character in [served, alone, second]:
		c.armament.ammo[0].pouch.fill(0)
		share.press(c, s, true)
		assert_eq(c.mag.asked, giver.id, "each asks the giver, the nearest with one to spare")
		if c == served:
			share.answer(giver, PlayerCommand.MagAnswer.TAKE, served.id, s, true)
	s.events.clear()
	share.answer(giver, PlayerCommand.MagAnswer.PASS_ON, served.id, s, true)
	assert_eq(second.mag.asked, 3, "the ask a free teammate can take goes to them")
	assert_eq(alone.mag.asked, giver.id, "the ask nobody else can take waits its turn with the giver")
	assert_null(s.events.first(GameEvent.Kind.MAG_REFUSED), "and nobody is refused")
	assert_eq(alone.mag.next_ask, -INF, "nor made to wait an ask's gap")
	assert_true(served.mag.taken, "the one being brought is kept")
	share.answer(giver, PlayerCommand.MagAnswer.PASS_ON, served.id, s, true)
	assert_eq(alone.mag.asked, giver.id, "said again, it still waits")
	# Off to the pole the giver takes none: there the same ask ends at once, as it did.
	share.answer(giver, PlayerCommand.MagAnswer.TURN_DOWN, served.id, s, true)
	assert_eq(alone.mag.asked, -1, "turned down outright, with nobody else, it ends")
	assert_eq(s.events.first(GameEvent.Kind.MAG_REFUSED).value, MagShare.Refusal.NOBODY)


## The wood is built a piece a frame and joins the tree with its last piece: a session freed on a frame between
## (Back on the loading screen) used to leave it, and its meshes, behind.
func test_a_load_left_while_the_wood_is_built_frees_the_wood() -> void:
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = "woodland"
	session.match_seed = 7
	session.autopilot = true
	session.staged = true
	add_child(session)
	# By the clock, not a frame count: the nav grid is built on a worker thread, and headless frames pass far faster.
	var until := Time.get_ticks_msec() + LOAD_WAIT_MSEC
	while Time.get_ticks_msec() < until and (session._woods == null or session._woods.is_inside_tree()) \
			and session._bots == null:
		await wait_process_frames(1)
	var woods := session._woods
	assert_not_null(woods, "the wood's first piece is built")
	assert_false(woods.is_inside_tree(), "and it is not in the tree yet: the load is between its pieces")
	session.free()
	assert_false(is_instance_valid(woods), "freed with the session")


## The crash screen's write failing after the start's own write worked: the record on disk is this run's, so no clean
## quit's mark is left for it (the mark would make a crash of this run read as a clean quit at the next start).
func test_a_seen_crash_that_cannot_be_written_never_marks_the_run_under_way() -> void:
	var dir := "user://test-aud2-lead-run"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("run.save")
	var gone := 999999
	var first := RunRecord.new()
	first.start("0.1 Dev 3", 1000, gone)
	assert_true(first.save(path))
	var run := RunRecord.load_file(path)
	run.start("0.1 Dev 3", 2000, gone - 1)
	assert_true(run.crashed_before(), "the run before it never closed")
	assert_true(run.save(path), "this start wrote its record")
	SaveFile.hold(PackedStringArray([path]))
	assert_false(run.crash_seen(path), "not written, and nothing marked: false, for main to warn of it")
	SaveFile.release(PackedStringArray([path]))
	assert_false(FileAccess.file_exists(RunRecord.closed_mark(path, run.pid, run.started)), "no mark for this run")
	# This run now ends without closing (a crash): the next start must see it.
	var next := RunRecord.load_file(path)
	next.start("0.1 Dev 3", 3000, OS.get_process_id())
	assert_true(next.crashed_before(), "a crash of this run is still shown")
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)

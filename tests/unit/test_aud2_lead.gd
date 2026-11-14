extends GutTest
## The second audit's fixes that fall between its groups (AUD2): Subway's steel lockers sound as Depot's do.

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

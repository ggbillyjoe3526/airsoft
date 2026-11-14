extends GutTest
## The second audit pass on the bots (AUD2): a bot leads by the replica it holds, kits kept to a kind of field (the
## Clearer indoors), bushes priced on the nav grid, the string-pulling's routes unchanged, and the bots' lift rides,
## magazine asks and squeezes past Subway's wagons.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.load_default()


# --- A bot leads by the replica it holds (KNOWN_ISSUES: bots lead by the default loadout's first replica) ---


## A bot holding `replicas` (the first in its hands), alone in a world of `tuning`.
func _holding(replicas: Array[ReplicaConfig]) -> Array:
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, replicas)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = BotConfig.load_default()
	w.characters = [me]
	return [Bot.new(me, 1, w.cfg.skill_for(&"normal"), 1), w]


func test_a_bot_leads_by_the_bbs_of_the_replica_in_its_hands() -> void:
	var aeg := ReplicaStats.load_replica(&"aeg")
	var shotgun := ReplicaStats.load_replica(&"shotgun")
	var with_aeg := _holding([aeg] as Array[ReplicaConfig])
	var with_shotgun := _holding([shotgun, aeg] as Array[ReplicaConfig])
	var by_aeg := BotCombat.flight_time(with_aeg[0], with_aeg[1], 30.0)
	var by_shotgun := BotCombat.flight_time(with_shotgun[0], with_shotgun[1], 30.0)
	var grams := shotgun.bb_weight
	assert_almost_eq(by_shotgun, Ballistics.flight_time_estimate(30.0, Ballistics.muzzle_velocity(shotgun,
			tuning.replica_rules, grams), Ballistics.bb_mass(shotgun, grams), tuning.ballistics), 1e-6,
			"the shotgun's own BBs")
	assert_gt(by_shotgun, by_aeg * 1.05, "slower BBs: a longer lead than the AEG's")
	var b: Bot = with_shotgun[0]
	b.character.armament.active = 1
	assert_almost_eq(BotCombat.flight_time(b, with_shotgun[1], 30.0), by_aeg, 1e-6, "the AEG once it is in hand")

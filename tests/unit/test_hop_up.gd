extends GutTest
## The hop-up dial's readout (Ballistics.hop_up_reach; the browser game's sim/hopUp.test.ts), and SC1's acceptance
## criterion 2: the factory dials keep the AEG Rifle on target to about 38 m and the GBB Pistol to about 26 m.
## The slider's weights and best-dial search belong to the Loadout screen and come with it.

const DT := 1.0 / 60.0
## The browser game's HOP_UP readout: on target while within 0.15 m of the aim line (about half a torso), followed to
## 60 m.
const BAND := 0.15
const RANGE := 60.0
const Replicas := preload("res://tests/unit/replica_fixtures.gd")

var tuning: SimTuning = SimTuning.new()


func reach(r: ReplicaConfig, dial: float) -> Ballistics.HopUpReach:
	return Ballistics.hop_up_reach(r, dial, tuning, DT, BAND, RANGE)


func test_factory_dials_keep_the_rifle_on_target_to_about_38_m_and_the_pistol_to_about_26_m() -> void:
	var rifle := reach(Replicas.aeg(), 0.65)
	var sidearm := reach(Replicas.pistol(), 0.55)
	# The browser game reads about 39 m and 27 m with these stats (its config/replicas.ts notes the rifle's 39 m).
	assert_between(rifle.on_target_to, 37.0, 40.0, "AEG Rifle")
	assert_between(sidearm.on_target_to, 25.0, 28.0, "GBB Pistol")


func test_out_of_the_box_the_rifle_reaches_34_m_with_a_gentle_rise() -> void:
	var r := Replicas.aeg()
	var rifle := reach(r, r.hop_up_dial)
	assert_gte(rifle.on_target_to, 34.0)
	assert_between(rifle.peak_rise, 0.03, BAND)


func test_out_of_the_box_the_pistol_is_a_sidearm() -> void:
	var p := Replicas.pistol()
	var r := Replicas.aeg()
	var sidearm := reach(p, p.hop_up_dial)
	assert_between(sidearm.on_target_to, 20.0, 30.0)
	assert_lt(sidearm.on_target_to, reach(r, r.hop_up_dial).on_target_to - 5.0)


func test_more_hop_carries_further_until_over_hopped() -> void:
	for r: ReplicaConfig in [Replicas.aeg(), Replicas.pistol()]:
		var none := reach(r, 0.0)
		var factory := reach(r, r.hop_up_dial)
		var full := reach(r, tuning.replica_rules.hop_up_max_dial)
		assert_gt(factory.on_target_to, none.on_target_to + 8.0, r.id)
		assert_lt(none.peak_rise, 0.01, "%s: no backspin, it only falls" % r.id)
		assert_gt(full.peak_rise, 0.4, "%s: turned right up, well over the aim" % r.id)
		assert_lt(full.on_target_to, factory.on_target_to, r.id)


func test_the_dial_turns_into_lift_within_its_range() -> void:
	var r := Replicas.aeg()
	var rules := tuning.replica_rules
	assert_almost_eq(Ballistics.hop_up_lift(r, 0.5, rules), r.hop_up_max / 2.0, 1e-12)
	assert_eq(Ballistics.hop_up_lift(r, 2.0, rules), r.hop_up_max)
	assert_eq(Ballistics.hop_up_lift(r, -1.0, rules), 0.0)


func test_a_lighter_bb_gets_to_10_and_20_m_sooner() -> void:
	for r: ReplicaConfig in [Replicas.aeg(), Replicas.pistol()]:
		var light := Ballistics.flight_time(r, r.hop_up_dial, 10.0, tuning, DT, 0.2)
		var heavy := Ballistics.flight_time(r, r.hop_up_dial, 10.0, tuning, DT, 0.28)
		assert_lt(light, heavy, r.id)
		assert_lt(Ballistics.flight_time(r, r.hop_up_dial, 20.0, tuning, DT, 0.2),
				Ballistics.flight_time(r, r.hop_up_dial, 20.0, tuning, DT, 0.28), r.id)


## BP7 row 33: How to Play's flat ranges are the simulation's, from the replicas as data/stats.md sets them out of the
## box (a drift check on numbers the page types, as a sentence reads).
func test_the_wikis_flat_ranges_are_the_simulations() -> void:
	var page := FileAccess.get_file_as_string("res://docs/wiki/How-to-Play.md")
	var said := RegEx.create_from_string(
			"The AEG Rifle stays on target to about \\*\\*(\\d+) m\\*\\*, the GBB Pistol to about \\*\\*(\\d+) m\\*\\*")
	var m := said.search(page)
	assert_not_null(m, "How to Play still says how far each stays on target")
	if m == null:
		return
	var loadout := ReplicaStats.default_loadout()
	assert_eq(loadout.size(), 2, "the AEG Rifle and the GBB Pistol")
	for k in loadout.size():
		var r := loadout[k]
		var flat := reach(r, r.hop_up_dial).on_target_to
		assert_almost_eq(float(m.get_string(k + 1)), flat, 1.0, "%s: the wiki's %s m, the simulation's %.1f m" % [r.id,
				m.get_string(k + 1), flat])

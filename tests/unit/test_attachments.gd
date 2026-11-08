extends GutTest
## Parts on a replica (AT1): data/pool.md's parts and what fits what, data/stats.md's part tables, a part saved with the
## loadout and checked, what each part makes of a replica as carried, and what it changes in play (the raise of the
## sight, the shake, a rattling magazine's footsteps, how far a silenced shot is heard). Ported from the browser game's
## config/attachments.test.ts and pool/kit.test.ts.

const DT := 1.0 / 60.0
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const LIPO := "000015"
const RED_DOT := "000007"
const SCOPE := "000010"
const VARIABLE_SCOPE := "000025"
const VERTICAL := "000006"
const ANGLED := "000011"
const LASER := "000005"
const HI_CAP := "000012"
const LOW_CAP := "000013"
const EXTENDED := "000014"
const TIGHT_BORE := "000016"
const LONG := "000017"
const SILENCER := "000018"

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())


func _ids(list: Array[Pool.Item]) -> Array:
	return list.map(func(i: Pool.Item) -> String: return i.id)


## The kit's slot `slot` with replica `id` fitted with `parts` (slot → part ID).
func _carried(id: String, parts: Dictionary, slot: int = 0) -> ReplicaConfig:
	var l := rules.default_loadout("Test")
	if l.equipped[slot] != id:
		rules.equip(l, slot as Loadout.Slot, id)
	for part_slot: StringName in parts:
		assert_true(rules.set_part(l, id, part_slot, parts[part_slot]), "%s fits %s" % [parts[part_slot], id])
	return rules.carried(l).replicas[slot]


func _base(id: String) -> ReplicaConfig:
	return rules.config(rules.pool.item(id))


func test_the_shipped_pool_lists_the_parts_by_slot() -> void:
	var pool := rules.pool
	assert_eq(pool.problems, [] as Array[String])
	assert_eq(pool.parts.size(), 13, "the weapon torch a part since WL7, the Variable Scope since SN2")
	assert_eq(pool.item(SCOPE).slot, &"optic")
	assert_eq(pool.item(SCOPE).key, &"scope2x")
	assert_eq(pool.item(SILENCER).slot, &"muzzle")
	var aeg := pool.item(AEG)
	var pistol := pool.item(PISTOL)
	assert_eq(_ids(pool.parts_for(aeg, &"optic", false)), [RED_DOT, SCOPE, VARIABLE_SCOPE], "public since 2026-11-05")
	assert_eq(_ids(pool.parts_for(aeg, &"grip", false)), [VERTICAL, ANGLED])
	assert_eq(_ids(pool.parts_for(aeg, &"magazine", false)), [HI_CAP, LOW_CAP])
	assert_eq(_ids(pool.parts_for(aeg, &"barrel", false)), [TIGHT_BORE, LONG])
	assert_eq(_ids(pool.parts_for(aeg, &"laser", false)), [LASER], "on its side rail (BP8)")
	assert_eq(_ids(pool.parts_for(pistol, &"optic", false)), [])
	assert_eq(_ids(pool.parts_for(pistol, &"laser", false)), [LASER])
	assert_eq(_ids(pool.parts_for(pistol, &"magazine", false)), [EXTENDED])
	assert_eq(_ids(pool.parts_for(pistol, &"muzzle", false)), [SILENCER])
	assert_eq(_ids(pool.parts_for(pool.item(CYBER), &"muzzle", false)), [])


func test_the_shipped_part_tables_read_without_a_problem() -> void:
	var s := ReplicaStats.read_file()
	assert_eq(s.problems, [] as Array[String])
	var scope := s.parts.part(&"optic", &"scope2x")
	assert_almost_eq(scope.zoom, 2.0, 1e-9)
	assert_almost_eq(scope.raise, 1.6, 1e-9)
	var hi := s.parts.part(&"magazine", &"hiCap")
	assert_almost_eq(hi.capacity, 2.0, 1e-9)
	assert_eq(hi.carried, -2)
	assert_true(hi.rattles)
	assert_false(s.parts.part(&"magazine", &"lowCap").rattles)
	assert_almost_eq(s.parts.part(&"barrel", &"long").energy, 0.1, 1e-9)
	var silencer := s.parts.part(&"muzzle", &"silencer")
	assert_almost_eq(silencer.energy, -0.05, 1e-9)
	assert_almost_eq(silencer.heard, 0.5, 1e-9)
	assert_almost_eq(s.parts.part(&"laser", &"redLaser").spread, 0.8, 1e-9)


func test_an_unreadable_part_cell_changes_nothing_there_and_says_where() -> void:
	var s := ReplicaStats.parse("""## Optics

| Key | Name | Zoom (×) | Raise time (×) |
|---|---|---|---|
| redDot | Red Dot | lots | 1.5 |

## Magazines

| Key | Name | Capacity (×) | Carried (+) | Reload (×) | Draw (×) | Rattles |
|---|---|---|---|---|---|---|
| hiCap | Hi-Cap | 2 | 1.5 | 1 | 1 | maybe |
""")
	var dot := s.parts.part(&"optic", &"redDot")
	assert_almost_eq(dot.zoom, 1.0, 1e-9, "the zoom that won't read changes nothing")
	assert_almost_eq(dot.raise, 1.5, 1e-9, "the rest of the row reads")
	assert_eq(s.parts.part(&"magazine", &"hiCap").carried, 0, "Carried must be whole")
	var joined := "\n".join(s.problems)
	assert_string_contains(joined, "stats.md:5: Zoom (×) must be a number from 1 to 8, not \"lots\"")
	assert_string_contains(joined, "Carried (+) must be a whole number")
	assert_string_contains(joined, "Rattles must be yes or no, not \"maybe\"")


func test_a_part_with_no_row_changes_nothing() -> void:
	var s := ReplicaStats.parse("")
	var p := s.parts.part(&"muzzle", &"silencer")
	assert_almost_eq(p.heard, 1.0, 1e-9)
	assert_almost_eq(p.energy, 0.0, 1e-9)
	assert_almost_eq(s.parts.part(&"nowhere", &"x").handling, 1.0, 1e-9)


func test_parts_are_saved_and_loaded_with_the_setup() -> void:
	var t := ReplicaTune.new()
	t.parts[&"optic"] = SCOPE
	t.parts[&"magazine"] = HI_CAP
	var back := ReplicaTune.from_dict(JSON.parse_string(JSON.stringify(t.to_dict())), ReplicaTune.new())
	assert_eq(back.parts, {&"optic": SCOPE, &"magazine": HI_CAP} as Dictionary[StringName, String])
	var copy := t.copy()
	copy.parts.erase(&"optic")
	assert_true(t.parts.has(&"optic"), "a copy has its own parts")
	var odd := ReplicaTune.from_dict({"parts": {"optic": 7, "grip": VERTICAL}}, ReplicaTune.new())
	assert_eq(odd.parts, {&"grip": VERTICAL} as Dictionary[StringName, String], "only text is read")


func test_a_part_is_fitted_only_where_it_fits_and_taken_off_with_nothing() -> void:
	var l := rules.default_loadout("Test")
	assert_true(rules.set_part(l, AEG, &"optic", SCOPE))
	assert_false(rules.set_part(l, PISTOL, &"grip", VERTICAL), "the pistol has no under rail")
	assert_false(rules.set_part(l, AEG, &"grip", SCOPE), "a scope isn't a grip")
	assert_false(rules.set_part(l, AEG, &"stock", SCOPE), "no such slot")
	assert_false(rules.set_part(l, PISTOL, &"optic", RED_DOT), "the pistol has no top rail")
	assert_eq(l.tunes[AEG].parts, {&"optic": SCOPE} as Dictionary[StringName, String])
	assert_true(rules.set_part(l, AEG, &"optic", ""))
	assert_eq(l.tunes[AEG].parts, {} as Dictionary[StringName, String])


func test_clean_takes_off_a_part_that_wont_do() -> void:
	var l := rules.default_loadout("Test")
	var t := rules.default_tune(rules.pool.item(AEG))
	t.parts = {&"optic": RED_DOT, &"laser": LASER, &"grip": SCOPE, &"muzzle": "999999", &"barrel": LONG}
	l.tunes[AEG] = t
	var said := rules.clean(l)
	assert_eq(t.parts, {&"optic": RED_DOT, &"laser": LASER, &"barrel": LONG} as Dictionary[StringName, String],
			"the AEG keeps its laser (BP8)")
	assert_eq(said.size(), 2)
	assert_string_contains(said[0] + said[1], "AEG Rifle's grip \"%s\" won't do" % SCOPE)


func test_as_it_comes_a_replica_plays_as_before() -> void:
	for id: String in [AEG, PISTOL]:
		var base := _base(id)
		var r := _carried(id, {}, 0 if id == AEG else 1)
		assert_eq(r.mag_size, base.mag_size)
		assert_eq(r.mags, base.mags)
		assert_almost_eq(r.reload_time, base.reload_time, 1e-9)
		assert_almost_eq(r.draw_time, base.draw_time, 1e-9)
		assert_almost_eq(r.spread_deg, base.spread_deg, 1e-9)
		assert_eq(r.aim_zoom, 0.0, "the iron sights' zoom")
		assert_eq(r.raise_scale, 1.0)
		assert_eq(r.shake_scale, 1.0)
		assert_false(r.rattles)
		assert_eq(r.heard_scale, 1.0)
		assert_false(r.muffled)


func test_magazines_change_capacity_count_reload_and_draw() -> void:
	var base := _base(AEG)
	var hi := _carried(AEG, {&"magazine": HI_CAP})
	assert_eq(hi.mag_size, base.mag_size * 2)
	assert_eq(hi.mags, maxi(1, base.mags - 2))
	assert_true(hi.rattles)
	var low := _carried(AEG, {&"magazine": LOW_CAP})
	assert_eq(low.mag_size, roundi(base.mag_size * 0.5))
	assert_eq(low.mags, base.mags + 2)
	assert_almost_eq(low.reload_time, base.reload_time * 0.75, 1e-6)
	assert_almost_eq(low.draw_time, base.draw_time * 0.9, 1e-6)
	assert_false(low.rattles)
	var pistol := _base(PISTOL)
	var ext := _carried(PISTOL, {&"magazine": EXTENDED}, 1)
	assert_eq(ext.mag_size, roundi(pistol.mag_size * 1.5))
	assert_almost_eq(ext.draw_time, pistol.draw_time * 1.35, 1e-6)


func test_optics_zoom_and_slow_the_raise_grips_handle_and_steady() -> void:
	var base := _base(AEG)
	var scope := _carried(AEG, {&"optic": SCOPE})
	assert_almost_eq(scope.aim_zoom, 2.0, 1e-9)
	assert_almost_eq(scope.raise_scale, 1.6, 1e-9)
	assert_almost_eq(scope.draw_time, base.draw_time, 1e-9, "an optic doesn't slow the draw")
	assert_almost_eq(_carried(AEG, {&"optic": RED_DOT}).aim_zoom, 1.25, 1e-9)
	var grip := _carried(AEG, {&"grip": VERTICAL, &"optic": SCOPE})
	assert_almost_eq(grip.draw_time, base.draw_time * 1.25, 1e-6)
	assert_almost_eq(grip.raise_scale, 1.25 * 1.6, 1e-6)
	assert_almost_eq(grip.shake_scale, 0.6, 1e-9)
	assert_almost_eq(_carried(AEG, {&"grip": ANGLED}).shake_scale, 1.3, 1e-9)


func test_lasers_and_barrels_tighten_the_spread_and_barrels_and_silencers_change_energy() -> void:
	var pistol := _base(PISTOL)
	assert_almost_eq(_carried(PISTOL, {&"laser": LASER}, 1).spread_deg, pistol.spread_deg * 0.8, 1e-9)
	var base := _base(AEG)
	var tight := _carried(AEG, {&"barrel": TIGHT_BORE})
	assert_almost_eq(tight.spread_deg, base.spread_deg * 0.85, 1e-9)
	var limit := rules.stats.energy_limit(base.site_class)
	assert_almost_eq(tight.muzzle_energy, minf(limit, base.muzzle_energy * 1.03), 1e-9)
	var long := _carried(AEG, {&"barrel": LONG})
	assert_almost_eq(long.draw_time, base.draw_time * 1.15, 1e-6, "a long barrel is front-heavy")
	var silenced := _carried(AEG, {&"muzzle": SILENCER, &"barrel": LONG})
	assert_almost_eq(silenced.muzzle_energy, minf(limit, base.muzzle_energy * 1.1 * 0.95), 1e-9)
	assert_almost_eq(silenced.draw_time, base.draw_time * 1.15 * 1.1, 1e-6)
	assert_almost_eq(silenced.heard_scale, 0.5, 1e-9)
	assert_true(silenced.muffled)


func test_a_barrel_counts_toward_the_site_limit() -> void:
	var l := rules.default_loadout("Test")
	assert_true(rules.set_power(l, AEG, LIPO))
	assert_true(rules.set_part(l, AEG, &"barrel", LONG))
	var kit := rules.carried(l)
	var base := _base(AEG)
	var energy := base.muzzle_energy * (1.0 + rules.stats.power(LIPO).energy) * 1.1
	var limit := rules.stats.energy_limit(base.site_class)
	assert_almost_eq(kit.replicas[0].muzzle_energy, minf(energy, limit), 1e-9)
	assert_eq(kit.capped[0], energy > limit)


func test_the_kit_lists_each_slots_part_keys() -> void:
	var l := rules.default_loadout("Test")
	rules.set_part(l, AEG, &"optic", RED_DOT)
	rules.set_part(l, PISTOL, &"muzzle", SILENCER)
	var kit := rules.carried(l)
	assert_eq(kit.parts, [{&"optic": &"redDot"}, {&"muzzle": &"silencer"}])
	assert_false(kit.dev)


func test_a_dev_part_plays_only_with_dev_content_on() -> void:
	var pool := Pool.parse("""### Replicas
| ID | Name | Key | Tags | Access |
|---|---|---|---|---|
| 000002 | AEG Rifle | aeg | rifle, electric, top-rail | public |
| 000001 | GBB Pistol | pistol | pistol, gas | public |

### Power sources
| ID | Name | Type | Fits | Access |
|---|---|---|---|---|
| 000003 | Standard Battery | battery | electric | public |
| 000004 | Green Gas | gas | gas | public |

### Optics
| ID | Name | Key | Fits | Access |
|---|---|---|---|---|
| 000010 | 2x Scope | scope2x | top-rail | dev |
""")
	rules = LoadoutRules.new(pool, ReplicaStats.read_file(), ReplicaRulesConfig.new())
	var l := rules.default_loadout("Test")
	assert_false(rules.set_part(l, AEG, &"optic", SCOPE), "not on offer with Dev content off")
	rules.dev_content = true
	assert_true(rules.set_part(l, AEG, &"optic", SCOPE))
	assert_almost_eq(rules.carried(l).replicas[0].aim_zoom, 2.0, 1e-9)
	assert_true(rules.carried(l).dev, "a dev part keeps the match off the record")
	rules.dev_content = false
	assert_eq(rules.clean(l), [] as Array[String], "it stays saved")
	var kit := rules.carried(l)
	assert_eq(kit.replicas[0].aim_zoom, 0.0, "and plays as not fitted")
	assert_false(kit.dev)


func test_an_optic_and_its_handling_set_how_long_the_sight_takes_to_come_up() -> void:
	var cfg := MovementConfig.new()
	for scale: float in [1.0, 1.6]:
		var r := _base(AEG).duplicate() as ReplicaConfig
		r.raise_scale = scale
		var c := Character.new(0, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])
		c.armament.draw_left = 0.0
		var cmd := PlayerCommand.new()
		cmd.aim = true
		var ticks := 0
		while c.aim_raise < 1.0 and ticks < 600:
			Aiming.step(c, cmd, cfg, DT)
			ticks += 1
		assert_eq(ticks, ceili(cfg.aim_raise_time * scale / DT - 1e-6), "raise at %s" % scale)


func test_a_grip_sets_how_long_a_sprints_shake_stays() -> void:
	var cfg := MovementConfig.new()
	var acc := AccuracyConfig.new()
	var r := _base(AEG).duplicate() as ReplicaConfig
	r.shake_scale = 0.6
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])
	c.grounded = true
	c.sprinting = true
	Accuracy.step(c, cfg, acc, DT)
	assert_almost_eq(c.shake_carry, acc.carry_time * 0.6, 1e-9)


func test_a_rattling_magazine_is_heard_walking() -> void:
	var cfg := FootstepConfig.new()
	var world := BoxWorld.new()
	var events := SimEvents.new()
	for rattling: bool in [false, true]:
		var r := _base(AEG).duplicate() as ReplicaConfig
		r.rattles = rattling
		var c := Character.new(0, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])
		c.walking = true
		var kinds: Array[int] = []
		for i in 60:
			events.clear()
			c.prev_position = c.position
			c.position.z -= (cfg.stride_run * 2.0 + 0.01) / 60.0
			c.grounded = true
			Footsteps.step(c, cfg, events, world)
			var e := events.first(GameEvent.Kind.FOOTSTEP)
			if e != null:
				kinds.append(e.value)
		assert_eq(kinds, [GameEvent.Footstep.RATTLE, GameEvent.Footstep.RATTLE] if rattling else [] as Array[int])
		# Running, it is heard as running.
		c.walking = false
		events.clear()
		c.step_distance = cfg.stride_run
		c.prev_position = c.position
		Footsteps.step(c, cfg, events, world)
		assert_eq(events.first(GameEvent.Kind.FOOTSTEP).value, GameEvent.Footstep.RUN)

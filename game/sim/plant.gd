class_name Plant
## Plant The Bomb's rules, one tick at a time (PB1, owner 2026-11-12): the bomb lies at the attackers' start; an
## attacker holding Use beside it picks it up, and drops it where it is hit; the carrier holding Use inside a site arms
## it there (PlantConfig.plant_time), after which its fuse runs and it beeps, faster as it runs out; a defender holding
## Use at the armed bomb disarms it (defuse_time, a let-go past the checkpoint kept). Round decides what each end means.
## Whoever arms or disarms has both hands on it: `busy` holds it still with its replica down (Simulation). A prop, as
## at a real site: it goes off with a siren and smoke and hurts nobody. Allocates nothing.

## What the device just did, a BOMB event's value. PICKED_UP, DROPPED: actor the carrier. ARMING, ARMING_STOPPED,
## PLANTED: actor the planter, value2 the site. BEEP: value2 the fuse left in tenths of a second. DEFUSING,
## DEFUSING_STOPPED, DEFUSED: actor the defuser. WENT_OFF: the fuse ran out.
enum Cue { PICKED_UP, DROPPED, ARMING, ARMING_STOPPED, PLANTED, BEEP, DEFUSING, DEFUSING_STOPPED, DEFUSED, WENT_OFF }
## How a tick left it for the round: still going, disarmed (the defenders win) or gone off (the attackers win).
enum Outcome { NONE, DEFUSED, WENT_OFF }
## What the sites are called, in the map's order, and the most a map has.
const LETTERS: PackedStringArray = ["A", "B"]
const MOST := 2
## A hold counted in ticks of dt falls short of its time by float error only: within this share it is done.
const SLACK := 1e-6


## One tick (`dt` s) of the device in a live round: pick-up, drop, arming, the fuse and disarming, each character's
## hand read from Character.using. `attackers` is the attacking team.
static func step(ps: PlantState, characters: Array[Character], attackers: int, cfg: PlantConfig, events: SimEvents,
		dt: float) -> Outcome:
	match ps.status:
		PlantState.Status.DOWN:
			_step_down(ps, characters, attackers, cfg, events)
		PlantState.Status.CARRIED:
			_step_carried(ps, characters, cfg, events, dt)
		PlantState.Status.PLANTED:
			return _step_planted(ps, characters, attackers, cfg, events, dt)
	return Outcome.NONE


## Whether `c` has both hands on the bomb this tick (arming or disarming it): it stands still, its replica down.
static func busy(ps: PlantState, c: Character) -> bool:
	return (ps.planter == c.id and ps.status == PlantState.Status.CARRIED) \
			or (ps.defuser == c.id and ps.status == PlantState.Status.PLANTED)


## The site `at` stands in (flat, within the site's radius, its feet within reach_height of the site's floor), or -1.
static func site_at(ps: PlantState, at: Vector3, cfg: PlantConfig) -> int:
	for i in ps.sites.size():
		var s := ps.sites[i]
		if absf(at.y - s.y) > cfg.reach_height:
			continue
		var r := ps.radii[i] if i < ps.radii.size() else cfg.site_radius
		if _flat_squared(at, s) <= r * r:
			return i
	return -1


## The site nearest `at` (flat); -1 with none.
static func nearest_site(ps: PlantState, at: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in ps.sites.size():
		var d := _flat_squared(at, ps.sites[i])
		if d < best_d:
			best_d = d
			best = i
	return best


## Whether `c` (in play) is close enough to the bomb where it lies or stands armed to work on it: within `reach` flat,
## its feet within reach_height of it.
static func in_reach(ps: PlantState, c: Character, reach: float, cfg: PlantConfig) -> bool:
	return Elimination.is_in_play(c) and absf(c.position.y - ps.position.y) <= cfg.reach_height \
			and _flat_squared(c.position, ps.position) <= reach * reach


## Seconds between beeps with `fuse_left` s of fuse to run.
static func beep_gap(fuse_left: float, cfg: PlantConfig) -> float:
	return lerpf(cfg.beep_fast, cfg.beep_slow, clampf(fuse_left / maxf(cfg.fuse_time, SLACK), 0.0, 1.0))


## The clock ran out or the Dev tab ended the round: a bomb armed goes off on the next tick.
static func run_out(ps: PlantState) -> void:
	if ps.status == PlantState.Status.PLANTED:
		ps.fuse_left = 0.0


## On the ground: the first attacker in play holding Use in reach takes it.
static func _step_down(ps: PlantState, characters: Array[Character], attackers: int, cfg: PlantConfig,
		events: SimEvents) -> void:
	for c in characters:
		if c.team != attackers or not c.using or not in_reach(ps, c, cfg.pickup_reach, cfg):
			continue
		ps.status = PlantState.Status.CARRIED
		ps.carrier = c.id
		ps.moved = true
		ps.position = c.position
		_cue(events, Cue.PICKED_UP, c.id, ps.position, -1)
		return


## Carried: it goes where its carrier goes; a carrier hit drops it there; the carrier holding Use on the ground inside a
## site arms it, and plants it once plant_time is held.
static func _step_carried(ps: PlantState, characters: Array[Character], cfg: PlantConfig, events: SimEvents,
		dt: float) -> void:
	var carrier := _by_id(characters, ps.carrier)
	if carrier == null or not Elimination.is_in_play(carrier):
		_stop_arming(ps, events)
		ps.status = PlantState.Status.DOWN
		if carrier != null:
			ps.position = carrier.position
		_cue(events, Cue.DROPPED, ps.carrier, ps.position, -1)
		ps.carrier = -1
		return
	ps.position = carrier.position
	var site := site_at(ps, carrier.position, cfg) if carrier.using and carrier.grounded else -1
	if site < 0:
		_stop_arming(ps, events)
		return
	if ps.planter != carrier.id:
		ps.planter = carrier.id
		ps.planting = 0.0
		ps.site = site
		_cue(events, Cue.ARMING, carrier.id, ps.position, site)
	ps.planting = minf(1.0, ps.planting + dt / maxf(cfg.plant_time, SLACK))
	if ps.planting < 1.0 - SLACK:
		return
	ps.status = PlantState.Status.PLANTED
	ps.site = site
	ps.carrier = -1
	ps.planter = -1
	ps.planting = 1.0
	ps.fuse_left = cfg.fuse_time
	ps.defuser = -1
	ps.defusing = 0.0
	ps.beep_in = beep_gap(ps.fuse_left, cfg)
	_cue(events, Cue.PLANTED, carrier.id, ps.position, site)


## Armed: a defender holding Use in reach disarms it (the one already on it kept, else the first); nobody on it, the
## defuse falls back to its checkpoint or to nothing. The fuse runs meanwhile and beeps; at its end it goes off, a
## defuse under way or not.
static func _step_planted(ps: PlantState, characters: Array[Character], attackers: int, cfg: PlantConfig,
		events: SimEvents, dt: float) -> Outcome:
	var on_it: Character = null
	for c in characters:
		if c.team == attackers or not c.using or not c.grounded or not in_reach(ps, c, cfg.defuse_reach, cfg):
			continue
		if c.id == ps.defuser:
			on_it = c
			break
		if on_it == null:
			on_it = c
	if on_it == null:
		if ps.defuser >= 0:
			_cue(events, Cue.DEFUSING_STOPPED, ps.defuser, ps.position, ps.site)
			ps.defuser = -1
			ps.defusing = cfg.defuse_checkpoint if cfg.defuse_checkpoint > 0.0 \
					and ps.defusing >= cfg.defuse_checkpoint else 0.0
	else:
		if ps.defuser != on_it.id:
			ps.defuser = on_it.id
			_cue(events, Cue.DEFUSING, on_it.id, ps.position, ps.site)
		ps.defusing = minf(1.0, ps.defusing + dt / maxf(cfg.defuse_time, SLACK))
		if ps.defusing >= 1.0 - SLACK:
			ps.status = PlantState.Status.DEFUSED
			ps.defusing = 1.0
			_cue(events, Cue.DEFUSED, on_it.id, ps.position, ps.site)
			return Outcome.DEFUSED
	ps.fuse_left = maxf(0.0, ps.fuse_left - dt)
	if ps.fuse_left <= 0.0:
		ps.status = PlantState.Status.GONE_OFF
		ps.defuser = -1
		_cue(events, Cue.WENT_OFF, -1, ps.position, ps.site)
		return Outcome.WENT_OFF
	ps.beep_in -= dt
	if ps.beep_in <= 0.0:
		ps.beep_in += beep_gap(ps.fuse_left, cfg)
		var beep := _cue(events, Cue.BEEP, -1, ps.position, ps.site)
		beep.value2 = roundi(ps.fuse_left * 10.0)
	return Outcome.NONE


static func _stop_arming(ps: PlantState, events: SimEvents) -> void:
	if ps.planter < 0:
		return
	_cue(events, Cue.ARMING_STOPPED, ps.planter, ps.position, ps.site)
	ps.planter = -1
	ps.planting = 0.0
	ps.site = -1


static func _cue(events: SimEvents, cue: Cue, actor: int, at: Vector3, site: int) -> GameEvent:
	var e := events.add(GameEvent.Kind.BOMB)
	e.value = cue
	e.actor = actor
	e.position = at
	e.value2 = site
	return e


static func _by_id(characters: Array[Character], id: int) -> Character:
	for c in characters:
		if c.id == id:
			return c
	return null


static func _flat_squared(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz

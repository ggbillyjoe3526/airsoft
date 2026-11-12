class_name BotPlant
## Plant The Bomb for bots (PB1, owner 2026-11-12). The sites stand in for Attack / Defend's poles (`sync` keeps a
## FlagState a site in BotWorld.flags: its middle, or the bomb once armed; "going up" while it is being armed, "up" once
## armed, and only once a defender is near enough to hear it), so lanes, posts, guards, retakes and flag mode are BotFlag's and BotMovement's as they are. This adds what a
## bomb needs: who fetches it from the ground, the carrier as the one who goes in and arms it, which site is in play,
## every defender back to an armed bomb with one disarming it, and when a bot's hands go on it (`act`).
##
## The player comes first (owner): on the attackers' team the bots leave the bomb to them for plant_player_first s of
## a round (less once they have walked off without it), and on the defenders' team no bot disarms while the player is
## in play near the bomb, until the fuse leaves a bot only just time to. Allocates nothing.

## A site being armed counts as a flag at least this far up, so the defenders nearest come at once.
const ARMING_FLOOR := 0.01


## The round's sites as BotWorld.flags, the bomb as BotWorld.plant and the site in play as flag_index (each tick).
static func sync(w: BotWorld, rs: RoundState) -> void:
	var ps := rs.plant
	w.plant = ps
	var n := ps.sites.size()
	if n == 0:
		# A map with no sites never hosts the mode (PlaySession); a test's bare state keeps the round's own flags.
		w.flags = rs.flags
		w.flag_index = 0
		w.flag = rs.flags[0]
		return
	while w.site_flags.size() < n:
		w.site_flags.append(FlagState.new())
	w.site_flags.resize(n)
	for i in n:
		w.site_flags[i].reset(ps.sites[i])
	if ps.site >= 0 and ps.site < n:
		var f := w.site_flags[ps.site]
		if ps.planted():
			f.position = ps.position
			f.progress = 1.0
			f.status = FlagState.Status.LOWERING if ps.defuser >= 0 else FlagState.Status.IDLE
		elif ps.planter >= 0 and _arming_heard(w):
			f.progress = maxf(ps.planting, ARMING_FLOOR)
			f.status = FlagState.Status.RAISING
	w.flags = w.site_flags
	w.plant_site = site_in_play(w)
	w.flag_index = w.plant_site
	w.flag = w.flags[w.flag_index]


## Whether the defenders know the bomb is being armed: one of them in play is within plant_heard of it (the keypad's
## beeps carry that far, as they do to the player). Until then their bots hold their posts.
static func _arming_heard(w: BotWorld) -> bool:
	for c in w.characters:
		if c.team != w.attackers and Elimination.is_in_play(c) \
				and _flat(c.position, w.plant.position) <= w.cfg.plant_heard:
			return true
	return false


## The site the attackers make for: the one the bomb is being armed in or stands armed in; else, while the player
## carries it, the site they are closing on (within plant_follow_site, and nearer than the one kept by
## plant_site_margin: the bots come with them); else the one drawn for the round (RoundPlanner.attack_flag).
static func site_in_play(w: BotWorld) -> int:
	var ps := w.plant
	var n := ps.sites.size()
	if ps.site >= 0 and ps.site < n and (ps.planted() or ps.planter >= 0):
		return ps.site
	var kept := clampi(w.planner.attack_flag if w.planner != null else 0, 0, n - 1)
	if ps.status != PlantState.Status.CARRIED:
		return kept
	var carrier := _by_id(w, ps.carrier)
	if carrier == null or w.bot_of(carrier) != null:
		return kept
	var near := Plant.nearest_site(ps, carrier.position)
	if near < 0 or near == kept:
		return kept
	var d := _flat(carrier.position, ps.sites[near])
	if d <= w.cfg.plant_follow_site and d + w.cfg.plant_site_margin <= _flat(carrier.position, ps.sites[kept]):
		# Kept for the rest of the round, whoever carries it next.
		w.planner.attack_flag = near
		return near
	return kept


## What the tick's events mean to the plan: the bomb on the ground since the round's GO or since it was dropped; a bomb
## dropped in the defenders' half moves the plan to the site nearest it (its carrier fell on the way in), and the bot
## that takes it up there goes on to the site rather than back to its lane.
static func observe(w: BotWorld, events: SimEvents, time: float) -> void:
	for i in events.count:
		var e := events.items[i]
		if e.kind == GameEvent.Kind.ROUND_START or e.kind == GameEvent.Kind.ROUND_GO:
			w.plant_down_at = time
			w.plant_fell_far = false
		elif e.kind == GameEvent.Kind.PLANT and e.value == Plant.Cue.DROPPED:
			w.plant_down_at = time
			w.plant_fell_far = w.plant != null and w.planner != null \
					and w.planner.in_enemy_half_at(e.position, w.attackers)
			if w.plant_fell_far:
				var near := Plant.nearest_site(w.plant, e.position)
				if near >= 0:
					w.planner.attack_flag = near
		elif e.kind == GameEvent.Kind.PLANT and e.value == Plant.Cue.PICKED_UP and w.plant_fell_far:
			# Taken up where its carrier fell on the way in: its new carrier's lane is behind it.
			for b in w.bots:
				if b.character.id == e.actor:
					b.lane_done = true


## Each tick, before the bots think: who fetches the bomb, who arms it, who goes back to it and who disarms it.
static func plan(w: BotWorld) -> void:
	if w.plant == null or w.attackers < 0:
		return
	_pick_fetcher(w)
	var ps := w.plant
	var carrier: Bot = null
	for b in w.bots:
		b.raiser = ps.status == PlantState.Status.CARRIED and ps.carrier == b.character.id \
				and b.order == SquadOrder.Kind.NONE
		if b.raiser:
			carrier = b
	_hold_carrier(w, carrier)
	if ps.planted():
		# Armed: every free defender goes back to it.
		for b in w.bots:
			b.retake_pole = ps.site if BotFlag._free_defender(b, w) else -1
			b.retake = b.retake_pole >= 0
	else:
		BotFlag.pick_retakers(w)
	_pick_defuser(w)


## The carrier goes in last (w.plant_go): its lane swept, it holds there until plant_escorts of its team in play, or
## all that are left, are within plant_escort_radius of the site's middle, or plant_carrier_wait s have passed. Kept
## once given, while the same bot carries it.
static func _hold_carrier(w: BotWorld, carrier: Bot) -> void:
	if carrier == null or carrier.character.id != w.plant_go_for:
		w.plant_go = false
		w.plant_hold_since = -1.0
		w.plant_go_for = carrier.character.id if carrier != null else -1
	if carrier == null or w.plant_go or not carrier.lane_done:
		return
	if w.plant_hold_since < 0.0:
		w.plant_hold_since = w.time
	if w.time - w.plant_hold_since >= w.cfg.plant_carrier_wait:
		w.plant_go = true
		return
	var site := w.plant.sites[w.plant_site]
	var others := 0
	var by := 0
	for c in w.characters:
		if c.team != w.attackers or c == carrier.character or not Elimination.is_in_play(c):
			continue
		others += 1
		if _flat(c.position, site) <= w.cfg.plant_escort_radius:
			by += 1
	w.plant_go = by >= mini(w.cfg.plant_escorts, others)


## Whether `b` should be at its site (or at the bomb) now. An attacker: fetching the bomb, with the bomb armed, with
## plant_rush_clock or less of the round left and nothing armed yet, or once its lane is swept (the carrier: once its
## escort is in, _hold_carrier). A defender: picked to go back to a site where the bomb is being armed or stands armed.
static func wants_site(b: Bot, w: BotWorld) -> bool:
	match BotFlag.role(b, w):
		BotFlag.Role.ATTACK:
			if b.fetcher or w.plant.planted() or (w.live and w.round_clock <= w.cfg.plant_rush_clock):
				return true
			return b.lane_done and (w.plant_go or not b.raiser)
		BotFlag.Role.DEFEND:
			return b.retake and b.retake_pole >= 0 and w.flags[b.retake_pole].progress > 0.0
	return false


## Whether `b` takes cover by its site rather than going onto it: an attacker who is neither fetching the bomb nor
## carrying it in, and a defender back at an armed bomb who is not the one disarming it. An attacker who hears the kit
## at work on the armed bomb (within plant_heard of it) leaves its cover and goes to the bomb itself.
static func guards(b: Bot, w: BotWorld) -> bool:
	if b.fetcher:
		return false
	if BotFlag.role(b, w) == BotFlag.Role.ATTACK:
		if w.plant.planted() and w.plant.defuser >= 0 \
				and _flat(b.character.position, w.plant.position) <= w.cfg.plant_heard:
			return false
		return not b.raiser
	return w.plant.planted() and not b.defuser


## Where an attacker guarding the armed bomb watches for the defenders coming back, and hides from: the guards split,
## by turns (a bot's place among the attackers in play), between the two ways back to it, from the other site and from
## the defenders' start, so an armed bomb is covered both ways. With one site, their start.
static func watch_point(b: Bot, w: BotWorld) -> Vector3:
	var ps := w.plant
	var home := w.planner.spawn_centre[1 - w.attackers]
	if ps.sites.size() < 2 or ps.site < 0:
		return home
	var turn := 0
	for o in w.bots:
		if o == b:
			break
		if o.character.team == b.character.team and Elimination.is_in_play(o.character):
			turn += 1
	return ps.sites[(ps.site + 1) % ps.sites.size()] if turn % 2 == 0 else home


## Whether the bots may take the bomb from the ground now. With no player on the attackers' team in play, at once.
## Lying at the start: once plant_player_first s of the round have run, or sooner once the player is plant_player_left
## m from it (they left it). Dropped: after plant_drop_wait s if the player is not within plant_player_near m of it,
## else once plant_player_first s have passed since it fell.
static func may_take(w: BotWorld) -> bool:
	var ps := w.plant
	var you := player_on(w, w.attackers)
	if you == null:
		return true
	var waited := w.time - w.plant_down_at
	if waited >= w.cfg.plant_player_first:
		return true
	if not ps.moved:
		return not _player_within(w, you, w.cfg.plant_player_left)
	return not _player_within(w, you, w.cfg.plant_player_near) and waited >= w.cfg.plant_drop_wait


## Whether a bot may disarm the bomb now. With no player on the defenders' team in play, or the player not within
## plant_player_claim m of it on its storey, at once. With the player near, never while they are on it, and otherwise only once the
## fuse leaves no more than what is left of the defuse plus plant_takeover_margin s.
static func may_defuse(w: BotWorld) -> bool:
	var ps := w.plant
	var you := player_on(w, 1 - w.attackers)
	if you == null:
		return true
	if ps.defuser == you.id:
		return false
	if not _player_within(w, you, w.cfg.plant_player_claim):
		return true
	return ps.fuse_left <= defuse_left(w) + w.cfg.plant_takeover_margin


## Whether the player `you` is within `reach` m of the bomb, measured level, and on its storey (plant_player_level).
static func _player_within(w: BotWorld, you: Character, reach: float) -> bool:
	var at := w.plant.position
	return absf(you.position.y - at.y) <= w.cfg.plant_player_level and _flat(you.position, at) <= reach


## Seconds of holding Use the defuse still needs.
static func defuse_left(w: BotWorld) -> float:
	return (1.0 - w.plant.defusing) * w.tuning.plant.defuse_time


## The player on `team` in play (the first character there no bot drives), or null.
static func player_on(w: BotWorld, team: int) -> Character:
	for c in w.characters:
		if c.team == team and Elimination.is_in_play(c) and w.bot_of(c) == null:
			return c
	return null


## After `b` has thought (`cmd` its command this tick): its hands go on the bomb when it is the one to take it, arm it
## or disarm it and it stands where that is done. A carrier arms once it has settled on its spot in the site, and one
## plant_commit along keeps arming whoever it sees; the one disarming keeps on past defuse_commit, or when the fuse
## leaves no time for anything else (plant_no_time).
static func act(b: Bot, w: BotWorld, cmd: PlayerCommand) -> void:
	var ps := w.plant
	var c := b.character
	if ps == null or not w.live or not Elimination.is_in_play(c):
		return
	var cfg := w.tuning.plant
	match ps.status:
		PlantState.Status.DOWN:
			if b.fetcher and may_take(w) and Plant.in_reach(ps, c, cfg.pickup_reach, cfg):
				cmd.interact = true
		PlantState.Status.CARRIED:
			if not b.raiser or Plant.site_at(ps, c.position, cfg) < 0:
				return
			var settled := b.mode == Bot.Mode.FLAG and not b.flag_guard \
					and _flat(c.position, b.flag_goal) <= w.cfg.flag_arrive + w.cfg.plant_settle_slack
			if settled or (ps.planter == c.id and ps.planting >= w.cfg.plant_commit):
				_hands_on(cmd)
		PlantState.Status.PLANTED:
			if not b.defuser or not Plant.in_reach(ps, c, cfg.defuse_reach, cfg):
				return
			var no_time := ps.fuse_left <= defuse_left(w) + w.cfg.plant_no_time
			var committed := ps.defuser == c.id and ps.defusing >= w.cfg.defuse_commit
			if b.mode == Bot.Mode.FLAG or no_time or committed:
				_hands_on(cmd)


## The attacking bot that fetches a bomb on the ground: the nearest in play under no squad order, the one already going
## kept unless another is raiser_switch_margin nearer. It walks to it at once and waits beside it (BotMovement) until
## may_take.
static func _pick_fetcher(w: BotWorld) -> void:
	var keep: Bot = null
	for b in w.bots:
		if b.fetcher:
			keep = b
		b.fetcher = false
	if w.plant.status != PlantState.Status.DOWN:
		return
	var best: Bot = null
	var best_d := INF
	for b in w.bots:
		if BotFlag.role(b, w) != BotFlag.Role.ATTACK or not Elimination.is_in_play(b.character) \
				or b.order != SquadOrder.Kind.NONE:
			continue
		var d := _flat(b.character.position, w.plant.position) - (w.cfg.raiser_switch_margin if b == keep else 0.0)
		if d < best_d:
			best_d = d
			best = b
	if best != null:
		best.fetcher = true


## The defending bot that disarms an armed bomb, once a bot may (may_defuse): the nearest of those back at it, the one
## already picked kept unless another is raiser_switch_margin nearer.
static func _pick_defuser(w: BotWorld) -> void:
	var keep: Bot = null
	for b in w.bots:
		if b.defuser:
			keep = b
		b.defuser = false
	if not w.plant.planted() or not may_defuse(w):
		return
	var best: Bot = null
	var best_d := INF
	for b in w.bots:
		if not b.retake:
			continue
		var d := _flat(b.character.position, w.plant.position) - (w.cfg.raiser_switch_margin if b == keep else 0.0)
		if d < best_d:
			best_d = d
			best = b
	if best != null:
		best.defuser = true


## Both hands on the bomb: Use held, still and low, the trigger let go.
static func _hands_on(cmd: PlayerCommand) -> void:
	cmd.interact = true
	cmd.fire = false
	cmd.aim = false
	cmd.crouch = true
	cmd.forward = 0.0
	cmd.right = 0.0
	cmd.sprint = false
	cmd.jump = false


static func _by_id(w: BotWorld, id: int) -> Character:
	for c in w.characters:
		if c.id == id:
			return c
	return null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

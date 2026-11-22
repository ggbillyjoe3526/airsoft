class_name BotSpread
## Spreading out (BG1, owner 2026-11-22): bots play as solos, pairs and trios, the whole team together only rarely. A
## noise or a teammate's call draws at most BotConfig.search_crowd_max teammates to one spot (the rest watch it from
## their plan), and hunters fan out away from one another. Same at every level. Allocates nothing. A teammate on another
## storey (more than BotConfig.anchor_search_rise above or below) is not at the spot (BP13: Subway's concourse stands
## over its platforms, so two upstairs kept the rest from a fight below).


## True if `spot` already has search_crowd_max of `b`'s teammates at it or on their way: in play within
## search_crowd_radius of it, or (bots) searching, fighting or in cover with their own threat in mind within that of it.
## Never for a bot within that of the spot itself.
static func crowded(b: Bot, w: BotWorld, spot: Vector3) -> bool:
	var cfg := w.cfg
	if cfg.search_crowd_max <= 0:
		return false
	var reach_sq := cfg.search_crowd_radius * cfg.search_crowd_radius
	# Already there itself: it is one of the crowd, not drawn in from afar.
	if _near(b.character.position, spot, reach_sq, cfg.anchor_search_rise):
		return false
	var team := b.character.team
	var n := 0
	for c in w.characters:
		if c != b.character and c.team == team and Elimination.is_in_play(c) \
				and _near(c.position, spot, reach_sq, cfg.anchor_search_rise):
			n += 1
	for m in w.bots:
		if m == b or m.character.team != team or not Elimination.is_in_play(m.character) or not m.has_last_known:
			continue
		if m.mode != Bot.Mode.SEARCH and m.mode != Bot.Mode.FIGHT and m.mode != Bot.Mode.COVER:
			continue
		# counted above already
		if _near(m.character.position, spot, reach_sq, cfg.anchor_search_rise):
			continue
		if _near(m.last_known, spot, reach_sq, cfg.anchor_search_rise):
			n += 1
	return n >= cfg.search_crowd_max


## True if a hunt spot is within hunt_crowd_gap of one of `b`'s teammates in play, or of where a hunting teammate is
## making for (RoundPlanner.hunt_point scores it staler).
static func hunt_crowded(b: Bot, w: BotWorld, spot: Vector3) -> bool:
	var gap_sq := w.cfg.hunt_crowd_gap * w.cfg.hunt_crowd_gap
	var rise := w.cfg.anchor_search_rise
	if gap_sq <= 0.0:
		return false
	var team := b.character.team
	for c in w.characters:
		if c != b.character and c.team == team and Elimination.is_in_play(c) \
				and _near(c.position, spot, gap_sq, rise):
			return true
	for m in w.bots:
		if m != b and m.hunting and m.character.team == team and Elimination.is_in_play(m.character) \
				and _near(m.hunt_goal, spot, gap_sq, rise):
			return true
	return false


## Whether `a` lies within the square root of `reach_sq` of `b` across the ground and within `rise` of its height.
static func _near(a: Vector3, b: Vector3, reach_sq: float, rise: float) -> bool:
	return absf(a.y - b.y) <= rise and Vector2(a.x - b.x, a.z - b.z).length_squared() < reach_sq

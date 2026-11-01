class_name SimAudio
extends Node
## The match's sound, from the tick's events (docs/ARCHITECTURE.md › Contracts 3): shots with their power part (a
## silenced one's shot duller and quieter; its power part and clicks as they are), dry clicks, magazines, the selector,
## the hop-up dial, the weapon torch's click (WL7) and draws, BB impacts by surface (in a bush's leaves their rustle,
## quieter for one brushing through an edge, WL5), footsteps by surface and pace (louder and further on loud ground, by
## the event's carry), vaults, a run into a noisy prop (its prop_<sound> cue; a BB's ring is its impact), the flag's
## rope ratcheting up or down, and hits: a tick where a BB hits a body (a ricochet that doesn't count too), the
## confirmation when it's yours, the thump when it's you. On the practice range steel rings and a figure knocks, heard
## down its whole length, your own target hit plays the confirmation, and the timed challenge's countdown and Go beep. A
## squad order of yours that a teammate took plays a radio's double click in your ear (on_order); so does each bot
## callout (on_calls): a teammate's in your ear, panned toward them, an enemy's from where they stand when close,
## through walls. Your own ping placed plays a soft pip in your ear (on_ping, PN2); a teammate's answer is its callout.
## The magazine hand-off (MH3): your ask taken plays the radio's double click, a toss its magToss from the thrower and
## its catch magCatch from the catcher. Smoke and flash bombs (SF1): the pin and the throw from the thrower, a bomb's
## knock where it bounces (louder the harder), a smoke's pop and hiss and a flash's bang (far: bang_reach) from the
## bomb, muffled by the walls between. A door opening or shutting (DO1): its door_open or door_shut cue from the door,
## yours too, muffled by the walls between. Kit rustles as a crouch, a stand or a lean starts (FoleyTracker, from the
## state: bots never hear it);
## a landing thuds louder and lower the harder it comes down, with a rustle under a hard one. The referee's whistle
## (WhistleQueue) on the Interface bus: two short blasts start a round, three quick short ones put Elimination's
## overtime flag up, one long ends a round, three more end the match, and the range's Time is one long. The map's ambience: its beds by day or night on the Ambience bus and its calls round
## the listener (AmbientCalls), positional, at the pool's lowest priority. Your own sounds play plain; everyone else's
## from where they happen, and only within reach of the ears the view is through (the listener): others' steps
## step_reach and at most step_limit per step_window, their rustle foley_reach and at most foley_limit per foley_window,
## BB impacts at most impact_limit per impact_window, the range's targets target_reach, shots and their power parts
## shot_reach (full level within shot_unit_size), the rest max_distance. Every
## variant is loaded up front, so the first shot never hitches. The voices are made once and shared through two
## VoicePools (yours plain, the field's positional) by priority. A cue never plays the same variant twice running; pitch
## and level are spread by kind (none on interface cues). Variant, pitch and level are presentation only, on SimAudio's
## own random stream. Every sound another character makes (a shot and its power part, mechanisms, steps, vaults, rustle,
## a hit on them) and every BB impact is muffled by the level geometry between it and the listener's eyes
## (SoundOcclusion): open, or on the half or full occlusion bus. Your own sounds and the interface's are never muffled.

const BUS_EFFECTS := &"Effects"
const BUS_FOOTSTEPS := &"Footsteps"
const BUS_AMBIENCE := &"Ambience"
const BUS_INTERFACE := &"Interface"
## The shot's power source part (gas, the motor) has its own bus under Effects, for its own volume (settings).
const BUS_POWER := &"Power"
## A silenced shot plays through this bus's low-pass filter (its first effect), under Effects.
const BUS_MUFFLED := &"Muffled"
## Cue names by RayHit.Surface (none sounds as concrete; a BB on gravel, grass or leaves as earth, a step on each as
## its own) and by GameEvent.Footstep.
const SURFACE_NAMES: PackedStringArray = ["concrete", "concrete", "metal", "wood", "earth", "gravel", "grass", "leaves"]
const IMPACT_NAMES: PackedStringArray = ["concrete", "concrete", "metal", "wood", "earth", "earth", "earth", "earth"]
const STEP_NAMES: PackedStringArray = ["run", "sprint", "land"]
## What a play is, for its pitch and level spread, its priority in the field's pool and how many of its cue may sound.
enum Kind { SHOT, MECHANISM, STEP, VAULT, ROPE, IMPACT, HIT, STEEL, INTERFACE, RADIO, FOLEY, CALL, PROP, RADIO_CALL }
## How far past the ears' distance a call's voice still carries, so the far edge of its ring is never cut off.
const CALL_SLACK := 1.0

var _cfg: SoundConfig = null
var _streams: Dictionary[StringName, Array] = {}
var _field: Array[AudioStreamPlayer3D] = []
var _own: Array[AudioStreamPlayer] = []
var _field_pool: VoicePool = null
var _own_pool: VoicePool = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The variant each cue played last (-1: none yet), so it never plays twice running.
var _last_variant: Dictionary[StringName, int] = {}
## By Kind: pitch spread (± share), level spread (± dB), priority among others' sounds and voices one cue may have.
var _pitch_spread: PackedFloat32Array = PackedFloat32Array()
var _level_spread: PackedFloat32Array = PackedFloat32Array()
var _priority: PackedInt32Array = PackedInt32Array()
var _cue_voices: PackedInt32Array = PackedInt32Array()
## By Kind: the distance (m) within which another's sound plays at full level.
var _unit_size: PackedFloat32Array = PackedFloat32Array()
var _steps: VoicePool.StartLimit = null
var _impacts: VoicePool.StartLimit = null
var _foleys: VoicePool.StartLimit = null
## Whose ears the view is through this tick (null: nobody's, so nothing is out of reach or muffled, and no call sounds).
var _listener: Character = null
var _ear: Vector3 = Vector3.ZERO
## Muffling through walls from the listener's eyes, through the level's WorldQuery.
var _occlusion: SoundOcclusion = null
## Cue names worked out once: by power source, by surface, by surface and pace.
var _shot: Dictionary[StringName, StringName] = {}
var _power: Dictionary[StringName, StringName] = {}
## By power source: its power part's level (SoundConfig.power_gains).
var _power_gain: Dictionary[StringName, float] = {}
var _dry: Dictionary[StringName, StringName] = {}
var _mag_out: Dictionary[StringName, StringName] = {}
var _mag_in: Dictionary[StringName, StringName] = {}
var _impact: Array[StringName] = []
## A BB in a bush's leaves (BBStep.IN_LEAVES), or brushing through an edge (BB_LEAVES).
var _leaves: StringName = &""
var _step: Array[StringName] = []
## A noisy prop's cue by NoiseConfig.Sound.
var _prop: Array[StringName] = []
var _body: BodyConfig = null
## The slowest landing that thuds (m/s; FootstepConfig.land_min_speed): a landing's level and pitch grow from it.
var _land_min: float = 0.0
## Kit rustle from the state, once per movement.
var _foley: FoleyTracker = FoleyTracker.new()
## The referee's whistle: its one voice, on Interface, and the blasts waiting for it.
var _whistle: AudioStreamPlayer = null
var _blasts: WhistleQueue = null
## Plays the ambience's night set (the playing preset's night flag, LightingConfig.night); set before `setup`.
var night: bool = false
## The map's ambience: a voice per bed, and its calls with the match they were last timed for.
var _beds: Array[AudioStreamPlayer] = []
var _calls: AmbientCalls = null
var _calls_match: int = -1
## The squad order outcome last heard (SquadOrders.Outcome.serial).
var _order_serial: int = 0
## Your ping heard (on_ping): the ping book's serial read up to, and when your last ping that piped was placed.
var _ping_serial: int = 0
var _ping_at: float = -INF
## A teammate's callout click (on_calls): its voices, unattenuated and panned at SoundConfig.radio_pan, the next one to
## use, and the call log read and the serial read up to.
var _radio: Array[AudioStreamPlayer3D] = []
var _radio_next: int = 0
var _call_log: CalloutLog = null
var _call_serial: int = 0


## Loads every cue `profiles` (the loadouts' sound profiles, ReplicaConfig.sound_profile) and the field need, makes the
## voices and starts the map's ambience (its beds; its calls are timed in play); replica sounds come from the eyes of a
## character shaped as `body`. A profile with no power part (the Cyber Pistol's) plays its shot alone. `query` and
## `map` are the level's (either may be null: no map plays the default ambience); `footsteps` says how soft a landing
## still thuds (null: the default).
func setup(cfg: SoundConfig, profiles: Array[StringName], body: BodyConfig, query: WorldQuery, map: MapData,
		footsteps: FootstepConfig = null) -> void:
	_cfg = cfg
	_body = body
	_land_min = footsteps.land_min_speed if footsteps != null else FootstepConfig.new().land_min_speed
	_kinds(cfg)
	_occlusion = SoundOcclusion.new(cfg, query)
	_steps = VoicePool.StartLimit.new(cfg.step_limit, cfg.step_window)
	_impacts = VoicePool.StartLimit.new(cfg.impact_limit, cfg.impact_window)
	_foleys = VoicePool.StartLimit.new(cfg.foley_limit, cfg.foley_window)
	_foley.lean_gap = cfg.foley_lean_gap
	_blasts = WhistleQueue.new(cfg)
	name = "Sound"
	for p in profiles:
		_shot[p] = _load("shot_%s" % p)
		var power_part := "power_%s" % p
		var has_part := ResourceLoader.exists("%s%s_1.wav" % [SoundConfig.CUE_DIR, power_part])
		_power[p] = _load(power_part) if has_part else &""
		_power_gain[p] = cfg.power_gains.get(p, cfg.power_gain)
		_dry[p] = _load("dryFire_%s" % p)
		_mag_out[p] = _load("magOut_%s" % p)
		_mag_in[p] = _load("magIn_%s" % p)
	for s in IMPACT_NAMES:
		_impact.append(_load("impact_%s" % s))
	_leaves = _load("impact_leaves")
	for s in SURFACE_NAMES:
		for k in STEP_NAMES:
			_step.append(_load("step_%s_%s" % [s, k]))
	for s in NoiseConfig.SOUND_NAMES:
		_prop.append(_load("prop_%s" % s))
	for cue: String in ["selector", "draw", "reloadRefused", "bodyHit", "hitTick", "hitMarker", "count_beep", "vault",
			"foley_holster", "magRattle", "rope_up", "rope_down", "steelRing", "radio_ack", "foley_crouch", "foley_stand",
			"foley_lean", "whistle_short", "whistle_long", "torchClick", "ping_pip", "magToss", "magCatch", "grenade_pin",
			"grenade_bounce", "smoke_pop", "flash_bang", "door_open", "door_shut"]:
		_load(cue)
	_set_muffle(cfg.muffled_cutoff_hz)
	for i in cfg.field_voices:
		var v := AudioStreamPlayer3D.new()
		v.unit_size = cfg.unit_size
		v.max_distance = cfg.max_distance
		v.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		v.bus = BUS_EFFECTS
		add_child(v)
		_field.append(v)
	for i in cfg.own_voices:
		var v := AudioStreamPlayer.new()
		v.bus = BUS_EFFECTS
		add_child(v)
		_own.append(v)
	_field_pool = VoicePool.new(_field)
	_own_pool = VoicePool.new(_own)
	for i in maxi(1, cfg.radio_voices):
		var v := AudioStreamPlayer3D.new()
		v.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		v.max_distance = 0.0 # no limit: a teammate's radio is heard wherever they are
		v.panning_strength = cfg.radio_pan
		v.bus = BUS_INTERFACE
		add_child(v)
		_radio.append(v)
	_whistle = AudioStreamPlayer.new()
	_whistle.bus = BUS_INTERFACE
	_whistle.volume_db = linear_to_db(cfg.whistle_gain)
	add_child(_whistle)
	_start_ambience(map.ambience if map != null else AmbienceConfig.DEFAULT_ID)


## Plays the tick's events in `state`; `player_id` is the one heard as yourself, `listener` the character the view is
## through (whose ears decide what is in reach; null: nobody's).
func on_tick(state: GameState, player_id: int, listener: Character) -> void:
	_listener = listener
	if listener != null:
		_ear = listener.eye(_body)
	_occlusion.begin_tick(state.characters, listener, _ear)
	var now := state.time
	var events := state.events
	for i in events.count:
		var e := events.items[i]
		var own := e.actor == player_id
		match e.kind:
			GameEvent.Kind.SHOT:
				var p := _power_of(state, e.actor, e.slot)
				var muffled := _muffled(state, e.actor, e.slot)
				var shooter := state.character(e.actor)
				var reach := _cfg.shot_reach * (MinimapHearing.heard_scale(shooter, e.slot) if shooter != null else 1.0)
				_play(_shot.get(p, &""), e.position, own, _cfg.shot_gain * (_cfg.muffled_gain if muffled else 1.0),
						Kind.SHOT, BUS_MUFFLED if muffled else BUS_EFFECTS, 1.0, reach, shooter)
				_play(_power.get(p, &""), e.position, own, _power_gain.get(p, _cfg.power_gain), Kind.SHOT, BUS_POWER, 1.0,
						reach, shooter)
			GameEvent.Kind.DRY_FIRE:
				_mechanism(_dry.get(_power_of(state, e.actor, e.slot), &""), state, e, own)
			GameEvent.Kind.RELOAD_START:
				_mechanism(_mag_out.get(_power_of(state, e.actor, e.slot), &""), state, e, own)
			GameEvent.Kind.RELOAD_END:
				_mechanism(_mag_in.get(_power_of(state, e.actor, e.slot), &""), state, e, own)
			GameEvent.Kind.RELOAD_REFUSED:
				_mechanism(&"reloadRefused", state, e, own)
			GameEvent.Kind.DRAW:
				_mechanism(&"draw", state, e, own)
			GameEvent.Kind.HOLSTER:
				_mechanism(&"foley_holster", state, e, own)
			GameEvent.Kind.FIRE_MODE, GameEvent.Kind.HOP_UP:
				_mechanism(&"selector", state, e, own)
			GameEvent.Kind.TORCH:
				_mechanism(&"torchClick", state, e, own)
			# The magazine hand-off (MH3): your ask taken is a radio's double click in your ear; a toss is heard from
			# its thrower, a catch from its catcher (the event's actor is the thrower).
			GameEvent.Kind.MAG_ASK when own:
				_play(&"radio_ack", Vector3.ZERO, true, _cfg.radio_ack_gain, Kind.RADIO, BUS_INTERFACE)
			GameEvent.Kind.MAG_TOSS:
				_mechanism(&"magToss", state, e, own)
			GameEvent.Kind.MAG_CATCH:
				var catcher := state.character(e.target)
				_play(&"magCatch", catcher.eye(_body) if catcher != null else e.position, e.target == player_id,
						_cfg.mechanism_gain, Kind.MECHANISM, BUS_EFFECTS, 1.0, 0.0, catcher)
			GameEvent.Kind.GRENADE_PIN:
				_mechanism(&"grenade_pin", state, e, own)
			GameEvent.Kind.GRENADE_THROW:
				_mechanism(&"magToss", state, e, own)
			GameEvent.Kind.GRENADE_BOUNCE:
				var hard := minf(1.0, e.reach / maxf(_cfg.bounce_full_speed, 0.001))
				_play(&"grenade_bounce", e.position, false, _cfg.bounce_gain * hard, Kind.PROP, BUS_EFFECTS, 1.0,
						_cfg.prop_reach, null, true)
			GameEvent.Kind.SMOKE_POP:
				_play(&"smoke_pop", e.position, false, _cfg.smoke_pop_gain, Kind.PROP, BUS_EFFECTS, 1.0, _cfg.prop_reach,
						null, true)
			GameEvent.Kind.FLASH_BANG:
				_play(&"flash_bang", e.position, false, _cfg.bang_gain, Kind.SHOT, BUS_EFFECTS, 1.0, _cfg.bang_reach, null,
						true)
			GameEvent.Kind.BB_IMPACT:
				if e.target < 0:
					if _in_reach(e.position, _cfg.max_distance) and _impacts.take(now):
						var s := clampi(e.value2, 0, _impact.size() - 1)
						var cue := _leaves if e.value == BBStep.IN_LEAVES else _impact[s]
						_play(cue, e.position, false, _cfg.impact_gain, Kind.IMPACT, BUS_EFFECTS, 1.0, 0.0, null, true)
				else:
					_play(&"bodyHit", e.position, e.target == player_id, _cfg.body_hit_gain, Kind.HIT, BUS_EFFECTS, 1.0,
							0.0, state.character(e.target))
			GameEvent.Kind.BB_LEAVES:
				if _in_reach(e.position, _cfg.max_distance) and _impacts.take(now):
					_play(_leaves, e.position, false, _cfg.leaf_brush_gain, Kind.IMPACT, BUS_EFFECTS, 1.0, 0.0, null, true)
			GameEvent.Kind.RICOCHET_TICK:
				_play(&"bodyHit", e.position, e.target == player_id, _cfg.body_hit_gain, Kind.HIT, BUS_EFFECTS, 1.0,
						0.0, state.character(e.target))
			# Your own hit's tick is the cue that must be read: on Interface, clear of the field's dip and muffling.
			GameEvent.Kind.CHARACTER_HIT when e.target == player_id:
				_play(&"hitTick", e.position, true, _cfg.hit_tick_gain, Kind.INTERFACE, BUS_INTERFACE)
			GameEvent.Kind.CHARACTER_HIT:
				_play(&"hitTick", e.position, false, _cfg.hit_tick_gain, Kind.HIT, BUS_EFFECTS, 1.0, 0.0,
						state.character(e.target))
				if own and e.target != player_id:
					_play(&"hitMarker", e.position, true, _cfg.hit_marker_gain, Kind.INTERFACE, BUS_INTERFACE)
			GameEvent.Kind.FOOTSTEP:
				var c := state.character(e.actor)
				var at := c.position if c != null else e.position
				var reach := _cfg.step_reach * e.carry
				if not own and not (_in_reach(at, reach) and _steps.take(now)):
					continue
				var gain := (_cfg.own_step_gain if own else _cfg.step_gain) * e.carry
				var pitch := 1.0
				var cue := &"magRattle"
				if e.value != GameEvent.Footstep.RATTLE:
					var surface := clampi(e.value2, 0, SURFACE_NAMES.size() - 1)
					cue = _step[surface * STEP_NAMES.size() + clampi(e.value, 0, STEP_NAMES.size() - 1)]
				var speed := e.direction.length()
				if e.value == GameEvent.Footstep.LAND:
					var hard := land_hardness(_cfg, _land_min, speed)
					gain = (_cfg.own_land_gain if own else _cfg.step_gain) * lerpf(1.0, _cfg.land_hard_gain, hard) * e.carry
					pitch = lerpf(1.0, _cfg.land_hard_pitch, hard)
				_play(cue, at, own, gain, Kind.STEP, BUS_FOOTSTEPS, pitch, reach, c)
				# A hard landing rustles the kit under its thud.
				if e.value == GameEvent.Footstep.LAND and speed >= _cfg.hard_land_speed and c != null:
					_kit(&"foley_crouch", c, own, now)
			GameEvent.Kind.VAULT:
				var gain := _cfg.own_vault_gain if own else _cfg.vault_gain
				_play(&"vault", e.position, own, gain, Kind.VAULT, BUS_FOOTSTEPS, 1.0, 0.0, state.character(e.actor))
			# From the prop where it was hit, yours too, muffled by the walls between it and your ears.
			GameEvent.Kind.PROP_KNOCK:
				_play(_prop[clampi(e.value, 0, _prop.size() - 1)], e.position, false, _cfg.prop_gain, Kind.PROP,
						BUS_EFFECTS, 1.0, _cfg.prop_reach, null, true)
			# A door opening or shutting (DO1): from the door, yours too, muffled by the walls between it and your ears.
			GameEvent.Kind.DOOR:
				_play(&"door_shut" if e.value == 1 else &"door_open", e.position, false, _cfg.door_gain, Kind.PROP,
						BUS_EFFECTS, 1.0, _cfg.door_reach, null, true)
			GameEvent.Kind.FLAG_ROPE:
				_play(&"rope_up" if e.value == 1 else &"rope_down", e.position, false, _cfg.rope_gain, Kind.ROPE,
						BUS_EFFECTS)
			GameEvent.Kind.TARGET_HIT:
				if e.value == RangeTarget.Kind.STEEL:
					_play(&"steelRing", e.position, false, _cfg.steel_ring_gain, Kind.STEEL, BUS_EFFECTS, 1.0,
							_cfg.target_reach)
				else:
					_play(_impact[RayHit.Surface.WOOD], e.position, false, _cfg.impact_gain, Kind.IMPACT, BUS_EFFECTS,
							1.0, _cfg.target_reach)
				if own:
					_play(&"hitMarker", e.position, true, _cfg.hit_marker_gain, Kind.INTERFACE, BUS_INTERFACE)
			# Time is up: the referee's long blast.
			GameEvent.Kind.CHALLENGE when own and e.value == RangeChallenge.Cue.TIME:
				_blasts.round_over(now)
			GameEvent.Kind.CHALLENGE when own:
				var pitch := _cfg.go_pitch if e.value == RangeChallenge.Cue.GO else 1.0
				_play(&"count_beep", Vector3.ZERO, true, _cfg.beep_gain, Kind.INTERFACE, BUS_INTERFACE, pitch)
			# Practice has no rounds to start: no whistle on the range. A new round's whistle cuts the last short.
			GameEvent.Kind.ROUND_START when not state.round_state.practice:
				_whistle.stop()
				_blasts.round_start(now)
			GameEvent.Kind.OVERTIME:
				_blasts.overtime(now)
			GameEvent.Kind.ROUND_OVER:
				_blasts.round_over(now)
			GameEvent.Kind.MATCH_OVER:
				_blasts.match_over(now)
	_blow_due(now)
	_rustle(state, player_id, now)
	_call(state, now)


## The radio click, in your ear only, when the squad order last recorded in `outcome` (since the last call) is one of
## `player_id`'s that a teammate took; a refused or cancelled order, or one nobody was there to take, plays nothing.
func on_order(outcome: SquadOrders.Outcome, player_id: int) -> void:
	if outcome.serial == _order_serial:
		return
	_order_serial = outcome.serial
	if order_taken(outcome, player_id):
		_play(&"radio_ack", Vector3.ZERO, true, _cfg.radio_ack_gain, Kind.RADIO, BUS_INTERFACE)


## The pip, in your ear only, when `player_id`'s own ping in `book` (Pings) was placed since the last call (the browser
## game's pingPlaced): a press that pings nothing, and a teammate's mark, play nothing.
func on_ping(book: Pings, player_id: int) -> void:
	if book == null or book.placed == _ping_serial:
		return
	_ping_serial = book.placed
	var p := book.of(player_id)
	if p == null or p.marked or p.at == -INF or p.at == _ping_at:
		return
	_ping_at = p.at
	_play(&"ping_pip", Vector3.ZERO, true, _cfg.ping_pip_gain, Kind.INTERFACE, BUS_INTERFACE)


## The calls said in `said` (CalloutLog) since the last look, each as its radio click (the browser game's radioCall): a
## teammate's (on `team`) in your ear, panned toward where they stand; an enemy's from where they stand, only within
## enemy_radio_reach of the listener's ears and muffled through walls. While `on` is false (Settings › HUD › Callouts
## off) the calls are passed over, never played late. Call after on_tick, which places the ears.
func on_calls(said: CalloutLog, state: GameState, team: int, on: bool) -> void:
	if said != _call_log or _call_serial > said.total:
		_call_log = said
		_call_serial = said.oldest()
	var from := maxi(_call_serial, said.oldest())
	_call_serial = said.total
	if not on:
		return
	for serial in range(from, said.total):
		var call := said.entry(serial)
		var c := state.character(call.speaker_id)
		if c == null:
			continue
		if call.team == team:
			_radio_call(c)
		else:
			_play(&"radio_ack", c.eye(_body), false, _cfg.radio_call_enemy_gain, Kind.RADIO_CALL, BUS_EFFECTS, 1.0,
					_cfg.enemy_radio_reach, c)


## Stops every callout's click sounding now (Settings › HUD › Callouts switched off); an order's click plays on.
func stop_calls() -> void:
	for v in _radio:
		v.stop()
	if not _streams.has(&"radio_ack"):
		return
	var clicks: Array = _streams[&"radio_ack"]
	for v in _field:
		if v.playing and clicks.has(v.stream):
			v.stop()


## The teammate's callout voices (for tests).
func radio_voices() -> Array[AudioStreamPlayer3D]:
	return _radio


## Whether `outcome` is an order from `player_id` that a teammate took (the browser game's orderHeard: a result that
## isn't none).
static func order_taken(outcome: SquadOrders.Outcome, player_id: int) -> bool:
	return outcome.giver == player_id and outcome.notice == SquadOrders.Notice.NONE \
			and outcome.order != SquadOrder.Kind.NONE


## Stops every voice on the way out, so no playback outlives the match (and its stream with it).
func _exit_tree() -> void:
	for v in _field:
		v.stop()
	for v in _own:
		v.stop()
	for v in _beds:
		v.stop()
	for v in _radio:
		v.stop()
	if _whistle != null:
		_whistle.stop()


## A teammate `c`'s callout click on the next radio voice: from where they stand, unattenuated, so it is panned toward
## them by radio_pan and no further.
func _radio_call(c: Character) -> void:
	var variants: Array = _streams[&"radio_ack"]
	if variants.is_empty() or _radio.is_empty():
		return
	var v := _radio[_radio_next]
	_radio_next = (_radio_next + 1) % _radio.size()
	v.stream = variants[_variant(&"radio_ack", variants.size())]
	v.volume_db = linear_to_db(_cfg.radio_call_gain)
	v.pitch_scale = 1.0 + _rng.randf_range(-_cfg.radio_call_pitch, _cfg.radio_call_pitch)
	v.global_position = c.eye(_body)
	v.play()


## How hard a landing at `speed` (m/s down) came down, 0 at `land_min` (the softest that thuds) .. 1 at `cfg`'s
## hard_land_speed and over: its level and pitch go from a step's to land_hard_gain and land_hard_pitch times it.
static func land_hardness(cfg: SoundConfig, land_min: float, speed: float) -> float:
	if cfg.hard_land_speed <= land_min:
		return 1.0 if speed >= cfg.hard_land_speed else 0.0
	return clampf((speed - land_min) / (cfg.hard_land_speed - land_min), 0.0, 1.0)


## The whistle's blasts due at `now` (s), on its one voice (a later one cuts an earlier one still sounding).
func _blow_due(now: float) -> void:
	var blast := _blasts.pop_due(now)
	while blast != WhistleQueue.Blast.NONE:
		var cue := &"whistle_long" if blast == WhistleQueue.Blast.LONG else &"whistle_short"
		var variants: Array = _streams[cue]
		if not variants.is_empty():
			_whistle.stream = variants[_variant(cue, variants.size())]
			_whistle.play()
		blast = _blasts.pop_due(now)


## Kit rustle for every crouch, stand and lean that started this tick (anyone in play; `player_id` heard as yourself).
func _rustle(state: GameState, player_id: int, now: float) -> void:
	_foley.update(state.characters, now)
	for i in state.characters.size():
		var moves := _foley.moves[i]
		if moves == FoleyTracker.Move.NONE:
			continue
		var c := state.characters[i]
		var own := c.id == player_id
		if (moves & FoleyTracker.Move.CROUCH) != 0:
			_kit(&"foley_crouch", c, own, now)
		if (moves & FoleyTracker.Move.STAND) != 0:
			_kit(&"foley_stand", c, own, now)
		if (moves & FoleyTracker.Move.LEAN) != 0:
			_kit(&"foley_lean", c, own, now)


## `c`'s kit rustling as `cue`: yours plain at own_foley_gain; others' from their eyes, within foley_reach and the
## rustle's start limit, muffled through walls.
func _kit(cue: StringName, c: Character, own: bool, now: float) -> void:
	if own:
		_play(cue, Vector3.ZERO, true, _cfg.own_foley_gain, Kind.FOLEY, BUS_FOOTSTEPS)
		return
	var at := c.eye(_body)
	if _in_reach(at, _cfg.foley_reach) and _foleys.take(now):
		_play(cue, at, false, _cfg.foley_gain, Kind.FOLEY, BUS_FOOTSTEPS, 1.0, _cfg.foley_reach, c)


## The ambience's calls due at `now` (s), round the listener's ears at each call's level and pitch spread, timed afresh
## for each match from its seed. None without a listener.
func _call(state: GameState, now: float) -> void:
	if state.match_number != _calls_match:
		_calls_match = state.match_number
		_calls.begin(state.match_seed, state.match_number, now)
	if _listener == null:
		return
	for i in _calls.size():
		if not _calls.due(i, now, _ear):
			continue
		var kind := _calls.calls[i]
		var at := _calls.at
		var pitch := 1.0 + _rng.randf_range(-kind.pitch, kind.pitch)
		var far := maxf(_cfg.max_distance, _ear.distance_to(at) + CALL_SLACK)
		_play(kind.cue, at, false, kind.level * _cfg.ambience_gain, Kind.CALL, BUS_AMBIENCE, pitch, far)


func _mechanism(cue: StringName, state: GameState, e: GameEvent, own: bool) -> void:
	var c := state.character(e.actor)
	var at := c.eye(_body) if c != null else e.position
	_play(cue, at, own, _cfg.mechanism_gain, Kind.MECHANISM, BUS_EFFECTS, 1.0, 0.0, c)


## The sound profile of `actor`'s replica in `slot` (its power's, or its own).
func _power_of(state: GameState, actor: int, slot: int) -> StringName:
	var c := state.character(actor)
	if c == null or slot < 0 or slot >= c.armament.replicas.size():
		return &""
	return c.armament.replicas[slot].sound_profile()


## Whether `actor`'s replica in `slot` is silenced.
func _muffled(state: GameState, actor: int, slot: int) -> bool:
	var c := state.character(actor)
	return c != null and slot >= 0 and slot < c.armament.replicas.size() and c.armament.replicas[slot].muffled


## The Muffled bus's low-pass cutoff (Hz), if the bus layout has it.
static func _set_muffle(cutoff_hz: float) -> void:
	var bus := AudioServer.get_bus_index(BUS_MUFFLED)
	if bus < 0 or AudioServer.get_bus_effect_count(bus) == 0:
		push_warning("SimAudio: no %s bus with a low-pass filter" % BUS_MUFFLED)
		return
	var filter := AudioServer.get_bus_effect(bus, 0) as AudioEffectFilter
	if filter != null:
		filter.cutoff_hz = cutoff_hz


## Plays a variant of `cue` at `pitch`, spread by its `kind`: plain if `own`, else from `at`, heard as far as `reach`
## (m; SoundConfig.max_distance when not positive) and not played beyond it, muffled by the walls between the listener
## and `source` (the character making it), or the surface `at` when `impact`. A full pool drops it.
func _play(cue: StringName, at: Vector3, own: bool, gain: float, kind: Kind, bus: StringName, pitch: float = 1.0,
		reach: float = 0.0, source: Character = null, impact: bool = false) -> void:
	if not _streams.has(cue):
		return
	var variants: Array = _streams[cue]
	if variants.is_empty():
		return
	var far := reach if reach > 0.0 else _cfg.max_distance
	if not own and not _in_reach(at, far):
		return
	var pool := _own_pool if own else _field_pool
	var i := pool.acquire(cue, VoicePool.Priority.OWN if own else _priority[kind], _cue_voices[kind])
	if i < 0:
		return
	var stream: AudioStream = variants[_variant(cue, variants.size())]
	var scale := pitch + _rng.randf_range(-_pitch_spread[kind], _pitch_spread[kind])
	var db := linear_to_db(gain) + _rng.randf_range(-_level_spread[kind], _level_spread[kind])
	if own:
		var v := _own[i]
		v.stream = stream
		v.volume_db = db
		v.pitch_scale = scale
		v.bus = bus
		v.play()
	else:
		# Rays only for a sound that has its voice.
		var share := _occlusion.impact_share(at) if impact else _occlusion.share_of(source)
		var v := _field[i]
		v.stream = stream
		var open := share <= 0.0 # the common case: nothing in the way, so no bus or level to work out
		v.volume_db = db if open else db + linear_to_db(SoundOcclusion.level_for(bus, share, _cfg))
		v.pitch_scale = scale
		v.unit_size = _unit_size[kind]
		# A shot's cap is its own level, so a bot's shot beside you is as loud as yours; the rest keep the field's.
		v.max_db = v.volume_db if kind == Kind.SHOT else _cfg.field_max_db
		v.max_distance = far
		v.bus = bus if open else SoundOcclusion.bus_for(bus, share, _cfg)
		v.global_position = at
		v.play()


## A variant of `cue`'s `count`, never the one it played last.
func _variant(cue: StringName, count: int) -> int:
	var last: int = _last_variant[cue]
	var k := 0
	if count > 1 and last < 0:
		k = _rng.randi_range(0, count - 1)
	elif count > 1:
		k = _rng.randi_range(0, count - 2)
		if k >= last:
			k += 1
	_last_variant[cue] = k
	return k


## Whether `at` is within `reach` (m) of the listener's ears (always, with no listener).
func _in_reach(at: Vector3, reach: float) -> bool:
	return _listener == null or at.distance_squared_to(_ear) <= reach * reach


## Each Kind's spreads, priority among others' sounds and voices per cue, from `cfg`.
func _kinds(cfg: SoundConfig) -> void:
	var n := Kind.size()
	_pitch_spread.resize(n)
	_level_spread.resize(n)
	_priority.resize(n)
	_cue_voices.resize(n)
	_unit_size.resize(n)
	var pitch: Dictionary[Kind, float] = {
		Kind.SHOT: cfg.shot_pitch, Kind.MECHANISM: cfg.mechanism_pitch, Kind.STEP: cfg.step_pitch,
		Kind.VAULT: cfg.vault_pitch, Kind.ROPE: cfg.rope_pitch, Kind.IMPACT: cfg.impact_pitch, Kind.HIT: 0.0,
		Kind.STEEL: cfg.steel_ring_pitch, Kind.INTERFACE: 0.0, Kind.RADIO: cfg.radio_ack_pitch,
		Kind.FOLEY: cfg.foley_pitch, Kind.CALL: 0.0, # a call's spread is its own (AmbienceCall.pitch)
		Kind.PROP: cfg.prop_pitch, Kind.RADIO_CALL: cfg.radio_call_pitch,
	}
	var level: Dictionary[Kind, float] = {
		Kind.SHOT: cfg.shot_spread_db, Kind.MECHANISM: cfg.mechanism_spread_db, Kind.STEP: cfg.step_spread_db,
		Kind.VAULT: cfg.vault_spread_db, Kind.ROPE: cfg.rope_spread_db, Kind.IMPACT: cfg.impact_spread_db,
		Kind.HIT: cfg.hit_spread_db, Kind.STEEL: cfg.steel_ring_spread_db, Kind.INTERFACE: 0.0, Kind.RADIO: 0.0,
		Kind.FOLEY: cfg.foley_spread_db, Kind.CALL: 0.0, Kind.PROP: cfg.prop_spread_db, Kind.RADIO_CALL: 0.0,
	}
	for k: Kind in pitch:
		_pitch_spread[k] = pitch[k]
		_level_spread[k] = level[k]
		_priority[k] = VoicePool.Priority.FIELD
		_cue_voices[k] = cfg.cue_voices
		_unit_size[k] = cfg.unit_size
	_priority[Kind.SHOT] = VoicePool.Priority.SHOT
	_priority[Kind.HIT] = VoicePool.Priority.SHOT
	_priority[Kind.INTERFACE] = VoicePool.Priority.OWN
	_priority[Kind.RADIO] = VoicePool.Priority.OWN
	_priority[Kind.CALL] = VoicePool.Priority.CALL
	_cue_voices[Kind.SHOT] = cfg.shot_cue_voices
	_unit_size[Kind.SHOT] = cfg.shot_unit_size


## Loads `<cue>_1.wav` .. `_<variants>.wav` (those that exist) under the cue's name, which it returns.
func _load(cue: String) -> StringName:
	var key := StringName(cue)
	if _streams.has(key):
		return key
	var list: Array = []
	for n in range(1, _cfg.variants + 1):
		var path := "%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n]
		if ResourceLoader.exists(path):
			list.append(load(path))
	if list.is_empty():
		push_warning("SimAudio: no sound for cue %s" % cue)
	_streams[key] = list
	_last_variant[key] = -1
	return key


## Starts ambience `id`'s beds by day or by `night`, each looping on the Ambience bus at its gain times its loop's
## stored peak, and makes its calls (timed in play). One copy of each bed, unpanned:
## a plain voice has no pan for the browser's two copies spread `width` apart.
func _start_ambience(id: StringName) -> void:
	var ambience := _cfg.ambiences.set_for(id, night)
	var peaks: Variant = JSON.parse_string(FileAccess.get_file_as_string(SoundConfig.PEAKS_PATH))
	for bed in ambience.beds:
		var path := "%s%s.wav" % [SoundConfig.LOOP_DIR, bed.loop]
		if not ResourceLoader.exists(path):
			push_warning("SimAudio: no ambience loop %s" % path)
			continue
		var peak := 1.0
		if peaks is Dictionary:
			peak = float((peaks as Dictionary).get(String(bed.loop), 1.0))
		var v := AudioStreamPlayer.new()
		v.stream = load(path)
		v.bus = BUS_AMBIENCE
		v.volume_db = linear_to_db(bed.gain * peak * _cfg.ambience_gain)
		add_child(v)
		v.play()
		_beds.append(v)
	_calls = AmbientCalls.new(ambience.calls)
	for call in ambience.calls:
		_load(String(call.cue))

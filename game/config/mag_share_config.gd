class_name MagShareConfig
extends Resource
## The magazine hand-off's rules (MH1; the browser game's config/magShare.ts, MG1): who can ask whom, a toss's reach and
## flight, and how long an ask stands. The simulation keeps them (MagShare); how bots bring one is BotConfig's (MH2).
## The same for every character at every difficulty. Part of SimTuning (sim_tuning.tres).

## An ask reaches the nearest teammate within this (m, across the ground) with a magazine to spare.
@export var ask_range: float = 30.0
## A magazine is tossed this far at most (m, eye to chest), with nothing of the level in between.
@export var toss_range: float = 6.0
## A toss's flight: this long, plus this much a metre of toss (s).
@export var flight_base: float = 0.3
@export var flight_per_metre: float = 0.05
## Its arc over the straight line from hand to chest at the middle (m): this much a metre of toss, never more than
## arc_max. A toss whose arc meets the level on the way (the catcher moved behind a wall meanwhile) is lost there.
@export var arc_per_metre: float = 0.1
@export var arc_max: float = 0.6
## That path is checked against the level as this many straight pieces, the same ones before a toss and in flight.
@export var path_pieces: int = 4
## The catch is this far under the catcher's eyes (m), about the chest; the toss leaves the hand this far under the
## thrower's (where presentation starts drawing it).
@export var catch_drop: float = 0.4
@export var throw_drop: float = 0.3
## Low on BBs: the spares for the replica in hand hold fewer BBs than this many full magazines of it.
@export var low_mags: int = 1
## An ask goes only to a teammate who keeps this many full magazines' worth of the replica it fights with after giving
## (a spare of a replica it is not holding it gives freely).
@export var keep_mags: int = 1
## An ask stands this long (s) unless a magazine lands first; then it lapses.
@export var ask_time: float = 15.0
## A character may ask again this long (s) after its last ask ended (a magazine caught or lost, or the ask lapsed): the
## player sooner than a bot.
@export var player_ask_gap: float = 4.0
@export var bot_ask_gap: float = 20.0
## Most magazines in the air at once (GameState.mag_tosses, made once with the state).
@export var max_tosses: int = 6

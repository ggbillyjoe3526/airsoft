class_name CalloutConfig
extends Resource
## The bots' callouts' fixed numbers (the browser game's config/callouts.ts CALLOUTS, CL1): how a call is read off what a
## bot does, how many a team holds back and how many said calls are kept. What they say, how often and the pace are
## data/callouts.md (CalloutsFile), the owner's to edit. Part of BotConfig (bot_tuning.tres).

## An enemy counts as in a bot's sight while it saw them this recently (s): its last sight check, give or take a tick.
@export var in_sight: float = 0.1
## Reloading is called only with an enemy seen or heard this recently (s).
@export var reload_threat: float = 4.0
## Last one names where they are only when the team saw them this recently (s).
@export var last_one_seen: float = 3.0
## Calls a team holds back at once, waiting for its turn to speak (callouts.md › Pace); the least urgent go first.
@export var queue: int = 3
## Said calls kept for the presentation to read (CalloutLog), the oldest overwritten: at most two a tick are said.
@export var log_size: int = 16
## A Go round ask's spot (BQ2) is the nearest walkable floor within this (m) of the point to the enemy's side.
@export var ask_snap: float = 4.0
## The point beside the enemy is lifted this (m) above its feet before snapping, so it finds the floor it stands on.
@export var ask_lift: float = 1.0

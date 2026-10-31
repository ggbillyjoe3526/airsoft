class_name PingConfig
extends Resource
## Pings (PN1; the browser game's config/pings.ts, PG1): marking where you look for your team. The simulation turns a
## press into a PING event within `reach`; the bots' controller resolves it (Pings) into a spot or a contact
## and keeps it in its ping book. How long a bot teammate keeps a ping in mind is BotConfig.ping_memory; how often a
## teammate's sighting call marks the enemy is data/callouts.md › Marks. Part of SimTuning (sim_tuning.tres).

## How far your view reaches for a ping (m): a spot further off, or the sky, pings nothing.
@export var reach: float = 120.0
## An enemy is the one pinged when the view passes within this angle (degrees) of their chest or head, or within
## `enemy_reach` metres of it up close, nearer than whatever the view meets behind them.
@export var enemy_cone_deg: float = 2.5
@export var enemy_reach: float = 0.5
## The floor spot your teammates go to or watch: the nearest walkable one within this many metres of the ping.
@export var spot_snap: float = 3.0
## Off a wall or a crate, the spot is looked for this far back towards you (m), in front of it rather than inside.
@export var back_off: float = 0.4
## A ping with your view marks only floor it can see (owner, 2026-10-31): the spot must be in a clear line from where
## the view met, judged sight_lift (m) above its floor; if a wall or a crate is between, it is looked for again further
## back towards you, spot_snap at a time.
@export var sight_lift: float = 1.0
## A ping placed on the full-screen map (FM1) marks the nearest walkable floor within map_snap (m) of the point picked,
## judged map_lift (m) above the floor of the storey the map shows.
@export var map_snap: float = 4.0
@export var map_lift: float = 1.0
## A ping is kept this long (s of match time) in the ping book, which the HUD reads.
@export var lifetime: float = 8.0
## One character's pings are at least this far apart (s): a double click is one ping.
@export var min_gap: float = 0.25

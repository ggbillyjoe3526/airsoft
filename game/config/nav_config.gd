class_name NavConfig
extends Resource
## The nav grid bots and walk-offs route on (the browser game's config/nav.ts). The body's numbers come from BodyConfig:
## its radius sets the clearance, its height the headroom, and its max_step (the browser's maxWalkableLedge) both the
## tallest block walked onto and the largest floor step between neighbouring cells.

## Cell size (m): fine enough that ~1 m door gaps keep a walkable lane down the middle.
@export var cell: float = 0.2
## Kept from blocks and drops beyond the body's radius (m), so routes don't scrape walls and corners.
@export var clearance_margin: float = 0.06
## Route ends off the grid (inside a wall's clearance, say) snap to the nearest walkable cell within this (m).
@export var snap: float = 2.0
## A route end on a raised floor's lip snaps to that floor, not to one more than this share of a body's height below it
## (G11: a body on the Depot dock's lip, its middle past the edge, snapped to the road and walked off the dock). Half
## (0.9 m): the dock's 1.2 m drop counts; a stair tread or a ramp's next cell does not.
@export var snap_drop_share: float = 0.5
## How far above a point (m) a floor still counts as the one under it: less than any storey, more than a jump lifts the
## feet off the floor below.
@export var pick_above: float = 0.5
## Lines are walked in samples this share of a cell apart, so a sample never skips a cell (at most half a cell).
@export var line_sample_share: float = 0.5
## How much more the route search trusts its straight-line estimate than the steps it has taken (weighted A*: each
## point's weight is 1 / this). 1 finds the shortest routes; 1.5 finds smoothed routes 3 % longer on average (13 % at
## worst) about six times faster (Depot, cross-map, measured 2026-10-18: 4.2 ms a search down to 0.7 ms).
@export var search_greed: float = 1.5
## Points random_walkable_near tries before it gives up and returns the point it was asked about.
@export var hunt_tries: int = 8
## Route searches a tick, the bots' and the walk-offs' together (the browser's NAV.searchBudget, 8,000 node expansions,
## about 2 to 2.6 ms there). AStar3D runs a search whole and can't count or pause its expansions, so the budget counts
## searches: one on Woodland costs about the browser's budget (mean 1.8 to 4.0 ms, WL1). A walk-off due takes the
## tick's first; a search over the budget waits for the next tick. At 6v6 on the old wood no bot waited 1 s (WL2).
@export var search_budget: int = 1


## The distance a walkable cell's centre keeps from every block and drop (m): the body's radius plus the margin.
func clearance(body: BodyConfig) -> float:
	return body.radius + clearance_margin


## How far round each point of a route's straight leg the cells must be walkable too (m, browser audit AI-12): a walkable
## cell's centre keeps the clearance, but a point inside it can be half a cell's diagonal nearer a corner, so a leg
## probed this far out keeps at least the body's radius from every block.
func leg_probe(body: BodyConfig) -> float:
	return body.radius + cell * sqrt(2.0) * 0.5 - clearance(body)

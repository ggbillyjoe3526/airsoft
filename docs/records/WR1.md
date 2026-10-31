# WR1 · Woodland rebuilt as the open wood of concept 3

**Review:** critic Accept 8/8 (attempt 2) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-10-31 | 1 | thread | targeted tests pass | Retry 6/8 | `settle()` swapped its loop variables; stale docs |
| 2026-10-31 | 2 | thread | see Checks | Accept 8/8 | – |

## Goal

The owner's approval of concept 3 (2026-10-31 13:18: "Perfect, go ahead and add this to the game with CC0 dressing.
Give me screenshots when it's done and I will playtest it."), first of four pull requests: WR1 the map, CR1 a crouched
body short enough for the tunnels, WR2 doors, two flags and 3:00 rounds, WR3 the CC0 dress. WR1 is the wood itself:
176 x 120 m of gently sloping ground with a dry stream down the middle, three lanes (Ridge, Clearing, road), sparse
cover, enterable huts, ferns and bushes that hide players, day by default and night by the Time of day row, bots seeing
60 m, 5v5 or 6v6.

## Approach

- `tools/woodland/` (new): the concept's `layout.py` (pieces, roofs, decks, tunnels, thickets, foliage, lights, areas,
  lanes) and `world.py` (the 0.5 m height field: slopes, the Ridge, the stream bed cut below its lower bank, slides,
  mounds), with `check.py` (the concept's build checker, 0 problems) and `analyze.py` (run times and lines).
  `build_map.py` (new) writes `data/maps/woodland.json` from them; change the scripts, never the JSON.
  `sightlines.py` (new) lists the longest standing lines across the built file.
- The game's blocks are axis-aligned, so every piece is squared to the nearest quarter turn and the stream runs north
  to south under both crossings (the North bridge's deck and the road over the culvert), level with the ground at
  their ends. Walls are split into parts of 4 m at most; windows get a sill and a lintel; tunnels (the Crawl box in
  plywood, the Badger run in logs, the culvert's 1.6 m pipe) are cut through their mounds with a roof and walls in
  1 m steps. `settle()` resolves every clash the field check would refuse: a tree in a block or thicket is left out
  (440 trees stand), otherwise the thinner overlap gives way, never a deck or the stair.
- 947 blocks (thicket 197, tree 440, fence 110, plywood 90, log 72, crate 17, tyre 12, wall 4, floor 3, ramp 1, truck
  1), 99 foliage (fern beds as 1 m bushes 1.2 m high, which hide a crouched body; bushes 1.7 m, which hide a standing
  one), 11 night lights (three fires, eight lanterns), 244 area boxes (each concept area rasterised on 2 m, and dead
  space named after the nearest area so every walkable spot is in one), three lanes, six spawns and dead-zone spots an
  end. `night` is false: day first, night second.
- `MapStyle`: tyre (wood's sound), truck (metal) and thicket (leaves) kinds, coloured off both team hues. The forest
  beyond the fence is 1800 cones, about what fits between the bigger field's fence and the ground's edge.
- Bots' cover (`BotCover.floor_blocks`): a piece sunk into the floor by up to `low_cover_floor_sink` (0.4 m) now
  stands on it, as one within `low_cover_floor_gap` over it always did. Every Woodland piece is sunk 0.3 m so no gap
  shows under its low side on a slope, so bots found 7 low and 7 tall cover blocks there; now 47 and 836. Depot and
  the old wood find the same blocks as before (16 / 154 and 23 / 225).
- Nav on smooth slopes (`NavGridBuilder._sloped_diagonal`): a diagonal step up a slope steeper than 0.53 (0.75 on
  a straight step) climbs more than max_step, so the grid had none and a line up such a bank read as a drop. A
  diagonal now links when both straight steps round it do and it climbs at most max_step x sqrt 2; `drop_on_line`
  reads it from the steps table. A kerb's corner is still a step up (test_terrain).
- A bot pushed off its leg asks for a fresh route for a drop on the way on once each time it has moved
  `off_leg_replan_moved` (0.5 m): on a Woodland bank the fresh route was the same one, asked again every tick, and
  the bot stood still (a livelock the match test found). It walks that route; `stuck_time` still catches a real block.
  (The critic's alternative, judging a fresh route's first leg from where the bot stands, is the deeper fix; the
  guard is the smaller change and keeps the off-leg check as it was everywhere else.)
- The match guards' held-up measure (`MatchRunner.errand_of`): a hunting bot's errand is its mode and the spot it
  hunts, so a hunter turning for another spot the way it came (a teammate checked its spot first) is a change of
  errand, as a search given up for the lane already was, not a loop. Bots still go out and back on such hunts on the
  bigger wood; that is how hunting works today, not a hold-up.
- A fifth slide in the stream bed north of the North bridge: the bridge's deck is 1.4 m over the bed, so the stretch
  beyond it was a pit of 37 m² with no way out on foot (the test below found it).
- The old wood is `tests/support/maps/old_woodland.json` (`OldWoodland`): the tests written against its layout (its
  70 bushes, the Knoll, the board fence's prop noise, the minimap's meadow) load it. The torch, woods-view and
  match-guard tests that need the night play Woodland by night (`lighting_pick`, `MatchRunner.night`, the guards'
  `night`), and the colour check reads painted pieces from the fixture too, now that no shipped map paints.
- `tests/unit/test_woodland_layout.gd` (rewritten): the file loads clean with six a side, by day or night, 11 lights,
  bots at 60 m; the field and the stream's depth; both crossings level with the ground at their ends; every piece on
  the ground; bots find cover at its sunk pieces; no walkable ground is a pit cut off from the camps (the Crawl box's
  mound top is out of reach instead); no spawn seen from anywhere walkable outside its camp, both ends (it found three gaps in the concept's
  gate screens: each now runs past its gate's post); the overtime flag even and the attackers' and defenders' walks to
  A; every crossing within 32 s of both ends; a body walks each lane end to end on the bots' routes; a bot match plays
  out with no bot held up.

## Defaults taken

- Sightline exception: rare pinhole gaps between trunks run 100 to 160 m across the whole wood; each lane's own lines
  stay under 78 m and the Ridge overlook 86 m. Asked to keep them or thicken the wood, the owner kept them
  (2026-10-31, decision card; DECISIONS); `FieldStandard.EXCEPTIONS` allows 170 m on Woodland.
- The tunnels are 1.4 m clear, under today's 1.8 m body: nobody goes through them until CR1 (KNOWN_ISSUES).
- Doors stand as open doorways and Attack / Defend keeps one flag, at the Fort (A), until WR2 (KNOWN_ISSUES).
- The greybox look (no CC0 models yet) until WR3; its card is a top view of the greybox.
- Woodland's match guards play it by night (`night = true`), as they did before WR1; by day it plays one whole match in
  test_woodland_layout (seed 7, 5v5). Day guard jobs would add about an hour of CI per pull request.

## Checks

- pending

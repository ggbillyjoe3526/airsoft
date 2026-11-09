# RK1 · Racking and small props for Depot and the Range

**Review:** attempts 4 · critic Accept 8/8 (Opus) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (build thread) | pending | art critic vs photos: Retry 6/8 models | rack uprights thin and unslotted, kit rack hooks and rods, barrel collar, pallet gaps, sofa backs low, locker louvres and base |
| 2026-11-09 | 2 | Opus 5.5 (build thread) | green (targeted) | Retry, Accept 3/8; qa Fail | 16-sided drums, drum proportions, rack slots unread and sack voids, kit rack stands squat with tiny holes, sofa seat high, lockers' doors wide, flat, sticker chips; qa: locker surface, bounce undocumented, pallet stretched, stale docs, test gaps |
| 2026-11-09 | 3 | Opus 5.5 (build thread) | green (targeted) | Retry, Accept 7/8; qa Fail; performance Fail | racking's empty pallets solid and sack seams; drum gaps shoot-through; five bays tripled Low draws |
| 2026-11-09 | 4 | Opus 5.5 (build thread) | green | Accept 8/8; qa Pass; performance Pass | |

## Goal

The owner (2026-11-09) gave reference photos for every Dev 3 map model and asked for them in Blender
(`/mnt/project-files/art/depot-range-model-list.md`, group 3): pallet racking (also the Range's kit rack), steel
drum, pallet, plastic barrel, sofa, office desk and steel locker.

## Approach

- `tools/blender/maps/prop.py`: one vertex-coloured mesh a model, painted by palette name ("crate*0.9" for a shade),
  a gentle foot-to-top gradient baked in, exported like the Kenney props (`assets/models/props/`), triangle budget
  enforced at build. `render_prop.py` renders a built .glb from labelled angles for review.
- One script a model in `tools/blender/maps/`, each modelled at its block's size so PropLayout's fit barely
  stretches it.
- `PropDressConfig.models` points Depot's barrel, drum, pallet, sofa and shelf at the new files, adds `desk`,
  `locker` and `kit_rack`; the Kenney barrel, drum and shelf files and their recipes are gone.
- Depot's desk and wardrobe pieces name their prop (`tools/depot/build_map.py` DRESS), keeping their kinds; the
  Range's rack block names `kit_rack` (`data/maps/range.json`). SiteDress skips a crate's battens and a plywood
  cap on a block drawn as its own prop.
- Depot's bake rebuilt (the drums', barrels' and lockers' surfaces changed); the Range's needs none (`dress` is not in
  its hash), only its play-data guard follows. SiteDress draws no details at all on a block drawn as its own prop.

## Decisions

- **Kit rack is its own model.** The owner's kit_rack photos are replica stands, not pallet racking: a bay of the
  same racking fitted with the stands, empty (replicas are carried, not racked), budget 2,500 (the plan said
  "shared").
- **Drums: two stacked a model, nine stacks a pallet** (`cluster_cell` 0.9 to 0.6). The drum block is 1.75 m tall;
  one drum to fill it was 0.9 m wide and 1.6 m tall. Now each drum is 0.53 by 0.8 m, a real one's proportions (0.585
  by 0.88): a cluster keeps its model's proportions in its cell (PropLayout), so a hand's width shows between stacks.
  81 stacks in the hall draw in 40 m chunks (`chunk_from`), as Woodland's trees do. The pallet is modelled at the
  drum block's 1.8 m foot, nine top boards.
- **Three racking bays, mixed** (the owner, 2026-11-09: "it looks too repetitive"): `PropDressConfig.variants` names
  the bays a lining model takes turns with; PropLayout picks one at random for each place along a rack, never one
  its in-line neighbour (by front face, across blocks) already is (`PropLayout.Turns`, seeded). Five bays tripled
  Depot's draws on Low (performance, measured); three, chunked 40 m (`many_chunk`), keep about one model's draws. Bay
  B has no drums or sacks and shows empty slots and slatted empty pallets.
- **Drum clusters are solid inside:** the stacks stand apart (a hand's width), so RoundSteps adds a core from the
  outer stacks' middles in; no BB or sight line threads the gaps (qa), the outer corners still graze open.
- **Racking bays end in half an upright,** so neighbouring bays meet in one whole upright; no rear uprights or beams
  (the backing hides the back half).
- **Team hues swapped for palette colours:** the photos' blue drums and barrels are violet and teal, the orange
  beams yellow, the navy uprights the look's ink.
- **Surfaces follow the look:** Depot's drums ring as metal (were cardboard fibre drums), its barrels tick as
  plastic (were steel), its lockers as metal (`surface` on the block; the kind stays plywood). That changes bounces
  too: BBs can ricochet off drums and lockers and no longer off barrels (changelog, wiki How to Play).
- **Lockers: three narrow double-door units a face** (doors 0.32 m), pressed rails, no worn patches (they read as
  stickers).
- **Desk and lockers stay opaque:** a modesty panel and kick panel to the floor, panel ends, a plinth set back
  between the lockers' legs, so nothing is seen through what the box stops.

## Known issues left

- Clustered drums reach `chunk_from` and draw as 8 chunks, about one draw a pallet (performance, advisory; can wait).
- Polish (critic, can wait): the lockers' legs are straight posts (the photos' are splayed on an arched skirt); the
  drums' hoops are single ridges and the racking's lying drums have none.
- For the owner to check in play: Depot's racking aisles on Low at 60 fps (F3), and how three bays read along a rack.

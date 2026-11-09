# WG3 · Woodland's structures as models

**Review:** critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | thread | see Checks | Retry 6/8 | open stair over a solid ramp, legs and posts thinner than their blocks, tower and shed short of the photos, the palisade too regular |
| 2026-11-09 | 2 | thread | see Checks | Retry 7/8 | the photos' pitched roofs, low lattice and open rails need taller or open boxes: the owner kept the boxes |
| 2026-11-09 | 3 | thread | see Checks | Accept 7/8 | – |

## Goal

The owner's Woodland references (2026-11-09: "here are all the reference images for the woodland models. start
building the models for this map."), group 3 of `/mnt/project-files/art/woodland-model-list.md`: 04 the log palisade,
05 the watch tower, 06 the log footbridge, 07 the Sawmill's open shed and 08 the huts' roofs, modelled from his photos
(`/mnt/project-files/art/references/maps/woodland/`), each inside its budget, without changing what stops a BB, a
body or sight.

## Approach

- **The map names each structure.** `tools/woodland/build_map.py` gives the blocks a `dress`: every fence block
  `palisade`; the tower's legs, deck, parapets, roof and stair `watch_tower`; the North bridge's deck and sides
  `footbridge`; the Sawmill's posts and roof `sawmill_shed`; a hut's roof `hut_roof` or, 6 m long or more,
  `hut_roof_long`. `data/maps/woodland.json` has 949 blocks, two of them the new tower walls (below).
- **Small map fixes** (`tools/woodland/world.py`): the tower's legs and the shed's posts stand from the ground under
  the structure to its deck or roof (some stopped up to 0.26 m short, the tower's were cut to slivers), and the tower's
  west parapet is a cell shorter so the settle pass no longer thins it. These move collision by a few centimetres.
- **The tower walled in** (the owner, 2026-11-09: "make sure the watch tower structure is solid with no gaps (except
  for viewing areas)"): its north and south walls run on 0.25 m over the west wall's ends, closing the notches at the
  west corners, and two new 1.15 m walls stand either side of the stair's head on the east, where the deck was open
  to a drop. The only openings are the band between the walls and the roof to look out of, and the stair.
- **Two new lays** (`PropDressConfig.Lay`): `STAKES` stands one stake model side by side along a block at about
  `stake_pitch`, each overlapping the next a little and a little under the top at random, turned a random quarter (a
  block too thin for a round stake gets flattened ones), with two rails (`stake_rails`) on the face toward the field's
  middle; `SET` fits one model once to the box of every block that names it (`PropDressConfig.set_box`), so a
  structure of several blocks is drawn whole, its stair ramp among them (a SET is the only dress a ramp takes).
- **Models** (`tools/blender/maps/`, `timberkit.py` the shared timber): each script reads its blocks from the map file
  and builds every part to fill its block (posts, deck, walls, roof); the open timbers between blocks (knee braces,
  trusses, stair rails) stand over head height or where a body can't go. Triangles: palisade 56 a stake and 20 a rail
  (992 a 4 m section of 1,000), tower 5,942 of 6,000, bridge 2,896 of 3,000, shed 4,688 of 5,000, roofs 1,368
  and 1,476 of 1,500.
- Shadows: the palisade casts them on Medium and up (Low has no sun shadows); its 2,942 stakes are 165k triangles in
  20 chunks of 40 m, its rails 216 more of 20 (performance review, measured headless).
- Pictures: `tools/woodland_pictures.gd`. Tests: `test_wg3_woodland_models.gd`; `test_props` checks a SET model inside
  its blocks' joint box.

- **Thin window headers** (asked through the coordinator, 2026-11-09): a Woodland window's sill or lintel under 0.3 m,
  which the plywood kit leaves a box (DM1: Depot's floor edges), names `plywood_header`, a fifth 0.2 m module of the
  plywood kit with no skirting, laid by RUN like the wall around it (`build_map.py` HEADER; today the Fort's north
  firing window's lintel). 72 triangles a module.

## Defaults taken

- **Roofs stay inside their 0.15 m roof blocks**, so the tower's hip, the shed's sheet and the huts' gables are almost
  flat. A real pitch needs taller roof boxes, which changes sight over the roofs: the owner's call.
- **Weathered grey-brown timber**, not the red-brown stain of some photos: that hue sits within 20° of Beta orange.
- **The bridge's sides are closed slab rails:** the side blocks stop BBs and sight to a metre, so open rails would show
  a player who can't be shot.
- **No cross-bracing low on the tower's legs:** a player walks under the deck, so the truss band starts at 2.3 m.

## Attempt 2

- The performance review found the rails never drawn (`PropDress._models_used` didn't load a STAKES model's rail);
  now loaded, and a test builds the game's own dress.
- The critic: the tower's stair is closed (boarded risers, sides and back down to the ground), so it reads as solid as
  the ramp that stops BBs under it; legs and posts are 0.288 m, their shoes' plates making up the block's 0.3 m; the
  tower's band has an X brace a side (the photos' lattice) and the shed a deep header round its roof and heavier
  braces; the stakes vary in size by 15 % either way and their tips by up to 0.25 m; the shakes are a warmer cedar.
  `test_each_block_of_a_structure_is_filled_to_its_faces` cuts each structure's blocks in bands and fails a part short
  of its block's faces (it fails attempt 1's tower).
- Put to the owner (each changes play): pitched roofs in taller roof boxes, X braces low on the tower's legs (as
  railings BBs pass), open log rails on the bridge. He kept the boxes as they are (2026-11-09).

## Attempt 3

- The owner asked for the tower solid with no gaps but to look out of: the walls above, and
  `test_nothing_is_seen_through_a_structure_s_blocks` traces lines through every block of each structure, every 4 cm
  along x, y and z, and fails one that meets no part of the model inside the block. It found and closed: the gap
  between the stair's foot and its first tread, the parapets' open ends, the bridge's 8 mm gaps between its deck logs
  and between its slab courses, and a slot between its sill logs and the deck.
- The owner saw through the tower from under its deck. The test now also traces the six diagonals, and an eye at
  either end of a line must meet a face turned to it before any face's back inside the block (backs aren't drawn, so
  meeting one first is seeing into a hollow and through it); a hairline under 3 mm where round parts touch doesn't
  count. It found and closed: the walls open underneath where they stand out over the deck, open board and leg ends,
  the deck's board gaps showing the sarking's back (now boarded both ways), an 8 mm slit at every matchboard groove
  (now a continuous sawtooth), the bridging's open ends, the bridge's decking open underneath (now a flat face under
  each half-log) and its stringer bay open at the sides (the outer stringers now flush with the deck's sides).

## Checks

- `test_wg3_woodland_models` 11/11: each model inside its budget and using it; the map names each structure on its
  blocks; each structure model built for its blocks as they are and laid once over them; the roofs fill their blocks;
  the stakes and rails stay in their blocks with no gap between stakes; a plain ramp keeps its box; the lay is seeded;
  the game's own dress draws the stakes, their rails and every structure; each structure fills its blocks band by
  band; nothing is seen through a structure's blocks. `tools/woodland/check.py` TOTAL 0.
- `test_props`, `test_bb_walls`, `test_dp4_qa`, `test_wr3_qa`, `test_woodland_layout` pass.
- In-game pictures of each structure checked against the photos (`/mnt/project-files/art/blender/woodland-wg3/`).

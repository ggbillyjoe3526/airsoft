# WG4 · Woodland's small props: tunnels, culvert, pickup, tyres, campfires and lanterns from the owner's photos (Dev)

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | build thread | see Verified | Retry 6/8 | the tunnel mouth not one round log, the cap a block; the pickup's rust everywhere, its tyres not flat enough; the tyres' lugs; the campfire's flames white; the culvert inside too pale |
| 2026-11-09 | 1, fix round 2 | build thread | see Verified | Retry 7/8 | the tunnel: a crease at the crown, strips at the joints inside, the mouth a ring in a box of earth, no bark rim |
| 2026-11-09 | 1, fix round 3 | build thread | see Verified | Retry 7/8 | the tunnel's outside from the mound: the earth over the log stepped per section, a flat side of the log standing out |
| 2026-11-09 | 1, fix round 4 (owner allowed a fifth try) | build thread | see Verified | Retry 7/8 | hard earth edges by the tunnel mouths, seen from the side and above |
| 2026-11-09 | 1, fix round 5 | build thread | see Verified | Accept 8/8 | |

## Goal

Dev 3's Woodland models (`art/woodland-model-list.md` in the project files), the small props: 15 the abandoned pickup,
16 the crouch tunnel kit, 17 the concrete culvert, 19 the tractor tyre stacks, 20 the campfire and 21 the lantern,
modelled in Blender from the owner's photos (`art/references/maps/woodland/`). Each model fills its block's box; the
tunnels keep 1.4 m clear inside; the campfires and lanterns are look only (the map's lights, no collider).

## Approach

- **Models** (`tools/blender/maps/`, vertex colours through `mapkit.py`, weathered per corner by the new
  `weathering.py`): `log_tunnel.py` (a hollow-log wall 120, the log's round arched top 240 and the mound's cap 96
  triangles: a section 576 of the list's 600), `culvert.py` (wall 840 of 890, kerb 342 of 360), `pickup.py` (9,259 of
  10,000), `tyre.py` (700 and 1,420 of 750 and 1,500), `campfire.py` (775 of 800), `lantern.py` (lantern 386 of 400,
  hook pole 136, chain 8).
- **Map:** `tools/woodland/build_map.py` names each block's model (`MapData.Block.dress`): tunnel walls and roofs,
  the culvert's walls and kerbs, the tyres, the pickup. The Crawl box's blocks become kind `log` (a wood surface, as
  plywood was); the roof blocks narrow to the log's width.
- **Lays** (`PropDressConfig.Lay`, `PropLayout`): `SIDE` turns a tunnel wall's inner face toward its partner across the
  tunnel (`side_reach`); `LINED` lays the roof shell at its own height and stretches its cap (`lined_caps`) from the
  log's shoulders to the roof block's top, so roof blocks up to 2 m high all read as log under earth; `joint_bend`
  shears each tunnel section to meet its neighbours where the floor and the mound step; `grounded` stands the tyres and
  the pickup on the ground under their block's middle, their tops at its top, a skirt under them so a slope never shows
  a gap.
- **Fires and lanterns** (`LightFixtures`, `LightFixturesConfig`, built by `PlaySession` beside `LightPools`): a
  campfire on the ground under each fire; a lantern on a nail where its light is inside a post, on a chain from a roof
  or beam within 1.2 m over it, else on a hooked pole stood clear of blocks. By day the coals are charcoal and there are
  no flames; at night the coals and globe glow and the flames flicker and sway (still under Reduced motion).
  `tools/eye_pictures.gd` draws them, and `night` lights them.

## Decisions (defaults, owner told 2026-11-09)

- Both tunnels are hollow oak logs (his photos show only hollow logs), so the Crawl box is no longer plywood; every
  section's cut ends are finished, so no separate mouth model.
- The pickup is faded violet as the model list says (a site colour); rust stays dull grey-brown, off the orange team.
- All three fires are campfires, the Truck bend's "fire drum" included.
- Tyres: the blocks are 0.85 m (tyre) and 1.7 m (tyre_stack) high, so a "single" is two 0.425 m tractor tyres and a
  stack four, as in the photos' stacks; the list's "singles and stacks of two" read as one and two blocks' worth.
- Critic round 1 and the owner (2026-11-09): the pickup's cab moved 0.5 m forward over a shorter hood (owner), the body
  lower on its flat tyres, nose down, wider (1.86 m), rustier, with blank plates, marker lamps, an aerial, mud flaps
  ("slightly more realistic", owner); the tunnel roof is the log's arched top (0.55 m over the clear height) and the
  roof blocks are the log's width (2.5 m, `TUNNEL_ROOF_HALF`), so a mouth reads as one round log; both tunnels' blocks
  are kind `log`; the Truck bend campfire stands 6.5 m off the road's middle line (owner: no campfire near the road);
  the campfire's stones and wood paler with five tongues of flame; the culvert a cool grey, darker inside.
- Critic round 2: the log's arched top 0.9 m on a round arch (`SHELL`, `TUNNEL_LOG_TOP`) so a mouth's crown is about its
  width; the cap slopes in toward the crown (`CAP_SLOPE`); the pickup's rust only at the rockers, arches and bed rails,
  flatter tyres, grey rims, small mud flaps; the tractor tyres 20 V lugs; the campfire's flames deeper orange and its
  light lower (0.7 m); the culvert darker inside. The QA and performance reports are `pipeline/out/wg4-*.md` (both
  Pass).
- Critic round 3: the vault arches 0.28 m into the shell (look only; the 1.4 m ceiling still stops a standing player);
  the cut end is heartwood, a pale sapwood ring and a dark bark rim (`END_LINES`); the mound's earth slopes up onto the
  log's shoulders, and over a tunnel it climbs 0.6 m a section from each mouth (`TUNNEL_MOUTH_RISE`), so a mouth is the
  log's end standing out of the slope; PropLayout bends each section to meet its neighbours halfway where the floor
  steps (`joint_bend`) and stands the walls unstretched, so the inside runs on without a seam. The olive strips inside
  were the woods' moss slabs on the tunnel's log blocks (`WoodsShapes.UNMOSSED` now skips them). The culvert darkens
  within its first metre inside. The cream stub by the culvert's kerb is DM1's crate at (1, 45.5).
- Critic round 4, a fifth attempt the owner chose (2026-11-09): the earth over a tunnel is one slope, each section at
  most 0.3 m over the next (`TUNNEL_EARTH_STEP`), the log alone at each mouth; the cap starts on the log's shoulders
  (`lined_cap_from`, `WEDGE_FOOT` 0.5 m over the ceiling) and is bent by the roofs' tops, so the caps run on as one
  ridge; the terrain is banked against the log's sides up to the same height (`TUNNEL_BANK`), so no flat of its side
  shows.
- Critic round 5 (the fifth attempt): the hard edges were a middle section standing at each end. The mouth model
  (`log_tunnel_mouth`: the shell under one hood of earth that runs from its neighbour's profile at the joint down onto
  the log's cut end, `PropDressConfig.lined_mouths`) was never loaded, since `PropDress._models_used` listed a lined
  model's cap but not its mouth; it does now, and a test checks both tunnels end in mouths. The earth is heaped against
  the log (`build_map.bank_tunnel`: `TUNNEL_BANK` over the ceiling for `TUNNEL_BANK_REACH` 0.5 m out, then falling
  1:1 to the ground on every side, past the mouths but never on the path), so no ridge, flap or gap shows beside a
  mouth; the earth's skirt (`SKIRT`, 0.25 m out) lies under it.
- The Kenney `tyre.glb` and `truck.glb` stay as the `tyre` and `truck` kinds' fallback; Woodland names its own models.

## Verified

- `tests/unit/test_wg4_woodland_props.gd` (9 tests): budgets, the walls facing in, sections meeting at a step, a run
  ending in a mouth turned to its open side (the model's earth low at its front), Woodland loading its mouths and caps
  (four mouths), the roof shell and cap, every prop inside its block, the grounded ones on the ground, every fire on the ground and every
  lantern on a chain or a hook, flames only at night and only on Woodland.
- `tests/unit/test_props.gd`: Woodland names `tractor_tyre` and `pickup` (not the Kenney `tyre` and `truck`); a SIDE or
  LINED section may reach `JOINT_SLACK` (0.2 m) over or under its box where it is bent to meet its neighbours; the
  tunnel's earth is a dull grey-brown off the orange team.
- In-game pictures by day and night (`art/blender/woodland-wg4/` in the project files).

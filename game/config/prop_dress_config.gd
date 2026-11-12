class_name PropDressConfig
extends Resource
## A field's props (DR2, WR3, RK1): which blocks are drawn as models instead of their box (Depot's by kind, Woodland's
## by the prop each block names, MapData.Block.dress), and how the models are laid in the box. Each prop fills its
## block's box (never past it), so cover and the nav grid stay the box's and collision the box's (a round prop's,
## its stepped boxes that hug it: MapStyle.round_steps, RoundSteps); the box's own faces are not
## drawn (SiteSurface.core_of). Every model is the game's own, built in Blender by tools/blender/maps/ into
## assets/models/props/, one vertex-coloured mesh each (docs/ASSETS.md; the last Kenney ones, unused once Woodland had
## its own models, went in Dev 3).

## How a kind's props are laid: ROW stands round props upright side by side along the box's long side, as many as fit
## at its short side's width; CLUSTER stands them on a pallet in a grid of cells about `cluster_cell` m across; FIT
## stretches one model to the whole box, its front to the field's middle; TILE lines the box's faces with rows of the
## model as tall as the box, each facing out (`tile_depths`), over a dark backing; GRID fills the box with the model
## in cells about `grid_cells` m across (x along the box's long side, y up, z across it), stacked, each stretched to
## its cell, the model's z across the box (WR3). RUN lays a wall's modules end to end along the box's long side, each
## about `run_lengths` m long (stretched so a whole number fill it), as tall and as thick as the box, each turned end
## for end at random (DM1: Depot's plywood walls). UNIT fits one model to the box like FIT, long side along the box's,
## its +x end (a container's doors) turned away from a block of its kind against either end, else away from the field's
## middle (DM1: Depot's containers, a port cut between two units of one). BAY lines a wall's box with the model in
## cells on a grid of the world (`bay_pitch` m apart from `bay_anchor`), each stretched to its cell and its front (+z)
## to the field's middle, a feature bay (`bay_features`) in some cells with nothing standing in front of them (Dev 3:
## Depot's hall walls, their columns under the roof's trusses). GROUND stands the model on the ground at the box's
## middle (its own y = 0 the ground line), its long side along the box's and stretched to fill it, its top the box's
## top, a half turn either way at random, and fills the box under it where the ground falls away with an earth bank
## (`ground_bank`): Woodland's logs, root plates, sawbench and boards (WG2), which lie on slopes in boxes that reach
## down to the lowest ground under them.
## SIDE fits a tunnel wall's model to its box, long side along the box's, its inner face (the model's -x) toward the
## wall across the tunnel (the nearest block named alike across the box's short side, within `side_reach` m), at its
## own height. LINED sets the model on the box's foot at its own height and width, stretched only along, and its cap
## (`lined_caps`) over the rest of the box, or its mouth model (`lined_mouths`) at the end of a run (WG4: Woodland's
## hollow-log tunnels, the log's top shell under the roof and the mound's earth over it; the shell's earth reaches
## past the box's sides onto the ground banked against the log).
## TREE stands one tree in the box (Dev 3, WT1: Woodland's pines, oaks and birches): the model's origin on the ground
## under the box's middle, its trunk's foot (`tree_feet` m round its origin) stretched to the box's half-width and the
## tree's top to the box's top, turned a random quarter; its crown (`tree_crowns`, a model of its own) scaled evenly by
## the tree's height over it, so it keeps its shape however the box is proportioned, spreading past the box over head
## height, look only, as the cone crowns WoodsView drew before. STAKES stands the model upright side by side along the
## box's long side and lays its rails along the side towards the field's middle (`stake_pitch`, `stake_rails`: WG3,
## Woodland's palisade). SET fits one model, unturned, to the box round every block that names it (`set_box`: WG3, a
## structure built over its blocks, each part filling its own: Woodland's watch tower, its footbridge and the Sawmill's
## shed); a ramp may be one of them, and a model may stand `set_heads` over its box.
enum Lay { ROW, CLUSTER, FIT, TILE, GRID, RUN, UNIT, BAY, GROUND, SIDE, LINED, TREE, STAKES, SET }

## Each prop's model (a .glb of one vertex-coloured mesh).
@export var models: Dictionary[StringName, String] = {
	# Depot's and the Range's, built in Blender (RK1): plastic barrels, two steel drums stacked, the pallet under them,
	# the Lounge's sofa, a bay of pallet racking, the Offices' desks and lockers, the Range's kit rack.
	&"barrel": "res://assets/models/props/plastic_barrel.glb",
	&"drum": "res://assets/models/props/steel_drum.glb",
	&"pallet": "res://assets/models/props/pallet.glb",
	&"sofa": "res://assets/models/props/sofa.glb",
	&"shelf": "res://assets/models/props/pallet_racking.glb",
	&"shelf_b": "res://assets/models/props/pallet_racking_b.glb",
	&"shelf_c": "res://assets/models/props/pallet_racking_c.glb",
	&"desk": "res://assets/models/props/office_desk.glb",
	&"locker": "res://assets/models/props/steel_locker.glb",
	&"kit_rack": "res://assets/models/props/kit_rack.glb",
	# The game's own map models (DM1, tools/blender/maps): Depot's and Woodland's crates, Depot's plywood walls and
	# containers.
	&"crate": "res://assets/models/props/crate.glb",
	&"plywood": "res://assets/models/props/plywood.glb",
	&"plywood_mid": "res://assets/models/props/plywood_mid.glb",
	&"plywood_low": "res://assets/models/props/plywood_low.glb",
	&"plywood_short": "res://assets/models/props/plywood_short.glb",
	&"plywood_header": "res://assets/models/props/plywood_header.glb",
	&"container": "res://assets/models/props/container.glb",
	&"container_low": "res://assets/models/props/container_low.glb",
	&"container_short": "res://assets/models/props/container_short.glb",
	&"container_wall": "res://assets/models/props/container_wall.glb",
	&"container_roof": "res://assets/models/props/container_roof.glb",
	# Depot's hall shell (Dev 3, tools/blender/maps/): the walls' bays, its pillars and its camouflage nets.
	&"hall_wall": "res://assets/models/props/hall_wall.glb",
	&"hall_shutter": "res://assets/models/props/hall_shutter.glb",
	&"hall_exit": "res://assets/models/props/hall_exit.glb",
	&"pillar": "res://assets/models/props/pillar.glb",
	&"camo_net": "res://assets/models/props/camo_net.glb",
	# Woodland's structures (Dev 3, WG3, tools/blender/maps/): the palisade's stake and rail, the watch tower, the
	# North bridge, the Sawmill's shed and the huts' roofs.
	&"palisade": "res://assets/models/props/palisade.glb",
	&"palisade_rail": "res://assets/models/props/palisade_rail.glb",
	&"watch_tower": "res://assets/models/props/watch_tower.glb",
	&"footbridge": "res://assets/models/props/footbridge.glb",
	&"sawmill_shed": "res://assets/models/props/sawmill_shed.glb",
	&"hut_roof": "res://assets/models/props/hut_roof.glb",
	# Subway's stairs and escalators (Dev 3 SM2, tools/blender/maps/), each laid over its ramps and their barriers
	# (SET): the two escalator banks, the spiral stair round its core and the stair down to the platforms.
	&"escalator_upper": "res://assets/models/props/escalator_upper.glb",
	&"escalator_lower": "res://assets/models/props/escalator_lower.glb",
	&"spiral_stair": "res://assets/models/props/spiral_stair.glb",
	&"platform_stair": "res://assets/models/props/platform_stair.glb",
	&"hut_roof_long": "res://assets/models/props/hut_roof_long.glb",
	# Woodland's undergrowth and logs (Dev 3 WG2, tools/blender/maps/): the fallen logs at three lengths, the
	# wind-thrown root plates, cordwood and B's sawn boards and sawbench, and the earth bank under them on slopes.
	&"fallen_log_5": "res://assets/models/props/fallen_log_5.glb",
	&"fallen_log_6": "res://assets/models/props/fallen_log_6.glb",
	&"fallen_log_8": "res://assets/models/props/fallen_log_8.glb",
	&"root_plate": "res://assets/models/props/root_plate.glb",
	&"cordwood": "res://assets/models/props/cordwood.glb",
	&"cordwood_b": "res://assets/models/props/cordwood_b.glb",
	&"cordwood_c": "res://assets/models/props/cordwood_c.glb",
	&"boards": "res://assets/models/props/boards.glb",
	&"sawbench": "res://assets/models/props/sawbench.glb",
	&"earth_bank": "res://assets/models/props/earth_bank.glb",
	# Woodland's trees (Dev 3, WT1, tools/blender/maps/): the pine's three ages, the oak and the birch, each block of
	# kind tree naming one, its trunk and its crown apart (tree_crowns); and the thickets' spruce.
	&"pine_young": "res://assets/models/props/pine_young.glb",
	&"pine_grown": "res://assets/models/props/pine_grown.glb",
	&"pine_old": "res://assets/models/props/pine_old.glb",
	&"oak": "res://assets/models/props/oak.glb",
	&"birch": "res://assets/models/props/birch.glb",
	&"pine_young_crown": "res://assets/models/props/pine_young_crown.glb",
	&"pine_grown_crown": "res://assets/models/props/pine_grown_crown.glb",
	&"pine_old_crown": "res://assets/models/props/pine_old_crown.glb",
	&"oak_crown": "res://assets/models/props/oak_crown.glb",
	&"birch_crown": "res://assets/models/props/birch_crown.glb",
	&"spruce": "res://assets/models/props/spruce.glb",
	# Woodland's small props (WG4, tools/blender/maps/): its tractor tyres, the pickup wreck, the culvert under the
	# road and the hollow-log tunnels.
	&"tractor_tyre": "res://assets/models/props/tractor_tyre.glb",
	&"tractor_tyre_stack": "res://assets/models/props/tractor_tyre_stack.glb",
	&"pickup": "res://assets/models/props/pickup.glb",
	&"culvert_wall": "res://assets/models/props/culvert_wall.glb",
	&"culvert_kerb": "res://assets/models/props/culvert_kerb.glb",
	&"log_tunnel_side": "res://assets/models/props/log_tunnel_side.glb",
	&"log_tunnel_roof": "res://assets/models/props/log_tunnel_roof.glb",
	&"log_tunnel_cap": "res://assets/models/props/log_tunnel_cap.glb",
	&"log_tunnel_mouth": "res://assets/models/props/log_tunnel_mouth.glb",
	# The practice range's (RM1), modelled in Blender by tools/blender/maps/.
	&"range_wall": "res://assets/models/props/range_wall.glb",
	&"range_backstop": "res://assets/models/props/range_backstop.glb",
	&"sandbags": "res://assets/models/props/sandbags.glb",
	&"site_toilet": "res://assets/models/props/site_toilet.glb",
	&"water_tote": "res://assets/models/props/water_tote.glb",
	&"generator": "res://assets/models/props/generator.glb",
	# Subway's ticket hall and concourse (Dev 3, SM3, tools/blender/maps/): its ticket gates, machines, kiosks, office,
	# booking counter, help points, benches and crowd barriers, each fitted to its block (FIT, or its `facing`).
	&"ticket_gate": "res://assets/models/props/ticket_gate.glb",
	&"ticket_machine": "res://assets/models/props/ticket_machine.glb",
	&"kiosk": "res://assets/models/props/kiosk.glb",
	&"kiosk_long": "res://assets/models/props/kiosk_long.glb",
	&"ticket_office": "res://assets/models/props/ticket_office.glb",
	&"booking_counter": "res://assets/models/props/booking_counter.glb",
	&"help_point": "res://assets/models/props/help_point.glb",
	&"station_bench": "res://assets/models/props/station_bench.glb",
	&"station_bench_long": "res://assets/models/props/station_bench_long.glb",
	&"crowd_barrier": "res://assets/models/props/crowd_barrier.glb",
	# Subway's (Dev 3, SM1, tools/blender/maps/train.py), named by their blocks (SD1): the trains' seats and the tool
	# carts in the south train's aisle, and the bogie under each train end. The cars themselves are TrainView's.
	&"train_seat": "res://assets/models/props/train_seat.glb",
	&"train_seat_short": "res://assets/models/props/train_seat_short.glb",
	&"tool_cart": "res://assets/models/props/tool_cart.glb",
	&"train_bogie": "res://assets/models/props/train_bogie.glb",
}
## Each dressed block kind's prop, and how it is laid. A kind not listed keeps its box.
@export var kind_props: Dictionary[StringName, StringName] = {
	&"barrel": &"barrel", &"drum": &"drum", &"sofa": &"sofa", &"rack": &"shelf", &"crate": &"crate",
	&"plywood": &"plywood", &"container": &"container",
	&"wall": &"hall_wall", &"pillar": &"pillar", &"net": &"camo_net",
}
@export var kind_lays: Dictionary[StringName, Lay] = {
	&"barrel": Lay.ROW, &"drum": Lay.CLUSTER, &"sofa": Lay.FIT, &"rack": Lay.TILE, &"crate": Lay.GRID,
	&"plywood": Lay.RUN, &"container": Lay.UNIT,
	&"wall": Lay.BAY, &"pillar": Lay.FIT, &"net": Lay.GRID,
}
## A model's versions for its kind's other shapes of block (DM1), each drawn when it loads: a flat one on a block
## `flat_height` m high or lower (the Box's roof), a thin one on a block `thin_depth` m thick or thinner (the Box's
## container walls), else the one of `heights` built nearest the block's height (by ratio): a plywood wall's sill
## under a window and lintel over one, a container's under and over a port, so a cap or a rail is never squashed or
## stretched far.
@export var flat_models: Dictionary[StringName, StringName] = {&"container": &"container_roof"}
@export var flat_height: float = 0.3
@export var thin_models: Dictionary[StringName, StringName] = {&"container": &"container_wall"}
@export var thin_depth: float = 1.0
## A model's heights: each version and the height (m) it is built at (tools/blender/maps, HEIGHTS and MODELS).
@export var heights: Dictionary[StringName, Dictionary] = {
	&"plywood": {&"plywood": 2.6, &"plywood_mid": 1.7, &"plywood_low": 1.0, &"plywood_short": 0.5},
	&"container": {&"container": 2.6, &"container_low": 1.0, &"container_short": 0.6},
}
## UNIT finds a block of its kind against an end this close (m) or closer, and turns a box along the blocks it touches
## only when its long side is under `unit_square` times its short (a cut piece, not a whole unit).
@export var unit_reach: float = 0.05
@export var unit_square: float = 1.5
## RUN's module length (m) a model: a plywood wall's batten pitch, half a 1.22 m sheet. A wall is that many whole
## modules, stretched by at most `run_stretch` (a share) to fill it, or else with a cut, narrower one at its end.
@export var run_lengths: Dictionary[StringName, float] = {
	&"plywood": 0.61, &"plywood_mid": 0.61, &"plywood_low": 0.61, &"plywood_short": 0.61, &"plywood_header": 0.61,
}
@export var run_stretch: float = 0.1
## A cut module narrower than this share of one is never laid: the whole ones stretch over the sliver instead.
@export var run_min_cut: float = 0.25
## A dressed kind's block thicker than this (m) keeps its box: Depot's wardrobe, a plywood block a metre deep, is no
## wall.
@export var kind_max_depth: Dictionary[StringName, float] = {&"plywood": 0.5}
## Other models a lining model (TILE) takes turns with, place by place along a rack, never the same twice in a row,
## and a GRID model's cells pick among at random (WG2: Woodland's woodpiles, three sections each its own ragged top),
## so a long rack wall or stack never reads as one bay repeated (the owner, 2026-11-09: the racking loaded three ways;
## five drew three times the hall's draws on Low). Each is in `models`, the same size as the model it stands in for.
## Their chunks are `many_chunk` across, so the bays together take about the draws one model did in `chunk` ones.
@export var variants: Dictionary[StringName, PackedStringArray] = {
	&"shelf": PackedStringArray(["shelf_b", "shelf_c"]),
	&"cordwood": PackedStringArray(["cordwood_b", "cordwood_c"]),
}
## How a prop a block names (MapData.Block.dress, WR3) is laid in it; one not listed is fitted to the box (FIT, long
## side along the box's).
@export var model_lays: Dictionary[StringName, Lay] = {
	&"crate": Lay.GRID, &"spruce": Lay.GRID,
	&"pine_young": Lay.TREE, &"pine_grown": Lay.TREE, &"pine_old": Lay.TREE, &"oak": Lay.TREE, &"birch": Lay.TREE,
	&"plywood_header": Lay.RUN,
	&"palisade": Lay.STAKES, &"watch_tower": Lay.SET, &"footbridge": Lay.SET, &"sawmill_shed": Lay.SET,
	&"escalator_upper": Lay.SET, &"escalator_lower": Lay.SET, &"spiral_stair": Lay.SET, &"platform_stair": Lay.SET,
	&"cordwood": Lay.GRID, &"fallen_log_5": Lay.GROUND, &"fallen_log_6": Lay.GROUND, &"fallen_log_8": Lay.GROUND,
	&"root_plate": Lay.GROUND, &"sawbench": Lay.GROUND, &"boards": Lay.GROUND,
	&"log_tunnel_side": Lay.SIDE, &"log_tunnel_roof": Lay.LINED,
	&"range_wall": Lay.GRID, &"range_backstop": Lay.GRID, &"sandbags": Lay.GRID,
}
## How far (m) a SET model stands over the top of its box: thin parts drawn for the look only, which stop no one and
## no BB (SM2: the platform stair's handrails, over its ramps, as the ceiling's lamps hang under the roof). The model is
## fitted to its box grown up by this much.
@export var set_heads: Dictionary[StringName, float] = {&"platform_stair": 0.922}
## SIDE looks this far (m) across a tunnel wall for the wall across from it.
@export var side_reach: float = 3.0
## LINED's caps: the model laid over the rest of a box above a lined model, stretched to it from `lined_cap_from` m
## over the box's foot (down over the lined model's shoulders: WG4's mound earth over the log, from where the earth
## heaped against it starts, log_tunnel.py WEDGE_FOOT); none where less than `lined_min_cap` m is left over the lined
## model's top.
@export var lined_caps: Dictionary[StringName, StringName] = {&"log_tunnel_roof": &"log_tunnel_cap"}
## LINED's mouths: the model laid instead at the end of a run of sections (a block with a neighbour named alike on one
## side only, joint_bend's), its -z end turned to the open side, at its own height with no cap (WG4: a tunnel's mouth,
## the mound's earth running down onto the log's end).
@export var lined_mouths: Dictionary[StringName, StringName] = {&"log_tunnel_roof": &"log_tunnel_mouth"}
@export var lined_cap_from: float = 0.5
@export var lined_min_cap: float = 0.02
## FIT models stood on the ground under the box's middle (WG4: the tyres and the pickup, on a slope too): the model's
## own y = 0 meets the ground there and its top the box's, so what is under its y = 0 (a skirt) runs into the ground
## the box sinks into (build_map's SINK) and the model is never sunk or lifted by the slope. Fitted to the whole box as
## FIT does where the skirt would reach under the box.
@export var grounded: PackedStringArray = PackedStringArray(["tractor_tyre", "tractor_tyre_stack", "pickup"])
## GRID's cells (m): x along the box's long side, y up (0: one layer the box's height), z across. Cordwood in 2 m
## sections as tall as the stack (layers would show their ragged tops as seams), plywood crates 1.2 m long, a metre
## deep and 1.15 m high on their pallets (DM1: two high in Depot's 2.4 m crate walls, one in its waist cover), a spruce
## every metre and a half.
@export var grid_cells: Dictionary[StringName, Vector3] = {
	&"crate": Vector3(1.2, 1.15, 1.0), &"spruce": Vector3(1.5, 0.0, 1.5),
	# a camouflage net's scaffold sections, a pole every 2 m
	&"camo_net": Vector3(2.0, 0.0, 0.3),
	# cordwood in 2 m sections as tall as the stack, one section across however deep the stack (WG2)
	&"cordwood": Vector3(2.0, 0.0, 2.0),
	&"range_wall": Vector3(2.4, 0.0, 0.4), &"range_backstop": Vector3(2.4, 0.0, 0.4),
	&"sandbags": Vector3(1.2, 0.0, 0.6),
}
## GRID models drawn wider than their cell (x along the box's long side, y across it, a factor), so neighbours'
## boughs interleave into one mass: a thicket's spruces (FT1, the owner: its core box showed as a plain block between
## narrow spires). Never past the box: the end ones stand flush with its ends and the rest evenly between.
@export var grid_spread: Dictionary[StringName, Vector2] = {&"spruce": Vector2(1.8, 1.5)}
## GRID models scattered off their even places, so a stand of them grows as a wood does, not in rows (WS1, the owner:
## the thickets' spruces stood too neatly): each moves up to this share of the pitch between them either way along and
## across the box, never past it, and stands the box's full height (trees keep to their boxes: what you see is what
## stops a BB). Seeded by the block's place, so a stand is the same every build and nothing else's random draws move.
@export var grid_scatter: Dictionary[StringName, float] = {&"spruce": 0.38}
## GRID models laid all one way round, never turned at random: a net wall's sections match only edge to edge as
## modelled (DH1).
@export var grid_unturned: PackedStringArray = PackedStringArray(["camo_net"])
## STAKES: each model's stake spacing (m, about: whole stakes stretched to fill the box), and its rails' model. The
## stakes stand as thick as the box less its rails (at most `stake_thick` times their spacing, so neighbours meet and
## nothing is seen between them), each `stake_drop` m under the box's top at most and turned a quarter at random (a
## box too thin for a round stake gets flattened ones, turned a half); the rails lie along the box's face towards the
## field's middle, as long as the box, one `stake_rail_heights.x` m over its foot and one `stake_rail_heights.y` m under
## its top (the box reaches 0.3 m under the ground).
@export var stake_pitch: Dictionary[StringName, float] = {&"palisade": 0.235}
@export var stake_rails: Dictionary[StringName, StringName] = {&"palisade": &"palisade_rail"}
@export var stake_thick: float = 1.06
@export var stake_drop: float = 0.25
## STAKES: how much each stake's share of the box's length varies either way (logs of mixed sizes).
@export var stake_vary: float = 0.15
@export var stake_rail_heights: Vector2 = Vector2(0.8, 0.7)
## A named prop whose box is still drawn behind it, cut down to a share (y) of its height and inset (x, m, at most
## MapLevel.CORE_SHARE of the box's width) on each side with no other such box against it, rather than not at all: a thicket's dark
## core between its spruces' feet, unbroken across touching thickets, so nothing is seen through a thicket that stops
## BBs under its boughs. A spruce core reaches 0.2 of the thicket's height, under the spruces' widest boughs (FT1: at
## 0.6 it stood past their narrowing tops and read as a plain block).
@export var model_cores: Dictionary[StringName, Vector2] = {&"spruce": Vector2(0.7, 0.2)}
## TREE's models: each one's trunk's widest reach (m) round its origin at the ground and under it (an oak's buttress
## roots), which the box's half-width is; as each build script prints it (tools/blender/maps/pine.py, oak.py,
## birch.py). A tree model not listed keeps its box.
@export var tree_feet: Dictionary[StringName, float] = {
	&"pine_young": 0.2, &"pine_grown": 0.33, &"pine_old": 0.42, &"oak": 0.85, &"birch": 0.17,
}
## Each TREE model's crown (its limbs and leaves, written apart by the build script): laid over the trunk scaled evenly
## by the tree's height (PropLayout.crown_fit). A tree without one is all trunk.
@export var tree_crowns: Dictionary[StringName, StringName] = {
	&"pine_young": &"pine_young_crown", &"pine_grown": &"pine_grown_crown", &"pine_old": &"pine_old_crown",
	&"oak": &"oak_crown", &"birch": &"birch_crown",
}
## A dressed kind's block lower than this (m) keeps its box: a rack's shelf boards stay boards, its racking is
## shelving; Depot's desks (crate blocks 0.8 m high) stay desks, its crate stacks and the Range's are crates.
## A plywood block under 0.3 m (a hut's floor edge) stays a board. Only a hall's 8 m walls are its bays (the Range's
## lower walls keep their boxes).
@export var kind_min_height: Dictionary[StringName, float] = {
	&"rack": 2.0, &"crate": 0.85, &"plywood": 0.3, &"wall": 6.0,
}
## BAY's cells (m) by model: their edges at `bay_anchor` plus whole `bay_pitch`es along the world's x (anchor x) or z
## (anchor y), a wall's end cell shorter than half a pitch joined to the next. Depot's hall: the roof's trusses stand
## every RoofConfig.truss_step m along x from 0, so a long wall's columns stand under them; the end walls' bays run
## from their corners.
@export var bay_pitch: Dictionary[StringName, float] = {&"hall_wall": 8.0}
@export var bay_anchor: Dictionary[StringName, Vector2] = {&"hall_wall": Vector2(0.0, 4.0)}
## A bay model's feature bays, taken in turn, at most `bay_feature_most` a wall, never side by side, each in a whole
## cell with no block standing within `bay_clear` m of its face below `bay_clear_height` m (a door behind a stack of
## crates would make no sense).
@export var bay_features: Dictionary[StringName, PackedStringArray] = {
	&"hall_wall": PackedStringArray(["hall_shutter", "hall_exit"]),
}
@export var bay_feature_most: int = 2
@export var bay_clear: float = 2.0
@export var bay_clear_height: float = 3.0
## A cluster's cell (m, about) and the pallet's height under it (m; `pallet` is its model). A drum block's 1.8 m
## pallet holds three by three stacks of two steel drums (RK1).
@export var cluster_cell: float = 0.6
## The share of its cell a cluster's prop is wide: a drum stack 0.53 m in its 0.6 m cell, a real drum's proportions at
## the block's height (RK1; RoundSteps steps them the same).
@export var cluster_fill: float = 0.887
@export var pallet_height: float = 0.15
@export var pallet: StringName = &"pallet"
## TILE lines a box's faces with rows of props, each row `tile_skin` m deep at most (half the box's depth across it
## at most), on every face at least `tile_min_face` m long (a row along x runs the whole face; one along z stops
## short of the x rows at its ends). The box itself is drawn half a row inside each lined face, and `backing_top`
## under its top, in a dark backing (SiteLook's `backing` finish): the props' fronts stand proud of it and nothing is
## seen through them that the box would stop.
@export var tile_skin: float = 0.9
@export var tile_min_face: float = 1.5
@export var backing_top: float = 0.05
## A round prop's turn about its axis is a random quarter (seeded by the map's dressing seed), and its shade varies
## this much either way, so a row never reads as one model repeated.
@export var shade_jitter: float = 0.06
## Tiled props (the shelving, most of the props' triangles) are drawn in square chunks this many m across, one
## MultiMesh a chunk, so the camera culls the chunks off screen and each takes its own mesh level of detail (the Mesh
## detail step's mesh_lod_threshold, GraphicsApply; the simpler meshes are generated on import). The other models are
## one MultiMesh each, few draw calls for few triangles.
@export var chunk: float = 20.0
## A model laid this many times or more is chunked too (Woodland's trunks, spruces and cordwood, WR3), in squares
## `many_chunk` m across, so a field's worth of it culls by area; fewer are one MultiMesh. Twice the shelving's chunk
## (BP7): Woodland's props drew 167 of a High frame's 445 draws in 20 m chunks, 93 in 40 m ones.
@export var chunk_from: int = 64
@export var many_chunk: float = 40.0
## Models chunked as `many_chunk` however few are laid: spread round a field's edge (Depot's hall walls, DH1) or
## heavy and spread over it (Woodland's oaks and birches, WT1), one MultiMesh would draw them all wherever you look.
@export var spread_models: PackedStringArray = PackedStringArray(["hall_wall", "camo_net", "oak", "oak_crown", "birch",
		"birch_crown"])
## GROUND's earth bank: the model drawn under a grounded prop where the lowest ground under its box (sampled at its
## corners, the middles of its sides and its middle) is more than `bank_from` m under the ground at its middle; it fills
## the box from its bottom to `bank_tuck` m over that ground (a little under it: its top hides under the ground where
## that is level and shows only where the ground falls away, never a slab round the prop), `bank_share` of the box
## across and `bank_length` of it along. A grounded prop shows at least `ground_least` m over the ground, however the
## box sits.
@export var ground_bank: StringName = &"earth_bank"
@export var bank_from: float = 0.08
@export var bank_tuck: float = -0.03
@export var bank_share: float = 0.7
@export var bank_length: float = 0.96
@export var ground_least: float = 0.2

## The props' material: roughness, and metalness.
@export var roughness: float = 0.7
@export var metallic: float = 0.0
## Models drawn rougher or smoother than `roughness` (each roughness its own material): Woodland's trees' foliage is
## matt, so its soft crown normals never shine like plastic (WT1).
@export var model_roughness: Dictionary[StringName, float] = {
	&"pine_young": 0.95, &"pine_grown": 0.95, &"pine_old": 0.95, &"oak": 0.95, &"birch": 0.95, &"spruce": 0.95,
	&"pine_young_crown": 0.95, &"pine_grown_crown": 0.95, &"pine_old_crown": 0.95, &"oak_crown": 0.95,
	&"birch_crown": 0.95,
	# Subway's escalators' brushed stainless (SM2): a soft sheen.
	&"escalator_upper": 0.4, &"escalator_lower": 0.4,
}
## How worn the props are drawn (SL2, look_vertex.gdshader's `wear`; LookConfig.wear scales it): grime up their feet,
## streaks, stains and dust on top. Models worn otherwise (each its own material): the trees' crowns are clean, as
## leaves don't gather grime, nor does the earth bank under the ground's props (it is the ground), and the racking's
## goods lightly (its model's foot is the floor, under its bottom pallets).
@export_range(0.0, 1.0) var wear: float = 1.0
@export var model_wear: Dictionary[StringName, float] = {
	&"shelf": 0.35, &"shelf_b": 0.35, &"shelf_c": 0.35, &"earth_bank": 0.0,
	&"pine_young_crown": 0.0, &"pine_grown_crown": 0.0, &"pine_old_crown": 0.0, &"oak_crown": 0.0, &"birch_crown": 0.0,
	# a thicket's spruce is all boughs (FT1: worn, the dust on its upturned tiers drew its sunlit tops pale beige)
	&"spruce": 0.0,
	# Subway's escalators and stairs, swept daily: full dust drew their steps and decks beige (SM2)
	&"escalator_upper": 0.08, &"escalator_lower": 0.08, &"spiral_stair": 0.12, &"platform_stair": 0.12,
}
## Models whose painted parts keep their whole colour, not the look's weathered share of it (LookConfig
## .paint_saturation): Subway's escalators' and stairs' safety yellow, which the pull drew cream (SM2). Their other
## paints are steel, rubber and stone greys, which the pull leaves as they are.
@export var full_colour: Array[StringName] = [&"escalator_upper", &"escalator_lower", &"spiral_stair", &"platform_stair"]

## Each model path's mesh as loaded (null when it won't load), so a kind is dressed only by a model that loads.
var _meshes: Dictionary[String, Mesh] = {}
## This config with no kind dressed (`named_only`), made once.
var _named: PropDressConfig = null


## This config dressing only the blocks that name a model (MapData.Block.dress), never one by its kind alone: a
## station's (SD1, Subway), whose generic kinds (a cabinet is a ticket gate, a locker or a tool cart) say nothing of
## what stands there. Made once; the same config each call.
func named_only() -> PropDressConfig:
	if _named == null:
		_named = duplicate() as PropDressConfig
		_named.kind_props = {}
	return _named


## Whether block `b` is drawn as props: the prop it names, or else its kind's, has a model that loads (a tree's with
## its foot's reach), the kind's is tall enough, and the block is no ramp, unless it is part of a structure laid by SET
## (else it keeps its box).
func dresses(b: MapData.Block) -> bool:
	if b.rise != MapData.Rise.NONE and (b.dress == &"" or lay_of(b) != Lay.SET):
		return false
	if b.dress != &"":
		# a tree model is laid only with its foot's reach (tree_feet)
		var tree_ok: bool = model_lays.get(b.dress, Lay.FIT) != Lay.TREE or tree_feet.has(b.dress)
		return tree_ok and mesh_of(b.dress) != null
	var model := model_of(b)
	return model != &"" and b.size.y >= kind_min_height.get(b.kind, 0.0) \
			and minf(b.size.x, b.size.z) <= kind_max_depth.get(b.kind, INF) and mesh_of(model) != null


## Whether `model` is part of a tree (Lay.TREE's trunk, or its crown): stood by its origin on the ground, its crown
## spreading past its box over head height.
func is_tree_part(model: StringName) -> bool:
	return model_lays.get(model, Lay.FIT) == Lay.TREE or tree_crowns.values().has(model)


## `model` and the variants it takes turns with (`variants`), those with a model.
func variants_of(model: StringName) -> Array[StringName]:
	var out: Array[StringName] = [model]
	for v: String in variants.get(model, PackedStringArray()):
		if models.has(StringName(v)):
			out.append(StringName(v))
	return out


## The prop block `b` is drawn as: the one it names (MapData.Block.dress), else its kind's (its flat, thin or low
## version on a block of that shape, when that loads); empty for none.
func model_of(b: MapData.Block) -> StringName:
	if b.dress != &"":
		return b.dress
	var model: StringName = kind_props.get(b.kind, &"")
	var shape: StringName = &""
	if b.size.y <= flat_height:
		shape = flat_models.get(model, &"")
	elif minf(b.size.x, b.size.z) <= thin_depth:
		shape = thin_models.get(model, &"")
	if shape == &"" and heights.has(model):
		shape = _nearest_height(heights[model], b.size.y)
	return shape if shape != &"" and mesh_of(shape) != null else model


## Of `versions` (model: the height it is built at), the one nearest `height` by ratio that loads; none: &"".
func _nearest_height(versions: Dictionary, height: float) -> StringName:
	var best: StringName = &""
	var best_gap := INF
	for v: StringName in versions:
		var gap := absf(log(maxf(height, 0.01) / float(versions[v])))
		if gap < best_gap and mesh_of(v) != null:
			best = v
			best_gap = gap
	return best


## How block `b`'s props are laid: its named prop's lay (FIT unless model_lays says), else its kind's.
func lay_of(b: MapData.Block) -> Lay:
	if b.dress != &"":
		return model_lays.get(b.dress, Lay.FIT)
	return kind_lays.get(b.kind, Lay.FIT)


## Where block `b`'s box is still drawn behind its props (model_cores): (side inset m, share of its height), or zero
## when it isn't drawn at all.
func core_of(b: MapData.Block) -> Vector2:
	return model_cores.get(b.dress, Vector2.ZERO) if b.dress != &"" and dresses(b) else Vector2.ZERO


## Prop `model`'s mesh, or null when its model is missing or holds none (loaded once a path).
func mesh_of(model: StringName) -> Mesh:
	var path: String = models.get(model, "")
	if not _meshes.has(path):
		_meshes[path] = load_mesh(path)
		if _meshes[path] == null:
			push_warning("PropDressConfig: %s's model \"%s\" won't load; its blocks stay boxes" % [model, path])
	return _meshes[path]


## The first mesh of the model at `path` (a .glb scene), or null.
static func load_mesh(path: String) -> Mesh:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	if root == null:
		return null
	var found := root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	root.free()
	return mesh


## Whether block `b` is drawn as props laid by TILE, with its backing behind them.
func backs(b: MapData.Block) -> bool:
	return lay_of(b) == Lay.TILE and dresses(b)


## The depth (m) of TILE's rows on block `b`'s faces: x for the rows along x (on its two faces across z), y for the
## rows along z; 0 where a face is too short for a row.
func tile_depths(b: MapData.Block) -> Vector2:
	var along_x := minf(tile_skin, b.size.z * 0.5) if b.size.x >= tile_min_face else 0.0
	var along_z := minf(tile_skin, b.size.x * 0.5) if b.size.z - 2.0 * along_x >= tile_min_face else 0.0
	return Vector2(along_x, along_z)


## The box round every block of `map` that names `model` (SET: one structure's blocks), or an empty one when none does.
static func set_box(map: MapData, model: StringName) -> AABB:
	var box := AABB()
	var first := true
	for b in map.blocks:
		if b.dress != model:
			continue
		var each := AABB(b.center - b.size * 0.5, b.size)
		box = each if first else box.merge(each)
		first = false
	return box

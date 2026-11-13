# Map models

Blender build scripts for the maps' own models (Dev 3), each writing one vertex-coloured prop to
`assets/models/props/` (one `Prop` material, palette colours linear; a lamp's lens keeps a material of its own). `mapkit.py` holds the shared palette, the vertex-colour bake, the export and the triangle report
for the hall shell (DH1); `prop.py` does the same for the racking and small props (RK1), painting by palette name with
a foot-to-top gradient (`render_prop.py` renders a built prop from labelled angles); `woodkit.py` holds Woodland's
shared parts (bark, logs, split ends, leaf clumps, fronds) and its colours, each checked off the team hues as the tests
measure them (WG2); `timberkit.py` holds the Woodland structures' timber paints, logs, boards and beams, and their
blocks read from `data/maps/woodland.json` (rerun a structure's script after `tools/woodland/build_map.py`, WG3).

| Script | Writes | Drawn as |
|---|---|---|
| `hall_wall.py` | `hall_wall.glb`, `hall_shutter.glb`, `hall_exit.glb` | Depot's 8 m hall walls, bay by bay (`PropDressConfig.Lay.BAY`) |
| `steel_pillar.py` | `pillar.glb` | Depot's pillars (fitted to the block) |
| `camo_net.py` | `camo_net.glb` | Depot's net walls, a 2 m section a cell |
| `roof_truss.py` | `roof_truss.glb`, `roof_lamp.glb` | Depot's roof bays and lamps (`RoofView`) |
| `pallet_racking.py` | `pallet_racking.glb`, `_b`, `_c` | Depot's tall racks, three bays taking turns (`PropDressConfig.variants`) |
| `kit_rack.py` | `kit_rack.glb` | The Range's kit rack (its block names it) |
| `steel_drum.py`, `pallet.py` | `steel_drum.glb`, `pallet.glb` | Depot's drum blocks, nine stacks on a pallet (CLUSTER) |
| `plastic_barrel.py` | `plastic_barrel.glb` | Depot's barrel blocks, two a block (ROW) |
| `sofa.py`, `office_desk.py`, `steel_locker.py` | `sofa.glb`, `office_desk.glb`, `steel_locker.glb` | The Lounge's sofa, the Offices' desks and lockers (fitted) |
| `palisade.py` | `palisade.glb`, `palisade_rail.glb` | Woodland's fences, stake by stake (`PropDressConfig.Lay.STAKES`) |
| `watch_tower.py` | `watch_tower.glb` | Woodland's watch tower, one model over its blocks (`Lay.SET`) |
| `footbridge.py` | `footbridge.glb` | Woodland's North bridge (`Lay.SET`) |
| `sawmill_shed.py` | `sawmill_shed.glb` | Woodland's Sawmill shed (`Lay.SET`) |
| `hut_roof.py` | `hut_roof.glb`, `hut_roof_long.glb` | Woodland's hut roofs (fitted to the block) |
| `fern.py`, `bush.py` | `fern.glb`, `bush.glb` | Woodland's ferns and bushes (`BushView`), stretched to each plant |
| `fallen_log.py` | `fallen_log_5.glb`, `_6.glb`, `_8.glb` | Woodland's fallen logs, the nearest length (`PropDressConfig.Lay.GROUND`) |
| `root_plate.py` | `root_plate.glb` | Woodland's wind-thrown trees (`Lay.GROUND`) |
| `cordwood.py` | `cordwood.glb`, `_b`, `_c`, `boards.glb` | Woodland's woodpiles, a 2 m section a cell, the three mixed (`Lay.GRID`, `variants`); B site's boards (`Lay.GROUND`) |
| `sawbench.py` | `sawbench.glb` | Woodland's B site saw bench (`Lay.GROUND`) |
| `earth_bank.py` | `earth_bank.glb` | The earth under a grounded prop where the ground falls away |
| `log_tunnel.py` | `log_tunnel_side.glb`, `log_tunnel_roof.glb`, `log_tunnel_mouth.glb`, `log_tunnel_cap.glb` | Woodland's crouch tunnels, a 1 m hollow-log section a block (`Lay.SIDE`, `Lay.LINED`; a run's end sections the mouth) |
| `culvert.py` | `culvert_wall.glb`, `culvert_kerb.glb` | Woodland's culvert under the road |
| `pickup.py` | `pickup.glb` | Woodland's pickup wreck (grounded) |
| `tyre.py` | `tractor_tyre.glb`, `tractor_tyre_stack.glb` | Woodland's tyre stacks (grounded) |
| `campfire.py`, `lantern.py` | `campfire.glb`, `lantern.glb`, `lantern_post.glb`, `lantern_chain.glb` | Woodland's fires and lanterns (`LightFixtures`, no collider) |
| `pine.py` | `pine_young.glb`, `pine_grown.glb`, `pine_old.glb` (each with its `_crown`) | Woodland's pines, the age by the tree's height (`PropDressConfig.Lay.TREE`) |
| `oak.py` | `oak.glb`, `oak_crown.glb` | Woodland's hand-placed oaks (TREE) |
| `birch.py` | `birch.glb`, `birch_crown.glb` | Woodland's birches (TREE) |
| `spruce.py` | `spruce.glb` | Woodland's thickets, a spruce a 1.5 m cell (GRID) |
| `far_tree.py` | `forest_tree.glb`, `skyline/treeline.glb` | The wood past Woodland's fence (`WoodsConfig.forest_model`) and the skyline's treeline band (`SkylineConfig.treeline_model`) |
| `skip_wagon.py`, `ballast_wagon.py`, `engineering_wagon.py` | `skip_wagon.glb`, `ballast_wagon.glb`, `engineering_wagon.glb` | Subway's works train, each wagon on the station's running rails (SM4) |
| `platelayer_trolley.py` | `platelayer_trolley.glb`, `_short`, `_long` | Subway's trackside trolleys, the size by the box (SM4) |
| `buffer_stop.py` | `buffer_stop.glb` | Subway's buffer stops at the tracks' west ends, facing the track (`facing`) |
| `cable_drum.py` | `cable_drum.glb`, `cable_drum_small.glb` | Subway's cable drums (SM4) |
| `tunnel_segments.py` | `tunnel_segments.glb` | Subway's stacked tunnel-lining segments (SM4) |
| `cabinets.py` | `signal_cabinet.glb`, `switch_cabinet.glb` | Subway's trackside signal cabinet and plant-room switch cabinets, shut (SM4) |
| `staff_booth.py` | `staff_booth.glb`, `_mid`, `_small` | Subway's platform booths, facing the platform's edge (`facing`) |
| `works_hoarding.py` | `works_hoarding.glb`, `_short`, `_deep` | Subway's works hoardings on the platforms, a closed compound (SM4) |
| `fan_housing.py` | `fan_housing.glb` | Subway's plant-room fan housings (SM4) |
| `escalator.py` | `escalator_upper.glb`, `escalator_lower.glb` | Subway's escalator banks, each over its ramp and middle barriers (`Lay.SET`) |
| `lift.py` | `lift_car.glb`, `lift_landing.glb`, `lift_landing_lit.glb`, `lift_leaf.glb`, `lift_button.glb` | Subway's lifts (`LiftView`: the car turned to its door, a doorway at each stop, the leaves and buttons scaled to each) |
| `spiral_stair.py` | `spiral_stair.glb` | Subway's spiral stair over its ramps and landings (`Lay.SET`; the core stays the station's pillar) |
| `platform_stair.py` | `platform_stair.glb` | Subway's stair to the platforms over its two flights (`Lay.SET`, its handrails `set_heads` over the box) |
| `railing.py` | `railing_bar.glb`, `railing_top.glb`, `railing_foot.glb`, `railing_post.glb` | Every bar railing's pieces (`RailingMesh`, `MapStyle.railing_look`), fitted to the bars and rails a BB meets |
| `station_lamps.py` | `strip_lamp.glb`, `tunnel_lamp.glb` | Subway's ceiling strip lamps (`RoofConfig.plain_lamp_model`, turned along their rooms) and the running tunnels' bulkhead lamps (SM5) |
| `station_extras.py` | `cctv_camera.glb`, `way_sign.glb`, `fire_extinguisher.glb`, `litter_bin.glb`, `edge_sign.glb`, `platform_clock.glb`, `poster_a..d.glb`, `name_board.glb` | Subway's look-only extras (`StationFixtures`, spots from `tools/subway/fixtures.py`) |
| `ticket_gate.py` | `ticket_gate.glb`, `gate_paddle.glb` | Subway's gate line, a slim pedestal a block with 1 m lanes between, and the paddle door GatePaddles swings in each lane (SM3) |
| `ticket_machine.py` | `ticket_machine.glb` | Subway's row of four ticket machines (SM3) |
| `kiosk.py` | `kiosk.glb`, `kiosk_long.glb` | Subway's shuttered kiosks, the hall's and the concourse's (SM3) |
| `ticket_office.py`, `booking_counter.py` | `ticket_office.glb`, `booking_counter.glb` | Subway's closed ticket office and the booking hall's counter (SM3) |
| `help_point.py` | `help_point.glb` | Subway's help point and map columns (SM3) |
| `station_bench.py` | `station_bench.glb`, `station_bench_long.glb` | Subway's benches, three seats and four (SM3) |
| `crowd_barrier.py` | `crowd_barrier.glb` | Subway's crowd barriers (SM3) |
| `train.py` | `train_body.glb`, `train_lights.glb`, `train_door.glb`, `train_door_glazed.glb`, `train_door_glass.glb`, `train_windows.glb`, `train_gangway.glb`, `train_end.glb`, `train_end_outer.glb`, `train_cab.glb`, `train_cab_open.glb`, `train_seat.glb`, `train_seat_short.glb`, `tool_cart.glb`, `train_bogie.glb`, `train_cab_leds.glb`, `train_end_leds.glb` | Subway's trains (SM1): each car's body, lamp strips, shut doors (the platform side's glazed) and window glass, its ends and their white LED lamps (cab front shut or open, blank, uncoupled; under a train's end its underframe and coupler) and the gangways, drawn by `TrainView` from the map's `dressing.trains` (where the train's box meets the ground, `StationSurface` lines it in its tunnel's finish); the seats, tool carts and the bogie under each train end are named blocks (FIT). A car is 22k triangles with its doors and seats, a bogie 3k |

Subway's stairs, escalators, lifts and railing (SM2) share `transit_kit.py`: their paints, a mesh builder with boxes,
sweeps, lathes, tubes round filleted paths, knobs and rings, and `report`, which writes the model and fails it over its
budget or off its box by more than 5 mm. The steps' cleats and nosings are drawn by the props' shader (`map_kit.ribbed`:
UV.x under -1 draws ribs 8.5 mm apart).

Subway's lamps and extras (SM5) share `stationkit.py` (a mesh builder in the game's axes: `Prop`, `Lens` and `Sign`
faces, a printed face's UVs into the sign sheet) and `station_cells.py` (the sheet's cells); `station_signs.py` draws
the sheet itself (`assets/textures/station/signs.png`, every word invented) and `station_render.py` renders the
models for review with their glass lit and their print on.

The trees share `treekit.py`: stems, limbs, foliage clumps and spruce tiers with crown-lit normals, and the build gates
(budget, no team hue, the trunk inside its foot radius, the crown only over the clearance outside it). A tree's trunk
and crown are written apart (`export(..., crown=True)`): the game stretches the trunk to its box and scales the
crown evenly over it.

Run each with Blender 5.x or pip's `bpy` (`pip install bpy==5.2.3`): `python3 -I tools/blender/maps/<script>.py <repo
root>`, then `godot --headless --path . --import`. Pictures for review: `tools/prop_pictures.gd` (a model alone),
`tools/hall_pictures.gd` (Depot) and `tools/woodland_pictures.gd` (Woodland), all under xvfb; `tools/eye_pictures.gd`
for a field (`night` lights its fires and lanterns). Records: `docs/records/DH1.md`, `docs/records/RK1.md` (RK1's
scripts run as `python3 tools/blender/maps/<script>.py`), `docs/records/WG2.md`, `docs/records/WG3.md`,
`docs/records/WG4.md` (`weathering.py`: WG4's noise and repaint helpers), `docs/records/WT1.md`, `docs/records/SM2.md`,
`docs/records/SM3.md` (`hallkit.py`: SM3's face decals, shutters, louvres and tubes on `prop.py`'s Prop),
`docs/records/SM4.md` (`works_kit.py`: the works gear's running rails, underframe, weathering and box fit). Dev only: tools/ never
ships.

Task: SM1 · QA commit 57eb0b8 · Verdict: Pass

Blocking: none. Advisory: none.

Hunt (attempt-4 delta be123fe..abe4794):
- Layer 1 reliance: only cull masks in game/ are OpticGlass's camera (all 20 layers minus hands and probes, so bit 16 is
  drawn: the scope still draws the station) and RoofLamps.leave_out. Decals (wear marks), reflection probes and
  LightPools lights use default masks (all layers): still reach the station mesh. LightPools shadow_caster_mask is
  all-but-fixtures: unaffected. No `layers == 1` checks on the station mesh.
- Lamps outside the cars: test_trains checks each lamp's cull mask against in_car; outside ones keep the layer, car
  ones keep bit 1 (cars and players lit).
- _round_finish: axis chosen from the face normal; x-facing faces skip _tunnel_over (uses past zone only), up/down
  faces use the tunnel-over lookup; both covered by the all-faces train-box test (16010 asserts).
- _train_round matches a zone only when a train's box (grown 1 cm) encloses it, so other maps' zones (no trains) never
  match.

Tests added:
- tests/unit/test_sm1_qa.gd:4 · the station layer is drawn by the scope camera and default cameras and shares no layer
  with hands, probes, fixtures or default · fails if LAYER is moved onto a peeled-off layer or inside OpticGlass's
  exclusions (checked by reading the masks; no stub run).
- Earlier attempt tests verified by the worker: test_trains no-face-on-a-train-box-side (fails without change 1), lamp
  mask check, test_station_dress mesh layer.

Runs (single files): test_trains 40/40, test_station_dress 29/29, test_station_fixtures 11/11, test_lamp_lights 10,
test_lamp_lights_qa 5, test_worn_lamps 8, test_bp8_replicas 20, test_sg1_hip_glass_qa 9, test_look 22, test_sm5_qa 13,
test_sm1_qa all pass. Whole suite and tools/check.sh not run by me (running in background).

Not testable headless: how the cars look lit and the tunnel walls unlit by car lamps; the scope picture on screen.

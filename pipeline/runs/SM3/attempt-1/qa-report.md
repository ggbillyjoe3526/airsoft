# SM3 · QA · attempt 1

**Verdict: Pass** (blocking: none; advisory: none)

- `facing` is read only in FIT's default branch; UNIT, ROW, GRID and the other lays never see it. A bad value is
  warned and cleared; the map still loads. subway.json: 3 "+z", 3 "-z" (platform benches), 1 "+x" (concourse bench).
- Added to tests/unit/test_station_hall_props.gd: a facing on a non-FIT lay is ignored; a facing on a square box
  keeps the model inside it, its front the way named; an empty facing keeps FIT's rule; Depot and Woodland name no
  facing.
- test_station_hall_props.gd 8/8 pass (1270 asserts); with test_station_dress.gd 26/26 before the additions.
- Not tested here: how the models look (needs a display; the thread's in-game pictures cover it).

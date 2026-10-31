Task: DR2 · QA re-check at 23c670c · QA tests in tests/unit/test_dr2_qa.gd (5) · Verdict: Pass

Blocking: none. The attempt 1 blocker is fixed: PropDressConfig.dresses needs mesh_of(model) != null (loaded once a path, warns once), so a model that is there but won't load leaves its blocks as boxes.

Verified: every core_of caller passes the map; sandbag stacks keep the same transform through _box_to; each prop lands in exactly one chunk (totals match at chunk 20, 0.5, 7.3, 1e9, 0, -5); every rack's footprint is rows or backing on Depot and the Range; building and freeing PropDress three times leaves no orphans; shelving casts no shadow.
Passing: test_props 14, test_dr2_qa 5, test_site_dress 14, test_dd1_qa 23, test_map_level 15, test_baked_light 12, test_saved_configs 1.
Advisory: a failed model is cached as null for the config's life; chunk <= 0 isn't validated (one odd cell, no loss).

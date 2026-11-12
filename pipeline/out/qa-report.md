Task: none (MQ2) · QA commit <none, uncommitted> · head 0aeb2a6 · Verdict: Pass

Blocking: none.

Advisory
- Figure copies sit at exactly 600 triangles (aeg redDot/scopeVar, pistol and smg silencer, smg redDot/scopeVar, sniper grips and optics): at the budget, not over; any added detail there breaks it. No real part is at 10,000.
- Pre-existing, unreachable today: `apply(..., OWN, surfaced=true)` on a `*_Figure` copy would surface the torch reflector, LED and laser lens (copies carry no table). figure_view.gd:288,326 and mag_toss_view.gd:124 pass surfaced=false.

Checked against b6d2f17 by parsing the glb JSON (all five parts files and inside/aeg.glb)
- Node names, mount transforms, material-name lists per part and per `_Figure` copy are identical, except the pistol silencer node (already explained: it now sits on pistol.glb's Muzzle mount).
- No mesh carries extras other than `surfaces`; no node, material or accessor carries extras; no `_Figure` copy has a table.
- Triangles: no hands part at or over 10,000; no copy over 600.
- assets/models/replicas/*.glb: `git diff b6d2f17..HEAD --stat` shows no change, so the replica's own AEG magazine is untouched.
- The silencer's front cap pin holes are in the part's Rubber material (the silencer uses Detail, Metal, Rubber only): drawn on the rubber surface in its own colour in every paint, never the paint's.
- Laser lens, torch reflector and LED, optic glass: never surfaced in any paint, Realistic on or off, surfaced or plain (sweep over 13 paints). The `polished` look change (relief 0, cloud 0) leaves the table and kind order unchanged; barrel inside test still passes.

Tests added to tests/unit/test_mq2_qa.gd (now 7 tests, 14,809 asserts, all pass)
- :`test_no_part_is_over_the_triangle_budget_and_carries_only_the_surfaces_table` · reads every mesh's triangle count (parts under 10,000, copies at most 600) and its extras keys · fails if a part grows past the cap, a copy gains a table, or a stray custom property is exported.
- :`test_a_silencers_dark_rubber_cap_details_keep_their_own_colour_in_every_paint` · the pin holes' Rubber stays in its own colour in all paints on aeg, pistol and smg · fails if the paint covers it or the surface is dropped.
- Earlier five tests unchanged.

Run (one godot process at a time, targeted): test_mq2_qa, test_part_surfaces, test_barrel_models, test_attachment_models, test_magazine_models, test_magazine_wear, test_replica_surfaces, test_replica_paint: 74 tests, 74 pass, 17,499 asserts; test_mag_share and test_mh3_qa (thrown and dropped magazines, the tossed mag): 42 pass. The barrels' inside picture loads (test_barrel_models). No full suite, no import, no smoke test (gate running).

Not tested: how the new detail looks, and the tossed magazine in motion (needs a display / the owner). Nothing committed by me.

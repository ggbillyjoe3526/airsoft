Task: MQ2 · Attachments, magazines and barrels made of what the real ones are
Attempt: 2 of 4
Head: e50955e (verdict holds only if part 7, the smoke test and the notices pass on this head; part 1's ba1 fix read and fair)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment: check 1 only)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] Most of attempt 1's points are answered. Real detail is added: wrench flats and pin holes on the silencers, a ridged bezel, grooves and a battery door on the torch, a window, screws and a coin-slot cap on the laser, ribs, seam and welds on the hi-cap, a target crown on the barrels. Polished is now clean (replica_surfaces.gd:+96-97). The grip is measured against vertical_grip/ (the record: 1.70 against the photo's 1.39 clamps, which is the owner's "a little longer"). It still fails model check (b) in the change's own close-ups:
   - The hi-cap's three BBs are visibly faceted, with a stepped silhouette and jagged highlight (p3/after/hitop.png). Their lathe profile has about 3 points (aeg.py, the "BB" lathe, `10 if fine == 1 else round_bb`).
   - The low-cap's BBs were made coarser (16 → 14 segments) to pay for a mould line you can barely see (magazines.py:+HICAP_SHAPE/LOWCAP_SHAPE "round_bb": 14). That trades the most-seen curve for the least-seen detail. The magazine top is in front of the camera on every reload and in the Loadout picture.
   - The tight bore's outer crown chamfer shows polygon steps along its bright rim (p3/after/bore.png, upper right).
   The folded feed lips (aeg.py:+lips) read the same before and after in hitop.
Must-fix for the next attempt:
- BBs on every magazine part (aeg, sniper, smg, pistol files): a rounder profile (more rings) with smooth normals, so the silhouette and highlight are round in the hitop close-up. Restore the low-cap to at least 16 segments: take the triangles from the mould line or from the stipple, not from the BBs.
- The tight bore's chamfer: enough segments (or smooth normals across it) that its rim highlight is one unbroken ring at that close-up.
- Re-render hitop, a low-cap top, and the bore close-up, before and after.
Advisories (not blocking):
- Flat steel faces mirror the studio sky as a flat white plate: the red dot's clamp jaw (p3/after/dot.png, under the hood) and the torch's clamp bevel (torchf.png). Both are hidden by the rail when fitted; worth a glance on the turntable.
- In Wolf grey the aluminium optics, silencer and torch now draw near-black, against grey before. This is consistent with MQ1's approved receivers (gain 0.68) but is a visible change for players who chose grey. It is on the owner's checklist, phrased as a question.
- aeg.glb is at 96.7 % of its 4 MiB cap (138 kB left), and the part budgets are within 54 triangles: the next detail pass must buy room first.
- QA: the figure copies sit at exactly 600.
Owner should test in the game:
- Customise turntable in Wolf grey, Tan and Cobalt: do the optics, silencer and torch read as anodised metal, and are you happy that grey paint goes near-black on them?
- Reload the AEG with the Hi-Cap, then the Low-Cap: can you tell steel from polymer, and do the BBs look round?
- The vertical grip at 64 mm on the AEG and the Sniper: long enough? (The left hand sits high until the arms thread refits it.)
- Torch and laser up close: the battery door, coin-slot cap, window and screws read well; the lens and reflector are not painted.
- The Loadout's barrel pictures: one clean highlight on each crown.

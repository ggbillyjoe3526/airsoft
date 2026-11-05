Task: none (BL8) · QA commit fc0d184 · Verdict: Pass

Blocking: none.

Advisory
- optic_redDot (aeg.glb, sniper.glb): looked at along the bore, the base/rear block covers the lower half of the glass disc (rays 3.7 mm or more below the sight line hit the housing at z 0.0065 to 0.023; the disc is at z -0.0125, radius 7.5 mm). The dot at the disc centre and the upper half are clear, so aiming works, but the glass shows as a clipped half-moon in play. The owner should eyeball the aimed red dot (needs a display). The 2x and variable scopes are clear over the whole disc.
- The 2x and variable scopes' rubber/detail eyepiece rims stand within 0.2 mm of the disc plane but not in front of it (held by the test).

Tests added: tests/unit/test_attachment_models.gd (11 tests, load the real glb files)
- budgets: every part under 10,000 triangles, every file under 2 MB, each part has a _Figure that is smaller.
- marker empties: optic _SightLine, muzzle _Muzzle, laser/torch _Beam, _UnderLaser on pistol/cyber torches only.
- red dot sight line (0, 0.104, -0.025) in aeg and sniper space; every sight line on its lens centre; optics on the bore plane.
- glass discs: rays down the bore through the window (centre and 0.9 of the radius) hit nothing in front of the disc and hit glass within 2 mm behind it; fails with the old viewmodel_config (checked: 2 of 11 fail with the base commit's config).
- glass radius inside the lens, glass_z inside the optic, eye_back set for all three optics.
- torch beam at its TorchLens centre and lens face on aeg, pistol, cyber, sniper; AEG/sniper torch out on the right rail pointing forward; laser beam at LaserLens.
- sniper carries the AEG's attachment models (same triangle counts) with its silencer further out.
- materials: named from the known set; ReplicaPaint (two schemes) leaves Lens, LensDot, Fibre, TorchLens, LaserLens and Rubber unpainted.

Existing part tests all pass: parts_in_play 15, customise_parts 24, variable_scope 10, sniper_rifle 11, torch 26, attachments 17, at3_qa 14, torch_qa 11 (log pipeline/out/qa/parts.log).
Game code reading part meshes (replica_pictures bounds, replica_paint, replica_parts) needs no change; nothing in game/ reads the _Beam empties (torch_beams uses constants).

Not tested: barrels and magazines byte-identical to the base (not diffed), tools/check.sh and the smoke test (not run), how the optics, torch and laser look (needs a display).

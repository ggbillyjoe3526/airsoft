Task: none (BL8) · head 4a17278 · Verdict: Pass
Run: no match run (the only code change is tools/blender/parts/attachments.py, a build script that never ships; a unit test was added; no GPU in the container) · budget: no baseline yet, judged against docs/CC0_ASSETS.md > Size limits, the targets and base 106a53f
Metrics (measured, from the glTF JSON of each .glb; 0 images in all, so no VRAM or import cost):
- File size: aeg 1,339 KB, sniper 1,250 KB, pistol 521 KB, cyber 93 KB / 2 MB limit (ok). Was 1,208 / 1,090 / 322 / 109 KB at 61dc3d6; total about 4.4 MB of the 500 MB install.
- Triangles per part, max: optic_scopeVar 9,960 / 10,000 (ok, 0.4 % margin; was 9,912). scope2x 6,388, grip_vertical 5,192 (was about 3,500, stipple studs), redDot 5,510, pistol max 4,926, cyber max 3,066. No part over the cap.
- Surfaces per part, max: 6 (scopeVar), 5 (pistol, cyber), 4 (redDot, scope2x), 3 (grip_vertical). Unchanged except the torch gaining a Led surface (the last report had 4).
- Worst-case AEG fit (scopeVar + vertical grip + torch + hiCap mag + silencer + barrel): about 20k part triangles, 24 part surfaces (24 extra draw calls, 1 blended). It fits the 40,000 hands cap only if the body is under about 20k (judgment: body not counted).
Regressions (> 10 % worse): none at runtime. Asset growth is by design (pistol +62 % in file size, grip about +48 % in triangles).
Blocking findings: none.
Advisory:
- Prewarm (measured by reading, not drawn): play_session.gd:737 view.materials() is the FlagView's (inside the ATTACK_DEFEND branch, lines 728-737), not the replica parts. replica_view.gd:100 prewarm_glass() returns only held.window.material. shader_prewarm.gd draws only the materials it is handed as specks. So the fitted parts' own materials (metal, polymer, Lens, LensDot, Fibre, Led, reflector) are not prewarmed (judgment: whether they share an already-listed material was not checked).
- They are still drawn before play for the replica in hand: replica_view.gd:274 shows only the active slot, and the hands are visible from the first frame (line 144), while the match holds for the prewarm (play_session.gd:1220). So the active replica's parts compile during the hold, not mid-match. A part's material first shows mid-match only on a first swap to the other slot, a first fire-mode or attachment change, or the torch Led and the blended LensDot lit for the first time (judgment, not verified, no GPU). Godot 4.x compiles pipelines asynchronously via ubershaders, which softens the hitch.
- Because it is 4.4 MB of geometry with 24 draw calls, a rendered check on the Low preset (F3 overlay, Sniper with every part fitted) is still worth doing.
- optic_scopeVar has 40 triangles of room: any more detail needs a trim.
- The diff adds no per-frame or per-tick allocation, nodes, timers or connections to free (measured by reading the diff).
Fixes: none required. Ranked if a first-swap hitch shows: (1) append each held replica's part materials (ReplicaParts.Fit) to the list in replica_view.prewarm_glass(); (2) make the inactive slot's parts drawn once during the hold.
Unexplained: none. Frame time and draw calls need the owner's rendered run.

# Performance: HS1 (681450b..HEAD 9252cee), rest_on_back

Verdict: Pass (no per-frame cost; one-time costs, one nit below).

Measured headless, Godot 4.7.2, Time.get_ticks_usec, throwaway script (deleted). Dev-machine numbers; a slow laptop
may be 2 to 3x.

- Load-time _back_rest (inside FigureModels.load_kinds, both kinds): 55 to 61 ms total, once at start-up. Fine.
- First hold, rest_on_back, per replica body mesh, kind 0 (the humanoid with kit):
  - aeg Body 30,996 tris: 67 ms
  - sniper Body 27,843 tris: 59 ms
  - pistol Body 29,028 tris: 50 ms
  - cyber Body 24,480 tris: 48 ms
  - small parts (flash hider, mag, sights, figure proxy): 0.3 to 5 ms each
- Kind 1 (robot, empty back_rest) returns at once: 0.01 ms.
- Cached repeat call: 0 to 13 us (Dictionary hit). Cost is about 2 us per triangle at the 1.5 cm sample.
- Per frame: rest_on_back is called only from figure_hands setup (game/play/figures/figure_hands.gd:139), never from
  process/physics. Nothing per frame, no allocation in a loop beyond the one get_faces() copy per first call
  (about 30k tris * 3 * 12 B = about 1.1 MB PackedVector3Array, freed after the call).

Does the first-hold hitch matter?
- A match has 12 figures but a handful of distinct meshes (4 bodies at most, cached per kind per Mesh): worst case
  about 60 to 70 ms once per distinct replica, or about 225 ms total if all four replicas are equipped by figures at
  spawn (spread over whatever frames the figures are built in). It happens at figure set-up, not mid-fight, if the
  figures are built during the round start/loading; a single 60 ms frame there is invisible.
- Risk to watch: if a bot's loadout is first built in the middle of a live round (e.g. a replica drawn for the first
  time while the match runs), that is a single 50 to 70 ms frame (about 4 frames dropped at 60 Hz). Not a fail,
  at most a one-off stutter.

Nit (can wait): Body meshes alone are 25 to 30k tris at 2 us each; sampling each triangle at 1.5 cm is far finer than
needed for a cell of 1.5 cm on mostly large flat faces. If a stutter is ever seen, warm the cache in loading
(call rest_on_back for each replica mesh once after load_kinds) or sample coarser. No change needed now.

Cached state: back_lift is Dictionary[Mesh, float] keyed on the mesh; holds Mesh refs (shared resources, not freed
per match), no leak. back_rest is built once; no orphan nodes or duplicate signal connections seen in the diff.

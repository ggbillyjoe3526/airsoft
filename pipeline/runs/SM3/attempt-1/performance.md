# SM3 · performance · attempt 1

**Verdict: Pass** (no --perf capture: no GPU in the cloud container; judged from the numbers and the code)

- Draws on Subway: about +13 on the main pass (11 new MultiMeshes, one per model, and Depot's crate and locker),
  up to about +26 with shadow passes on High; Low about +13. Small against the 150 High target.
- Triangles: the 11 props add about 49.2k (ticket_machine 9.3k, placed once), the crates and lockers about 20 to
  40k more: under 0.1 M against 1.5 M.
- Install: the 11 .glb files are 1.4 MB (ticket_machine.glb the largest, 522 KB): 0.3 % of 500 MB.
- Material: every new model shares the prop material (no roughness or wear entries): no new shader permutation.
- Allocations: `facing` is read at map load and at layout only; nothing new per frame. New views are PropDress's
  children, freed with it; no timers, tweens or connections.
- Advisory: no LOD for the 9.3k ticket machine (not needed at these sizes); read Subway's real draws from F3 on the
  owner's hardware.

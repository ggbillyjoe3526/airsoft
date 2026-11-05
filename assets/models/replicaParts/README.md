# Replica parts

A replica's fittable parts as `<replica id>.glb` (glTF binary): the AEG's and the GBB Pistol's (RM1, RM7), and the Cyber
Pistol's torch (RM8). Each part is one top-level object named `<kind>_<id>` (`optic_redDot`, `magazine_hiCap` …) in
the replica's space where it fits. How to make them: [docs/CC0_ASSETS.md](../../../docs/CC0_ASSETS.md) › Replica
models. The attachments (optics, grips, silencers, laser, torch) are built from the owner's photos by
`tools/blender/parts/attachments.py` (BL8); the AEG's two barrels (an inner barrel in its hop-up unit, the long one
with its outer extension) by `tools/blender/parts/barrels.py` (BA1); the magazines by the replicas' scripts and
`tools/blender/parts/fit_parts.py`; the Sniper Rifle's file from the AEG's by `tools/blender/replicas/sniper.py`.
Record every file in [docs/ASSETS.md](../../../docs/ASSETS.md).

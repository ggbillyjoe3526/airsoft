Task: BL6 targeted rerun · head 229bd55 (e7725d6..HEAD) · Verdict: Pass
Method: parsed assets/models/replicas/cyber.glb with python3 -I (numpy), against e7725d6 (the last passed head) and
origin/main (74cdd35). No Godot, no check.sh (CI runs the unit tests). No tests added; nothing under game/ touched.

1. Bones and clips: Pass.
   - Against e7725d6 the only differences in the whole file are the trigger bone and its mesh node: bone translation
     y 0.0165 -> 0.0045 (z -0.0125, x 0), the Trigger mesh node -0.0165 -> -0.0045, the trigger's inverse bind matrix
     (origin column y -0.0165 -> -0.0045) and the trigger translation keys in Fire, Selector, Reload and Inspect
     (every key moved by exactly -0.012 in y). All other bones, node transforms and inverse bind matrices are identical.
   - Rotation keys of the trigger are identical to e7725d6 (Fire peak x -0.14936, w 0.98878 = -17.18 deg about X).
     Against origin/main they differ by at most 7.5e-5 in a quaternion component (0.009 deg), which arrived with the
     earlier BL6 rebuild, not with this change; harmless.
2. Game and tests do not read the trigger bone: Pass. find_bone is used only for "selector" (selector_pose.gd),
   "slide" (slide_lock_pose.gd), the sight-fold bones and figure_graph.gd's path lookup (the figure rig, not cyber).
   No "trigger" bone name in game/ or tests/ (hits are comments and the input flag).
3. Trigger inside the guard opening: Pass. Trigger mesh (302 vertices, mm in model space) spans y 1.2 to 8.4,
   z -36.7 to -11.1, |x| <= 2.8. At rest and at the Fire peak (rotated -17.18 deg about the bone at y 4.5, z -12.5),
   all 224 vertices below z -16.5 lie inside GUARD_HOLE, the nearest 1.85 mm (rest) and 1.88 mm (peak) from its edge.
   The 78 vertices above it lie inside TRIGGER_SLOT (y -8..13, z -26..-8, half width 3.4), and |x| 2.8 < 3.4.
   At the peak the blade reaches y -2.9, z -36.1: clear of the opening's back (-11.5) and floor (-40).
   Body vertices in the trigger corridor (104) are all on the slot's walls (x = +-3.4); none inside the blade's path.
4. Figure mesh: Pass. The new frame outline (13 points, GUARD_LOOP[:5] plus floor, grip and tang) has no crossing
   edges and no vertex touching another edge: a simple polygon (clockwise, area 11468.5 mm2). In the glb, welded by
   position the Figure is a closed manifold (144 vertices, 240 triangles, no duplicate or unpaired edges, positive
   volume, no degenerate triangles). Each side plane (x = +-15.8) holds 11 outward triangles whose area sums to the
   polygon's exactly (11468.5), so none overlap or are flipped; the other 2 triangles per side face inward (the
   window prism's base), hidden.
5. Empties, materials and clips: Pass. Against e7725d6 the empties (Muzzle, MagWell, SlideBack, TorchMount, FrontSight,
   RearSight, the lower-case bones), material names and order, mesh primitives and clip lengths (Fire 0.1333, Selector
   0.2, Reload 1.1, Inspect 2.0) are identical. Against origin/main the clip lengths and the five material names are
   the same (the list order differs, and primitives index it by name-order); the empties are the same except two
   differences that predate this rerun and passed before: the Figure node has no -0.3 y offset any more, and
   FrontSight and RearSight are listed in a different order (same positions).

Blocking findings: none. Advisory findings: none new.
Not testable here: how the trigger and guard look and reach in the owner's hand, and the figures' pistol in play
(needs a display); the Godot import of the rebuilt glb and the unit tests (CI).

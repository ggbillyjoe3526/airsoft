# TP1 · The replicas the figures hold, made from the hands' models

**Review:** critic Accept (art round 3; code 7/8, attempt 2) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | figure tests green locally | Revise | the GBB's slide streak and small shapes, the Cyber's accents, the scope's red strip, the AEG's grip |
| 2026-11-05 | 2 | Claude (build thread) | figure tests green locally | Revise | the GBB's slide-top shading, the Cyber's "III", ring and screen dots, the laser's lens; reported specks |
| 2026-11-05 | 3 | Claude (build thread) | tools/check.sh | art Accept; code Retry 6/8 | the well's magazine stayed through a reload; `figure_meshes` dead; a third `"Figure"` constant; docs (KNOWN_ISSUES FI row, DECISIONS, figures README) |
| 2026-11-05 | 4 | Claude (build thread) | tools/check.sh | code Accept 7/8 | – (check 7: magazine_node's comment, fixed in the same push) |

## What was asked

Bots held each replica as an old hand-made block of 120 to 340 faces (known issue AT3, now closed), so a fitted part
showed over the standard magazine or flash hider, and the iron sights stayed up under an optic. Make the figures'
replicas from the Blender models in the hands, with the parts they have fitted.

## What changed

- **`tools/blender/replicas/figure_copy.py`** (new) makes the `Figure` copy from the hands' model at the end of each
  replica script (aeg.py, gbb.py, cyber.py, sniper.py): every mesh in its rest pose; the BBs dropped; flat runs
  merged; the faces no outside ray reaches dropped (96 directions); cut down by Decimate's collapse to a budget, with
  material borders kept; shaded smooth with edges over 15° hard and the normals weighted to the big faces. The pieces a
  part replaces or folds are children: `Figure_Magazine` (in the Magazine's own frame), `Figure_FlashHider`,
  `Figure_Sights`.
- **Markings** (the accent and glow materials: a front post's tip, a fibre, a lens, the Cyber's lines, core and window
  bars, the GBB's stipple) are cut down apart, kept whole when they fit in half a piece's budget, keep their small
  pieces, and move out past the cut-down body along their facing.
- **`tools/blender/parts/figure_parts.py`** (new) remakes every part's `<part>_Figure` the same way. It runs last,
  after every script that writes a parts file.
- **`ReplicaParts.fit_figure`** fits the figure's parts as `fit` does on the model in the hands: a magazine part hides
  `Figure_Magazine` and is the figure's reload magazine; a muzzle part hides the flash hider and moves the muzzle out;
  a barrel moves the flash hider and muzzle with it; an optic hides `Figure_Sights`. `FigureView` uses it.
- **The reload** hides the magazine in the replica's well while the well is empty (FigureHands), so a figure never
  shows two; the hand's copy is the fitted magazine part's when there is one.
- The Cyber's two window bars have their own material, `CyberBar` (the metal's look), so the copy keeps them.
- Tests: `tests/unit/test_figure_copies.gd` (budgets used, pieces, places, fitting, the reload magazine);
  `test_figure_raise.gd` measures the replica with its pieces.

## Decisions

- **Budget: 3,000 triangles a replica**, the documented figure limit (`docs/CC0_ASSETS.md` › Size limits), used in
  full (owner rule: about 95 %). Split per piece in each script's `FIGURE_TRIS`.
- **A part's copy:** 15 % of its own triangles, kept between 120 and 600 (900 until main's magazines and barrels
  filled the AEG's parts file; its cap is 3 MiB, as BL8b's #216 sets it, since the copies take it to about 2.2 MB); a
  magazine part as many as its replica's own figure magazine (read from the replica's model file, so the two can't
  drift apart).
- **A barrel keeps its own copy** (`figure_parts.py` OWN_COPY): BA1's `barrels.py` builds the tube that shows past the
  handguard in a few faces, as the part's inner barrel and hop-up unit take its 10,000 triangles nearly to the last.
- **Hard edges at 15°** (25° left a shading wedge across the GBB's slide top).
- **Specks** the critic saw in round 2 were checked by rendering on magenta and flood-filling from the border: the
  only enclosed background was the real openings, so they are highlights, not holes.

## Known issues left

- Can wait (critic): the GBB silencer copy's octagon facets show as highlight lines close up; the AEG grip's finger
  grooves are simplified. Neither shows at play size.
- The figures' support hand on the AEG sits past the handguard, and the rifles are held high: the next change (the
  owner's 2026-11-05 rifle-hold request).

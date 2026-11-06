# GS2 · GBB slide at rest, the slide from the owner's photos, AEG sights and stock

**Review:** critic auto-accept 7/8 (owner's extra round, 2026-11-05 19:42) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | green | Retry 7/8 | serration widths, pitch and positions off the photo (scale misread); nose blend; barrel face flush |
| 2026-11-05 | 2 | Claude (build thread) | green (targeted) | Retry 7/8 | grooves 2.75 mm wide with square tops; barrel 1.8 mm proud with a flat crown; spring hole fused to the barrel; kink at the nose; sights and bore height off the photo |
| 2026-11-05 | 3 | Claude (build thread) | green (targeted) | Retry 7/8 | the slide's nose lip under the barrel missing, so the spring hole was 3 mm; barrel 12 mm across (photo 14); muzzle opening small; crown shading |
| 2026-11-05 | 4 | Claude (build thread) | green (targeted) | Retry 7/8 | the lip 10.1 mm under the slide's foot (photo 11.9); the spring a smooth tube; the channel's walls 0.6 mm |
| 2026-11-05 | 5 (owner allowed one extra round, 19:42) | Claude (build thread) | green (targeted) | 7/8, shipped on the owner's extra-round choice ("review once more, then merge") | locked back the spring showed in front of the slide (fixed after: the rod rides with the slide); the dust cover's square front (in KNOWN_ISSUES) |

## What the owner asked (2026-11-05)

- The GBB Pistol's slide shows pushed back in screenshots; it may only be back while firing or with the magazine
  empty. Firing, only the slide moves and the barrel shows. Match the slide to his new photos
  (`art/references/replicas/gbb-pistol/william-2026-11-05/`): lines at the front and back, a chamfered front, slightly
  rounded edges.
- The AEG Rifle's iron sights smaller and more subtle (the rear especially), still easy to line up on a target.
- With any optic fitted, iron sights removed completely, not folded: the AEG and the Sniper now, every later replica
  too.
- The AEG's stock without the half-cylinders on each side.
- The AEG's charging handle moved down a little, not enough to clip, still pulling clear back without obstruction.

## Cause of the slide

`pistol.glb` itself rests with the slide home. Blender's glTF importer makes the file's first clip (`Fire`) the active
action, and Blender's scene starts on frame 1, where the slide is 25 mm back mid-shot; and the build scripts left their
NLA tracks live after `clips()`, so the last track (`SlideLock`, held past its end) posed the slide back in anything
evaluated later in the build. Every review render and figure copy made by importing the file showed the slide back.

## What changed

- **Rest pose.** `hardsurface.rest_pose(arm)` ends every replica's `clips()` (no active action, tracks muted; the
  exporter still writes every track, the files are byte-identical for it). `hardsurface.import_glb(path)` imports a
  replica at rest; `attachments.py` and `fit_parts.py` use it.
- **GBB.** The barrel and spring guide are their own mesh (`Barrel`) on the frame, not the slide, so firing and locked
  back the barrel shows in front of the slide; the guide rod runs back the slide's travel. The `Inspect` clip no longer
  press-checks the slide (it keys it home). The slide from the new photos: 7 grooves at each end, 2.6 mm wide (about the
  ridges' width) with square tops cut up through the top's rounded edge, 5.0 mm apart, the first front one 13.8 mm
  behind the face, the last rear one 9.4 mm before the back (measured on the side view, 2,560 px wide, the slide 142 to
  2,255 px: 0.088 mm a pixel); the nose chamfered 2.4 mm in over its last 6 mm on top and both sides, blended into the
  flats over 3 mm, its corner growing from the top's own 2.2 mm fillet to 3 mm at the face so no kink where it starts
  (was 1.6 mm at 45°); the top edges filleted 2.2 mm (were chamfered); the back face's edges rounded 2.2 mm; five fine
  lines across the rear cover plate. The nose lip, as the photos': under the barrel the face drops 11.8 mm below the
  slide's side, 3 mm deep and 14 mm wide with rounded bottom corners, in front of the dust cover, whose front now sits
  3.4 mm behind the face and which has a channel the lip runs back in as the slide cycles. The lip holds the recoil
  spring's 10.4 mm hole (about 2.2 mm of metal under and over it, 1.8 mm beside) with the guide rod's flat cap and its
  centre hole; the rod rides with the slide, so locked back nothing but the barrel shows in front of the slide, as the
  owner's locked-back photos. The channel's walls stand 1.2 mm beside the lip (the rail slots 3.9 mm deep, were 4.5).
  The barrel is 14 mm across with a flat crown round a 9.4 mm opening, the inner barrel's bore recessed 3 mm behind it;
  it stands 1.7 mm proud of the face, its bore 48 % down the face (was 54 %). 39,250 triangles in the hand (budget
  40,000): the slide's edge bevel is one segment, which pays for the five-segment top fillet; the barrel is turned with
  32 segments. `test_gbb_slide.gd` checks the lip's drop, the dust cover behind it and the spring hole's size.
- **AEG sights.** The sight line drops from 2.45 to 1.7 cm over the rail (`SIGHT_Z` 0.0905), so the front ears and
  post drop 7.5 mm with it. The rear sight is new: a low clamp (31 mm long, 3.5 mm over the rail) with a thin wing
  either side of a 3.2 mm leaf whose top is a ghost ring (8.4 mm hole, 1.8 mm wall) on the sight line, a hinge pin, a
  cross bolt nut and a windage knob. The whole rear sight hangs from the `rearSight` bone (its base had been in the
  body, so it stayed under an optic).
- **Iron sights under an optic.** `SightFold` (fold, then shrink) is gone; `IronSights.of(model)` returns the bone
  attachments of every bone whose name ends in `Sight`, and `ReplicaParts.fit` hides them with any optic (undone by
  `unfit`). No per-frame modifier is needed, since visibility outlives the clips. The `SightsFold` clips are gone from
  the AEG and the Sniper. `tests/unit/test_iron_sights.gd` fits an optic to every model with an `OpticMount` and checks
  that both sights hide whole and that nothing else rises over the rail between the sight points.
- **AEG stock.** The battery tubes and their caps are gone; the body is flat-sided.
- **AEG charging handle.** Lowered 3 mm (`CH_Z` from 66.5–75.0 to 63.5–72.0 mm) so it tucks under the rail's back
  end. Checked by BVH overlap at rest, 25 mm and 50 mm pulled: no overlap with any other mesh, nearest 0.4 mm.
- **Triangles.** AEG 37,784 (was 36,424 without the tubes: the barrel, buffer tube, front sight collars and flash
  hider turned with more segments to use the budget, ~95 %). Counts are the replica in the hand; each file also holds
  the bots' `Figure` copy (pistol 120, AEG 352), so the files total 39,370 and 38,136.

## Defaults taken

- The pistol's sights keep GS1's size and place (merged in #211 after the owner's sight-picture fixes), not the
  photos' (front base 7.5 mm long and 3.8 mm tall, rear 4.2 mm tall and 8.8 mm from the back; in KNOWN_ISSUES):
  their height sets the sight line and the aimed eye, so changing them reopens the owner's approved picture.
- The GBB's barrel stays level when the slide is back (a real one tips down): the replica's barrel is fixed, and it
  reads cleanly.
- The Sniper keeps its own flip-up sights (only the AEG's were asked to shrink); they hide whole under an optic like
  the AEG's.
- Inspect (IN1, merged first) eased the GBB's slide 16 mm back; it now stays home there too, and the pistol's two
  slide clicks went with it: the owner's rule is the slide is back only firing or locked empty.
- The parts files are untouched: `gbb.py` and `fit_parts.py` would rewrite them, but nothing in them moved, and the
  open part pull requests own them.

## Known issues

- None open from the bots' copies: merged over TP1 (#220), the four replicas rebuilt (their figure copies now cut down
  from these models, `Figure_Sights` hidden under an optic), `figure_parts.py` rerun; its copies in the parts files
  came out a few bytes off main's even for the unchanged Cyber, so main's parts files stay.
- Main's export broke with TP2 (#228): `HitFit.cheek_turn` named `HitConfig`, which preloads `hit_fit.tres`, a cycle
  an exported build can't load (`Could not preload resource file "res://game/config/hit_fit.tres"`, smoke test dead).
  Fixed here: `cheek_turn` takes the two angles as numbers. Reproduced and checked with a local `--export-pack` run.

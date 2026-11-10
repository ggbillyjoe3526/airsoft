# CS2 · The Compact SMG's model

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (build thread) | one test failed (the reload showed the left forearm), fixed | Retry 6/8 | the stock read as a flat plate, the receiver and handguard as boxes, aimed the irons hid the post; docs |
| 2026-11-10 | 2 | Opus 5.5 (build thread) | targeted tests pass | Retry 7/8 | the near-eye shapes shaded as flat facets, the pad a block; QA and performance reports; no reload picture |
| 2026-11-10 | 3 | Opus 5.5 (build thread) | gates 1-4 pass, stopped for the owner's changes | Accept 8/8 | – (the owner's version-3 changes followed) |
| 2026-11-10 | 4 | Opus 5.5 (build thread) | targeted tests pass (218 + QA's 4); full gates in CI | Accept 8/8 | – (the owner's version-4 and version-5 changes, the wear; performance: the wear mask VRAM-compressed as the AEG's) |

## Decisions

- **The owner's ask.** His five photos of a classic roller-delayed 9 mm sub-machine gun (07:04, "Create an initial
  model based on this MP5 smg"), "You can add small rails for attachments" (07:07) and three magazine photos (07:09).
  Saved to the project files' `art/references/smg/`. Generic: no maker's marks, selector pictograms or stamps.
- **Traced from his side photo** (`4-side-right.jpg`, the right side, stock collapsed) at 2.33 px per mm (its 550 mm
  collapsed length), lined up so the grip's front just under the trigger guard sits where the AEG Rifle's is at the
  hand's height (as the Sniper Rifle, BL5): the grip rakes 30 degrees as the AEG's and is 12 mm deeper, so the hold is
  the AEG's with the web and little finger 1 cm further back.
- **Defaults the owner may change.** The stock collapsed (his side photos; compact, and the butt stays clear of the
  eye). The curved steel magazine (his polymer one with a window could be a second magazine part later). The small
  rails: a short top rail on a low claw-style mount for the optics, a short rail each side of the handguard's front
  half (laser left, torch right) so the left hand holds the bare handguard behind them; no under rail (it takes no
  grips). Aimed with the irons (attempt 2): the drum's aperture opened to an 11 mm ghost ring that frames the front
  sight's hood, the replica held 15 cm ahead of the eye (the AEG's 20 put the stock's end in the lower screen), the
  top rail's mount lowered and the sight line 2 mm higher than traced, so the rail stays 5 mm under it and the whole
  post shows (a true-size aperture filled the view with the drum).
- **Shapes (attempt 2, the critic):** the stock's pad 47 mm wide against its arm's 37, rounded 9 mm all round; the
  receiver's strut channels round-bottomed and 3.6 mm deep; the handguard's sides bowed 1 mm, rounder underneath,
  with a 1.6 mm lip round its front. Attempt 3: the pad's sides bowed 2.5 mm (an elliptic section), the receiver's
  roof in 24 facets, the rear sight's base rounded across its top, the end cap rounder.
- **The owner's changes on version 2 (09:23-09:25):** the grip, trigger guard and trigger housing welded into one
  moulding (the grip flush with the housing's sides where it leaves them); every rail 3.2 mm lower (6.8 mm base to
  teeth); the stock's outline corners rounder; the barrel shown through the gap between the handguard and the front
  block; the drum sat down in its base's raised front step; the cocking handle one turned bolt-like piece with a
  knurled round-ended knob.
- **The owner's changes on version 3 (10:14):** the handguard runs up to the front sight block (no gap), the barrel
  one piece from inside the receiver to the block; the housing's back runs down into the grip's back strap, the
  grip's top square where it leaves the housing, a curved web in the corner at the grip's front, and the guard's
  rear end inside the grip, so the three read as one moulding. On version 4 (10:22, "still a gap between the handle
  and body. It's one solid piece"): the grip starts inside the housing (its top had stopped at the housing's foot,
  a hairline gap at its front), the housing exactly the receiver's width, and the housing, grip and guard welded
  into the receiver as one mesh (smg.py `weld`, which keeps their Furniture paint).
- **Wear (the owner, 10:19, after RW1):** lightly used as the AEG Rifle, `wear.apply(seed=3, heavier={"Magazine": 2.5})`
  after the figure copy, so the magazine wears most and the bots' copy stays plain; the receiver's ribs and the rail
  slots keep only a broken fringe of grime (`art/smg/smg-wear-closeups.jpg`).
- **Clips.** Fire is one trigger pull at 18 a second; Selector safe, semi at half, auto at the end (no burst);
  Reload keeps the AEG Rifle's timeline (the game plays it as a share of the reload, and the arms' magazine change and
  `reload_carry` are keyed to those shares), but it comes up 6 cm through a reload, not the AEG's 10, so your left
  forearm stays below the screen (the deeper grip holds the hands lower); Inspect pulls the cocking handle back, flicks it up into its notch, holds
  it and slaps it down and home.
- **Its parts file** is the AEG's optics, laser, torch and silencer moved onto its own mounts (smg.py `build_parts`),
  then `figure_parts.py` (FILES now lists `smg`) cuts their figure copies; the other replicas' parts files are left
  as they were.
- **The stand-in goes.** `model = &"aeg"` is dropped from `smg.tres`; `ReplicaConfig.model` stays for any later
  replica that needs one.
- **The review tool draws dev replicas** (`tools/render_replica_view.gd` turns Dev content on), so the SMG and the
  Sniper Rifle can be pictured in first person.

## Known issues left

- The Loadout's Performance sheet still shows neither pace nor moving spread (`docs/KNOWN_ISSUES.md`).
- How it feels in the hands (the hold, the aimed ghost ring, the inspect) is on the Dev 3 checklist for the owner.

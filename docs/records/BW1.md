# BW1 · Your right hand works the Sniper Rifle's bolt; the arms fitted to GS2's replicas

**Review:** critic Accept 8/8 (owner ruling on the art, 2026-11-06 17:05) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-06 | 1 | thread | arms tests pass | Retry | the hand lay flat over the knob, index straight; palm-up flash; snap back to the grip |
| 2026-11-06 | 2 | thread | arms (13), BW1 QA (3), grenade arms and model picture tests pass; full arms build clean | Retry 6/8, then Accept 8/8 | the wrist bends to about 53 degrees on the knob and the hand leaves the screen at the hip mid-cycle; no changelog note or wiki line. The owner (17:05): "just add it to the game as it is": the art taken as it is (KNOWN_ISSUES), the note and the wiki line added |

## What the owner asked (2026-11-06, bug pass thread, 13:39 and 13:41)

- Re-fit the AEG's right hand to the AEG model GS2 rebuilt (#226), so a rebuild of the arms no longer needs the model
  from before it (`BL_FIT_AEG`), the hand looking as he approved it.
- Fix "no hand on the sniper bolt": the right hand works the bolt in first person.

## Cause of the AEG twist

Not GS2's model. `Collider.dist` takes its sign from the nearest face's normal, and a point beside a convex corner
(the AEG's trigger guard on GS2's model, the grip's right side on the one before it) is nearest a face whose normal
points away from it, so it read as 4 to 14 mm inside the replica. The hand's roll search then turned the hand away
from the false contact; on the model before GS2 the misread happened to fall where the approved roll was clear. A
point that reads deeper than `DEEP` (4 mm) is now checked by `Collider.inside` (three rays; most must strike a face
from behind); a point outside is given its distance back.

With the corners read truly, the free search finds slightly different rolls and thumbs on the AEG, the GBB and the
Cyber, so the approved ones are pinned: `rolls` (the GBB's -6°, the AEG's 0°) and the new `thumb_turn` (the thumb's
across, twist, bend and knuckle turn, which skips its search). The AEG and the Cyber render as approved side by side;
the sniper solves exactly as before.

## The owner's notes on the way (2026-11-06, this thread)

- The GBB's trigger finger "looks broken ... It should be straight and resting on the trigger" (15:39, his rear view
  circled: the finger bowed up and out at its knuckle; "the side view is ok"). The AEG "is OK": unchanged.

## What changed

- **The GBB's trigger finger**: the hand sits 3 mm lower on the grip (its three marks), so the finger reaches the
  trigger nearly straight. New hold keys on `Hand.onto`: `index_from` (the base never bent back), `index_bends` (each
  joint's most bend: 70, 75, 35) and `index_left` (the tip kept 5 mm short of the trigger's far side). A pinned finger
  (`index_turn`, the AEG's as approved) skips the search. The Cyber keeps its own marks and keys, no longer inheriting
  the GBB's; the bombs' holds (GT1, built on the GBB's) clear the GBB's pins and keys and solve as before (their bones
  match main's to 0.1 mm).
- **The bolt clip** (`tools/blender/arms/cycle.py`): for a replica with a `bolt` bone, `sniper_Fire`, 0.25 s longer
  than the replica's `Fire` clip (1.0 s). The right hand's fingers open as it draws off the grip (out to the side
  first, then back), it is carried up and out round the stock's side and hooks the knob in its curled index finger,
  the knob's centre at the centre of the finger's curl and the other fingers in a loose fist past the knob's end; its
  turn about the handle is searched for the glove clear of the replica with the straightest wrist (27° as it takes the knob, rising to about 53° as the bolt comes back), then the
  thumb's turn whose tip closes nearest the knob. It rides the knob up, back, forward and down (turning half the
  bolt's turn so the wrist never rolls over the receiver's top, where the scope sits) and returns the same way, the
  fingers closing on the grip once the hand is there. Each key is checked for the arms passing into the replica;
  a finger sweeping off or onto the grip is bent the least either way that clears it, else the bend that leaves the
  least of the glove in it.
- **The game** (`ArmsView.follow`): each frame ReplicaView passes the replica's AnimationPlayer; while it plays `Fire`
  the arms play `<id>_Fire` at the same point, then let it run on to its end (the hand back on the grip) once `Fire`
  has ended; another clip cutting in (a reload) puts them back on the hold. Replicas without a bolt clip are untouched.
- **The build**: `BL_FIT_<STEM>` removed; the KNOWN_ISSUES rows for it and for the missing bolt clip removed, one
  added for the fitted scope.

## Decisions

- The hand turns half the bolt's lift (`ROLL_SHARE`): the whole turn put the wrist over the receiver's top, through a
  fitted scope (attachments are not in the build's collider).
- The reach takes the clip's first 0.13 s (the replica's bolt starts lifting at 0.15 s); the hand is back on the grip
  0.25 s after the replica's clip ends (the rifle is ready at 1.25 s at the earliest).
- The knob is hooked in the index finger rather than taken overhand (the critic: an overhand hand left the index
  lying straight along the receiver) or pinched (the pinch put the hand beside the knob, not round it, seen from the
  eye).

## Known issues

- A fitted scope is not in the build's collision check; the hand is kept below the receiver's top by its path only.
- The wrist bends up to about 53 degrees as the bolt comes back, and at the hip the hand is half off screen mid-cycle
  (the critic, attempt 2; the owner took it as it is). A test of turning the hand on the knob each key (the wrist
  straightest, the arm clear of the stock) held it under 30 degrees; not built.

# HG1 · The bots' hands hold their replicas as the first-person arms do

**Review:** critic Accept 8/8 · qa Pass · performance Pass (by the owner's ruling on the cost, 2026-11-06 18:51)

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-06 | 1 | Claude (BP4 thread) | parts 1-4 green | Retry 6/8 | The handguard read from vertices only (the Sniper Rifle with a grip held on its barrel); the thumb 1 cm into the handguard; no README rows; QA and performance not yet in |
| 2026-11-06 | 2 | Claude (BP4 thread) | targeted green | Retry 6/8 | The Sniper's fingers into its side rail and barrel (a round, not the outline); the cross-section helpers in FigureHands |
| 2026-11-06 | 3 | Claude (BP4 thread) | targeted green | Retry 4/8 | The stretched thumb and the figures' glove (the owner kept the glove); no QA or performance report yet; a switch didn't let go (QA); the fingers doubled the skeleton's cost (performance) |
| 2026-11-06 | 4 | Claude (BP4 thread) | targeted green | Retry 6/8 | Performance: 11 figures +13.5 % over main (fingers now only near, one reach update an arm); the thumb and index as the owner approved them on the labelled picture; the per-slot hold arrays gathered (FigureHeld) |
| 2026-11-06 | 5 | Claude (BP4 thread) | green (one fix: a pistol's left arm stretched at a wall) | Accept 8/8 | Performance +9.8 % in all, skeleton +15.8 % a figure: the owner accepted the cost (18:51) |

## Background

BP4's close-up pictures (2026-11-06) showed the support hand off the AEG Rifle's handguard (its grasp bone 3 cm under
the handguard's middle and 7 cm past the grip mount) and the fingers of both hands left as the clips put them, a
splayed claw. The owner asked for both to be fixed (2026-11-06 13:37).

On attempt 2's pictures the owner wrote: "That looks worse… They all look wrong… The issue is with the right hand.
It's not gripping the guns properly. And the finger needs to be resting on the trigger… the thumb needs to be on the
left of the handle/grip… I gave reference photos for a reason."

Attempts 1 and 2 curled each finger chain procedurally until it touched the replica's surface. The fingers bent too
far and twisted, and the skin swelled at the joints. The right hand also sat on the grip turned about 90° from a real
grip, so no curl could put the thumb on the grip's left side or the index finger on the trigger. The owner's photos
(`ref_images.zip` › hands/holding_replica) show the grip he wants. The first-person arms (BL4) already hold every
replica that way, and he approved those holds.

On attempt 3's first pictures the owner asked "what is happening with the thumb? and only one hand for the pistol",
then "the thumbs are missing" (circled where they should be). The figures' thumbs are a third shorter than the arms'
(6.7 cm against 10.4 from root to tip), so copying the arms' turns left the thumb tip inside the grip. Pistols had kept
TP3's second fist; he wants them one-handed, as the first-person hold is. Attempt 3's critic (Retry 4/8) also found the
stretched thumb too long and the figures' glove plates breaking into shards; the owner then kept the bots' own gloves.
On attempt 4's labelled picture (`playtest/hg1/bot-hands-final.jpg`) the owner wrote "perfect" (2026-11-06 16:37).

## What changed

- **The bots' hands copy the first-person holds** (FigureArmsHold, FigureGrasp). `arms.glb` carries one hold per
  replica: its clip `<id>_Hold` and its empty `Hold_<id>` where the replica's origin sits. FigureModels reads each
  hold once a session at its clip's first frame. It reads each hand's turn and knuckles (Middle1's root) in the
  replica's frame, and each finger and thumb bone's turn against its hand.
- **On the figure,** each hand is brought by FigureReady's two-bone reach to that turn. The reach now reads the arm's
  frames once and sets each bone over its parent's new frame (it worked the skeleton's frames out after each bone),
  which TP3's grip fit shares. The right hand's place is set
  by its thumb's root, where the arms' is (`hold_thumb_share` 1), then turned `hold_wrap` (0.35 rad) round the grip
  about its knuckle line, so the thumb's root comes round the back strap. The left's is set by its knuckles
  (`hold_thumb_share_left` 0), so its fingers reach up the handguard's side. Each finger bone is turned as the arms'
  is against the hand, then aimed at the arms' next joint (the figures' fingers are shorter), so the fingertips go
  where theirs do.
- **The thumbs** reach their tip as far along the arms' last thumb bone as they can, and the two inner joints follow
  (FABRIK, six passes). The thumb lies along the grip's left side, high under the receiver; on the Sniper Rifle it
  comes over the stock's wrist.
- **The fingers are worked out once a hold** (FigureGrasp.Closed): a hand on the replica sits the same way on it
  whatever the body does, so each bone's turn over its parent is kept until the hold or the hand's place changes, and
  each frame only blends the clips' turns toward them. They close only within LOD0's line of the eye (FigureView sets
  FigureBody.near); past it the hand still holds the replica but keeps the clips' fingers. Out of the camera's view
  (FigureView's `_seen` through `in_cone`: a cone round the view's corners, widened by a 1 m ball round the chest, looked at every 4th
  frame, the figures staggered by id) the hands keep the clips' and the replica its clips' place; the hold's easing runs on, so it is in place when the figure shows.
- **Each slot's hold is one FigureHeld** (FigureHands.held): the arms' hold, both hands' places, the left's shift and
  the replica on the grip bone as the clips hold it and as the hand holds it; FigureBend hands it to FigureGrasp.
  - **The right hand** holds the replica whenever it is in the hand: high on the grip, fingers round it, index on the
    trigger, thumb along the grip's left side.
  - **The left hand** holds a rifle under its handguard: fingers up its right side, thumb along its left. On the
    Sniper Rifle it is the open-palm rest the owner approved for first person. A pistol is held in one hand: the left
    takes the first-person pistol hold's lowered left arm, in place of TP3's second fist. That left hand goes with the aim alone: in the high
    ready at a wall it lets go (it isn't on the replica, so the raised pistol would carry it out of the arm's reach).
  - **Behind a fitted grip** (the rifle model's `GripMount`), the left hand moves straight back until its knuckles are
    `support_behind_grip` (4.5 cm) behind the grip's back end (FigureView.support_mark), and the marks its fingers aim
    at move with it.
- **The replica stays where the clips and TP2/TP3 put it.** FigureGrasp reads where the replica is before it moves
  the hand. FigureHands then hangs the replica from the moved grip bone by the place the hold gives it
  (`held_on_grip`), blended by how far the hold is in.
- **Easing:** the right hand eases in with the aim and the left with a rifle's aim. Both ease in over
  `settle_support` (0.08 s) and out quicker over `settle_support_off` (0.025 s), so a reload's clip reaches for the
  magazine at once. Both let go in a switch, a throw (GT1) and calling the hit; the left also in a reload.
- **Removed:** attempt 2's finger curl, the mesh cross-sections (ReplicaSection) and their settings.

## Decisions

- **The first-person holds are the one source.** The owner approved them finger by finger, and both rigs share bone
  names and axes. Now a change to a hold in `tools/blender/arms/pose.py` changes the bots' hands too
  (`assets/models/arms/README.md`).
- **The right hand is aligned by its thumb's root, the left by its knuckles.** The figures' Grip bones sit further down
  the hand than the arms'; lining those up left the palm low. Lining the right hand's knuckles up left its short thumb
  buried in the grip ("the thumbs are missing"); lining the left's thumb up curled its fingers into a fist under the
  handguard.
- **The thumb is not lengthened.** A runtime stretch (1.3 times) reached the arms' thumb tip but read as too long and
  swollen next to the owner's photos; turning the hand `hold_wrap` round the grip brings the thumb out instead.
- **The bots keep their own gloves** (owner, 16:31: "keep it as then. that's fine"). A rebuild of the figures' gloves
  to match the first-person glove (one knuckle shell, no finger plates) was tried and put back; the bots' gloves are a
  simpler model in a smaller budget.
- **Pistols are one-handed** (owner, 2026-11-06 15:36: "only one hand for the pistol"), as the first-person hold is.

## Checks

- `tests/unit/test_hands_on_replica.gd`:
  - The arms model has a hold, with every finger, for all four replicas.
  - For each replica, the drawn right hand is within 5 mm and 0.05 rad of its place on the replica, each finger bone
    points within 0.05 rad of the arms' next joint, the thumb's tip is within 1 cm of the line of the arms' last thumb
    bone, and it is on the grip's left side.
  - The left hand passes the same check on the AEG Rifle and the Sniper Rifle.
  - A pistol is held in one hand (the left lowered, over 20 cm from the right), and a reload lets go.
  - A switch lets go with both hands (QA, attempt 3).
  - Behind a vertical and an angled grip, the left hand and its finger marks move straight back, and it is held the
    same way.
- Close-up pictures of the AEG Rifle, Sniper Rifle and GBB Pistol from several sides, posted in the thread before the
  pull request (`playtest/hg1/bot-hands-final.jpg`, each picture labelled with what to look at).
- `test_figure_hands_qa.gd`'s "in the fist" gap is 3.5 cm (was 3): the palm now wraps the grip's side, so the palm's
  line runs a grip's half-width off its middle (3.08 cm on the pistols).
- `tools/figure_bench.gd`, 11 figures, 30 s, pinned to one core (`taskset -c 1`; unpinned runs drifted 10 %),
  alternating with main. Performance's runs: both together 2.195 ms against 1.999 (+9.8 %), skeleton per figure 47.9
  us against 41.4 (+15.8 %), animation +8 %; the worker's own: +3 %. The hands' own work is about 10-17 us a figure in
  view. Looking at the view every frame cost about 10 us a figure (the camera and viewport calls), hence the 4-frame
  stride. Attempt 3 worked the fingers out every frame (90 us); attempt 4's reviews measured +13.5 % with every figure
  holding, seen or not.
- **The owner accepted the cost** (2026-11-06 18:51, on the question "Accept the bots' new hands costing about 10 %
  more figure time?": "Accept the cost and merge"), over simplifying the fingers to within about 8 m. Performance's
  skeleton line stands at +15.8 % by his ruling.
- Left for the figures batch: the glove's knuckle plates show small shards on a deep bend (KNOWN_ISSUES).

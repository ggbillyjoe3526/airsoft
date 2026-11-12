# Stats: how every replica and part performs

The performance numbers of every replica, power source and part: muzzle energy, BB weight, rate of fire, magazines
and handling. [pool.md](pool.md) is the register of what exists (IDs, names, tags) and [levels.md](levels.md) the level
that unlocks each; this file says how each of those things shoots and handles. There is one of each item: what a row
says is what everyone who has it gets.

**The game reads this file**, the same way it reads pool.md: it is bundled into the build and parsed when the game
starts (`game/config/replica_stats.gd`). Change a number, run the game, and it changes, for bots too. After editing,
run `tools/unit_tests.sh`: `tests/unit/test_replica_stats.gd` reads this file and fails with the line number of anything
it can't understand. A cell the game can't read keeps its built-in number, with a warning in the game's log (Godot's
output), so a typo never stops the game from starting.

One hit is still one hit. Nothing here is "damage": energy changes how fast and how far a BB flies, the rest how a
replica handles.

---

## How to read and edit this file

- **Rows** are matched by their first column: a replica or part by its **Key** (as in pool.md's Key column), a power
  source by its pool.md **ID**. The **Name** column is only there to make the table readable; pool.md's name is the one
  shown.
- **Column units.** `(×)` columns multiply a time or an amount: below 1 is quicker or smaller, above 1 slower or
  bigger. `%` columns add that share on top (10 is 10 % more, −10 is 10 % less).
- **New rows.** A new replica or part needs its pool.md row and a row here. A brand new behaviour (a new Key) needs
  code first.

### Muzzle energy and BB weight

**Energy (J)** is the muzzle energy with the replica's factory BB weight (**BB (g)**), the way a site's chrono rates
it. With the BB weight it sets the speed the BB leaves the barrel at (E = ½·m·v²). Other BB weights shift the energy a
little (a heavier BB takes more of the push); every BB weight is free and picked on the Loadout's slider. What happens
to the BB after it leaves the barrel (drag, hop-up lift, spin) is in `game/config/ballistics_config.gd`.

### Power sources

What drives the replica, by type (pool.md's power source Type):

- **Battery.** Sets the rate of fire, as in a real AEG (the spring inside the replica sets its energy). The LiPo's
  faster cycling kicks a third harder, so a held trigger climbs off a far target sooner (RP1).
- **Gas.** Sets the energy: a stronger gas pushes harder, and kicks harder too. Green Gas is the one for quick
  follow-up shots; Black Gas reaches furthest, kicks 40 % harder and slams the slide, so it cycles a tenth slower
  (RP1).
- **Spring.** Sets the energy, as a gas does, and how hard the rifle is to cock, how hard it kicks and how far its
  shot is heard: each spring is its own trade (Which spring, under the Power sources table).

### Site limits

Like a real site's chrono, the energy a replica may leave the barrel with is capped by its **Class** (rifle, pistol, or
sniper for a single-shot spring rifle, which sites let shoot harder, as UK sites do for bolt-actions).
Stacked parts (a strong gas with a long barrel, say) stop at the limit, and the Loadout says so.

---

## Replicas

| Key | Name | Class | Energy (J) | BB (g) | Fire rate (BBs/s) | Magazine (BBs) | Magazines | Reload (s) | Draw (s) | Spread (°) | Recoil (°) | Hip spread (×) | Pace (×) | Moving spread (×) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| aeg | AEG Rifle | rifle | 0.97 | 0.25 | 13 | 60 | 4 | 1.8 | 0.45 | 0.45 | 0.18 | 1 | 1 | 1 |
| pistol | GBB Pistol | pistol | 0.52 | 0.2 | 7 | 18 | 4 | 1.0 | 0.22 | 0.65 | 0.5 | 0.8 | 1.04 | 1 |
| cyber | Cyber Pistol | pistol | 1.0 | 0.25 | 14 | 30 | 3 | 1.1 | 0.28 | 0.3 | 0.06 | 1 | 1.04 | 2 |
| sniper | Sniper Rifle | sniper | 1.9 | 0.3 | 0.8 | 25 | 4 | 2.2 | 0.65 | 0.1 | 0.4 | 10 | 0.95 | 1 |
| smg | Compact SMG | rifle | 0.75 | 0.2 | 18 | 45 | 5 | 1.4 | 0.32 | 0.6 | 0.14 | 0.75 | 1.08 | 0.5 |

- **Fire rate.** BBs a second with the trigger held (auto, and within a burst), or the fastest you can click (semi).
- **Magazines.** Carried per round, the loaded one included.
- **Spread.** The random scatter of the shots from the hip (degrees), before stance, movement and the hip spread.
- **Recoil.** The upward kick of each shot (degrees). Light: these are toys, not firearms.
- **Hip spread.** How many times wider the spread is with the sight down than with it raised (1: no difference beyond
  the usual, Accuracy's). A long rifle pointed from the hip is a guess; under 1, a compact replica is that much tighter
  from the hip.
- **Pace.** How fast you run and sprint carrying it, as a share of the usual (1.08 is 8 % faster). Holstered, the
  holster's pace stands instead. A pistol in the hand is a little lighter on your feet than a rifle (1.04), the
  Compact SMG the quickest thing to fight with (1.08) and the long Sniper Rifle the slowest (0.95) (RP1).
- **Moving spread.** The share of the extra spread that walking, running, jumping and sprinting add that it takes (0.5
  is half, 2 twice as much; standing still is as steady as ever).
- **What each replica is for** (RP1, the owner's 2026-11-12 balance pass: every replica its own strengths and
  weaknesses). The AEG Rifle is the all-rounder that takes every part. The GBB Pistol is the fastest thing to bring up
  (0.22 s), tight for a pistol and tighter still from the hip, and its gas sets its reach; against that, single shots,
  a hard kick and 18 BBs. The Cyber Pistol keeps the owner's design (docs/DECISIONS.md: rifle power with pistol
  handling, the tightest spread of the automatics and almost no kick); against that, 30 BBs a magazine and 90 a round
  (two seconds of trigger a magazine; 50 and 150 until RP1), twice the usual extra spread running, sprinting or
  jumping (one hand swings; standing, crouched or at a walk it is as tight as ever) and no parts. Until RP1 it had no
  weakness: it out-shot the AEG Rifle standing and the Compact SMG on the move. The Sniper Rifle is reach and
  precision, one shot at a time, slow on its feet and a guess from the hip. The Compact SMG is the one for shooting on
  the move.
- **Sniper Rifle** (SN1, owner 2026-11-02: like the AEG with a longer barrel, spring driven, single shot, the 2x Scope
  fitted as it comes). The long-range pick: 1.90 J with 0.30 g BBs (the heaviest the Loadout loads; 440 fps on a
  0.20 g chrono) stays within 15 cm of the aim line to about 48 m (the AEG 39 m) and gets to 50 m in 0.81 s (the AEG
  1.18 s), and its 0.10° of spread is the tightest there is. Against that, one shot every 1.25 s (the
  spring cocked by the charging handle after each one), 25 BBs a magazine, a slow reload and draw, and from the hip ten
  times the spread (six until PP1: a snap shot from the hip at 15 m still hit nine times in ten). Its class's site
  limit is the bolt-action one (below).
- **Compact SMG** (CS1, owner 2026-11-10: "a compact electric smg" that plays unlike the others). The close-quarters
  pick, built for shooting on the move: 18 BBs a second, the fastest there is, and 8 % quicker on your feet than with a
  rifle; moving adds only half the usual spread and from the hip it is 0.75 times as wide, so on the run it groups about
  30 % tighter than the AEG, and as tight as it from a standing hip. The quickest draw and reload of the rifles.
  Against that,
  0.75 J with 0.20 g BBs (284 fps) stays within 15 cm of the aim line to 27 m as it comes (31 m at its best hop-up; the
  AEG 39 m) and takes 0.59 s to fly 30 m (the AEG 0.52 s); a third wider spread aimed; 45 BBs a magazine, empty in
  2.5 s with the trigger held; and no grip, barrel or magazine parts. Semi and full auto, no burst.

## Power sources

| ID | Name | Energy % | Fire rate % | Recoil % | Heard from % |
|---|---|---|---|---|---|
| 000003 | Standard Battery | 0 | 0 | 0 | 0 |
| 000015 | 11.1 V LiPo Battery | 0 | 15 | 30 | 0 |
| 000004 | Green Gas | 0 | 0 | 0 | 0 |
| 000008 | Red Gas | 10 | 0 | 20 | 0 |
| 000009 | Black Gas | 20 | -10 | 40 | 0 |
| 000022 | M130 Spring | 0 | 0 | 0 | -15 |
| 000023 | M140 Spring | 10 | -6 | 20 | 0 |
| 000024 | M150 Spring | 20 | -18 | 50 | 20 |

- **Heard from.** How much further its shots are heard, by bots, on the minimap and in the sound cues, on top of a
  muzzle part's (−15: 15 % less far).
- **Which spring** (RP1, owner 2026-11-12: "Springs should have differences"; until then they were one ladder, 10 %
  energy and kick and 5 % of the cycle a step). The M130 is the quick, quiet spring: a shot every 1.25 s, heard from
  15 % less far. The M140 is the middle one: 2.09 J (on target to about 50 m), a shot every 1.33 s, a fifth more
  kick. The M150 is the long shot: 2.28 J, under the sniper limit (about 53 m, and 0.52 s to 40 m against the M130's
  0.57 s), paid for with a shot every 1.52 s, half as much kick again (through a scope the view jumps, so you see less
  of where the shot went) and a crack heard a fifth further.

## Optics

| Key | Name | Zoom (×) | Raise time (×) | In the glass | Zoom to (×) |
|---|---|---|---|---|---|
| redDot | Red Dot | 1.25 | 0.85 | no | 1.25 |
| scope2x | 2x Scope | 2 | 1.45 | yes | 2 |
| scopeVar | Variable Scope | 2 | 2 | yes | 6 |

- **Zoom.** How much aiming through it narrows the view (1 is none).
- **Raise time.** The time to bring it to your eye (× the iron sights'). The Red Dot is the quick sight, 0.85 (PP1:
  at 1 its slight zoom was all it gave).
- **In the glass.** yes: only the view inside its glass is zoomed (a scope); the view round it stays as the iron sights'
  (owner, 2026-10-19: no dark surround). no: the whole view zooms.
- **Zoom to.** A variable optic's top zoom (SN2): aimed through it, the mouse wheel turns it from its Zoom up to this
  (up zooms in, down out, 1× a notch: `zoom_step` in `game/config/replica_rules_config.gd`), and the zoom stays where
  you left it for the rest of the match. The same as Zoom: a fixed optic. Only an optic zoomed in the glass turns; on
  one that zooms the whole view (In the glass: no) it is ignored.
- **Variable Scope** (SN2, owner 2026-11-02: the 2x Scope, variable, a little longer): 2× to 6×, only in its glass as
  the 2x Scope; a longer, heavier scope, so slower to raise (2 against 1.45; RP1 set them further apart, 1.9 and 1.6
  before, so the 2x Scope is the quick scope and the Variable Scope the far one).

## Grips

| Key | Name | Handling (×) | Shake (×) | Moving spread (×) |
|---|---|---|---|---|
| vertical | Vertical Grip | 1.15 | 0.6 | 0.8 |
| angled | Angled Grip | 0.85 | 1.4 | 1 |

- **Handling.** The time to bring the replica up after a switch and to raise a fitted optic.
- **Shake.** How long the shake of a sprint or a landing stays in your aim.
- **Moving spread.** The share of the extra spread that walking, running, jumping and sprinting add that is left with
  the grip fitted, on top of the replica's own Moving spread (0.8: a fifth less).
- **Which grip** (RP1). The Vertical Grip is the control pick: steadier on the move and sooner steady after a sprint,
  slower to bring up (until RP1 it only cut the shake, for a quarter more handling: a bad trade). The Angled Grip is the
  speed pick: quicker to bring up and to raise a sight, and the shake of a sprint stays longer.

## Lasers

| Key | Name | Hip spread (×) | Handling (×) |
|---|---|---|---|
| redLaser | Red Laser | 0.75 | 1.05 |

- **Hip spread.** The spread with the sight down, times this, on top of the replica's own Hip spread; with the sight
  raised to your eye a laser changes nothing.
- **Handling.** The time to bring the replica up after a switch and to raise a fitted optic.
- **Which laser** (RP1). The Red Laser is the part for shooting from the hip, on the move above all: a quarter
  tighter there, for a unit on the rail that is a touch slower to bring up. Until RP1 it tightened every shot by a
  fifth at no cost, so with a rail free it was always fitted.

## Magazines

Each replica's standard magazine is how it comes (its Magazine and Magazines above); these are the alternatives.

| Key | Name | Capacity (×) | Carried (+) | Reload (×) | Draw (×) | Rattles |
|---|---|---|---|---|---|---|
| hiCap | Hi-Cap Magazine | 2 | -2 | 1.25 | 1 | yes |
| lowCap | Low-Cap Magazine | 0.5 | 2 | 0.7 | 0.85 | no |
| extended | Extended Magazine | 1.5 | 0 | 1 | 1.35 | no |

- **Carried.** Magazines carried, added to the replica's own (at least one is always carried).
- **Rattles.** The loose BBs rattle as you move, so bots close by hear you even walking.
- **Which magazine.** On the rifle, the hi-cap carries as many BBs as the standard ones in fewer, rattling changes,
  each a quarter slower (a longer, heavier magazine, RP1), and the low-cap fewer BBs in all for the quickest change
  and draw. On the pistol, the extended magazine carries half as many
  again for a slower draw.

## Barrels

Only replicas tagged `barrel-mount` in pool.md take a barrel (the AEG Rifle); as it comes, a replica has its standard
barrel.

| Key | Name | Energy % | Spread (×) | Handling (×) |
|---|---|---|---|---|
| tightBore | Tight-Bore Barrel | -5 | 0.8 | 1 |
| long | Long Barrel | 10 | 1 | 1.1 |

- **Handling.** The time to bring the replica up after a switch and to raise a fitted optic (a long barrel is
  front-heavy).
- **Which barrel** (RP1). The tight bore is the accuracy pick: a fifth tighter at no handling cost, for a little less
  energy, so a little less reach (parts are trade-offs, never straight upgrades, PP1). The long barrel is the reach
  pick: the most energy (1.07 J, 333 fps, on target to about 41 m), no tighter, and a little front-heavy (1.1; 1.15
  while it also tightened the groups). Until RP1 it tightened them nearly as much as the tight bore did, so the two
  overlapped. Its energy stays 10 %: at 15 % the factory hop-up over-lifts the faster BB out of the on-target band at
  25 m, and the dial's best is then no further than the standard barrel's.

## Muzzle parts

Screwed onto a replica tagged `muzzle-thread` in pool.md (the GBB Pistol, the AEG Rifle and the Sniper Rifle).

| Key | Name | Energy % | Handling (×) | Heard from (×) |
|---|---|---|---|---|
| silencer | Silencer | -5 | 1.1 | 0.5 |

- **Heard from.** How far away its shots are heard, by bots, on the minimap and in the sound cues (0.5 is half as
  far). A silencer's shots also sound muffled.

## Lights

A weapon torch (M33h) on any replica it fits (pool.md's Lights table), switched with the Weapon torch key. A brighter
torch is a new row.

| Key | Name | Reach (m) | Beam (°) | Spill (°) |
|---|---|---|---|---|
| weaponTorch | Weapon Torch | 40 | 14 | 28 |

- **Reach.** How far its beam lights someone well enough to be made out at night, by you and by bots (no further than
  a light pool lets them be seen).
- **Beam.** The bright hotspot's full angle.
- **Spill.** The dimmer cone round it, full angle. Anyone inside it within its reach is lit.

## Site limits

| Class | Limit (J) |
|---|---|
| rifle | 1.2 |
| pistol | 1.0 |
| sniper | 2.3 |

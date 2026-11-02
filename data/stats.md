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

- **Battery.** Sets the rate of fire, as in a real AEG (the spring inside the replica sets its energy).
- **Gas.** Sets the energy: a stronger gas pushes harder, and kicks harder too.
- **Spring.** Sets the energy, as a gas does, and how hard the rifle is to cock: the medium and high-performance springs
  shoot harder and kick harder, like Red and Black Gas, and cycle a little slower (the M150 takes the rifle to 2.28 J,
  under the sniper limit).

### Site limits

Like a real site's chrono, the energy a replica may leave the barrel with is capped by its **Class** (rifle, pistol, or
sniper for a single-shot spring rifle, which sites let shoot harder, as UK sites do for bolt-actions).
Stacked parts (a strong gas with a long barrel, say) stop at the limit, and the Loadout says so.

---

## Replicas

| Key | Name | Class | Energy (J) | BB (g) | Fire rate (BBs/s) | Magazine (BBs) | Magazines | Reload (s) | Draw (s) | Spread (°) | Recoil (°) | Hip spread (×) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| aeg | AEG Rifle | rifle | 0.97 | 0.25 | 13 | 60 | 4 | 1.8 | 0.45 | 0.45 | 0.18 | 1 |
| pistol | GBB Pistol | pistol | 0.52 | 0.2 | 7 | 18 | 4 | 1.2 | 0.3 | 0.8 | 0.5 | 1 |
| cyber | Cyber Pistol | pistol | 1.0 | 0.25 | 14 | 50 | 3 | 1.1 | 0.28 | 0.3 | 0.06 | 1 |
| sniper | Sniper Rifle | sniper | 1.9 | 0.3 | 0.8 | 25 | 4 | 2.2 | 0.65 | 0.1 | 0.4 | 6 |

- **Fire rate.** BBs a second with the trigger held (auto, and within a burst), or the fastest you can click (semi).
- **Magazines.** Carried per round, the loaded one included.
- **Spread.** The random scatter of the shots from the hip (degrees), before stance, movement and the hip spread.
- **Recoil.** The upward kick of each shot (degrees). Light: these are toys, not firearms.
- **Hip spread.** How many times wider the spread is with the sight down than with it raised (1: no difference beyond
  the usual, Accuracy's). A long rifle pointed from the hip is a guess.
- **Sniper Rifle** (SN1, owner 2026-11-02: like the AEG with a longer barrel, spring driven, single shot, the 2x Scope
  fitted as it comes). The long-range pick: 1.90 J with 0.30 g BBs (the heaviest the Loadout loads; 440 fps on a
  0.20 g chrono) stays within 15 cm of the aim line to about 48 m (the AEG 39 m) and gets to 50 m in 0.81 s (the AEG
  1.18 s), and its 0.10° of spread is the tightest there is. Against that, one shot every 1.25 s (the
  spring cocked by the charging handle after each one), 25 BBs a magazine, a slow reload and draw, and from the hip six
  times the spread. Its class's site limit is the bolt-action one (below).

## Power sources

| ID | Name | Energy % | Fire rate % | Recoil % |
|---|---|---|---|---|
| 000003 | Standard Battery | 0 | 0 | 0 |
| 000015 | 11.1 V LiPo Battery | 0 | 15 | 0 |
| 000004 | Green Gas | 0 | 0 | 0 |
| 000008 | Red Gas | 10 | 0 | 10 |
| 000009 | Black Gas | 20 | 0 | 20 |
| 000022 | M130 Spring | 0 | 0 | 0 |
| 000023 | M140 Spring | 10 | -5 | 10 |
| 000024 | M150 Spring | 20 | -10 | 20 |

## Optics

| Key | Name | Zoom (×) | Raise time (×) | In the glass |
|---|---|---|---|---|
| redDot | Red Dot | 1.25 | 1 | no |
| scope2x | 2x Scope | 2 | 1.6 | yes |

- **Zoom.** How much aiming through it narrows the view (1 is none).
- **Raise time.** The time to bring it to your eye.
- **In the glass.** yes: only the view inside its glass is zoomed (a scope); the view round it stays as the iron sights'
  (owner, 2026-10-19: no dark surround). no: the whole view zooms.

## Grips

| Key | Name | Handling (×) | Shake (×) |
|---|---|---|---|
| vertical | Vertical Grip | 1.25 | 0.6 |
| angled | Angled Grip | 0.8 | 1.3 |

- **Handling.** The time to bring the replica up after a switch and to raise a fitted optic.
- **Shake.** How long the shake of a sprint or a landing stays in your aim.

## Lasers

| Key | Name | Spread (×) |
|---|---|---|
| redLaser | Red Laser | 0.8 |

## Magazines

Each replica's standard magazine is how it comes (its Magazine and Magazines above); these are the alternatives.

| Key | Name | Capacity (×) | Carried (+) | Reload (×) | Draw (×) | Rattles |
|---|---|---|---|---|---|---|
| hiCap | Hi-Cap Magazine | 2 | -2 | 1 | 1 | yes |
| lowCap | Low-Cap Magazine | 0.5 | 2 | 0.75 | 0.9 | no |
| extended | Extended Magazine | 1.5 | 0 | 1 | 1.35 | no |

- **Carried.** Magazines carried, added to the replica's own (at least one is always carried).
- **Rattles.** The loose BBs rattle as you move, so bots close by hear you even walking.
- **Which magazine.** On the rifle, the hi-cap carries as many BBs as the standard ones in fewer, rattling changes, and
  the low-cap fewer BBs in all for a quick change and draw. On the pistol, the extended magazine carries half as many
  again for a slower draw.

## Barrels

Only replicas tagged `barrel-mount` in pool.md take a barrel (the AEG Rifle); as it comes, a replica has its standard
barrel.

| Key | Name | Energy % | Spread (×) | Handling (×) |
|---|---|---|---|---|
| tightBore | Tight-Bore Barrel | 3 | 0.85 | 1 |
| long | Long Barrel | 10 | 0.9 | 1.15 |

- **Handling.** The time to bring the replica up after a switch and to raise a fitted optic (a long barrel is
  front-heavy).
- **Which barrel.** The tight bore is the accuracy pick (tighter groups at no handling cost), the long barrel the reach
  pick (the most energy, a little tighter, front-heavy).

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

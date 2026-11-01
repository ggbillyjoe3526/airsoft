# How to Play

## The match

Two teams of the same size, **Alpha** (blue) and **Beta** (orange), start at opposite ends of a field. You play one
member of your team; everyone else is a [bot](Bots). A match is played in rounds against the clock:

- **Elimination:** take out the whole other team to win the round.
- **Attack / Defend:** the attackers raise their flag on the defenders' pole, or the defenders hold out.

The first team to <!-- wiki:config round_config.wins_needed --> round wins takes the match, and the teams swap ends at half time so neither keeps the better end.
[Modes](Modes) has the full rules, including Custom matches where you set them yourself.

## One hit and you're out

There are no health bars. **Any BB that hits you takes you out**, wherever it lands, and the same goes for everyone
else.

When a BB hits you:

1. You hear a sharp tick, your replica jolts and drops out of view, and the field's sound dips.
2. You raise your hand and call **HIT!** for a moment, so everyone can see you're out.
3. You walk off to your team's **dead zone**, round cover rather than through it. Walking off, you can't shoot and
   can't be hit.
4. From the dead zone you watch the round through a teammate's eyes until it ends.

A card on the left says **What got you**: who hit you, from how far, whether they were holding that angle and how long
you were in their view ([HUD and Minimap](HUD-and-Minimap#what-got-you)).

Bots call their hits honestly, every time, exactly as you do. When you hit someone you hear the tick, see the hit
marker round the crosshair, and they raise a hand with "HIT!" and walk off. The hit feed in the corner shows who hit
whom.

Once a round is decided it is a cease-fire: nobody can fire, and BBs still in the air hit no one. If both teams are
knocked out at once, or the clock runs out in Elimination with players left on both sides, the round is a **draw** and
is played again under the same number.

### Skipping the rest of the round

Once you're out, click (**Fire**) and the rest of the round is played out at once, unseen: a plain screen says
**Skipping the round** for a moment, then the round's result shows. Click it for the next round, which waits for you;
after the match's last round the results follow. A hint at the bottom of the screen reminds you, using your own Fire
key, and the pause menu has **Skip to next round** while you can skip. The trigger held as you were hit doesn't skip:
let go and click again.

## BBs are real projectiles

Nothing in Airsoft is hitscan. Every BB leaves the muzzle at a real speed, slows in the air, falls, and is lifted by
its backspin (the **hop-up**), so you can watch it fly and lead a moving target.

- The AEG Rifle stays on target to about **38 m**, the GBB Pistol to about **26 m**. Past that, aim a little higher.
- A white BB in flight is drawn a little larger than life with a faint short trail, so you can follow it against a
  pale wall or the sky.
- BBs puff on what they hit, in its colour: metal, wood, concrete or earth.
- A BB stops on a body, a crate or the ground. Off concrete and steel containers it **ricochets**.
- [Replicas](Replicas) differ in how fast their BBs leave the barrel, how fast they fire and how they handle, never in
  "damage": one hit is one hit.

### Wind

Every match has its own light breeze, from calm to about 2 m/s, with gusts. It pushes BBs, never players: lighter BBs
and longer shots drift further downwind. Specks of dust drift with it, so you can read which way it blows.

### Hop-up

Each replica has a hop-up dial. Press **Page Down** (less) or **Page Up** (more) to turn it during a
match. The replica panel shows the setting for a moment, with how far a level shot stays flat, or where an
over-hopped BB starts to climb. Each replica keeps its own setting until the match ends; set its starting value in the
[Loadout](Loadout). Bots keep their replicas' factory setting.

### Ricochets

By default a BB that bounces before it hits you doesn't count: you hear a tick, see **"Ricochet: play on"** and keep
playing. A [Custom match](Modes#skirmish-and-custom) can make ricochets count, and then a bounce can take out anyone, its shooter
included.

## Magazines and reloading

You carry a set of magazines, and nothing refills during a round. Press **R** to swap in your fullest spare; the old
magazine keeps what was left in it. When your magazine runs empty a trigger pull only clicks dry, and a small
**R RELOAD** prompt under the crosshair shows the key to press (it names your own key if you rebound it). With
[Settings](Settings#controls) › Controls › Reload on Automatic, an empty trigger pull clicks dry and starts a reload at
once instead. The replica panel shows a gauge for every magazine you carry, and a low magazine turns yellow. The GBB
Pistol's slide locks back on its last BB and closes as the new magazine seats.

## Aiming and accuracy

How still you are decides how tight your shots group, by the same rule for you and the bots:

- Standing still and crouched is tightest. Walking with **Shift** is almost as steady as standing.
- Running, sprinting and jumping are loosest. You can fire while sprinting, but your shots spread wide and kick
  harder.
- Aiming down the sights (right mouse) halves your spread. Every replica has iron sights; an optic replaces them
  ([Parts and Power](Parts-and-Power#optics)).
- **B** changes fire mode where the replica has more than one: single shots, 3-round bursts or full auto.

## Friendly fire

In the standard rules (Skirmish) your BBs can hit your own teammates, and theirs can hit you, so watch your line.
Bots never fire with a teammate in the way. A Custom match can turn friendly fire off.

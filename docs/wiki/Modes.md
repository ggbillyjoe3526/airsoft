# Modes

Pick the mode on the **Match** screen, with the map, your team, the [bots](Bots) and the rules. Every mode is played
in rounds against the clock, and the first team to the rounds to win takes the match. Teams swap ends at half time,
one round before the win, so the deciding round is always played in the second half.

## Elimination

The classic: **take out the whole other team** to win the round. If both teams are knocked out at once, the round is a
draw and is played again under the same number. If the clock runs out with players left on both sides, the round goes
to [the overtime flag](#the-overtime-flag).

### The overtime flag

A clock run out with players left on both sides puts a flag up near the middle of the map, and the first team to touch it, within <!-- wiki:config overtime_config.reach --> m of its foot, wins the
round. Players of both teams at it hold each other off, and a team knocked out while it is up still loses. Untouched
for <!-- wiki:config overtime_config.time --> seconds, the round is a draw, played again. Bots go for it a moment after
it goes up, still fighting anyone they see ([Bots](Bots#the-overtime-flag)). Three quick whistle blasts and an
**OVERTIME · TOUCH THE FLAG** banner say it is up; the flag rises out of the ground, a chequered off-white and dark
cloth on a short pole with a ring on the floor at its reach, and the clock shows **OT** and the flag's time left. Once
touched, its cloth and ring take that team's colour and the banner says **FLAG TOUCHED**. Attack / Defend has none.

## Attack / Defend

One team attacks, the other defends a flagpole at the defenders' end. The team you pick attacks first, and the sides
swap at half time; the Match card says who attacks first. Depot has two poles, **A** and **B**, one on each site: the
attackers win by raising their flag on either, and each pole's flag goes up and down on its own.

- **Attackers** win the round by raising their flag: stand at the pole, on the rope, for **<!-- wiki:config flag_config.raise_time --> seconds**.
- **Defenders** win by holding out until the clock runs out, or by taking out every attacker. Defenders at the pole
  pull a raised flag down in **<!-- wiki:config flag_config.lower_time --> seconds**.
- With both teams at the pole, the flag holds still.
- **Overtime:** if attackers are on the rope when time runs out, the round goes on for up to <!-- wiki:config flag_config.max_overtime --> seconds while they
  keep working it. "OT" on the clock shows what is left.

On the field a ring round the pole shows its reach: white with nobody on the rope, the attackers' colour as they
raise, the defenders' as they pull down, and yellow with both there. The flag climbs in the attackers' colour and the
rope ratchets as it moves. The HUD shows **ATK** and **DEF** tags over the scores, a **FLAG** gauge with 12 notches,
a "FLAG · 24 m" marker over the pole, and "Their flag is going up!" when you defend away from the rope. With two
poles a big **A** or **B** stands over each, the minimap shows both, and the marker and the gauge follow the pole in
play: the one being fought over, until a flag going up at the other stands higher or the fight ends; else the flag
going up; else the nearer pole. The marker reads "FLAG B · 24 m", and the warning names the flag going up ("Their flag
is going up at B!").

A map needs a flagpole for Attack / Defend; the Match screen says when one hasn't got it.

## Skirmish and Custom

Under the modes, the **Rules** section picks the rules:

- **Skirmish** is the standard match, shown as chips on the Match card.
- **Custom** lets you set every switch yourself. Your Custom setup is saved for next time.

<!-- wiki:rules -->

Custom matches never go into your records, and they pay XP at no more than the Custom multiplier
([Levels and Unlocks](Levels-and-Unlocks#earning-xp)). The team size offers only the sizes the picked map plays:
5v5 or 6v6 on both fields.

## Practice

Practice has no bots, no score and no XP, just targets and a timed challenge. It is the
[Practice Range](Practice-Range)'s only mode, and every field hosts it too, with targets where the other team would play
([Practice on a field](Practice-Range#practice-on-a-field)). While Practice is picked the Match screen shows Team, Bots
and Rules as NOT USED, and keeps your picks for your next match.

## Round flow

1. Two short whistle blasts start the round, with a banner naming the round (and in Attack / Defend, whether you
   attack or defend).
2. When a round ends, one long blast sounds and a banner says **WON**, **LOST** or **DRAW** from your side, then the
   round's table slides in with everyone's hits, BBs fired and time in play. Click to start the next round sooner.
3. Several long blasts end the match. After the last round's table, the match summary shows the result, everyone's
   numbers, your XP and records ([HUD and Minimap](HUD-and-Minimap#the-match-summary)).
4. The next match starts <!-- wiki:config play_tuning.rematch_delay --> seconds after the summary appears, or at once when you click. That click never fires a
   shot.

The pause menu (Esc) shows the map, mode and round, the match's seed, and has **Quit match** to leave: you land on the Match page, ready to play again.

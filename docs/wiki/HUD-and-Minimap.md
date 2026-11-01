# HUD and Minimap

The HUD shows what matters and nothing else: the score and clock, your replica and magazines, who hit whom, and
where your team is. It always reflects the real state of the match. Much of it can be tuned in **Settings › HUD**
([Settings](Settings#hud)).

## The top bar

Each team's score as pips filling toward the win, the round clock, the round number and the target ("FIRST TO 5").
Your team is always on the left in its own colour (Alpha blue, Beta orange), even after the ends swap at half time.
In Attack / Defend it adds **ATK** and **DEF** tags and the **FLAG** gauge, and "OT" on the clock in overtime. Big
slanted banners call the round start, half time with the ends swapped, and who took the round or the match.

## The replica panel

Bottom right: your BB count, the fire-mode chips (**S**, **B**, **A**: single, burst, auto) with the current one lit,
and a gauge for every magazine you carry, the loaded one first, then your spares, fullest first. An empty magazine
shows dark, so you can read them without colour. A low magazine turns yellow, and **HOLSTERED**, **RELOADING**,
**LAST MAG**, **OUT OF BBS** or a bomb **IN HAND** show when they apply. Turning the hop-up dial shows its setting here for a moment.

The crosshair opens with your spread, so it tells you how steady you are. Under it, a **RELOAD** prompt with your
Reload key shows while your magazine is empty and you have one to load, unless reloads are Automatic in Settings; it
goes as the reload starts.

## Hit feed and teammate markers

The hit feed (top right, or bottom left if you like) shows each hit: who fired, the BB trail, who was hit and their
red **HIT** call with a raised hand, in team colours. Your own lines say "You" and are framed in yellow, and your own
hit stays framed until the next round.

Teammates wear a chevron in your team's colour over their heads, seen through walls: solid when you can see them,
hollow when cover hides them, grey with a raised hand once they're hit. Markers never show over enemies and never
show names.

### Callouts

Your [bot teammates' callouts](Bots#callouts) share the hit feed: each of your teammates' calls is a line with their
chevron and name in your team's colour, a small radio and the words ("Rook: Two, Box yard!"). A call stays and fades
like a hit line and counts toward the feed's lines; on **Keep** the hits stay and the calls still go: a call shows on
top, and the oldest hit it moves out of sight comes back when the call goes. Every call goes when a new round starts.
Each call clicks over the radio, panned toward the teammate who made it. You never see the other team's words, but an
enemy within 15 m is heard keying their radio from where they stand, muffled by walls.

## The overtime flag

While Elimination's [overtime flag](Modes#the-overtime-flag) stands, the clock and the scoreboard show **OT** and its
time left, a **FLAG** marker with a chequered flag and the distance sits over it, seen through cover and pinned under
the minimap when it is off screen, and the minimap shows the chequered flag at its spot. A round won there ends with
**FLAG TOUCHED** and the team that took it.

## Ping markers

Your [ping](Squad-Orders#pings) is a ring in your team's colour just over the floor with **PING** and its distance
under it ("PING · 9 M"), and a soft pip in your ear. A teammate's Contact mark is a diamond in the other team's colour
over the enemy's head where they were seen ("CONTACT · 13 M"); it stays there and never follows them. A teammate
[asking for you](Bots#your-teammates-ask-for-you) pings a ring marked with what it wants: "HELP · 40 M", "GO · 25 M"
or "COVER · 30 M". Markers are seen
through cover, pop in, stay 7 seconds and fade over the last one. Off screen they are pinned inside the edge under the
minimap with an arrow the way they are. They hide while you watch a teammate, with the scoreboard up and in the pause
menu. Settings › HUD › Ping markers turns them off.

## The magazine hand-off

For [Need a Mag](Squad-Orders#need-a-mag), one line under the crosshair says what the hand-off is doing, never which
key to press: who needs a mag and how far ("Rook needs a mag · 12 m"), underlined in your team's colour once they are
close enough for a toss; whose is coming ("Brick is bringing you a mag"); what you caught ("+1 mag from Brick · 60
BBs", without the BBs while the ammo counter is off); and why a press did nothing, for a couple of seconds. The line
hides while the order wheel is open. A small magazine sits by the chevron of a teammate asking you for one or bringing
you one. Settings › HUD › Mag hand-off turns the line and the magazines off; Screen reader messages read the line's
notices.

## Scoreboard

Hold **Tab** for the scoreboard over the field while the match keeps playing: the map, mode, bots' level and team
size, the round and its time, each team's score and players still in (your team first), and every player's hits this
round, hits, times hit, BBs fired, accuracy and time in play. Players out this round are greyed with an **OUT** tag.

## What got you

When your hit is called, a card on the left shows the shooter's name and side, how far away they were and a dial of
the shot's line, whether they were holding that angle, how long you were in their view and whether you were moving,
then that bot's personality note. **Settings › HUD › What got you** is Auto (only against Hard bots, the default), On
or Off.

## The match summary

After the last round: a **WON** or **LOST** stamp with the score, map and bots; every player's numbers for the whole
match; your XP card with any level-up; your records for that bot level and mode with **NEW RECORD** tags; What got you
for the last five times you were hit; and, against Hard bots, the next Pro tip.

## The minimap

Top left, the minimap shows the field from above:

- You are the **white arrow**; teammates are dots in your team's colour, grey once hit.
- The other team shows only where your side **heard** them: a dashed ring for footsteps, a disc for a shot, fading
  after a few seconds. Steps carry about 22 m and shots about 60 m.
- The area you stand in is named at the top, with the map and round under it.
- In Attack / Defend the pole (both on Depot) shows while the round is live, and your Hold Here spot shows as a
  diamond.
- Your team's pings show as the same ring or diamond, on the minimap's edge when they are off it, and the overtime
  flag as a chequered flag at its spot.
- **Rotating** (the default) turns the field so the way you look is up; **Fixed** keeps north up. Pick it in
  Settings › HUD › Minimap.
- **Zoom** (Settings › HUD › Minimap, 50 % to 200 %, 100 % by default) sets how close it shows the field: at 100 % it
  shows <!-- wiki:config minimap_config.view_radius --> metres from your arrow to its edge, at 200 % half that, bigger.
- Once you are out, the minimap follows the teammate you watch.
- The ground is shaded by what it is: grass, tracks and roads apart, hills shaded by their slope, hedges and thickets
  in green.

## The full-screen map

Hold **M** (Map in Settings › Controls) to see the whole field, north up, as big as the screen allows over a dimmed
screen. The header names the map, the round and the mode, and says what your side must do this round ("You attack:
raise the flag at A / B", "You defend", "Knock out the other team"). A key down the right explains every mark.

On top of what the minimap shows (you, your teammates, your Hold Here or Go There spot, your team's pings, and the
other team only where your side heard them) the map marks what never moves:

- **The flags:** in Attack / Defend each flag has a yellow ring and its letter, **A** or **B**. In Elimination a faint
  ring marks where the overtime flag will rise, solid once it is up.
- **Each team's start**, boxed in the colour of the team starting there (they swap at half time), and the **dead
  zones**, hatched grey.
- **Doors**, as short wood-coloured bars across their doorways.
- **Place names**, bigger for the big areas; where two would overlap the smaller one moves aside or is left out.
- **The ground:** grass, tracks, decks and roads in their own shades, hills shaded by their slope, hedges and thickets
  in green. The minimap shows the same ground.
- A **compass** and a 10 m **scale bar** in the corner.

It shows the storey you stand on.

While it is open the mouse moves a pointer on the map instead of turning your view, and your feet still move. **Click**
to send your teammates there ([Go There](Squad-Orders#go-there)), or press the ping's key (the middle mouse button) to
ping that spot for them. Let go of M and you look around again; the trigger needs a fresh pull. Once you are out you
can still look at the map, but not ping on it. There is no map on the [Practice Range](Practice-Range).

## Sounds that carry information

Everything you hear is positioned where it happened. Sounds from behind a wall are duller and quieter; round a corner
or behind a low barrier they're only half muffled, so you can still tell where they are. Your own sounds, your hit
tick and the referee's whistle are never muffled. Kit rustles when someone nearby crouches or leans, and landings
thud harder the further the drop. For a visual version of these sounds, see
[Sound cues](Accessibility#sound-cues).

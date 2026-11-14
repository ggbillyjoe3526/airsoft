# Bots

Every other player in Airsoft is a bot: your teammates and the whole other team. Bots play like airsoft players, not
aimbots. They walk lanes, hold corners, take cover, peek and lean, flank, search where they last saw or heard you,
and call their hits honestly, by the same rules as you. A bot firing over cover tips its replica up a little so the
barrel clears the top.

## What bots know

Bots know only what they see and hear:

- They see in a **120° view** in front of them, never through walls, but through glass as you do. Glass still
  stops BBs, so a bot that sees you through it with no shot goes round to you.
- A bush hides you from a bot only past <!-- wiki:config bot_config.close_awareness --> m: closer, it notices you
  whichever way it faces. Further off it holds fire through more than a thin edge of leaves, but that close it fires
  whenever a BB could get through to you, so hiding in the same bush as a bot means a shoot-out.
- They hear running, sprinting, vaults, landings, knocked props, shots, and a [flash's bang or a smoke's
  pop](Grenades). Walls muffle what they hear. **Walking and
  moving crouched are silent**, so you can sneak up on a bot that hasn't seen you.
- A rattling hi-cap magazine gives you away to bots close by, and a silencer halves how far your shots carry.
- They see about 55 to 60 m by day, depending on the field. A BB that lands by a bot, or hits its teammate close to
  it, gives the shooter away: for a few seconds the bot makes them out to 70 m, so a long shot from out of sight is
  answered.
- They react after a moment, and their aim settles before it is steady. They never fire with a teammate in the way,
  or where a teammate could step into the shot before the BBs arrive.

### At night

At night bots see only as far as the light lets them: about 40 m if you stand in the light of a fire, a lantern or a
torch beam, 25 m in the open under the moon, 15 m indoors and only 10 m under the trees. Bots on Normal and up keep out
of the light when they hold a spot or hunt for you; Easy bots stand wherever their lane takes them. Every bot carries a
[weapon torch](Parts-and-Power#lights), which you can see on its replica, its light glowing, and loads glowing BBs.

## Difficulty

The Match screen's **Bots** section has two rows, **Opponents** and **Teammates**, each Easy, Normal or Hard; rest the
pointer on a level to read how it plays. The XP the match pays shows after **Opponents** (XP ×1). A new player starts on
Normal. Your teammates follow the opponents' level until you pick
one; "Follow opponents" puts them back.

| Level | How it plays |
| --- | --- |
| **Easy** | A fair fight to learn on: its first BBs up close can miss. |
| **Normal** | Reacts faster, aims steadier, leads moving targets more, takes cover more and flanks more often. |
| **Hard** | Careful, not twitchier: aims at the corners, doorways and bush edges you would step out of, and plays as a team. |

**Hard bots** in more detail:

- Step out right where a Hard bot is aiming and it shoots back faster; from anywhere else it is no faster than Normal.
- Near your side they walk instead of run, check each corner ahead and lean out past it.
- When you duck out of a fight they watch that spot for a moment before coming after you, and low on BBs with you
  nearby they top up from cover.
- When a teammate is hit, nearby Hard bots run to trade it. A Hard bot that hears you tells its team where.
- Two Hard bots on one lane move in pairs, one covering while the other moves, and in Attack / Defend two defenders on
  a lane set up a crossfire.
- A Hard team that's behind with <!-- wiki:config bot_config.late_push_time --> seconds or less left stops holding and comes looking.
- Against Hard bots the scoreboard shows a **Pro tip** each round.

**Normal and Hard bots** also play as a team, and fight smarter:

- A bot that spots you tells the teammates near that spot where you are, a moment later (sooner and further on Hard),
  and they come ready for you there.
- A team two or more eliminations ahead in Elimination stops holding and goes looking for the rest.
- The last bot of a team still in plays it carefully: it walks, checks each corner ahead and leans out past it.
- In a fight in the open they take a knee for each burst, then sidestep between bursts: steadier BBs, and less of
  them to hit.

The bots' level sets the XP a match pays ([Levels and Unlocks](Levels-and-Unlocks#earning-xp)).

## Personalities

Every bot has a name and one of four personalities. A name always plays the same personality, and each team gets
different ones while there are enough. A personality changes **how** a bot plays, never how well.

<!-- wiki:personalities -->

Names show on a WATCHING line while you spectate a bot and on the [What got you](HUD-and-Minimap#what-got-you) card,
never over heads.

## Kits

Every bot, on your team and the other, carries a kit: a replica set with parts and power picked from the same items you unlock. Each bot
picks its kit at the start of a match, by difficulty, and leans towards kits that suit its personality. Parts work
in their hands exactly as in yours and show on their replicas. The same match seed gives the same kits.

The percentages are how likely a bot on that level is to carry each kit before its personality leans it towards the
kits that suit it.

<!-- wiki:bot-kits -->

Under the Factory kit house rule every bot carries the AEG Rifle and the GBB Pistol as they come. Bots fire full auto wherever their replica has it,
except on an indoor field (Depot, [no full auto indoors](Maps#depot)): there they fire single shots and only now and
then switch to full auto, at someone out in the open down a long sight line. Each bot decides that once per opponent
each round.

## Bots in Attack / Defend

Attacking bots walk their lanes to just past the middle, then make for the pole. The nearest attacker raises the flag
crouched at the rope while the others guard it from cover close by. Defenders hold near the pole, go after only what
they see or hear close to it, and the two nearest run to pull a rising flag down. On Depot's two poles the attackers
pick A or B each round and head for the pole in play, the one being fought over or else the one where a flag goes up
(yours too). Bots already fighting at a pole's rope stay on it, and defenders split: start a flag at B while A is
fought over, and the nearest free defenders come to B while those at A stay. Each defender keeps watch round the pole
nearest the point it holds.

## Bots in Plant The Bomb

Attacking bots pick Site A or B each round. One of them fetches the bomb, the others walk their lanes, and the
carrier goes in once its lane is clear, or at once when <!-- wiki:config bot_config.plant_rush_clock --> seconds
of the round are left. It plants kneeling behind cover inside the site where there is some, while the others guard
it from cover close by, and they stay to hold the armed bomb. If the carrier is hit, the nearest attacker picks the
bomb up; dropped by the other site, they plant there instead.

**The bomb is yours first.** At the start of a round your teammates wait beside it for <!-- wiki:config bot_config.plant_player_first -->
seconds, or until you have walked <!-- wiki:config bot_config.plant_player_left -->
m away without it. Carry it towards the other site and they come
with you.

Defending bots hold their posts by the sites; where their posts would leave one site open, half
of them guard that site instead. They learn the bomb is being planted only when one of them is within <!-- wiki:config bot_config.plant_heard -->
m of it and hears the code keyed in. Once it is armed every free
defender goes back to it; the nearest defuses while the others cover.

**The defuse is yours first too.** While you are in play within <!-- wiki:config bot_config.plant_player_claim -->
m of the armed bomb no bot defuses it, until the fuse leaves a
bot only just time: its defuse plus <!-- wiki:config bot_config.plant_takeover_margin --> seconds. With your own
hands on it they never take over. A [squad order](Squad-Orders) keeps a bot off the bomb: it does what you asked.

**Smoke does not hide the work.** A bot within <!-- wiki:config bot_config.plant_gives_away -->
m of whoever is keying the bomb in or defusing it makes them out through smoke: the keypad and the kit are too loud
to miss that close. That goes for you as for them; anyone with their hands off the bomb is hidden as usual.

## Callouts

Bots tell their team what they already do, in words in the [hit feed](HUD-and-Minimap#callouts)
with a radio click, never a voice: a sighting ("Contact, Dock!"), a noise while nobody on the team sees anyone, the
team's hits ("Two left!", "Last one!"), a reload under fire, setting off after someone, settling at a hold, the
flag going up, and in Plant The Bomb the bomb being planted, armed, defused or dropped ("They're planting at A
site!"). A team speaks one call at a time, a moment apart, the most urgent first; each personality has its own
lines and talks more or less. Hit players never talk, and what a bot says never changes how anyone plays. You see
only your own team's words; an enemy close by is heard keying their radio.

### Your teammates ask for you

A bot on your team can ask you over with a ping as well as words, when you are far from it: **Need help** when it is
fighting two or more at once, or defends the pole the other team starts raising the flag on; **Go round** when it has
traded looks with one enemy for a while, pinging a spot to their side for you to flank from (never on a floor no route
joins to yours); **Cover me** when it starts raising the flag. The team asks at most once every 30 s and three times a
round, so an ask always means something. The ping shows like yours, marked HELP, GO or COVER with its distance; nobody
else changes what they do for it, so it's your call whether to go.

## The overtime flag

When Elimination's [overtime flag](Modes#the-overtime-flag) goes up, every bot sets off to touch
it a moment after the whistles (slowest on Easy, quickest on Hard), still fighting anyone it sees on the way. Anchors
and careful bots first watch it from cover close by, aiming at it, for a few seconds, unless they are the last of their
team or the overtime is nearly over; a flanker may come at it round the side. A bot you gave an order keeps to it. On
each team the bot nearest the flag calls it, naming where it stands.

## Smoke and flash bombs

Every bot carries a smoke and a flash bomb a round, as you do, and throws them: a smoke when pinned in cover by
someone at range, a flash round a corner before it pushes, then it looks away until the bang. Harder bots throw more
often. A Normal or Hard bot that sees someone else's flash coming may turn away from it too (Hard more often than
Normal; an Easy bot never does), so a flash is surest thrown where it lands out of sight. Bots walk round a standing smoke cloud
where the way round is open, and through it only where it is the only way. [Grenades](Grenades) has the rules.

## Magazines

A bot running low on BBs for its rifle asks the nearest teammate within 30 m who has one to spare,
saying "Need a mag!". A bot asked, by a teammate or by you, calls "Mag coming!", sprints over while it is far, runs the
last metres and tosses it once you are in reach and in sight; a bot never gives away its last full spare of the replica
it fights with, but hands over its unused pistol's freely. A bot that asked you walks up to you and waits for your toss;
one that asked another bot waits where it is, behind cover while that bot is held up in a fight. An ask to a teammate
who then asks for one of its own ends at once, so the asker can try someone else. A bot that can't come (off to the
flag, or already bringing one when someone else could) passes the ask on to the next nearest teammate with one to
spare, or tells you nobody can. A fight or cover comes first, then bringing one, then your squad order,
then waiting for one; the same at every level. A catch gets a "Thanks for the mag!" now and then. You toss yours, and ask
for one, with [Need a Mag](Squad-Orders#need-a-mag).

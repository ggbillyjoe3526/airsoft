# Squad Orders

Your bot teammates follow the team's plan on their own, but you can tell them what to do. Orders go to every
teammate still in play, except Cover Me, which goes to one.

| Order | Key | What your teammates do |
| --- | --- | --- |
| **Follow Me** | <!-- wiki:key order_follow --> | Stay with you and keep up as you move. One that ducked into cover comes out to keep up once nobody is in sight, and one left far behind runs a little faster than a sprint until it has caught up. |
| **Hold Here** | <!-- wiki:key order_hold --> | Spread out across the spot you are looking at and hold it (where they stand, if you look at nothing in reach). |
| **Go There** | <!-- wiki:key ping_move --> | Go to the spot you are looking at, however far, and hold it once they are all there ([below](#go-there)). |
| **Cover Me** | wheel only | Your nearest teammate who isn't in a fight comes to stand beside you, looking where you look, and stays with you there until you go more than <!-- wiki:config squad_config.cover_leave --> m from that spot. The others go back to the team's plan. |
| **Watching Here** | wheel only | Leave the spot you are looking at to you: one teammate comes to watch it beside you and the rest spread out to other angles ([below](#watching-here)). |
| **Regroup** | <!-- wiki:key order_regroup --> | Come back to you. |
| **Team Plan** | wheel only | Drop your order and go back to the team's own plan. |

Hold **<!-- wiki:key order_wheel -->** to open the **order wheel** round the crosshair: **Spotted** in a circle in the
middle and four buttons on each side, names only.

| Left | | Right |
| --- | --- | --- |
| Team Plan | | Watching Here |
| Go There | **Spotted** | Follow Me |
| Hold Here | | Cover Me |
| Regroup | | Need a Mag |

Move the mouse to put the dot on a button and let go (or click, with **Order wheel: Click** in Settings › Controls ›
Squad orders). The button under the dot lights up, and the order in force has a stripe in your team's colour on its
outer edge. While the wheel is open the mouse moves the dot instead of turning your view, and the dot never leaves the
wheel, so a big flick still lands on a button. Straight above or below the circle is nothing: let go there to give
nothing.

- You hear a **radio click** when your team takes an order. That click is the only confirmation: there's no order text
  on the HUD. An order nobody can take is silent, and the wheel's middle says why (for example "No teammates in play
  to order").
- **Hold Here** puts a "HOLD · 18 M" marker over the spot, with a dashed ring on the floor. Turn away and it slides to
  the screen edge with an arrow. The minimap shows it as a diamond. With the full-screen map open, Hold Here's key
  holds the spot under the map's pointer instead, your teammates side by side across the way there and looking on.
- An order lasts until you give another, until you are hit, or until the round (or the match) ends. In Attack / Defend it overrides
  your teammates' work at the pole.
- An order that ends by itself ends quietly: when the last teammate carrying it is hit, when you walk away from Cover
  Me or Watching Here, or when a Go There has gone quiet, your teammates go back to the team plan without a notice
  on screen. The wheel's circle shows a notice for <!-- wiki:config hud_config.order_notice_time --> s only to
  answer an order you gave.
- With respawns, a teammate hit while following you (Follow Me or Regroup) takes it up again when it comes back, as
  long as another teammate still carries it. Orders to a spot (Hold Here, Go There, Watching Here, Cover Me) are not
  taken up again.
- Orders do nothing on the [Practice Range](Practice-Range), where there's nobody to order.

All the keys can be rebound in Settings › Controls ([Controls](Controls)).

## Spotted

**Tap <!-- wiki:key order_wheel -->** (press and let go quickly), or let go of the wheel with the dot in its middle, to
spot the opponent under your crosshair. You have to be able to see them, but you don't need perfect aim. A small yellow
arrow hangs over their head for <!-- wiki:config ping_config.spot_time --> seconds, following them and showing through
walls and cover. It fades out over the last second, and it goes when they are out or the round ends. Spotting them
again starts the time over. Only your team sees it, and a soft pip says your spot went out.

While they are spotted, your bot teammates within <!-- wiki:config ping_config.spot_share_radius --> m of them hear
where they are, at once and again every second. Each one goes after them or watches them from its post, the way it
plays. Teammates further off, in a fight or with someone else in sight carry on. Nobody under your crosshair spots
nobody. A tap never shows the wheel, and it spots however the mouse is moving: the trigger, your aim and the mouse
wheel stay yours through it, so you can spot someone while you follow them or fire at them. Your view waits while the
key is down and takes the whole turn as you let go.

## Pings

Press the **middle mouse button** (Squad: ping a spot in Settings › Controls) to tell your team you are heading for
the spot where your crosshair meets the field, up to <!-- wiki:config ping_config.reach --> m away, and would like them
to come. The sky marks nothing, and a ping through a window or a bar railing marks what lies beyond it. It is not an
order, so teammates can ignore it ([Go There](#go-there) is the order). Each teammate within about
the <!-- wiki:config bot_config.ping_follow_reach --> m round you comes along on a roll (a chance of
about <!-- wiki:config bot_config.ping_follow_chance -->), even from a post it holds, and keeps it in mind for <!-- wiki:config bot_config.ping_memory --> seconds unless it sees or hears something newer.
The rest carry on with their own play. A teammate under your order keeps the order and only watches the spot. One in
a fight, in cover or with someone in sight carries on. An opponent under your crosshair that you can see is marked as
a contact instead, and every teammate free to take it does, as a threat. One of them answers in the hit feed, "Going to your ping" or "Watching your ping" in its
own words. You have one ping at a time and a double click is one ping; pings clear each round and do nothing while you
are out, while the order wheel is open or on the [Practice Range](Practice-Range). A soft pip says your ping went out,
and a marker shows it over the field and on the minimap ([HUD and Minimap](HUD-and-Minimap#ping-markers)).

## Go There

Press **<!-- wiki:key ping_move -->** (Squad: go there in Settings › Controls), pick **Go There** on the order wheel (left, second down),
or click anywhere on the [full-screen map](HUD-and-Minimap#the-full-screen-map) to send your teammates to a spot, even
one where nobody has been seen. They spread out side by side across the way there and set off; once all of them have
arrived it becomes a **Hold Here** on that spot, everyone looking on the way they came. While they are on their way the
marker over the spot reads "GO · 30 M", then "HOLD · 30 M"; the minimap shows it as Hold Here's diamond. Go There at
the same spot again keeps it (it never cancels); somewhere else moves it. Aimed at the sky, it goes nowhere and the
wheel's middle says so. A teammate fighting on the way fights first, as with every order.

A Go There spot isn't held for ever: once they are all there, if nothing happens near them for about the
next <!-- wiki:config squad_config.go_there_quiet --> s (no enemy seen, no fight, nothing heard within about
the <!-- wiki:config squad_config.go_there_contact_radius --> m round them), they read "All quiet" and go back to the
team plan. Any contact starts the wait again, and so does Go There at the same spot. A Hold Here you give yourself is
held until you end it.

## Watching Here

Pick **Watching Here** on the order wheel (right, at the top) to tell your team you have the spot you are looking at
covered. A marker over it reads "WATCHING · 15 M", with a dashed ring on the floor, and the minimap shows it as Hold
Here's diamond. Any order in force ends: the nearest teammate who isn't fighting, within about
the <!-- wiki:config squad_config.watch_join_range --> m round you, comes to stand beside you looking at the spot and
says so on the radio; at most one comes. The rest go back to the team plan and leave the area to you: they don't hunt
within the <!-- wiki:config squad_config.watch_radius --> m round the spot or hold angles into it, so they spread out to
cover the rest. With nobody free to come, the nearest says the spot is yours.

It lasts until you give another order (Team Plan ends it), walk more than
the <!-- wiki:config squad_config.watch_leave --> m from where you marked it, are hit, or the round ends. Watching Here
at the same spot again keeps it; somewhere else moves it. Aimed at the sky, it marks nothing and the wheel's middle
says so.

## Need a Mag

Press **<!-- wiki:key mag_hand_off -->** (Squad: need a mag in Settings › Controls), or pick **Need a Mag** on the order wheel
(right, at the bottom). It does what fits now: when a teammate who asked you for a magazine is close enough, with a
clear path for its arc, you toss them one (the item then reads **Toss a Mag**); otherwise, when you are down to less
than one full spare magazine, you ask the nearest teammate within <!-- wiki:config mag_share_config.ask_range --> m who has one to spare,
and a radio click says they heard. Your magazine flies in a short arc into their hands, and theirs into yours, in the
thrower's own replica colours: nothing is made, the BBs come out of the thrower's pouch. If the catcher steps behind
a wall while it flies, it is lost at the wall, BBs and all, and they can ask again at once. A toss reaches <!-- wiki:config mag_share_config.toss_range --> m.
After an ask ends you can ask again <!-- wiki:config mag_share_config.player_ask_gap --> seconds later. A press that
can't do anything says why: on the line under the crosshair, or in the wheel's middle when you picked it there
("Nobody near has a spare mag that fits", "You still have a full spare mag", "Get closer to Rook to toss a mag"). It
does nothing while you are out or on the [Practice Range](Practice-Range); between rounds magazines wait for the next round.
What the [HUD](HUD-and-Minimap#the-magazine-hand-off) shows, and how [bots](Bots#magazines) ask and bring one.

# Squad Orders

Your bot teammates follow the team's plan on their own, but you can tell them what to do. Orders go to every
teammate still in play.

| Order | Key | What your teammates do |
| --- | --- | --- |
| **Follow Me** | F | Stay with you and keep up as you move. |
| **Hold Here** | X | Spread out across the spot you are looking at and hold it (where they stand, if you look at nothing in reach). |
| **Go There** | Mouse 4 | Go to the spot you are looking at, however far, and hold it once they are all there ([below](#go-there)). |
| **Regroup** | V | Come back to you. |
| **Team Plan** | wheel only | Drop your order and go back to the team's own plan. |

Hold **Z** to open the **order wheel** round the crosshair: point at an order with the mouse and let go (or click,
with **Order wheel: Click** in Settings › Controls › Squad orders). The slice you point at lights yellow, and the order
in force wears a blue band and an **ACTIVE** tag. While the wheel is open the mouse aims it instead of turning your
view.

- You hear a **radio click** when your team takes an order. That click is the only confirmation: there's no order text
  on the HUD. An order nobody can take is silent, and the wheel's middle says why (for example "No teammates in play
  to order").
- **Hold Here** puts a "HOLD · 18 M" marker over the spot, with a dashed ring on the floor. Turn away and it slides to
  the screen edge with an arrow. The minimap shows it as a diamond.
- An order lasts until you give another, until you are hit, or until the round (or the match) ends. In Attack / Defend it overrides
  your teammates' work at the pole.
- Orders do nothing on the [Practice Range](Practice-Range), where there's nobody to order.

All the keys can be rebound in Settings › Controls ([Controls](Controls)).

## Pings

Press the **middle mouse button** (Squad: ping a spot in Settings › Controls) to mark where your crosshair
meets the field, up to <!-- wiki:config ping_config.reach --> m away, for your bot teammates; the sky marks nothing.
An opponent under your crosshair that you can see is marked as a contact instead, and counts as a threat. Your
teammates take a ping as somewhere worth a look, kept in mind for <!-- wiki:config bot_config.ping_memory --> seconds
unless they see or hear something newer: one sets off to check it the way it plays (a rusher runs, a careful bot walks
in), and one under your order, at its post or holding watches it instead. A teammate in a fight, in cover or with
someone in sight carries on. One of them answers in the hit feed, "Going to your ping" or "Watching your ping" in its
own words. You have one ping at a time and a double click is one ping; pings clear each round and do nothing while you
are out, while the order wheel is open or on the [Practice Range](Practice-Range). A soft pip says your ping went out,
and a marker shows it over the field and on the minimap ([HUD and Minimap](HUD-and-Minimap#ping-markers)).

## Go There

Press **mouse button 4** (Squad: go there in Settings › Controls), pick **Go There** on the order wheel (lower right),
or click anywhere on the [full-screen map](HUD-and-Minimap#the-full-screen-map) to send your teammates to a spot, even
one where nobody has been seen. They spread out side by side across the way there and set off; once all of them have
arrived it becomes a **Hold Here** on that spot, everyone looking on the way they came. While they are on their way the
marker over the spot reads "GO · 30 M", then "HOLD · 30 M"; the minimap shows it as Hold Here's diamond. Go There at
the same spot again keeps it (it never cancels); somewhere else moves it. Aimed at the sky, it goes nowhere and the
wheel's middle says so. A teammate fighting on the way fights first, as with every order.

## Need a Mag

Press **H** (Squad: need a mag in Settings › Controls), or pick **Need a Mag**, the order wheel's last
item at its upper left. It does what fits now: when a teammate who asked you for a magazine is close enough and in
sight, you toss them one (the item then reads **Toss a Mag**); otherwise, when you are down to less than one full spare
magazine, you ask the nearest teammate within <!-- wiki:config mag_share_config.ask_range --> m who has one to spare,
and a radio click says they heard. Your magazine flies in a short arc into their hands, and theirs into yours: nothing
is made, the BBs come out of the thrower's pouch. A toss reaches <!-- wiki:config mag_share_config.toss_range --> m.
After an ask ends you can ask again <!-- wiki:config mag_share_config.player_ask_gap --> seconds later. A press that
can't do anything says why: on the line under the crosshair, or in the wheel's middle when you picked it there
("Nobody near has a mag to spare", "You still have a full spare mag", "Get closer to Rook to toss a mag"). It does
nothing while you are out or on the [Practice Range](Practice-Range); between rounds magazines wait for the next round.
What the [HUD](HUD-and-Minimap#the-magazine-hand-off) shows, and how [bots](Bots#magazines) ask and bring one.

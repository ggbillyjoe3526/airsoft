# CW1 · Comms wheel redesign, Spotted, ping as intention and Cover me

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | – | – | – |

## Owner's asks (William, 2026-11-15)

- The wheel smaller, Spotted in a circle in the middle, four rectangular same-size buttons a side, names only (no key
  chips), nothing clipped; held Z and the mouse lights a button, smooth like a commo rose.
- Order: right Watching Here, Follow Me, Cover Me, Need a Mag; left Team Plan, Go There, Hold Here, Regroup (07:13,
  replacing his first order). The circle slightly smaller (07:14).
- A tap of Z spots the bot under the view: a small yellow arrow over its head for 10 s, seen through cover, shared
  with teammates, and only teammates near enough go after it.
- The middle-click ping becomes your intention ("I'm heading there, follow me"), which teammates may ignore; Go There
  on the wheel stays the strict order.

## Decisions (Claude's defaults, easy to change)

- **Layout.** Buttons 236 × 48 px, rows 58 px apart, columns 100 px either side of the middle, circle radius 66 px
  (`ControlsConfig` `wheel_*`). The pointer is kept inside the buttons' outer box, so a flick lands on the outer
  button; inside the circle is Spotted; a 20 px strip straight above and below the circle is nothing; elsewhere the
  side and row decide (`OrderWheelLayout.pick`), so there is no dead gap between buttons.
- **Tap.** Let go within 0.2 s (`wheel_tap`) without leaving the circle and it spots, on Hover or Click; the wheel
  never shows for a tap. Held longer, letting go in the circle spots on Hover.
- **Spotted.** The enemy under the view within 4° (`PingConfig.spot_cone_deg`, a ping's is narrower) whom the bots'
  sight rules let you see; nobody there, nothing happens. A spot plays the ping's soft pip (`SimAudio.on_spot`), a tap
  on nobody nothing. Marked 10 s, again from the start when spotted again, ended when out or at a new round. Bot teammates within 30 m of them (`spot_share_radius`) not fighting or
  seeing someone hear where they are, at once and every 1 s (`spot_share_gap`), as a teammate's call; each then goes
  after them or watches from its post as its own play decides. The arrow is drawn only when on screen, not pinned to
  the edge, fading over the last second.
- **Ping as intention.** A ping of a spot: each bot teammate within 40 m of you (`BotConfig.ping_follow_reach`) comes
  along on a 60 % roll (`ping_follow_chance`, from its own seeded stream), leaving a post to do so; one under your squad
  order only watches the spot. A ping of an enemy you can see (a contact) is unchanged: every free teammate takes it
  as a threat.
- **Cover me** (the new button). The nearest teammate in play not fighting, in cover or seeing someone (else the
  nearest) comes to a post beside you (`SquadOrders.watch_post`) looking where you look (Hold here's spot, or 12 m
  along your view: `SquadConfig.cover_look`), and holds there; the rest go back to the team plan. It replaces the
  order in force and ends when you are more than 30 m from the post (`cover_leave`), as every order ends.

## Verified

- To fill in: checks, agents.
- Pictures: `art/comms-wheel/cw1-wheel-v2-in-game.png` and `cw1-wheel-v2-close-ups.png` in the shared files.

## Known issues left

- To fill in.

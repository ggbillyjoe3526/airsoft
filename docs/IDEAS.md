# Ideas (not approved)

The parking lot for future features the owner hasn't placed in a version yet. Don't implement any of them unless asked.

New ideas go here until the owner places them. The feature triage (owner, 2026-10-05) emptied the list: every idea
parked here was placed in a version on the roadmap (`docs/ROADMAP.md`, Beta and "After 0.1") or declined below.

## Later, version not set

Work the owner wants one day but hasn't placed in a version.

- **Another UI redesign (owner, 2026-10-13).** "We're probably going to have to do another UI redesign at some point.
  Maybe in a future Dev release or after 1.0." Nothing is built for it until he places it.
- **A Visual redesign (owner, 2026-10-16).** A fresh look for the game's visuals, to be done at some point. Timing not
  decided; nothing is built for it until he places it.
- **An Audio redesign (owner, 2026-10-16).** A fresh sound for the game, to be done at some point. Timing not decided;
  nothing is built for it until he places it.
  For it: the browser game's short reverb per field on every in-world sound (Depot 0.8 s, wet 0.22), left out of the
  step 19 sound pass (plan §5.6).
- **A Performance update (owner, 2026-10-16).** An update that focuses on making the game run better. Timing not
  decided; nothing is built for it until he places it.
- **Vehicles on a big outdoor map (owner, 2026-10-31).** A future massive outdoor field (perhaps the redesigned
  Woodland) with vehicles to drive round it. A driving player can't shoot but can still ping and give orders; a bot
  can drive but gives no orders (it follows the player's); players and bots in passenger seats can fight. Nothing is
  built until he places it.
- ~~**Doors (owner, 2026-10-17, for Neon Heights; NH2).**~~ Built for Depot's hall (DO1, 2026-10-31).

## Maybe

New ideas the owner wants to think about (owner, 2026-10-06). Roadmap items he marked maybe stay in their place in
`docs/ROADMAP.md`.

- **A civilian outfit for some figures (AX1, 2026-10-17).** Two of the human's six looks in everyday clothes (a hoodie,
  work trousers) under the team carrier, so a match reads more like a Sunday site. It needs a second outfit texture
  from the figure's Blender source; the owner kept today's figures in Beta 1.
- **Throwing better (SF1, 2026-10-30).** An arc preview while you hold the key, an underhand roll for a short throw
  round a corner, and cooking a flash for a shorter fuse. Left out of the basic smoke and flash bombs.
- **Choosing your grenades (SF1).** Swap the smoke for a second flash, or the other way round, in the Loadout's
  Grenades slot. Today every player and bot carries one of each; the 0.2 rigs and pouches decide carrying.
- **Clutch moments.** A "last one standing" banner and a clutch count in your records.
- **Match wagers.** Stake some of a match's XP on winning it, for more XP if you do.
- **A downside for the 11.1 V LiPo Battery.** It fires 15 % faster with no number made worse; a cost (more kick, a
  shorter battery life, or slower trigger response) would make it a real trade-off (owner, 2026-10-11: leave it for
  now).
- **A built-in voice for the screen reader messages (AC6, 2026-10-23).** Read the hit calls, your hit and the rounds'
  results aloud with Godot's text to speech (`DisplayServer.tts_speak`, needs `audio/general/text_to_speech`) for
  players without a screen reader, behind its own switch (plan step 21, question 7: Godot's screen reader support only
  for now).
- **A Dev aid: skip to the last round.** The owner's suggestion, a Dev setting that jumps a match to its last round
  to test the match's end (moved from `docs/KNOWN_ISSUES.md`, KI1).

## No for now

From the owner's Dev 6 and Dev 7 picks (owner, 2026-10-06). He may change his mind later, so these can come back when
he raises them; don't propose them again before that:

- Bang-bang surrender or a rubber-knife tag.
- The dead rag, a light on hit players at night and a shouted "HIT!" (the hit system is good enough as it is).
- Throwing a decoy to lure bots.
- A key to glance at your magazine (the option to hide the ammo counter is a yes).
- Hand-made scenarios rated with stars.
- A "good game" line-up after the match.
- Slide into cover: a short sprint slide that ends crouched behind cover (owner, 2026-10-12; vaulting went to
  0.1 Dev 6 instead).
- Ray traced or path traced light (built as RT1 and scrapped by the owner, 2026-10-11: too much work for what it adds;
  the code is archived in the project's shared files, `archive/ray-tracing/`).

## Declined in the feature triage

Cut for adding more complexity than player value (owner, 2026-10-05; reasons in `docs/DECISIONS.md`). Don't propose
these again unless the owner brings them up:

- Bomb (Attack / Defend with another prop).
- Intel grab (Extraction already is "grab it and get out").
- Free-for-all.
- The overshooting rule (bots never overshoot).
- Tracer BBs as their own option (glowing BBs do it).
- Supply weekends and dated events (M49 built them; RV1 took them out).
- VIP escort.
- Hostage rescue.
- A referee NPC (the whistles cover it).
- Tuning the hop-up during a match (the Customise dial covers it).
- A who-hit-you replay (the "what got you" card covers it).
- A separate speedsoft mode and surrender rule (the field rule presets and the bang-bang rule cover them).

## Declined from the third research list

Offered in the third research list (`future-features-2026-10-04.md` in the project files) and turned down (owner,
2026-10-04). Don't propose these again unless the owner brings them up:

- Infection.
- A game day playlist.
- A shoot house time trial.
- King of the Hill as a Domination option.
- Hi-cap winding.
- A riot shield.
- 40 mm shower shells and claymores.
- A goggle view.
- Site dressing at the dead zone.
- A Tour mode.
- Photo mode.
- Match replays.
- Site sounds on the menus.
- Controller support.

Also offered on 2026-10-03 and not picked: captions for hit calls and whistles, a map editor / mod support, a "gun hits
count" house rule.

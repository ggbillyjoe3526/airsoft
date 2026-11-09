# Settings

Open **Settings** from the rail on the left of the menus or from the pause menu. Every change applies at once, even in
the middle of a match, and is saved straight away. If the settings file is ever damaged, the game starts on the defaults
and says so. **Back**, a small button at the bottom left, closes Settings. An On/Off setting is a switch: teal with the
knob at the right when on. The tabs are a row of buttons under the SETTINGS title, the one open in white, and a row of
choices is one bar with the picked choice in white. Nothing on the screen moves or changes size when you press a switch
or pick a choice. Rest the pointer on a row to see what it does: the help wraps onto more lines and always stays on
screen.

## Controls

Hip and aimed mouse sensitivity (also as centimetres per 360° at your mouse's DPI; aimed, the view turns slower the
more your sight zooms, through a scope's glass too), invert vertical look, two keys for every action, and the
**Squad orders** section with Order wheel: Hover or Click. The default keys are on [Controls](Controls).

## Gameplay

- **Crouch, aim and reload:** Crouch and Aim down sights as Hold or Toggle, and Reload: Manual (the default: you
  press the Reload key) or Automatic (an empty trigger pull reloads).
- **After a hit:** **What got you**, Auto, On or Off ([HUD and Minimap](HUD-and-Minimap#what-got-you)).
- **Skipped rounds:** **Simulate skipped rounds**, Off (the default) or On. On, skipping a round offers a **SIMULATE**
  button that decides the round at once ([How to Play](How-to-Play#skipping-the-rest-of-the-round)).

These were on Controls and HUD before; your saved choices are kept.

## Audio

Volumes for **Master**, **Effects**, **Power source** (the motor or gas part of a shot), **Ambience** and
**Interface**. A new game starts with Master at 100 %, Effects 70 %, Power source 100 %, Ambience 20 % and Interface
40 %. If you delete your save, they come back. Gunfire carries across the whole field, so you can hear where a fight
is from a long way off; a silenced replica carries half as far.

## Display

- **Window mode:** Windowed, Borderless (a borderless fullscreen window) or Fullscreen (exclusive). A new game opens in
  Fullscreen, on the screen the game starts on; after that it opens in the mode you left.
  **F11** or **Alt+Enter** switches between windowed and your last fullscreen mode.
- **Monitor:** with two screens or more, the screen the window opens on.
- **V-Sync** (off by default) and a **Frame-rate limit**: 30 to 360 frames a second, or Off for no limit. In the background
  the game drops to 30 frames a second. The menus never draw more frames than your screen shows, whatever
  the limit.
- **Field of view** and **Show FPS** (the figure sits in the bottom-right corner).

## Graphics

Pick a preset or set each row yourself. The game starts on the preset picked for your graphics card, marked **FOR YOUR
CARD**: Medium for built-in graphics, High for a separate card, never Ultra. Changing a row makes the preset
**Custom** and marks what you changed; **Reset** goes back to the pick for your card. **Edge smoothing** is Off on
every preset; turn it on if you want it.

<!-- wiki:graphics -->

- **Low** is for speed: no sun shadows, ambient occlusion, baked light, wind dust or light effects, and a lower render
  scale. Every player gets a soft shadow under their feet instead, lying on a ramp's slope and on the floor below a
  ledge they drop from. The game's look (its colours and soft, stylised
  light) is the same on every preset.
- **Ultra** is the top end, for the most powerful cards: bounce light from the whole field, reflections on screen,
  volumetric haze and the softest shadows, sharp at their foot and soft away from it.
- **Baked light** gives Depot soft shade in its corners, warm light bounced off sunlit walls and its dim Lounge; its
  doors, flag poles and props take the same light.
- **Mesh detail** sets how near a player must be to be drawn in full detail. Through a scope that is how near they
  look, so a far player seen at 6x keeps the detail of one six times nearer; only the players in the scope's glass do,
  the rest of the view keeps its own. It also sets how many puffs make up a smoke cloud: fewer, bigger ones on Low and
  Medium, so standing in smoke costs less.
- **Occlusion culling** skips drawing what walls, containers and houses hide from you, such as a player behind a wall.
  It saves the graphics card work and costs the processor a little, so it is off on Low and on from Medium.
- **Light effects:** **Bounce light** is light bouncing off the field: Screen bounces what you see, Scene the whole
  field. **Reflections** on Probes show the room a shiny surface is in; Screen adds what is on screen. **Glow** makes
  lamps bloom softly. **Volumetric haze** is a faint haze the light shines through. **Lamp light** makes an indoor
  hall's roof lamps real lights that cast shadows (and, at night, fires and lanterns cast shadows too): Near (High)
  lights the lamps round you, Far (Ultra) the whole hall and up to eight fires. The lamps' shadows follow your shadow
  settings.
- While graphics are on **For your card**, slow frames in a match step the preset down one at the end of a round,
  never mid-round and never below Low, with a short note under the score. A preset you picked yourself never steps
  down.
- Choices your graphics card or renderer can't draw are greyed out, with the reason.
- **Start-up › Renderer** picks Auto or Compatibility (the simpler renderer) from the next start. If the game closes
  while drawing its graphics, the next start restarts once on the simpler renderer and Low, then asks whether to keep
  safe graphics or try your settings again.

If the game stutters, lower the preset or the render scale first.

## HUD

- **Crosshair:** shape (cross, cross and dot, circle or dot), colour, size, thickness, gap and opacity, dynamic or
  static spread, and an outline, with a live preview.
- **Hit marker:** on or off, with its own colour and size.
- **Ammo counter:** off hides every BB count, and each magazine gauge only shows whether it holds BBs.
- **Hit feed:** top right or bottom left; lines fade after a few seconds, or on **Keep** the last 10 hits stay up all
  match.
- **HUD opacity** fades the backgrounds of the ammo and bomb panel and the minimap in a match, from solid down to
  20 %. Their icons, numbers and words stay solid.
- **HUD size** from 80 % to 150 %. The crosshair and hit marker keep their size.
- **Minimap:** Rotating or Fixed, and its **Zoom**, 50 % to 200 % (how close it shows the field).
- **Callouts:** On (the default) shows your teammates' calls in the hit feed with a radio click, and lets you hear
  enemies close by keying their radios. Off hides the calls and stops every call's click at once; a squad order a
  teammate takes still clicks.
- **Ping markers:** On (the default) shows your pings and your teammates' marks over the field with their distance,
  and on the minimap. Off hides only the markers: your pings still reach your teammates, the pip still plays and they
  still answer.
- **Mag hand-off:** On (the default) shows the magazine hand-off's line under the crosshair and the magazine by a
  teammate's chevron. Off hides only those: Need a Mag still asks and tosses, and your teammates still call it.

## Accessibility

Team colours, gauge patterns, sound cues, reduced motion and screen reader messages: see
[Accessibility](Accessibility).

## Save file

Your save, its folder and its restore points: see [Saving and Bug Reports](Saving-and-Bug-Reports).

## About

**About** shows the game's version and the renderer it draws with, and has **Report a Bug**, **Licences** (everything
the game ships and their licences) and **Quit to desktop**. In a match, the pause menu has its own Report a Bug.

## Dev settings

The **Dev** tab holds tools for testing the game, such as game speed and spectating bots. Every one is off until you
turn it on, and a match played with one that changes how it plays stays out of your records and gives no XP. [Development](Development#dev-settings) lists them.

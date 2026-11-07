### Menus, HUD and controls fixes from the third bug pass
- Customise's turning replica is framed whole at every screen size: at 1080p and 4K it came out zoomed in on the
  receiver, and closer each time it was drawn. Moving the game to a screen of another size redraws it sharp.
- The minimap stays on the field by its edges: at a spawn by the edge a third of it was empty, so now your arrow moves
  off the middle instead.
- The Armory's level track takes keyboard and controller focus: left and right pick a level.
- The Performance sheet's Magazines row colours the magazine's size and how many apart, as the part cards do.
- The replica panel's round count sits in a line as tall as its numbers, as in the HUD's design, so the panel is a
  little shorter.
- A paint's name too long for its tile ("Ranger green") is set smaller to fit, never cut.
- The credits' title uses the same lettering as the other pages' titles.
- Settings › Accessibility says "Your system doesn't say whether it wants reduced motion" when it can't tell, not "asks
  for reduced motion: It doesn't say".
- The map pictures on the Match page's cards are drawn smooth rather than grainy.
- After an update that moved a default key (the bombs to 4 and 5, doors to G), an action whose new key you already use
  for something else gets its old key back if that is free; if not, Settings says which actions have no key.
- A key slot waiting for a key ("PRESS A KEY") stops waiting when you change Settings tab or the window loses focus.
- Coming back from the practice Loadout with a held crouch, you come back standing at once; a toggled crouch is still
  kept.
- While you spectate, the WATCHING line steps aside while the round's table is up, so it no longer covers "CLICK FOR THE
  NEXT ROUND".
- Keys rebound to punctuation show the mark they print (`[`, `;`, `/`) instead of names like "BracketLeft", and number
  pad keys read "Num 5".
- The match's XP card says "Rounds won with you in them", since a round you took no part in isn't counted.
- The crosshair and the teammates' markers no longer show through the pause menu.
- The walk-off line under HIT! keeps clear of the LOST banner when your hit ends the round.

### Screen reader
- Your squad orders are read out ("Order · Follow Me"), and so is an order that has to wait for the next round.
- Skipping a round is read out, and the last hit line no longer stays behind to be read again.
- Settings' choices, switches and sliders, Customise's paint tiles and the Armory's level track have spoken names.

### Bug reports
- Report a Bug takes out an IPv6 address written in letters only (`dead::beef`) or in mixed case (`Fe80::1`), a
  zero-padded IPv4 address and WSL's path to another account (`/mnt/c/Users/…`), and keeps C++ names (`Fade::1`),
  versions (`v1.2.3.4`) and the graphics driver's version.
- An account named with an ordinary word ("player", "test", "deck") is taken out of folder paths only, not from every
  sentence of the report.
- A sentence written after a user folder's path keeps its words.
- An account name with a space or a tab ("Jo Bloggs") never leaves its first word behind when a long note is cut.
- A clean quit that can't write its run record (a full disk, a locked file) leaves a mark beside it, so the next start
  no longer takes it for a crash; a save folder that takes no file at all still can.

### Dev tools
- F4's BB trails are ribbons a few pixels wide at any distance, not 1 px lines.
- Bot intentions (Dev tab) are hidden behind walls and while the order wheel, the field map or your sight is up, and
  labels over bots standing close step up so they don't overlap.
- F3's readout sits in the bottom left corner, clear of the minimap.
- Retro pixels (Dev tab) has Pixel size and Shades sliders.

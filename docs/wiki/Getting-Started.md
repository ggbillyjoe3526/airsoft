# Getting Started

## Download

Every version is posted on the
[Releases page](https://github.com/ggbillyjoe3526/airsoft/releases), with its [Patch Notes](Patch-Notes).
<!-- wiki:latest -->

Each release has three downloads, named after the version (here `0.1-dev.1`):

| File | What it is |
| --- | --- |
| `Airsoft-0.1-dev.1-Windows-Setup.exe` | The Windows installer: Start menu and desktop shortcuts, and an uninstaller. |
| `Airsoft-0.1-dev.1-Windows-Portable.zip` | Windows without installing: unzip anywhere and run `Airsoft.exe`. |
| `Airsoft-0.1-dev.1-Linux.zip` | Linux: unzip, then run `Airsoft.x86_64` (mark it executable first if your file manager asks). |

Every download carries `THIRD_PARTY_NOTICES.txt`, the licences of everything the game ships; the game shows the same
text under **Licences** on the title screen.

## Installing on Windows

Run the installer and follow its steps. Windows may show **"Windows protected your PC"**: the installer isn't signed
with a paid certificate yet, so SmartScreen doesn't know it. Click **More info**, then **Run anyway**.

The installer adds two Start menu shortcuts:

- **Airsoft** starts the game.
- **Airsoft (safe graphics)** starts it on the simpler renderer. Use it if the game won't draw on your graphics card
  ([Settings](Settings#graphics) has more).

Uninstall it from Windows' Apps settings or the **Uninstall Airsoft** shortcut. Your save stays behind unless you
delete it ([Saving and Bug Reports](Saving-and-Bug-Reports)).

## What your PC needs

The game is built to run smoothly on modest PCs: the Low graphics preset aims at 60 frames a second on a low-spec
laptop. It draws with Vulkan or Direct3D 12; a graphics card or driver without them is switched to a simpler renderer
on its own, and the title screen says so once. Mouse and keyboard; there is no controller support yet.

## Your first start

1. The first start shows your graphics card, your screen and the graphics preset picked for them (Medium for built-in
   graphics, High for a separate card). Press **OK**, or **Graphics settings** to change it.
2. The title screen says "Call your hit. Go again." Press **START** (or Enter).
3. The top bar holds **Match**, **Loadout**, **Armory**, **Settings** and your level. Click **AIRSOFT** at its left to go
   back to the title screen. **Esc** in the menus asks **Quit game?**: **Quit** leaves, **Cancel** (or Esc again) stays.

## Your first match

1. Open **Match**. Pick the map (Depot), the mode (**Elimination** is the classic), your team (**ALPHA** or **BETA**)
   and how well the bots play: start on **Easy** or **Normal**. Next time, Match opens on the map and team you last
   played.
2. Press **PLAY**. A loading screen shows the map until the match is ready, then **CONTINUE** comes up: click it, or
   press Enter or Space, to start.
3. You start at your team's end with two bot teammates, against three bots. The round starts on two short whistle
   blasts.
4. Move with **W A S D**, aim with the right mouse button, fire with the left. One BB hit takes anyone out, you
   included.
5. Take out the whole other team to win the round. First to <!-- wiki:config round_config.wins_needed --> rounds wins the match.
6. **Esc** pauses; **Quit match** there takes you back to the Match page.

Then read [How to Play](How-to-Play), set your keys in [Controls](Controls), and try the
[Practice Range](Practice-Range) to learn how BBs fly.

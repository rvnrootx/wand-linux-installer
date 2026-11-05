# Wand Linux Installer

Unofficial installer for running the **Wand** (formerly WeMod) Windows trainer app
with Steam Proton games on **CachyOS / Arch Linux**.

It installs [DeckCheatz/wemod-launcher](https://github.com/DeckCheatz/wemod-launcher),
adds a small `wand` wrapper that fixes Steam launch options containing environment
variables, patches a launcher bug in the dotnet48 download, and can prepare the
Horizon Forbidden West prefix for Wand.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/rvnrootx/wand-linux-installer/main/install.sh | bash
```

or from a clone:

```bash
git clone https://github.com/rvnrootx/wand-linux-installer.git
cd wand-linux-installer
./install.sh --prepare-hfw
```

Re-run it at any time to update the launcher. `--prepare-hfw` is only needed once
per game prefix; it is safe to run again (it exits immediately when the prefix is
already prepared).

## Steam Setup

Add this to the game's Steam Launch Options:

```text
$HOME/.local/share/wand-launcher/wand %command%
```

Environment variables go **in front** of the wrapper:

```text
PROTON_ENABLE_WAYLAND=1 $HOME/.local/share/wand-launcher/wand %command%
```

Then launch the game normally through Steam.

> Why the wrapper: Steam sometimes hands leading `KEY=VALUE` launch-option tokens
> to the program as arguments instead of environment variables. The launcher then
> tries to run `PROTON_ENABLE_WAYLAND=1` as a program and dies with
> `[Errno 2] No such file or directory: 'PROTON_ENABLE_WAYLAND=1'`, so the game
> never starts. The wrapper turns those tokens back into real environment
> variables before starting the launcher.

## Horizon Forbidden West Complete Edition (Steam AppID 2420110)

The game is single-player with no anti-cheat, and Wand has an official trainer
for it.

1. Start the game once **without** the launcher so Steam creates its Proton
   prefix, then quit it.
2. Prepare the prefix:

   ```bash
   ./install.sh --prepare-hfw
   ```

   This downloads Wand's prepared prefix (about 960 MB), unpacks it over
   `compatdata/2420110`, and keeps your saves. It refuses to touch anything if
   the download looks wrong, and it leaves the previous prefix behind for
   rollback.
3. Launch Options:

   ```text
   $HOME/.local/share/wand-launcher/wand %command%
   ```

   No `VKD3D_DISABLE_EXTENSIONS=...` is needed for this game; vkd3d-proton
   already special-cases `HorizonForbiddenWest.exe`.
4. Start the game. Wand opens next to it and the game launches; log in once.
5. Wand no longer auto-detects games. Add it manually with *Add game* and point it
   at:

   ```text
   Z:\home\<you>\.local\share\Steam\steamapps\common\Horizon Forbidden West Complete Edition\HorizonForbiddenWest.exe
   ```

6. Attach the trainer **after** reaching the main menu. The first start compiles
   Decima's pipeline cache and can take 5-15 minutes, during which the game looks
   frozen.

### Why not let the launcher do it ("build" vs "download")

The launcher's *Prefix Setup* dialog offers **download** (recommended) or
**build**. Both replace or modify the game's Proton prefix, which is where this
game stores its saves:

```text
~/.local/share/Steam/steamapps/compatdata/2420110/pfx/drive_c/users/steamuser/Documents/Horizon Forbidden West Complete Edition/<steamid>/
```

`--prepare-hfw` handles that safely. If you do it through the dialog instead,
pick **download** and back the prefix up first:

```bash
cp -a ~/.local/share/Steam/steamapps/compatdata/2420110 \
      ~/wand-prefix-backup-2420110
```

**build** additionally installs dotnet48 and DirectX/vkd3d overrides into your
working game prefix, takes a long time, and is the usual source of `.NET error`
inside Wand.

### Proton version

Wand's newest prepared prefix is built on **GE-Proton10.1**. Because
`--prepare-hfw` installs an already-prepared prefix, the launcher never rebuilds
it, so the game can keep running on whatever Proton version it already uses
(GE-Proton11 works fine here). If you prefer the launcher to install Wand itself,
use a matching `GE-Proton10-*` instead.

## Troubleshooting

`Download Failed ... ndp48-x86-x64-allos-enu.exe ... No such file or directory`
: An upstream bug where `get_dotnet48()` passed an absolute path into
  `popup_download()`, producing `.../.cache/./home/<you>/.cache/ndp48-...exe`.
  This installer patches `src/mainutils.py` to pass a bare file name. Re-run
  `./install.sh` after any launcher update, because the launcher's self-update
  runs `git reset --hard`.

`[Errno 2] No such file or directory: 'SOME_VAR=...'`
: The game was started through the bundled `wemod` entry point instead of the
  `wand` wrapper. Switch the launch option to
  `$HOME/.local/share/wand-launcher/wand %command%`.

`'NoneType' object has no attribute 'split'`
: Same cause: the launcher was started outside Steam without
  `STEAM_COMPAT_TOOL_PATHS`. The `wand` wrapper sets it.

`.NET error` inside Wand
: Proton/prefix mismatch, usually from letting the launcher *build* a prefix on a
  Proton major version that differs from the prepared one. Use
  `./install.sh --prepare-hfw`, or force `GE-Proton10-*` for the game.

Wand opens but the game is missing
: Add the game manually (step 5). Game detection is a Wand-side limitation, not
  something the launcher can control.

## Requirements

- CachyOS / Arch Linux
- Steam (native package)
- Proton, GE-Proton recommended
- git, python, tk, curl, unzip

## Running it for anyone (global installer)

This repository is now a **global, per-user installer**:

- Files install into `~/.local/share/wand-launcher`, so one checkout works for
  every user that logs into the machine. No `sudo`, no system-wide files, no
  root-owned paths.
- The `wand` wrapper is placed next to the installed launcher and is git-ignored
  (it is generated, not committed), so each user can keep their own settings and
  the project stays clean.

## Shared mods

Wand stores its user data in a single place, so a shared folder can expose it to
the whole machine:

- **Windows (Z:\\)**: `Z:\home\<user>\.local\share\wand\data`
- **Linux**: `~/.local/share/wand/data`

From the Linux box (adjust `<user>` to the account that runs the game):

```bash
sudo mkdir -p /mnt/shared-data
sudo chown <user>:<user> /mnt/shared-data
ln -s /home/<user>/.local/share/wand/data /mnt/shared-data/data
```

Both the game and Wand then read and write the same profile files, so all mods
created or downloaded by any account appear for all of them.

## Disclaimer

This is an unofficial community installer and is not affiliated with or endorsed
by Wand, DeckCheatz, or any game developer or publisher.

The `wand-launcher` project is maintained separately by DeckCheatz.

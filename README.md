# Wand Linux Installer

**Steam game trainer installer for Linux (CachyOS / Arch).**

Unofficial installer for running the **Wand** (formerly WeMod) Windows trainer app
with Steam Proton games on **CachyOS / Arch Linux**.

This project is **self-contained**: it packages the Wand launcher (Python source,
virtual environment, wemod_data, and the `wand` wrapper) directly into the
repository. No external clone or upstream dependency is required at install time.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/rvnrootx/wand-linux-installer/main/install.sh | bash
```

or from a clone:

```bash
git clone https://github.com/rvnrootx/wand-linux-installer.git
cd wand-linux-installer
./install.sh
```

Re-run it at any time to update the launcher. No game-specific flags are needed
for a plain install; the launcher works for any Steam game you point it at.

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

## Adding a Steam game (optional)

Wand tracks games by their Steam AppID. To set up a specific game for Wand:

```bash
./install.sh --game <AppID>
```

For example:

```bash
./install.sh --game 2420110
```

This:

- Finds the game's Proton prefix (`~/.local/share/Steam/steamapps/compatdata/<AppID>`).
- Downloads Wand's prepared prefix (about 960 MB) and swaps it in, keeping the
  game's `drive_c/users` data (saves, configs) inside the new prefix.
- Refuses to run if the downloaded prefix lacks the Wand marker or is incomplete.
- Leaves the old prefix behind under `~/.local/share/Steam/steamapps/compatdata/` for rollback.

The launcher itself is game-agnostic: it installs the same launcher for every
game. `--game` only prepares the prefix so Wand can find and launch the chosen
game.

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
  Proton major version that differs from the prepared one. Use a prepared prefix
  (the launcher's download path), and verify the game runs on the same Proton
  major the prefix was built for.

Wand opens but the game is missing
: Add the game manually (Add game). Game detection is a Wand-side limitation, not
  something the launcher can control.

## Requirements

- CachyOS / Arch Linux
- Steam (native package)
- Proton, GE-Proton recommended
- git, python, tk, curl, unzip

## Running it for anyone (global installer)

This repository is a **global, per-user installer**:

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

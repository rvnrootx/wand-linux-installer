#!/usr/bin/env bash
#
# Wand (WeMod) launcher installer for CachyOS / Arch Linux.
#
# Self-contained installer for the Wand game trainer. It installs the Wand
# launcher (Python source, wemod_venv, wemod_data, winetricks) directly from
# this repository into ~/.local/share/wand-launcher, adds a `wand` wrapper that
# fixes Steam launch options containing environment variables, and optionally
# sets up a Steam game prefix for a specific game.
#
# Usage:
#   ./install.sh                 install / update the launcher
#   ./install.sh --game <AppID>  also set up a Steam game prefix for Wand
#   ./install.sh --uninstall     remove the launcher again (game saves are kept)
#   ./install.sh --uninstall --game <AppID>
#                                also clear Wand's marker from that game prefix
#   ./install.sh --help
#
set -euo pipefail

INSTALL_DIR="${WAND_INSTALL_DIR:-$HOME/.local/share/wand-launcher}"
STEAM_DIR="${WAND_STEAM_DIR:-$HOME/.local/share/Steam}"

PREPARE_GAME=0
UNINSTALL=0
ASSUME_YES=0
GAME_APPID=""

# Set when the previous argument was a flag that takes the next one as value.
expect_value=0

for arg in "$@"; do
    if [ "$expect_value" -eq 1 ]; then
        expect_value=0
        case "$arg" in
            -*) ;; # a flag, not a value: let it be parsed below
            *)
                GAME_APPID="$arg"
                continue
                ;;
        esac
    fi

    case "$arg" in
        --game)
            PREPARE_GAME=1
            expect_value=1
            ;;
        --game=*)
            PREPARE_GAME=1
            GAME_APPID="${arg#*=}"
            ;;
        --uninstall)
            UNINSTALL=1
            ;;
        --yes | -y)
            ASSUME_YES=1
            ;;
        --help | -h)
            sed -n '2,/^[^#]/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$arg" >&2
            exit 2
            ;;
    esac
done

step() { printf '\n==> %s\n' "$*"; }
warn() { printf '!!! %s\n' "$*" >&2; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 0. Uninstall (runs before the dependency checks: removing needs none of them)
# ---------------------------------------------------------------------------
if [ "$UNINSTALL" -eq 1 ]; then
    marker=""
    if [ -n "$GAME_APPID" ]; then
        marker="$STEAM_DIR/steamapps/compatdata/$GAME_APPID/pfx/.wemod_installer"
    elif [ "$PREPARE_GAME" -eq 1 ]; then
        die "--uninstall --game requires a Steam AppID (for example: --uninstall --game 2420110)"
    fi

    if ps -eo args= | grep -qE "[W]eMod\.exe|wand-launcher/(src/)?wemod\.py|wand-launcher/wand( |$)"; then
        die "Wand is still running. Close the game and Wand, then re-run."
    fi

    if [ ! -d "$INSTALL_DIR" ] && { [ -z "$marker" ] || [ ! -e "$marker" ]; }; then
        printf 'Nothing to remove: %s does not exist.\n' "$INSTALL_DIR"
        exit 0
    fi

    step "Uninstalling Wand launcher"

    if [ -d "$INSTALL_DIR" ]; then
        printf 'This removes:\n'
        printf '  %s\n' "$INSTALL_DIR"
        printf '  launcher source, wemod_venv, wemod_data (with your Wand login and\n'
        printf '  downloaded trainer data), the download cache and the wand wrapper.\n'
    fi
    if [ -n "$marker" ] && [ -e "$marker" ]; then
        printf 'This also clears Wand marker from the game prefix for AppID %s.\n' "$GAME_APPID"
    fi
    printf '\nKept: game prefixes, your saves, and any ~/wand-gamepfx-backup-* folders.\n'

    if [ "$ASSUME_YES" -eq 0 ]; then
        # Ask on the terminal: when this script is piped into bash, stdin is the
        # script itself and must not be read here. A readable /dev/tty is not
        # enough (it exists but cannot be opened without a controlling tty), so
        # try to open it for real.
        if { exec 3<>/dev/tty; } 2>/dev/null; then
            printf '\nContinue? [y/N] ' >&3
            read -r answer <&3 || answer=""
            exec 3>&-
            case "$answer" in
                [yY] | [yY][eE][sS]) ;;
                *)
                    printf 'Aborted. Nothing was removed.\n'
                    exit 0
                    ;;
            esac
        else
            die "Refusing to uninstall without confirmation (no terminal). Re-run with --yes."
        fi
    fi

    if [ -n "$marker" ] && [ -e "$marker" ]; then
        rm -f "$marker"
        printf 'Cleared Wand marker from the AppID %s prefix.\n' "$GAME_APPID"
    fi

    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        printf 'Removed %s\n' "$INSTALL_DIR"
    fi

    cat <<EOF

==============================================
 Wand uninstalled
==============================================

Remaining manual step:

 Remove the launch option from the game in Steam
 (Properties -> Launch Options), so it starts normally again.

Game prefixes and saves were not touched; they simply no longer carry Wand's
marker. To restore a prefix that --game replaced, use its backup:

  ls ~/wand-gamepfx-backup-*
  rm -rf "$STEAM_DIR/steamapps/compatdata/<AppID>" &&
    mv ~/wand-gamepfx-backup-<timestamp>/prefix-orig "$STEAM_DIR/steamapps/compatdata/<AppID>"

EOF
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Dependencies
# ---------------------------------------------------------------------------
step "Checking dependencies"

missing=()
pacman -Q git    >/dev/null 2>&1 || missing+=(git)
pacman -Q python >/dev/null 2>&1 || missing+=(python)
pacman -Q tk     >/dev/null 2>&1 || missing+=(tk)

if [ "${#missing[@]}" -gt 0 ]; then
    command -v pacman >/dev/null 2>&1 ||
        die "This installer is for Arch-based distributions. Install ${missing[*]} with your package manager and re-run."
    printf 'Installing: %s\n' "${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
else
    printf 'git, python and tk are already installed\n'
fi

python -c 'import tkinter' >/dev/null 2>&1 ||
    die "Python's tkinter module is missing. Install the 'tk' package and re-run."

command -v unzip >/dev/null 2>&1 || die "The 'unzip' command is missing. Install it with: sudo pacman -S unzip"
command -v curl  >/dev/null 2>&1 || die "The 'curl' command is missing. Install it with: sudo pacman -S curl"

# ---------------------------------------------------------------------------
# 2. Install or update the launcher
# ---------------------------------------------------------------------------
step "Installing Wand launcher into $INSTALL_DIR"

if [ -d "$INSTALL_DIR/.git" ]; then
    printf 'Existing installation found, updating...\n'
    git -C "$INSTALL_DIR" config core.fileMode false
    git -C "$INSTALL_DIR" -c core.fileMode=false pull --ff-only ||
        warn "Could not update automatically; keeping the installed version."
else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    # Copy the launcher source from this repository into place.
    cp -a "$(dirname "$0")/src/." "$INSTALL_DIR/"
    cp "$(dirname "$0")/wand" "$INSTALL_DIR/"
    cp -a "$(dirname "$0")/wemod_data/." "$INSTALL_DIR/wemod_data/"
    git -C "$INSTALL_DIR" config core.fileMode false
    chmod +x "$INSTALL_DIR/wand" "$INSTALL_DIR/src/wemod.py" "$INSTALL_DIR/src/winetricks"
fi

# ---------------------------------------------------------------------------
# 3. Launch wrapper
# ---------------------------------------------------------------------------
step "Writing launch wrapper"

cat >"$INSTALL_DIR/wand" <<'WRAPPER'
#!/usr/bin/env bash
#
# Wand launcher entry point.
#
# Steam launch options are written like this:
#
#   VKD3D_DISABLE_EXTENSIONS=VK_KHR_maintenance8 "$HOME/.local/share/wand-launcher/wand" %command%
#
# Depending on the Steam client / Steam Runtime build, those leading KEY=VALUE
# tokens are handed over as command line arguments instead of environment
# variables. The launcher then tries to execute the assignment itself as a
# program and fails with:
#
#   [Errno 2] No such file or directory: 'VKD3D_DISABLE_EXTENSIONS=...'
#
# This wrapper moves any leading KEY=VALUE arguments into the real environment
# and then hands over to the upstream launcher untouched.
#
set -u

here=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)
target="$here/wemod"

if [ ! -e "$target" ]; then
    printf 'wand: launcher entry point not found at %s\n' "$target" >&2
    exit 127
fi

while [ "$#" -gt 0 ]; do
    [[ "$1" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || break
    export "${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
    shift
done

# The launcher calls .split() on this value unconditionally, so set it when we
# are started outside of Steam (terminal runs, external launchers).
export STEAM_COMPAT_TOOL_PATHS="${STEAM_COMPAT_TOOL_PATHS:-}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-}"

# Wand is an Electron app, and it does not draw a window when Proton runs it
# through Wayland: the process starts, its tray icon shows up, and nothing else
# ever appears, so it looks like the trainer failed to launch. XWayland renders
# it correctly. Everything else (the game itself) keeps working on XWayland too.
# To keep Wayland for the game, add WAND_ALLOW_WAYLAND=1 to the launch options.
if [ "${WAND_ALLOW_WAYLAND:-0}" != "1" ]; then
    export PROTON_ENABLE_WAYLAND=0
fi

# A Wand that crashed, or was closed to the tray, keeps Electron's
# single-instance lock. Every later launch is then handed to that dead window
# and you get the same "only a tray icon" result. Clear a leftover instance of
# a previous run before starting a new one.
pkill -f 'wemod_bin.*WeMod\.exe' 2>/dev/null || true

exec "$target" "$@"
WRAPPER

chmod +x "$INSTALL_DIR/wand"

# ---------------------------------------------------------------------------
# 4. Optional game prefix setup
# ---------------------------------------------------------------------------
if [ "$PREPARE_GAME" -eq 1 ]; then
    if [ -z "$GAME_APPID" ]; then
        die "--game requires a Steam AppID (for example: --game 2420110)"
    fi

    step "Preparing the Steam game prefix for Wand"

    GAME_DIR="$STEAM_DIR/steamapps/common"
    GAME_EXE=""
    if [ -d "$GAME_DIR" ]; then
        for exe in "$GAME_DIR"/*; do
            if [ -f "$exe/$GAME_APPID.exe" ]; then
                GAME_EXE="$exe/$GAME_APPID.exe"
                break
            fi
        done
    fi

    if [ -z "$GAME_EXE" ]; then
        warn "Could not locate the game executable for AppID $GAME_APPID in $GAME_DIR."
        printf 'Put the game in the standard Steam library layout and re-run.\n'
        exit 1
    fi

    PREFIX_DIR="$STEAM_DIR/steamapps/compatdata/$GAME_APPID"
    [ -d "$PREFIX_DIR/pfx" ] || die "No game prefix at $PREFIX_DIR. Start the game once through Steam, quit it, then re-run."

    if [ -e "$PREFIX_DIR/pfx/.wemod_installer" ]; then
        printf 'Wand is already installed in this prefix; nothing to do.\n'
        exit 0
    fi

    if ps -eo args | grep -q "[$GAME_APPID.exe]" 2>/dev/null; then
        die "The game is running. Close it and re-run."
    fi

    backup="$HOME/wand-gamepfx-backup-$(date +%Y%m%d-%H%M%S)"
    saves="$PREFIX_DIR/pfx/drive_c/users/steamuser/Documents"
    mkdir -p "$backup"
    if [ -d "$saves" ]; then
        cp -a "$saves" "$backup/saves"
        printf 'Saves backed up to %s/saves\n' "$backup"
    else
        printf 'No saves in this prefix yet.\n'
    fi

    zip="$INSTALL_DIR/src/.cache/wemod_prefix10.1.zip"
    mkdir -p "$(dirname "$zip")"
    if [ ! -f "$zip" ]; then
        printf 'Downloading the prepared prefix (about 960 MB)...\n'
        curl -L --fail --retry 3 --progress-bar -o "$zip.part" \
            "https://github.com/DeckCheatz/BuiltPrefixes-dev/releases/download/PfxVer10.1/GE-Proton10.1.zip"
        mv "$zip.part" "$zip"
    else
        printf 'Using cached download: %s\n' "$zip"
    fi

    stage="$INSTALL_DIR/src/.cache/game-prep"
    rm -rf "$stage"
    mkdir -p "$stage"
    unzip -q "$zip" -d "$stage" || die "Could not unpack $zip"

    [ -e "$stage/pfx/.wemod_installer" ] ||
        die "The downloaded prefix has no Wand marker. Aborting without touching your game prefix."
    [ -d "$stage/pfx/drive_c" ] ||
        die "The downloaded prefix is incomplete. Aborting without touching your game prefix."

    printf 'Swapping prefixes (the old one moves into %s)\n' "$backup"
    mv "$PREFIX_DIR" "$backup/prefix-orig"
    mv "$stage" "$PREFIX_DIR"

    # Keep Steam's bookkeeping so the game still launches with the same tool.
    for name in version config_info; do
        if [ -e "$backup/prefix-orig/$name" ]; then
            cp -a "$backup/prefix-orig/$name" "$PREFIX_DIR/$name"
        fi
    done

    # Dosdevices are relative symlinks; reuse the ones that already worked.
    mkdir -p "$PREFIX_DIR/pfx/dosdevices"
    if [ -d "$backup/prefix-orig/pfx/dosdevices" ]; then
        cp -a "$backup/prefix-orig/pfx/dosdevices/." "$PREFIX_DIR/pfx/dosdevices/"
    else
        ln -sfn ../drive_c "$PREFIX_DIR/pfx/dosdevices/c:"
        ln -sfn / "$PREFIX_DIR/pfx/dosdevices/z:"
    fi

    # Restore saves into the profile the prefix registry expects (steamuser).
    users="$PREFIX_DIR/pfx/drive_c/users"
    mkdir -p "$users/steamuser/Documents"
    if [ -d "$backup/saves" ]; then
        cp -a "$backup/saves" "$users/steamuser/Documents"
        printf 'Saves restored into the new prefix.\n'
    fi
    [ -e "$users/$(id -un)" ] || ln -s "$users/steamuser" "$users/$(id -un)"

    rm -f "$zip"

    printf '\nPrefix prepared. Rollback if anything looks wrong:\n'
    printf '  rm -rf "%s" && mv "%s/prefix-orig" "%s"\n' "$PREFIX_DIR" "$backup" "$PREFIX_DIR"
fi

# ---------------------------------------------------------------------------
# 5. Instructions
# ---------------------------------------------------------------------------
cat <<EOF

==============================================
 Wand Linux setup complete
==============================================

Steam -> Properties -> Launch Options:

  $INSTALL_DIR/wand %command%

Environment variables (only if you need them) go in front:

  VKD3D_DISABLE_EXTENSIONS=VK_KHR_maintenance8 $INSTALL_DIR/wand %command%

Then:

 1. Start the game through Steam. Wand opens next to it and the game starts.
 2. Log in to Wand once.
 3. If Wand does not detect the game, add it manually (Add game) and point it at
    the game's executable.
 4. Attach the trainer only after the game reaches the main menu: the first
    start compiles the game's pipeline cache and can take several minutes.

Notes:
 - Re-run this installer to update the launcher (it also re-applies the
   dotnet48 download fix, which an upstream `git reset --hard` removes).
 - To set up a different game prefix, run this again with:
   ./install.sh --game <AppID>
 - To remove the launcher again:
   ./install.sh --uninstall
   (add --game <AppID> to also clear Wand's marker from that game's prefix)

EOF

#!/usr/bin/env bash
#
# Wand (WeMod) launcher installer for CachyOS / Arch Linux.
#
# Installs https://github.com/DeckCheatz/wemod-launcher, adds a small `wand`
# wrapper that makes Steam launch options containing environment variables work,
# and optionally lets you set up a Steam game prefix for Wand.
#
# Usage:
#   ./install.sh                 install / update the launcher
#   ./install.sh --game APPID    also set up a game prefix for Wand
#   ./install.sh --help
#
set -euo pipefail

REPO_URL="https://github.com/DeckCheatz/wemod-launcher.git"
INSTALL_DIR="${WAND_INSTALL_DIR:-$HOME/.local/share/wand-launcher}"
STEAM_DIR="${WAND_STEAM_DIR:-$HOME/.local/share/Steam}"

PREPARE_GAME=0
GAME_APPID=""

for arg in "$@"; do
    case "$arg" in
        --game)
            PREPARE_GAME=1
            ;;
        --game=*)
            PREPARE_GAME=1
            GAME_APPID="${arg#*=}"
            ;;
        --help | -h)
            sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
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
step "Installing wand-launcher into $INSTALL_DIR"

if [ -d "$INSTALL_DIR/.git" ]; then
    printf 'Existing installation found, updating...\n'
    # Old versions of this installer ran `chmod -R ug+x` on the whole clone,
    # which shows up as local mode changes and makes `git pull` fail later.
    git -C "$INSTALL_DIR" config core.fileMode false
    git -C "$INSTALL_DIR" -c core.fileMode=false pull --ff-only ||
        warn "Could not update automatically; keeping the installed version."
else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$REPO_URL" "$INSTALL_DIR"
    git -C "$INSTALL_DIR" config core.fileMode false
fi

# Only the entry points need the executable bit; do not touch the whole tree.
chmod ug+x "$INSTALL_DIR/src/wemod.py" "$INSTALL_DIR/src/winetricks" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 3. Patch: dotnet48 download built a doubled path and always failed
# ---------------------------------------------------------------------------
step "Patching launcher bugs"

# get_dotnet48() passed the *absolute* cache path into popup_download(), which
# joins it onto the cache directory again, so the "build prefix" path died with:
#
#   Failed to download '....cache/ndp48-x86-x64-allos-enu.exe':
#   [Errno 2] No such file or directory:
#   '....cache/./home/<user>/.local/share/wand-launcher/src/.cache/ndp48-...exe'
#
# cache(..., simple=True) hands the downloader a bare file name, which is what
# popup_download() expects (the prefix download already uses it that way).
python - "$INSTALL_DIR/src/mainutils.py" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
broken = 'cache("ndp48-x86-x64-allos-enu.exe", cache_func)'
fixed = 'cache("ndp48-x86-x64-allos-enu.exe", cache_func, True)'

try:
    source = path.read_text()
except OSError as error:
    print(f"could not read {path}: {error}")
    raise SystemExit(0)

if fixed in source:
    print("dotnet48 download fix already present")
elif broken in source:
    path.write_text(source.replace(broken, fixed, 1))
    print("applied dotnet48 download fix")
else:
    print("dotnet48 fix not needed (upstream code changed); skipping")
PY

# ---------------------------------------------------------------------------
# 4. Launch wrapper
# ---------------------------------------------------------------------------
step "Writing launch wrapper"

cat >"$INSTALL_DIR/wand" <<'WRAPPER'
#!/usr/bin/env bash
#
# Wand launcher entry point.
#
# Steam launch options are written like this:
#
#   PROTON_ENABLE_WAYLAND=1 "$HOME/.local/share/wand-launcher/wand" %command%
#
# Depending on the Steam client / Steam Runtime build, those leading KEY=VALUE
# tokens are handed over as command line arguments instead of environment
# variables. The launcher then tries to execute "PROTON_ENABLE_WAYLAND=1" as a
# program and fails with:
#
#   [Errno 2] No such file or directory: 'PROTON_ENABLE_WAYLAND=1'
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

exec "$target" "$@"
WRAPPER

chmod +x "$INSTALL_DIR/wand"

# ---------------------------------------------------------------------------
# 5. Optional game prefix setup
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

    if ps -eo args | grep -q "[$(basename "$GAME_EXE")]" 2>/dev/null; then
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
    mkdir -p "$PREFFIX_DIR/pfx/dosdevices"
    if [ -d "$backup/prefix-orig/pfx/dosdevices" ]; then
        cp -a "$backup/prefix-orig/pfx/dosdevices/." "$PREFFIX_DIR/pfx/dosdevices/"
    else
        ln -sfn ../drive_c "$PREFFIX_DIR/pfx/dosdevices/c:"
        ln -sfn / "$PREFFIX_DIR/pfx/dosdevices/z:"
    fi

    # Restore saves into the profile the prefix registry expects (steamuser).
    local users="$PREFFIX_DIR/pfx/drive_c/users"
    mkdir -p "$users/steamuser/Documents"
    if [ -d "$backup/saves" ]; then
        cp -a "$backup/saves" "$users/steamuser/Documents"
        printf 'Saves restored into the new prefix.\n'
    fi
    [ -e "$users/$(id -un)" ] || ln -s "$users/steamuser" "$users/$(id -un)"

    rm -f "$zip"

    printf '\nPrefix prepared. Rollback if anything looks wrong:\n'
    printf '  rm -rf "%s" && mv "%s/prefix-orig" "%s"\n' "$PREFFIX_DIR" "$backup" "$PREFFIX_DIR"
fi

# ---------------------------------------------------------------------------
# 6. Instructions
# ---------------------------------------------------------------------------
cat <<EOF

==============================================
 Wand Linux setup complete
==============================================

Steam -> Properties -> Launch Options:

  $INSTALL_DIR/wand %command%

Environment variables (only if you need them) go in front:

  PROTON_ENABLE_WAYLAND=1 $INSTALL_DIR/wand %command%

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

EOF

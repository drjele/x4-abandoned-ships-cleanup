#!/usr/bin/env bash
# Copies extension/ into the X4 installation so the game picks the mod up on its next start.
# X4 only enumerates real directories under extensions/ - a symlink there is silently ignored -
# so this copies rather than links, and has to be re-run after every edit.
#
#   ./install.sh              install / refresh
#   ./install.sh --uninstall  remove it from the game
#
# The game is located automatically from the usual Steam layouts, including extra Steam library
# folders. Set X4_PATH to point somewhere else:
#
#   X4_PATH="/path/to/X4 Foundations" ./install.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/find_x4.sh
source "$REPO_ROOT/lib/find_x4.sh"

if ! GAME_PATH="$(find_x4)"; then
    echo "could not find an X4: Foundations installation - set X4_PATH to point at it" >&2
    exit 1
fi

if [[ ! -d "$GAME_PATH/extensions" ]]; then
    echo "no extensions directory at $GAME_PATH/extensions" >&2
    exit 1
fi

EXTENSION_ID="$(extension_id "$REPO_ROOT/extension/content.xml")"
if [[ -z "$EXTENSION_ID" ]]; then
    echo "could not read the extension id out of extension/content.xml" >&2
    exit 1
fi

TARGET="$GAME_PATH/extensions/$EXTENSION_ID"

if [[ "${1:-}" == "--uninstall" ]]; then
    rm -rf -- "$TARGET"
    echo "removed $TARGET"
    echo "restart X4 for the change to take effect"
    exit 0
fi

rm -rf -- "$TARGET"
mkdir -p -- "$TARGET"
if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$REPO_ROOT/extension/" "$TARGET/"
else
    cp -r -- "$REPO_ROOT/extension/." "$TARGET/"
fi

echo "installed $TARGET"
echo "restart X4 for the change to take effect"

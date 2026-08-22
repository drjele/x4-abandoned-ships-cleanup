#!/usr/bin/env bash
# Copies extension/ into the X4 installation so the game picks the mod up on its next start.
# X4 only enumerates real directories under extensions/ - a symlink there is silently ignored -
# so this copies rather than links, and has to be re-run after every edit.
#
#   ./install.sh              install / refresh
#   ./install.sh --uninstall  remove it from the game
#   X4_PATH=... ./install.sh  point at a different game location
set -euo pipefail

X4_PATH="${X4_PATH:-/mnt/data/steam-library/steamapps/common/X4 Foundations}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSION_ID="$(sed -n 's/.*<content[^>]*id="\([^"]*\)".*/\1/p' "$REPO_ROOT/extension/content.xml" | head -1)"

if [[ -z "$EXTENSION_ID" ]]; then
    echo "could not read the extension id out of extension/content.xml" >&2
    exit 1
fi
if [[ ! -d "$X4_PATH/extensions" ]]; then
    echo "no extensions directory at $X4_PATH/extensions - set X4_PATH" >&2
    exit 1
fi

TARGET="$X4_PATH/extensions/$EXTENSION_ID"

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

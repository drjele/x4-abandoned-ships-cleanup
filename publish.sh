#!/usr/bin/env bash
# Publishes the extension to the Steam Workshop for X4: Foundations (app 392160).
#
#   ./publish.sh publish                    first upload
#   ./publish.sh update "what changed"      subsequent uploads, changenote is mandatory
#
# Egosoft does this with WorkshopTool, shipped in the "X Tools" package - Steam app 282160,
# steam://install/282160. It is a Windows executable, so on Linux it is run through Proton: plain
# wine cannot reach the native Steam client that Steamworks needs. Steam has to be running and
# logged in either way.
#
# The tool writes the Workshop id it gets back into content.xml. That id must not end up in the
# repo copy - a manual install would then claim the same extension id as a Workshop subscription
# and X4 would see the two as one. So the repo keeps the readable id, steam/workshop-id keeps the
# numeric one, and the substitution happens only in the copy staged inside the game.
#
# Overrides: X4_PATH, X_TOOLS_PATH, PROTON_PATH.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/find_x4.sh
source "$REPO_ROOT/lib/find_x4.sh"

WORKSHOP_ID_FILE="$REPO_ROOT/steam/workshop-id"

die() { echo "$*" >&2; exit 1; }

usage() {
    cat >&2 <<'USAGE'
usage:
  ./publish.sh publish                 first upload of the extension
  ./publish.sh update "what changed"   update the published item
USAGE
    exit 2
}

COMMAND="${1:-}"
case "$COMMAND" in
    publish)
        [[ $# -eq 1 ]] || usage
        [[ -f "$WORKSHOP_ID_FILE" ]] \
            && die "$WORKSHOP_ID_FILE already exists - the item is published, use: ./publish.sh update \"...\""
        ;;
    update)
        [[ $# -eq 2 && -n "${2:-}" ]] || usage
        CHANGENOTE="$2"
        [[ -f "$WORKSHOP_ID_FILE" ]] \
            || die "no $WORKSHOP_ID_FILE - nothing has been published yet, use: ./publish.sh publish"
        ;;
    *) usage ;;
esac

# WorkshopTool.exe, out of the X Tools package.
find_workshop_tool() {
    local candidate
    if [[ -n "${X_TOOLS_PATH:-}" ]]; then
        if [[ -f "$X_TOOLS_PATH" ]]; then
            printf '%s\n' "$X_TOOLS_PATH"
            return 0
        fi
        candidate="$X_TOOLS_PATH/WorkshopTool.exe"
        [[ -f "$candidate" ]] || return 1
        printf '%s\n' "$candidate"
        return 0
    fi
    local dir
    dir="$(find_in_libraries "X Tools")" || return 1
    candidate="$(find "$dir" -maxdepth 2 -iname 'WorkshopTool.exe' -print -quit)"
    [[ -n "$candidate" ]] || return 1
    printf '%s\n' "$candidate"
}

# Newest Proton in any Steam library. Only used off Windows.
find_proton() {
    if [[ -n "${PROTON_PATH:-}" ]]; then
        [[ -x "$PROTON_PATH/proton" ]] || return 1
        printf '%s\n' "$PROTON_PATH"
        return 0
    fi
    local library best=""
    while IFS= read -r library; do
        local dir
        for dir in "$library"/steamapps/common/Proton*; do
            [[ -x "$dir/proton" ]] || continue
            best="$dir"
            [[ "$dir" == *Experimental* ]] && { printf '%s\n' "$dir"; return 0; }
        done
    done < <(steam_libraries)
    [[ -n "$best" ]] || return 1
    printf '%s\n' "$best"
}

steam_root() {
    local library
    while IFS= read -r library; do
        printf '%s\n' "$library"
        return 0
    done < <(steam_libraries)
    return 1
}

# Proton maps the host root at Z:, so /a/b becomes Z:\a\b.
win_path() {
    printf 'Z:%s\n' "${1//\//\\}"
}

if ! GAME_PATH="$(find_x4)"; then
    die "could not find an X4: Foundations installation - set X4_PATH to point at it"
fi
[[ -d "$GAME_PATH/extensions" ]] || die "no extensions directory at $GAME_PATH/extensions"

if ! TOOL="$(find_workshop_tool)"; then
    die "could not find WorkshopTool.exe - install the X Tools package (steam://install/282160),
or set X_TOOLS_PATH to the directory holding it"
fi

EXTENSION_ID="$(extension_id "$REPO_ROOT/extension/content.xml")"
[[ -n "$EXTENSION_ID" ]] || die "could not read the extension id out of extension/content.xml"
STAGE="$GAME_PATH/extensions/$EXTENSION_ID"
[[ -f "$REPO_ROOT/extension/preview.jpg" ]] || die "extension/preview.jpg is missing"

echo "game:  $GAME_PATH"
echo "tool:  $TOOL"
echo "stage: $STAGE"

# Stage a clean copy of the extension inside the game, then swap in the Workshop id if we have one.
rm -rf -- "$STAGE"
mkdir -p -- "$STAGE"
cp -r -- "$REPO_ROOT/extension/." "$STAGE/"

if [[ -f "$WORKSHOP_ID_FILE" ]]; then
    WORKSHOP_ID="$(tr -cd '0-9' < "$WORKSHOP_ID_FILE")"
    [[ -n "$WORKSHOP_ID" ]] || die "$WORKSHOP_ID_FILE holds no digits"
    sed -i "s/id=\"$EXTENSION_ID\"/id=\"ws_$WORKSHOP_ID\"/" "$STAGE/content.xml"
    echo "item:  ws_$WORKSHOP_ID"
fi

# The tool is interactive - it asks before uploading - so it inherits this terminal untouched.
run_tool() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*|Windows_NT)
            ( cd "$(dirname "$TOOL")" && ./"$(basename "$TOOL")" "$@" )
            ;;
        *)
            local proton steam prefix
            proton="$(find_proton)" \
                || die "could not find Proton - install any Proton version from Steam, or set PROTON_PATH"
            steam="$(steam_root)"
            prefix="$(dirname "$(dirname "$TOOL")")/../compatdata/282160"
            mkdir -p -- "$prefix"
            echo "proton: $proton"
            STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam" \
            STEAM_COMPAT_DATA_PATH="$(cd "$prefix" && pwd)" \
                "$proton/proton" run "$TOOL" "$@"
            ;;
    esac
}

STAGE_WIN="$(win_path "$STAGE")"
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT) STAGE_WIN="$STAGE" ;;
esac

if [[ "$COMMAND" == "publish" ]]; then
    run_tool publishx4 -path "$STAGE_WIN" -preview "$STAGE_WIN\\preview.jpg" -buildcat
else
    run_tool update -path "$STAGE_WIN" -buildcat -changenote "$CHANGENOTE"
fi

# The tool wrote the item id into the staged content.xml. Keep it, the staged copy is thrown away.
NEW_ID="$(extension_id "$STAGE/content.xml" | tr -cd '0-9')"
if [[ "$COMMAND" == "publish" ]]; then
    [[ -n "$NEW_ID" ]] || die "the tool did not write a Workshop id into $STAGE/content.xml - upload failed?"
    mkdir -p -- "$(dirname "$WORKSHOP_ID_FILE")"
    printf '%s\n' "$NEW_ID" > "$WORKSHOP_ID_FILE"
    echo
    echo "published as https://steamcommunity.com/sharedfiles/filedetails/?id=$NEW_ID"
    echo "the item is hidden until you open that page, accept the Steam Workshop Legal Agreement"
    echo "and set the visibility to public"
    echo
    echo "commit the new $WORKSHOP_ID_FILE - ./publish.sh update needs it"
fi

# Put the local install back to the repo's content.xml, so it does not collide with a subscription.
"$REPO_ROOT/install.sh" >/dev/null
echo "local install restored to id=$EXTENSION_ID"

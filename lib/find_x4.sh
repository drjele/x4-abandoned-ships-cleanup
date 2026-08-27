# Locating the Steam bits everything else needs. Sourced by install.sh and publish.sh; not
# executable on its own.
#
#   steam_libraries        every Steam library folder, one per line
#   find_x4                the X4 Foundations directory, honouring X4_PATH
#   find_in_libraries NAME a steamapps/common/NAME directory from any library

steam_libraries() {
    local roots=(
        "$HOME/.steam/steam"
        "$HOME/.local/share/Steam"
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
        "$HOME/snap/steam/common/.local/share/Steam"
        "$HOME/Library/Application Support/Steam"
    )
    local root vdf line
    for root in "${roots[@]}"; do
        [[ -d "$root" ]] || continue
        printf '%s\n' "$root"
        vdf="$root/steamapps/libraryfolders.vdf"
        [[ -f "$vdf" ]] || continue
        while IFS= read -r line; do
            printf '%s\n' "$line"
        done < <(sed -n 's/.*"path"[[:space:]]*"\(.*\)".*/\1/p' "$vdf")
    done
}

find_in_libraries() {
    local name="$1" library
    while IFS= read -r library; do
        if [[ -d "$library/steamapps/common/$name" ]]; then
            printf '%s\n' "$library/steamapps/common/$name"
            return 0
        fi
    done < <(steam_libraries)
    return 1
}

find_x4() {
    if [[ -n "${X4_PATH:-}" ]]; then
        printf '%s\n' "$X4_PATH"
        return 0
    fi
    local library
    while IFS= read -r library; do
        if [[ -x "$library/steamapps/common/X4 Foundations/X4" ]] \
        || [[ -f "$library/steamapps/common/X4 Foundations/X4.exe" ]]; then
            printf '%s\n' "$library/steamapps/common/X4 Foundations"
            return 0
        fi
    done < <(steam_libraries)
    return 1
}

extension_id() {
    sed -n 's/.*<content[^>]*id="\([^"]*\)".*/\1/p' "$1" | head -1
}

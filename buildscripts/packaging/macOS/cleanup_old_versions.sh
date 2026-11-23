#!/usr/bin/env bash

# HARD RELEASE POLICY:
# Keep only the current DB Studio app/build artifacts and the newest installer
# package for each platform. This runs after every successful macOS package.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
SOURCE_ROOT="$(dirname "$PROJECT_DIR")"
CANONICAL_APP="/Applications/鼓乐熊Studio.app"
CANONICAL_BINARY="$CANONICAL_APP/Contents/MacOS/dbstudio"
MAC_CANONICAL="$HOME/Desktop/鼓乐熊Studio.dmg"
WINDOWS_CANONICAL="$HOME/Desktop/鼓乐熊Studio.msi"
DRY_RUN=false
KEEP_DMG=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --keep-dmg)
            KEEP_DMG="${2:-}"
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
    shift
done

removed_paths=()
kept_apps=()
kept_mac_packages=()
kept_windows_packages=()

is_protected_app() {
    local candidate="$1"
    local protected
    for protected in \
        "$CANONICAL_APP" \
        "$PROJECT_DIR/applebuild/dbstudio.app" \
        "$PROJECT_DIR/builds/Mac-Qt6.10.2-macos-Ninja-Release/src/studio/dbstudio.app"; do
        if [[ "$candidate" == "$protected" ]]; then
            return 0
        fi
    done
    return 1
}

remove_verified_path() {
    local target="$1"
    if is_protected_app "$target"; then
        echo "Refusing to remove protected application: $target" >&2
        return 0
    fi
    case "$target" in
        /Applications/*|"$HOME/Applications"/*|"$HOME/Desktop"/*|"$HOME/Downloads"/*|"$HOME/Documents/Codex"/*|"$HOME/Library/Containers/com.tencent.xinWeChat"/*|"$HOME/Library/Containers/com.tencent.WeWorkMac"/*|"$SOURCE_ROOT"/*|"$HOME"/*)
            ;;
        *)
            echo "Refusing to remove path outside verified roots: $target" >&2
            exit 1
            ;;
    esac

    if $DRY_RUN; then
        echo "[dry-run] remove $target"
    else
        rm -rf -- "$target"
        echo "Removed $target"
    fi
    removed_paths+=("$target")
}

cleanup_app_copies() {
    local candidates=()
    local app id

    while IFS= read -r app; do
        [[ -n "$app" ]] && candidates+=("$app")
    done < <(
        {
            mdfind "kMDItemCFBundleIdentifier == 'app.dbstudio.DBStudio5' || kMDItemCFBundleIdentifier == 'app.dbstudio.DBStudio5Development'" 2>/dev/null || true
            find /Applications "$HOME/Applications" "$HOME/Desktop" "$HOME/Downloads" \
                -maxdepth 8 -type d \( -iname 'dbstudio.app' -o -iname 'db studio*.app' -o -iname 'DBStudio*.app' \) \
                -prune -print 2>/dev/null || true
        } | sort -u
    )

    for app in "${candidates[@]}"; do
        if is_protected_app "$app"; then
            kept_apps+=("$app")
            continue
        fi
        [[ -d "$app" ]] || continue
        if [[ -f "$app/Contents/Info.plist" ]]; then
            id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null || true)
            [[ "$id" == "app.dbstudio.DBStudio5" || "$id" == "app.dbstudio.DBStudio5Development" ]] || continue
        fi
        remove_verified_path "$app"
    done
}

cleanup_old_build_directories() {
    local directory
    while IFS= read -r directory; do
        [[ -n "$directory" ]] && remove_verified_path "$directory"
    done < <(
        find "$PROJECT_DIR" -maxdepth 1 -type d -name 'applebuild.old.*' -print | sort
    )

    while IFS= read -r directory; do
        [[ -n "$directory" ]] && remove_verified_path "$directory"
    done < <(
        find "$SOURCE_ROOT" -maxdepth 1 -type d -name '_旧源码备份_*' -print | sort
    )
}

cleanup_mac_packages() {
    local all_candidates=()
    local candidates=()
    local package chosen=""

    while IFS= read -r package; do
        [[ -n "$package" ]] && all_candidates+=("$package")
    done < <(
        find "$PROJECT_DIR/applebuild" "$HOME/Desktop" -maxdepth 1 -type f \
            \( -iname '*dbstudio*.dmg' -o -iname '*db*studio*.dmg' -o -iname '*dbstudio*.pkg' -o -iname '*db*studio*.pkg' \) \
            -print 2>/dev/null | sort
        find "$HOME/Downloads" -maxdepth 4 -type f \
            \( -iname '*dbstudio*.dmg' -o -iname '*db*studio*.dmg' -o -iname '*dbstudio*.pkg' -o -iname '*db*studio*.pkg' \) \
            -print 2>/dev/null | sort
    )

    local canonical_mtime=0
    if [[ -f "$CANONICAL_BINARY" ]]; then
        canonical_mtime=$(stat -f '%m' "$CANONICAL_BINARY")
    fi
    if [[ ${#all_candidates[@]} -gt 0 ]]; then
        for package in "${all_candidates[@]}"; do
            if [[ "$(stat -f '%m' "$package")" -ge "$canonical_mtime" ]]; then
                candidates+=("$package")
            fi
        done
    fi

    if [[ -n "$KEEP_DMG" && -f "$KEEP_DMG" && "$(stat -f '%m' "$KEEP_DMG")" -ge "$canonical_mtime" ]]; then
        chosen="$KEEP_DMG"
    elif [[ -f "$MAC_CANONICAL" && "$(stat -f '%m' "$MAC_CANONICAL")" -ge "$canonical_mtime" ]]; then
        chosen="$MAC_CANONICAL"
    elif [[ ${#candidates[@]} -gt 0 ]]; then
        chosen=$(for package in "${candidates[@]}"; do
            printf '%s\t%s\n' "$(stat -f '%m' "$package")" "$package"
        done | sort -nr | head -n 1 | cut -f2-)
    fi

    if [[ ${#all_candidates[@]} -gt 0 ]]; then
        for package in "${all_candidates[@]}"; do
            if [[ "$package" == "$chosen" ]]; then
                kept_mac_packages+=("$package")
            else
                remove_verified_path "$package"
            fi
        done
    fi
}

cleanup_windows_packages() {
    local all_candidates=()
    local keep_windows=()
    local package
    local versioned=""

    while IFS= read -r package; do
        [[ -f "$package" ]] || continue
        case "$(basename "$package" | tr '[:upper:]' '[:lower:]')" in
            dbstudio.exe|dbstudio5.exe)
                continue
                ;;
        esac
        all_candidates+=("$package")
    done < <(
        {
            find "$HOME" -maxdepth 1 -type f \
                \( -iname '*db*studio*.exe' -o -iname '*db*studio*.msi' -o -iname '*db*studio*.win' -o -iname '*db*studio*.zip' -o -iname '*db*studio*.7z' -o -iname '*db*studio*.appx' -o -iname '*db*studio*.msix' \) \
                -print 2>/dev/null || true
            find "$HOME/Desktop" "$HOME/Downloads" "$PROJECT_DIR/applebuild" -maxdepth 4 -type f \
                \( -iname '*db*studio*.exe' -o -iname '*db*studio*.msi' -o -iname '*db*studio*.win' -o -iname '*db*studio*.zip' -o -iname '*db*studio*.7z' -o -iname '*db*studio*.appx' -o -iname '*db*studio*.msix' \) \
                -print 2>/dev/null || true
            mdfind "kMDItemFSName == '*DB*Studio*.exe'c || kMDItemFSName == '*DB*Studio*.msi'c || kMDItemFSName == '*DB*Studio*.zip'c || kMDItemFSName == '*DB*Studio*.7z'c" 2>/dev/null || true
        } | sort -u
    )

    [[ -f "$WINDOWS_CANONICAL" ]] && keep_windows+=("$WINDOWS_CANONICAL")

    versioned=$(
        find "$HOME" "$HOME/Desktop" "$HOME/Downloads" -maxdepth 1 -type f \
            -iname 'DB-Studio-Windows-*.msi' -print 2>/dev/null |
        sort -u |
        while IFS= read -r package; do
            printf '%s\t%s\n' "$(stat -f '%m' "$package")" "$package"
        done |
        sort -nr |
        head -n 1 |
        cut -f2-
    )
    if [[ -n "$versioned" && "$versioned" != "$WINDOWS_CANONICAL" ]]; then
        keep_windows+=("$versioned")
    fi

    if [[ ${#all_candidates[@]} -gt 0 ]]; then
        for package in "${all_candidates[@]}"; do
            local keep=false
            local kept
            for kept in "${keep_windows[@]:-}"; do
                if [[ "$package" == "$kept" ]]; then
                    keep=true
                    break
                fi
            done
            if $keep; then
                kept_windows_packages+=("$package")
                continue
            fi
            remove_verified_path "$package"
        done
    fi
}

cleanup_empty_download_directories() {
    local directory
    while IFS= read -r directory; do
        [[ -n "$directory" ]] && remove_verified_path "$directory"
    done < <(
        find "$HOME/Downloads" -maxdepth 1 -type d -iname '*db*studio*.download' -print 2>/dev/null | sort
    )
}

cleanup_old_build_directories
cleanup_app_copies
cleanup_mac_packages
cleanup_windows_packages
cleanup_empty_download_directories

echo "Kept applications:"
printf '  %s\n' "${kept_apps[@]}"
echo "Kept macOS packages:"
if [[ ${#kept_mac_packages[@]} -eq 0 ]]; then
    echo "  none"
else
    printf '  %s\n' "${kept_mac_packages[@]}"
fi
echo "Kept Windows packages:"
if [[ ${#kept_windows_packages[@]} -eq 0 ]]; then
    echo "  none"
else
    printf '  %s\n' "${kept_windows_packages[@]}"
fi
echo "Cleanup removed ${#removed_paths[@]} old path(s)."

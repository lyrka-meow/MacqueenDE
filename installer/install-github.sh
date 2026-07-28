#!/usr/bin/env bash

set -euo pipefail

repo=${MACQUEENDE_GITHUB_REPO:-lyrka-meow/MacqueenDE}
release_tag=${MACQUEENDE_RELEASE_TAG:-}
arch=$(uname -m)
case "$arch" in
    x86_64) ;;
    *) echo "MacqueenDE binary releases do not support $arch yet." >&2; exit 1 ;;
esac

if command -v pacman >/dev/null; then
    echo "Installing MacqueenDE runtime dependencies..."
    sudo pacman -S --needed --noconfirm \
        kwin spectacle xdg-desktop-portal-kde quickshell \
        cava brightnessctl ddcutil \
        qt6-multimedia qt6-positioning qt6-sensors qt6-svg qt6-5compat \
        qt6-connectivity qt6-imageformats
fi

tmp_dir=$(mktemp -d)
cleanup() { rm -rf -- "$tmp_dir"; }
trap cleanup EXIT

if [[ -n "$release_tag" ]]; then
    release_api="https://api.github.com/repos/$repo/releases/tags/$release_tag"
else
    release_api="https://api.github.com/repos/$repo/releases?per_page=20&cache_bust=$(date +%s)"
fi

asset_url=$(curl -fsSL \
    -H 'Accept: application/vnd.github+json' \
    -H 'Cache-Control: no-cache' \
    "$release_api" |
    sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*macqueende-[^"]*-'"$arch"'\.tar\.zst\)".*/\1/p' |
    head -n1)
[[ -n "$asset_url" ]] || {
    echo "No compatible MacqueenDE release was found." >&2
    exit 1
}

echo "Downloading $(basename "$asset_url")..."
curl -fL --progress-bar "$asset_url" -o "$tmp_dir/macqueende.tar.zst"
curl -fsSL "$asset_url.sha256" -o "$tmp_dir/macqueende.tar.zst.sha256"
(
    cd "$tmp_dir"
    expected=$(awk '{print $1}' macqueende.tar.zst.sha256)
    printf '%s  %s\n' "$expected" macqueende.tar.zst | sha256sum -c -
)
tar --zstd -xf "$tmp_dir/macqueende.tar.zst" -C "$tmp_dir"
"$tmp_dir/install.sh"

if [[ -n "$release_tag" ]]; then
    expected_version=${release_tag#v}
    installed_version=$(cat /opt/macqueende/VERSION 2>/dev/null || true)
    [[ "$installed_version" == "$expected_version" ]] || {
        echo "Installed version mismatch: expected $expected_version, got ${installed_version:-unknown}" >&2
        exit 1
    }
fi

#!/usr/bin/env bash

set -euo pipefail

repo=${MACQUEENDE_GITHUB_REPO:-lyrka-meow/MacqueenDE}
arch=$(uname -m)
case "$arch" in
    x86_64) ;;
    *) echo "MacqueenDE binary releases do not support $arch yet." >&2; exit 1 ;;
esac

tmp_dir=$(mktemp -d)
cleanup() { rm -rf -- "$tmp_dir"; }
trap cleanup EXIT

asset_url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" |
    sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*macqueende-[^"]*-'"$arch"'\.tar\.zst\)".*/\1/p' |
    head -n1)
[[ -n "$asset_url" ]] || {
    echo "No compatible MacqueenDE release was found." >&2
    exit 1
}

curl -fL --progress-bar "$asset_url" -o "$tmp_dir/macqueende.tar.zst"
curl -fsSL "$asset_url.sha256" -o "$tmp_dir/macqueende.tar.zst.sha256"
(
    cd "$tmp_dir"
    expected=$(awk '{print $1}' macqueende.tar.zst.sha256)
    printf '%s  %s\n' "$expected" macqueende.tar.zst | sha256sum -c -
)
tar --zstd -xf "$tmp_dir/macqueende.tar.zst" -C "$tmp_dir"
"$tmp_dir/install.sh"

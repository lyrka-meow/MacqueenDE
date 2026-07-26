#!/usr/bin/env bash

set -euo pipefail

payload_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root="$payload_root/opt/macqueende"

[[ -x "$source_root/build/compositor/bin/macqueen" ]] || {
    echo "Invalid MacqueenDE release payload." >&2
    exit 1
}

sudo install -d /opt
new_root="/opt/macqueende.new.$$"
sudo cp -a "$source_root" "$new_root"
if [[ -e /opt/macqueende ]]; then
    backup_root="/opt/macqueende.previous.$(date +%Y%m%d-%H%M%S)"
    sudo mv /opt/macqueende "$backup_root"
fi
sudo mv "$new_root" /opt/macqueende

sudo install -Dm755 /opt/macqueende/start-macqueende /usr/bin/start-macqueende
sed 's|Exec=/usr/local/bin/start-macqueende|Exec=/usr/bin/start-macqueende|' \
    /opt/macqueende/session/macqueende.desktop |
    sudo install -Dm644 /dev/stdin /usr/share/wayland-sessions/macqueende.desktop
sudo install -Dm644 /opt/macqueende/session/macqueende-portals.conf \
    /usr/share/xdg-desktop-portal/macqueende-portals.conf
sed 's|@MACQUEENDE_ROOT@|/opt/macqueende|g' \
    /opt/macqueende/session/org.freedesktop.impl.portal.desktop.kde.desktop.in |
    sudo install -Dm644 /dev/stdin \
        /usr/share/applications/org.macqueen.portal.desktop

echo "MacqueenDE installed. Log out and select MacqueenDE in SDDM."
[[ -z ${backup_root:-} ]] ||
    echo "Previous installation kept at $backup_root."

#!/usr/bin/env bash

set -euo pipefail

sudo rm -f /usr/bin/start-macqueende \
    /usr/share/wayland-sessions/macqueende.desktop \
    /usr/share/xdg-desktop-portal/macqueende-portals.conf \
    /usr/share/applications/org.macqueen.portal.desktop
sudo rm -rf /opt/macqueende

echo "MacqueenDE removed. User configuration in ~/.config was preserved."

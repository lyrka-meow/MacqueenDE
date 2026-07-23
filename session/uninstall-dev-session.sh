#!/usr/bin/env bash

set -euo pipefail

sudo rm -f \
    /usr/local/bin/start-macqueende \
    /usr/share/wayland-sessions/macqueende.desktop \
    /etc/macqueende/dev-root

sudo rmdir /etc/macqueende 2>/dev/null || true

echo "Removed the MacqueenDE development session."

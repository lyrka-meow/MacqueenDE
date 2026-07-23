/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2026 The MacqueenDE contributors
*/

import Macqueen.Ipc
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Scope {
    id: root

    function captureRegion() {
        if (captureProcess.running)
            return;
        PopoutManager.closeAllPopouts();
        PopoutManager.screenshotActive = true;
        captureProcess.running = true;
    }

    Connections {
        target: Macqueen

        function onScreenshotRequested() {
            root.captureRegion();
        }
    }

    IpcHandler {
        target: "macqueen-screenshot"

        function capture(): string {
            root.captureRegion();
            return "SCREENSHOT_STARTED";
        }
    }

    Process {
        id: captureProcess
        command: ["spectacle", "--region", "--new-instance"]
        running: false

        onExited: (exitCode, exitStatus) => {
            PopoutManager.screenshotActive = false;
        }
    }
}

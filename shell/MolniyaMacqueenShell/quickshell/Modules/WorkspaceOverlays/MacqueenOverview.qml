import Macqueen.Ipc
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

Scope {
    id: root

    property bool overviewOpen: false
    property int selectedWindow: -1
    property string draggingWindowId: ""

    readonly property var visibleWindows: Macqueen.windows.filter(window => !window.skipTaskbar)

    function windowsForWorkspace(workspaceId) {
        return visibleWindows.filter(window => (window.workspaces || []).includes(workspaceId));
    }

    function selectRelative(offset) {
        if (visibleWindows.length === 0) {
            selectedWindow = -1;
            return;
        }
        const currentId = Macqueen.activeWindow?.id || "";
        if (selectedWindow < 0)
            selectedWindow = Math.max(0, visibleWindows.findIndex(window => window.id === currentId));
        selectedWindow = (selectedWindow + offset + visibleWindows.length) % visibleWindows.length;
    }

    function open(reason) {
        if (!overviewOpen) {
            overviewOpen = true;
            selectedWindow = visibleWindows.findIndex(window => window.id === (Macqueen.activeWindow?.id || ""));
        }
        if (reason === "alt-tab")
            selectRelative(1);
        else if (reason === "alt-shift-tab")
            selectRelative(-1);
    }

    function close(activateSelection) {
        if (activateSelection && selectedWindow >= 0 && selectedWindow < visibleWindows.length)
            Macqueen.activateWindow(visibleWindows[selectedWindow].id);
        overviewOpen = false;
        draggingWindowId = "";
    }

    Connections {
        target: Macqueen

        function onOverviewRequested(reason) {
            if (reason === "screen-edge" && root.overviewOpen)
                root.close(false);
            else
                root.open(reason);
        }
    }

    Loader {
        active: root.overviewOpen
        asynchronous: false

        sourceComponent: PanelWindow {
            id: panel

            screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
            visible: root.overviewOpen
            color: "transparent"

            WlrLayershell.namespace: "macqueen:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: root.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.withAlpha("#000000", 0.62)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close(false)
                }
            }

            FocusScope {
                id: focusScope

                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: event => {
                    root.close(false);
                    event.accepted = true;
                }
                Keys.onReturnPressed: event => {
                    root.close(true);
                    event.accepted = true;
                }
                Keys.onEnterPressed: event => {
                    root.close(true);
                    event.accepted = true;
                }
                Keys.onTabPressed: event => {
                    root.selectRelative((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                    event.accepted = true;
                }
                Keys.onLeftPressed: event => {
                    root.selectRelative(-1);
                    event.accepted = true;
                }
                Keys.onRightPressed: event => {
                    root.selectRelative(1);
                    event.accepted = true;
                }
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Alt) {
                        root.close(true);
                        event.accepted = true;
                    }
                }

                Component.onCompleted: forceActiveFocus()

                Column {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Theme.spacingXL * 2, 1400)
                    spacing: Theme.spacingL

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "overview"
                            size: 28
                            color: Theme.primary
                        }

                        StyledText {
                            text: I18n.tr("Macqueen Overview")
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeXLarge
                            font.weight: Font.DemiBold
                        }
                    }

                    Grid {
                        id: workspaceGrid

                        width: parent.width
                        columns: Math.max(1, Math.min(SettingsData.overviewColumns, Macqueen.workspaces.length))
                        spacing: Theme.spacingM

                        Repeater {
                            model: Macqueen.workspaces

                            delegate: Rectangle {
                                id: workspaceCard

                                required property var modelData
                                readonly property var workspaceWindows: root.windowsForWorkspace(modelData.id)
                                readonly property real cardWidth: (workspaceGrid.width - workspaceGrid.spacing * (workspaceGrid.columns - 1)) / workspaceGrid.columns

                                width: cardWidth
                                height: Math.max(180, width * 0.56)
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainer
                                border.width: modelData.current ? 3 : 1
                                border.color: modelData.current ? Theme.primary : Theme.outline

                                DropArea {
                                    anchors.fill: parent
                                    onDropped: {
                                        if (root.draggingWindowId)
                                            Macqueen.moveWindowToWorkspace(root.draggingWindowId, workspaceCard.modelData.id);
                                        root.draggingWindowId = "";
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        Macqueen.activateWorkspace(workspaceCard.modelData.id);
                                        root.close(false);
                                    }
                                }

                                StyledText {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: Theme.spacingM
                                    text: workspaceCard.modelData.name || workspaceCard.modelData.position
                                    color: workspaceCard.modelData.current ? Theme.primary : Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.DemiBold
                                }

                                Grid {
                                    id: windowGrid

                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        bottom: parent.bottom
                                        margins: Theme.spacingM
                                        topMargin: Theme.spacingXL * 2
                                    }
                                    columns: workspaceCard.workspaceWindows.length > 4 ? 3 : 2
                                    spacing: Theme.spacingS

                                    Repeater {
                                        model: workspaceCard.workspaceWindows

                                        delegate: Rectangle {
                                            id: windowCard

                                            required property var modelData
                                            readonly property int globalIndex: root.visibleWindows.findIndex(window => window.id === modelData.id)
                                            readonly property var entry: DesktopEntries.heuristicLookup(Paths.moddedAppId(modelData.appId || ""))
                                            readonly property string iconPath: Paths.getAppIcon(modelData.appId || "", entry) || Quickshell.iconPath("application-x-executable", "image-missing")

                                            width: (windowGrid.width - windowGrid.spacing * (windowGrid.columns - 1)) / windowGrid.columns
                                            height: Math.max(52, (windowGrid.height - windowGrid.spacing) / 2)
                                            radius: Theme.cornerRadius
                                            color: globalIndex === root.selectedWindow ? Theme.primaryContainer : Theme.surfaceContainerHigh
                                            border.width: globalIndex === root.selectedWindow ? 2 : 1
                                            border.color: globalIndex === root.selectedWindow ? Theme.primary : Theme.outline

                                            Drag.active: dragArea.drag.active
                                            Drag.source: windowCard
                                            Drag.hotSpot.x: width / 2
                                            Drag.hotSpot.y: height / 2

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacingS
                                                spacing: Theme.spacingS

                                                Image {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 32
                                                    height: 32
                                                    source: windowCard.iconPath
                                                    sourceSize: Qt.size(32, 32)
                                                }

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 40

                                                    StyledText {
                                                        width: parent.width
                                                        text: windowCard.modelData.title || windowCard.modelData.appId
                                                        color: Theme.surfaceText
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        font.weight: Font.Medium
                                                        elide: Text.ElideRight
                                                    }

                                                    StyledText {
                                                        width: parent.width
                                                        text: windowCard.modelData.appId
                                                        color: Theme.surfaceVariantText
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: dragArea

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                drag.target: windowCard
                                                onPressed: root.draggingWindowId = windowCard.modelData.id
                                                onReleased: {
                                                    windowCard.Drag.drop();
                                                    windowCard.x = 0;
                                                    windowCard.y = 0;
                                                }
                                                onClicked: {
                                                    root.selectedWindow = windowCard.globalIndex;
                                                    root.close(true);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.tr("Alt+Tab or arrows to select • Enter to open • drag windows between workspaces • Esc to close")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }
        }
    }
}

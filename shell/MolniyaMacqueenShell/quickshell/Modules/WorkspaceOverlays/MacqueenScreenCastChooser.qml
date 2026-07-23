/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2026 The MacqueenDE contributors
*/

import Macqueen.Ipc
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

Scope {
    id: root

    property bool chooserOpen: false
    property string requestId: ""
    property string title: ""
    property var choices: []
    property bool allowRestore: true
    property int selectedIndex: -1

    function closeChooser() {
        chooserOpen = false;
        requestId = "";
        choices = [];
        selectedIndex = -1;
    }

    function cancel() {
        if (requestId.length > 0)
            Macqueen.cancelScreenCastSelection(requestId);
        closeChooser();
    }

    function accept() {
        if (selectedIndex < 0 || selectedIndex >= choices.length)
            return;
        const choice = choices[selectedIndex];
        if (Macqueen.submitScreenCastSelection(requestId, choice.kind, choice.id, allowRestore))
            closeChooser();
    }

    Connections {
        target: Macqueen

        function onScreenCastSelectionRequested(newRequestId, newTitle, optionsJson) {
            let options = {};
            try {
                options = JSON.parse(optionsJson);
            } catch (error) {
                console.warn("Invalid Macqueen screencast request:", error);
                Macqueen.cancelScreenCastSelection(newRequestId);
                return;
            }
            root.requestId = newRequestId;
            root.title = newTitle;
            root.choices = (options.outputs || []).concat(options.windows || []);
            root.allowRestore = true;
            root.selectedIndex = root.choices.length === 1 ? 0 : -1;
            root.chooserOpen = true;
        }
    }

    Loader {
        active: root.chooserOpen
        asynchronous: false

        sourceComponent: PanelWindow {
            id: panel

            screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
            visible: root.chooserOpen
            color: "transparent"

            WlrLayershell.namespace: "macqueen:screencast-chooser"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.withAlpha("#000000", 0.68)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.cancel()
                }
            }

            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: event => {
                    root.cancel();
                    event.accepted = true;
                }
                Keys.onReturnPressed: event => {
                    root.accept();
                    event.accepted = true;
                }
                Keys.onEnterPressed: event => {
                    root.accept();
                    event.accepted = true;
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 920)
                    height: Math.min(parent.height - 48, 680)
                    radius: 24
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: Theme.outline

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 28
                        spacing: 18

                        Label {
                            Layout.fillWidth: true
                            text: root.title
                            color: Theme.surfaceText
                            font.pixelSize: 24
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "Выберите экран или окно для демонстрации"
                            color: Theme.withAlpha(Theme.surfaceText, 0.72)
                            font.pixelSize: 15
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            GridLayout {
                                width: parent.width
                                columns: width >= 700 ? 3 : 2
                                columnSpacing: 12
                                rowSpacing: 12

                                Repeater {
                                    model: root.choices

                                    delegate: Rectangle {
                                        id: card

                                        required property int index
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 132
                                        radius: 16
                                        color: root.selectedIndex === index ? Theme.primaryContainer : Theme.surfaceContainerHigh
                                        border.width: root.selectedIndex === index ? 2 : 1
                                        border.color: root.selectedIndex === index ? Theme.primary : Theme.outline

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 8

                                            Label {
                                                text: card.modelData.kind === "window" ? "▣  Окно" : "▰  Экран"
                                                color: root.selectedIndex === card.index ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.7)
                                                font.pixelSize: 13
                                                font.bold: true
                                            }

                                            Label {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                text: card.modelData.label || card.modelData.name || card.modelData.id
                                                color: Theme.surfaceText
                                                font.pixelSize: 16
                                                font.bold: true
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.selectedIndex = card.index
                                            onDoubleClicked: {
                                                root.selectedIndex = card.index;
                                                root.accept();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            CheckBox {
                                checked: root.allowRestore
                                text: "Запомнить выбор"
                                onToggled: root.allowRestore = checked
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Отмена"
                                onClicked: root.cancel()
                            }

                            Button {
                                text: "Поделиться"
                                enabled: root.selectedIndex >= 0
                                highlighted: true
                                onClicked: root.accept()
                            }
                        }
                    }
                }
            }
        }
    }
}

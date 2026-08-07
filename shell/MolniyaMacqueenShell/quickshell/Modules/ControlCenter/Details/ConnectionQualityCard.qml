import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool expanded: false
    readonly property var latest: {
        if (RegaliaService.networkTestJob?.result)
            return RegaliaService.networkTestJob.result;
        return RegaliaService.networkTestHistory.length > 0 ? RegaliaService.networkTestHistory[0] : null;
    }
    readonly property var measurements: latest?.results || []
    readonly property var primaryMeasurement: {
        if (measurements.length < 1)
            return null;
        for (let index = 0; index < measurements.length; index++) {
            if (measurements[index].route === "proxy")
                return measurements[index];
        }
        return measurements[0];
    }
    readonly property bool running: RegaliaService.networkTestRunning
    readonly property int compactHeight: 72
    readonly property int detailHeight: measurements.length > 1 ? 270 : 220

    implicitHeight: expanded ? detailHeight : compactHeight
    height: implicitHeight
    radius: Theme.cornerRadius
    color: Theme.surfaceLight
    border.width: 1
    border.color: running ? Theme.primary : Theme.outlineLight
    clip: true

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: {
        if (RegaliaService.networkTestSupported)
            RegaliaService.refreshNetworkTestHistory();
    }

    Connections {
        target: RegaliaService
        function onStatusChanged() {
            if (RegaliaService.networkTestSupported && RegaliaService.networkTestHistory.length === 0)
                RegaliaService.refreshNetworkTestHistory();
        }
    }

    function networkContext() {
        if (NetworkService.networkStatus === "wifi") {
            return {
                "kind": "wifi",
                "interface": NetworkService.wifiInterface || "",
                "name": NetworkService.currentWifiSSID || ""
            };
        }
        return {
            "kind": "ethernet",
            "interface": NetworkService.ethernetInterface || "",
            "name": I18n.tr("Ethernet")
        };
    }

    function startTest() {
        if (!RegaliaService.networkTestSupported || running)
            return;
        const mode = RegaliaService.connected && RegaliaService.networkCompareSupported ? "compare" : "direct";
        expanded = true;
        RegaliaService.startNetworkTest(mode, networkContext());
    }

    function ratingText(rating) {
        switch (rating) {
        case "excellent": return I18n.tr("Excellent connection");
        case "good": return I18n.tr("Good connection");
        case "fair": return I18n.tr("Average connection");
        case "poor": return I18n.tr("Poor connection");
        default: return I18n.tr("Not tested yet");
        }
    }

    function phaseText(phase) {
        if (!phase)
            return I18n.tr("Preparing test…");
        if (phase.indexOf("latency") >= 0)
            return I18n.tr("Measuring latency…");
        if (phase.indexOf("download") >= 0)
            return I18n.tr("Measuring download speed…");
        if (phase.indexOf("upload") >= 0)
            return I18n.tr("Measuring upload speed…");
        return I18n.tr("Preparing test…");
    }

    function timestampText(value) {
        if (!value)
            return "";
        const date = new Date(value);
        if (isNaN(date.getTime()))
            return "";
        return Qt.formatDateTime(date, "dd.MM.yyyy · HH:mm");
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        Row {
            width: parent.width
            height: 44
            spacing: Theme.spacingM

            Rectangle {
                width: 40
                height: 40
                radius: 20
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.primaryHoverLight

                DankIcon {
                    anchors.centerIn: parent
                    name: "speed"
                    size: 22
                    color: Theme.primary
                }
            }

            Column {
                width: parent.width - 40 - actionButton.width - expandButton.width - Theme.spacingM * 3
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    width: parent.width
                    text: I18n.tr("Connection quality")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: {
                        if (!RegaliaService.networkTestSupported)
                            return I18n.tr("Update Regalia to run a connection test");
                        if (running)
                            return root.phaseText(RegaliaService.networkTestJob?.phase || "");
                        if (RegaliaService.networkTestError.length > 0)
                            return I18n.tr("The last test failed");
                        if (primaryMeasurement)
                            return root.ratingText(primaryMeasurement.rating) + " · " + root.timestampText(latest.finishedAt);
                        return I18n.tr("Run an on-demand test — no background load");
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: RegaliaService.networkTestError.length > 0 ? Theme.error : Theme.surfaceVariantText
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: actionButton
                width: actionLabel.implicitWidth + Theme.spacingM * 2
                height: 32
                radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: actionMouse.containsMouse ? Theme.primaryHover : Theme.primary
                opacity: RegaliaService.networkTestSupported ? 1 : 0.45

                StyledText {
                    id: actionLabel
                    anchors.centerIn: parent
                    text: running ? I18n.tr("Cancel") : (RegaliaService.connected ? I18n.tr("Compare") : I18n.tr("Test"))
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.primaryText
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: RegaliaService.networkTestSupported
                    cursorShape: Qt.PointingHandCursor
                    onClicked: running ? RegaliaService.cancelNetworkTest() : root.startTest()
                }
            }

            DankActionButton {
                id: expandButton
                anchors.verticalCenter: parent.verticalCenter
                buttonSize: 32
                iconSize: 18
                iconName: root.expanded ? "expand_less" : "expand_more"
                enabled: root.latest !== null || RegaliaService.networkTestHistory.length > 0
                onClicked: root.expanded = !root.expanded
            }
        }

        Rectangle {
            width: parent.width
            height: running ? 3 : 0
            radius: 2
            color: Theme.outlineLight
            visible: running

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, RegaliaService.networkTestJob?.percent || 0)) / 100
                height: parent.height
                radius: parent.radius
                color: Theme.primary

                Behavior on width { NumberAnimation { duration: 180 } }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: root.expanded
            opacity: visible ? 1 : 0

            Repeater {
                model: root.measurements

                delegate: Row {
                    required property var modelData
                    width: parent.width
                    height: 34
                    spacing: Theme.spacingS

                    Rectangle {
                        width: 72
                        height: 26
                        radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.route === "proxy" ? Theme.primaryHoverLight : Theme.surfaceVariant

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.route === "proxy" ? I18n.tr("Via VPN")
                                : (RegaliaService.connected ? I18n.tr("Direct") : I18n.tr("Current route"))
                            font.pixelSize: Theme.fontSizeSmall
                            color: modelData.route === "proxy" ? Theme.primary : Theme.surfaceText
                            font.weight: Font.Medium
                        }
                    }

                    StyledText {
                        width: (parent.width - 72 - Theme.spacingS * 4) / 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↓ " + Number(modelData.downloadMbps || 0).toFixed(1) + " Mbps"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }

                    StyledText {
                        width: (parent.width - 72 - Theme.spacingS * 4) / 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↑ " + Number(modelData.uploadMbps || 0).toFixed(1) + " Mbps"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }

                    StyledText {
                        width: (parent.width - 72 - Theme.spacingS * 4) / 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: Number(modelData.latencyMs || 0).toFixed(0) + " ms · ±" + Number(modelData.jitterMs || 0).toFixed(0)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        width: (parent.width - 72 - Theme.spacingS * 4) / 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Errors %1%").arg(Number(modelData.httpErrorRate || 0).toFixed(0))
                        font.pixelSize: Theme.fontSizeSmall
                        color: Number(modelData.httpErrorRate || 0) > 0 ? Theme.warning : Theme.surfaceVariantText
                    }
                }
            }

            StyledText {
                width: parent.width
                visible: root.latest?.compare !== null && root.latest?.compare !== undefined
                text: {
                    const comparison = root.latest?.compare;
                    if (!comparison)
                        return "";
                    const speed = Number(comparison.downloadDeltaPct || 0);
                    const latency = Number(comparison.latencyDeltaMs || 0);
                    return I18n.tr("VPN difference: download %1% · latency %2 ms")
                        .arg((speed > 0 ? "+" : "") + speed.toFixed(1))
                        .arg((latency > 0 ? "+" : "") + latency.toFixed(1));
                }
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                elide: Text.ElideRight
            }

            Row {
                width: parent.width
                height: 28

                StyledText {
                    width: parent.width - clearButton.width
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Last test: %1 · history %2/20 · 30 days").arg(root.timestampText(root.latest?.finishedAt || "")).arg(RegaliaService.networkTestHistory.length)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: clearButton
                    width: clearLabel.implicitWidth + Theme.spacingM * 2
                    height: 28
                    radius: 14
                    color: clearMouse.containsMouse ? Theme.errorHover : "transparent"
                    visible: RegaliaService.networkTestHistory.length > 0

                    StyledText {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: I18n.tr("Clear history")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: RegaliaService.clearNetworkTestHistory()
                    }
                }
            }

            StyledText {
                width: parent.width
                text: root.measurements.length > 1
                    ? I18n.tr("Direct and VPN tests run sequentially (~14 MB via Cloudflare). Other applications keep their routes.")
                    : I18n.tr("The test uses about 7 MB via Cloudflare and only runs when you press the button.")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}

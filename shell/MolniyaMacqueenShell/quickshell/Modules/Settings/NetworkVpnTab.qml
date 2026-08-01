pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Services
import qs.Widgets

Item {
    id: networkVpnTab

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    Component.onCompleted: RegaliaService.detect()

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn

            topPadding: 4
            width: Math.min(600, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingL

            SettingsCard {
                title: I18n.tr("VPN")
                iconName: "vpn_key"
                settingKey: "networkVpn"
                tags: ["vpn", "regalia", "proxy", "tun", "routing"]
                width: parent.width

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    Rectangle {
                        width: parent.width
                        height: unavailableContent.height + Theme.spacingL * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainer
                        border.width: 1
                        border.color: Theme.outline
                        visible: RegaliaService.availabilityState !== "ready"

                        Column {
                            id: unavailableContent
                            width: parent.width - Theme.spacingL * 2
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            Rectangle {
                                width: 56
                                height: 56
                                radius: 28
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Theme.withAlpha(Theme.primary, 0.14)

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: RegaliaService.checkingInstallation ? "sync" : "vpn_key_off"
                                    size: 28
                                    color: Theme.primary
                                }
                            }

                            StyledText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                                text: {
                                    switch (RegaliaService.availabilityState) {
                                    case "checking":
                                        return I18n.tr("Checking Regalia");
                                    case "not-installed":
                                        return I18n.tr("Regalia is not installed");
                                    case "service-offline":
                                        return I18n.tr("Regalia service is not running");
                                    case "incompatible":
                                        return I18n.tr("Regalia needs to be updated");
                                    default:
                                        return I18n.tr("Regalia is unavailable");
                                    }
                                }
                            }

                            StyledText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                text: {
                                    switch (RegaliaService.availabilityState) {
                                    case "checking":
                                        return I18n.tr("Looking for the optional VPN component");
                                    case "not-installed":
                                        return I18n.tr("VPN support is optional. Install Regalia separately to unlock connection, server and routing settings.");
                                    case "service-offline":
                                        return I18n.tr("The component is installed, but its user service is offline. Your desktop works normally without it.");
                                    case "incompatible":
                                        return I18n.tr("This shell requires Regalia API version %1 or newer.").arg(RegaliaService.minimumApiVersion);
                                    default:
                                        return RegaliaService.lastError || I18n.tr("The VPN component could not be reached");
                                    }
                                }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: optionalText.implicitWidth + Theme.spacingM * 2
                                height: 26
                                radius: 13
                                color: Theme.surfaceContainerHigh
                                visible: RegaliaService.availabilityState === "not-installed"

                                StyledText {
                                    id: optionalText
                                    anchors.centerIn: parent
                                    text: I18n.tr("Optional component")
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceVariantText
                                }
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Theme.spacingS
                                visible: !RegaliaService.checkingInstallation

                                DankButton {
                                    text: RegaliaService.availabilityState === "service-offline" ? I18n.tr("Start service") : I18n.tr("Open project")
                                    iconName: RegaliaService.availabilityState === "service-offline" ? "play_arrow" : "open_in_new"
                                    buttonHeight: 36
                                    enabled: !RegaliaService.busy
                                    onClicked: {
                                        if (RegaliaService.availabilityState === "service-offline")
                                            RegaliaService.startDaemon();
                                        else
                                            RegaliaService.openProject();
                                    }
                                }

                                DankButton {
                                    text: I18n.tr("Check again")
                                    iconName: "refresh"
                                    buttonHeight: 36
                                    backgroundColor: Theme.surfaceContainerHigh
                                    textColor: Theme.surfaceText
                                    enabled: !RegaliaService.busy
                                    onClicked: RegaliaService.detect()
                                }
                            }

                            StyledText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.error
                                text: RegaliaService.lastError
                                visible: text.length > 0
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: RegaliaService.availabilityState === "ready"

                        SettingsToggleRow {
                            settingKey: "regaliaVpnEnabled"
                            text: I18n.tr("Enable VPN")
                            description: {
                                if (RegaliaService.busy)
                                    return I18n.tr("Applying VPN state");
                                if (RegaliaService.connected)
                                    return I18n.tr("Connected through Regalia TUN");
                                if (RegaliaService.enabled)
                                    return I18n.tr("Enabled, waiting for the engine");
                                return I18n.tr("Keep this setting after logout and reboot");
                            }
                            checked: RegaliaService.enabled
                            enabled: !RegaliaService.busy && RegaliaService.engineAvailable && (RegaliaService.configurationReady || RegaliaService.enabled)
                            onToggled: checked => RegaliaService.setEnabled(checked)
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outline
                            opacity: 0.2
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                anchors.verticalCenter: parent.verticalCenter
                                color: RegaliaService.connected ? Theme.success : (RegaliaService.enabled ? Theme.warning : Theme.surfaceVariantText)
                            }

                            Column {
                                width: parent.width - statusBadge.width - Theme.spacingM * 2 - 10
                                spacing: Theme.spacingXXS

                                StyledText {
                                    width: parent.width
                                    text: {
                                        if (RegaliaService.connected)
                                            return I18n.tr("Connected");
                                        if (RegaliaService.engineState === "starting")
                                            return I18n.tr("Connecting");
                                        if (RegaliaService.engineState === "failed")
                                            return I18n.tr("Connection failed");
                                        return I18n.tr("Disconnected");
                                    }
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    width: parent.width
                                    text: RegaliaService.activeServer ? (RegaliaService.activeServer.name || I18n.tr("Selected server")) : I18n.tr("No server selected")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                id: statusBadge
                                anchors.verticalCenter: parent.verticalCenter
                                width: engineText.implicitWidth + Theme.spacingM * 2
                                height: 28
                                radius: 14
                                color: Theme.surfaceContainer

                                StyledText {
                                    id: engineText
                                    anchors.centerIn: parent
                                    text: RegaliaService.engineState
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }
                    }
                }
            }

            SettingsCard {
                title: I18n.tr("Current configuration")
                iconName: "tune"
                settingKey: "regaliaConfiguration"
                tags: ["regalia", "server", "route", "profile"]
                width: parent.width
                visible: RegaliaService.availabilityState === "ready"

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    ConfigRow {
                        label: I18n.tr("Server")
                        value: RegaliaService.activeServer ? (RegaliaService.activeServer.name || "-") : I18n.tr("Not selected")
                    }

                    ConfigRow {
                        label: I18n.tr("Protocol")
                        value: RegaliaService.activeServer ? (RegaliaService.activeServer.protocol || "-") : "-"
                    }

                    ConfigRow {
                        label: I18n.tr("Routing profile")
                        value: RegaliaService.activeRoute ? (RegaliaService.activeRoute.name || "-") : I18n.tr("Default")
                    }

                    ConfigRow {
                        label: I18n.tr("Default route")
                        value: RegaliaService.activeRoute ? (RegaliaService.activeRoute.defaultOutbound || "proxy") : "proxy"
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                    }

                    StyledText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: RegaliaService.configurationReady ? I18n.tr("Regalia is ready. Subscription, server and per-application routing controls will appear in this section.") : (RegaliaService.configurationError || I18n.tr("Complete the Regalia configuration before enabling VPN."))
                        font.pixelSize: Theme.fontSizeSmall
                        color: RegaliaService.configurationReady ? Theme.surfaceVariantText : Theme.warning
                    }
                }
            }

            SettingsCard {
                title: I18n.tr("Diagnostics")
                iconName: "monitor_heart"
                width: parent.width
                visible: RegaliaService.availabilityState === "ready" && (RegaliaService.engineError.length > 0 || RegaliaService.restoreError.length > 0 || RegaliaService.lastError.length > 0)

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: RegaliaService.lastError || RegaliaService.restoreError || RegaliaService.engineError
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                    }

                    DankButton {
                        text: I18n.tr("Refresh status")
                        iconName: "refresh"
                        buttonHeight: 34
                        enabled: !RegaliaService.statusRequestPending
                        onClicked: RegaliaService.refreshStatus()
                    }
                }
            }
        }
    }

    component ConfigRow: Row {
        required property string label
        required property string value

        width: parent.width
        spacing: Theme.spacingM

        StyledText {
            width: parent.width * 0.42
            text: parent.label
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceVariantText
            horizontalAlignment: Text.AlignLeft
        }

        StyledText {
            width: parent.width * 0.58 - Theme.spacingM
            text: parent.value
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}

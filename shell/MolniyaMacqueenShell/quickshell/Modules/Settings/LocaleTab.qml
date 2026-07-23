import QtQuick
import Macqueen.Ipc
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: localeTab

    readonly property string _systemDefaultLabel: I18n.tr("System Default")
    property string pendingLayoutCode: ""

    function availableLayoutOptions() {
        return Macqueen.availableKeyboardLayouts.map(layout => `${layout.name} (${layout.code})`);
    }

    function codeForLayoutOption(option) {
        const match = option.match(/\(([^()]+)\)$/);
        return match ? match[1] : "";
    }

    function addPendingLayout() {
        if (!pendingLayoutCode)
            return;
        const current = Macqueen.keyboardLayouts.map(layout => layout.code);
        if (!current.includes(pendingLayoutCode))
            Macqueen.setKeyboardLayouts(current.concat([pendingLayoutCode]));
    }

    function removeLayout(code) {
        const current = Macqueen.keyboardLayouts.map(layout => layout.code);
        if (current.length <= 1)
            return;
        Macqueen.setKeyboardLayouts(current.filter(layout => layout !== code));
    }

    function _localeDisplayName(localeCode) {
        if (!I18n.presentLocales[localeCode])
            return;
        const nativeName = I18n.presentLocales[localeCode].nativeLanguageName;
        return nativeName[0].toUpperCase() + nativeName.slice(1);
    }

    function _allLocaleOptions() {
        return [_systemDefaultLabel].concat(Object.keys(I18n.presentLocales).map(_localeDisplayName));
    }

    function _codeForDisplayName(displayName) {
        if (displayName === _systemDefaultLabel)
            return "";
        for (const code of Object.keys(I18n.presentLocales)) {
            if (_localeDisplayName(code) === displayName)
                return code;
        }
        return "";
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                tab: "locale"
                tags: ["locale", "language", "country"]
                title: I18n.tr("General")
                iconName: "language"

                SettingsDropdownRow {
                    id: localeDropdown
                    tab: "locale"
                    tags: ["locale", "language", "country"]
                    settingKey: "locale"
                    text: I18n.tr("Current Locale")
                    description: I18n.tr("Change the locale used by the DMS interface.")
                    options: localeTab._allLocaleOptions()
                    enableFuzzySearch: true

                    Component.onCompleted: {
                        currentValue = SessionData.locale ? localeTab._localeDisplayName(SessionData.locale) : localeTab._systemDefaultLabel;
                    }

                    onValueChanged: value => {
                        SessionData.set("locale", localeTab._codeForDisplayName(value));
                    }
                }

                SettingsDropdownRow {
                    id: timeLocaleDropdown
                    tab: "locale"
                    tags: ["locale", "time", "date", "format", "region"]
                    settingKey: "timeLocale"
                    text: I18n.tr("Time & Date Locale")
                    description: I18n.tr("Change the locale used for date and time formatting, independent of the interface language.")
                    options: localeTab._allLocaleOptions()
                    enableFuzzySearch: true

                    Component.onCompleted: {
                        currentValue = SessionData.timeLocale ? localeTab._localeDisplayName(SessionData.timeLocale) : localeTab._systemDefaultLabel;
                    }

                    onValueChanged: value => {
                        SessionData.set("timeLocale", localeTab._codeForDisplayName(value));
                    }
                }
            }

            SettingsCard {
                visible: Macqueen.available
                tab: "locale"
                tags: ["keyboard", "layout", "language", "input", "раскладка", "клавиатура"]
                title: I18n.tr("Keyboard Layouts")
                iconName: "keyboard"

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Choose the languages used for typing. Click a layout to make it active.")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: Macqueen.keyboardLayouts

                        delegate: Rectangle {
                            required property var modelData
                            width: parent?.width ?? 0
                            height: 48
                            radius: Theme.cornerRadius
                            color: modelData.active ? Theme.primaryContainer : Theme.surfaceContainerHigh

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Macqueen.setCurrentKeyboardLayout(modelData.index)
                            }

                            StyledText {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name || modelData.code.toUpperCase()
                                color: modelData.active ? Theme.primary : Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: modelData.active ? Font.DemiBold : Font.Normal
                            }

                            StyledText {
                                anchors.right: removeButton.left
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.code.toUpperCase()
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            DankButton {
                                id: removeButton
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: "delete"
                                buttonHeight: 32
                                horizontalPadding: 6
                                backgroundColor: "transparent"
                                textColor: enabled ? Theme.error : Theme.surfaceVariantText
                                enabled: Macqueen.keyboardLayouts.length > 1
                                onClicked: localeTab.removeLayout(modelData.code)
                            }
                        }
                    }

                    SettingsDropdownRow {
                        id: addLayoutDropdown
                        width: parent.width
                        tab: "locale"
                        tags: ["keyboard", "layout", "add", "language"]
                        settingKey: "keyboardLayoutToAdd"
                        text: I18n.tr("Add keyboard layout")
                        description: I18n.tr("Select any layout installed by the system.")
                        options: localeTab.availableLayoutOptions()
                        enableFuzzySearch: true
                        onValueChanged: value => localeTab.pendingLayoutCode = localeTab.codeForLayoutOption(value)
                    }

                    DankButton {
                        anchors.right: parent.right
                        text: I18n.tr("Add")
                        iconName: "add"
                        enabled: localeTab.pendingLayoutCode.length > 0
                            && !Macqueen.keyboardLayouts.some(layout => layout.code === localeTab.pendingLayoutCode)
                        onClicked: localeTab.addPendingLayout()
                    }

                    StyledText {
                        visible: Macqueen.keyboardLayouts.length === 1
                        width: parent.width
                        text: I18n.tr("The last keyboard layout cannot be removed.")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}

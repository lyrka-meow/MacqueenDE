import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property var activePlayer
    property int currentIndex: -1
    property color accent: MediaAccentService.accent
    readonly property string trackTitle: activePlayer?.trackTitle || MprisController.stableTitle || ""
    readonly property string trackArtist: activePlayer?.trackArtist || MprisController.stableArtist || ""

    onCurrentIndexChanged: {
        if (currentIndex >= 0)
            lyrics.positionViewAtIndex(currentIndex, ListView.Center);
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.withAlpha(root.accent, 0.1)
            }
            GradientStop {
                position: 0.42
                color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.08)
            }
            GradientStop {
                position: 1
                color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.34)
            }
        }
    }

    Item {
        id: lyricsHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        anchors.rightMargin: 52
        height: 48

        Rectangle {
            id: headerIcon
            width: 38
            height: 38
            radius: 13
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.withAlpha(root.accent, 0.16)
            border.width: 1
            border.color: Theme.withAlpha(root.accent, 0.34)

            DankIcon {
                anchors.centerIn: parent
                name: "lyrics"
                size: 19
                color: root.accent
            }
        }

        Column {
            anchors.left: headerIcon.right
            anchors.leftMargin: Theme.spacingS
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Row {
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Lyrics")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: syncedLabel.implicitWidth + 10
                    height: 18
                    radius: 9
                    color: Theme.withAlpha(root.accent, 0.12)
                    visible: LyricsService.hasLyrics

                    StyledText {
                        id: syncedLabel
                        anchors.centerIn: parent
                        text: "SYNC"
                        font.pixelSize: Math.max(8, Theme.fontSizeSmall - 2)
                        font.weight: Font.DemiBold
                        color: root.accent
                    }
                }
            }

            StyledText {
                width: parent.width
                text: root.trackTitle
                    ? (root.trackArtist ? root.trackTitle + " · " + root.trackArtist : root.trackTitle)
                    : I18n.tr("Current track")
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextSecondary
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingS
        visible: LyricsService.loading || !LyricsService.hasLyrics
        width: parent.width - Theme.spacingL * 2

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 54
            height: 54
            radius: 18
            color: Theme.withAlpha(root.accent, LyricsService.loading ? 0.16 : 0.09)

            DankIcon {
                id: emptyStateIcon
                anchors.centerIn: parent
                name: LyricsService.loading ? "progress_activity" : "lyrics"
                size: Theme.iconSize * 1.45
                color: LyricsService.loading ? root.accent : Theme.surfaceTextSecondary

                RotationAnimation on rotation {
                    running: LyricsService.loading
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            text: LyricsService.loading ? I18n.tr("Loading lyrics…")
                                        : (LyricsService.error || I18n.tr("Lyrics not found"))
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.surfaceTextSecondary
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    ListView {
        id: lyrics
        anchors.fill: parent
        anchors.topMargin: 74
        anchors.bottomMargin: Theme.spacingM
        anchors.leftMargin: Theme.spacingS
        anchors.rightMargin: Theme.spacingS
        visible: LyricsService.hasLyrics
        clip: true
        model: LyricsService.lines
        spacing: 3
        currentIndex: root.currentIndex
        highlightMoveDuration: 420
        highlightMoveVelocity: -1
        preferredHighlightBegin: height * 0.4
        preferredHighlightEnd: height * 0.6
        highlightRangeMode: ListView.ApplyRange
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            required property var modelData
            required property int index
            width: ListView.view.width
            readonly property bool currentLine: index === root.currentIndex
            readonly property int lineDistance: root.currentIndex < 0 ? 1 : Math.abs(index - root.currentIndex)
            height: lyricText.implicitHeight + (currentLine ? 20 : 12)

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                radius: Theme.cornerRadius
                color: currentLine ? Theme.withAlpha(root.accent, 0.14) : "transparent"
                border.width: currentLine ? 1 : 0
                border.color: Theme.withAlpha(root.accent, 0.28)
            }

            Rectangle {
                width: 3
                height: Math.min(24, parent.height - 12)
                radius: 2
                anchors.left: parent.left
                anchors.leftMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                color: root.accent
                opacity: currentLine ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 180 }
                }
            }

            StyledText {
                id: lyricText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: currentLine ? 16 : 12
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.text || "♪"
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                horizontalAlignment: Text.AlignHCenter
                color: currentLine ? root.accent : Theme.surfaceText
                font.pixelSize: currentLine ? Theme.fontSizeMedium : Theme.fontSizeSmall
                font.weight: currentLine ? Font.DemiBold : Font.Normal
                opacity: currentLine ? 1 : Math.max(0.28, 0.66 - lineDistance * 0.1)

                Behavior on color {
                    ColorAnimation { duration: 220 }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 220 }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    if (root.activePlayer?.canSeek)
                        root.activePlayer.position = modelData.time + 0.01;
                }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: lyricsHeader.bottom
        height: 24
        z: 2
        visible: LyricsService.hasLyrics
        enabled: false
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.withAlpha(Theme.floatingSurface, 0.82)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 24
        z: 2
        visible: LyricsService.hasLyrics
        enabled: false
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Theme.withAlpha(Theme.floatingSurface, 0.82)
            }
        }
    }
}

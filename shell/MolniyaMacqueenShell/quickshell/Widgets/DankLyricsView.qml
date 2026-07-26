import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property var activePlayer
    property int currentIndex: -1
    property color accent: MediaAccentService.accent

    onCurrentIndexChanged: {
        if (currentIndex >= 0)
            lyrics.positionViewAtIndex(currentIndex, ListView.Center);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.42)
        border.width: 0
    }

    Row {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        DankIcon {
            name: "lyrics"
            size: Theme.iconSize
            color: root.accent
        }
        StyledText {
            text: I18n.tr("Lyrics")
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
            color: Theme.surfaceText
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingS
        visible: LyricsService.loading || !LyricsService.hasLyrics

        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: LyricsService.loading ? "progress_activity" : "lyrics"
            size: Theme.iconSize * 1.6
            color: LyricsService.loading ? root.accent : Theme.surfaceTextSecondary

            RotationAnimation on rotation {
                running: LyricsService.loading
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: LyricsService.loading ? I18n.tr("Loading lyrics…")
                                        : (LyricsService.error || I18n.tr("Lyrics not found"))
            color: Theme.surfaceTextSecondary
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    ListView {
        id: lyrics
        anchors.fill: parent
        anchors.topMargin: 43
        anchors.bottomMargin: Theme.spacingM
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        visible: LyricsService.hasLyrics
        clip: true
        model: LyricsService.lines
        spacing: Theme.spacingS
        currentIndex: root.currentIndex
        highlightMoveDuration: 380
        preferredHighlightBegin: height * 0.38
        preferredHighlightEnd: height * 0.62
        highlightRangeMode: ListView.ApplyRange

        delegate: StyledText {
            required property var modelData
            required property int index
            width: ListView.view.width
            text: modelData.text || "♪"
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            horizontalAlignment: Text.AlignHCenter
            color: ListView.isCurrentItem ? root.accent : Theme.surfaceTextSecondary
            font.pixelSize: ListView.isCurrentItem ? Theme.fontSizeMedium : Theme.fontSizeSmall
            font.weight: ListView.isCurrentItem ? Font.Bold : Font.Normal
            opacity: ListView.isCurrentItem ? 1 : 0.34

            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on opacity { NumberAnimation { duration: 220 } }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.activePlayer?.canSeek)
                        root.activePlayer.position = modelData.time + 0.01;
                }
            }
        }
    }
}

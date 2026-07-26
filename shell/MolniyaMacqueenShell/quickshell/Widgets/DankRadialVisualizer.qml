import QtQuick
import Quickshell.Services.Mpris
import qs.Services

// Adapted from Caelestia's radial CoverVisualiser concept (GPL-3.0).
Item {
    id: root

    property var activePlayer
    property color color: MediaAccentService.accent
    property int barCount: 48
    property real innerRadius: Math.min(width, height) * 0.35
    property real maxLength: Math.min(width, height) * 0.105
    readonly property bool playing: activePlayer?.playbackState === MprisPlaybackState.Playing

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.translate(width / 2, height / 2);
            ctx.strokeStyle = root.color;
            ctx.lineCap = "round";
            ctx.lineWidth = Math.max(2, Math.min(width, height) * 0.014);

            const values = CavaService.values;
            for (let i = 0; i < root.barCount; i++) {
                const bandPos = i * 6 / root.barCount;
                const lo = Math.floor(bandPos) % 6;
                const hi = (lo + 1) % 6;
                const mix = bandPos - Math.floor(bandPos);
                const raw = (values[lo] || 0) * (1 - mix) + (values[hi] || 0) * mix;
                const level = root.playing ? Math.max(0.06, Math.min(1, raw / 45)) : 0.035;
                const angle = i * Math.PI * 2 / root.barCount - Math.PI / 2;
                const length = 2 + level * root.maxLength;
                const cos = Math.cos(angle);
                const sin = Math.sin(angle);
                ctx.beginPath();
                ctx.moveTo(cos * root.innerRadius, sin * root.innerRadius);
                ctx.lineTo(cos * (root.innerRadius + length), sin * (root.innerRadius + length));
                ctx.stroke();
            }
        }

        Connections {
            target: CavaService
            function onValuesChanged() { canvas.requestPaint(); }
        }

        Connections {
            target: MediaAccentService
            function onAccentChanged() { canvas.requestPaint(); }
        }
    }

    onPlayingChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
}

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Synced lyrics inspired by Caelestia's player integration (GPL-3.0).
// Kept independent from Caelestia: LRCLIB is queried directly.
Singleton {
    id: root

    property bool loading: false
    property bool hasLyrics: lines.length > 0
    property string error: ""
    property var lines: []
    property string plainLyrics: ""
    property string trackKey: ""
    property int requestId: 0

    function encoded(value) {
        return encodeURIComponent((value || "").trim());
    }

    function loadTrack(artist, title, album, duration) {
        const cleanTitle = (title || "").trim();
        const cleanArtist = (artist || "").trim();
        const key = cleanArtist + "\n" + cleanTitle + "\n" + (album || "") + "\n" + Math.round(duration || 0);
        if (key === trackKey)
            return;

        trackKey = key;
        requestId++;
        lines = [];
        plainLyrics = "";
        error = "";
        fetcher.running = false;

        if (!cleanTitle) {
            loading = false;
            return;
        }

        const query = "track_name=" + encoded(cleanTitle)
                    + "&artist_name=" + encoded(cleanArtist)
                    + ((album || "") ? "&album_name=" + encoded(album) : "")
                    + ((duration || 0) > 0 ? "&duration=" + Math.round(duration) : "");
        fetcher.reqId = requestId;
        fetcher.command = ["curl", "-fsSL", "--connect-timeout", "4", "--max-time", "10",
                           "-H", "User-Agent: MolniyaMacqueenShell/0.1",
                           "https://lrclib.net/api/get?" + query];
        loading = true;
        fetcher.running = true;
    }

    function parseLrc(text) {
        const parsed = [];
        const rows = (text || "").split(/\r?\n/);
        const stamp = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
        for (let i = 0; i < rows.length; i++) {
            const value = rows[i].replace(stamp, "").trim();
            stamp.lastIndex = 0;
            let match;
            while ((match = stamp.exec(rows[i])) !== null) {
                parsed.push({
                    time: Number(match[1]) * 60 + Number(match[2]),
                    text: value || "♪"
                });
            }
        }
        parsed.sort((a, b) => a.time - b.time);
        return parsed;
    }

    function indexForTime(position) {
        let low = 0;
        let high = lines.length - 1;
        let result = -1;
        while (low <= high) {
            const middle = (low + high) >> 1;
            if (lines[middle].time <= position + 0.08) {
                result = middle;
                low = middle + 1;
            } else {
                high = middle - 1;
            }
        }
        return result;
    }

    Process {
        id: fetcher
        property int reqId: 0
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (fetcher.reqId !== root.requestId)
                    return;
                try {
                    const result = JSON.parse(text);
                    root.plainLyrics = result.plainLyrics || "";
                    root.lines = root.parseLrc(result.syncedLyrics || "");
                    if (root.lines.length === 0 && root.plainLyrics)
                        root.error = qsTr("Lyrics are available, but not synchronized");
                    else if (root.lines.length === 0)
                        root.error = qsTr("Lyrics not found");
                } catch (e) {
                    root.error = qsTr("Lyrics not found");
                    root.lines = [];
                }
            }
        }

        onExited: exitCode => {
            if (reqId !== root.requestId)
                return;
            root.loading = false;
            if (exitCode !== 0 && root.lines.length === 0)
                root.error = qsTr("Lyrics not found");
        }
    }
}

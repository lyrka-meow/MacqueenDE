pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property var log: Log.scoped("RegaliaService")
    readonly property string projectUrl: "https://github.com/lyrka-meow/Regalia"
    readonly property string runtimeDirectory: Quickshell.env("XDG_RUNTIME_DIR")
    readonly property string socketPath: runtimeDirectory.length > 0 ? runtimeDirectory + "/regalia/regaliad.sock" : ""
    readonly property int minimumApiVersion: 3

    property bool installed: false
    property bool checkingInstallation: true
    property bool daemonOnline: false
    property bool compatible: false
    property bool statusReceived: false
    property bool busy: false
    property bool statusRequestPending: false
    property int apiVersion: 0
    property var capabilities: []
    property bool enabled: false
    property bool connected: false
    property bool engineAvailable: false
    property string engineState: "unavailable"
    property string engineError: ""
    property string restoreError: ""
    property string configurationState: "incomplete"
    property string configurationError: ""
    property var activeServer: null
    property var activeRoute: null
    property string lastError: ""

    readonly property bool available: installed && daemonOnline && compatible
    readonly property bool configurationReady: configurationState === "ready"
    readonly property string availabilityState: {
        if (checkingInstallation || (daemonOnline && !statusReceived))
            return "checking";
        if (!installed)
            return "not-installed";
        if (!daemonOnline)
            return "service-offline";
        if (!compatible)
            return "incompatible";
        return "ready";
    }

    property var pendingRequests: ({})
    property int requestCounter: 0

    signal statusChanged

    Component.onCompleted: detect()

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: {
            if (root.daemonOnline)
                root.refreshStatus();
            else
                root.detect();
        }
    }

    function detect() {
        if (packageCheck.running || socketProbe.running)
            return;
        checkingInstallation = true;
        packageCheck.running = true;
    }

    function probeDaemon() {
        if (!installed || socketProbe.running)
            return;
        socketProbe.running = true;
    }

    function disconnectSocket() {
        requestSocket.connected = false;
        daemonOnline = false;
        compatible = false;
        statusReceived = false;
        apiVersion = 0;
        capabilities = [];
        statusRequestPending = false;
        pendingRequests = ({});
    }

    function connectSocket() {
        if (!installed || socketPath.length === 0 || requestSocket.connected)
            return;
        requestSocket.connected = true;
    }

    function sendRequest(method, params, callback) {
        if (!daemonOnline) {
            if (callback)
                callback({"error": {"code": "daemon_offline", "message": "Regalia service is offline"}});
            return;
        }
        requestCounter++;
        const id = Date.now() + requestCounter;
        const request = {"id": id, "method": method};
        if (params !== null && params !== undefined)
            request.params = params;
        if (callback)
            pendingRequests[id] = callback;
        requestSocket.send(request);
    }

    function handleResponse(response) {
        const callback = pendingRequests[response.id];
        if (!callback)
            return;
        delete pendingRequests[response.id];
        callback(response);
    }

    function errorMessage(error) {
        if (!error)
            return "";
        if (typeof error === "string")
            return error;
        return error.message || error.code || JSON.stringify(error);
    }

    function refreshStatus() {
        if (!daemonOnline || statusRequestPending)
            return;
        statusRequestPending = true;
        sendRequest("status", null, response => {
            statusRequestPending = false;
            if (response.error) {
                lastError = errorMessage(response.error);
                return;
            }
            applyStatus(response.result || {});
        });
    }

    function applyStatus(status) {
        statusReceived = true;
        apiVersion = status.apiVersion || 0;
        capabilities = status.capabilities || [];
        compatible = apiVersion >= minimumApiVersion && capabilities.includes("vpn.toggle");
        enabled = status.enabled === true;
        connected = status.connected === true;
        engineAvailable = status.engineAvailable === true;
        engineState = status.engine || "unavailable";
        engineError = status.engineError || "";
        restoreError = status.restoreError || "";
        configurationState = status.configuration || "incomplete";
        configurationError = status.configurationError || "";
        activeServer = status.activeServer || null;
        activeRoute = status.activeRoute || null;
        lastError = "";
        statusChanged();
    }

    function setEnabled(value) {
        if (!available || busy)
            return;
        busy = true;
        sendRequest("vpn.setEnabled", {"enabled": value}, response => {
            busy = false;
            if (response.error) {
                lastError = errorMessage(response.error);
                ToastService.showError(I18n.tr("VPN operation failed"), lastError);
                refreshStatus();
                return;
            }
            applyStatus(response.result || {});
        });
    }

    function startDaemon() {
        if (!installed || startServiceProcess.running)
            return;
        busy = true;
        lastError = "";
        startServiceProcess.running = true;
    }

    function openProject() {
        Qt.openUrlExternally(projectUrl);
    }

    Process {
        id: packageCheck
        command: ["sh", "-c", "command -v regalia >/dev/null 2>&1 && command -v regaliad >/dev/null 2>&1"]
        running: false

        onExited: exitCode => {
            root.installed = exitCode === 0;
            root.checkingInstallation = false;
            if (root.installed)
                root.probeDaemon();
            else
                root.disconnectSocket();
        }
    }

    Process {
        id: socketProbe
        command: ["test", "-S", root.socketPath]
        running: false

        onExited: exitCode => {
            if (exitCode === 0)
                root.connectSocket();
            else
                root.disconnectSocket();
        }
    }

    Process {
        id: startServiceProcess
        command: ["systemctl", "--user", "start", "regaliad.service"]
        running: false

        stderr: StdioCollector {
            id: startServiceError
        }

        onExited: exitCode => {
            root.busy = false;
            if (exitCode !== 0) {
                root.lastError = startServiceError.text.trim() || I18n.tr("Failed to start Regalia service");
                return;
            }
            reconnectDelay.restart();
        }
    }

    Timer {
        id: reconnectDelay
        interval: 500
        repeat: false
        onTriggered: root.probeDaemon()
    }

    DankSocket {
        id: requestSocket
        path: root.socketPath
        connected: false

        onConnectionStateChanged: {
            root.daemonOnline = connected;
            if (connected) {
                root.statusReceived = false;
                root.lastError = "";
                root.refreshStatus();
            } else {
                root.compatible = false;
                root.statusReceived = false;
                root.statusRequestPending = false;
                root.pendingRequests = ({});
            }
        }

        parser: SplitParser {
            onRead: line => {
                if (!line || line.length === 0)
                    return;
                try {
                    root.handleResponse(JSON.parse(line));
                } catch (error) {
                    root.log.warn("Invalid Regalia response:", line.substring(0, 120));
                }
            }
        }
    }
}

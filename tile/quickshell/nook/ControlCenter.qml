// The control center: everything extra, in the launcher's style, above the bar's right end.
//   [ audio ]  output and input device, volume, mute, a mixer per app
//   [ net ]    wifi on/off and networks (NetworkManager), wired links
//   [ bt ]     bluetooth on/off, scan, devices with connect and battery
//   [ apps ]   background apps (the tray) as a list, and what's playing
//   [ nook ]   what the bar and the desktop show (Settings.qml), homelab hosts, weather place
// Opened from the bar (vol → audio, net/bt → net or bt, tray → apps, right-click λ nook → nook),
// SUPER A, or IPC:
//   qs -c nook ipc call control toggle [audio|net|bt|apps|nook]
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Scope {
    id: root

    readonly property var tabs: [
        { id: "audio", hue: Theme.rose },
        { id: "net",   hue: Theme.blue },
        { id: "bt",    hue: Theme.cyan },
        { id: "apps",  hue: Theme.amber },
        { id: "nook",  hue: Theme.red }
    ]

    IpcHandler {
        target: "control"
        function toggle(tab: string): void { Ui.openControl(tab || Ui.controlTab) }
        function close(): void { Ui.controlOpen = false }
        function rescan(): void { nm.running = true }
    }

    // ── audio: nodes by media.class ──
    readonly property var nodes: Pipewire.nodes.values
    function cls(n) { return n?.properties?.["media.class"] ?? "" }
    readonly property var sinks:   nodes.filter(n => cls(n) === "Audio/Sink")
    readonly property var sources: nodes.filter(n => cls(n) === "Audio/Source")
    readonly property var streams: nodes.filter(n => cls(n) === "Stream/Output/Audio")
    PwObjectTracker { objects: root.sinks.concat(root.sources, root.streams) }
    function label(n) { return n?.nickname || n?.description || n?.name || "?" }
    function appName(n) {
        const p = n?.properties ?? {};
        return (p["application.name"] || p["node.name"] || n?.name || "app").toLowerCase();
    }

    // ── wired links: Quickshell's network module only knows wifi ──
    property var wired: []
    Process {
        id: nm
        command: ["nmcli", "-t", "-f", "TYPE,DEVICE,STATE,CONNECTION", "device"]
        stdout: StdioCollector {
            onStreamFinished: root.wired = this.text.trim().split("\n")
                // container veths (docker, podman) and unmanaged links aren't yours to click
                .map(l => l.split(":")).filter(f => f[0] === "ethernet" && !/^veth/.test(f[1]) && f[2] !== "unmanaged")
                .map(f => ({ dev: f[1], state: f[2], conn: f[3] }))
        }
    }
    Timer { interval: 5000; repeat: true; triggeredOnStart: true; running: Ui.controlOpen && Ui.controlTab === "net"; onTriggered: nm.running = true }

    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNets: (wifiDev?.networks?.values ?? []).slice()
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))

    // wifi scans while the net tab is open
    Binding {
        when: root.wifiDev !== null
        target: root.wifiDev
        property: "scannerEnabled"
        value: Ui.controlOpen && Ui.controlTab === "net"
    }
    function nmcli(args) { Quickshell.execDetached(["sh", "-c", "nmcli \"$@\" >/dev/null 2>&1; qs -c nook ipc call control rescan", "nmcli"].concat(args)) }
    function netSettings() {
        Ui.controlOpen = false;
        Quickshell.execDetached(["sh", "-c", "command -v nm-connection-editor >/dev/null && exec nm-connection-editor || exec kitty -e nmtui"]);
    }

    property string pskFor: ""            // the wifi network asking for its password
    property string netError: ""
    property string pairingWith: ""       // bt address we paired from here: trust + connect when done
    // destructive row actions (forget, remove) need a second click within 3 s
    property string armed: ""
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }
    function confirm(id) {
        if (root.armed === id) { root.armed = ""; disarm.stop(); return true; }
        root.armed = id;
        disarm.restart();
        return false;
    }

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btDevices: (bt?.devices?.values ?? []).slice()
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name ?? "").localeCompare(b.name ?? ""))

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    function bars(v, n) { const k = Math.round(Math.max(0, Math.min(1, v)) * n); return "█".repeat(k) + "░".repeat(n - k) }
    function signal(s) { const k = Math.round(s * 4); return "▂▄▆█".slice(0, k).padEnd(4, " ") }

    // ── small parts in the design system's look ──
    component Mono: Text {
        color: Theme.ink
        font.family: Theme.font
        font.pixelSize: 12
        elide: Text.ElideRight
    }
    component Label: Mono {
        color: Theme.faint
        font.pixelSize: Theme.label
        font.bold: true
        font.letterSpacing: 1.2
        Layout.topMargin: 6
        Layout.bottomMargin: 2
    }
    // [ text ] button: outlined in its hue, filled when on
    component Btn: Rectangle {
        id: btn
        property string text
        property color hue: Theme.cyan
        property bool on: false
        signal clicked()
        implicitWidth: bt_.implicitWidth + 16
        implicitHeight: 22
        radius: Theme.radiusSm
        color: on ? hue : btnArea.containsMouse ? Theme.soft(hue) : "transparent"
        border.width: 1
        border.color: hue
        Mono { id: bt_; anchors.centerIn: parent; text: btn.text; color: btn.on ? Theme.onAccent : btn.hue; font.pixelSize: Theme.small; font.bold: btn.on }
        MouseArea { id: btnArea; anchors.fill: parent; hoverEnabled: true; onClicked: btn.clicked() }
    }
    // a selectable row: [•] name ........ note, cyan ring when it's the current one
    // An optional [action] button at the end (forget, remove …) sits on top of the row's click.
    component Row: Rectangle {
        id: row
        property string name
        property string note
        property color hue: Theme.ink
        property bool current: false
        property string action: ""
        property color actionHue: Theme.orange
        signal clicked()
        signal actionClicked()
        Layout.fillWidth: true
        implicitHeight: 24
        radius: Theme.radiusSm
        color: current ? Theme.soft(Theme.cyan) : rowArea.containsMouse ? Theme.bg300 : "transparent"
        border.width: current ? 1 : rowArea.containsMouse ? 1 : 0
        border.color: current ? Theme.cyan : Theme.line
        MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.clicked() }
        RowLayout {
            anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
            spacing: 8
            Mono { text: row.current ? "[•]" : "[ ]"; color: row.current ? Theme.cyan : Theme.faint }
            Mono { text: row.name; color: row.hue; Layout.maximumWidth: 230 }
            Mono { text: ".".repeat(80); color: Theme.faint; Layout.fillWidth: true; clip: true; elide: Text.ElideNone }
            Mono { text: row.note; color: Theme.muted; font.pixelSize: Theme.small }
            Btn {
                visible: row.action !== ""
                text: row.action
                hue: row.actionHue
                implicitHeight: 18
                onClicked: row.actionClicked()
            }
        }
    }
    // [x] name  note: a compact on/off switch for the nook tab
    component Check: Rectangle {
        id: chk
        property string name
        property string note
        property bool on: true
        property color hue: Theme.red
        signal toggled()
        Layout.fillWidth: true
        implicitHeight: 22
        radius: Theme.radiusSm
        color: chkArea.containsMouse ? Theme.bg300 : "transparent"
        RowLayout {
            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
            spacing: 6
            Mono { text: chk.on ? "[x]" : "[ ]"; color: chk.on ? chk.hue : Theme.faint; font.bold: chk.on }
            Mono { text: chk.name; color: chk.on ? Theme.ink : Theme.muted }
            Mono { text: chk.note; color: Theme.faint; font.pixelSize: Theme.label; Layout.fillWidth: true }
        }
        MouseArea { id: chkArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chk.toggled() }
    }
    // a one-line text field; ⏎ accepts, esc cancels (closes when empty), tab jumps to `next`
    component Field: Rectangle {
        id: field
        property alias text: input.text
        property string placeholder
        property bool secret: false
        property color hue: Theme.cyan
        property Item next: null
        signal accepted()
        signal cancelled()
        function focusIn() { input.forceActiveFocus() }
        Layout.fillWidth: true
        implicitHeight: 24
        radius: Theme.radiusSm
        color: Theme.bg200
        border.width: 1
        border.color: input.activeFocus ? field.hue : Theme.line
        MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: input.forceActiveFocus() }
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: 7; rightMargin: 7 }
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.ink
            selectionColor: field.hue
            selectedTextColor: Theme.onAccent
            font.family: Theme.font
            font.pixelSize: 12
            echoMode: field.secret ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            clip: true
            selectByMouse: true
            onAccepted: field.accepted()
            // esc in an empty field falls through and closes the panel
            Keys.onEscapePressed: e => { if (text === "") e.accepted = false; else field.cancelled() }
            Keys.onTabPressed: e => { if (field.next) field.next.focusIn(); else e.accepted = false }
        }
        Mono {
            anchors { fill: parent; leftMargin: 7 }
            verticalAlignment: Text.AlignVCenter
            visible: input.text === "" && !input.activeFocus
            text: field.placeholder
            color: Theme.faint
        }
    }
    // [██████░░░░] 60%: click or drag to set, scroll for ±5%
    component Level: RowLayout {
        id: lvl
        property real value: 0
        property bool muted: false
        property color hue: Theme.rose
        property string name: "vol"
        signal picked(real v)
        signal toggleMute()
        Layout.fillWidth: true
        spacing: 8
        Mono { text: lvl.name; color: Theme.muted; Layout.preferredWidth: 34 }
        Mono {
            id: barText
            Layout.fillWidth: true
            text: "[" + root.bars(lvl.value, 24) + "]"
            color: lvl.muted ? Theme.faint : lvl.hue
            elide: Text.ElideNone
            MouseArea {
                anchors.fill: parent
                function at(x) { lvl.picked(Math.max(0, Math.min(1, (x - 7) / (barText.contentWidth - 14)))) }
                onPressed: m => at(m.x)
                onPositionChanged: m => { if (pressed) at(m.x) }
                onWheel: w => lvl.picked(Math.max(0, Math.min(1, lvl.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
        Mono { text: lvl.muted ? "mute" : Math.round(lvl.value * 100) + "%"; color: lvl.muted ? Theme.faint : Theme.ink; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
        Btn { text: lvl.muted ? "unmute" : "mute"; hue: Theme.orange; on: lvl.muted; onClicked: lvl.toggleMute() }
    }

    HyprlandFocusGrab {
        windows: [panel]
        active: Ui.controlOpen && panel.visible
        onCleared: Ui.controlOpen = false
    }

    PanelWindow {
        id: panel
        visible: Ui.controlOpen
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nook-control"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        anchors { bottom: true; right: true }
        margins { bottom: Theme.pill + 10 + Theme.gap; right: Theme.pad }
        implicitWidth: 520
        implicitHeight: Math.min(card.implicitHeight, (screen?.height ?? 1440) - 120) + 20
        color: "transparent"

        RectangularShadow {
            anchors.fill: card
            radius: Theme.radius
            blur: 24
            color: Theme.alpha(Theme.cyan, 0.45)
        }

        Rectangle {
            id: card
            x: 10; y: 10
            width: 500
            height: parent.height - 20
            implicitHeight: body.implicitHeight + 2
            radius: Theme.radius
            color: Theme.bg100
            border.width: 1
            border.color: Theme.cyan
            clip: true
            focus: true
            Keys.onEscapePressed: Ui.controlOpen = false
            Keys.onTabPressed: {
                const i = root.tabs.findIndex(t => t.id === Ui.controlTab);
                Ui.controlTab = root.tabs[(i + 1) % root.tabs.length].id;
            }

            Flickable {
                anchors.fill: parent
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: body
                    width: card.width
                    spacing: 0

                    // ── header: title + tabs ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.margins: 14
                        Layout.bottomMargin: 10
                        spacing: 6
                        Text { text: "λ control"; color: Theme.ink; font.family: Theme.pixel; font.pixelSize: 24 }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: root.tabs
                            Btn {
                                required property var modelData
                                text: modelData.id
                                hue: modelData.hue
                                on: Ui.controlTab === modelData.id
                                onClicked: Ui.controlTab = modelData.id
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.line }

                    // ── AUDIO ──
                    ColumnLayout {
                        visible: Ui.controlTab === "audio"
                        Layout.fillWidth: true
                        Layout.margins: 14
                        spacing: 3

                        Label { text: "AUDIO // OUT" }
                        Level {
                            name: "vol"
                            hue: Theme.rose
                            value: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                            muted: Pipewire.defaultAudioSink?.audio?.muted ?? false
                            onPicked: v => { if (Pipewire.defaultAudioSink?.audio) Pipewire.defaultAudioSink.audio.volume = v }
                            onToggleMute: { const a = Pipewire.defaultAudioSink?.audio; if (a) a.muted = !a.muted }
                        }
                        Repeater {
                            model: root.sinks
                            Row {
                                required property var modelData
                                name: root.label(modelData)
                                note: modelData === Pipewire.defaultAudioSink ? "default" : ""
                                current: modelData === Pipewire.defaultAudioSink
                                hue: current ? Theme.ink : Theme.muted
                                onClicked: Pipewire.preferredDefaultAudioSink = modelData
                            }
                        }

                        Label { text: "AUDIO // IN" }
                        Level {
                            name: "mic"
                            hue: Theme.aqua
                            value: Pipewire.defaultAudioSource?.audio?.volume ?? 0
                            muted: Pipewire.defaultAudioSource?.audio?.muted ?? false
                            onPicked: v => { if (Pipewire.defaultAudioSource?.audio) Pipewire.defaultAudioSource.audio.volume = v }
                            onToggleMute: { const a = Pipewire.defaultAudioSource?.audio; if (a) a.muted = !a.muted }
                        }
                        Repeater {
                            model: root.sources
                            Row {
                                required property var modelData
                                name: root.label(modelData)
                                note: modelData === Pipewire.defaultAudioSource ? "default" : ""
                                current: modelData === Pipewire.defaultAudioSource
                                hue: current ? Theme.ink : Theme.muted
                                onClicked: Pipewire.preferredDefaultAudioSource = modelData
                            }
                        }

                        Label { text: "MIXER // APPS"; visible: root.streams.length > 0 }
                        Repeater {
                            model: root.streams
                            Level {
                                required property var modelData
                                name: root.appName(modelData).slice(0, 4)
                                hue: Theme.rose
                                value: modelData.audio?.volume ?? 0
                                muted: modelData.audio?.muted ?? false
                                onPicked: v => { if (modelData.audio) modelData.audio.volume = v }
                                onToggleMute: { if (modelData.audio) modelData.audio.muted = !modelData.audio.muted }
                            }
                        }
                        Mono { visible: root.streams.length === 0; text: "  nothing is playing sound"; color: Theme.faint; font.pixelSize: Theme.small; Layout.topMargin: 6 }
                    }

                    // ── NET ──
                    ColumnLayout {
                        visible: Ui.controlTab === "net"
                        Layout.fillWidth: true
                        Layout.margins: 14
                        spacing: 3

                        Label { text: "NET // WIRED"; visible: root.wired.length > 0 }
                        Repeater {
                            model: root.wired
                            Row {
                                required property var modelData
                                readonly property bool up: modelData.state === "connected"
                                name: modelData.dev + (modelData.conn ? "  " + modelData.conn : "")
                                readonly property bool cable: modelData.state !== "unavailable"
                                note: cable ? modelData.state : "no cable"
                                current: up
                                hue: up ? Theme.ink : Theme.muted
                                action: !cable ? "" : up ? "disconnect" : "connect"
                                actionHue: up ? Theme.orange : Theme.blue
                                onClicked: if (cable) actionClicked()
                                onActionClicked: root.nmcli(["device", up ? "disconnect" : "connect", modelData.dev])
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "NET // WIFI" + (root.wifiDev ? "  " + root.wifiDev.name : "") }
                            Mono {
                                visible: root.wifiDev?.scannerEnabled ?? false
                                text: "scanning…"; color: Theme.faint; font.pixelSize: Theme.label
                                Layout.topMargin: 6; Layout.bottomMargin: 2
                            }
                            Item { Layout.fillWidth: true }
                            Btn {
                                text: Networking.wifiEnabled ? "wifi on" : "wifi off"
                                hue: Theme.blue
                                on: Networking.wifiEnabled
                                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                            }
                            Btn { text: "settings"; hue: Theme.amber; onClicked: root.netSettings() }
                        }
                        Mono { visible: !root.wifiDev; text: "  no wifi device"; color: Theme.faint; font.pixelSize: Theme.small }
                        Repeater {
                            model: Networking.wifiEnabled ? root.wifiNets.slice(0, 12) : []
                            ColumnLayout {
                                id: wrow
                                required property var modelData
                                readonly property string ssid: modelData.name || "(hidden)"
                                readonly property bool open: modelData.security === WifiSecurityType.Open
                                readonly property bool busy: modelData.stateChanging || modelData.state === ConnectionState.Connecting
                                readonly property bool asking: root.pskFor !== "" && root.pskFor === modelData.name
                                Layout.fillWidth: true
                                spacing: 3

                                Connections {
                                    target: wrow.modelData
                                    function onConnectionFailed(reason) {
                                        root.netError = wrow.ssid + ": " + ConnectionFailReason.toString(reason).toLowerCase();
                                        if (reason === ConnectionFailReason.NoSecrets && !wrow.open) root.pskFor = wrow.modelData.name;
                                    }
                                    function onConnectedChanged() {
                                        if (wrow.modelData.connected && root.pskFor === wrow.modelData.name) root.pskFor = "";
                                        if (wrow.modelData.connected) root.netError = "";
                                    }
                                }

                                Row {
                                    name: wrow.ssid
                                    note: (wrow.busy ? "connecting…  " : wrow.modelData.connected ? "connected  " : wrow.modelData.known ? "known  " : "")
                                          + (wrow.open ? "open " : "") + root.signal(wrow.modelData.signalStrength)
                                    current: wrow.modelData.connected || wrow.asking
                                    hue: wrow.modelData.connected ? Theme.ink : wrow.modelData.known ? Theme.blue : Theme.muted
                                    action: wrow.modelData.known ? (root.armed === "wifi:" + wrow.ssid ? "sure?" : "forget") : ""
                                    // known and open networks connect right away; new secured ones ask below
                                    onClicked: {
                                        root.netError = "";
                                        if (wrow.modelData.connected) wrow.modelData.disconnect();
                                        else if (wrow.modelData.known || wrow.open) wrow.modelData.connect();
                                        else root.pskFor = wrow.asking ? "" : wrow.modelData.name;
                                    }
                                    onActionClicked: { if (root.confirm("wifi:" + wrow.ssid)) wrow.modelData.forget() }
                                }
                                RowLayout {
                                    visible: wrow.asking
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 30
                                    Layout.bottomMargin: 4
                                    spacing: 6
                                    onVisibleChanged: if (visible) { psk.text = ""; psk.focusIn() }
                                    Mono { text: "λ psk >"; color: Theme.aqua }
                                    Field {
                                        id: psk
                                        secret: !showPsk.on
                                        hue: Theme.blue
                                        placeholder: "password"
                                        onAccepted: if (text.length >= 8) { wrow.modelData.connectWithPsk(text); root.netError = "" }
                                                    else root.netError = "a wifi password has at least 8 characters"
                                        onCancelled: root.pskFor = ""
                                    }
                                    Btn { id: showPsk; text: "show"; hue: Theme.faint; onClicked: on = !on }
                                    Btn { text: "join"; hue: Theme.blue; on: psk.text.length >= 8; onClicked: psk.accepted() }
                                }
                            }
                        }
                        Mono {
                            visible: root.netError !== ""
                            Layout.fillWidth: true
                            text: "[!!] " + root.netError
                            color: Theme.orange; font.pixelSize: Theme.small; wrapMode: Text.Wrap
                        }
                        Mono {
                            text: "click: connect / disconnect · new networks ask for the password here"
                            color: Theme.faint; font.pixelSize: Theme.label; Layout.topMargin: 6
                        }
                    }

                    // ── BT ──
                    ColumnLayout {
                        visible: Ui.controlTab === "bt"
                        Layout.fillWidth: true
                        Layout.margins: 14
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "BT // " + (root.bt?.name ?? "no adapter") }
                            Item { Layout.fillWidth: true }
                            Btn {
                                visible: !!root.bt
                                text: root.bt?.enabled ? "bt on" : "bt off"
                                hue: Theme.cyan
                                on: root.bt?.enabled ?? false
                                onClicked: root.bt.enabled = !root.bt.enabled
                            }
                            Btn {
                                visible: root.bt?.enabled ?? false
                                text: root.bt?.discovering ? "scanning…" : "scan"
                                hue: Theme.blue
                                on: root.bt?.discovering ?? false
                                onClicked: root.bt.discovering = !root.bt.discovering
                            }
                        }
                        Repeater {
                            model: (root.bt?.enabled ?? false) ? root.btDevices.slice(0, 14) : []
                            Row {
                                id: brow
                                required property var modelData
                                readonly property bool connecting: modelData.state === BluetoothDeviceState.Connecting
                                Connections {
                                    target: brow.modelData
                                    // paired from here: trust it (reconnects by itself later) and connect
                                    function onPairedChanged() {
                                        if (brow.modelData.paired && root.pairingWith === brow.modelData.address) {
                                            root.pairingWith = "";
                                            brow.modelData.trusted = true;
                                            brow.modelData.connect();
                                        }
                                    }
                                }
                                name: modelData.name || modelData.address
                                note: (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%  " : "")
                                      + (modelData.connected ? "connected" : modelData.pairing ? "pairing…"
                                         : connecting ? "connecting…"
                                         : modelData.paired ? "paired" : "new")
                                current: modelData.connected
                                hue: modelData.connected ? Theme.ink : modelData.paired ? Theme.cyan : Theme.muted
                                action: modelData.pairing ? "cancel"
                                      : modelData.paired ? (root.armed === "bt:" + modelData.address ? "sure?" : "forget") : ""
                                onClicked: {
                                    if (modelData.connected) modelData.disconnect();
                                    else if (modelData.paired) modelData.connect();
                                    else if (!modelData.pairing) { root.pairingWith = modelData.address; modelData.pair(); }
                                }
                                onActionClicked: {
                                    if (modelData.pairing) modelData.cancelPair();
                                    else if (root.confirm("bt:" + modelData.address)) modelData.forget();
                                }
                            }
                        }
                        Mono {
                            visible: (root.bt?.enabled ?? false) && root.btDevices.length === 0
                            text: "  no devices · press scan"; color: Theme.faint; font.pixelSize: Theme.small
                        }
                        Mono {
                            text: "click: connect / disconnect · new devices pair and connect (scan first)"
                            color: Theme.faint; font.pixelSize: Theme.label; Layout.topMargin: 6
                        }
                    }

                    // ── NOOK: what the shell shows, homelab hosts, weather place ──
                    ColumnLayout {
                        id: nookTab
                        visible: Ui.controlTab === "nook"
                        Layout.fillWidth: true
                        Layout.margins: 14
                        spacing: 3

                        readonly property var hostRe: /^[A-Za-z0-9][A-Za-z0-9_.-]{0,252}(:\d{1,5})?$/
                        readonly property var nameRe: /^[A-Za-z0-9][A-Za-z0-9_.-]{0,31}$/
                        function addHost() {
                            const n = newName.text.trim(), h = newHost.text.trim();
                            if (!nookTab.nameRe.test(n)) { Feeds.confError = "name: letters, digits, '.', '_', '-' (no spaces)"; newName.focusIn(); return; }
                            if (!nookTab.hostRe.test(h)) { Feeds.confError = "host: an address or name, or host:port"; newHost.focusIn(); return; }
                            Feeds.setConf("srv", n, h);
                            Settings.set("widget.srv", true);
                            newName.text = ""; newHost.text = "";
                            newName.focusIn();
                        }

                        Label { text: "BAR // MODULES" }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 6
                            rowSpacing: 0
                            Repeater {
                                model: Settings.bar
                                Check {
                                    required property var modelData
                                    name: modelData.name; note: modelData.note
                                    on: Settings.shown(modelData.id)
                                    hue: Theme.red
                                    onToggled: Settings.toggle(modelData.id)
                                }
                            }
                        }

                        Label { text: "DESK // WIDGETS" }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 6
                            rowSpacing: 0
                            Repeater {
                                model: Settings.widgets.concat(Settings.desk)
                                Check {
                                    required property var modelData
                                    name: modelData.name.toLowerCase(); note: modelData.note
                                    on: Settings.shown(modelData.id)
                                    hue: Theme.aqua
                                    onToggled: Settings.toggle(modelData.id)
                                }
                            }
                        }

                        Label { text: "SRV // HOMELAB · " + (Feeds.conf.srv ?? []).length }
                        Repeater {
                            model: Feeds.conf.srv ?? []
                            Row {
                                required property var modelData
                                readonly property var live: (Feeds.srv.hosts ?? []).find(h => h.name === modelData.name) ?? null
                                name: modelData.name
                                note: modelData.host + (live ? (live.up ? "  ● " + Math.round(live.ms) + "ms" : "  ● down") : "")
                                hue: live ? (live.up ? Theme.aqua : Theme.orange) : Theme.ink
                                action: root.armed === "srv:" + modelData.name ? "sure?" : "remove"
                                onClicked: { newName.text = modelData.name; newHost.text = modelData.host; newHost.focusIn() }
                                onActionClicked: { if (root.confirm("srv:" + modelData.name)) Feeds.unsetConf("srv", modelData.name) }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Field { id: newName; placeholder: "name"; Layout.preferredWidth: 120; Layout.fillWidth: false; next: newHost; onAccepted: newHost.focusIn(); onCancelled: text = "" }
                            Field { id: newHost; placeholder: "host  or  host:port"; next: newName; onAccepted: nookTab.addHost(); onCancelled: text = "" }
                            Btn { text: (Feeds.conf.srv ?? []).some(h => h.name === newName.text.trim()) ? "save" : "add"; hue: Theme.aqua; onClicked: nookTab.addHost() }
                        }

                        Label { text: "WX // PLACE" }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Field {
                                id: place
                                text: Feeds.conf.weather?.location ?? ""
                                placeholder: "city, ~landmark or airport · empty = by IP"
                                hue: Theme.gold
                                onAccepted: Feeds.setConf("weather", "location", text.trim())
                                onCancelled: text = Feeds.conf.weather?.location ?? ""
                            }
                            Btn { text: "set"; hue: Theme.gold; onClicked: place.accepted() }
                        }

                        Mono {
                            visible: Feeds.confError !== ""
                            Layout.fillWidth: true
                            text: "[!!] " + Feeds.confError
                            color: Theme.orange; font.pixelSize: Theme.small; wrapMode: Text.Wrap
                        }
                        Mono {
                            Layout.fillWidth: true
                            text: "click: on / off · a host row fills the form · kept in ~/.config/nook/shell.json and " + (Feeds.conf.path ?? "widgets.conf")
                            color: Theme.faint; font.pixelSize: Theme.label; Layout.topMargin: 6; wrapMode: Text.Wrap
                        }
                    }

                    // ── APPS: background apps (tray) + media ──
                    ColumnLayout {
                        visible: Ui.controlTab === "apps"
                        Layout.fillWidth: true
                        Layout.margins: 14
                        spacing: 3

                        Label { text: "APPS // BACKGROUND · " + SystemTray.items.values.length }
                        Repeater {
                            model: SystemTray.items
                            Rectangle {
                                id: trow
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 26
                                radius: Theme.radiusSm
                                color: tArea.containsMouse ? Theme.bg300 : "transparent"
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                    spacing: 8
                                    Mono { text: "[" + String(trow.index + 1).padStart(2, "0") + "]"; color: Theme.faint }
                                    IconImage { source: trow.modelData.icon; implicitSize: 16 }
                                    Mono {
                                        text: (trow.modelData.title || trow.modelData.tooltipTitle || trow.modelData.id).toLowerCase()
                                        color: Theme.amber
                                        Layout.maximumWidth: 200
                                    }
                                    Mono { text: ".".repeat(80); color: Theme.faint; Layout.fillWidth: true; clip: true; elide: Text.ElideNone }
                                    Mono { text: trow.modelData.status === Status.NeedsAttention ? "needs you" : trow.modelData.id.toLowerCase(); color: trow.modelData.status === Status.NeedsAttention ? Theme.orange : Theme.muted; font.pixelSize: Theme.small; Layout.maximumWidth: 120 }
                                }
                                MouseArea {
                                    id: tArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: m => {
                                        if (m.button === Qt.RightButton || trow.modelData.onlyMenu) {
                                            const p = trow.mapToItem(null, m.x, m.y);
                                            trow.modelData.display(panel, p.x, p.y);
                                        } else {
                                            trow.modelData.activate();
                                            Ui.controlOpen = false;
                                        }
                                    }
                                }
                            }
                        }
                        Mono { visible: SystemTray.items.values.length === 0; text: "  nothing running in the background"; color: Theme.faint; font.pixelSize: Theme.small }

                        Label { text: "MEDIA // NOW"; visible: root.player !== null }
                        ColumnLayout {
                            visible: root.player !== null
                            Layout.fillWidth: true
                            spacing: 2
                            Mono { text: root.player?.trackTitle ?? ""; color: Theme.ink; font.bold: true; Layout.fillWidth: true }
                            Mono { text: (root.player?.trackArtist ?? "") + "  ·  " + (root.player?.identity ?? "").toLowerCase(); color: Theme.muted; Layout.fillWidth: true }
                            RowLayout {
                                spacing: 6
                                Btn { text: "◀◀"; hue: Theme.rose; onClicked: root.player?.previous() }
                                Btn { text: root.player?.isPlaying ? "▮▮" : "▶"; hue: Theme.rose; on: root.player?.isPlaying ?? false; onClicked: root.player?.togglePlaying() }
                                Btn { text: "▶▶"; hue: Theme.rose; onClicked: root.player?.next() }
                            }
                        }
                        Mono {
                            text: "click: open · right-click: its menu"
                            color: Theme.faint; font.pixelSize: Theme.label; Layout.topMargin: 6
                        }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.line }
                    Mono {
                        Layout.margins: 10
                        Layout.leftMargin: 14
                        text: "tab next · esc close · SUPER A"
                        color: Theme.faint; font.pixelSize: Theme.label
                    }
                }
            }
        }
    }
}

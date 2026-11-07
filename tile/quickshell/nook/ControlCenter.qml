// The control center: everything extra, in the launcher's style, above the bar's right end.
//   [ audio ]  output and input device, volume, mute, a mixer per app
//   [ net ]    wifi on/off and networks (NetworkManager), wired links
//   [ bt ]     bluetooth on/off, scan, devices with connect and battery
//   [ apps ]   background apps (the tray) as a list, and what's playing
// Opened from the bar (vol → audio, net/bt → net or bt, tray → apps), SUPER A, or IPC:
//   qs -c nook ipc call control toggle [audio|net|bt|apps]
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
        { id: "apps",  hue: Theme.amber }
    ]

    IpcHandler {
        target: "control"
        function toggle(tab: string): void { Ui.openControl(tab || Ui.controlTab) }
        function close(): void { Ui.controlOpen = false }
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
                .map(l => l.split(":")).filter(f => f[0] === "ethernet")
                .map(f => ({ dev: f[1], state: f[2], conn: f[3] }))
        }
    }
    Timer { interval: 5000; repeat: true; triggeredOnStart: true; running: Ui.controlOpen && Ui.controlTab === "net"; onTriggered: nm.running = true }

    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNets: (wifiDev?.networks?.values ?? []).slice()
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))

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
    component Row: Rectangle {
        id: row
        property string name
        property string note
        property color hue: Theme.ink
        property bool current: false
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 24
        radius: Theme.radiusSm
        color: current ? Theme.soft(Theme.cyan) : rowArea.containsMouse ? Theme.bg300 : "transparent"
        border.width: current ? 1 : 0
        border.color: Theme.cyan
        RowLayout {
            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
            spacing: 8
            Mono { text: row.current ? "[•]" : "[ ]"; color: row.current ? Theme.cyan : Theme.faint }
            Mono { text: row.name; color: row.hue; Layout.maximumWidth: 250 }
            Mono { text: ".".repeat(80); color: Theme.faint; Layout.fillWidth: true; clip: true; elide: Text.ElideNone }
            Mono { text: row.note; color: Theme.muted; font.pixelSize: Theme.small }
        }
        MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; onClicked: row.clicked() }
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
                                name: modelData.dev + (modelData.conn ? "  " + modelData.conn : "")
                                note: modelData.state
                                current: modelData.state === "connected"
                                hue: current ? Theme.ink : Theme.muted
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "NET // WIFI" + (root.wifiDev ? "  " + root.wifiDev.name : "") }
                            Item { Layout.fillWidth: true }
                            Btn {
                                text: Networking.wifiEnabled ? "wifi on" : "wifi off"
                                hue: Theme.blue
                                on: Networking.wifiEnabled
                                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                            }
                            Btn { text: "settings"; hue: Theme.amber; onClicked: { Ui.controlOpen = false; Quickshell.execDetached(["kitty", "-e", "nmtui"]) } }
                        }
                        Mono { visible: !root.wifiDev; text: "  no wifi device"; color: Theme.faint; font.pixelSize: Theme.small }
                        Repeater {
                            model: Networking.wifiEnabled ? root.wifiNets.slice(0, 12) : []
                            Row {
                                required property var modelData
                                name: modelData.name || "(hidden)"
                                note: (modelData.connected ? "connected  " : modelData.known ? "known  " : "")
                                      + (modelData.security === WifiSecurityType.Open ? "open " : "") + root.signal(modelData.signalStrength)
                                current: modelData.connected
                                hue: modelData.connected ? Theme.ink : modelData.known ? Theme.blue : Theme.muted
                                // known and open networks connect here; new secured ones go through nmtui
                                onClicked: {
                                    if (modelData.connected) modelData.disconnect();
                                    else if (modelData.known || modelData.security === WifiSecurityType.Open) modelData.connect();
                                    else { Ui.controlOpen = false; Quickshell.execDetached(["kitty", "-e", "nmtui", "connect", modelData.name]); }
                                }
                            }
                        }
                        Mono {
                            text: "click: connect / disconnect · new secured networks ask for the password in nmtui"
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
                                required property var modelData
                                name: modelData.name || modelData.address
                                note: (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%  " : "")
                                      + (modelData.connected ? "connected" : modelData.pairing ? "pairing…"
                                         : modelData.state === BluetoothDeviceState.Connecting ? "connecting…"
                                         : modelData.paired ? "paired" : "new")
                                current: modelData.connected
                                hue: modelData.connected ? Theme.ink : modelData.paired ? Theme.cyan : Theme.muted
                                onClicked: {
                                    if (modelData.connected) modelData.disconnect();
                                    else if (modelData.paired) modelData.connect();
                                    else modelData.pair();
                                }
                            }
                        }
                        Mono {
                            visible: (root.bt?.enabled ?? false) && root.btDevices.length === 0
                            text: "  no devices · press scan"; color: Theme.faint; font.pixelSize: Theme.small
                        }
                        Mono {
                            text: "click: connect / disconnect · new devices pair (scan first)"
                            color: Theme.faint; font.pixelSize: Theme.label; Layout.topMargin: 6
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

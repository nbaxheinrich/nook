// The bar: separate floating modules along the bottom, 10px above the edge, 12px from the sides.
//   λ nook · workspaces · window title ······ clock ······ cpu/ram · vol · tray · power
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Bluetooth
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Scope {
    id: root

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ── keyboard layout (eu / de). Hyprland 0.57 sends no event for switchxkblayout, so the
    //    switch (pill click or SUPER K) asks for a re-read over IPC; a slow poll catches the rest ──
    property string kb: ""
    function kbShort(name) {
        if (/eurkey/i.test(name)) return "eu";
        if (/german|deutsch/i.test(name)) return "de";
        return name.slice(0, 2).toLowerCase();
    }
    function switchKb() { Quickshell.execDetached(["sh", "-c", "hyprctl switchxkblayout all next >/dev/null && qs -c nook ipc call kb refresh"]) }
    IpcHandler {
        target: "kb"
        function refresh(): void { kbRead.running = true }
    }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: kbRead.running = true }
    Process {
        id: kbRead
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const k = JSON.parse(this.text).keyboards;
                    const main = k.find(x => x.main) ?? k[0];
                    if (main) root.kb = root.kbShort(main.active_keymap);
                } catch (e) {}
            }
        }
    }
    Connections {
        target: Hyprland
        // data: "<keyboard>,<layout name>"
        function onRawEvent(event) {
            if (event.name === "activelayout") root.kb = root.kbShort(event.data.split(",").slice(1).join(","));
        }
    }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // Hyprland 0.57 takes Lua dispatchers over IPC
    function dispatch(lua) { Quickshell.execDetached(["hyprctl", "dispatch", lua]) }
    function openMenu() { Ui.toggleLauncher() }

    // one bar module: bg-100 at 88%, 1px line, radius-md
    component Pill: Rectangle {
        id: pill
        default property alias content: row.data
        property bool hot: false                       // cyan ring + glow (menu open, hover)
        signal clicked(var mouse)
        signal scrolled(var wheel)
        implicitHeight: Theme.pill
        implicitWidth: row.implicitWidth + 28
        radius: Theme.radius
        color: Theme.alpha(Theme.bg100, 0.88)
        border.width: 1
        border.color: hot || area.containsMouse ? Theme.cyan : Theme.line
        Behavior on border.color { ColorAnimation { duration: 120 } }
        // declared before the row so mouse areas inside the module (workspace marks, tray icons) sit on top
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: m => pill.clicked(m)
            onWheel: w => pill.scrolled(w)
        }
        RowLayout { id: row; anchors.centerIn: parent; spacing: 10 }
    }
    component Label: Text {
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: Theme.small
    }
    // coloured text gets a soft halo in its own colour
    component Glow: MultiEffect {
        shadowEnabled: true
        shadowBlur: 0.6
        shadowOpacity: 0.55
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            readonly property var hmon: Hyprland.monitorFor(modelData)
            screen: modelData
            WlrLayershell.namespace: "nook-bar"
            anchors { bottom: true; left: true; right: true }
            margins { bottom: 10; left: Theme.pad; right: Theme.pad }
            implicitHeight: Theme.pill
            // 6 px short of the bar's top edge: with gaps_out 12, windows end 6 px above the bar,
            // the same as the gap between two windows
            exclusiveZone: Theme.pill + 10 - 6
            color: "transparent"

            // ── overflow: the clock sits in the middle, each side gets half of what's left ──
            // left:  start + workspaces stay; the window tag takes the rest (title first, then
            //        the whole tag, go when there's no room)
            // right: cpu/ram goes first, then the tray icons ("bg N" stays)
            readonly property real half: (width - clockPill.implicitWidth) / 2 - Theme.gap
            readonly property real tagRoom: half - startPill.implicitWidth - wsPill.implicitWidth - 2 * Theme.gap
            readonly property real tagFixed: 28 + 4 * 10 + lb.implicitWidth + appLbl.implicitWidth + dash.implicitWidth + rb.implicitWidth
            readonly property real titleRoom: Math.min(320, tagRoom - tagFixed)
            readonly property real bgIconsW: SystemTray.items.values.length * (16 + 10)
            readonly property real bgFullW: bgPill.visible ? 28 + bgLbl.implicitWidth + bgIconsW + Theme.gap : 0
            readonly property real rightCore: kbPill.implicitWidth + netbt.implicitWidth + vol.implicitWidth + powerPill.implicitWidth + 3 * Theme.gap
            readonly property bool showCpu: rightCore + bgFullW + cpuPill.implicitWidth + Theme.gap <= half
            readonly property bool showBgIcons: rightCore + bgFullW <= half

            RowLayout {
                anchors.fill: parent
                spacing: Theme.gap

                // ── λ nook: solid red neon, opens the hack menu ──
                Pill {
                    id: startPill
                    color: Theme.red
                    border.color: Ui.launcherOpen ? Theme.cyan : Theme.red
                    border.width: Ui.launcherOpen ? 2 : 1
                    onClicked: root.openMenu()
                    layer.enabled: true
                    layer.effect: Glow { shadowColor: Theme.red; shadowBlur: 0.8; shadowOpacity: 0.7 }
                    Text { text: "λ"; color: Theme.onAccent; font.family: Theme.pixel; font.pixelSize: 26 }
                    Text { text: "nook"; color: Theme.onAccent; font.family: Theme.font; font.pixelSize: Theme.body; font.bold: true }
                }

                // ── workspaces 1–9: active = cyan bar, occupied = muted, empty = faint, urgent = orange ──
                Pill {
                    id: wsPill
                    onScrolled: w => root.dispatch(`hl.dsp.focus({ workspace = "${w.angleDelta.y < 0 ? "e+1" : "e-1"}" })`)
                    Repeater {
                        model: 9
                        Item {
                            id: mark
                            required property int index
                            readonly property int ws: index + 1
                            readonly property var wsObj: Hyprland.workspaces.values.find(w => w.id === ws) ?? null
                            readonly property bool active: bar.hmon?.activeWorkspace?.id === ws
                            readonly property bool urgent: wsObj?.urgent ?? false
                            implicitWidth: dot.width
                            implicitHeight: 14
                            Rectangle {
                                id: dot
                                anchors.verticalCenter: parent.verticalCenter
                                width: mark.active ? 30 : 10
                                height: 10
                                radius: Theme.radiusSm
                                color: mark.urgent ? Theme.orange : mark.active ? Theme.cyan
                                     : mark.wsObj ? Theme.muted : Theme.faint
                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 180 } }
                                layer.enabled: mark.active || mark.urgent
                                layer.effect: Glow { shadowColor: dot.color }
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -3
                                onClicked: root.dispatch(`hl.dsp.focus({ workspace = ${mark.ws} })`)
                            }
                        }
                    }
                }

                // ── focused window as a tag ──
                Pill {
                    id: titlePill
                    visible: (ToplevelManager.activeToplevel?.title ?? "") !== ""
                             && bar.tagRoom >= bar.tagFixed - dash.implicitWidth - 10
                    Label { id: lb; text: "["; color: Theme.faint }
                    Label {
                        id: appLbl
                        // "org.kde.dolphin" → dolphin, Chromium web apps "brave-<32 letters>-default" → brave app
                        text: (ToplevelManager.activeToplevel?.appId ?? "").replace(/^(\w+)-[a-p]{32}-\w+$/, "$1 app").split(".").pop().toLowerCase()
                        color: Theme.cyan
                    }
                    Label { id: dash; text: "—"; color: Theme.faint; visible: bar.titleRoom >= 40 }
                    Label {
                        text: ToplevelManager.activeToplevel?.title ?? ""
                        color: Theme.ink
                        elide: Text.ElideRight
                        visible: bar.titleRoom >= 40
                        Layout.maximumWidth: Math.max(40, bar.titleRoom)
                    }
                    Label { id: rb; text: "]"; color: Theme.faint }
                }

                Item { Layout.fillWidth: true }

                // ── cpu sparkline + ram (first to go when the right side is full) ──
                Pill {
                    id: cpuPill
                    visible: bar.showCpu
                    Label { text: "cpu" }
                    Label { text: Stats.spark(Stats.cpuHist, 100); color: Theme.amber; font.pixelSize: 13 }
                    Label { text: Stats.cpu + "%"; color: Theme.amber }
                    Label { text: "ram"; Layout.leftMargin: 4 }
                    Label { text: Stats.ram + "%"; color: Theme.aqua }
                }

                // ── keyboard layout: click (or SUPER K) switches eu ⇄ de ──
                Pill {
                    id: kbPill
                    visible: root.kb !== ""
                    onClicked: root.switchKb()
                    onScrolled: root.switchKb()
                    Label { text: "kb" }
                    Label { text: root.kb; color: root.kb === "de" ? Theme.gold : Theme.aqua; font.bold: true }
                }

                // ── net · bt: wifi signal and bluetooth; click → control center ──
                Pill {
                    id: netbt
                    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
                    readonly property var wnet: wifi?.networks?.values.find(n => n.connected) ?? null
                    readonly property var bta: Bluetooth.defaultAdapter
                    readonly property int btOn: (bta?.devices?.values ?? []).filter(d => d.connected).length
                    hot: Ui.controlOpen && (Ui.controlTab === "net" || Ui.controlTab === "bt")
                    onClicked: m => Ui.openControl(m.button === Qt.RightButton ? "bt" : "net")
                    Label { text: "net" }
                    Label {
                        text: netbt.wnet ? "▂▄▆█".slice(0, Math.max(1, Math.round(netbt.wnet.signalStrength * 4))).padEnd(4, "▁") : (netbt.wifi && Networking.wifiEnabled ? "····" : "wire")
                        color: Theme.blue
                    }
                    Label { text: "bt"; Layout.leftMargin: 2 }
                    Label {
                        text: !netbt.bta || !netbt.bta.enabled ? "off" : netbt.btOn > 0 ? "●" + netbt.btOn : "○"
                        color: netbt.bta?.enabled ? Theme.cyan : Theme.faint
                    }
                }

                // ── volume: click → audio in the control center, right-click = mute, scroll = ±5% ──
                Pill {
                    id: vol
                    readonly property var sink: Pipewire.defaultAudioSink
                    readonly property real v: sink?.audio?.volume ?? 0
                    readonly property bool muted: sink?.audio?.muted ?? false
                    hot: Ui.controlOpen && Ui.controlTab === "audio"
                    onClicked: m => {
                        if (m.button === Qt.RightButton) { if (sink?.audio) sink.audio.muted = !sink.audio.muted }
                        else Ui.openControl("audio")
                    }
                    onScrolled: w => { if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, v + (w.angleDelta.y > 0 ? 0.05 : -0.05))) }
                    Label { text: "vol" }
                    Label {
                        readonly property int n: Math.min(8, Math.round(vol.v * 8))
                        text: vol.muted ? "muted" : "▮".repeat(n) + "▯".repeat(8 - n)
                        color: vol.muted ? Theme.faint : Theme.rose
                    }
                    Label {
                        visible: UPower.displayDevice.isLaptopBattery
                        readonly property real p: UPower.displayDevice.percentage
                        text: "bat " + Math.round(p > 1 ? p : p * 100) + "%"
                        color: Theme.aqua
                    }
                }

                // ── background apps: count + icons; the pill opens the list, an icon its app ──
                Pill {
                    id: bgPill
                    visible: SystemTray.items.values.length > 0
                    hot: Ui.controlOpen && Ui.controlTab === "apps"
                    onClicked: Ui.openControl("apps")
                    Label { id: bgLbl; text: "bg " + SystemTray.items.values.length; color: Theme.amber }
                    Repeater {
                        model: SystemTray.items
                        IconImage {
                            id: icon
                            required property var modelData
                            visible: bar.showBgIcons
                            source: modelData.icon
                            implicitSize: 16
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: m => {
                                    if (m.button === Qt.RightButton || icon.modelData.onlyMenu) {
                                        const p = icon.mapToItem(null, 0, 0);
                                        icon.modelData.display(bar, p.x, p.y - 8);
                                    } else icon.modelData.activate();
                                }
                            }
                        }
                    }
                }

                // ── power: solid red like λ nook; opens the menu (power buttons), right-click locks ──
                Pill {
                    id: powerPill
                    color: Theme.red
                    border.color: Ui.launcherOpen ? Theme.cyan : Theme.red
                    border.width: Ui.launcherOpen ? 2 : 1
                    onClicked: m => m.button === Qt.RightButton
                        ? Quickshell.execDetached(["loginctl", "lock-session"])
                        : root.openMenu()
                    layer.enabled: true
                    layer.effect: Glow { shadowColor: Theme.red; shadowBlur: 0.8; shadowOpacity: 0.7 }
                    Text { text: "⏻"; color: Theme.onAccent; font.pixelSize: 17; font.bold: true }
                }
            }

            // ── clock: VT323 red, centred on the screen (not between the modules) ──
            Pill {
                id: clockPill
                anchors.centerIn: parent
                Text {
                    id: hhmm
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.red
                    font.family: Theme.pixel
                    font.pixelSize: 28
                    layer.enabled: true
                    layer.effect: Glow { shadowColor: Theme.red }
                }
                Rectangle { implicitWidth: 1; implicitHeight: 18; color: Theme.line }
                Label {
                    // a plain date: "sa 07.11.2026" (weekday in the system language)
                    text: Qt.locale().toString(clock.date, "ddd dd.MM.yyyy").replace(/^(\S+?)\.? /, "$1 ").toLowerCase()
                    color: Theme.ink
                    font.pixelSize: Theme.body
                }
            }
        }
    }
}

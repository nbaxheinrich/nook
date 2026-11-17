// The bar: a 30px strip flush on the bottom edge, its modules as pills inside it.
//   λ nook · workspaces · window title ··························· cpu/ram · ● clock · date ▮▮▮▯ · power
// The clock pill is also the control center's button: sound, net, bluetooth, the tray apps and the
// nook tab sit behind it (ControlCenter.qml).
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
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

    // ── battery, for the clock's overview ──
    readonly property var batt: UPower.displayDevice
    readonly property bool hasBatt: batt.isLaptopBattery
    readonly property real pct: batt.percentage > 1 ? batt.percentage / 100 : batt.percentage
    readonly property bool charging: batt.state === UPowerDeviceState.Charging || batt.state === UPowerDeviceState.FullyCharged
    readonly property color battHue: charging ? Theme.aqua : pct <= 0.15 ? Theme.orange : pct <= 0.3 ? Theme.gold : Theme.ink
    readonly property color kbHue: kb === "de" ? Theme.gold : Theme.aqua

    // Hyprland 0.57 takes Lua dispatchers over IPC
    function dispatch(lua) { Quickshell.execDetached(["hyprctl", "dispatch", lua]) }
    function openMenu() { Ui.toggleLauncher() }

    // one bar module, drawn in the pill style picked in the nook tab (Settings.pillStyle):
    //   box      bg-100 at 88%, 1px line, radius-md        round    the same as a capsule
    //   glass    see-through, no line, a highlight on top  chip     solid dark, a coloured bar on the left
    //   tab      rises from the screen edge, round on top  neon     no fill, a glowing outline tube
    //   bracket  no fill, four [ ] corner marks            under    no fill, a neon underline
    //   text     nothing at all, just the glowing text
    // accent (λ nook, power) is solid red in the filled styles and red in the open ones;
    // hot (its panel is open, hover) turns the outline / marks cyan.
    component Pill: Rectangle {
        id: pill
        default property alias content: row.data
        property bool hot: false
        property bool accent: false
        readonly property string look: Settings.pillStyle
        readonly property bool filled: ["box", "round", "glass", "chip", "tab"].indexOf(look) >= 0
        readonly property bool lit: hot || area.containsMouse
        // an accent pill in an open style (bracket …) fills solid red while its panel is open
        readonly property bool lamp: accent && hot && !filled
        readonly property color edge: lamp ? Theme.red : lit ? Theme.cyan : accent ? Theme.red : Theme.line
        // text on a pill: dark on the solid red ones, red on the open ones
        readonly property color onPill: accent && (filled || lamp) ? Theme.onAccent : accent ? Theme.red : Theme.ink
        signal clicked(var mouse)
        signal scrolled(var wheel)
        // tab: a little taller and sitting on the screen's edge
        Layout.alignment: look === "tab" ? Qt.AlignBottom : Qt.AlignVCenter
        implicitHeight: look === "tab" ? Theme.pill + 3 : Theme.pill
        implicitWidth: row.implicitWidth + (look === "round" || look === "neon" ? 26 : look === "chip" ? 24 : look === "text" ? 8 : 20)
        radius: look === "round" || look === "neon" ? height / 2 : look === "glass" ? 7 : look === "chip" ? 5
              : look === "box" ? Theme.radius : 0
        topLeftRadius: look === "tab" ? 8 : radius
        topRightRadius: look === "tab" ? 8 : radius
        color: lamp ? Theme.red
             : !filled ? Theme.alpha(Theme.red, 0)
             : accent ? (look === "glass" ? Theme.alpha(Theme.red, 0.85) : Theme.red)
             : look === "glass" ? Theme.alpha(Theme.bg300, 0.55)
             : look === "chip" ? Theme.bg000
             : Theme.alpha(Theme.bg100, 0.88)
        border.width: look === "box" || look === "round" ? (hot ? 2 : 1)
                    : (look === "glass" || look === "chip" || look === "tab") && hot ? 1 : 0
        border.color: edge
        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 150 } }
        // glass: a faint highlight along the top
        Rectangle {
            visible: pill.look === "glass"
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 5; rightMargin: 5; topMargin: 1 }
            height: 1
            color: Qt.rgba(1, 1, 1, pill.accent ? 0.25 : 0.10)
        }
        // chip: a coloured bar down the left side
        Rectangle {
            visible: pill.look === "chip" && !pill.accent
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 5; bottomMargin: 5; leftMargin: 4 }
            width: 2; radius: 1
            color: pill.lit ? Theme.cyan : Theme.muted
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        // tab: a lit line along the top
        Rectangle {
            visible: pill.look === "tab" && !pill.accent
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 6; rightMargin: 6 }
            height: 1
            color: pill.lit ? Theme.cyan : Theme.line
        }
        // neon: a glowing outline tube
        Rectangle {
            visible: pill.look === "neon"
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.width: pill.hot ? 2 : 1
            border.color: pill.lit ? Theme.cyan : pill.accent ? Theme.red : Theme.alpha(Theme.cyan, 0.55)
            layer.enabled: pill.look === "neon"
            layer.effect: Glow { shadowColor: pill.lit ? Theme.cyan : pill.accent ? Theme.red : Theme.cyan; shadowBlur: 0.6; shadowOpacity: pill.lit || pill.accent ? 0.8 : 0.4 }
        }
        // declared before the row so mouse areas inside the module (workspace marks, tray icons) sit on top
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: m => pill.clicked(m)
            onWheel: w => pill.scrolled(w)
        }
        // bracket: an L in each corner
        Repeater {
            model: pill.look === "bracket" ? 4 : 0
            Item {
                required property int index
                readonly property bool atRight: index % 2 === 1
                readonly property bool atBottom: index >= 2
                width: 6; height: 6
                x: atRight ? pill.width - width : 0
                y: atBottom ? pill.height - height : 0
                Rectangle { width: parent.width; height: pill.hot ? 2 : 1; y: parent.atBottom ? parent.height - height : 0; color: pill.edge }
                Rectangle { width: pill.hot ? 2 : 1; height: parent.height; x: parent.atRight ? parent.width - width : 0; color: pill.edge }
            }
        }
        // under: a glowing line under the module
        Rectangle {
            visible: pill.look === "under"
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 4; rightMargin: 4 }
            height: pill.hot || pill.accent ? 2 : 1
            radius: 1
            color: pill.lit || pill.accent ? pill.edge : Theme.muted
            Behavior on color { ColorAnimation { duration: 120 } }
            layer.enabled: pill.lit || pill.accent
            layer.effect: Glow { shadowColor: pill.edge }
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
        shadowBlur: 0.8
        shadowOpacity: 0.8
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }
    // neon text: two blurred copies of the text under a crisp one. A single shadow (Glow) is too
    // faint on thin glyphs; stacking the blur makes the halo read at bar size.
    component Neon: Item {
        id: neon
        property alias text: crisp.text
        property alias color: crisp.color
        property alias font: crisp.font
        property real glow: 0.9                    // halo strength, 0–1
        implicitWidth: crisp.implicitWidth
        implicitHeight: crisp.implicitHeight
        Text { id: src; visible: false; layer.enabled: true; text: crisp.text; color: crisp.color; font: crisp.font }
        Repeater {
            model: 2
            MultiEffect {
                source: src
                anchors.fill: src
                autoPaddingEnabled: true
                blurEnabled: true
                blur: 1.0
                blurMax: 10
                opacity: neon.glow
            }
        }
        Text { id: crisp; font.family: Theme.font; font.pixelSize: Theme.small; color: Theme.muted }
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
            // the strip is Theme.bar high; 14 px of room above it lets the pills' glow fade out
            // instead of being cut off at the window's top edge. Only the strip takes clicks.
            implicitHeight: Theme.bar + 14
            mask: Region { item: stripArea }
            // up to the top of the pills, not the strip: Hyprland adds gaps_out (Theme.edge) on top,
            // so windows end Theme.edge above the pills, the same as the gap between two windows.
            // (Hyprland counts a layer's margin into its exclusive zone, so a margin here would
            // have to come off this number.)
            exclusiveZone: Theme.bar - (Theme.bar - Theme.pill) / 2
            color: "transparent"

            // the strip that joins the pills, in the style picked in the nook tab (Settings.stripStyle):
            //   strip     bg-100 at 88%, hairline on top     glow   the same with a cyan neon line on top
            //   baseline  no strip, a neon line on the bottom edge      float  nothing, the pills alone
            readonly property string strip: Settings.stripStyle
            Item {
                id: stripArea
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: Theme.bar
            }
            Rectangle {
                anchors.fill: stripArea
                visible: bar.strip === "strip" || bar.strip === "glow"
                color: Theme.alpha(Theme.bg100, 0.88)
            }
            Rectangle {
                visible: bar.strip !== "float"
                anchors { left: parent.left; right: parent.right }
                y: bar.strip === "baseline" ? parent.height - height : stripArea.y
                height: bar.strip === "strip" ? 1 : 2
                color: bar.strip === "strip" ? Theme.line : Theme.cyan
                opacity: bar.strip === "baseline" ? 0.8 : 1
                layer.enabled: bar.strip !== "strip"
                layer.effect: Glow { shadowColor: Theme.cyan; shadowBlur: 1.0; shadowOpacity: 0.9 }
            }

            // ── where the modules sit (Settings.barLayout): three rows, left / centre / right, and
            //    place() moves each module into its row in order. Modules a layout leaves out wait
            //    in the hidden pool. ──
            readonly property var layouts: ({
                split:  { left: ["start", "ws", "title"], center: [], right: ["cpu", "clock", "power"] },
                center: { left: ["start", "title"], center: ["ws"], right: ["cpu", "clock", "power"] },
                clock:  { left: ["start", "ws", "title"], center: ["clock"], right: ["cpu", "power"] },
                island: { left: [], center: ["start", "ws", "clock", "power"], right: [] },
                corner: { left: ["start", "ws", "clock", "power", "title"], center: [], right: ["cpu"] }
            })
            function place() {
                const pills = { start: startPill, ws: wsPill, title: titlePill, cpu: cpuPill, clock: clockPill, power: powerPill };
                const l = layouts[Settings.barLayout] ?? layouts.split;
                for (const k in pills) pills[k].parent = pool;
                for (const [row, ids] of [[leftRow, l.left], [centerRow, l.center], [rightRow, l.right]])
                    for (const id of ids) pills[id].parent = row;
            }
            Connections { target: Settings; function onBarLayoutChanged() { bar.place() } }
            Component.onCompleted: place()

            // ── overflow: the window tag takes what's left of its side (title first, then the
            //    whole tag, go when there's no room); cpu/ram goes when its side is full.
            //    Modules switched off in the nook tab (Settings) take no room. ──
            function roomIn(row, except) {
                let w = 0;
                for (const p of row.children) if (p !== except && p.visible) w += p.implicitWidth + Theme.gap;
                return w;
            }
            readonly property bool hasCenter: centerRow.implicitWidth > 0
            readonly property real side: hasCenter ? (width - centerRow.implicitWidth) / 2 - 2 * Theme.gap : width / 2 - Theme.gap
            readonly property real tagRoom: (hasCenter ? side : width - roomIn(rightRow) - 2 * Theme.edge - Theme.gap)
                                            - roomIn(leftRow, titlePill)
            readonly property real tagFixed: 20 + 4 * 10 + lb.implicitWidth + appLbl.implicitWidth + dash.implicitWidth + rb.implicitWidth
            readonly property real titleRoom: Math.min(320, tagRoom - tagFixed)
            readonly property bool showCpu: roomIn(rightRow, cpuPill) + cpuPill.implicitWidth <= side

            Item {
                id: modules
                anchors.fill: stripArea
                anchors.leftMargin: Theme.edge
                anchors.rightMargin: Theme.edge
                anchors.topMargin: 1          // below the hairline
                RowLayout { id: leftRow;   anchors { left: parent.left; top: parent.top; bottom: parent.bottom } spacing: Theme.gap }
                RowLayout { id: centerRow; anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom } spacing: Theme.gap }
                RowLayout { id: rightRow;  anchors { right: parent.right; top: parent.top; bottom: parent.bottom } spacing: Theme.gap; layoutDirection: Qt.LeftToRight }
            }

            Item {
                id: pool
                visible: false
                height: Theme.bar

                // ── λ nook: solid red neon, opens the hack menu (right-click: the nook tab) ──
                Pill {
                    id: startPill
                    visible: Settings.shown("bar.start")
                    accent: true
                    hot: Ui.launcherOpen || (Ui.controlOpen && Ui.controlTab === "nook")
                    // right-click: the nook tab, to pick what the bar and the desktop show
                    onClicked: m => m.button === Qt.RightButton ? Ui.openControl("nook") : root.openMenu()
                    layer.enabled: filled || lamp
                    layer.effect: Glow { shadowColor: Theme.red; shadowBlur: 0.8; shadowOpacity: 0.7 }
                    Text { text: "λ"; color: startPill.onPill; font.family: Theme.pixel; font.pixelSize: 20 }
                    Text { text: "nook"; color: startPill.onPill; font.family: Theme.font; font.pixelSize: Theme.body; font.bold: true }
                }

                // ── workspaces 1–9: on this screen = cyan bar, occupied = muted, empty = faint,
                //    urgent = orange. Click brings it to this screen (trades if the other one shows it) ──
                Pill {
                    id: wsPill
                    visible: Settings.shown("bar.workspaces")
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
                                onClicked: root.dispatch(`function() nook_show_workspace(${mark.ws}, "${bar.hmon?.name ?? ""}") end`)
                            }
                        }
                    }
                }

                // ── focused window as a tag ──
                Pill {
                    id: titlePill
                    visible: Settings.shown("bar.title") && (ToplevelManager.activeToplevel?.title ?? "") !== ""
                             && bar.tagRoom >= bar.tagFixed - dash.implicitWidth - 10
                    Label { id: lb; text: "["; color: Theme.faint }
                    Neon {
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

                // ── cpu sparkline + ram (first to go when the right side is full) ──
                Pill {
                    id: cpuPill
                    visible: Settings.shown("bar.cpu") && bar.showCpu
                    Label { text: "cpu" }
                    Neon { text: Stats.spark(Stats.cpuHist, 100); color: Theme.amber; font.pixelSize: 13 }
                    Neon { text: Stats.cpu + "%"; color: Theme.amber }
                    Label { text: "ram"; Layout.leftMargin: 4 }
                    Neon { text: Stats.ram + "%"; color: Theme.aqua }
                }

                // ── clock: the overview and the control center's button. kb dot · VT323 time · date ·
                //    battery bar. Click = control center (SUPER A), on the date = calendar (SUPER C), right-click = next layout (SUPER K),
                //    middle-click = mute, scroll = volume ±5%. Cyan ring + glow while the panel is open. ──
                Pill {
                    id: clockPill
                    visible: Settings.shown("bar.clock")
                    readonly property var sink: Pipewire.defaultAudioSink
                    readonly property bool attention: SystemTray.items.values.some(i => i.status === Status.NeedsAttention)
                    hot: Ui.controlOpen
                    onClicked: m => {
                        if (m.button === Qt.RightButton) root.switchKb();
                        else if (m.button === Qt.MiddleButton) { if (sink?.audio) sink.audio.muted = !sink.audio.muted }
                        else Ui.toggleControl();
                    }
                    onScrolled: w => { if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))) }
                    layer.enabled: hot && filled
                    layer.effect: Glow { shadowColor: Theme.cyan; shadowBlur: 0.9; shadowOpacity: 0.6 }
                    // keyboard layout: a glowing dot, aqua = eu, gold = de; click switches (like SUPER K)
                    Item {
                        visible: root.kb !== ""
                        implicitWidth: 10; implicitHeight: 10
                        Rectangle {
                            id: kbDot
                            anchors.centerIn: parent
                            width: 8; height: 8; radius: 4
                            color: root.kbHue
                            Behavior on color { ColorAnimation { duration: 200 } }
                            layer.enabled: true
                            layer.effect: Glow { shadowColor: kbDot.color; shadowBlur: 1.0; shadowOpacity: 0.9 }
                        }
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.switchKb() }
                    }
                    Neon {
                        id: hhmm
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.red
                        font.family: Theme.pixel
                        font.pixelSize: 22
                        glow: 1.0
                    }
                    Rectangle { implicitWidth: 1; implicitHeight: 14; color: Theme.line }
                    Label {
                        // a plain date: "sa 07.11.2026" (weekday in the system language)
                        text: Qt.locale().toString(clock.date, "ddd dd.MM.yyyy").replace(/^(\S+?)\.? /, "$1 ").toLowerCase()
                        color: dateArea.containsMouse ? Theme.gold : Theme.ink
                        font.pixelSize: Theme.body
                        // a click on the date: the calendar (SUPER C)
                        MouseArea {
                            id: dateArea
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ui.openControl("cal")
                        }
                    }
                    // battery: a thin bar in its state's hue (aqua charging, gold ≤ 30 %, orange ≤ 15 %)
                    Rectangle { visible: root.hasBatt; implicitWidth: 1; implicitHeight: 14; color: Theme.line }
                    RowLayout {
                        visible: root.hasBatt
                        spacing: 6
                        Rectangle {
                            implicitWidth: 46; implicitHeight: 8
                            radius: Theme.radiusSm
                            color: Theme.bg300
                            border.width: 1
                            border.color: Theme.alpha(root.battHue, 0.45)
                            Rectangle {
                                id: battFill
                                x: 1; y: 1
                                height: parent.height - 2
                                width: Math.max(2, (parent.width - 2) * Math.max(0, Math.min(1, root.pct)))
                                radius: 1
                                color: root.battHue
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                layer.enabled: true
                                layer.effect: Glow { shadowColor: battFill.color }
                                // charging: a slow pulse
                                SequentialAnimation on opacity {
                                    running: root.charging && root.pct < 1
                                    loops: Animation.Infinite
                                    onRunningChanged: if (!running) battFill.opacity = 1
                                    NumberAnimation { to: 0.55; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                        Neon { text: Math.round(root.pct * 100) + "%"; color: root.battHue }
                    }
                    // muted, or a tray app asking for you: one small mark, details in the panel
                    Label { visible: clockPill.sink?.audio?.muted ?? false; text: "mute"; color: Theme.faint }
                    Neon { visible: clockPill.attention; text: "●"; color: Theme.orange }
                }

                // ── power: solid red like λ nook; opens the menu (power buttons), right-click locks ──
                Pill {
                    id: powerPill
                    visible: Settings.shown("bar.power")
                    accent: true
                    hot: Ui.launcherOpen
                    onClicked: m => m.button === Qt.RightButton
                        ? Quickshell.execDetached(["loginctl", "lock-session"])
                        : root.openMenu()
                    layer.enabled: filled || lamp
                    layer.effect: Glow { shadowColor: Theme.red; shadowBlur: 0.8; shadowOpacity: 0.7 }
                    Text { text: "⏻"; color: powerPill.onPill; font.pixelSize: 14; font.bold: true }
                }
            }

        }
    }
}

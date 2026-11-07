// The hack menu (SUPER SPACE, or the λ nook button): the design system's Launcher, live.
//
//   ┌ NOOK banner (fire → ice, diagonal) ─────────────────────────────┐
//   │ user@host  kernel  uptime  ● status                              │
//   │ λ ~/ > query▮                                                    │
//   │ APPS // PINNED | MATCH              │ SYS // LIVE  bars, net     │
//   │ [01] ▢ terminal ........... kitty   │ hexdump of what you type   │
//   │ …                                   │ the cat                    │
//   │ [ lock ] [ sleep ] [ reboot ] [ shutdown ]        ↑↓ nav · ⏎ run │
//   └──────────────────────────────────────────────────────────────────┘
//
// Pinned apps come from config/apps.conf (the same list as the Plasma taskbar; apps.conf in
// this folder is a symlink to it). Typing searches every installed .desktop entry.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Scope {
    id: root

    property string query: ""
    property int sel: 0
    property var pinned: []                 // [{label, hue, entry}]
    property string armed: ""               // power button waiting for a second click
    property string kernel: ""
    property string host: ""
    property string uptime: ""

    readonly property int maxRows: 9

    IpcHandler {
        target: "launcher"
        function toggle(): void { Ui.toggleLauncher() }
        function open(): void { Ui.launcherOpen = true }
        function close(): void { Ui.launcherOpen = false }
    }

    Connections {
        target: Ui
        function onLauncherOpenChanged() {
            if (Ui.launcherOpen) {
                root.query = ""; root.sel = 0; root.armed = "";
                info.running = true;
            }
        }
    }

    // ── categories → hue + icon (one hue per category, everywhere) ──
    readonly property var pastelToNeon: ({ pink: "rose", coral: "orange", peach: "red", butter: "gold",
                                           mint: "aqua", teal: "cyan", sky: "blue", lavender: "amber", lilac: "cream" })
    function hueOf(entry) {
        const c = (entry?.categories ?? []).join(";");
        if (/TerminalEmulator|System|Settings|Monitor|HardwareSettings|PackageManager/.test(c)) return "amber";
        if (/Development|IDE|TextEditor|Building|Debugger/.test(c)) return "aqua";
        if (/WebBrowser|Network|FileTransfer|RemoteAccess/.test(c) && !/Chat|InstantMessaging|Email/.test(c)) return "blue";
        if (/Chat|InstantMessaging|Email|IRCClient|Telephony/.test(c)) return "cyan";
        if (/Audio|Video|AudioVideo|Player|Music|Graphics|Photography|Game/.test(c)) return "rose";
        if (/Security|Encryption/.test(c)) return "orange";
        if (/Clock|Calendar|Scheduling|Archiving|Compression/.test(c)) return "red";
        if (/FileManager|FileTools|Office|Viewer|Documentation|WordProcessor|Spreadsheet/.test(c)) return "gold";
        return "amber";
    }
    function iconOf(entry, hue) {
        const c = (entry?.categories ?? []).join(";");
        if (/TerminalEmulator/.test(c)) return "terminal";
        if (/Game/.test(c)) return "game";
        if (/Clock|Calendar/.test(c)) return "clock";
        return ({ amber: "settings", aqua: "code", blue: "globe", cyan: "chat", rose: "music",
                  orange: "shield", red: "clock", gold: "folder", cream: "user" })[hue] ?? "app";
    }
    function binOf(entry) {
        const cmd = (entry?.command ?? []).filter(a => !a.startsWith("%") && !a.startsWith("-") && a !== "env" && !a.includes("="));
        if (!cmd.length) return "";
        if (cmd[0].endsWith("flatpak")) return (cmd.find(a => /^[a-z]+\.[\w.]+$/i.test(a)) ?? "flatpak").split(".").pop().toLowerCase();
        return cmd[0].split("/").pop();
    }

    // ── pinned apps: config/apps.conf ──
    FileView {
        id: appsConf
        path: Quickshell.shellDir + "/apps.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.loadPinned()
    }
    function loadPinned() {
        const out = [];
        for (const raw of appsConf.text().split("\n")) {
            const l = raw.trim();
            if (!l || l.startsWith("#")) continue;
            if (l.startsWith("[")) break;                     // [fill] section: not shown
            const f = l.split("|").map(s => s.trim());
            if (f.length < 3) continue;
            const entry = f[2].split(/\s+/).map(id => DesktopEntries.byId(id)).find(e => e) ?? null;
            if (entry) out.push({ label: f[0], hue: root.pastelToNeon[f[1]] ?? root.hueOf(entry), entry });
        }
        root.pinned = out;
    }
    Connections { target: DesktopEntries.applications; function onValuesChanged() { root.loadPinned() } }

    // ── search: word-prefix beats substring beats keyword ──
    function score(e, q) {
        const name = (e.name ?? "").toLowerCase();
        if (name === q) return 100;
        if (name.startsWith(q)) return 80;
        if (name.split(/[\s\-_.]/).some(w => w.startsWith(q))) return 60;
        if (name.includes(q)) return 40;
        const extra = [(e.genericName ?? ""), (e.keywords ?? []).join(" "), root.binOf(e), e.id ?? ""].join(" ").toLowerCase();
        if (extra.includes(q)) return 20;
        return 0;
    }
    readonly property var results: {
        const q = root.query.trim().toLowerCase();
        if (q === "") return root.pinned;
        const hits = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue;
            const s = root.score(e, q);
            if (s > 0) hits.push({ s, e });
        }
        hits.sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name));
        const seen = new Set();
        return hits.filter(h => !seen.has(h.e.name) && seen.add(h.e.name))
                   .map(h => ({ label: h.e.name.toLowerCase(), hue: root.hueOf(h.e), entry: h.e }));
    }
    onResultsChanged: sel = 0

    function launch(i) {
        const r = root.results[i];
        if (!r) return;
        r.entry.execute();
        Ui.launcherOpen = false;
    }

    // ── power: click once to arm, again to run (lock and sleep run at once) ──
    readonly property var power: [
        { id: "lock",     hue: "orange", cmd: ["loginctl", "lock-session"],  confirm: false },
        { id: "sleep",    hue: "blue", cmd: ["systemctl", "suspend"],       confirm: false },
        { id: "reboot",   hue: "gold", cmd: ["systemctl", "reboot"],        confirm: true },
        { id: "shutdown", hue: "rose", cmd: ["systemctl", "poweroff"],      confirm: true }
    ]
    function pressPower(p) {
        if (p.confirm && root.armed !== p.id) { root.armed = p.id; return; }
        Ui.launcherOpen = false;
        Quickshell.execDetached(p.cmd);
    }

    // header facts, read each time the menu opens
    Process {
        id: info
        command: ["sh", "-c", "uname -r; hostname -s; awk '{s=int($1); printf \"%02d:%02d:%02d\\n\", s/3600, s%3600/60, s%60}' /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n");
                root.kernel = l[0] ?? ""; root.host = l[1] ?? ""; root.uptime = l[2] ?? "";
            }
        }
    }

    // NOOK banner, coloured in 5-column bands that shift two columns per row (fire → ice, diagonal)
    readonly property var banner: [
        "███╗   ██╗ ██████╗  ██████╗ ██╗  ██╗",
        "████╗  ██║██╔═══██╗██╔═══██╗██║ ██╔╝",
        "██╔██╗ ██║██║   ██║██║   ██║█████╔╝ ",
        "██║╚██╗██║██║   ██║██║   ██║██╔═██╗ ",
        "██║ ╚████║╚██████╔╝╚██████╔╝██║  ██╗",
        "╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝"
    ]
    function bannerRow(row) {
        const chars = Array.from(root.banner[row]);
        let html = "", cur = -1;
        for (let col = 0; col < chars.length; col++) {
            const k = Math.floor((col + 2 * row) / 5) % 9;
            if (k !== cur) { if (cur >= 0) html += "</span>"; html += `<span style="color:${Theme.rainbow[k]}">`; cur = k; }
            html += chars[col] === " " ? "&nbsp;" : chars[col];
        }
        return html + "</span>";
    }

    // hexdump of the query (or of "nook" while empty), 8 bytes a line, 3 lines
    function hexdump(s) {
        const bytes = Array.from(unescape(encodeURIComponent(s || "nook <3 λ"))).map(c => c.charCodeAt(0));
        while (bytes.length < 24) bytes.push([0xca, 0xfe, 0x13, 0x37, 0xbe, 0xef, 0x42, 0x00][bytes.length % 8]);
        const lines = [];
        for (let i = 0; i < 24; i += 8)
            lines.push(i.toString(16).padStart(4, "0") + "  " + bytes.slice(i, i + 8).map(b => b.toString(16).padStart(2, "0")).join(" "));
        return lines.join("\n");
    }

    component Mono: Text {
        color: Theme.ink
        font.family: Theme.font
        font.pixelSize: 12
    }
    component Label: Mono {
        color: Theme.faint
        font.pixelSize: Theme.label
        font.bold: true
        font.letterSpacing: 1.2
    }

    HyprlandFocusGrab {
        windows: [panel]
        active: Ui.launcherOpen && panel.visible
        onCleared: Ui.launcherOpen = false
    }

    PanelWindow {
        id: panel
        visible: Ui.launcherOpen
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nook-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        anchors { bottom: true; left: true }
        margins { bottom: Theme.pill + 10 + Theme.gap; left: Theme.pad }
        implicitWidth: 560
        implicitHeight: card.implicitHeight + 40
        color: "transparent"
        onVisibleChanged: if (visible) focusTimer.restart()
        // the layer surface takes keyboard focus a moment after it maps
        Timer { id: focusTimer; interval: 50; onTriggered: input.forceActiveFocus() }

        // the cyan neon halo around the card
        RectangularShadow {
            anchors.fill: card
            radius: Theme.radius
            blur: 24
            spread: 0
            color: Theme.alpha(Theme.cyan, 0.45)
        }

        Rectangle {
            id: card
            x: 10; y: 10
            width: 540
            implicitHeight: body.implicitHeight
            radius: Theme.radius
            color: Theme.bg100
            border.width: 1
            border.color: Theme.cyan
            clip: true

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 0

                // ── header: banner + who ──
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: 16
                    Layout.bottomMargin: 10
                    spacing: 10
                    Column {
                        Repeater {
                            model: root.banner.length
                            Text {
                                required property int index
                                textFormat: Text.RichText
                                text: root.bannerRow(index)
                                font.family: Theme.font
                                font.pixelSize: 10
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 11
                            }
                        }
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true; shadowColor: Theme.red
                            shadowBlur: 0.35; shadowOpacity: 0.3
                            shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                        }
                    }
                    RowLayout {
                        spacing: 12
                        Text {
                            text: (Quickshell.env("USER") ?? "root") + "@" + (root.host || "nook")
                            color: Theme.ink; font.family: Theme.pixel; font.pixelSize: 22
                        }
                        Mono { text: "kernel " + root.kernel.split("-")[0]; color: Theme.muted; font.pixelSize: Theme.small }
                        Mono { text: "up " + root.uptime; color: Theme.muted; font.pixelSize: Theme.small }
                        Mono { text: "● hyprland"; color: Theme.aqua; font.pixelSize: Theme.small }
                    }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.line; opacity: 0.8 }

                // ── prompt ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.margins: 16
                    Layout.topMargin: 12
                    Layout.bottomMargin: 12
                    implicitHeight: 34
                    radius: Theme.radiusSm
                    color: Theme.bg000
                    border.width: 1
                    border.color: Theme.cyan
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 8
                        Mono { text: "λ ~/"; color: Theme.aqua; font.bold: true; font.pixelSize: Theme.body }
                        Mono { text: ">"; color: Theme.faint; font.pixelSize: Theme.body }
                        TextInput {
                            id: input
                            Layout.fillWidth: true
                            text: root.query
                            onTextChanged: root.query = text
                            focus: true
                            color: Theme.ink
                            selectionColor: Theme.cyan
                            selectedTextColor: Theme.onAccent
                            font.family: Theme.font
                            font.pixelSize: Theme.body
                            cursorDelegate: Rectangle {
                                width: 8; height: 16
                                color: Theme.aqua
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite; running: Ui.launcherOpen
                                    PropertyAction { value: 1 } PauseAnimation { duration: 525 }
                                    PropertyAction { value: 0 } PauseAnimation { duration: 525 }
                                }
                            }
                            Connections {
                                target: Ui
                                function onLauncherOpenChanged() { if (Ui.launcherOpen) { input.text = ""; input.forceActiveFocus(); } }
                            }
                            Keys.onPressed: e => {
                                const n = Math.min(root.results.length, root.maxRows);
                                if (e.key === Qt.Key_Escape) { Ui.launcherOpen = false; e.accepted = true; }
                                else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) { root.sel = n ? (root.sel + 1) % n : 0; e.accepted = true; }
                                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { root.sel = n ? (root.sel - 1 + n) % n : 0; e.accepted = true; }
                                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.launch(root.sel); e.accepted = true; }
                                else if ((e.modifiers & Qt.AltModifier) && e.key >= Qt.Key_1 && e.key <= Qt.Key_9) { root.launch(e.key - Qt.Key_1); e.accepted = true; }
                            }
                        }
                    }
                }

                // ── two columns: apps | sys ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 12
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 300
                        Layout.alignment: Qt.AlignTop
                        spacing: 1
                        Label {
                            text: root.query === "" ? "APPS // PINNED" : "APPS // MATCH · " + root.results.length
                            Layout.bottomMargin: 5
                        }
                        Repeater {
                            model: root.results.slice(0, root.maxRows)
                            Rectangle {
                                id: row
                                required property var modelData
                                required property int index
                                readonly property bool selected: index === root.sel
                                readonly property color hue: Theme[modelData.hue] ?? Theme.amber
                                Layout.fillWidth: true
                                implicitHeight: 24
                                radius: Theme.radiusSm
                                color: selected ? Theme.soft(Theme.cyan) : rowArea.containsMouse ? Theme.bg300 : "transparent"
                                border.width: selected ? 1 : 0
                                border.color: Theme.cyan
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                    spacing: 8
                                    Mono {
                                        text: "[" + String(row.index + 1).padStart(2, "0") + "]"
                                        color: row.selected ? Theme.cyan : Theme.faint
                                    }
                                    Image {
                                        source: Icons.url(root.iconOf(row.modelData.entry, row.modelData.hue), row.hue.toString())
                                        sourceSize: Qt.size(16, 16)
                                        Layout.preferredWidth: 16; Layout.preferredHeight: 16
                                        layer.enabled: true
                                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: row.hue; shadowBlur: 0.4; shadowOpacity: 0.6; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
                                    }
                                    Mono { text: row.modelData.label; color: row.hue; Layout.maximumWidth: 150; elide: Text.ElideRight }
                                    Mono { text: ".".repeat(60); color: Theme.faint; Layout.fillWidth: true; clip: true; elide: Text.ElideNone }
                                    Mono { text: root.binOf(row.modelData.entry); color: Theme.muted; Layout.maximumWidth: 90; elide: Text.ElideRight }
                                }
                                MouseArea {
                                    id: rowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: root.sel = row.index
                                    onClicked: root.launch(row.index)
                                }
                            }
                        }
                        Mono {
                            visible: root.results.length === 0
                            text: root.query === "" ? "no pinned apps · edit config/apps.conf" : "λ: command not found: " + root.query
                            color: root.query === "" ? Theme.faint : Theme.orange
                            font.pixelSize: Theme.small
                            Layout.leftMargin: 6
                        }
                        Mono {
                            visible: root.results.length > root.maxRows
                            text: "+" + (root.results.length - root.maxRows) + " more · keep typing"
                            color: Theme.faint; font.pixelSize: Theme.small
                            Layout.leftMargin: 6
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 196
                        Layout.maximumWidth: 196
                        Layout.alignment: Qt.AlignTop
                        spacing: 2
                        Label { text: "SYS // LIVE"; Layout.bottomMargin: 5 }
                        Repeater {
                            model: [
                                { k: "cpu", v: Stats.cpu, hue: Theme.amber, unit: "%" },
                                { k: "ram", v: Stats.ram, hue: Theme.aqua, unit: "%" },
                                { k: "gpu", v: Stats.gpu, hue: Theme.blue, unit: "%" },
                                { k: "tmp", v: Math.min(100, Stats.temp), hue: Theme.red, unit: "°" }
                            ]
                            Text {
                                required property var modelData
                                textFormat: Text.RichText
                                font.family: Theme.font; font.pixelSize: Theme.small
                                text: `<span style="color:${Theme.muted}">${modelData.k} </span>`
                                    + `<span style="color:${Theme.faint}">[</span>`
                                    + `<span style="color:${modelData.hue}">${"█".repeat(Math.round(modelData.v / 10))}</span>`
                                    + `<span style="color:${Theme.faint}">${"░".repeat(10 - Math.round(modelData.v / 10))}]</span>`
                                    + `<span style="color:${Theme.ink}"> ${modelData.v}${modelData.unit}</span>`
                            }
                        }
                        Text {
                            textFormat: Text.RichText
                            font.family: Theme.font; font.pixelSize: Theme.small
                            text: `<span style="color:${Theme.muted}">net </span><span style="color:${Theme.cyan}">↓ ${Stats.rate(Stats.rx)} ↑ ${Stats.rate(Stats.tx)}</span>`
                        }
                        Text {
                            textFormat: Text.RichText
                            font.family: Theme.font; font.pixelSize: Theme.small
                            text: `<span style="color:${Theme.muted}">ws  </span><span style="color:${Theme.gold}">${Hyprland.workspaces.values.length} open · on ${Hyprland.focusedMonitor?.activeWorkspace?.id ?? "?"}</span>`
                        }
                        Mono {
                            Layout.topMargin: 8
                            text: root.hexdump(root.query)
                            color: Theme.faint
                            font.pixelSize: Theme.label
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 14
                        }
                        Mono {
                            Layout.topMargin: 8
                            text: " /\\_/\\  \n( o.o ) \n > ^ <  \n/  λ  \\ "
                            color: Theme.faint
                            font.pixelSize: Theme.label
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 11
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.line; opacity: 0.8 }

                // ── footer: bracketed power buttons ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 16
                    Layout.topMargin: 10
                    Layout.bottomMargin: 12
                    spacing: 6
                    Repeater {
                        model: root.power
                        Rectangle {
                            id: pw
                            required property var modelData
                            readonly property color hue: Theme[modelData.hue]
                            readonly property bool armedHere: root.armed === modelData.id
                            implicitWidth: pwText.implicitWidth + 16
                            implicitHeight: 22
                            radius: Theme.radiusSm
                            color: armedHere ? hue : pwArea.containsMouse ? Theme.soft(hue) : "transparent"
                            border.width: 1
                            border.color: hue
                            Mono {
                                id: pwText
                                anchors.centerIn: parent
                                text: pw.armedHere ? pw.modelData.id + "?" : pw.modelData.id
                                color: pw.armedHere ? Theme.onAccent : pw.hue
                                font.pixelSize: Theme.small
                                font.bold: pw.armedHere
                            }
                            MouseArea { id: pwArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.pressPower(pw.modelData) }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Mono { text: "↑↓ nav · ⏎ run · alt 1‥9 · esc"; color: Theme.faint; font.pixelSize: Theme.label }
                }
            }
        }
    }
}

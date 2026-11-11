// Desktop widgets on the bottom layer, stacked top-right on every screen:
//   A: TIME // LOCAL (NOOK shadow-block digits) · SYS // LIVE (cpu/ram/disk/gpu/vram bars, net) · NOW // PLAYING
//   B: WX // OUTSIDE · SRV // HOMELAB · CAL // NEXT · PROC // TOP   (Feeds.qml, bin/nook-feed)
// Landscape screens get A and B side by side, portrait screens one column.
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Scope {
    id: root
    SystemClock { id: clock; precision: SystemClock.Minutes }

    // 6-row shadow-block font, same style as the NOOK wallpaper banner
    readonly property var glyphs: ({
        "0": [" ██████╗ ", "██╔═████╗", "██║██╔██║", "████╔╝██║", "╚██████╔╝", " ╚═════╝ "],
        "1": [" ██╗", "███║", "╚██║", " ██║", " ██║", " ╚═╝"],
        "2": ["██████╗ ", "╚════██╗", " █████╔╝", "██╔═══╝ ", "███████╗", "╚══════╝"],
        "3": ["██████╗ ", "╚════██╗", " █████╔╝", " ╚═══██╗", "██████╔╝", "╚═════╝ "],
        "4": ["██╗  ██╗", "██║  ██║", "███████║", "╚════██║", "     ██║", "     ╚═╝"],
        "5": ["███████╗", "██╔════╝", "███████╗", "╚════██║", "███████║", "╚══════╝"],
        "6": [" ██████╗ ", "██╔════╝ ", "███████╗ ", "██╔═══██╗", "╚██████╔╝", " ╚═════╝ "],
        "7": ["███████╗", "╚════██║", "    ██╔╝", "   ██╔╝ ", "   ██║  ", "   ╚═╝  "],
        "8": [" █████╗ ", "██╔══██╗", "╚█████╔╝", "██╔══██╗", "╚█████╔╝", " ╚════╝ "],
        "9": [" █████╗ ", "██╔══██╗", "╚██████║", " ╚═══██║", " █████╔╝", " ╚════╝ "],
        ":": ["   ", "██╗", "╚═╝", "██╗", "╚═╝", "   "]
    })
    function blockRows(s) {
        const rows = ["", "", "", "", "", ""];
        for (const ch of s)
            for (let r = 0; r < 6; r++)
                rows[r] += root.glyphs[ch][r] + " ";
        return rows;
    }
    // fire → ice, one hue per row (matches the wallpaper banner)
    readonly property var clockHues: [Theme.rose, Theme.red, Theme.orange, Theme.gold, Theme.aqua, Theme.cyan]

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property int colW: 380

    // what shows: picked in the control center's nook tab (Settings), and only with data to show
    readonly property bool showTime: Settings.shown("widget.time")
    readonly property bool showSys: Settings.shown("widget.sys")
    readonly property bool showMedia: Settings.shown("widget.media") && player !== null
    readonly property bool showWeather: Settings.shown("widget.weather") && Feeds.weather.ok === true
    readonly property bool showSrv: Settings.shown("widget.srv") && (Feeds.srv.hosts ?? []).length > 0
    readonly property bool showCal: Settings.shown("widget.cal")
        && (Feeds.cal.ok === true || (Feeds.cal.error ?? "").indexOf("no [cal]") < 0)
    readonly property bool showProc: Settings.shown("widget.proc")
    readonly property bool colA: showTime || showSys || showMedia
    readonly property bool colB: showWeather || showSrv || showCal || showProc

    // weather hue names from nook-feed → Theme colours
    function hue(n) { return Theme[n] ?? Theme.muted }
    // "today", "tmrw", or the weekday
    function dayLabel(ts) {
        const d = new Date(ts * 1000), n = clock.date;
        const day = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
        const diff = Math.round((day(d) - day(n)) / 86400000);
        return diff === 0 ? "today" : diff === 1 ? "tmrw" : Qt.formatDate(d, "ddd").toLowerCase();
    }
    // ISO 8601 week (Qt's date formats have no week token)
    function isoWeek(date) {
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        return Math.ceil(((d - Date.UTC(d.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }
    function until(sec) {
        const m = Math.max(0, Math.round(sec / 60));
        return m < 60 ? m + "m" : m < 1440 ? Math.floor(m / 60) + "h " + (m % 60) + "m" : Math.floor(m / 1440) + "d";
    }

    // PROC // TOP: first click arms a row, a second click within 3 s sends SIGTERM.
    // The session itself is never offered.
    readonly property var protectedProcs: ["Hyprland", "qs", "quickshell", "Xwayland", "systemd", "pipewire", "wireplumber", "sddm", "kwin_wayland"]
    property string armed: ""
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }
    function tapKill(pid, safe) {
        if (safe) return;
        if (root.armed === pid) {
            Quickshell.execDetached(["kill", pid]);
            root.armed = "";
            disarm.stop();
        } else {
            root.armed = pid;
            disarm.restart();
        }
    }

    // panel: bg-100, radius-md, 1px line, uppercase label header with a status on the right
    component Panel: Rectangle {
        id: panel
        property string title
        property string status
        property color statusHue: Theme.faint
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight + 2 * Theme.pad
        radius: Theme.radius
        color: Theme.alpha(Theme.bg100, 0.82)
        border.width: 1
        border.color: Theme.line
        ColumnLayout {
            id: col
            anchors { fill: parent; margins: Theme.pad }
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Text { text: panel.title; color: Theme.faint; font.family: Theme.font; font.pixelSize: Theme.label; font.bold: true; font.letterSpacing: 1.2 }
                Item { Layout.fillWidth: true }
                Text { text: panel.status; color: panel.statusHue; font.family: Theme.font; font.pixelSize: Theme.label }
            }
            ColumnLayout { id: inner; Layout.fillWidth: true; spacing: 4 }
        }
    }
    component Mono: Text {
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: Theme.small
    }
    component BarRow: RowLayout {
        property string name
        property int pct
        property color hue
        property string extra: ""
        Layout.fillWidth: true
        Mono { text: parent.name.padEnd(5, " "); color: Theme.muted }
        Mono { text: "[" + Stats.bar(parent.pct, 16) + "]"; color: parent.hue }
        Mono { text: String(parent.pct).padStart(3, " ") + "%"; color: Theme.ink }
        Item { Layout.fillWidth: true }
        Mono { text: parent.extra; color: Theme.faint }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            readonly property bool portrait: modelData.height > modelData.width
            screen: modelData
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "nook-widgets"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; right: true }
            margins { top: 48; right: 56 }
            // landscape: two columns (live + info on the right, the new feeds left of it);
            // portrait: one tall column next to the cheatsheet
            visible: root.colA || root.colB
            implicitWidth: portrait || !(root.colA && root.colB) ? root.colW : 2 * root.colW + 16
            implicitHeight: grid.implicitHeight
            color: "transparent"

            GridLayout {
                id: grid
                width: parent.width
                columns: win.portrait ? 1 : 2
                layoutDirection: win.portrait ? Qt.LeftToRight : Qt.RightToLeft
                columnSpacing: 16
                rowSpacing: 16

                // ── column A: clock, system, media ──
                ColumnLayout {
                    visible: root.colA
                    Layout.preferredWidth: root.colW
                    Layout.alignment: Qt.AlignTop
                    spacing: 16

                    Panel {
                        visible: root.showTime
                        title: "TIME // LOCAL"
                        status: "wk" + root.isoWeek(clock.date)
                        statusHue: Theme.red
                        Column {
                            Layout.alignment: Qt.AlignHCenter
                            Repeater {
                                model: root.blockRows(Qt.formatDateTime(clock.date, "HH:mm"))
                                Text {
                                    required property string modelData
                                    required property int index
                                    text: modelData
                                    color: root.clockHues[index]
                                    font.family: Theme.font
                                    font.pixelSize: 13
                                    lineHeight: 1.0
                                }
                            }
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true; shadowColor: Theme.red
                                shadowBlur: 0.8; shadowOpacity: 0.45
                                shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                            }
                        }
                        Mono {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatDateTime(clock.date, "dddd · dd.MM.yyyy").toLowerCase()
                        }
                    }

                    Panel {
                        visible: root.showSys
                        title: "SYS // LIVE"
                        status: Stats.temp > 0 ? Stats.temp + "°c" : ""
                        statusHue: Stats.temp >= 80 ? Theme.orange : Theme.amber
                        BarRow { name: "cpu"; pct: Stats.cpu; hue: Theme.amber }
                        BarRow { name: "ram"; pct: Stats.ram; hue: Theme.aqua }
                        BarRow { name: "disk"; pct: Stats.disk; hue: Theme.gold; extra: "/" }
                        // GPU (NVIDIA, via nvidia-smi): load, VRAM, temperature, watts, fan
                        BarRow {
                            visible: Stats.vramTotal > 0
                            name: "gpu"; pct: Stats.gpu; hue: Theme.blue
                            extra: Stats.gpuTemp + "°c"
                        }
                        BarRow {
                            visible: Stats.vramTotal > 0
                            name: "vram"; pct: Stats.vram; hue: Theme.cyan
                            extra: (Stats.vramUsed / 1024).toFixed(1) + "/" + Math.round(Stats.vramTotal / 1024) + "g"
                        }
                        RowLayout {
                            visible: Stats.vramTotal > 0
                            Layout.fillWidth: true
                            Mono { text: "     " }
                            Mono { text: Stats.spark(Stats.gpuHist, 100); color: Theme.blue; font.pixelSize: 13 }
                            Item { Layout.fillWidth: true }
                            Mono {
                                text: Stats.gpuName + " · " + Stats.gpuWatt + "w · fan " + Stats.gpuFan + "%"
                                color: Stats.gpuTemp >= 80 ? Theme.orange : Theme.faint
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Mono { text: "net  " }
                            Mono { text: Stats.spark(Stats.netHist); color: Theme.blue; font.pixelSize: 13 }
                            Item { Layout.fillWidth: true }
                            Mono { text: "↓" + Stats.rate(Stats.rx) + " ↑" + Stats.rate(Stats.tx); color: Theme.faint }
                        }
                    }

                    Panel {
                        visible: root.showMedia
                        title: "NOW // PLAYING"
                        status: root.player?.isPlaying ? "▶ playing" : "▮▮ paused"
                        statusHue: Theme.rose
                        Mono {
                            Layout.fillWidth: true
                            text: root.player?.trackTitle ?? ""
                            color: Theme.ink; font.pixelSize: Theme.body; font.bold: true
                            elide: Text.ElideRight
                        }
                        Mono {
                            Layout.fillWidth: true
                            text: root.player?.trackArtist ?? ""
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            spacing: 10
                            Repeater {
                                model: [
                                    { t: "[◀◀]", f: () => root.player?.previous() },
                                    { t: root.player?.isPlaying ? "[ ▮▮ ]" : "[ ▶ ]", f: () => root.player?.togglePlaying() },
                                    { t: "[▶▶]", f: () => root.player?.next() }
                                ]
                                Mono {
                                    required property var modelData
                                    text: modelData.t
                                    color: btn.containsMouse ? Theme.rose : Theme.muted
                                    MouseArea { id: btn; anchors.fill: parent; hoverEnabled: true; onClicked: parent.modelData.f() }
                                }
                            }
                        }
                    }
                }

                // ── column B: weather, servers, calendar, processes ──
                ColumnLayout {
                    visible: root.colB
                    Layout.preferredWidth: root.colW
                    Layout.alignment: Qt.AlignTop
                    spacing: 16

                    Panel {
                        visible: root.showWeather
                        title: "WX // OUTSIDE"
                        status: Feeds.weather.place ?? ""
                        statusHue: Theme.gold
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14
                            Text {
                                text: Feeds.weather.sym ?? ""
                                color: root.hue(Feeds.weather.hue)
                                font.pixelSize: 40
                            }
                            ColumnLayout {
                                spacing: 0
                                Text {
                                    text: (Feeds.weather.temp ?? "") + "°"
                                    color: Theme.ink
                                    font { family: Theme.font; pixelSize: 28; bold: true }
                                }
                                Mono { text: Feeds.weather.desc ?? "" }
                            }
                            Item { Layout.fillWidth: true }
                            ColumnLayout {
                                spacing: 2
                                Mono { Layout.alignment: Qt.AlignRight; text: "feels " + Feeds.weather.feels + "°"; color: Theme.faint }
                                Mono { Layout.alignment: Qt.AlignRight; text: "↓" + Feeds.weather.min + "° ↑" + Feeds.weather.max + "°"; color: Theme.faint }
                                Mono { Layout.alignment: Qt.AlignRight; text: Feeds.weather.hum + "% · " + Feeds.weather.wind + "km/h"; color: Theme.faint }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Repeater {
                                model: Feeds.weather.next ?? []
                                ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Mono { Layout.alignment: Qt.AlignHCenter; text: modelData.h + "h"; color: Theme.faint; font.pixelSize: Theme.label }
                                    Text { Layout.alignment: Qt.AlignHCenter; text: modelData.sym; color: root.hue(modelData.hue); font.pixelSize: 18 }
                                    Mono { Layout.alignment: Qt.AlignHCenter; text: modelData.t + "°"; color: Theme.ink }
                                    Mono {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.rain + "%"
                                        color: modelData.rain >= 50 ? Theme.blue : Theme.faint
                                        font.pixelSize: Theme.label
                                    }
                                }
                            }
                        }
                    }

                    Panel {
                        id: srvPanel
                        readonly property var hosts: Feeds.srv.hosts ?? []
                        readonly property int up: hosts.filter(h => h.up).length
                        visible: root.showSrv
                        title: "SRV // HOMELAB"
                        status: up + "/" + hosts.length + " up"
                        statusHue: up === hosts.length ? Theme.aqua : Theme.orange
                        Repeater {
                            model: srvPanel.hosts
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Mono { text: "●"; color: modelData.up ? Theme.aqua : Theme.orange }
                                Mono { text: modelData.name.padEnd(14, " "); color: Theme.ink }
                                Mono {
                                    text: Stats.spark((Feeds.srvHist[modelData.name] ?? []).map(v => Math.max(0, v)).slice(-16))
                                    color: modelData.up ? Theme.blue : Theme.orange
                                    font.pixelSize: 13
                                }
                                Item { Layout.fillWidth: true }
                                Mono {
                                    text: modelData.up ? (modelData.ms < 10 ? modelData.ms.toFixed(1) : Math.round(modelData.ms)) + "ms" : "down"
                                    color: modelData.up ? (modelData.ms >= 100 ? Theme.gold : Theme.muted) : Theme.orange
                                }
                            }
                        }
                    }

                    Panel {
                        id: calPanel
                        readonly property var c: Feeds.cal
                        readonly property var events: c.events ?? []
                        readonly property real now: clock.date.getTime() / 1000
                        readonly property var first: events.length ? events[0] : null
                        visible: root.showCal
                        title: "CAL // NEXT"
                        status: !first ? "" : first.allday ? root.dayLabel(first.start) + " · all day"
                            : first.start <= now ? "now · until " + Qt.formatTime(new Date(first.end * 1000), "HH:mm")
                            : "in " + root.until(first.start - now)
                        statusHue: first && first.start <= now ? Theme.aqua : Theme.red
                        Mono {
                            visible: calPanel.c.ok !== true
                            Layout.fillWidth: true
                            text: "[!!] " + (calPanel.c.error ?? "")
                            color: Theme.orange
                            wrapMode: Text.Wrap
                        }
                        Mono {
                            visible: calPanel.c.ok === true && calPanel.events.length === 0
                            text: "nothing coming up"
                            color: Theme.faint
                        }
                        Repeater {
                            model: calPanel.events.slice(0, 6)
                            RowLayout {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Mono {
                                    text: root.dayLabel(modelData.start).padEnd(6, " ")
                                        + (modelData.allday ? "  ···" : Qt.formatTime(new Date(modelData.start * 1000), "HH:mm"))
                                    color: index === 0 ? Theme.red : Theme.muted
                                }
                                Mono {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: Theme.ink
                                    elide: Text.ElideRight
                                }
                                Mono {
                                    Layout.maximumWidth: 90
                                    text: modelData.where
                                    color: Theme.faint
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Panel {
                        visible: root.showProc
                        title: "PROC // TOP"
                        status: root.armed ? "click again = kill " + root.armed : "click = kill"
                        statusHue: root.armed ? Theme.orange : Theme.faint
                        RowLayout {
                            Layout.fillWidth: true
                            Mono { text: "    pid"; color: Theme.faint; font.pixelSize: Theme.label }
                            Mono { Layout.fillWidth: true; text: "name"; color: Theme.faint; font.pixelSize: Theme.label }
                            Mono { text: "cpu            ram"; color: Theme.faint; font.pixelSize: Theme.label }
                        }
                        Repeater {
                            model: Feeds.procs
                            Item {
                                id: prow
                                required property var modelData
                                readonly property bool safe: root.protectedProcs.indexOf(modelData.name) >= 0
                                readonly property bool armed: root.armed === modelData.pid
                                Layout.fillWidth: true
                                implicitHeight: cells.implicitHeight
                                RowLayout {
                                  id: cells
                                  anchors.fill: parent
                                  Mono { text: prow.modelData.pid.padStart(7, " "); color: Theme.faint }
                                  Mono {
                                      Layout.fillWidth: true
                                      text: prow.armed ? "[kill " + prow.modelData.name + "?]" : prow.modelData.name
                                      color: prow.armed ? Theme.orange : hover.containsMouse && !prow.safe ? Theme.rose : Theme.ink
                                      elide: Text.ElideRight
                                  }
                                  Mono {
                                      text: "[" + Stats.bar(Math.min(100, prow.modelData.cpu), 8) + "]"
                                      color: prow.modelData.cpu >= 80 ? Theme.orange : Theme.amber
                                  }
                                  Mono { text: (Math.round(prow.modelData.cpu) + "%").padStart(5, " "); color: Theme.ink }
                                  Mono { text: (prow.modelData.mem.toFixed(1) + "%").padStart(6, " "); color: Theme.faint }
                                }
                                MouseArea {
                                    id: hover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: prow.safe ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: root.tapKill(prow.modelData.pid, prow.safe)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

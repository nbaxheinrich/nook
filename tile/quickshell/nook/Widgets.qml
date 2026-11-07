// Desktop widgets on the bottom layer, stacked top-right on every screen:
//   TIME // LOCAL (block digits, one hue per row) · SYS // LIVE (bars + net sparkline) · NOW // PLAYING
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Scope {
    id: root
    SystemClock { id: clock; precision: SystemClock.Minutes }

    // 3×5 block font, ██ per pixel
    readonly property var glyphs: ({
        "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
        "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
        "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
        "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
        "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
        ":": ["0", "1", "0", "1", "0"]
    })
    function blockRows(s) {
        const rows = ["", "", "", "", ""];
        for (const ch of s)
            for (let r = 0; r < 5; r++)
                rows[r] += root.glyphs[ch][r].replace(/1/g, "██").replace(/0/g, "  ") + " ";
        return rows;
    }
    readonly property var clockHues: [Theme.rose, Theme.orange, Theme.gold, Theme.aqua, Theme.cyan]

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

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
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "nook-widgets"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; right: true }
            margins { top: 48; right: 56 }
            implicitWidth: 380
            implicitHeight: stack.implicitHeight
            color: "transparent"

            ColumnLayout {
                id: stack
                width: parent.width
                spacing: 16

                Panel {
                    title: "TIME // LOCAL"
                    status: "wk" + Qt.formatDateTime(clock.date, "ww")
                    statusHue: Theme.orange
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
                                font.pixelSize: 15
                                lineHeight: 0.9
                            }
                        }
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true; shadowColor: Theme.orange
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
                    title: "SYS // LIVE"
                    status: Stats.temp > 0 ? Stats.temp + "°c" : ""
                    statusHue: Stats.temp >= 80 ? Theme.red : Theme.amber
                    BarRow { name: "cpu"; pct: Stats.cpu; hue: Theme.amber }
                    BarRow { name: "ram"; pct: Stats.ram; hue: Theme.aqua }
                    BarRow { name: "disk"; pct: Stats.disk; hue: Theme.gold; extra: "/" }
                    RowLayout {
                        Layout.fillWidth: true
                        Mono { text: "net  " }
                        Mono { text: Stats.spark(Stats.netHist); color: Theme.blue; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                        Mono { text: "↓" + Stats.rate(Stats.rx) + " ↑" + Stats.rate(Stats.tx); color: Theme.faint }
                    }
                }

                Panel {
                    visible: root.player !== null
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
        }
    }
}

// TIME // LOCAL: the Nook clock.
//   on the desktop: a big clock drawn with # in monospace, one pastel per digit, with the date and ISO week
//   in a panel:     a big rainbow HH:MM with day/date and week/seconds stacked beside it; click for a calendar
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar as PlasmaCalendar

PlasmoidItem {
    id: root
    readonly property var hues: ["#f5a8c9", "#f7a59a", "#f9c49a", "#f2e29b", "#a6e6bf", "#94dcd6", "#a3cdf5", "#c4b2f5", "#e2b5f0"]
    readonly property string mono: Kirigami.Theme.fixedWidthFont.family
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                                    || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    property date now: new Date()
    // digits drawn with # on a 5x5 grid, so the whole clock is one block of monospace text
    readonly property var glyphs: ({
        "0": ["#####", "#   #", "#   #", "#   #", "#####"],
        "1": ["  #  ", " ##  ", "  #  ", "  #  ", " ### "],
        "2": ["#####", "    #", "#####", "#    ", "#####"],
        "3": ["#####", "    #", " ####", "    #", "#####"],
        "4": ["#   #", "#   #", "#####", "    #", "    #"],
        "5": ["#####", "#    ", "#####", "    #", "#####"],
        "6": ["#####", "#    ", "#####", "#   #", "#####"],
        "7": ["#####", "    #", "   # ", "  #  ", "  #  "],
        "8": ["#####", "#   #", "#####", "#   #", "#####"],
        "9": ["#####", "#   #", "#####", "    #", "#####"],
        ":": ["   ", " # ", "   ", " # ", "   "]
    })
    // one StyledText block: row by row, each character in its own pastel, spaces kept as &nbsp;
    function hashArt(text, colorOf) {
        const rows = []
        for (let r = 0; r < 5; r++) {
            rows.push(text.split("").map((c, i) =>
                span(glyphs[c][r].replace(/ /g, "&nbsp;"), colorOf(c, i))).join("&nbsp;"))
        }
        return rows.join("<br>")
    }

    preferredRepresentation: inPanel ? compactRepresentation : fullRepresentation
    Plasmoid.backgroundHints: inPanel ? PlasmaCore.Types.NoBackground
                                      : PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    toolTipMainText: Qt.formatDate(now, "dddd, d MMMM yyyy")
    toolTipSubText: "week " + isoWeek(now)

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    function pad(n) { return String(n).padStart(2, "0") }
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        const day = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - day)
        return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7)
    }
    function span(text, color) { return "<font color='" + color + "'>" + text + "</font>" }
    // HH:MM with the digits walking through the rainbow
    function rainbowTime() {
        const t = pad(now.getHours()) + pad(now.getMinutes())
        return span(t[0], hues[0]) + span(t[1], hues[1])
            + span(":", now.getSeconds() % 2 ? "#7d6d62" : "#bfae9f")
            + span(t[2], hues[4]) + span(t[3], hues[5])
    }

    // ── panel: big rainbow 21:09 as tall as the app icons, with day/date over week/seconds beside it ──
    compactRepresentation: MouseArea {
        id: compact
        readonly property real big: Math.max(14, height * 0.62)
        readonly property real small: Math.max(9, height * 0.27)
        Layout.minimumWidth: line.implicitWidth + 20
        Layout.preferredWidth: line.implicitWidth + 20
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        Rectangle {  // hover tile + bar, like the task buttons
            anchors.fill: parent; anchors.margins: 2
            radius: 3
            color: "#372f2a"
            opacity: compact.containsMouse || root.expanded ? 1 : 0
        }
        Rectangle {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 2 }
            width: root.expanded ? 28 : 0; height: 3
            color: "#c4b2f5"
        }
        Row {
            id: line
            anchors.centerIn: parent
            spacing: compact.small * 0.7
            Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.StyledText
                font { family: root.mono; pixelSize: compact.big; bold: true }
                text: root.rainbowTime()
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    textFormat: Text.StyledText
                    font { family: root.mono; pixelSize: compact.small; bold: true }
                    lineHeight: 0.9
                    text: root.span(Qt.formatDate(root.now, "ddd").toLowerCase(), "#e2b5f0") + " "
                        + root.span(Qt.formatDate(root.now, "dd.MM"), "#f9c49a")
                }
                Text {
                    textFormat: Text.StyledText
                    font { family: root.mono; pixelSize: compact.small; bold: true }
                    lineHeight: 0.9
                    text: root.span("wk" + root.pad(root.isoWeek(root.now)), "#7d6d62") + " "
                        + root.span(":" + root.pad(root.now.getSeconds()), "#c4b2f5")
                }
            }
        }
    }

    // ── desktop card / panel popup ──
    fullRepresentation: ColumnLayout {
        id: col
        spacing: 0
        Layout.preferredWidth: root.inPanel ? Kirigami.Units.gridUnit * 22 : -1
        Layout.preferredHeight: root.inPanel ? Kirigami.Units.gridUnit * 26 : -1
        readonly property real big: root.inPanel ? Kirigami.Units.gridUnit * 4.5
                                                 : Math.min(width / 4.2, (height - 60) * 0.95)

        RowLayout {
            Layout.fillWidth: true
            Text { text: "TIME // LOCAL"; color: "#f9c49a"; font { family: root.mono; pixelSize: Math.max(10, col.big * 0.09); bold: true; letterSpacing: 1.4 } }
            Item { Layout.fillWidth: true }
            Text { text: Qt.formatDate(root.now, "dddd").toLowerCase(); color: "#7d6d62"; font { family: root.mono; pixelSize: Math.max(10, col.big * 0.09) } }
        }
        Item { Layout.fillHeight: true; Layout.minimumHeight: 6 }
        FontMetrics { id: fm; font { family: root.mono; pixelSize: 100; bold: true } }
        Row {
            id: art
            Layout.alignment: Qt.AlignHCenter
            spacing: fs * fm.averageCharacterWidth / 100 * 2
            // HH:MM is 27 columns; the seconds beside it at half size add about 7 more
            readonly property real fs: root.inPanel ? Kirigami.Units.gridUnit * 0.8
                : Math.min(col.width / (36 * fm.averageCharacterWidth / 100), (col.height - 100) / 5)
            Text {
                textFormat: Text.StyledText
                font { family: root.mono; pixelSize: art.fs; bold: true }
                lineHeightMode: Text.FixedHeight
                lineHeight: art.fs
                text: root.hashArt(root.pad(root.now.getHours()) + ":" + root.pad(root.now.getMinutes()),
                                   (c, i) => c === ":" ? (root.now.getSeconds() % 2 ? "#7d6d62" : "#bfae9f")
                                                       : root.hues[i * 2 % 9])
            }
            Text {
                y: parent.height - height
                textFormat: Text.StyledText
                font { family: root.mono; pixelSize: art.fs * 0.5; bold: true }
                lineHeightMode: Text.FixedHeight
                lineHeight: art.fs * 0.5
                text: root.hashArt(root.pad(root.now.getSeconds()), () => "#c4b2f5")
            }
        }
        Item { Layout.fillHeight: true; Layout.minimumHeight: 4 }
        Text {
            Layout.alignment: Qt.AlignHCenter
            textFormat: Text.StyledText
            text: root.span(Qt.formatDate(root.now, "dd.MM.yyyy"), "#bfae9f")
                + root.span("  ·  ", "#7d6d62") + root.span("week " + root.isoWeek(root.now), "#f9c49a")
                + root.span("  ·  ", "#7d6d62") + root.span("day " + Qt.formatDate(root.now, "d") + "/"
                    + new Date(root.now.getFullYear(), root.now.getMonth() + 1, 0).getDate(), "#bfae9f")
            font { family: root.mono; pixelSize: Math.max(11, col.big * 0.12) }
        }
        PlasmaCalendar.MonthView {
            visible: root.inPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.minimumHeight: visible ? Kirigami.Units.gridUnit * 14 : 0
            today: root.now
            showWeekNumbers: true
        }
    }
}

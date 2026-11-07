// Nook logout screen (ksmserver-logout-greeter): the login screen's dot grid, # clock and
// rainbow banner around a SESSION // POWER card of [ sleep ] [ restart ] [ shut down ] … tiles.
//   keys: ←→ / tab pick an action · ⏎ or space runs it · esc cancels
// The signals and the context properties (sdtype, maysd, spdMethods, canLogout, …) are the
// greeter's API, the same ones Breeze's Logout.qml uses; keep them when changing this file.
import QtQuick
import QtQuick.Controls as QQC2

import org.kde.coreaddons as KCoreAddons
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.sessions

import "timer.js" as AutoTriggerTimer

Item {
    id: root
    height: screenGeometry.height
    width: screenGeometry.width

    signal logoutRequested()
    signal haltRequested()
    signal haltUpdateRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal rebootUpdateRequested()
    signal cancelRequested()
    signal lockScreenRequested()
    signal cancelSoftwareUpdateRequested()

    readonly property color bg000: "#1a1614"
    readonly property color bg100: "#221d1a"
    readonly property color bg300: "#372f2a"
    readonly property color line: "#4a3f38"
    readonly property color ink: "#f6ece4"
    readonly property color muted: "#bfae9f"
    readonly property color faint: "#7d6d62"
    readonly property var hues: ["#f5a8c9", "#f7a59a", "#f9c49a", "#f2e29b", "#a6e6bf", "#94dcd6", "#a3cdf5", "#c4b2f5", "#e2b5f0"]
    readonly property color coral: hues[1]
    readonly property color butter: hues[3]
    readonly property color mint: hues[4]
    readonly property color sky: hues[6]
    readonly property color lavender: hues[7]
    readonly property color lilac: hues[8]

    readonly property string mono: Kirigami.Theme.fixedWidthFont.family
    readonly property real s: Math.min(width, height) / 1440   // drawn at 1440p, like the wallpaper
    readonly property real fs: Math.max(12, 19 * s)
    property date now: new Date()

    // ── what the buttons do; a request for one action (sdtype) counts down to it ──
    readonly property bool showAllOptions: sdtype === ShutdownType.ShutdownTypeDefault
    property real timeout: 30
    property real remainingTime: root.timeout
    property var currentAction: {
        switch (sdtype) {
        case ShutdownType.ShutdownTypeReboot:
            return () => softwareUpdatePending ? rebootUpdateRequested() : rebootRequested();
        case ShutdownType.ShutdownTypeHalt:
            return () => softwareUpdatePending ? haltUpdateRequested() : haltRequested();
        default:
            return () => logoutRequested();
        }
    }
    onRemainingTimeChanged: if (remainingTime <= 0) (currentAction)()

    readonly property bool rebootShown: maysd && (sdtype === ShutdownType.ShutdownTypeReboot || showAllOptions)
    readonly property bool haltShown: maysd && (sdtype === ShutdownType.ShutdownTypeHalt || showAllOptions)
    readonly property var actions: [
        { label: "sleep", hue: sky, shown: spdMethods.SuspendState && showAllOptions,
          run: () => root.suspendRequested(2) },
        { label: "hibernate", hue: lilac, shown: spdMethods.HibernateState && showAllOptions,
          run: () => root.suspendRequested(4) },
        { label: softwareUpdatePending ? "update + restart" : "restart", hue: butter, shown: rebootShown,
          kind: ShutdownType.ShutdownTypeReboot,
          run: () => softwareUpdatePending ? root.rebootUpdateRequested() : root.rebootRequested() },
        { label: "restart", hue: butter, shown: rebootShown && softwareUpdatePending,
          run: () => root.rebootRequested() },
        { label: softwareUpdatePending ? "update + shut down" : "shut down", hue: coral, shown: haltShown,
          kind: ShutdownType.ShutdownTypeHalt,
          run: () => softwareUpdatePending ? root.haltUpdateRequested() : root.haltRequested() },
        { label: "shut down", hue: coral, shown: haltShown && softwareUpdatePending,
          run: () => root.haltRequested() },
        { label: "log out", hue: mint, shown: canLogout && (sdtype === ShutdownType.ShutdownTypeNone || showAllOptions),
          kind: ShutdownType.ShutdownTypeNone,
          run: () => root.logoutRequested() },
        { label: "cancel", hue: muted, shown: true, run: () => root.cancelRequested() }
    ].filter(a => a.shown)

    // the action asked for, else shut down (as Breeze does), else the first one
    function initialIndex() {
        const want = showAllOptions ? ShutdownType.ShutdownTypeHalt : sdtype
        const i = actions.findIndex(a => a.kind === want)
        return i >= 0 ? i : 0
    }
    property int current: initialIndex()
    function move(step) {
        AutoTriggerTimer.cancelAutoTrigger()
        current = (current + step + actions.length) % actions.length
    }

    KCoreAddons.KUser { id: kuser }

    // for the "other users are logged in" warning
    SessionsModel {
        id: otherSessionsModel
        includeUnusedSessions: false
        includeOwnSession: false
    }

    QQC2.Action {
        onTriggered: root.cancelRequested()
        shortcut: "Escape"
    }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Timer {
        id: countDownTimer
        running: !root.showAllOptions
        repeat: true
        interval: 1000
        onTriggered: root.remainingTime--
        Component.onCompleted: AutoTriggerTimer.addCancelAutoTriggerCallback(() => countDownTimer.running = false)
    }

    function pad(n) { return String(n).padStart(2, "0") }
    function span(text, c) { return "<font color='" + c + "'>" + text + "</font>" }

    // ── # clock, the same glyphs as the desktop's TIME // LOCAL and the login screen ──
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
    function hashArt(text, colorOf) {
        const rows = []
        for (let r = 0; r < 5; r++)
            rows.push(text.split("").map((c, i) => span(glyphs[c][r].replace(/ /g, "&nbsp;"), colorOf(c, i))).join("&nbsp;"))
        return rows.join("<br>")
    }

    // ── rainbow banner, lolcat-style: a diagonal sweep through the nine hues ──
    readonly property var banner: [
        "███╗   ██╗ ██████╗  ██████╗ ██╗  ██╗",
        "████╗  ██║██╔═══██╗██╔═══██╗██║ ██╔╝",
        "██╔██╗ ██║██║   ██║██║   ██║█████╔╝ ",
        "██║╚██╗██║██║   ██║██║   ██║██╔═██╗ ",
        "██║ ╚████║╚██████╔╝╚██████╔╝██║  ██╗",
        "╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝"]
    function mix(a, b, t) {
        const ca = Qt.color(a), cb = Qt.color(b)
        return Qt.rgba(ca.r + (cb.r - ca.r) * t, ca.g + (cb.g - ca.g) * t, ca.b + (cb.b - ca.b) * t, 1)
    }
    function rainbow() {
        const cols = banner[0].length, span8 = cols + banner.length * 4
        return banner.map((rowText, r) => rowText.split("").map((ch, c) => {
            if (ch === " ") return "&nbsp;"
            const t = (c + r * 4) / span8 * 8, i = Math.min(7, Math.floor(t))
            return span(ch, mix(hues[i], hues[i + 1], t - i))
        }).join("")).join("<br>")
    }

    function countdownText() {
        const n = root.remainingTime + "s"
        switch (sdtype) {
        case ShutdownType.ShutdownTypeReboot: return (softwareUpdatePending ? "updating + restarting in " : "restarting in ") + n
        case ShutdownType.ShutdownTypeNone: return "logging out in " + n
        default: return (softwareUpdatePending ? "updating + shutting down in " : "shutting down in ") + n
        }
    }
    // notes shown above the buttons, as [!!] lines
    readonly property var notes: {
        const n = []
        if (otherSessionsModel.count > 0 && (sdtype !== ShutdownType.ShutdownTypeNone || showAllOptions))
            n.push(otherSessionsModel.count + " other user" + (otherSessionsModel.count > 1 ? "s are" : " is")
                   + " logged in and may lose work")
        if (rebootToFirmwareSetup) n.push("restart goes to the firmware setup")
        if (rebootToBootLoaderMenu) n.push("restart goes to the boot loader menu")
        if (rebootToBootLoaderEntry != "") n.push("restart boots " + rebootToBootLoaderEntry)
        return n
    }

    // ── ground: the desktop dimmed, then the dot grid ──
    Rectangle { anchors.fill: parent; color: root.bg000; opacity: 0.94 }
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const g = getContext("2d"), p = 24 * root.s, r = Math.max(1, 1.3 * root.s)
            g.reset()
            g.fillStyle = root.line
            for (let y = p / 2; y < height; y += p)
                for (let x = p / 2; x < width; x += p) g.fillRect(x - r / 2, y - r / 2, r, r)
        }
    }
    MouseArea { anchors.fill: parent; onClicked: root.cancelRequested() }

    // ── top bar: λ user on the left, date on the right ──
    Text {
        x: 48 * root.s; y: 40 * root.s
        textFormat: Text.StyledText
        font { family: root.mono; pixelSize: root.fs; bold: true }
        text: root.span("λ ", root.mint) + root.span(kuser.loginName, root.ink) + root.span("  ~/" + kuser.host, root.faint)
    }
    Text {
        anchors { right: parent.right; rightMargin: 48 * root.s }
        y: 40 * root.s
        textFormat: Text.StyledText
        font { family: root.mono; pixelSize: root.fs }
        text: root.span(Qt.formatDate(root.now, "ddd").toLowerCase() + " ", root.lilac)
            + root.span(Qt.formatDate(root.now, "dd.MM.yyyy"), root.hues[2])
    }

    // ── centre: clock, then the power card ──
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: (root.height - height) * 0.36
        spacing: 56 * root.s

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property real px: Math.max(10, 26 * root.s)
            textFormat: Text.StyledText
            font { family: root.mono; pixelSize: px; bold: true }
            lineHeightMode: Text.FixedHeight
            lineHeight: px
            text: root.hashArt(root.pad(root.now.getHours()) + ":" + root.pad(root.now.getMinutes()),
                               (c, i) => c === ":" ? (root.now.getSeconds() % 2 ? root.faint : root.muted) : root.hues[i * 2 % 9])
        }

        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(root.width - 64 * root.s, Math.max(560, 1040 * root.s) + 2 * pad)
            height: body.height + 2 * pad
            readonly property real pad: 28 * root.s
            color: root.bg100
            radius: 6 * root.s
            border { width: 1; color: root.lavender }

            // swallow clicks, so only the dimmed ground around the card cancels
            MouseArea { anchors.fill: parent }

            Column {
                id: body
                x: card.pad; y: card.pad
                width: card.width - 2 * card.pad
                spacing: 14 * root.s

                Item {
                    width: parent.width; height: head.height
                    Text {
                        id: head
                        text: "SESSION // POWER"
                        color: root.lavender
                        font { family: root.mono; pixelSize: root.fs * 0.8; bold: true; letterSpacing: 1.6 }
                    }
                    Text {
                        anchors.right: parent.right
                        text: "[" + root.pad(root.actions.length) + "]"
                        color: root.faint
                        font { family: root.mono; pixelSize: root.fs * 0.8 }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: root.line }

                Repeater {
                    model: root.notes
                    Text {
                        required property string modelData
                        width: body.width
                        wrapMode: Text.WordWrap
                        text: "[!!] " + modelData
                        color: root.butter
                        font { family: root.mono; pixelSize: root.fs * 0.8 }
                    }
                }

                Flow {
                    id: buttons
                    width: parent.width
                    spacing: 8 * root.s
                    focus: true
                    Keys.onLeftPressed: root.move(-1)
                    Keys.onRightPressed: root.move(1)
                    Keys.onTabPressed: root.move(1)
                    Keys.onBacktabPressed: root.move(-1)
                    Keys.onReturnPressed: root.actions[root.current].run()
                    Keys.onEnterPressed: root.actions[root.current].run()
                    Keys.onSpacePressed: root.actions[root.current].run()
                    Keys.onPressed: AutoTriggerTimer.cancelAutoTrigger()

                    Repeater {
                        model: root.actions
                        Power {
                            required property var modelData
                            required property int index
                            label: modelData.label
                            hot: modelData.hue
                            selected: root.current === index
                            onHovered: root.current = index
                            onHit: modelData.run()
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.line }

                Text {
                    text: countDownTimer.running ? root.countdownText() : "⏎ run · ←→ pick · esc cancel"
                    color: countDownTimer.running ? root.butter : root.faint
                    font { family: root.mono; pixelSize: root.fs * 0.8 }
                }
            }
        }
    }

    // ── banner along the bottom ──
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 56 * root.s }
        readonly property real px: Math.min(30 * root.s, root.width * 0.8 / (root.banner[0].length * 0.6))
        textFormat: Text.StyledText
        font { family: root.mono; pixelSize: px }
        lineHeightMode: Text.FixedHeight
        lineHeight: px * 1.18
        text: root.rainbow()
    }

    // [ restart ]: a tile with the taskbar's bar under it; lit while picked or hovered
    component Power: Item {
        id: btn
        property string label
        property color hot: root.lavender
        property bool selected
        signal hit()
        signal hovered()
        width: txt.implicitWidth + 24 * root.s
        height: txt.implicitHeight + 16 * root.s
        Rectangle { anchors.fill: parent; radius: 3 * root.s; color: root.bg300; visible: btn.selected }
        Rectangle {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: btn.selected ? parent.width * 0.6 : parent.width * 0.15
            height: 2
            color: btn.selected ? btn.hot : root.line
            Behavior on width { NumberAnimation { duration: 120 } }
        }
        Text {
            id: txt
            anchors.centerIn: parent
            text: (btn.selected ? "▶ " : "[ ") + btn.label + (btn.selected ? "  " : " ]")
            color: btn.selected ? btn.hot : root.muted
            font { family: root.mono; pixelSize: root.fs; bold: btn.selected }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // on a move, not on enter: the pointer may already rest where a tile appears
            onPositionChanged: if (!btn.selected) btn.hovered()
            onClicked: btn.hit()
        }
    }
}

// Nook login screen (SDDM, Qt 6): the wallpaper's dot grid, the desktop's # clock, a
// terminal-style login card and the rainbow NOOK banner. Plain QtQuick only, so it runs on
// any SDDM greeter without Plasma's QML modules.
//   keys: tab / shift+tab between user, password and session · ←→ change user or session · ⏎ log in
import QtQuick

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: bg000

    // palette from theme.conf: "ramen" (Ramen Sign: neutral greys + neons, cyan focus; the default)
    // or "pastel" (the cocoa Plasma rice). Role names stay the pastel ones; in Ramen they map to
    // coral → red, butter → gold, mint → aqua, lavender → cyan (focus), lilac → cream (session).
    readonly property bool ramen: (config.palette || "ramen") !== "pastel"
    readonly property color bg000: ramen ? "#060606" : "#1a1614"
    readonly property color bg100: ramen ? "#0d0d0d" : "#221d1a"
    readonly property color bg300: ramen ? "#202020" : "#372f2a"
    readonly property color line: ramen ? "#343434" : "#4a3f38"
    readonly property color ink: ramen ? "#f2f2f2" : "#f6ece4"
    readonly property color muted: ramen ? "#a8a8a8" : "#bfae9f"
    readonly property color faint: ramen ? "#626262" : "#7d6d62"
    readonly property var hues: ramen
        ? ["#ff7a5c", "#ff6458", "#ff9a3c", "#ffc247", "#4fd8cf", "#45c8e6", "#62a5ff", "#ffb14a", "#ffd98f"]
        : ["#f5a8c9", "#f7a59a", "#f9c49a", "#f2e29b", "#a6e6bf", "#94dcd6", "#a3cdf5", "#c4b2f5", "#e2b5f0"]
    readonly property color coral: hues[1]
    readonly property color butter: hues[3]
    readonly property color mint: hues[4]
    readonly property color lavender: ramen ? hues[5] : hues[7]
    readonly property color lilac: hues[8]

    readonly property string mono: config.font || "JetBrains Mono"
    readonly property real s: Math.min(width, height) / 1440   // drawn at 1440p, like the wallpaper
    readonly property real fs: Math.max(12, 19 * s)
    // SDDM opens one window per screen; only the primary one gets the login card
    readonly property bool primary: typeof primaryScreen === "undefined" || primaryScreen
    property date now: new Date()

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string status: ""
    property color statusColor: muted
    property bool busy: false

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    // models are read through hidden repeaters: QML has no index access into SDDM's list models
    Repeater { id: users; model: userModel; Item { property string login: model.name; property string real: model.realName } }
    Repeater { id: sessions; model: sessionModel; Item { property string label: model.name } }

    function pad(n) { return String(n).padStart(2, "0") }
    function span(text, c) { return "<font color='" + c + "'>" + text + "</font>" }
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        const day = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - day)
        return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7)
    }
    function userName() {
        if (users.count === 0) return userInput.text
        const u = users.itemAt(userIndex)
        return u ? u.login : ""
    }
    function userReal() {
        const u = users.count ? users.itemAt(userIndex) : null
        return u && u.real && u.real !== u.login ? u.real : ""
    }
    function sessionName() {
        const x = sessions.itemAt(sessionIndex)
        return x ? x.label.toLowerCase() : "default"
    }
    function cycle(which, step) {
        if (which === "user" && users.count > 1) userIndex = (userIndex + step + users.count) % users.count
        if (which === "session" && sessions.count > 1) sessionIndex = (sessionIndex + step + sessions.count) % sessions.count
    }
    function login() {
        if (busy || userName() === "") return
        busy = true
        status = "authenticating " + userName() + " …"
        statusColor = muted
        sddm.login(userName(), password.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            root.status = "[xx] login failed"
            root.statusColor = root.coral
            password.text = ""
            password.forceActiveFocus()
            shake.restart()
        }
        function onLoginSucceeded() { root.status = "[ok] starting " + root.sessionName(); root.statusColor = root.mint }
        function onInformationMessage(message) { root.status = message; root.statusColor = root.butter }
    }

    // ── # clock, the same glyphs as the desktop's TIME // LOCAL ──
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

    // ── ground: dot grid ──
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

    // ── top bar: λ host on the left, date on the right ──
    Text {
        x: 48 * root.s; y: 40 * root.s
        textFormat: Text.StyledText
        font { family: root.mono; pixelSize: root.fs; bold: true }
        text: root.span("λ ", root.mint) + root.span("nook", root.ink) + root.span("  ~/" + sddm.hostName, root.faint)
    }
    Text {
        anchors { right: parent.right; rightMargin: 48 * root.s }
        y: 40 * root.s
        textFormat: Text.StyledText
        font { family: root.mono; pixelSize: root.fs }
        text: root.span(Qt.formatDate(root.now, "ddd").toLowerCase() + " ", root.lilac)
            + root.span(Qt.formatDate(root.now, "dd.MM.yyyy"), root.hues[2])
            + root.span("  wk" + root.pad(root.isoWeek(root.now)), root.faint)
    }

    // ── centre: clock, then the login card ──
    Column {
        id: centre
        anchors.horizontalCenter: parent.horizontalCenter
        y: (root.height - height) * (root.primary ? 0.36 : 0.4)
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
            visible: root.primary
            width: Math.min(root.width - 64 * root.s, Math.max(560, 760 * root.s))
            height: body.height + 2 * pad
            readonly property real pad: 28 * root.s
            color: root.bg100
            radius: 6 * root.s
            border { width: 1; color: root.lavender }
            transform: Translate { id: nudge }

            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: nudge; property: "x"; to: -10 * root.s; duration: 45 }
                NumberAnimation { target: nudge; property: "x"; to: 10 * root.s; duration: 90 }
                NumberAnimation { target: nudge; property: "x"; to: 0; duration: 45 }
            }

            Column {
                id: body
                x: card.pad; y: card.pad
                width: card.width - 2 * card.pad
                spacing: 14 * root.s

                Item {
                    width: parent.width; height: head.height
                    Text {
                        id: head
                        text: "LOGIN // TTY"
                        color: root.lavender
                        font { family: root.mono; pixelSize: root.fs * 0.8; bold: true; letterSpacing: 1.6 }
                    }
                    Text {
                        anchors.right: parent.right
                        text: Qt.formatTime(root.now, "hh:mm:ss")
                        color: root.faint
                        font { family: root.mono; pixelSize: root.fs * 0.8 }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: root.line }

                // user ‹ name ›   (a text field when SDDM lists no users)
                Field {
                    id: userRow
                    label: "user"
                    hue: root.hues[6]
                    choice: users.count > 0
                    value: root.userName()
                    note: root.userReal()
                    KeyNavigation.tab: password
                    KeyNavigation.backtab: sessionRow
                    onStep: (d) => root.cycle("user", d)
                    TextInput {
                        id: userInput
                        visible: users.count === 0
                        x: userRow.valueX; anchors.verticalCenter: parent.verticalCenter
                        width: userRow.width - x
                        color: root.ink; selectionColor: root.bg300
                        font { family: root.mono; pixelSize: root.fs }
                        KeyNavigation.tab: password
                        onAccepted: password.forceActiveFocus()
                    }
                }

                // password ▸ ••••
                Item {
                    id: passRow
                    width: parent.width; height: Math.round(root.fs * 2)
                    Rectangle { anchors.fill: parent; radius: 3 * root.s; color: root.bg300; visible: password.activeFocus }
                    Text {
                        x: 10 * root.s; anchors.verticalCenter: parent.verticalCenter
                        text: password.activeFocus ? "▶" : " "
                        color: root.lavender
                        font { family: root.mono; pixelSize: root.fs }
                    }
                    Text {
                        x: userRow.labelX; anchors.verticalCenter: parent.verticalCenter
                        text: "pass"; color: root.hues[0]
                        font { family: root.mono; pixelSize: root.fs; bold: true }
                    }
                    TextInput {
                        id: password
                        x: userRow.valueX; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - 12 * root.s
                        focus: true
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        passwordMaskDelay: 0
                        color: root.ink
                        selectionColor: root.bg300
                        clip: true
                        font { family: root.mono; pixelSize: root.fs }
                        cursorDelegate: Rectangle {
                            width: root.fs * 0.6; color: root.lavender
                            visible: password.activeFocus
                            SequentialAnimation on opacity { loops: Animation.Infinite; running: password.activeFocus
                                NumberAnimation { to: 0; duration: 530 } NumberAnimation { to: 1; duration: 530 } }
                        }
                        KeyNavigation.tab: sessionRow
                        KeyNavigation.backtab: users.count ? userRow : userInput
                        onAccepted: root.login()
                        Keys.onPressed: (e) => { if (e.key === Qt.Key_Escape) text = "" }
                    }
                    MouseArea { anchors.fill: parent; z: -1; onClicked: password.forceActiveFocus() }
                }

                Field {
                    id: sessionRow
                    label: "session"
                    hue: root.mint
                    choice: true
                    value: root.sessionName()
                    KeyNavigation.tab: users.count > 1 ? userRow : password
                    KeyNavigation.backtab: password
                    onStep: (d) => root.cycle("session", d)
                }

                Rectangle { width: parent.width; height: 1; color: root.line }

                Item {
                    width: parent.width; height: Math.round(root.fs * 1.8)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: keyboard.capsLock ? "[!!] caps lock is on"
                            : root.status !== "" ? root.status : "⏎ log in · tab next · ←→ change"
                        color: keyboard.capsLock ? root.butter : root.status !== "" ? root.statusColor : root.faint
                        font { family: root.mono; pixelSize: root.fs * 0.8 }
                    }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 8 * root.s
                        Power { label: "suspend"; shown: sddm.canSuspend; onHit: sddm.suspend() }
                        Power { label: "reboot"; shown: sddm.canReboot; onHit: sddm.reboot() }
                        Power { label: "shut down"; shown: sddm.canPowerOff; hot: root.coral; onHit: sddm.powerOff() }
                    }
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

    // a row whose value is picked with ←→ or the ‹ › arrows
    component Field: Item {
        id: field
        property string label
        property color hue
        property string value
        property string note
        property bool choice: true
        signal step(int d)
        readonly property real labelX: 34 * root.s
        readonly property real valueX: labelX + root.fs * 0.6 * 9
        width: parent ? parent.width : 0
        height: Math.round(root.fs * 2)
        activeFocusOnTab: choice
        Keys.onLeftPressed: step(-1)
        Keys.onRightPressed: step(1)
        Keys.onReturnPressed: root.login()
        Keys.onEnterPressed: root.login()

        Rectangle { anchors.fill: parent; radius: 3 * root.s; color: root.bg300; visible: field.activeFocus }
        Text {
            x: 10 * root.s; anchors.verticalCenter: parent.verticalCenter
            text: field.activeFocus ? "▶" : " "
            color: root.lavender
            font { family: root.mono; pixelSize: root.fs }
        }
        Text {
            x: field.labelX; anchors.verticalCenter: parent.verticalCenter
            text: field.label; color: field.hue
            font { family: root.mono; pixelSize: root.fs; bold: true }
        }
        Row {
            visible: field.choice
            x: field.valueX; anchors.verticalCenter: parent.verticalCenter
            spacing: root.fs * 0.6
            Arrow { glyph: "‹"; onHit: field.step(-1) }
            Text { text: field.value; color: root.ink; font { family: root.mono; pixelSize: root.fs } }
            Arrow { glyph: "›"; onHit: field.step(1) }
            Text { text: field.note; color: root.faint; font { family: root.mono; pixelSize: root.fs * 0.8 }
                   anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { anchors.fill: parent; z: -1; enabled: field.choice; onClicked: field.forceActiveFocus() }
    }

    component Arrow: Text {
        property string glyph
        signal hit()
        text: glyph
        color: hover.containsMouse ? root.lavender : root.faint
        font { family: root.mono; pixelSize: root.fs; bold: true }
        MouseArea { id: hover; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: parent.hit() }
    }

    // [ reboot ]: a hover tile with a bar under it, like the taskbar buttons
    component Power: Item {
        id: btn
        property string label
        property bool shown: true
        property color hot: root.lavender
        signal hit()
        visible: shown
        width: txt.implicitWidth + 16 * root.s
        height: txt.implicitHeight + 10 * root.s
        Rectangle { anchors.fill: parent; radius: 3 * root.s; color: root.bg300; visible: area.containsMouse }
        Rectangle {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: area.containsMouse ? parent.width * 0.6 : 0; height: 2; color: btn.hot
            Behavior on width { NumberAnimation { duration: 120 } }
        }
        Text {
            id: txt
            anchors.centerIn: parent
            text: "[ " + btn.label + " ]"
            color: area.containsMouse ? btn.hot : root.muted
            font { family: root.mono; pixelSize: root.fs * 0.8 }
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: btn.hit() }
    }
}

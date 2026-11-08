// Nook login screen (SDDM, Qt 6), in the Ramen Sign design language:
//   ground   bg-000 with the dot grid, scanlines and the glowing NOOK banner
//   centre   the TIME // LOCAL block clock (one hue per row) over a login card in the
//            launcher's look: cyan ring + glow, `user ‹ nbax ›`, a `λ ~/ >` password prompt
//            with a blinking aqua block, `session ‹ hyprland ›`, bracketed power buttons
//   bottom   the desktop's bar: red `λ nook`, the clock pill, a red ⏻
// QtQuick + QtQuick.Effects only (no Plasma modules), so it runs on any Qt 6 SDDM greeter.
// No custom fonts either: the greeter can't read fonts from your home, so the clock is drawn
// from blocks instead of VT323.
//   keys: tab / shift+tab between user, password and session · ←→ change user or session · ⏎ log in
import QtQuick
import QtQuick.Effects

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: bg000

    // palette from theme.conf: "ramen" (default) or "pastel" (the cocoa Plasma rice).
    // Roles: accent (λ, clock, power), focus (rings, selection), ok, warn, error, session.
    readonly property bool ramen: (config.palette || "ramen") !== "pastel"
    readonly property color bg000: ramen ? "#060606" : "#1a1614"
    readonly property color bg100: ramen ? "#0d0d0d" : "#221d1a"
    readonly property color bg300: ramen ? "#202020" : "#372f2a"
    readonly property color line:  ramen ? "#343434" : "#4a3f38"
    readonly property color ink:   ramen ? "#f2f2f2" : "#f6ece4"
    readonly property color muted: ramen ? "#a8a8a8" : "#bfae9f"
    readonly property color faint: ramen ? "#626262" : "#7d6d62"
    readonly property color dots:  ramen ? "#1e1e1e" : "#2e2723"
    readonly property color onAccent: ramen ? "#0d0d0d" : "#1a1614"
    // the nine hues, fire → ice (Ramen) / the pastels
    readonly property var hues: ramen
        ? ["#ff7a5c", "#ff6458", "#ff9a3c", "#ffc247", "#4fd8cf", "#45c8e6", "#62a5ff", "#ffb14a", "#ffd98f"]
        : ["#f5a8c9", "#f7a59a", "#f9c49a", "#f2e29b", "#a6e6bf", "#94dcd6", "#a3cdf5", "#c4b2f5", "#e2b5f0"]
    readonly property color rose:   hues[0]
    readonly property color red:    hues[1]
    readonly property color orange: hues[2]
    readonly property color gold:   hues[3]
    readonly property color aqua:   hues[4]
    readonly property color cyan:   hues[5]
    readonly property color blue:   hues[6]
    readonly property color cream:  hues[8]
    readonly property color accent: ramen ? red : hues[7]       // λ, clock, ⏻
    readonly property color focusHue: ramen ? cyan : hues[7]      // rings, selection
    readonly property color error:  ramen ? orange : red
    function soft(c, a) { return Qt.rgba(c.r, c.g, c.b, a === undefined ? 0.16 : a) }

    readonly property string mono: config.font || "JetBrains Mono"
    readonly property real s: Math.min(width, height) / 1440   // drawn at 1440p, like the desktop
    readonly property real fs: Math.max(12, 17 * s)
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
        status = "λ authenticating " + userName() + " …"
        statusColor = muted
        sddm.login(userName(), password.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            root.status = "[!!] login failed"
            root.statusColor = root.error
            password.text = ""
            password.forceActiveFocus()
            shake.restart()
        }
        function onLoginSucceeded() { root.status = "[OK] starting " + root.sessionName(); root.statusColor = root.aqua }
        function onInformationMessage(message) { root.status = "[~] " + message; root.statusColor = root.gold }
    }

    // ── block clock: 3×5 pixels per digit, ██ per pixel (the desktop's TIME // LOCAL) ──
    readonly property var glyphs: ({
        "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
        "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
        "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
        "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
        "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
        ":": ["0", "1", "0", "1", "0"]
    })
    function blockRow(text, r) {
        return text.split("").map(ch => glyphs[ch][r].replace(/1/g, "██").replace(/0/g, "  ")).join(" ")
    }
    readonly property var clockHues: [rose, red, gold, aqua, cyan]

    // ── NOOK banner: 5-column bands, two columns further per row (fire → ice, diagonal) ──
    readonly property var banner: [
        "███╗   ██╗ ██████╗  ██████╗ ██╗  ██╗",
        "████╗  ██║██╔═══██╗██╔═══██╗██║ ██╔╝",
        "██╔██╗ ██║██║   ██║██║   ██║█████╔╝ ",
        "██║╚██╗██║██║   ██║██║   ██║██╔═██╗ ",
        "██║ ╚████║╚██████╔╝╚██████╔╝██║  ██╗",
        "╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝"]
    function bannerRow(r) {
        const chars = Array.from(banner[r])
        let html = "", cur = -1, open = false
        for (let c = 0; c < chars.length; c++) {
            const k = Math.floor((c + 2 * r) / 5) % 9
            if (k !== cur) { if (open) html += "</font>"; html += "<font color='" + hues[k] + "'>"; open = true; cur = k }
            html += chars[c] === " " ? "&nbsp;" : chars[c]
        }
        return html + "</font>"
    }

    // ── ground: dot grid and scanlines ──
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const g = getContext("2d"), p = 24 * root.s, d = Math.max(1, 2 * root.s)
            g.reset()
            g.fillStyle = root.dots
            for (let y = p / 2; y < height; y += p)
                for (let x = p / 2; x < width; x += p) g.fillRect(x, y, d, d)
            g.fillStyle = "rgba(255,255,255,0.018)"
            for (let y = 0; y < height; y += 3) g.fillRect(0, y, width, 1)
        }
    }
    // ── the NOOK sign, bottom-right above the bar, glowing ──
    Column {
        id: sign
        anchors { right: parent.right; bottom: bar.top; rightMargin: 72 * root.s; bottomMargin: 56 * root.s }
        readonly property real px: Math.min(26 * root.s, root.width * 0.5 / (root.banner[0].length * 0.6))
        Repeater {
            model: root.banner.length
            Text {
                required property int index
                textFormat: Text.StyledText
                text: root.bannerRow(index)
                font { family: root.mono; pixelSize: sign.px }
                lineHeightMode: Text.FixedHeight
                lineHeight: sign.px * 1.1
            }
        }
        Text {
            topPadding: 14 * root.s
            textFormat: Text.StyledText
            font { family: root.mono; pixelSize: root.fs * 0.8 }
            text: root.span("λ ~/", root.aqua) + root.span(" &gt; ", root.faint) + root.span("login", root.muted)
                + root.span("   # cozy, colourful, slightly dangerous-looking", root.faint)
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: root.accent
            shadowBlur: 0.9; shadowOpacity: 0.55
            shadowHorizontalOffset: 0; shadowVerticalOffset: 0
        }
    }

    // ── centre: block clock, then the login card ──
    Column {
        id: centre
        anchors.horizontalCenter: parent.horizontalCenter
        y: (root.height - height - bar.height) * (root.primary ? 0.42 : 0.45)
        spacing: 40 * root.s

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property real px: Math.max(10, 22 * root.s)
            Repeater {
                model: 5
                Text {
                    required property int index
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.blockRow(root.pad(root.now.getHours()) + ":" + root.pad(root.now.getMinutes()), index)
                    color: root.clockHues[index]
                    font { family: root.mono; pixelSize: parent.px }
                    lineHeightMode: Text.FixedHeight
                    lineHeight: parent.px * 0.95
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 14 * root.s
                text: Qt.locale().toString(root.now, "dddd · dd.MM.yyyy").toLowerCase()
                color: root.muted
                font { family: root.mono; pixelSize: root.fs }
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: root.accent
                shadowBlur: 0.7; shadowOpacity: 0.45
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0
            }
        }

        Item {
            // card + its neon halo
            visible: root.primary
            anchors.horizontalCenter: parent.horizontalCenter
            width: card.width; height: card.height
            transform: Translate { id: nudge }

            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: nudge; property: "x"; to: -10 * root.s; duration: 45 }
                NumberAnimation { target: nudge; property: "x"; to: 10 * root.s; duration: 90 }
                NumberAnimation { target: nudge; property: "x"; to: 0; duration: 45 }
            }

            Rectangle {
                id: halo
                anchors.fill: card
                radius: card.radius
                color: root.bg100
                border { width: 1; color: root.focusHue }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: root.focusHue
                    shadowBlur: 1.0; shadowOpacity: 0.55
                    shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                }
            }

            Rectangle {
                id: card
                width: Math.min(root.width - 64 * root.s, Math.max(520, 640 * root.s))
                height: body.height + 2 * pad
                readonly property real pad: 22 * root.s
                color: root.bg100
                radius: 4 * root.s
                border { width: 1; color: root.focusHue }

                Column {
                    id: body
                    x: card.pad; y: card.pad
                    width: card.width - 2 * card.pad
                    spacing: 10 * root.s

                    // header: user@host + LOGIN // TTY
                    Item {
                        width: parent.width; height: who.height
                        Text {
                            id: who
                            textFormat: Text.StyledText
                            font { family: root.mono; pixelSize: root.fs * 1.25; bold: true }
                            text: root.span(root.userName() || "root", root.ink) + root.span("@", root.faint) + root.span(sddm.hostName, root.cyan)
                        }
                        Text {
                            anchors { right: parent.right; verticalCenter: who.verticalCenter }
                            text: "LOGIN // TTY"
                            color: root.faint
                            font { family: root.mono; pixelSize: root.fs * 0.7; bold: true; letterSpacing: 1.6 }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: root.line }

                    // user ‹ name ›   (a text field when SDDM lists no users)
                    Field {
                        id: userRow
                        label: "user"
                        hue: root.cream
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
                            color: root.ink; selectionColor: root.focusHue; selectedTextColor: root.onAccent
                            font { family: root.mono; pixelSize: root.fs }
                            KeyNavigation.tab: password
                            onAccepted: password.forceActiveFocus()
                        }
                    }

                    // λ ~/ > ••••▮   the launcher's prompt box
                    Rectangle {
                        id: prompt
                        width: parent.width
                        height: Math.round(root.fs * 2.3)
                        radius: 2 * root.s
                        color: root.bg000
                        border { width: 1; color: password.activeFocus ? root.focusHue : root.line }
                        Row {
                            anchors { left: parent.left; leftMargin: 12 * root.s; verticalCenter: parent.verticalCenter }
                            spacing: root.fs * 0.6
                            Text { text: "λ ~/"; color: root.aqua; font { family: root.mono; pixelSize: root.fs; bold: true } }
                            Text { text: ">"; color: root.faint; font { family: root.mono; pixelSize: root.fs } }
                        }
                        Text {
                            x: userRow.valueX; anchors.verticalCenter: parent.verticalCenter
                            visible: password.text === "" && !password.activeFocus
                            text: "password"
                            color: root.faint
                            font { family: root.mono; pixelSize: root.fs }
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
                            selectionColor: root.focusHue
                            selectedTextColor: root.onAccent
                            clip: true
                            font { family: root.mono; pixelSize: root.fs }
                            cursorDelegate: Rectangle {
                                width: root.fs * 0.6; color: root.aqua
                                visible: password.activeFocus
                                SequentialAnimation on opacity { loops: Animation.Infinite; running: password.activeFocus
                                    PropertyAction { value: 1 } PauseAnimation { duration: 525 }
                                    PropertyAction { value: 0 } PauseAnimation { duration: 525 } }
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
                        hue: root.aqua
                        choice: true
                        value: root.sessionName()
                        KeyNavigation.tab: users.count > 1 ? userRow : password
                        KeyNavigation.backtab: password
                        onStep: (d) => root.cycle("session", d)
                    }

                    // status: caps lock, login progress, or the key hints
                    Text {
                        width: parent.width
                        topPadding: 2 * root.s
                        text: keyboard.capsLock ? "[!!] caps lock is on"
                            : root.status !== "" ? root.status : "⏎ log in · tab next · ←→ change"
                        color: keyboard.capsLock ? root.gold : root.status !== "" ? root.statusColor : root.faint
                        font { family: root.mono; pixelSize: root.fs * 0.8 }
                    }

                    Rectangle { width: parent.width; height: 1; color: root.line }

                    // [ suspend ] [ reboot ] [ shut down ]: outlined in their hue, filled on hover
                    Row {
                        spacing: 8 * root.s
                        Power { label: "suspend";   hue: root.blue;   shown: sddm.canSuspend;  onHit: sddm.suspend() }
                        Power { label: "reboot";    hue: root.gold;   shown: sddm.canReboot;   onHit: sddm.reboot() }
                        Power { label: "shut down"; hue: root.orange; shown: sddm.canPowerOff; onHit: sddm.powerOff() }
                    }
                }
            }
        }
    }

    // ── the desktop's bar: red λ nook · clock pill · red ⏻ ──
    Item {
        id: bar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 * root.s; bottomMargin: 10 * root.s }
        height: 40 * root.s

        Pill {
            anchors.left: parent.left
            fill: root.accent
            glow: true
            Row {
                anchors.centerIn: parent
                spacing: 8 * root.s
                Text { text: "λ"; color: root.onAccent; font { family: root.mono; pixelSize: root.fs * 1.3; bold: true } }
                Text { text: "nook"; color: root.onAccent; font { family: root.mono; pixelSize: root.fs * 0.85; bold: true }
                       anchors.verticalCenter: parent.verticalCenter }
            }
            width: 110 * root.s
        }

        Pill {
            anchors.horizontalCenter: parent.horizontalCenter
            width: clockRow.width + 28 * root.s
            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 12 * root.s
                Text { text: Qt.formatTime(root.now, "hh:mm"); color: root.accent; font { family: root.mono; pixelSize: root.fs * 1.15; bold: true } }
                Rectangle { width: 1; height: 18 * root.s; color: root.line; anchors.verticalCenter: parent.verticalCenter }
                Text { text: Qt.locale().toString(root.now, "ddd dd.MM.yyyy").replace(/^(\S+?)\.? /, "$1 ").toLowerCase()
                       color: root.ink; font { family: root.mono; pixelSize: root.fs * 0.8 }
                       anchors.verticalCenter: parent.verticalCenter }
            }
        }

        Pill {
            visible: sddm.canPowerOff
            anchors.right: parent.right
            fill: root.accent
            glow: true
            width: height * 1.15
            Text { anchors.centerIn: parent; text: "⏻"; color: root.onAccent; font { pixelSize: root.fs * 1.05; bold: true } }
            MouseArea { anchors.fill: parent; onClicked: sddm.powerOff() }
        }
    }

    // a bar module: bg-100 at 88% with a 1px line, or a solid accent fill with a glow
    component Pill: Rectangle {
        property color fill: "transparent"
        property bool glow: false
        height: parent ? parent.height : 40
        radius: 4 * root.s
        color: fill === Qt.color("transparent") ? root.soft(root.bg100, 0.88) : fill
        border { width: 1; color: fill === Qt.color("transparent") ? root.line : fill }
        layer.enabled: glow
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: root.accent
            shadowBlur: 0.8; shadowOpacity: 0.6
            shadowHorizontalOffset: 0; shadowVerticalOffset: 0
        }
    }

    // a row whose value is picked with ←→ or the ‹ › arrows; cyan-soft + ring when focused
    component Field: Item {
        id: field
        property string label
        property color hue
        property string value
        property string note
        property bool choice: true
        signal step(int d)
        readonly property real labelX: 12 * root.s
        readonly property real valueX: labelX + root.fs * 0.6 * 9
        width: parent ? parent.width : 0
        height: Math.round(root.fs * 2)
        activeFocusOnTab: choice
        Keys.onLeftPressed: step(-1)
        Keys.onRightPressed: step(1)
        Keys.onReturnPressed: root.login()
        Keys.onEnterPressed: root.login()

        Rectangle {
            anchors.fill: parent
            radius: 2 * root.s
            color: field.activeFocus ? root.soft(root.focusHue) : hover.containsMouse ? root.bg300 : "transparent"
            border { width: field.activeFocus ? 1 : 0; color: root.focusHue }
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
        MouseArea { id: hover; anchors.fill: parent; z: -1; hoverEnabled: true; enabled: field.choice; onClicked: field.forceActiveFocus() }
    }

    component Arrow: Text {
        property string glyph
        signal hit()
        text: glyph
        color: area.containsMouse ? root.focusHue : root.faint
        font { family: root.mono; pixelSize: root.fs; bold: true }
        MouseArea { id: area; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: parent.hit() }
    }

    // [ reboot ]: outlined in its hue, soft fill on hover (the launcher's power buttons)
    component Power: Rectangle {
        id: btn
        property string label
        property bool shown: true
        property color hue: root.focusHue
        signal hit()
        visible: shown
        width: txt.implicitWidth + 16 * root.s
        height: txt.implicitHeight + 8 * root.s
        radius: 2 * root.s
        color: area.containsMouse ? root.soft(btn.hue) : "transparent"
        border { width: 1; color: btn.hue }
        Text {
            id: txt
            anchors.centerIn: parent
            text: btn.label
            color: btn.hue
            font { family: root.mono; pixelSize: root.fs * 0.8 }
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: btn.hit() }
    }
}

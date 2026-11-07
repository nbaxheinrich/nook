// APPS // PINNED: a desktop card of app tiles, styled like the Nook taskbar.
// Everything scales with the card, so a bigger widget means bigger tiles.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    readonly property color bg300: "#372f2a"
    readonly property color line: "#4a3f38"
    readonly property color ink: "#f6ece4"
    readonly property color muted: "#bfae9f"
    readonly property color faint: "#7d6d62"
    readonly property color lavender: "#c4b2f5"
    readonly property color mint: "#a6e6bf"
    readonly property string mono: Kirigami.Theme.fixedWidthFont.family

    readonly property var apps: {
        try { return JSON.parse(Plasmoid.configuration.apps) } catch (e) { return [] }
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    P5Support.DataSource {
        id: shell
        engine: "executable"
        onNewData: (source) => disconnectSource(source)
    }

    // open windows, so a tile raises a running app instead of starting a second copy
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    function quote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    // detached and with its output on /dev/null: the DataSource closes its pipes once the shell
    // exits, and an app still writing to them dies of EPIPE (Discord: "write EPIPE" dialog)
    function run(cmd) { shell.connectSource("setsid -f sh -c " + quote(cmd) + " >/dev/null 2>&1 </dev/null") }
    function launch(app) {
        for (let i = 0; i < tasks.count; i++) {
            const idx = tasks.index(i, 0)
            if (tasks.data(idx, TaskManager.AbstractTasksModel.IsWindow)
                    && tasks.data(idx, TaskManager.AbstractTasksModel.AppId) === app.id) {
                tasks.requestActivate(idx)
                return
            }
        }
        run("gtk-launch " + quote(app.id) + " || kioclient exec " + quote(app.path))
    }

    fullRepresentation: ColumnLayout {
        id: card
        spacing: 8
        readonly property int columns: root.apps.length > 6 ? 4 : 3
        readonly property int rows: Math.max(1, Math.ceil(root.apps.length / columns))
        readonly property real gap: 8
        // the tile size that fits both the width and the height left for the grid; taken from the
        // widget's own (fixed) size, not this layout's, which would depend on the tile size itself
        readonly property real tile: Math.max(64, Math.min((root.width - 24 - gap * (columns - 1)) / columns,
                                                        (root.height - 110 - gap * (rows - 1)) / rows / 0.9))
        readonly property real fs: Math.max(11, tile * 0.11)

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "APPS // PINNED"
                color: root.lavender
                font { family: root.mono; pixelSize: Math.max(10, card.fs * 0.8); bold: true; letterSpacing: 1.4 }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "[" + String(root.apps.length).padStart(2, "0") + "]"
                color: root.faint
                font { family: root.mono; pixelSize: Math.max(10, card.fs * 0.8) }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.line }

        Item { Layout.fillHeight: true }

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: card.columns
            rowSpacing: card.gap
            columnSpacing: card.gap

            Repeater {
                model: root.apps
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    implicitWidth: card.tile
                    implicitHeight: card.tile * 0.9

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: root.bg300
                        opacity: mouse.containsMouse ? 1 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    Rectangle {  // tinted wash in the app's hue while pressed
                        anchors.fill: parent
                        radius: 4
                        color: tile.modelData.hue
                        opacity: mouse.pressed ? 0.22 : 0
                    }
                    Text {
                        x: card.tile * 0.06; y: card.tile * 0.04
                        text: "[" + String(tile.index + 1).padStart(2, "0") + "]"
                        color: mouse.containsMouse ? tile.modelData.hue : root.faint
                        font { family: root.mono; pixelSize: card.fs * 0.8 }
                    }
                    Kirigami.Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: card.tile * 0.16
                        width: card.tile * 0.44; height: width
                        source: tile.modelData.icon
                        scale: mouse.containsMouse ? 1.08 : 1
                        Behavior on scale { NumberAnimation { duration: 120 } }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: card.tile * 0.66
                        text: tile.modelData.name
                        color: tile.modelData.hue
                        font { family: root.mono; pixelSize: card.fs; bold: mouse.containsMouse }
                    }
                    Rectangle {  // focus bar, like the taskbar
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                        width: mouse.containsMouse ? card.tile * 0.3 : card.tile * 0.12
                        height: 3
                        color: mouse.containsMouse ? tile.modelData.hue : root.line
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launch(tile.modelData)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.line }

        Text {
            Layout.fillWidth: true
            text: "<font color='" + root.mint + "'>λ</font> ~/ > meta · all apps"
            textFormat: Text.StyledText
            color: footer.containsMouse ? root.ink : root.muted
            font { family: root.mono; pixelSize: Math.max(10, card.fs * 0.85) }
            MouseArea {
                id: footer
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: Plasmoid.configuration.menuCommand !== ""
                onClicked: root.run(Plasmoid.configuration.menuCommand)
            }
        }
    }
}

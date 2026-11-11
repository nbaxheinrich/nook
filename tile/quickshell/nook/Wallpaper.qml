// The wallpaper, drawn live on the background layer of every screen at its real size:
// bg-000 ground, a dot grid (3 × space-2 pitch), faint scanlines, and the glowing NOOK banner.
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

Scope {
    id: root
    readonly property var banner: [
        "███╗   ██╗ ██████╗  ██████╗ ██╗  ██╗",
        "████╗  ██║██╔═══██╗██╔═══██╗██║ ██╔╝",
        "██╔██╗ ██║██║   ██║██║   ██║█████╔╝ ",
        "██║╚██╗██║██║   ██║██║   ██║██╔═██╗ ",
        "██║ ╚████║╚██████╔╝╚██████╔╝██║  ██╗",
        "╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝"
    ]
    // fire → ice, one hue per row
    readonly property var rowHues: [Theme.rose, Theme.red, Theme.orange, Theme.gold, Theme.aqua, Theme.cyan]

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "nook-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: Theme.bg000

            Canvas {
                visible: Settings.shown("desk.grid")
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.fillStyle = Theme.bg000;
                    ctx.fillRect(0, 0, width, height);
                    // dot grid, 24px pitch
                    ctx.fillStyle = "#1e1e1e";
                    for (let y = 12; y < height; y += 24)
                        for (let x = 12; x < width; x += 24)
                            ctx.fillRect(x, y, 2, 2);
                    // scanlines
                    ctx.fillStyle = "rgba(255,255,255,0.018)";
                    for (let y = 0; y < height; y += 3)
                        ctx.fillRect(0, y, width, 1);
                }
            }

            // NOOK banner bottom-right, above the bar
            Column {
                id: art
                visible: Settings.shown("desk.banner")
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 56; bottomMargin: 96 }
                spacing: 0
                Repeater {
                    model: root.banner
                    Text {
                        required property string modelData
                        required property int index
                        text: modelData
                        color: root.rowHues[index]
                        font.family: Theme.font
                        font.pixelSize: win.width > 2000 ? 22 : 16
                        lineHeight: 1.0
                    }
                }
                Text {
                    topPadding: 10
                    text: "λ ~/ > whoami · " + (Quickshell.env("USER") ?? "root") + "@nook — cozy, colourful, slightly dangerous-looking"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: Theme.small
                }
                // big ASCII glows harder
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.alpha(Theme.red, 0.9)
                    shadowBlur: 1.0
                    shadowOpacity: 0.6
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }
        }
    }
}
